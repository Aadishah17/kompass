// Custom subclass to distinguish the animation overlay

import MapKit

import SwiftUI

class AnimatablePolyline: MKPolyline {}
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
        mapView.userTrackingMode = .none
        mapView.showsScale = true
        mapView.showsCompass = true

        // Vector Map Configuration — MapKit uses native vector rendering (no raster tiles)
        // Filter POIs to essential categories only (avoid clutter, keep it clean)
        let poiFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .hotel, .museum,
            .park, .publicTransport, .hospital,
            .school, .university, .store, .theater
        ])
        mapView.pointOfInterestFilter = poiFilter

        // Dark muted vector style for AMOLED aesthetic
        let config = MKStandardMapConfiguration(emphasisStyle: .muted)
        config.pointOfInterestFilter = poiFilter
        config.showsTraffic = false
        mapView.preferredConfiguration = config

        // Lock map to San Francisco Downtown
        let sfCenter = CLLocationCoordinate2D(latitude: 37.79, longitude: -122.40)
        
        // Zoom constraints
        let zoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 500,   // Max zoom in (~street level)
            maxCenterCoordinateDistance: 15000   // Max zoom out (city overview)
        )
        mapView.setCameraZoomRange(zoomRange, animated: false)
        
        // Pan boundaries — user cannot scroll beyond SF
        let boundaryRegion = MKCoordinateRegion(center: sfCenter, latitudinalMeters: 12000, longitudinalMeters: 12000)
        mapView.setCameraBoundary(MKMapView.CameraBoundary(coordinateRegion: boundaryRegion), animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update Configuration (Style)
        let config: MKMapConfiguration
        switch mapStyle {
        case .standard:
            let standard = MKStandardMapConfiguration()
            standard.emphasisStyle = .muted
            if showTraffic { standard.showsTraffic = true }
            config = standard
        case .hybrid:
            let hybrid = MKHybridMapConfiguration()
            if showTraffic { hybrid.showsTraffic = true }
            // hybrid.elevationStyle = .realistic // iOS 17+
            config = hybrid
        case .imagery:
            config = MKImageryMapConfiguration()
        }

        mapView.preferredConfiguration = config

        // Update 3D Mode (Pitch)
        if is3DMode {
            if mapView.camera.pitch < 45 {
                let camera = mapView.camera
                camera.pitch = 60
                mapView.setCamera(camera, animated: true)
            }
        } else if mapView.camera.pitch > 0 {
            let camera = mapView.camera
            camera.pitch = 0
            mapView.setCamera(camera, animated: true)
        }

        // Update region
        if !isNavigating {
            let currentCenter = mapView.region.center
            let centerDiff =
                abs(currentCenter.latitude - region.center.latitude)
                + abs(currentCenter.longitude - region.center.longitude)
            let currentSpan = mapView.region.span
            let spanDiff =
                abs(currentSpan.latitudeDelta - region.span.latitudeDelta)
                + abs(currentSpan.longitudeDelta - region.span.longitudeDelta)
            if centerDiff > 0.0001 || spanDiff > 0.0001 {
                mapView.setRegion(region, animated: true)
            }
        }

        if isNavigating {
            if !context.coordinator.isTrackingConfigured {
                UIView.animate(withDuration: 1.0) {
                    mapView.setUserTrackingMode(.followWithHeading, animated: true)
                }
                context.coordinator.isTrackingConfigured = true
            }
            context.coordinator.startAnimation(mapView: mapView)
        } else {
            if context.coordinator.isTrackingConfigured {
                if mapView.userTrackingMode != .none {
                    mapView.setUserTrackingMode(.none, animated: true)
                }
                context.coordinator.isTrackingConfigured = false
            }
            context.coordinator.stopAnimation()
        }

        // Update annotations
        updateAnnotations(mapView: mapView)

        // Update polyline
        updateOverlays(mapView: mapView, context: context)
    }

    private func updateAnnotations(mapView: MKMapView) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? LocationAnnotation }
        let existingIDs = Set(existingAnnotations.map { $0.location.id })
        let newIDs = Set(locations.map { $0.id })

        let toRemove = existingAnnotations.filter { !newIDs.contains($0.location.id) }
        if !toRemove.isEmpty { mapView.removeAnnotations(toRemove) }

        let toAdd = locations.filter { !existingIDs.contains($0.id) }
        if !toAdd.isEmpty {
            mapView.addAnnotations(toAdd.map { LocationAnnotation(location: $0) })
        }

        // Selection
        if let selected = selectedLocation {
            if let annotation = mapView.annotations.first(where: {
                ($0 as? LocationAnnotation)?.location.id == selected.id
            }) {
                if !mapView.selectedAnnotations.contains(where: {
                    ($0 as? LocationAnnotation)?.location.id == selected.id
                }) {
                    mapView.selectAnnotation(annotation, animated: true)
                }
            }
        } else {
            if !mapView.selectedAnnotations.isEmpty {
                mapView.selectedAnnotations.forEach {
                    mapView.deselectAnnotation($0, animated: true)
                }
            }
        }
    }

    private func updateOverlays(mapView: MKMapView, context: Context) {
        if routeCoordinates.isEmpty {
            // Remove only polyline overlays, NOT tile overlays
            let polylineOverlays = mapView.overlays.filter { $0 is MKPolyline }
            mapView.removeOverlays(polylineOverlays)
            mapView.removeAnnotations(mapView.annotations.filter { $0 is MKPointAnnotation })
            return
        }

        if context.coordinator.routeHasChanged(comparedTo: routeCoordinates) {
            context.coordinator.lastRouteCoordinates = routeCoordinates

            // Remove only polyline overlays, NOT tile overlays
            let polylineOverlays = mapView.overlays.filter { $0 is MKPolyline }
            mapView.removeOverlays(polylineOverlays)

            // Add Base Track
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)

            // Add Animation Layer
            let animPolyline = AnimatablePolyline(
                coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(animPolyline, level: .aboveRoads)

            // Markers
            mapView.removeAnnotations(mapView.annotations.filter { $0 is MKPointAnnotation })
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

            // Zoom
            let rect = polyline.boundingMapRect
            mapView.setVisibleMapRect(
                rect, edgePadding: UIEdgeInsets(top: 100, left: 60, bottom: 300, right: 60),
                animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var lastRouteCoordinates: [CLLocationCoordinate2D] = []
        var isTrackingConfigured = false
        private var animationTimer: Timer?
        private var animePhase: Double = 0
        private var activeAnimRenderers: [MKPolylineRenderer] = []

        init(parent: MapView) {
            self.parent = parent
        }

        func routeHasChanged(comparedTo coordinates: [CLLocationCoordinate2D]) -> Bool {
            guard lastRouteCoordinates.count == coordinates.count else { return true }

            return zip(lastRouteCoordinates, coordinates).contains { lhs, rhs in
                abs(lhs.latitude - rhs.latitude) > 0.000001
                    || abs(lhs.longitude - rhs.longitude) > 0.000001
            }
        }

        func startAnimation(mapView: MKMapView) {
            guard animationTimer == nil else { return }
            animePhase = 0

            // Re-fetch renderers for safety
            activeAnimRenderers.removeAll()
            for overlay in mapView.overlays {
                if overlay is AnimatablePolyline,
                    let renderer = mapView.renderer(for: overlay) as? MKPolylineRenderer
                {
                    activeAnimRenderers.append(renderer)
                }
            }

            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) {
                [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.animePhase += 0.02

                    // Loading Bar Chase Effect
                    // Use truncated remainder to cycle 0 -> 1
                    let progress = self.animePhase.truncatingRemainder(dividingBy: 1.0)

                    for renderer in self.activeAnimRenderers {
                        let totalLen =
                            renderer.polyline.boundingMapRect.size.width
                            + renderer.polyline.boundingMapRect.size.height
                        // Length tuning: MapRect units are large, but relative proportions work
                        // We want a visible dash. Let's make it 30% of the total length.

                        // Note: MKPolylineRenderer geometry is in map points.
                        // We'll use a simpler heuristic for dash pattern.
                        // If we set pattern to [len, gap], and phase, it repeats.
                        // We want ONE segment moving.
                        // So pattern should be [segmentLength, hugeGap].

                        let segmentLength = totalLen * 0.3
                        let gapLength = totalLen * 2.0  // Make gap large enough so we don't see a second one

                        renderer.lineDashPattern = [
                            NSNumber(value: Double(segmentLength)),
                            NSNumber(value: Double(gapLength)),
                        ]

                        // Move the phase backwards to make dash move forwards?
                        // Phase is the offset into the pattern where drawing starts.
                        // If phase = 0, dash starts at 0.
                        // If phase = segmentLength, dash starts at -segmentLength (invisible).
                        // We want dash to travel from 0 to totalLen.
                        // Phase should go from segmentLength down to -totalLen ?

                        // Actually: phase P means "start drawing at index P of the pattern".
                        // If pattern is [10, 100].
                        // Phase 0: Dash[0-10], Gap[10-110].
                        // Phase 5: Dash[5-10] (first 5 cut off), Gap...
                        // Subtracting from phase moves pattern RIGHT.
                        // Adding to phase moves pattern LEFT.

                        // We want to move pattern ALONG the line (forward).
                        // So we subtract.

                        // We start with dash fully hidden "behind" start, or just entering?
                        // Let's start with phase = segmentLength (hidden left) and decrease?

                        // Simpler: Just cycle phase negatively.
                        renderer.lineDashPhase = CGFloat(
                            totalLen * 2.0 - (totalLen * 3.0 * progress))

                        renderer.setNeedsDisplay()
                    }
                }
            }
        }

        func stopAnimation() {
            animationTimer?.invalidate()
            animationTimer = nil
            activeAnimRenderers.removeAll()
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is MKPointAnnotation {
                let identifier = "RouteMarker"
                var view =
                    mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(
                        annotation: annotation, reuseIdentifier: identifier)
                }
                view?.annotation = annotation
                if let title = annotation.title, title == "Start" {
                    view?.markerTintColor = UIColor(white: 0.2, alpha: 0.9)
                    view?.glyphImage = UIImage(systemName: "location.fill")
                    view?.glyphTintColor = .white
                } else {
                    view?.markerTintColor = UIColor(
                        red: 39 / 255, green: 110 / 255, blue: 241 / 255, alpha: 0.9)
                    view?.glyphImage = UIImage(systemName: "mappin.circle.fill")
                    view?.glyphTintColor = .white

                    // Add breathing animation to Destination
                    if let title = annotation.title, title == "End" {
                        // Remove existing pulse layers if any to avoid stacking
                        view?.layer.sublayers?.filter { $0.name == "PulseLayer" }.forEach {
                            $0.removeFromSuperlayer()
                        }

                        let pulseLayer = CALayer()
                        pulseLayer.name = "PulseLayer"
                        pulseLayer.backgroundColor =
                            UIColor(red: 39 / 255, green: 110 / 255, blue: 241 / 255, alpha: 0.5)
                            .cgColor
                        pulseLayer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
                        pulseLayer.position = CGPoint(x: 20, y: 20)  // Centered in a standard marker?
                        // Marker view bounds might be different.
                        // MKMarkerAnnotationView is usually around 40x40 or so but has a shadow and balloon shape.
                        // Let's position it at the anchor.

                        // Actually, standard UIView animation on the view itself is safer for "breathing" size/opacity.
                        let animation = CABasicAnimation(keyPath: "transform.scale")
                        animation.fromValue = 1.0
                        animation.toValue = 1.2
                        animation.duration = 1.0
                        animation.autoreverses = true
                        animation.repeatCount = .infinity
                        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                        view?.layer.add(animation, forKey: "breathing")
                    }
                }
                return view
            }

            guard let locationAnnotation = annotation as? LocationAnnotation else { return nil }
            let identifier = "LocationAnnotation"
            var view =
                mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            }
            view?.annotation = annotation

            let location = locationAnnotation.location
            if let category = location.category {
                view?.markerTintColor = UIColor(category.color)
                view?.glyphImage = UIImage(systemName: category.icon)
            } else {
                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: location.iconName)
            }
            view?.displayPriority = .defaultHigh
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let locationAnnotation = view.annotation as? LocationAnnotation {
                parent.selectedLocation = locationAnnotation.location
            }
        }

        func mapView(
            _ mapView: MKMapView, annotationView view: MKAnnotationView,
            calloutAccessoryControlTapped control: UIControl
        ) {
            if let locationAnnotation = view.annotation as? LocationAnnotation {
                parent.selectedLocation = locationAnnotation.location
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let animPoly = overlay as? AnimatablePolyline {
                // Animation Layer: Bright White "Loading Bar"
                let renderer = MKPolylineRenderer(polyline: animPoly)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.85)  // Softer white
                renderer.lineWidth = 6
                renderer.lineCap = .round
                renderer.lineJoin = .round
                activeAnimRenderers.append(renderer)
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                // Base Track: Dark Gray (AMOLED style) but slightly elevated
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(white: 0.25, alpha: 0.6)  // Glassy dark trace
                renderer.lineWidth = 6
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
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
