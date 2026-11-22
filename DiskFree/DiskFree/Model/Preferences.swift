import Foundation
import os


public struct Preferences: Codable, Sendable {
    var localVolumesToShow: Set<String>
    var localPollIntervalSeconds: Int
    var networkVolumesToShow: Set<String>
    /// Volumes the owner hid, keyed by local volume name. Volumes not listed are shown.
    var localVolumesHidden: Set<String>
    /// Network volumes the owner hid, keyed by localMount.
    var networkVolumesHidden: Set<String>
    /// Set only when a stored file has `localVolumesToShow` but no `localVolumesHidden`
    /// (written by an older version). Consumed by the first discovery; never encoded.
    var legacyLocalVolumesToShow: Set<String>?
    var networkPollIntervalSeconds: Int
    var showSettingsView: Bool
    var chartType: ChartType
    var showFreeSpace: Bool
    var showUsedSpace: Bool
    var soundVoiceOnWarnings: Bool
    var soundVoiceOnErrors: Bool
    var warningVoice: VoiceActor.Voice
    var errorVoice: VoiceActor.Voice
    var legendFontSize: CGFloat
    var lowSpaceWarningThresholdGigs: UInt
    var lowSpaceErrorThresholdGigs: UInt // not used
    var maxDataAgeMinutes: TimeInterval

    init() {
        // defaults are set here
        localVolumesToShow = []
        localPollIntervalSeconds = 4
        networkVolumesToShow = []
        localVolumesHidden = []
        networkVolumesHidden = []
        networkPollIntervalSeconds = 30
        showSettingsView = false
        chartType = .combined
        showFreeSpace = true
        showUsedSpace = false
        soundVoiceOnWarnings = true
        soundVoiceOnErrors = true
        warningVoice = .Ellen // random
        errorVoice = .Ellen // random
        legendFontSize = 24
        lowSpaceWarningThresholdGigs = 100
        lowSpaceErrorThresholdGigs = 20
        maxDataAgeMinutes = 60 // one hour
    }

    static let localPollIntervalRange = 1...3600
    static let networkPollIntervalRange = 5...3600
    static let maxDataAgeMinutesRange: ClosedRange<TimeInterval> = 1...1440

    /// A copy with the settings that could spin the poll loops clamped into range.
    func sanitized() -> Preferences {
        var p = self
        p.localPollIntervalSeconds = min(max(p.localPollIntervalSeconds, Self.localPollIntervalRange.lowerBound), Self.localPollIntervalRange.upperBound)
        p.networkPollIntervalSeconds = min(max(p.networkPollIntervalSeconds, Self.networkPollIntervalRange.lowerBound), Self.networkPollIntervalRange.upperBound)
        let age = p.maxDataAgeMinutes.isFinite ? p.maxDataAgeMinutes : Preferences().maxDataAgeMinutes
        p.maxDataAgeMinutes = min(max(age, Self.maxDataAgeMinutesRange.lowerBound), Self.maxDataAgeMinutesRange.upperBound)
        return p
    }

    private enum CodingKeys: String, CodingKey {
        case localVolumesToShow, localPollIntervalSeconds, networkVolumesToShow,
             localVolumesHidden, networkVolumesHidden,
             networkPollIntervalSeconds, showSettingsView, chartType, showFreeSpace,
             showUsedSpace, soundVoiceOnWarnings, soundVoiceOnErrors, warningVoice,
             errorVoice, legendFontSize, lowSpaceWarningThresholdGigs,
             lowSpaceErrorThresholdGigs, maxDataAgeMinutes
    }

    /// Tolerant decoding: any missing key takes its default from init().
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        localVolumesToShow = try c.decodeIfPresent(Set<String>.self, forKey: .localVolumesToShow) ?? localVolumesToShow
        localVolumesHidden = try c.decodeIfPresent(Set<String>.self, forKey: .localVolumesHidden) ?? localVolumesHidden
        networkVolumesHidden = try c.decodeIfPresent(Set<String>.self, forKey: .networkVolumesHidden) ?? networkVolumesHidden
        if !c.contains(.localVolumesHidden), c.contains(.localVolumesToShow) {
            legacyLocalVolumesToShow = localVolumesToShow
        }
        localPollIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .localPollIntervalSeconds) ?? localPollIntervalSeconds
        networkVolumesToShow = try c.decodeIfPresent(Set<String>.self, forKey: .networkVolumesToShow) ?? networkVolumesToShow
        networkPollIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .networkPollIntervalSeconds) ?? networkPollIntervalSeconds
        showSettingsView = try c.decodeIfPresent(Bool.self, forKey: .showSettingsView) ?? showSettingsView
        chartType = try c.decodeIfPresent(ChartType.self, forKey: .chartType) ?? chartType
        showFreeSpace = try c.decodeIfPresent(Bool.self, forKey: .showFreeSpace) ?? showFreeSpace
        showUsedSpace = try c.decodeIfPresent(Bool.self, forKey: .showUsedSpace) ?? showUsedSpace
        soundVoiceOnWarnings = try c.decodeIfPresent(Bool.self, forKey: .soundVoiceOnWarnings) ?? soundVoiceOnWarnings
        soundVoiceOnErrors = try c.decodeIfPresent(Bool.self, forKey: .soundVoiceOnErrors) ?? soundVoiceOnErrors
        warningVoice = try c.decodeIfPresent(VoiceActor.Voice.self, forKey: .warningVoice) ?? warningVoice
        errorVoice = try c.decodeIfPresent(VoiceActor.Voice.self, forKey: .errorVoice) ?? errorVoice
        legendFontSize = try c.decodeIfPresent(CGFloat.self, forKey: .legendFontSize) ?? legendFontSize
        lowSpaceWarningThresholdGigs = try c.decodeIfPresent(UInt.self, forKey: .lowSpaceWarningThresholdGigs) ?? lowSpaceWarningThresholdGigs
        lowSpaceErrorThresholdGigs = try c.decodeIfPresent(UInt.self, forKey: .lowSpaceErrorThresholdGigs) ?? lowSpaceErrorThresholdGigs
        maxDataAgeMinutes = try c.decodeIfPresent(TimeInterval.self, forKey: .maxDataAgeMinutes) ?? maxDataAgeMinutes
        self = sanitized()
    }
}

public actor PreferenceManager {

    private var preferences: Preferences?

    let preferencesFilename: String

    /// `directory` defaults to the user's Documents folder.
    init?(directory: URL? = nil) {
        guard let dir = directory ?? FileManager.default.urls(for: .documentDirectory,
                                                              in: .userDomainMask).last
        else { return nil }
        self.preferencesFilename = dir.appendingPathComponent("Preferences.json").path
    }

    func set(preferences: Preferences) {
        self.preferences = preferences.sanitized()
    }

    func getPreferences() -> Preferences? { preferences }

    func loadPreferences() async throws {
        if FileManager.default.fileExists(atPath: preferencesFilename) {
            let data = try Data(contentsOf: URL(fileURLWithPath: preferencesFilename))
            do {
                self.preferences = try JSONDecoder().decode(Preferences.self, from: data)
            } catch {
                Log.persistence.error("cannot load preferences: \(error, privacy: .public)")
            }
        }
    }

    func writePreferences() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let jsonData = try encoder.encode(self.preferences)
        try jsonData.write(to: URL(fileURLWithPath: preferencesFilename), options: [.atomic])
    }
}
