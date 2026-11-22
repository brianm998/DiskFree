import SwiftUI
import Combine

@MainActor @Observable
public final class ViewModel {

    /*
     property wrappers used with @Observable:
     
     @Bindable
     @State
     @Environment

     https://forums.developer.apple.com/forums/thread/735416
     
     */
    var localVolumes: [VolumeViewModel] = [] {
        didSet { refreshAllVolumes() }
    }
    var networkVolumes: [VolumeViewModel] = [] {
        didSet { refreshAllVolumes() }
    }

    /// local + network volumes, most free space first.  Stored so views don't
    /// re-sort on every access; refreshed when either list changes and in applyColors.
    private(set) var allVolumes: [VolumeViewModel] = []

    private func refreshAllVolumes() {
        let sorted = (localVolumes + networkVolumes)
          .sorted { $0.lastFreeSize() > $1.lastFreeSize() }
        // avoid invalidating observers when nothing changed
        if sorted.map(\.id) != allVolumes.map(\.id) {
            allVolumes = sorted
        }
    }
    
    var preferences = Preferences() {
        didSet {
            // clamp settings that could spin the poll loops
            let clean = preferences.sanitized()
            if clean.localPollIntervalSeconds != preferences.localPollIntervalSeconds
                || clean.networkPollIntervalSeconds != preferences.networkPollIntervalSeconds
                || clean.maxDataAgeMinutes != preferences.maxDataAgeMinutes
            {
                preferences = clean
            }
            pushThresholdsToVolumes()
        }
    }

    /// clamp preferences in place (call after the user edits a setting)
    func sanitizePreferences() { preferences = preferences.sanitized() }

    /// keep every volume's low-space thresholds in step with preferences;
    /// only assigns on change so unrelated edits don't invalidate volume views
    private func pushThresholdsToVolumes() {
        let warning = preferences.lowSpaceWarningThresholdGigs
        let error = preferences.lowSpaceErrorThresholdGigs
        for v in localVolumes + networkVolumes {
            if v.lowSpaceWarningThresholdGigs != warning { v.lowSpaceWarningThresholdGigs = warning }
            if v.lowSpaceErrorThresholdGigs != error { v.lowSpaceErrorThresholdGigs = error }
        }
    }
    
    var warningLocalVolumes: Set<String> = []
    var errorLocalVolumes: Set<String> = []
    var volumeRecordsTimeDurationSeconds: TimeInterval = 0

    private var cancellables: Set<AnyCancellable> = []

    /// true only for App Store screenshot launches: demo data, no polling,
    /// nothing read from or written to disk
    let isDemo: Bool

    /// screenshot mode: deterministic demo volumes, see ScreenshotMode
    init(demo: Bool) {
        precondition(demo)
        self.isDemo = true
        ScreenshotMode.populate(self)
    }

    func applyDemoColors() { applyColors() }

    init() {
        self.isDemo = false
        Speaker.warmVoiceCache()
        observeTermination()
        Task.detached {
            // try to load load preferences from file
            try? await self.preferenceManager?.loadPreferences()
            if let preferenceManager = self.preferenceManager,
               let preferences = await preferenceManager.getPreferences()
            {
                let clean = preferences.sanitized()
                await MainActor.run {
                    self.preferences = clean
                }
              await self.manager.set(maxDataAgeMinutes: clean.maxDataAgeMinutes)
            }
        }
    }
    
    let manager = Manager()

    /// replaceable in tests (point them at a temporary directory)
    var localVolumeRecordKeeper = LocalVolumeRecordKeeper()
    var networkVolumeRecordKeeper = NetworkVolumeRecordKeeper()

    /// records are written to disk at most this often while polling
    nonisolated static let recordSaveInterval: TimeInterval = 5 * 60
    /// clock for the save policy; replaceable in tests
    var now: () -> Date = { Date() }
    private var lastRecordSave: Date?
    private var pendingLocalRecords: LocalVolumeRecords?
    private var pendingNetworkRecords: NetworkVolumeRecords?
    private var saveTask: Task<Void, Never>?

