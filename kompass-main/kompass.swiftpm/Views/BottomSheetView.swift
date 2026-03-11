import SwiftUI

enum SheetDetent: CaseIterable {
    case peek
    case half
    case full

    func height(maxHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek: return 120
        case .half: return maxHeight * 0.45
        case .full: return maxHeight * 0.85
        }
    }
}
struct BottomSheetView<Content: View>: View {
    @Binding var isOpen: Bool
    let maxHeight: CGFloat
    let minHeight: CGFloat
    let content: Content

    @State private var currentDetent: SheetDetent = .peek
    @GestureState private var translation: CGFloat = 0

    private var currentHeight: CGFloat {
        if !isOpen { return minHeight }
        return currentDetent.height(maxHeight: maxHeight)
    }

    private var offset: CGFloat {
        maxHeight - currentHeight
    }

    private var indicator: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 5)
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    cycleDetent()
                }
            }
    }

    init(
        isOpen: Binding<Bool>, maxHeight: CGFloat, minHeight: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.content = content()
        self._isOpen = isOpen
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                self.content
            }
            .frame(width: geometry.size.width, height: maxHeight, alignment: .top)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .environment(\.colorScheme, .dark)
            )
            .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: -4)
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(self.offset + self.translation, 0))
            .animation(
                .spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.5),
                value: currentDetent
            )
            .animation(
                .spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.5), value: isOpen
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: translation)
            .gesture(
                DragGesture()
                    .updating(self.$translation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let velocity =
                            value.predictedEndTranslation.height - value.translation.height
                        let projected = currentHeight - value.translation.height - velocity * 0.15

                        snapToNearest(projectedHeight: projected)
                    }
            )
        }
    }

    private func cycleDetent() {
        switch currentDetent {
        case .peek: currentDetent = .half
        case .half: currentDetent = .full
        case .full: currentDetent = .peek
        }
    }

    private func snapToNearest(projectedHeight: CGFloat) {
        let detents: [SheetDetent] = [.peek, .half, .full]
        var closestDetent = currentDetent
        var closestDist = CGFloat.infinity

        for detent in detents {
            let h = detent.height(maxHeight: maxHeight)
            let dist = abs(projectedHeight - h)
            if dist < closestDist {
                closestDist = dist
                closestDetent = detent
            }
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            // Always keep open when snapping to a detent
            if !isOpen { isOpen = true }
            currentDetent = closestDetent
        }
    }
}
