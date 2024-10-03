import SwiftUI


/*


 make a swift view that has a @State element that is a VoiceActor.Voice
 and a text box (with sample text) for testing what each one sounds like.

 
 */

struct VoiceChooserView: View {
    @Binding var voice: VoiceActor.Voice // XXX make this @Bindable
    @State var testMessage: String = ""
    let labelText: String
    
    init(labelText: String, voice: Binding<VoiceActor.Voice>) {
        self._voice = voice
        self.labelText = labelText
    }
    
    var body: some View {
        VStack {
            Picker(labelText, selection: $voice) {
                ForEach(VoiceActor.Voice.allCases, id: \.self) { voice in
                    Text(voice.rawValue)
                }
            }
              .onChange(of: voice) { _, voice in
                  self.say()
              }
            HStack {
                Button(action: {
                    if testMessage == "" {
                        testMessage = "Do you like this voice?"
                    }
                    self.say()
                }) {
                    Text("Test")
                }
                TextField("Type Here", text: $testMessage)
                  .onSubmit {
                      self.say()
                  }
            }
        }
    }

    func say() {
        Task {
            do {
                try await voiceActor.say(testMessage, as: voice)
            } catch {
                print("can't say \(testMessage) as \(voice.rawValue): \(error)")
            }
        }
    }
}
