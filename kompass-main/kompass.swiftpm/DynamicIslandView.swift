import Foundation
import SwiftUI

struct DynamicIslandView: View {
    let destinationName: String
    let destinationDetail: String
    let currentInstruction: String
    let nextInstruction: String?
    let summaryText: String
    let arrivalTimeText: String
    let statusText: String
    let etaSeconds: TimeInterval
    let distanceMeters: Double
    let progressValue: Double
    let stepIndex: Int
    let totalSteps: Int
    var onTap: () -> Void = {}
    var onEndNavigation: () -> Void = {}

    @State private var isExpanded = false

    private var turnIcon: String {
        let lower = currentInstruction.lowercased()
        if lower.contains("direct") { return "arrow.up" }
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("u-turn") || lower.contains("u turn") { return "arrow.uturn.down" }
        if lower.contains("merge") { return "arrow.merge" }
        if lower.contains("exit") { return "arrow.up.right" }
        if lower.contains("destination") || lower.contains("arrive") { return "flag.checkered" }
        return "arrow.up"
    }

    private var etaFormatted: String {
        let mins = Int(etaSeconds) / 60
        if mins < 1 { return "<1 min" }
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        let minutes = mins % 60
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    private var distanceFormatted: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) m"
        }
        return String(format: "%.1f km", distanceMeters / 1000)
    }

    private var progressPercentText: String {
        "\(Int((clampedProgress * 100).rounded()))%"
    }

    private var clampedProgress: Double {
        min(max(progressValue, 0), 1)
    }

    private var stepText: String {
        "\(min(stepIndex + 1, max(totalSteps, 1)))/\(max(totalSteps, 1))"
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if isExpanded {
                    expandedView
                } else {
                    compactView
                }
                Spacer()
            }
            .padding(.top, max(proxy.safeAreaInsets.top + 6, 18))
            .padding(.horizontal, isExpanded ? 12 : 18)
            .animation(.spring(response: 0.4, dampingFraction: 0.84), value: isExpanded)
        }
        .ignoresSafeArea(.all, edges: .top)
    }

    private var compactView: some View {
        Button {
            onTap()
            isExpanded = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: turnIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(destinationName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.58))
                        .lineLimit(1)
                    Text(abbreviate(currentInstruction, limit: 26))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(etaFormatted)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    Text(progressPercentText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.black)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(destinationName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(destinationDetail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.54))
                        .lineLimit(2)
                    statusPill(statusText)
                }

                Spacer(minLength: 12)

                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(white: 0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: turnIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentInstruction.isEmpty ? "Continue on route" : currentInstruction)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let nextInstruction, !nextInstruction.isEmpty {
                        Text("Then \(abbreviate(nextInstruction, limit: 44))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(white: 0.58))
                            .lineLimit(2)
                    }

                    Text(summaryText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.green.opacity(0.9))
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Trip progress")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.55))
                    Spacer(minLength: 8)
                    Text(progressPercentText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(white: 0.18))
                        Capsule()
                            .fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(clampedProgress))
                    }
                }
                .frame(height: 5)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                statCard(title: "ETA", value: etaFormatted, accent: .green)
                statCard(title: "Arrive", value: arrivalTimeText)
                statCard(title: "Left", value: distanceFormatted)
                statCard(title: "Step", value: stepText)
            }

            HStack(spacing: 10) {
                Text(abbreviate(summaryText, limit: 40))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(white: 0.58))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    onEndNavigation()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("End")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.78))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func statusPill(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(white: 0.14))
            )
            .overlay(
                Capsule()
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
    }

    private func statCard(title: String, value: String, accent: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.55))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(white: 0.18), lineWidth: 1)
        )
    }

    private func abbreviate(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }
}
