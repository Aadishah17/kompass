import Foundation
import UIKit
import CoreLocation

struct RideShareService {
    
    enum Provider: String, CaseIterable, Identifiable {
        case uber = "Uber"
        case lyft = "Lyft"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .uber: return "car.side.front.open"
            case .lyft: return "car.side"
            }
        }
        
        var color: UIColor {
            switch self {
            case .uber: return UIColor.black
            case .lyft: return UIColor(red: 234/255, green: 0, blue: 137/255, alpha: 1)
            }
        }
        
        var urlScheme: String {
            switch self {
            case .uber: return "uber://"
            case .lyft: return "lyft://"
            }
        }
        
        var appStoreURL: String {
            switch self {
            case .uber: return "https://apps.apple.com/app/uber-request-a-ride/id368677368"
            case .lyft: return "https://apps.apple.com/app/lyft/id529379082"
            }
        }
    }
    
    /// Check if the ride-share app is installed
    @MainActor
    static func isAvailable(_ provider: Provider) -> Bool {
        guard let url = URL(string: provider.urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Generate deep link URL for the provider
    static func deepLink(
        provider: Provider,
        pickupLat: Double,
        pickupLon: Double,
        dropoffLat: Double,
        dropoffLon: Double,
        dropoffName: String? = nil
    ) -> URL? {
        switch provider {
        case .uber:
            var components = URLComponents(string: "uber://")
            components?.queryItems = [
                URLQueryItem(name: "action", value: "setPickup"),
                URLQueryItem(name: "pickup[latitude]", value: "\(pickupLat)"),
                URLQueryItem(name: "pickup[longitude]", value: "\(pickupLon)"),
                URLQueryItem(name: "dropoff[latitude]", value: "\(dropoffLat)"),
                URLQueryItem(name: "dropoff[longitude]", value: "\(dropoffLon)")
            ]
            if let name = dropoffName {
                components?.queryItems?.append(URLQueryItem(name: "dropoff[nickname]", value: name))
            }
            return components?.url
            
        case .lyft:
            var components = URLComponents(string: "lyft://ridetype")
            components?.queryItems = [
                URLQueryItem(name: "id", value: "lyft"),
                URLQueryItem(name: "pickup[latitude]", value: "\(pickupLat)"),
                URLQueryItem(name: "pickup[longitude]", value: "\(pickupLon)"),
                URLQueryItem(name: "destination[latitude]", value: "\(dropoffLat)"),
                URLQueryItem(name: "destination[longitude]", value: "\(dropoffLon)")
            ]
            return components?.url
        }
    }
    
    /// Open the ride-share app or fallback to App Store
    @MainActor
    static func openRideShare(
        provider: Provider,
        pickup: CLLocationCoordinate2D,
        dropoff: CLLocationCoordinate2D,
        dropoffName: String? = nil
    ) {
        if let url = deepLink(
            provider: provider,
            pickupLat: pickup.latitude,
            pickupLon: pickup.longitude,
            dropoffLat: dropoff.latitude,
            dropoffLon: dropoff.longitude,
            dropoffName: dropoffName
        ), isAvailable(provider) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: provider.appStoreURL) {
            UIApplication.shared.open(fallback)
        }
    }
    
    /// Rough fare estimate based on distance (USD)
    static func estimateFare(
        provider: Provider,
        distanceKm: Double
    ) -> (low: Double, high: Double) {
        let baseFare: Double
        let perKm: Double
        
        switch provider {
        case .uber:
            baseFare = 2.50
            perKm = 1.50
        case .lyft:
            baseFare = 2.00
            perKm = 1.40
        }
        
        let estimate = baseFare + (distanceKm * perKm)
        let low = max(5.0, estimate * 0.85)
        let high = estimate * 1.35
        return (low: low, high: high)
    }
    
    static func formatFare(_ range: (low: Double, high: Double)) -> String {
        return "$\(Int(range.low))–$\(Int(range.high))"
    }
}
