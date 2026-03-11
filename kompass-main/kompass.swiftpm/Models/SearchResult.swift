import Foundation
import CoreLocation
import MapKit

enum SearchResult: Hashable, Identifiable {
    case offline(Location)
    case online(MKLocalSearchCompletion)
    
    var id: String {
        switch self {
        case .offline(let location):
            return location.id.uuidString
        case .online(let completion):
            // Fallback securely since MKLocalSearchCompletion doesn't have an ID
            return completion.title + completion.subtitle + completion.description
        }
    }
    
    var title: String {
        switch self {
        case .offline(let location):
            return location.name
        case .online(let completion):
            return completion.title
        }
    }
    
    var subtitle: String {
        switch self {
        case .offline(let location):
            return location.description
        case .online(let completion):
            return completion.subtitle
        }
    }
}
