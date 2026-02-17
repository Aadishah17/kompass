import SwiftUI

struct CompassView: View {
    var heading: Double // The magnetic heading of the device
    var targetBearing: Double? // The bearing to the destination
    var distance: Double? // Distance in meters
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer Ring
                Circle()
                    .stroke(LinearGradient(colors: [.white, .gray], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                    .frame(width: 220, height: 220)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Cardinal Directions
                ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                    Text(direction)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .offset(y: -95)
                        .rotationEffect(.degrees(angleForDirection(direction)))
                }
                
                // Compass markings
                ForEach(0..<60) { i in
                    Rectangle()
                        .fill(i % 15 == 0 ? Color.primary : Color.primary.opacity(0.4))
                        .frame(width: 2, height: i % 15 == 0 ? 15 : 8)
                        .offset(y: -105)
                        .rotationEffect(.degrees(Double(i) * 6))
                }
                
                // Destination Pointer (the fun interactive part!)
                if let target = targetBearing {
                    let relativeBearing = target - heading
                    
                    VStack {
                        Image(systemName: "location.north.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                            .shadow(color: .orange.opacity(0.6), radius: 10)
                            .offset(y: -130) // Positioned outside/on the edge
                    }
                    .rotationEffect(.degrees(relativeBearing))
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: relativeBearing)
                }
                
                // Device Heading indicator (Center)
                VStack {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.4), radius: 5)
                }
                
                // Heading Display
                VStack {
                    Spacer()
                    Text("\(Int(heading))°")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.bottom, 60)
                }
            }
            .frame(width: 250, height: 250)
            .rotationEffect(.degrees(-heading)) // Rotate the whole dial opposite to heading
            
            if let dist = distance {
                VStack {
                    Text("DISTANCE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    Text(formatDistance(dist))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.primary.opacity(0.1)))
            }
        }
        .padding(30)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func angleForDirection(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
}

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            CompassView(heading: 45, targetBearing: 10, distance: 1200)
        }
    }
}
