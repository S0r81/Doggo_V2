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

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20) // Slide up 20px
            .scaleEffect(isVisible ? 1 : 0.98) // Slight zoom in
            .onAppear {
                guard !EntryAnimationGate.completed.contains(index) else {
                    isVisible = true
                    return
                }
                EntryAnimationGate.completed.insert(index)

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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
    func smoothListAnimation<T: Equatable>(value: T) -> some View {
        self.animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
    }
}
