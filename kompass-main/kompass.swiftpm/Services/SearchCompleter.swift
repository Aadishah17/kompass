import Combine
import CoreLocation
import SwiftUI

@MainActor
class SearchCompleter: ObservableObject {
    @Published var query = ""
    @Published var completions: [SearchResult] = []
    @Published var allLocations: [Location] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        $query
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] newQuery in
                guard let self = self else { return }
                self.performOfflineSearch(query: newQuery)
            }
            .store(in: &cancellables)
    }

    private func performOfflineSearch(query: String) {
        guard !query.isEmpty else {
            self.completions = []
            return
        }

        self.completions = getOfflineResults(for: query)
    }

    private func getOfflineResults(for query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Match coordinate input (e.g., "37.33, -122.03")
        let str = query.trimmingCharacters(in: .whitespaces)
        let coordinateRegex = "^[-+]?([1-8]?\\d(\\.\\d+)?|90(\\.0+)?)\\s*,?\\s*[-+]?(180(\\.0+)?|((1[0-7]\\d)|([1-9]?\\d))(\\.\\d+)?)$"
        if str.range(of: coordinateRegex, options: .regularExpression) != nil {
            let parts = str.components(separatedBy: CharacterSet(charactersIn: ", ")).filter { !$0.isEmpty }
            if parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let loc = Location(
                    name: "Coordinate",
                    coordinate: coord,
                    description: "Lat: \(lat), Lon: \(lon)",
                    iconName: "mappin.and.ellipse",
                    address: "Custom Coordinates",
                    category: nil,
                    distance: nil
                )
                results.append(SearchResult.offline(loc))
            }
        }

        let lowerQuery = query.lowercased()
        let localLocations = allLocations + OfflineCities.all
        let filtered = localLocations.filter { loc in
            loc.name.lowercased().contains(lowerQuery)
                || loc.description.lowercased().contains(lowerQuery)
        }
        
        results.append(contentsOf: filtered.map { SearchResult.offline($0) })
        return results
    }
}
