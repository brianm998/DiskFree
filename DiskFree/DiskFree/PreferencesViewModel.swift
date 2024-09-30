import SwiftUI
import Combine

class PreferencesViewModel: ObservableObject {
    // this is tracked with published variables in the volume view models
    // used here for initial values, and also shadowing the view model observables
    var volumesToShow: Set<String>
    @Published var showSettingsView: Bool
    @Published var showMultipleCharts: Bool
    @Published var showFreeSpace: Bool
    @Published var showUsedSpace: Bool
    @Published var soundVoiceOnErrors: Bool
    @Published var errorVoice: VoiceActor.Voice
    @Published var legendFontSize: Int
    @Published var pollIntervalSeconds: Int
    @Published var lowSpaceWarningThresholdGigs: UInt
    @Published var lowSpaceErrorThresholdGigs: UInt

    init() {
        self.volumesToShow = []
        self.showSettingsView = true
        self.showMultipleCharts = false
        self.showFreeSpace = true
        self.showUsedSpace = false
        self.soundVoiceOnErrors = true
        self.errorVoice = .Ellen // random
        self.legendFontSize = 24
        self.pollIntervalSeconds = 12
        self.lowSpaceWarningThresholdGigs = 100
        self.lowSpaceErrorThresholdGigs = 20
    }

    init(preferences: Preferences) {
        self.volumesToShow = Set(preferences.volumesToShow)
        self.showSettingsView = preferences.showSettingsView
        self.showMultipleCharts = preferences.showMultipleCharts
        self.showFreeSpace = preferences.showFreeSpace
        self.showUsedSpace = preferences.showUsedSpace
        self.errorVoice = preferences.errorVoice
        self.soundVoiceOnErrors = preferences.soundVoiceOnErrors
        self.legendFontSize = preferences.legendFontSize
        self.pollIntervalSeconds = preferences.pollIntervalSeconds
        self.lowSpaceWarningThresholdGigs = preferences.lowSpaceWarningThresholdGigs
        self.lowSpaceErrorThresholdGigs = preferences.lowSpaceErrorThresholdGigs
    }

    var preferencesToSave: Preferences {
        Preferences(volumesToShow: Array(volumesToShow),
                    showSettingsView: self.showSettingsView,
                    showMultipleCharts: self.showMultipleCharts,
                    showFreeSpace: self.showFreeSpace,
                    showUsedSpace: self.showUsedSpace,
                    soundVoiceOnErrors: self.soundVoiceOnErrors,
                    errorVoice: self.errorVoice,
                    legendFontSize: self.legendFontSize,
                    pollIntervalSeconds: self.pollIntervalSeconds,
                    lowSpaceWarningThresholdGigs: self.lowSpaceWarningThresholdGigs,
                    lowSpaceErrorThresholdGigs: self.lowSpaceErrorThresholdGigs)
    }
}
