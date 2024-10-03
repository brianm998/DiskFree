import SwiftUI
import Combine

@Observable
class PreferencesViewModel {
    // this is tracked with published variables in the volume view models
    // used here for initial values, and also shadowing the view model observables
    var volumesToShow: Set<String>
    var showSettingsView: Bool
    var showMultipleCharts: Bool
    var showFreeSpace: Bool
    var showUsedSpace: Bool
    var soundVoiceOnWarnings: Bool
    var soundVoiceOnErrors: Bool
    var warningVoice: VoiceActor.Voice
    var errorVoice: VoiceActor.Voice
    var legendFontSize: CGFloat
    var pollIntervalSeconds: Int
    var lowSpaceWarningThresholdGigs: UInt
    var lowSpaceErrorThresholdGigs: UInt

    init() {
        self.volumesToShow = []
        self.showSettingsView = false
        self.showMultipleCharts = false
        self.showFreeSpace = true
        self.showUsedSpace = false
        self.soundVoiceOnWarnings = true
        self.soundVoiceOnErrors = true
        self.warningVoice = .Ellen // random
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
        self.warningVoice = preferences.warningVoice
        self.errorVoice = preferences.errorVoice
        self.soundVoiceOnWarnings = preferences.soundVoiceOnWarnings
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
                    soundVoiceOnWarnings: self.soundVoiceOnWarnings,
                    soundVoiceOnErrors: self.soundVoiceOnErrors,
                    warningVoice: self.warningVoice,
                    errorVoice: self.errorVoice,
                    legendFontSize: self.legendFontSize,
                    pollIntervalSeconds: self.pollIntervalSeconds,
                    lowSpaceWarningThresholdGigs: self.lowSpaceWarningThresholdGigs,
                    lowSpaceErrorThresholdGigs: self.lowSpaceErrorThresholdGigs)
    }
}
