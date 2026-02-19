import SwiftUI

// MARK: - Dynamic Island Navigation Overlay
// Simulates Apple Maps-style Dynamic Island during navigation.
// Shows compact pill by default; expand on tap for detailed view.

struct DynamicIslandView: View {
    let currentInstruction: String
    let nextInstruction: String?
    let etaSeconds: TimeInterval
    let distanceMeters: Double
    let stepIndex: Int
    let totalSteps: Int
    var onTap: () -> Void = {}
    var onEndNavigation: () -> Void = {}
    
    @State private var isExpanded = false
    @State private var pulseArrow = false
    
    // Derive turn icon from instruction
    private var turnIcon: String {
        let lower = currentInstruction.lowercased()
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("u-turn") || lower.contains("u turn") { return "arrow.uturn.down" }
        if lower.contains("merge") { return "arrow.merge" }
        if lower.contains("exit") { return "arrow.up.right" }
        if lower.contains("destination") || lower.contains("arrive") { return "mappin.circle.fill" }
        return "arrow.up"
    }
    
    private var etaFormatted: String {
        let mins = Int(etaSeconds) / 60
        if mins < 1 { return "<1 min" }
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    
    private var distFormatted: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m"
        }
        return String(format: "%.1f km", distanceMeters / 1000)
    }
    
    var body: some View {
        VStack {
            if isExpanded {
                expandedView
            } else {
                compactView
            }
            Spacer()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isExpanded)
        .onAppear {
            pulseArrow = true
        }
    }
    
    // MARK: - Compact Pill (Apple Maps style)
    private var compactView: some View {
        HStack(spacing: 0) {
            // Leading: Turn arrow
            HStack(spacing: 8) {
                Image(systemName: turnIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .overlay(
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .white.opacity(0.7), .clear]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 30)
                                .offset(x: pulseArrow ? proxy.size.width : -30)
                                .animation(
                                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                                    value: pulseArrow
                                )
                        }
                        .mask(Image(systemName: turnIcon).font(.system(size: 14, weight: .bold)))
                    )
                    .onAppear {
                        pulseArrow = true
                    }
                
                Text(abbreviateInstruction(currentInstruction))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Trailing: ETA
            Text(etaFormatted)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .layoutPriority(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .frame(width: 200)
        .padding(.top, 14) // Increased slightly to lower it from the sensor housing
        .contentShape(Rectangle()) // Ensure the entire area is hittable
        .onTapGesture {
            print("Dynamic Island Tapped") // Debug print
            isExpanded = true
        }
    }
    
    // MARK: - Expanded View (Apple Maps Dynamic Island expanded)
    private var expandedView: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 12) {
                // Turn direction header
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: turnIcon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentInstruction.isEmpty ? "Continue on route" : currentInstruction)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if let next = nextInstruction, !next.isEmpty {
                            Text("Then: \(abbreviateInstruction(next))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.5))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(white: 0.2))
                            .frame(height: 3)
                        Capsule()
                            .fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(stepIndex + 1) / CGFloat(max(totalSteps, 1)), height: 3)
                            .animation(.spring(response: 0.4), value: stepIndex)
                    }
                }
                .frame(height: 3)
                
                // Bottom row: ETA + Distance + Step
                HStack {
                    // ETA
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(etaFormatted)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Distance
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.5))
                        Text(distFormatted)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(white: 0.6))
                    }
                    
                    Spacer()
                    
                    // Step count
                    Text("Step \(stepIndex + 1)/\(totalSteps)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .onTapGesture {
            isExpanded = false
        }
    }
    
    private func abbreviateInstruction(_ text: String) -> String {
        let short = text
            .replacingOccurrences(of: "Turn ", with: "")
            .replacingOccurrences(of: "Continue on ", with: "On ")
            .replacingOccurrences(of: "Keep ", with: "")
            .replacingOccurrences(of: "Proceed to ", with: "To ")
        return String(short.prefix(30)) + (short.count > 30 ? "…" : "")
    }
}
