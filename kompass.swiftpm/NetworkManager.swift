import Foundation
import Network
import Combine

@MainActor
class NetworkManager: ObservableObject {
    @Published var isConnected = true
    @Published var isSimulatedOffline = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    var isEffectiveOffline: Bool {
        return !isConnected || isSimulatedOffline
    }
}
