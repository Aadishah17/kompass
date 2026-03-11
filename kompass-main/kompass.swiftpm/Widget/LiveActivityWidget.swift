import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct LiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NavigationAttributes.self) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: maneuverIcon(for: context.state.currentInstruction))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.destinationName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(white: 0.55))

                        if !context.attributes.destinationDetail.isEmpty {
                            Text(context.attributes.destinationDetail)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.52))
                                .lineLimit(1)
                        }

                        Text(context.state.currentInstruction)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 8) {
                        statusBadge(context.state.statusText)
                        metricPill(value: context.state.arrivalTimeText, label: "Arrive")
                    }
                }

                if let next = context.state.nextInstruction, !next.isEmpty {
                    Text("Then \(next)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(2)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    infoCard(title: "ETA", value: formatETA(context.state.etaSeconds), accent: .green)
                    infoCard(title: "Left", value: formatDistance(context.state.distanceMeters))
                    infoCard(
                        title: "Step",
                        value: "\(context.state.stepIndex + 1)/\(max(context.state.totalSteps, 1))"
                    )
                    infoCard(title: "Progress", value: progressText(for: context.state))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(context.state.summaryText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(white: 0.55))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(progressText(for: context.state))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(white: 0.18))
                            Capsule().fill(Color.green)
                                .frame(width: geo.size.width * progress(for: context.state))
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(16)
            .background(Color.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.destinationName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(white: 0.55))

                        if !context.attributes.destinationDetail.isEmpty {
                            Text(context.attributes.destinationDetail)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.48))
                                .lineLimit(2)
                        }

                        statusBadge(context.state.statusText)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(formatETA(context.state.etaSeconds))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text(context.state.arrivalTimeText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(formatDistance(context.state.distanceMeters))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(white: 0.6))
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: maneuverIcon(for: context.state.currentInstruction))
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(compactInstruction(context.state.currentInstruction))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            if let next = context.state.nextInstruction, !next.isEmpty {
                                Text("Then \(compactInstruction(next))")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(white: 0.6))
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(context.state.summaryText)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(white: 0.55))
                            Spacer(minLength: 8)
                            miniChip(progressText(for: context.state), systemImage: "chart.bar.fill")
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(white: 0.18))
                                Capsule().fill(Color.green)
                                    .frame(width: geo.size.width * progress(for: context.state))
                            }
                        }
                        .frame(height: 5)

                        HStack(spacing: 8) {
                            miniChip(context.state.arrivalTimeText, systemImage: "clock.badge.checkmark")
                            miniChip(formatDistance(context.state.distanceMeters), systemImage: "arrow.left.and.right")
                            miniChip(
                                "\(context.state.stepIndex + 1)/\(max(context.state.totalSteps, 1))",
                                systemImage: "list.number"
                            )
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: maneuverIcon(for: context.state.currentInstruction))
                    .foregroundColor(.green)
            } compactTrailing: {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatETA(context.state.etaSeconds))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(progressText(for: context.state))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.7))
                }
            } minimal: {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                    Image(systemName: maneuverIcon(for: context.state.currentInstruction))
                        .foregroundColor(.green)
                }
            }
            .keylineTint(.green)
        }
    }

    @ViewBuilder
    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.55))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
    }

    @ViewBuilder
    private func infoCard(title: String, value: String, accent: Color = .white) -> some View {
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
    }

    @ViewBuilder
    private func statusBadge(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(white: 0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func miniChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(white: 0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
    }

    private func progress(for state: NavigationAttributes.ContentState) -> CGFloat {
        CGFloat(min(max(state.progressValue, 0), 1))
    }

    private func progressText(for state: NavigationAttributes.ContentState) -> String {
        "\(Int((min(max(state.progressValue, 0), 1) * 100).rounded()))%"
    }

    private func compactInstruction(_ instruction: String) -> String {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 26 else { return trimmed }
        return String(trimmed.prefix(26)) + "…"
    }

    private func maneuverIcon(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("arrive") { return "flag.checkered" }
        if lower.contains("walk") { return "figure.walk" }
        if lower.contains("ride") { return "tram.fill" }
        return "arrow.up"
    }

    private func formatETA(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 1 { return "<1m" }
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}