    /// Queue a save if the interval has passed (or `force`).  Superseded
    /// requests are dropped: only the newest records are written.
    private func requestRecordSave(local: LocalVolumeRecords? = nil,
                                   network: NetworkVolumeRecords? = nil,
                                   force: Bool = false)
    {
        guard persistsToDisk, !isDemo else { return }
        if let local { newLocalVolumeSizes = local }
        if let network { newNetworkVolumeSizes = network }
        let t = now()
        if !force {
            if let last = lastRecordSave, t.timeIntervalSince(last) < Self.recordSaveInterval { return }
        }
        lastRecordSave = t
        if !newLocalVolumeSizes.isEmpty { pendingLocalRecords = newLocalVolumeSizes }
        if !newNetworkVolumeSizes.isEmpty { pendingNetworkRecords = newNetworkVolumeSizes }
        if saveTask == nil { startSaveTask() }
    }

    private func startSaveTask() {
        saveTask = Task { [weak self] in
            while let self, let (l, n) = self.takePending() {
                if let l {
                    do { try await self.localVolumeRecordKeeper?.save(records: l) }
                    catch { print("cannot save local volume records: \(error)") }
                }
                if let n {
                    do { try await self.networkVolumeRecordKeeper?.save(records: n) }
                    catch { print("cannot save network volume records: \(error)") }
                }
            }
            self?.saveTask = nil
        }
    }

    private func takePending() -> (LocalVolumeRecords?, NetworkVolumeRecords?)? {
        if pendingLocalRecords == nil && pendingNetworkRecords == nil { return nil }
        defer { pendingLocalRecords = nil; pendingNetworkRecords = nil }
        return (pendingLocalRecords, pendingNetworkRecords)
    }

    /// Write the latest records now (window closed, app terminating).
    func saveRecordsNow() { requestRecordSave(force: true) }

    /// Wait for any queued record save to finish (tests).
    func flushSaves() async { await saveTask?.value }

