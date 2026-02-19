import Foundation
import CoreLocation
import MapKit
import SwiftUI

struct Location: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let iconName: String
    
    // Enhanced fields
    var address: String?
    var category: PlaceCategory?
    var phoneNumber: String?
    var rating: Double?
    var isOpen: Bool?
    var distance: CLLocationDistance?
    var url: URL?
    
    /// Create a Location from an MKMapItem with real data
    static func from(mapItem: MKMapItem, userLocation: CLLocation? = nil) -> Location {
        let placemark = mapItem.placemark
        
        // Build a human-readable address
        var addressParts: [String] = []
        if let street = placemark.thoroughfare { addressParts.append(street) }
        if let number = placemark.subThoroughfare { addressParts.insert(number, at: 0) }
        if let city = placemark.locality { addressParts.append(city) }
        if let state = placemark.administrativeArea { addressParts.append(state) }
        let address = addressParts.isEmpty ? (placemark.title ?? "") : addressParts.joined(separator: ", ")
        
        // Calculate distance from user
        var dist: CLLocationDistance? = nil
        if let userLoc = userLocation {
            dist = userLoc.distance(from: CLLocation(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude))
        }
        
        // Detect category from mapItem
        let category = detectCategory(from: mapItem)
        
        return Location(
            name: mapItem.name ?? "Unknown Place",
            coordinate: placemark.coordinate,
            description: address,
            iconName: category?.icon ?? "mappin.circle.fill",
            address: address,
            category: category,
            phoneNumber: mapItem.phoneNumber,
            rating: nil,
            isOpen: mapItem.isCurrentLocation ? true : nil,
            distance: dist,
            url: mapItem.url
        )
    }
    
    private static func detectCategory(from mapItem: MKMapItem) -> PlaceCategory? {
        if let categories = mapItem.pointOfInterestCategory {
            switch categories {
            case .restaurant, .bakery, .brewery, .foodMarket:
                return .restaurant
            case .cafe:
                return .coffee
            case .gasStation, .evCharger:
                return .gasStation
            case .hotel:
                return .hotel
            case .parking:
                return .parking
            case .pharmacy:
                return .pharmacy
            case .hospital:
                return .hospital
            case .park, .nationalPark:
                return .park
            case .atm, .bank:
                return .atm
            default:
                return nil
            }
        }
        return nil
    }
    
    var categoryColor: Color {
        category?.color ?? .white
    }
    
    var formattedDistance: String? {
        guard let dist = distance else { return nil }
        if dist < 1000 {
            return "\(Int(dist))m"
        } else {
            return String(format: "%.1f km", dist / 1000)
        }
    }
}

extension Location: Equatable, Hashable {
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Location {
    static let sampleData: [Location] = [
        Location(
            name: "Eiffel Tower",
            coordinate: CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945),
            description: "Champ de Mars, Paris, France",
            iconName: "building.columns",
            category: nil
        ),
        Location(
            name: "Statue of Liberty",
            coordinate: CLLocationCoordinate2D(latitude: 40.6892, longitude: -74.0445),
            description: "Liberty Island, New York, NY",
            iconName: "figure.stand",
            category: nil
        ),
        Location(
            name: "Sydney Opera House",
            coordinate: CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153),
            description: "Bennelong Point, Sydney, Australia",
            iconName: "music.note.house",
            category: nil
        ),
        Location(
            name: "Taj Mahal",
            coordinate: CLLocationCoordinate2D(latitude: 27.1751, longitude: 78.0421),
            description: "Dharmapuri, Forest Colony, Agra, India",
            iconName: "building",
            category: nil
        ),
        Location(
            name: "Machu Picchu",
            coordinate: CLLocationCoordinate2D(latitude: -13.1631, longitude: -72.5450),
            description: "Cusco Region, Peru",
            iconName: "mountain.2",
            category: nil
        )
    ]
}
