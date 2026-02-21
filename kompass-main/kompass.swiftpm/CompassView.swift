import SwiftUI
import CoreLocation

struct CompassView: View {
    @ObservedObject var locationManager: LocationManager
    var targetCoordinate: CLLocationCoordinate2D?
    @State private var isBreathing = false
    private let hapticEngine = UIImpactFeedbackGenerator(style: .heavy)
    @State private var lastHapticHeading: Int = -999
    
    var breathingDuration: Double {
        guard let dist = targetCoordinate.flatMap({ locationManager.distanceTo($0) }), dist > 0 else { return 2.5 }
        let minDuration = 0.4
        let maxDuration = 2.5
        let maxDistance = 1000.0 // 1km
        
        if dist > maxDistance { return maxDuration }
        return minDuration + (maxDuration - minDuration) * (dist / maxDistance)
    }
    
    var body: some View {
        let magnetic = locationManager.lastHeading?.magneticHeading ?? 0
        let trueH = locationManager.lastHeading?.trueHeading ?? -1
        let heading = trueH >= 0 ? trueH : magnetic
        
        let bearing: Double? = targetCoordinate.flatMap { locationManager.bearingTo(target: $0) }
        let distance: Double? = targetCoordinate.flatMap { locationManager.distanceTo($0) }
        
        VStack(spacing: 24) {
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.white.opacity(0.6), .gray.opacity(0.2), .white.opacity(0.6)],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(isBreathing ? 1.05 : 0.95)
                    .opacity(isBreathing ? 0.8 : 0.5)
                    .animation(
                        .easeInOut(duration: breathingDuration).repeatForever(autoreverses: true),
                        value: isBreathing
                    )
                
                // Inner ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 230, height: 230)
                    .scaleEffect(isBreathing ? 1.02 : 0.98)
                    .animation(
                        .easeInOut(duration: breathingDuration).repeatForever(autoreverses: true).delay(0.1),
                        value: isBreathing
                    )
                
                // Tick marks
                ForEach(0..<72, id: \.self) { i in
                    let isMajor = i % 18 == 0
                    let isMinor = i % 9 == 0
                    Rectangle()
                        .fill(isMajor ? Color.white : (isMinor ? Color.white.opacity(0.5) : Color.white.opacity(0.2)))
                        .frame(width: isMajor ? 2.5 : 1.5, height: isMajor ? 18 : (isMinor ? 12 : 6))
                        .offset(y: -118)
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                
                // Cardinal directions
                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, dir in
                    Text(dir)
                        .font(.system(size: dir == "N" ? 22 : 16, weight: .black, design: .rounded))
                        .foregroundColor(dir == "N" ? .red : .white)
                        .offset(y: -96)
                        .rotationEffect(.degrees(Double(index) * 90))
                }
                
                // Intercardinal directions
                ForEach(Array(["NE", "SE", "SW", "NW"].enumerated()), id: \.offset) { index, dir in
                    Text(dir)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .offset(y: -96)
                        .rotationEffect(.degrees(45 + Double(index) * 90))
                }
                
                // Degree labels at 30° intervals
                ForEach([30, 60, 120, 150, 210, 240, 300, 330], id: \.self) { deg in
                    Text("\(deg)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .offset(y: -82)
                        .rotationEffect(.degrees(Double(deg)))
                }
                
                // Destination pointer arrow
                if let targetBearing = bearing {
                    let normalizedBearing = targetBearing
                    
                    ZStack {
                        // Glow trail
                        Image(systemName: "location.north.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .foregroundColor(.orange.opacity(0.3))
                            .blur(radius: 8)
                            .offset(y: -138)
                        
                        // Main arrow
                        Image(systemName: "location.north.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .orange.opacity(0.8), radius: 12)
                            .offset(y: -138)
                    }
                    .rotationEffect(.degrees(normalizedBearing))
                }
                
                // Center device heading needle
                VStack(spacing: 2) {
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 14, height: 18)
                        .shadow(color: .red.opacity(0.5), radius: 4)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    
                    Triangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 14, height: 18)
                        .rotationEffect(.degrees(180))
                }
                
                // Heading degrees
                Text("\(Int(heading))°")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .offset(y: 50)
            }
            .frame(width: 280, height: 280)
            .rotationEffect(.degrees(-heading))
            .animation(.easeOut(duration: 0.3), value: heading)
            .onChange(of: heading) { newHeading in
                if let tb = bearing {
                    let diff = ((tb - newHeading) + 360).truncatingRemainder(dividingBy: 360)
                    if (diff <= 1 || diff >= 359) {
                        if abs(newHeading - Double(lastHapticHeading)) > 2 { // Fire only if we moved away and came back
                            hapticEngine.impactOccurred()
                            lastHapticHeading = Int(newHeading)
                        }
                    }
                }
            }
            
            // Distance capsule
            if let dist = distance, dist > 0 {
                VStack(spacing: 4) {
                    Text("DISTANCE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(white: 0.45))
                        .tracking(2)
                    Text(formatDistance(dist))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .overlay(Capsule().stroke(Color(white: 0.15), lineWidth: 1))
                )
            }
        }
        .onAppear {
            isBreathing = true
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
}

// Simple triangle shape for the compass needle
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CompassView(
                locationManager: LocationManager(),
                targetCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
        }
    }
}