    private var terminationObserver: NSObjectProtocol?
    func observeTermination() {
        guard terminationObserver == nil, !isDemo else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated { self?.writeRecordsSynchronously() }
        }
    }

    /// Blocking final write; the process may exit right after this returns.
    private func writeRecordsSynchronously() {
        guard persistsToDisk else { return }
        let l = newLocalVolumeSizes, n = newNetworkVolumeSizes
        let lk = localVolumeRecordKeeper, nk = networkVolumeRecordKeeper
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            if !l.isEmpty { try? await lk?.save(records: l) }
            if !n.isEmpty { try? await nk?.save(records: n) }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 5)
    }
    
    let preferenceManager = PreferenceManager()
    
    var newLocalVolumeSizes: LocalVolumeRecords = [:]

    var newNetworkVolumeSizes: NetworkVolumeRecords = [:]

    func decreaseFontSize() {
        if preferences.legendFontSize > 4 { // XXX hardcoded minimum
            preferences.legendFontSize -= 1
        }
        savePreferences()
    }

    func increaseFontSize() {
        preferences.legendFontSize += 1
        savePreferences()
    }

    var localVolumesSortedByEmptyFirst: [VolumeViewModel] {
        localVolumes.sorted { (a: VolumeViewModel, b: VolumeViewModel) in
            a.lastFreeSize() > b.lastFreeSize()
        } + networkVolumes
    }

    /// false in tests: skip writing record and preference files
    var persistsToDisk = !TestHost.isActive
    /// test seam: the async preference load in init() would overwrite preferences
    var networkPollIntervalOverride: Int?
    /// test seam, like networkPollIntervalOverride (bypasses the clamp)
    var localPollIntervalOverride: Int?

    /// interval the local loop actually sleeps: preference clamped to its range
    nonisolated static func effectiveLocalInterval(_ seconds: Int) -> Int {
        min(max(seconds, Preferences.localPollIntervalRange.lowerBound), Preferences.localPollIntervalRange.upperBound)
    }
    nonisolated static func effectiveNetworkInterval(_ seconds: Int) -> Int {
        min(max(seconds, Preferences.networkPollIntervalRange.lowerBound), Preferences.networkPollIntervalRange.upperBound)
    }
    var currentLocalPollInterval: Int {
        localPollIntervalOverride ?? Self.effectiveLocalInterval(preferences.localPollIntervalSeconds)
    }

    func listNetworkVolumes() {
        if networkVolumeTask != nil { return }
        let manager = self.manager
        self.networkVolumeTask = Task.detached { [weak self] in
            _ = await manager.loadStoredNetworkVolumeRecords()

            var isFirst = true
            // iterate until we are cancelled or the model goes away
            while !Task.isCancelled {
                guard let seconds = await self?.networkPollOnce() else { return }
                if Task.isCancelled { return }
                // don't sleep the first time so the graph updates quicker
                if !isFirst {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(max(seconds, 0)*1_000_000_000))
                    } catch { return }
                }
                isFirst = false
            }
        }
    }

    /// One network poll.  Returns the poll interval, or nil if cancelled.
    private func networkPollOnce() async -> Int? {
        do {
            let (newNetworkVolumes, sizeRecords) =
              try await manager.recordNetworkVolumeSizes()

            await networkRecordViewUpdate(volumes: newNetworkVolumes,
                                          records: sizeRecords)

            /*
             reconcile the existing network volumes with new ones
             create view models for new network volumes
             */
            for newVolume in newNetworkVolumes {
                var isNew = true
                for volumeView in networkVolumes {
                    if volumeView.volume == newVolume {
                        // set sizes here
                        if let sizes = sizeRecords[volumeView.volume.name] {
                            volumeView.sizes = sizes
                        }
                        isNew = false
                        break
                    }
                }

                if isNew {
                    let viewModel = VolumeViewModel(volume: newVolume,
                                                    color: .purple,
                                                    preferences: preferences)
                    if let sizes = sizeRecords[newVolume.name] {
                        viewModel.sizes = sizes
                    }
                    networkVolumes.append(viewModel)
                }
            }
        } catch is CancellationError {
            return nil
        } catch {
            print("ERROR: \(error)")
        }
        return networkPollIntervalOverride ?? Self.effectiveNetworkInterval(preferences.networkPollIntervalSeconds)
    }

    func listLocalVolumes() {
        if listingTask != nil { return }
        self.listingTask = Task.detached { [weak self] in
            do {
                guard let found = try await self?.discoverLocalVolumes() else { return }
                _ = found
                if Task.isCancelled { return }
                await self?.startLocalVolumeTask()
            } catch {
                print("ERROR: \(error)")
            }
        }
    }

    private func discoverLocalVolumes() async throws -> [LocalVolume] {
        await manager.loadStoredLocalVolumeRecords()
        let volumes = try await manager.listLocalVolumes()
        if preferences.localVolumesToShow.count == 0 {
            preferences.localVolumesToShow = Set(volumes.map { $0.name })
        }
        var colorIndex = 0
        localVolumes = volumes.map {
            let ret = VolumeViewModel(volume: $0,
                                      color: lineColors[colorIndex],
                                      preferences: preferences)
            colorIndex += 1
            if colorIndex >= lineColors.count { colorIndex = 0 }
            ret.isSelected = preferences.localVolumesToShow.contains($0.name)
            return ret
        }
        return volumes
    }

    private var listingTask: Task<Void,Never>?
    private var localVolumeTask: Task<Void,Never>?
    private var networkVolumeTask: Task<Void,Never>?

    /// Cancel all polling loops (window closed).  A later listLocalVolumes() /
    /// listNetworkVolumes() starts them again.
    func stopPolling() {
        listingTask?.cancel()
        localVolumeTask?.cancel()
        networkVolumeTask?.cancel()
        listingTask = nil
        localVolumeTask = nil
        networkVolumeTask = nil
        saveRecordsNow()
    }

    /// Like stopPolling(), but returns only after the cancelled loops have finished.
    func stopPollingAndWait() async {
        let tasks = [listingTask, localVolumeTask, networkVolumeTask]
        stopPolling()
        for t in tasks { t?.cancel(); await t?.value }
    }

    public func chartRange(showFree: Bool, showUsed: Bool) -> ClosedRange<UInt> {

        var min = minGigs(showFree: showFree, showUsed: showUsed)
        var max = maxGigs(showFree: showFree, showUsed: showUsed)

        if min<max {

            let bufferGigs = (max-min)/8

            if min > bufferGigs {
                min -= bufferGigs
            } else {
                min = 0
            }
            if max < UInt.max - bufferGigs {
                max += bufferGigs
            } else {
                max = UInt.max
            }
            
            return min...max
        } else {
            return 0...max
        }
    }
    
    private func minGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret = UInt.max<<8
        if localVolumes.count == 0,
           networkVolumes.count == 0
        {
            return 0
        }
        for volumeViewModel in localVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.minGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs < ret { ret = maxGigs }
            }
        }
        for volumeViewModel in networkVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.minGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs < ret { ret = maxGigs }
            }
        }
        return ret
    }

    private func maxGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret: UInt = 0
        if localVolumes.count == 0,
           networkVolumes.count == 0
        {
            return UInt.max<<8
        }
        for volumeViewModel in localVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.maxGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs > ret { ret = maxGigs }
            }
        }
        for volumeViewModel in networkVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.maxGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs > ret { ret = maxGigs }
            }
        }
        return ret
    }
    
    func clearAll() {
        for volumeViewModel in localVolumes {
            volumeViewModel.isSelected = false
        }
    }

    func selectAll() {
        for volumeViewModel in localVolumes {
            volumeViewModel.isSelected = true
        }
    }

    private func potentialSizeAudio(for oldSize: SizeInfo?,
                                    and newSize: SizeInfo,
                                    of volume: VolumeViewModel,
                                    warningThreshold: UInt,
                                    badText: String,
                                    goodText: String,
                                    lowVolumes: inout Set<String>,
                                    with voice: VoiceActor.Voice)
    {
        if !volume.isSelected { return }

        // compare and see if we've crossed this threshold

        if lowVolumes.contains(volume.volume.name) { 
            if newSize.gigsFree > warningThreshold {
                lowVolumes.remove(volume.volume.name)

                let message = goodText
                  .replacingOccurrences(of: "$0", with: volume.volume.name)
                  .replacingOccurrences(of: "$1", with: "\(newSize.gigsFree)")

                say(message, as: voice)
            }
            return
        }

        let message = badText
          .replacingOccurrences(of: "$0", with: volume.volume.name)
          .replacingOccurrences(of: "$1", with: "\(newSize.gigsFree)")

        if let oldSize,
           oldSize.gigsFree >= warningThreshold,
           newSize.gigsFree < warningThreshold
        {
            say(message, as: voice)
            print("WARNING: \(volume.volume.name) oldSize.gigsFree \(oldSize.gigsFree) newSize.gigsFree \(newSize.gigsFree)")
            lowVolumes.insert(volume.volume.name)
        } else if newSize.gigsFree < warningThreshold {
            // no old size
            print("WARNING: \(volume.volume.name) newSize.gigsFree \(newSize.gigsFree)")
            
            say(message, as: voice)
            lowVolumes.insert(volume.volume.name)
        } else {
            // put out some kind of other error if it gets empty or really close to so
        }
    }
    
    private let lineColors: [Color] =
      [
        .blue,
        .cyan,
        .indigo,
        .brown,
        .yellow,
        .pink,
        .orange,
        .purple,
      ]
    /*
     [.mint,
     .green,
     
     .orange,

     .teal,

     */

    func networkRecordViewUpdate(volumes: [NetworkVolume],
                                         records: NetworkVolumeRecords,
                                         shouldSave: Bool = true) async
    {
        if shouldSave { requestRecordSave(network: records) }


        await MainActor.run {
            self.newNetworkVolumeSizes = records
            
            for volume in self.networkVolumes {
                if let newSizes = self.newNetworkVolumeSizes[volume.volume.name] {
                    volume.lastSize = newSizes.last
                    volume.sizes = newSizes
                }
            }

            // apply colors here
            applyColors()
        }

        // XXX still don't have alerts for network drives
    }

    func localRecordViewUpdate(records: LocalVolumeRecords,
                                       duration: TimeInterval,
                                       shouldSave: Bool = true) async
    {

        if shouldSave { requestRecordSave(local: records) }

        await MainActor.run {
            self.newLocalVolumeSizes = records

            self.volumeRecordsTimeDurationSeconds = duration
            
            for volume in self.localVolumes {

                // XXX extract this into a method and call it above for network volumes too
                
                if let newSizes = self.newLocalVolumeSizes[volume.volume.name] {
                    //print("volume.lastSize \(volume.lastSize)")

                    let oldSize = volume.lastSize
                    let newSize = newSizes.last
                    
                    volume.lastSize = newSize
                    volume.sizes = newSizes

                    if let oldSize,
                       let newSize
                    {
                        if preferences.soundVoiceOnErrors { 
                            potentialSizeAudio(for: oldSize,
                                               and: newSize,
                                               of: volume,
                                               warningThreshold: preferences.lowSpaceErrorThresholdGigs,
                                               badText: "Low Disk Space Error.  $0 is running EXTREMELY low on free space.  It now has only $1 gigabytes of free space left.",

                                               goodText: "$0 is no longer extremely low on free space.  It now has $1 gigabytes of free space left.",
                                               lowVolumes: &errorLocalVolumes,
                                               with: preferences.errorVoice)
                        }
                        if preferences.soundVoiceOnWarnings { 
                            potentialSizeAudio(for: oldSize,
                                               and: newSize,
                                               of: volume,
                                               warningThreshold: preferences.lowSpaceWarningThresholdGigs,
                                               badText: "Low Disk Space Warning.  $0 is running low on free space.  It now has only $1 gigabytes of free space left.",

                                               goodText: "$0 is no longer low on free space.  It now has $1 gigabytes of free space left.",
                                               lowVolumes: &warningLocalVolumes,
                                               with: preferences.warningVoice)
                        }
                    }
                    
                    //print("updating volume \(volume.volume.name) size to \(newSizes.count)")
                }
            }
            // only assign when the order changed, so Observation doesn't
            // invalidate every view reading localVolumes on each poll
            if let sorted = Self.sortedIfChanged(self.localVolumes) {
                self.localVolumes = sorted
            }

            // apply colors here
            applyColors()
        }
    }

    /// Volumes sorted by total size (largest first), or nil if already in that order.
    static func sortedIfChanged(_ volumes: [VolumeViewModel]) -> [VolumeViewModel]? {
        let sorted = volumes.sorted {
            $0.lastSize?.totalSize_k ?? 0 > $1.lastSize?.totalSize_k ?? 0
        }
        return sorted.map(\.id) == volumes.map(\.id) ? nil : sorted
    }

    private func applyColors() {
        refreshAllVolumes()   // lastSize values may have changed
        let volumesEmptyFirst = self.allVolumes.filter { $0.isSelected }
        
        var colorIndex = 0
        var lastSelectedViewModel: VolumeViewModel? = nil
        var firstSelectedViewModel: VolumeViewModel? = nil

        let minHue = 0.3
        let maxHue = 1.0

        
        var hueStep = 1.0
        if volumesEmptyFirst.count > 1 {
            hueStep = (maxHue-minHue)/Double(volumesEmptyFirst.count-1)
        }

        var currentHue = minHue 
        
        for volumeViewModel in volumesEmptyFirst {
            volumeViewModel.isMostFull = false
            volumeViewModel.isMostEmpty = false

            if firstSelectedViewModel == nil {
                firstSelectedViewModel = volumeViewModel
                //                    volumeViewModel.lineColor = .green
            } else {
                //                    volumeViewModel.lineColor = lineColors[colorIndex]
                colorIndex += 1
                if colorIndex >= lineColors.count { colorIndex = 0 }
            }
            // 0.00 - dark red
            // 0.25 - greenish
            // 0.50 - bluish
            // 0.75 - purple
            // 1.00 - red again
            
            volumeViewModel.lineColor = Color(hue: currentHue, saturation: 1, brightness: 1)
            currentHue += hueStep
            lastSelectedViewModel = volumeViewModel
        }

        if let lastSelectedViewModel {
            lastSelectedViewModel.isMostFull = true
        }

        if let firstSelectedViewModel {
            firstSelectedViewModel.isMostEmpty = true
        }
    }
    
    private func startLocalVolumeTask() {
        if localVolumeTask != nil { return }
        self.localVolumeTask = Task.detached { [weak self] in
            var isFirst = true
            var pollCount = 0
            // iterate until we are cancelled or the model goes away
            while !Task.isCancelled {
                guard let seconds = await self?.localPollOnce() else { return }

                if Task.isCancelled { return }

                // don't sleep the first time so the graph updates quicker
                if !isFirst {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(max(seconds, 0)*1_000_000_000))
                    } catch { return }
                }
                isFirst = false

                // periodically re-discover local volumes
                pollCount += 1
                let every = Self.rediscoveryPollCount(pollIntervalSeconds: seconds)
                if pollCount >= every {
                    pollCount = 0
                    await self?.rediscoverLocalVolumes()
                }
            }
        }
    }

    /// One local poll.  Returns the poll interval, or nil if cancelled.
    private func localPollOnce() async -> Int? {
        do {
                    let records = try await self.manager.recordLocalVolumeSizes()
            // time span of the records, computed off the main actor
            let duration = Date().timeIntervalSince1970 - oldestTime(from: records)
                    await self.localRecordViewUpdate(records: records, duration: duration)
        } catch is CancellationError {
            return nil
        } catch {
            print("ERROR: \(error)")
        }
        return currentLocalPollInterval
    }

    private func rediscoverLocalVolumes() async {
        do {
            let volumes = try await manager.listLocalVolumes()
            reconcileLocalVolumes(with: volumes)
        } catch {
            print("ERROR re-listing local volumes: \(error)")
        }
    }

    /// number of polls between local volume re-discovery (about once a minute)
    nonisolated static func rediscoveryPollCount(pollIntervalSeconds: Int) -> Int {
        guard pollIntervalSeconds > 0 else { return 1 }
        return max(1, Int((60.0 / Double(pollIntervalSeconds)).rounded(.up)))
    }

    /// Merge freshly discovered volumes into localVolumes, by name.  Existing view
    /// models are kept (with the new volume value); new volumes are appended;
    /// volumes no longer present are left in place.
    func reconcileLocalVolumes(with volumes: [LocalVolume]) {
        for volume in volumes {
            if let existing = localVolumes.first(where: { $0.volume.name == volume.name }) {
                // LocalVolume equality is by name only, so always replace
                existing.volume = .local(volume)
            } else {
                let vm = VolumeViewModel(volume: volume,
                                         color: lineColors[localVolumes.count % lineColors.count],
                                         preferences: preferences)
                vm.isSelected = preferences.localVolumesToShow.contains(volume.name)
                localVolumes.append(vm)
            }
        }
    }

    func updateManager() {
        Task.detached {
          await self.manager.set(maxDataAgeMinutes: self.preferences.maxDataAgeMinutes)
        }
    }
    
    func update() {
        savePreferences()
    }

    func update(for volumeViewModel: VolumeViewModel? = nil) { 
        if let volumeViewModel {
            if volumeViewModel.isSelected {
                self.preferences.localVolumesToShow.insert(volumeViewModel.volume.name)
            } else {
                self.preferences.localVolumesToShow.remove(volumeViewModel.volume.name)
            }
        }
        savePreferences()
    }

    func savePreferences() {
        if isDemo || !persistsToDisk { return }
        let prefsToSave = self.preferences
        Task.detached {
            do {
              await self.preferenceManager?.set(preferences: prefsToSave)
                try await self.preferenceManager?.writePreferences()
            } catch {
                print("error saving preferences: \(error)")
            }
        }
    }
}

