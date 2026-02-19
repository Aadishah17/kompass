import SwiftUI
import MapKit
import Combine

class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = ""

    @Published var completions: [SearchResult] = []
    
    @Published var isOffline = false
    @Published var allLocations: [Location] = [] // Injected from ContentView
    
    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        completer.delegate = self
        
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newQuery in
                guard let self = self else { return }
                if self.isOffline {
                    self.performOfflineSearch(query: newQuery)
                } else {
                    self.completer.queryFragment = newQuery
                }
            }
            .store(in: &cancellables)
            
        // React to offline mode changes
        $isOffline
            .sink { [weak self] offline in
                guard let self = self else { return }
                if offline {
                    self.performOfflineSearch(query: self.query)
                } else {
                    self.completer.queryFragment = self.query
                }
            }
            .store(in: &cancellables)
    }
    
    func updateRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }
    
    private func performOfflineSearch(query: String) {
        guard !query.isEmpty else {
            self.completions = []
            return
        }
        
        let lowerQuery = query.lowercased()
        let filtered = allLocations.filter { loc in
            loc.name.lowercased().contains(lowerQuery) ||
            loc.description.lowercased().contains(lowerQuery)
        }
        
        self.completions = filtered.map { .offline($0) }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        if !isOffline {
            self.completions = completer.results.map { .online($0) }
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer failed: \(error.localizedDescription)")
    }
}

