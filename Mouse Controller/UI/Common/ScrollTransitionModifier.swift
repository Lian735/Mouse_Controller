import SwiftUI

struct ScrollTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollTransition(.animated) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.3)
                .blur(radius: phase.isIdentity ? 0 : 1)
        }
    }
}
