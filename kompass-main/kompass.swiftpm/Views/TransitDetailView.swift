import SwiftUI

/// Segment of a transit journey (e.g. walk → bus → metro → walk)
struct TransitSegment: Identifiable {
    let id = UUID()
    let mode: TransitSegmentMode
    let lineName: String
    let departure: String
    let arrival: String
    let stops: Int
    let duration: TimeInterval
    let color: Color
}

enum TransitSegmentMode: String {
    case walk = "Walk"
    case bus = "Bus"
    case metro = "Metro"
    case tram = "Tram"
    case train = "Train"
    case ferry = "Ferry"
    
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .bus: return "bus.fill"
        case .metro: return "tram.circle.fill"
        case .tram: return "tram.fill"
        case .train: return "train.side.front.car"
        case .ferry: return "ferry.fill"
        }
    }
}

struct TransitDetailView: View {
    let segments: [TransitSegment]
    let totalDuration: TimeInterval
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transit Route")
                        .font(.headline)
                    Text(formatDuration(totalDuration))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Segment Bar
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    let fraction = totalDuration > 0 ? CGFloat(segment.duration / totalDuration) : 1.0 / CGFloat(segments.count)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segment.color.gradient)
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: fraction * CGFloat(segments.count), anchor: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Timeline
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        HStack(alignment: .top, spacing: 14) {
                            // Timeline dot + line
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(segment.color)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: segment.mode.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                                
                                if index < segments.count - 1 {
                                    Rectangle()
                                        .fill(segment.color.opacity(0.3))
                                        .frame(width: 3)
                                        .frame(minHeight: 40)
                                }
                            }
                            
                            // Segment details
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(segment.mode.rawValue)
                                        .font(.subheadline.bold())
                                    
                                    if segment.mode != .walk {
                                        Text(segment.lineName)
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(segment.color)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatDuration(segment.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(segment.departure)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                if segment.stops > 0 {
                                    Text("\(segment.stops) stops → \(segment.arrival)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("→ \(segment.arrival)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }
}
