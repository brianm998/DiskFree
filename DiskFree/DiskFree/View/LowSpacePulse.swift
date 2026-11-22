import SwiftUI

/// Decides whether a low-space warning should pulse. A volume pulses for a
/// fixed number of cycles when it first becomes low, never with Reduce Motion.
struct LowSpacePulseState: Equatable {
    static let defaultCycles = 3

    let cycles: Int
    private(set) var isLow = false
    private(set) var remainingCycles = 0

    init(cycles: Int = LowSpacePulseState.defaultCycles) {
        self.cycles = cycles
    }

    var isPulsing: Bool { remainingCycles > 0 }

    /// Report the current low state. Returns true when a new pulse starts.
    @discardableResult
    mutating func update(isLow newLow: Bool, reduceMotion: Bool) -> Bool {
        defer { isLow = newLow }
        if !newLow || reduceMotion {
            remainingCycles = 0
            return false
        }
        if !isLow {
            remainingCycles = cycles
            return true
        }
        return false
    }

    /// Call when one pulse cycle finishes.
    mutating func finishCycle() {
        if remainingCycles > 0 { remainingCycles -= 1 }
    }
}

struct PulseViewModifier: ViewModifier {
    let isLow: Bool
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = LowSpacePulseState()
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.2 : 1)
            .onAppear { evaluate() }
            .onChange(of: isLow) { _, _ in evaluate() }
            .onChange(of: reduceMotion) { _, _ in evaluate() }
    }

    private func evaluate() {
        guard state.update(isLow: isLow, reduceMotion: reduceMotion) else {
            if !state.isPulsing { dimmed = false }
            return
        }
        runCycle()
    }

    private func runCycle() {
        guard state.isPulsing else { dimmed = false; return }
        withAnimation(.easeInOut(duration: duration)) { dimmed = true } completion: {
            withAnimation(.easeInOut(duration: duration)) { dimmed = false } completion: {
                state.finishCycle()
                runCycle()
            }
        }
    }
}

extension View {
    /// Pulse briefly when `isLow` becomes true; steady otherwise.
    func lowSpacePulse(if isLow: Bool, duration: Double = 0.4) -> some View {
        modifier(PulseViewModifier(isLow: isLow, duration: duration))
    }
}
