import Testing
import Foundation
@testable import DiskFree

struct SpeakerTests {
    @Test func voicesEnumeratedOncePerProcess() {
        _ = Speaker.voiceIdentifier(named: "Flo")
        _ = Speaker.voiceIdentifier(named: "Fred")
        #expect(Speaker.enumerationCount == 1)
    }

    @Test func unknownVoiceHasNoIdentifier() {
        #expect(Speaker.voiceIdentifier(named: "No Such Voice") == nil)
    }
}
