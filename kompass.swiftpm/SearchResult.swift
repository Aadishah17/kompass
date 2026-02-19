
import Foundation
import MapKit

enum SearchResult: Identifiable, Hashable {
    case online(MKLocalSearchCompletion)
    case offline(Location)
    
    var id: String {
        switch self {
        case .online(let completion):
            return completion.title + completion.subtitle
        case .offline(let location):
            return location.id.uuidString
        }
    }
    
    var title: String {
        switch self {
        case .online(let completion):
            return completion.title
        case .offline(let location):
            return location.name
        }
    }
    
    var subtitle: String {
        switch self {
        case .online(let completion):
            return completion.subtitle
        case .offline(let location):
            return location.description
        }
    }
}
