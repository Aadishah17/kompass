import Foundation
import CoreLocation

enum SearchResult: Identifiable, Hashable {
    case offline(Location)
    
    var id: String {
        switch self {
        case .offline(let location):
            return location.id.uuidString
        }
    }
    
    var title: String {
        switch self {
        case .offline(let location):
            return location.name
        }
    }
    
    var subtitle: String {
        switch self {
        case .offline(let location):
            return location.description
        }
    }
}
