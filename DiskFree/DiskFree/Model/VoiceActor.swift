import Foundation

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
            
            let shellActor = ShellActor("say",
                                        arguments: ["-v",
                                                    nextVoice.rawValue,
                                                    "'\(nextMessage)'"])
            try await shellActor.execute()
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
