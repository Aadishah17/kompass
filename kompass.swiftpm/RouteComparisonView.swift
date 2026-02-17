import SwiftUI
import MapKit

/// A single route option returned from MKDirections or ride-share estimation
struct RouteOption: Identifiable {
    let id = UUID()
    let mode: ExtendedTransportMode
    let travelTime: TimeInterval
    let distance: CLLocationDistance
    let steps: [SimpleRouteStep]
    let polylineCoords: [CLLocationCoordinate2D]
    var fareEstimate: String?
    var isSelected: Bool = false
}

/// Extended transport modes covering all travel methods
enum ExtendedTransportMode: String, CaseIterable, Identifiable {
    case drive = "Drive"
    case walk = "Walk"
    case transit = "Transit"
    case cycle = "Cycle"
    case scooter = "Scooter"
    case motorcycle = "Motorcycle"
    case ferry = "Ferry"
    case uber = "Uber"
    case lyft = "Lyft"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .drive: return "car.fill"
        case .walk: return "figure.walk"
        case .transit: return "bus.fill"
        case .cycle: return "bicycle"
        case .scooter: return "scooter"
        case .motorcycle: return "motorcycle.fill"
        case .ferry: return "ferry.fill"
        case .uber: return "car.side.front.open"
        case .lyft: return "car.side"
        }
    }
    
    var color: Color {
        switch self {
        case .drive: return .white
        case .walk: return .white
        case .transit: return .white
        case .cycle: return .white
        case .scooter: return .white
        case .motorcycle: return .white
        case .ferry: return .white
        case .uber: return .white
        case .lyft: return .white
        }
    }
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var mkTransportType: MKDirectionsTransportType? {
        switch self {
        case .drive, .motorcycle: return .automobile
        case .walk: return .walking
        case .transit, .ferry: return .transit
        case .cycle, .scooter: return .walking
        case .uber, .lyft: return nil
        }
    }
    
    var isRideShare: Bool {
        self == .uber || self == .lyft
    }
    
    var isNativeRoute: Bool {
        [.drive, .walk, .transit].contains(self)
    }
    
    var speedMultiplier: Double {
        switch self {
        case .scooter: return 0.65
        case .motorcycle: return 0.85
        case .ferry: return 1.2
        default: return 1.0
        }
    }
}

// MARK: - Route Comparison View

struct RouteComparisonView: View {
    let routeOptions: [RouteOption]
    let onSelectRoute: (RouteOption) -> Void
    let onOpenRideShare: (ExtendedTransportMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Routes")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Text("\(routeOptions.count) options")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(white: 0.12)).overlay(Capsule().stroke(Color(white: 0.22), lineWidth: 1)))
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(routeOptions) { option in
                        routeCard(option)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    @ViewBuilder
    private func routeCard(_ option: RouteOption) -> some View {
        let fastestTime = routeOptions.filter({ !$0.mode.isRideShare }).map({ $0.travelTime }).min()
        let isFastest = option.travelTime == fastestTime && !option.mode.isRideShare
        
        Button {
            if option.mode.isRideShare {
                onOpenRideShare(option.mode)
            } else {
                onSelectRoute(option)
            }
        } label: {
            VStack(spacing: 10) {
                // Fastest badge
                if isFastest {
                    Text("FASTEST")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.gradient))
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                        .padding(.vertical, 3)
                }
                
                // Mode Icon with gradient
                ZStack {
                    Circle()
                        .fill(option.isSelected ? option.mode.gradient : LinearGradient(colors: [Color(white: 0.14), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(Circle().stroke(option.isSelected ? Color.clear : Color(white: 0.22), lineWidth: 1))
                        .shadow(color: option.mode.color.opacity(option.isSelected ? 0.4 : 0), radius: 8, y: 4)
                    Image(systemName: option.mode.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(option.isSelected ? .white : option.mode.color)
                        .symbolEffect(.bounce, value: option.isSelected)
                }
                
                // Mode name
                Text(option.mode.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.85))
                
                // ETA
                Text(formatDuration(option.travelTime))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(isFastest ? .green : .white)
                
                // Distance
                Text(formatDist(option.distance))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Fare or label
                if let fare = option.fareEstimate {
                    Text(fare)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(option.mode.gradient))
                } else if option.mode.isRideShare {
                    Text("Open App")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 105)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(option.isSelected
                        ? option.mode.color.opacity(0.12)
                        : Color(white: 0.08))
                    .shadow(color: option.isSelected ? option.mode.color.opacity(0.2) : .clear, radius: option.isSelected ? 12 : 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(option.isSelected ? option.mode.color.opacity(0.5) : Color(white: 0.18), lineWidth: option.isSelected ? 2 : 1)
            )
            .scaleEffect(option.isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: option.isSelected)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }
    
    private func formatDist(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}
