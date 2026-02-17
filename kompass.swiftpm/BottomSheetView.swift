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

    init(isOpen: Binding<Bool>, maxHeight: CGFloat, minHeight: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.content = content()
        self._isOpen = isOpen
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                self.indicator
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                self.content
            }
            .frame(width: geometry.size.width, height: maxHeight, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(white: 0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: -4)
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(self.offset + self.translation, 0))
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: currentDetent)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isOpen)
            .animation(.interactiveSpring(), value: translation)
            .gesture(
                DragGesture()
                    .updating(self.$translation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height - value.translation.height
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
            if closestDetent == .peek && currentDetent == .peek {
                isOpen = false
            } else {
                isOpen = true
                currentDetent = closestDetent
            }
        }
    }
}
