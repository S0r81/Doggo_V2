import SwiftUI

// MARK: - 1. Cascading Entry Animation

/// Tracks which entry animations have already played this launch, so the
/// cascade doesn't replay every time the user returns to the tab.
private enum EntryAnimationGate {
    static var completed = Set<Int>()
}

struct EntryAnimationModifier: ViewModifier {
    let index: Int
    let delay: Double
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            // Honor Reduce Motion: fade only, no slide/zoom
            .offset(y: isVisible || reduceMotion ? 0 : 20)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
            .onAppear {
                guard !EntryAnimationGate.completed.contains(index) else {
                    isVisible = true
                    return
                }
                EntryAnimationGate.completed.insert(index)

                if reduceMotion {
                    withAnimation(.easeIn(duration: 0.2).delay(delay)) { isVisible = true }
                    return
                }

                // Determine delay: Base delay + (Index * Stagger)
                let totalDelay = delay + (Double(index) * 0.05)

                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(totalDelay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - 2. Tactile Button Style
// Makes buttons shrink slightly when held down
struct BouncyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(.snappy, value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Extensions for Easy Use
extension View {
    /// Cascades the view in with a slide and fade effect.
    /// - Parameter index: The order in which this view appears (0, 1, 2...)
    func animateEntry(index: Int = 0, delay: Double = 0) -> some View {
        modifier(EntryAnimationModifier(index: index, delay: delay))
    }
    
    /// Apply this to Lists to fix "choppy" re-ordering.
    /// Uses the iOS-standard `.smooth` curve for consistency across screens.
    func smoothListAnimation<T: Equatable>(value: T) -> some View {
        self.animation(.smooth, value: value)
    }
}
