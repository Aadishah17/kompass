import SwiftUI
import MapKit

enum PlaceCategory: String, CaseIterable, Identifiable {
    case restaurant = "Restaurants"
    case coffee = "Coffee"
    case gasStation = "Gas"
    case grocery = "Groceries"
    case hotel = "Hotels"
    case parking = "Parking"
    case pharmacy = "Pharmacy"
    case atm = "ATMs"
    case hospital = "Hospital"
    case park = "Parks"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .coffee: return "cup.and.saucer.fill"
        case .gasStation: return "fuelpump.fill"
        case .grocery: return "cart.fill"
        case .hotel: return "bed.double.fill"
        case .parking: return "p.circle.fill"
        case .pharmacy: return "cross.case.fill"
        case .atm: return "banknote.fill"
        case .hospital: return "cross.fill"
        case .park: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .restaurant: return .white
        case .coffee: return .white
        case .gasStation: return .white
        case .grocery: return .white
        case .hotel: return .white
        case .parking: return .white
        case .pharmacy: return .white
        case .atm: return .white
        case .hospital: return .white
        case .park: return .white
        }
    }
    
    var searchQuery: String {
        switch self {
        case .restaurant: return "restaurant"
        case .coffee: return "coffee"
        case .gasStation: return "gas station"
        case .grocery: return "grocery"
        case .hotel: return "hotel"
        case .parking: return "parking"
        case .pharmacy: return "pharmacy"
        case .atm: return "ATM"
        case .hospital: return "hospital"
        case .park: return "park"
        }
    }
}
