import Combine

@preconcurrency import CoreLocation
import Foundation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var lastLocation: CLLocation?
    @Published var lastHeading: CLHeading?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentPlacemark: CLPlacemark?  // Kept for type stability, now mostly nil
    @Published var currentAddress: String = "Satellite Fix Acquired"


    // Removed geocodeTimer as it requires network

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Upgrade to highest possible accuracy for pinpoint offline tracking
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone  // Receive all updates
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            startLiveUpdates()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.authorizationStatus = auth
            switch auth {
            case .authorizedAlways, .authorizedWhenInUse:
                self?.startLiveUpdates()
            default:
                self?.manager.stopUpdatingLocation()
                self?.manager.stopUpdatingHeading()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.lastLocation = location
            // Provide pinpoint coordinate parsing (Decimal Degrees)
            self?.currentAddress =
                "\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))"
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor [weak self] in
            self?.lastHeading = newHeading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }

    // MARK: - Reverse Geocoding (Disabled for True Offline)
    func reverseGeocode(_ location: CLLocation) {
        // In a true offline app with no local database, we cannot reverse geocode.
        Task { @MainActor [weak self] in
            self?.currentAddress =
                "\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))"
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void)
    {
        completion(
            "\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))"
        )
    }

    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
        return "Unknown Location"
    }

    private func startLiveUpdates() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func bearingTo(target: CLLocationCoordinate2D) -> Double? {
        guard let current = lastLocation else { return nil }

        let lat1 = current.coordinate.latitude.toRadians()
        let lon1 = current.coordinate.longitude.toRadians()
        let lat2 = target.latitude.toRadians()
        let lon2 = target.longitude.toRadians()
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let radiansBearing = atan2(y, x)
        return radiansBearing.toDegrees()
    }

    func distanceTo(_ coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let current = lastLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: target)
    }

    // MARK: - Simulation Logic
    private var simulationTimer: Timer?
    private var simulationRoute: [CLLocationCoordinate2D] = []
    private var simulationIndex = 0
    @Published var isSimulating = false

    func startSimulation(route: [CLLocationCoordinate2D], speedMultiplier: Double = 1.0) {
        stopSimulation()
        guard !route.isEmpty else { return }

        simulationRoute = route
        simulationIndex = 0
        isSimulating = true

        // Stop real updates to avoid conflict (optional, but cleaner)
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()

        // Timer to advance position
        // MKDirections points are usually close. 0.5s interval is okay.
        simulationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5 / speedMultiplier, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.nextSimulationStep()
            }
        }
    }

    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulationRoute = []
        isSimulating = false

        // Resume real updates
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    private func nextSimulationStep() {
        guard simulationIndex < simulationRoute.count else {
            stopSimulation()
            return
        }

        let coord = simulationRoute[simulationIndex]
        let timestamp = Date()

        // Calculate course from current point to next point
        var course: CLLocationDirection = lastHeading?.trueHeading ?? 0
        if simulationIndex + 1 < simulationRoute.count {
            course = calculateBearing(from: coord, to: simulationRoute[simulationIndex + 1])
        } else if simulationIndex > 0 {
            // Keep previous course if at end
            course = calculateBearing(from: simulationRoute[simulationIndex - 1], to: coord)
        }

        let location = CLLocation(
            coordinate: coord,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: course,
            speed: 15,  // ~54 km/h generic speed
            timestamp: timestamp
        )

        lastLocation = location
        simulationIndex += 1
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
        -> Double
    {
        let lat1 = from.latitude.toRadians()
        let lon1 = from.longitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let lon2 = to.longitude.toRadians()
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let radiansBearing = atan2(y, x)
        return radiansBearing.toDegrees()
    }
}
extension Double {
    func toRadians() -> Double { return self * .pi / 180 }
    func toDegrees() -> Double { return self * 180 / .pi }
}
