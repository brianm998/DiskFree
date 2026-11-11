import Foundation
import AppKit

// talk to this global actor directly if you want to know when the speaking ends
public let voiceActor = VoiceActor()

// use this method to speak and not wait for it to finish
public func say(_ message: String, as voice: VoiceActor.Voice = .Flo) {
    Task {
        do {
            try await voiceActor.say(message, as: voice)
        } catch {
            print("unable to say: \(message): because of error \(error)")
        }
    }
}

// NSSpeechSynthesizer is used rather than AVSpeechSynthesizer because most
// of the Voice cases (Albert, Bells, Trinoids, Zarvox...) are novelty voices
// that AVSpeechSynthesizer does not expose.
@MainActor
final class Speaker: NSObject, NSSpeechSynthesizerDelegate {
    static let shared = Speaker()

    private var continuation: CheckedContinuation<Void, Never>?

    private static func voiceIdentifier(named name: String) -> NSSpeechSynthesizer.VoiceName? {
        for id in NSSpeechSynthesizer.availableVoices {
            let attrs = NSSpeechSynthesizer.attributes(forVoice: id)
            if attrs[.name] as? String == name { return id }
        }
        return nil
    }

    func speak(_ message: String, voiceName: String) async {
        let synth = NSSpeechSynthesizer(voice: Self.voiceIdentifier(named: voiceName))
            ?? NSSpeechSynthesizer()
        synth.delegate = self
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            self.continuation = c
            if !synth.startSpeaking(message) {
                self.continuation = nil
                c.resume()
            }
        }
        synth.delegate = nil
    }

    nonisolated func speechSynthesizer(_ sender: NSSpeechSynthesizer,
                                       didFinishSpeaking finishedSpeaking: Bool)
    {
        Task { @MainActor in
            let c = self.continuation
            self.continuation = nil
            c?.resume()
        }
    }
}

public actor VoiceActor {

    private var isTalkingNow = false

    private var messageQueue: [(String,Voice)] = []
    
    func say(_ message: String, as voice: Voice = .Flo) async throws {
        self.messageQueue.append((message, voice))

        if self.isTalkingNow { return }

        self.isTalkingNow = true         

        while self.messageQueue.count > 0 {
            let (nextMessage, nextVoice) = self.messageQueue[0]
            self.messageQueue.removeFirst(1)
            
            await Speaker.shared.speak(nextMessage, voiceName: nextVoice.rawValue)
        }
        
        self.isTalkingNow = false
    }
    
    public enum Voice: String,
                       Sendable,
                       CaseIterable,
                       Codable
    { 
        case Albert
        case Alice
        case Alva
        case Amélie
        case Amira
        case Anna
        case Bad
        case Bahh
        case Bells
        case Boing
        case Bubbles
        case Carmit
        case Cellos
        case Damayanti
        case Daniel
        case Daria
        case Eddy
        case Ellen
        case Flo
        case Fred
        case Good
        case Grandma
        case Grandpa
        case Ioana
        case Jacques
        case Jester
        case Joana
        case Junior
        case Kanya
        case Karen
        case Kathy
        case Kyoko
        case Lana
        case Laura
        case Lekha
        case Lesya
        case Linh
        case Luciana
        case Majed
        case Meijia
        case Melina
        case Milena
        case Moira
        case Mónica
        case Montse
        case Nora
        case Organ
        case Paulina
        case Ralph
        case Reed
        case Rishi
        case Rocko
        case Samantha
        case Sandy
        case Sara
        case Satu
        case Shelley
        case Sinji
        case Superstar
        case Tessa
        case Thomas
        case Tina
        case Tingting
        case Trinoids
        case Tünde
        case Whisper
        case Wobble
        case Xander
        case Yelda
        case Yuna
        case Zarvox
        case Zosia
        case Zuzana
    }
}
