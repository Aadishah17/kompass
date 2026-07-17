import Combine
import CoreLocation
@preconcurrency import MapKit
// Delegate Helper to handle non-isolated MKLocalSearchCompleter callbacks safely
class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onUpdate: (([MKLocalSearchCompletion]) -> Void)?
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate?(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search failed: \(error.localizedDescription)")
    }
}

@MainActor
class SearchCompleter: ObservableObject {
    @Published var query = ""
    @Published var completions: [SearchResult] = []
    @Published var allLocations: [Location] = []

    private var completer = MKLocalSearchCompleter()
    private var delegateHelper = SearchCompleterDelegate()
    private var cancellables = Set<AnyCancellable>()

    init() {
        completer.delegate = delegateHelper
        completer.resultTypes = [.address, .pointOfInterest]
        
        delegateHelper.onUpdate = { [weak self] newResults in
            Task { @MainActor in
                guard let self = self else { return }
                let onlineResults = newResults.map { SearchResult.online($0) }
                
                // Retain offline results, placing them at the top, and append online results
                let offlineResults = self.completions.filter {
                    switch $0 {
                    case .offline: return true
                    case .online: return false
                    }
                }
                self.completions = offlineResults + onlineResults
            }
        }

        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newQuery in
                guard let self = self else { return }
                guard !newQuery.isEmpty else {
                    self.completions = []
                    return
                }
                
                // Allow coordinate search fallback
                if self.isCoordinate(newQuery) {
                    self.performCoordinateSearch(query: newQuery)
                } else {
                    // Populate offline results instantly
                    self.performOfflineSearch(query: newQuery)
                    
                    // Fallback to online local search completion
                    self.completer.queryFragment = newQuery
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Offline Search Helpers
    
    private func performOfflineSearch(query: String) {
        let trimmedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        // Combine predefined POIs and active dynamic locations
        let allSearchable = OfflineCities.all + allLocations

        // Filter based on query match (name, description, or address)
        let filtered = allSearchable.filter { location in
            location.name.lowercased().contains(trimmedQuery) ||
            location.description.lowercased().contains(trimmedQuery) ||
            (location.address?.lowercased().contains(trimmedQuery) ?? false)
        }

        // De-duplicate results
        var uniqueFiltered: [Location] = []
        for loc in filtered {
            let isDuplicate = uniqueFiltered.contains { existing in
                existing.name == loc.name &&
                abs(existing.coordinate.latitude - loc.coordinate.latitude) < 0.00001 &&
                abs(existing.coordinate.longitude - loc.coordinate.longitude) < 0.00001
            }
            if !isDuplicate {
                uniqueFiltered.append(loc)
            }
        }

        // Map to SearchResult.offline
        self.completions = uniqueFiltered.map { SearchResult.offline($0) }
    }
    
    // MARK: - Coordinate Search Helpers
    
    private func isCoordinate(_ query: String) -> Bool {
        let str = query.trimmingCharacters(in: .whitespaces)
        let coordinateRegex = "^[-+]?([1-8]?\\d(\\.\\d+)?|90(\\.0+)?)\\s*,?\\s*[-+]?(180(\\.0+)?|((1[0-7]\\d)|([1-9]?\\d))(\\.\\d+)?)$"
        return str.range(of: coordinateRegex, options: .regularExpression) != nil
    }
    
    private func performCoordinateSearch(query: String) {
        let str = query.trimmingCharacters(in: .whitespaces)
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
            self.completions = [SearchResult.offline(loc)]
        }
    }
}
