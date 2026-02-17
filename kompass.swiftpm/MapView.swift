import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var locations: [Location]
    @Binding var selectedLocation: Location?
    @Binding var routeCoordinates: [CLLocationCoordinate2D]
    @Binding var isNavigating: Bool
    @Binding var mapStyle: MapStyle
    @Binding var is3DMode: Bool
    @Binding var showTraffic: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsScale = true
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .includingAll
        
        updateMapConfiguration(mapView)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update Configuration (Style)
        updateMapConfiguration(mapView)
        
        // Update 3D Mode (Pitch)
        if is3DMode {
            mapView.camera.pitch = 60
        } else if mapView.camera.pitch > 0 {
            mapView.camera.pitch = 0
        }
        
        // Update region
        if !isNavigating {
            let currentCenter = mapView.region.center
            let centerDiff = abs(currentCenter.latitude - region.center.latitude) + abs(currentCenter.longitude - region.center.longitude)
            let currentSpan = mapView.region.span
            let spanDiff = abs(currentSpan.latitudeDelta - region.span.latitudeDelta) + abs(currentSpan.longitudeDelta - region.span.longitudeDelta)
            if centerDiff > 0.0001 || spanDiff > 0.0001 {
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Update tracking mode
        if isNavigating {
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
        } else {
            if mapView.userTrackingMode != .none {
                mapView.setUserTrackingMode(.none, animated: true)
            }
        }

        // Update annotations - rebuild only when needed
        let existingAnnotations = mapView.annotations.compactMap { $0 as? LocationAnnotation }
        let existingIDs = Set(existingAnnotations.map { $0.location.id })
        let newIDs = Set(locations.map { $0.id })
        
        // Remove stale
        let toRemove = existingAnnotations.filter { !newIDs.contains($0.location.id) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }
        
        // Add new
        let toAdd = locations.filter { !existingIDs.contains($0.id) }
        if !toAdd.isEmpty {
            mapView.addAnnotations(toAdd.map { LocationAnnotation(location: $0) })
        }
        
        // Update selection
        if let selected = selectedLocation {
             if let annotation = mapView.annotations.first(where: { ($0 as? LocationAnnotation)?.location.id == selected.id }) {
                 if !mapView.selectedAnnotations.contains(where: { ($0 as? LocationAnnotation)?.location.id == selected.id }) {
                     mapView.selectAnnotation(annotation, animated: true)
                 }
             }
        } else {
             if !mapView.selectedAnnotations.isEmpty {
                 mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: true) }
             }
        }

        // Update polyline
        mapView.removeOverlays(mapView.overlays)
        if !routeCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
            
            // Add start/end markers
            if let first = routeCoordinates.first {
                let startAnnotation = MKPointAnnotation()
                startAnnotation.coordinate = first
                startAnnotation.title = "Start"
                mapView.addAnnotation(startAnnotation)
            }
            if let last = routeCoordinates.last, routeCoordinates.count > 1 {
                let endAnnotation = MKPointAnnotation()
                endAnnotation.coordinate = last
                endAnnotation.title = "End"
                mapView.addAnnotation(endAnnotation)
            }
             
            // Zoom to fit route
            let rect = polyline.boundingMapRect
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 100, left: 60, bottom: 300, right: 60), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func updateMapConfiguration(_ mapView: MKMapView) {
        switch mapStyle {
        case .standard:
            let config = MKStandardMapConfiguration(elevationStyle: .realistic)
            config.pointOfInterestFilter = .includingAll
            config.showsTraffic = showTraffic
            mapView.preferredConfiguration = config
        case .hybrid:
            let config = MKHybridMapConfiguration(elevationStyle: .realistic)
            config.pointOfInterestFilter = .includingAll
            config.showsTraffic = showTraffic
            mapView.preferredConfiguration = config
        case .imagery:
            let config = MKImageryMapConfiguration(elevationStyle: .realistic)
            mapView.preferredConfiguration = config
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // User location - default
            if annotation is MKUserLocation { return nil }
            
            // Start/End route markers
            if let pointAnnotation = annotation as? MKPointAnnotation {
                let identifier = "RouteMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = annotation
                }
                if pointAnnotation.title == "Start" {
                    view?.markerTintColor = .systemGreen
                    view?.glyphImage = UIImage(systemName: "figure.walk")
                } else {
                    view?.markerTintColor = .systemRed
                    view?.glyphImage = UIImage(systemName: "flag.fill")
                }
                view?.displayPriority = .required
                return view
            }
            
            // Location annotations with category colors
            guard let locationAnnotation = annotation as? LocationAnnotation else { return nil }
            
            let identifier = "LocationAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                view?.animatesWhenAdded = true
            } else {
                view?.annotation = annotation
            }
            
            // Color by category
            let location = locationAnnotation.location
            if let category = location.category {
                view?.markerTintColor = UIColor(category.color)
                view?.glyphImage = UIImage(systemName: category.icon)
            } else {
                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: location.iconName)
            }
            
            view?.displayPriority = .defaultHigh
            view?.clusteringIdentifier = "places"
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
             if let locationAnnotation = view.annotation as? LocationAnnotation {
                 parent.selectedLocation = locationAnnotation.location
             }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
             // Don't clear selection - let the UI handle it
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let locationAnnotation = view.annotation as? LocationAnnotation {
                parent.selectedLocation = locationAnnotation.location
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 6
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Sync region back to SwiftUI
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

class LocationAnnotation: NSObject, MKAnnotation {
    let location: Location
    var coordinate: CLLocationCoordinate2D { location.coordinate }
    var title: String? { location.name }
    var subtitle: String? { location.address ?? location.description }

    init(location: Location) {
        self.location = location
    }
}
