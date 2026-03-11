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
                self?.completions = newResults.map { SearchResult.online($0) }
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
                    self.completer.queryFragment = newQuery
                }
            }
            .store(in: &cancellables)
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
