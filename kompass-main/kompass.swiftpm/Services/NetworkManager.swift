import Foundation
import Network
import Combine

/// A centralized manager to monitor network connectivity and perform internet-dependent operations.
@MainActor
final class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                self.isConnected = path.status == .satisfied
                self.connectionType = self.getConnectionType(from: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.status != .satisfied {
            return .none
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    // MARK: - Generic Networking Helper
    
    /// Performs a generic network request with JSON decoding.
    func fetch<T: Decodable>(url: URL) async throws -> T {
        guard isConnected else {
            throw NetworkError.noConnection
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
        } catch {
            throw NetworkError.decodingFailed
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case noConnection
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection is available."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverError(let statusCode):
            return "The server returned an error (Status code: \(statusCode))."
        case .decodingFailed:
            return "Failed to parse the server data."
        }
    }
}
