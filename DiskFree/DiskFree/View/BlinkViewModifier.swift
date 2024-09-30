import SwiftUI

struct BlinkViewModifier: ViewModifier {
    let duration: Double
    @State private var blinking: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(blinking ? 0.02 : 1)
            .animation(.easeInOut(duration: duration).repeatForever(), value: blinking)
            .onAppear { blinking.toggle() }
    }
}

extension View {
    func blinking(if shouldBlink: Bool = true, duration: Double = 0.5) -> some View {
        Group {
            if shouldBlink {
                modifier(BlinkViewModifier(duration: duration))
            } else {
                self
            }
        }
    }
}
