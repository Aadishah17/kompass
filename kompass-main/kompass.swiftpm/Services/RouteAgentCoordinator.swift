import Foundation
import CoreLocation
import MapKit

// Shared data structure returned by any agent
struct RouteResult {
    let coordinates: [CLLocationCoordinate2D]
    let steps: [SimpleRouteStep] // Custom struct from ContentView.swift
    let travelTime: TimeInterval
    let distance: Double
}

protocol RouteAgent {
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, mode: MKDirectionsTransportType) async throws -> RouteResult
}

struct PrimaryAgent: RouteAgent {
    // Online Agent: Uses Apple Maps MKDirections for guided routes
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, mode: MKDirectionsTransportType) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = mode
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw NSError(domain: "PrimaryAgent", code: 404, userInfo: [NSLocalizedDescriptionKey: "No routes found."])
        }
        
        // Extract Coordinates
        let pointCount = route.polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        
        // Extract Turn-by-Turn Instructions
        let steps = route.steps.map { step in
            SimpleRouteStep(instructions: step.instructions.isEmpty ? "Continue on route" : step.instructions)
        }
        
        return RouteResult(
            coordinates: coords,
            steps: steps,
            travelTime: route.expectedTravelTime,
            distance: route.distance
        )
    }
}

struct SecondaryAgent: RouteAgent {
    // Offline Agent: Calculates direct vector (crow-flies) route using math without the internet
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, mode: MKDirectionsTransportType) async throws -> RouteResult {
        let loc1 = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let loc2 = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        let dist = loc1.distance(from: loc2)
        
        let speed: Double
        switch mode {
        case .automobile: speed = 13.8  // ~50 km/h
        case .walking: speed = 1.4  // ~5 km/h
        case .transit: speed = 8.3  // ~30 km/h
        default: speed = 10.0
        }
        
        let time = dist / speed
        
        // Just provide A to B points
        let coords = [start, destination]
        let steps = [SimpleRouteStep(instructions: "Go directly to destination")]
        
        return RouteResult(
            coordinates: coords,
            steps: steps,
            travelTime: time,
            distance: dist
        )
    }
}

struct RouteAgentCoordinator {
    let primaryAgent = PrimaryAgent()
    let secondaryAgent = SecondaryAgent()
    
    func getBestRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: MKDirectionsTransportType) async -> RouteResult {
        let localPrimaryAgent = self.primaryAgent
        do {
                // Wait up to 10 seconds for the primary online agent to respond
            return try await withThrowingTaskGroup(of: RouteResult.self) { group in
                group.addTask {
                    let result = try await localPrimaryAgent.calculateRoute(from: start, to: end, mode: transportType)
                    return result
                }
                
                // Add a timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    throw NSError(domain: "Timeout", code: 408, userInfo: nil)
                }
                
                guard let firstResult = try await group.next() else {
                    throw NSError(domain: "EmptyGroup", code: 500, userInfo: nil)
                }
                
                group.cancelAll()
                return firstResult
            }
        } catch {
            print("Primary Agent Timeout/Error. Failing over to Secondary Agent Offline Vector Route.")
            // Immediately execute the fallback Secondary Agent
            return try! await secondaryAgent.calculateRoute(from: start, to: end, mode: transportType)
        }
    }
}
