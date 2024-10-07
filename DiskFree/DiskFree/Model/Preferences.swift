import Foundation


public struct Preferences: Codable, Sendable {
    var localVolumesToShow: Set<String>
    var localPollIntervalSeconds: Int
    var networkVolumesToShow: Set<String>
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
}

public actor PreferenceManager {

    private var preferences: Preferences?
    
    let preferencesFilename: String
    
    init?() {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                             in: .userDomainMask).last
        {
            let fileURL = documentsDirectory.appendingPathComponent("Preferences.json")
            self.preferencesFilename = fileURL.path
            print("using preferencesFilename \(preferencesFilename)")
        } else {
            return nil          // XXX maybe throw error instead?
        }
    }

    func set(preferences: Preferences) {
        self.preferences = preferences
    }
    
    func getPreferences() -> Preferences? { preferences }
    
    func loadPreferences() async throws {
        if FileManager.default.fileExists(atPath: preferencesFilename) {
            let url = NSURL(fileURLWithPath: preferencesFilename, isDirectory: false) as URL
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            let decoder = JSONDecoder()
            do {
                self.preferences = try decoder.decode(Preferences.self, from: data)
            } catch {
                print("cannot load preferences: \(error)")
            }
        }
    }

    func writePreferences() throws {
        if FileManager.default.fileExists(atPath: preferencesFilename) {
            // blow away any existing file
            try FileManager.default.removeItem(atPath: preferencesFilename)
        }

        // write out new file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        
        let jsonData = try encoder.encode(self.preferences)

        FileManager.default.createFile(atPath: preferencesFilename,
                                       contents: jsonData,
                                       attributes: nil)
        
    }
}
