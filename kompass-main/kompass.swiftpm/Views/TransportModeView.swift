import SwiftUI

struct TransportModeView: View {
    @Binding var selectedMode: ExtendedTransportMode
    var routeOptions: [RouteOption]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExtendedTransportMode.allCases) { mode in
                    let option = routeOptions.first(where: { $0.mode == mode })
                    modeChip(mode: mode, option: option)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func modeChip(mode: ExtendedTransportMode, option: RouteOption?) -> some View {
        let isSelected = selectedMode == mode
        
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    
                    if let opt = option {
                        Text(formatDuration(opt.travelTime))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .opacity(0.85)
                    } else if mode.isRideShare {
                        Text("Ride")
                            .font(.system(size: 10, design: .rounded))
                            .opacity(0.7)
                    }
                }
            }
            .foregroundColor(isSelected ? .white : Color(white: 0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(mode.gradient) : AnyShapeStyle(Color(white: 0.15)))
                    .shadow(color: isSelected ? mode.color.opacity(0.5) : .clear, radius: 10, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color(white: 0.25), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}
