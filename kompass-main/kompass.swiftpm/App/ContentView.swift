import MapKit

import SwiftUI

// TransportMode kept for backward compatibility, primary modes now in ExtendedTransportMode

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude && lhs.center.longitude == rhs.center.longitude
            && lhs.span.latitudeDelta == rhs.span.latitudeDelta
            && lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}
struct SimpleRouteStep: Identifiable, Hashable {
    let id = UUID()
    let instructions: String
}
struct RouteInfo {
    let expectedTravelTime: TimeInterval
    let distance: CLLocationDistance
}
enum MapStyle: String, CaseIterable, Identifiable {
    case standard, hybrid, imagery
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid: return "Hybrid"
        case .imagery: return "Satellite"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "globe.americas"
        case .imagery: return "globe"
        }
    }
}
enum TransportMode: String, CaseIterable, Identifiable {
    case driving = "Driving"
    case walking = "Walking"
    case transit = "Transit"

    var id: String { rawValue }

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }

    var icon: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }
}
@MainActor
struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var hasSetRegion = false
    @State private var selectedLocation: Location?
    @State private var routeSteps: [SimpleRouteStep] = []
    @State private var showDirections = false
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var startLocation: Location?
    @State private var endLocation: Location?
    @State private var routeInfo: RouteInfo?
    @State private var mapStyle: MapStyle = .standard
    @State private var is3DMode = false
    @State private var transportType: TransportMode = .driving

    // Multi-modal transport
    @State private var extendedMode: ExtendedTransportMode = .drive
    @State private var routeOptions: [RouteOption] = []
    @State private var isCalculatingRoutes = false
    @State private var transitSegments: [TransitSegment] = []
    @State private var showTransitDetail = false
    @State private var showTraffic = true

    // Search
    @StateObject private var toCompleter = SearchCompleter()
    @State private var toText = ""
    @State private var toResults: [SearchResult] = []
    @State private var fromText = ""
    @State private var activeField: ActiveField? = nil

    // Bottom Sheet
    @State private var isBottomSheetOpen = true

    // Compass & Location
    @StateObject private var locationManager = LocationManager()
    @State private var showCompass = false
    private let liveActivityManager = NavigationLiveActivityManager.shared

    // Network
    // Removed NetworkManager for true offline mode

    // Navigation
    @State private var isNavigating = false
    @State private var isRoutePlanning = false
    @State private var currentStepIndex = 0
    @State private var currentRouteCoordinateIndex = 0
    @State private var remainingDistanceMeters: CLLocationDistance = 0
    @State private var remainingTravelTime: TimeInterval = 0

    // POI
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var nearbyPlaces: [Location] = []
    @State private var isSearchingNearby = false

    // Favorites
    @AppStorage("savedPlaceNames") private var savedPlaceNamesJSON: String = "[]"
    @State private var savedPlaces: [Location] = []

    // Recents
    @State private var recentSearches: [Location] = []

    // Alerts
    @State private var showOfflineAlert = false

    enum ActiveField {
        case from, to
    }

    private var currentInstructionText: String {
        guard routeSteps.indices.contains(currentStepIndex) else { return "Continue on route" }

        let instruction = routeSteps[currentStepIndex].instructions.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return instruction.isEmpty ? "Continue on route" : instruction
    }

    private var nextInstructionText: String? {
        let nextIndex = currentStepIndex + 1
        guard routeSteps.indices.contains(nextIndex) else { return nil }

        let instruction = routeSteps[nextIndex].instructions.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return instruction.isEmpty ? nil : instruction
    }

    private var destinationDisplayName: String {
        endLocation?.name ?? "Destination"
    }

    private var destinationDetailText: String {
        if let address = endLocation?.address?.trimmingCharacters(in: .whitespacesAndNewlines),
            !address.isEmpty,
            address != destinationDisplayName
        {
            return address
        }

        if let description = endLocation?.description.trimmingCharacters(in: .whitespacesAndNewlines),
            !description.isEmpty,
            description != destinationDisplayName
        {
            return description
        }

        return "Offline guidance with richer trip detail"
    }

    private var navigationStatusText: String {
        locationManager.isSimulating ? "Preview" : "Live"
    }

    private var arrivalTimeText: String {
        let remaining = max(displayedRemainingTravelTime, 0)
        guard remaining > 0 else { return "Now" }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date().addingTimeInterval(remaining))
    }

    private var progressPercentText: String {
        "\(Int((navigationProgress * 100).rounded()))%"
    }

    private var remainingManeuverCount: Int {
        max(routeSteps.count - currentStepIndex - 1, 0)
    }

    private var remainingManeuverText: String {
        switch remainingManeuverCount {
        case 0:
            return "Final maneuver"
        case 1:
            return "1 maneuver left"
        default:
            return "\(remainingManeuverCount) maneuvers left"
        }
    }

    private var remainingCheckpointCount: Int {
        guard routeCoordinates.count > 1 else {
            return max(routeSteps.count - currentStepIndex - 1, 0)
        }

        return max(routeCoordinates.count - currentRouteCoordinateIndex - 1, 0)
    }

    private var remainingCheckpointText: String {
        switch remainingCheckpointCount {
        case 0:
            return "Final segment"
        case 1:
            return "1 checkpoint left"
        default:
            return "\(remainingCheckpointCount) checkpoints left"
        }
    }

    private var navigationProgress: Double {
        let rawProgress: Double

        guard routeCoordinates.count > 1 else {
            guard routeSteps.count > 1 else { return 0 }
            rawProgress = Double(currentStepIndex) / Double(routeSteps.count - 1)
            return min(max(rawProgress, 0), 1)
        }

        rawProgress = Double(currentRouteCoordinateIndex) / Double(routeCoordinates.count - 1)
        return min(max(rawProgress, 0), 1)
    }

    private var displayedRemainingDistance: CLLocationDistance {
        isNavigating ? remainingDistanceMeters : (routeInfo?.distance ?? 0)
    }

    private var displayedRemainingTravelTime: TimeInterval {
        isNavigating ? remainingTravelTime : (routeInfo?.expectedTravelTime ?? 0)
    }

    private var navigationLiveActivityState: NavigationAttributes.ContentState {
        NavigationAttributes.ContentState(
            currentInstruction: currentInstructionText,
            nextInstruction: nextInstructionText,
            summaryText: remainingCheckpointText,
            arrivalTimeText: arrivalTimeText,
            statusText: navigationStatusText,
            etaSeconds: max(displayedRemainingTravelTime, 0),
            distanceMeters: max(displayedRemainingDistance, 0),
            progressValue: navigationProgress,
            stepIndex: currentStepIndex,
            totalSteps: max(routeSteps.count, 1)
        )
    }

    var body: some View {
        ZStack {
            // MARK: - Map
            MapView(
                region: $region,
                locations: allLocations,
                selectedLocation: $selectedLocation,
                routeCoordinates: $routeCoordinates,
                isNavigating: $isNavigating,
                mapStyle: $mapStyle,
                is3DMode: $is3DMode,
                showTraffic: $showTraffic
            )
            .edgesIgnoringSafeArea(.all)

            // MARK: - Top Bar
            VStack(spacing: 0) {
                if !isNavigating {
                    if isRoutePlanning {
                        routePlanningBar
                    } else {
                        searchBar
                    }
                }

                Spacer()
            }

            // MARK: - Right Side Controls
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    mapStyleButton
                    locationButton
                    zoomControls
                }
                .padding(.trailing, 12)
                .padding(.bottom, isBottomSheetOpen ? 160 : 100)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // MARK: - Bottom Sheet (hidden during navigation to avoid overlap with navigationHeader)
            if !isNavigating {
                BottomSheetView(
                    isOpen: $isBottomSheetOpen,
                    maxHeight: UIScreen.main.bounds.height * 0.7,
                    minHeight: 80
                ) {
                    bottomSheetContent
                }
            }

            // MARK: - Navigation Header
            if isNavigating && !routeSteps.isEmpty {
                navigationHeader
            }

            // Dynamic Island is handled by the real ActivityKit Live Activity
            // (see LiveActivityWidget.swift and NavigationLiveActivityManager.swift)

            // MARK: - Compass FAB (during navigation)
            if isNavigating && !showCompass {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showCompass = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.10))
                                    .frame(width: 52, height: 52)
                                    .overlay(Circle().stroke(Color(white: 0.22), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                                Image(systemName: "safari")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
            }

            // MARK: - Full-Screen Compass Overlay
            if showCompass {
                compassOverlay
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDirections) {
            directionsSheet
        }
        .onReceive(locationManager.$lastLocation) { location in
            handleLocationUpdate(location)
        }
        .onChange(of: toText) { _, newValue in
            toCompleter.query = newValue
            toCompleter.allLocations = allLocations
        }
        .onChange(of: extendedMode) { _, newMode in
            handleModeChange(newMode)
        }
        .onChange(of: currentStepIndex) { _, _ in
            updateNavigationActivity()
        }
        .onChange(of: remainingDistanceMeters) { _, _ in
            updateNavigationActivity()
        }
        .onChange(of: remainingTravelTime) { _, _ in
            updateNavigationActivity()
        }
        .onReceive(toCompleter.$completions) { completions in
            toResults = completions
        }
        .onDisappear {
            Task {
                await liveActivityManager.end()
            }
        }
        .alert("True Offline Mode", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "This app runs completely offline. Your map, compass, GPS location, and routing use satellite tracking and local data."
            )
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(white: 0.5))
                    .font(.system(size: 16, weight: .medium))

                TextField("Search places...", text: $toText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .onTapGesture {
                        activeField = .to
                        isBottomSheetOpen = true
                    }

                if !toText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            toText = ""
                            toResults = []
                            endLocation = nil
                            nearbyPlaces = []
                            selectedCategory = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(white: 0.4))
                            .font(.system(size: 18))
                    }
                }

                // Current location label
                if toText.isEmpty {
                    Text(
                        locationManager.currentAddress.isEmpty ? "" : locationManager.currentAddress
                    )
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.black)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }

    // MARK: - Route Planning Bar
    private var routePlanningBar: some View {
        VStack(spacing: 10) {
            // Transport Mode Selector
            TransportModeView(
                selectedMode: $extendedMode,
                routeOptions: routeOptions
            )

            // From / To Inputs
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    TextField("From: My Location", text: $fromText)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white)
                        .onTapGesture {
                            activeField = .from
                            isBottomSheetOpen = true
                        }
                }
                .padding(10)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.2), lineWidth: 1))

                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                    TextField("To: Destination", text: $toText)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white)
                        .onTapGesture {
                            activeField = .to
                            isBottomSheetOpen = true
                        }
                }
                .padding(10)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.2), lineWidth: 1))
            }
            .padding(.horizontal)

            // Loading indicator
            if isCalculatingRoutes {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding routes...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !routeCoordinates.isEmpty, let info = routeInfo {
                routePreviewSummary(info: info)
            }

            // Actions
            HStack {
                Button("Cancel") {
                    cancelRoutePlanning()
                }
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .medium))

                Spacer()

                // Ride-share button if applicable
                if extendedMode.isRideShare {
                    Button {
                        openRideShare(mode: extendedMode)
                    } label: {
                        Label("Open \(extendedMode.rawValue)", systemImage: extendedMode.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(extendedMode.color)
                            .clipShape(Capsule())
                    }
                } else if !routeCoordinates.isEmpty {
                    HStack(spacing: 10) {
                        Button {
                            startNavigation(simulating: true)
                        } label: {
                            Label("Preview", systemImage: "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(white: 0.16))
                                .clipShape(Capsule())
                        }

                        Button {
                            startNavigation(simulating: false)
                        } label: {
                            Label("Start", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 6)
        .padding(.horizontal, 12)
        .padding(.top, 52)
    }

    // MARK: - Route Info Bar
    private func routeInfoBar(info: RouteInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip at a glance")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.55))
                    Text(destinationDisplayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(destinationDetailText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Button {
                    showDirections = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                metricTile(
                    title: "Travel time",
                    value: formatTime(info.expectedTravelTime),
                    systemImage: "clock.fill"
                )
                metricTile(
                    title: "Arrive",
                    value: arrivalTimeText,
                    systemImage: "clock.badge.checkmark",
                    accent: .green
                )
                metricTile(
                    title: "Distance",
                    value: formatDistance(info.distance),
                    systemImage: "arrow.left.and.right"
                )
                metricTile(
                    title: "Checkpoints",
                    value: "\(max(routeCoordinates.count, routeSteps.count))",
                    systemImage: "point.3.filled.connected.trianglepath.dotted"
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(label: extendedMode.rawValue, systemImage: extendedMode.icon)
                    statusChip(
                        label: liveActivityManager.areActivitiesAvailable
                            ? "Dynamic Island Ready" : "On-Device Only",
                        systemImage: liveActivityManager.areActivitiesAvailable
                            ? "dot.radiowaves.left.and.right" : "iphone"
                    )
                    statusChip(label: remainingCheckpointText, systemImage: "point.3.connected.trianglepath.dotted")
                    statusChip(label: destinationDisplayName, systemImage: "mappin.and.ellipse")
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Map Style Button
    private var mapStyleButton: some View {
        Menu {
            Picker("Map Style", selection: $mapStyle) {
                ForEach(MapStyle.allCases) { style in
                    Label(style.displayName, systemImage: style.icon).tag(style)
                }
            }
            Toggle("Traffic", isOn: $showTraffic)
            Toggle("3D Mode", isOn: $is3DMode)

            Divider()

            if !routeCoordinates.isEmpty {
                Toggle(
                    "Simulate Drive",
                    isOn: Binding(
                        get: { locationManager.isSimulating },
                        set: { newValue in
                            if newValue {
                                locationManager.startSimulation(route: routeCoordinates)
                            } else {
                                locationManager.stopSimulation()
                            }
                        }
                    ))
            }
        } label: {
            Image(systemName: "square.2.layers.3d")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(white: 0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(white: 0.22), lineWidth: 1))
        }
    }

    // MARK: - Location Button
    private var locationButton: some View {
        Button(action: {
            if let location = locationManager.lastLocation {
                withAnimation {
                    // Zoom in significantly tighter (from 0.008 to 0.002) to showcase high accuracy
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                    )
                }
            }
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(white: 0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(white: 0.22), lineWidth: 1))
        }
    }

    // MARK: - Zoom Controls
    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button(action: zoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 40)
            }
            Divider().frame(width: 28).opacity(0.3)
            Button(action: zoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 40)
            }
        }
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(white: 0.22), lineWidth: 1)
        )
    }

    // MARK: - Bottom Sheet Content
    private var bottomSheetContent: some View {
        VStack(spacing: 0) {
            if showTransitDetail && !transitSegments.isEmpty {
                // Transit detail timeline
                TransitDetailView(
                    segments: transitSegments,
                    totalDuration: routeInfo?.expectedTravelTime ?? 0,
                    onClose: { showTransitDetail = false }
                )
            } else if isRoutePlanning && !routeOptions.isEmpty {
                // Route comparison cards
                RouteComparisonView(
                    routeOptions: routeOptions,
                    onSelectRoute: { option in
                        selectRouteOption(option)
                    },
                    onOpenRideShare: { mode in
                        openRideShare(mode: mode)
                    }
                )
                .padding(.top, 8)

                // Transit detail button
                if extendedMode == .transit,
                    routeOptions.first(where: { $0.mode == .transit }) != nil
                {
                    Button {
                        buildTransitSegments()
                        showTransitDetail = true
                    } label: {
                        Label("View Transit Details", systemImage: "list.bullet.below.rectangle")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                    }
                }
            } else if let selected = selectedLocation {
                // Place detail
                LocationDetailView(
                    location: selected,
                    userLocation: locationManager.lastLocation,
                    onDirections: {
                        endLocation = selected
                        toText = selected.name
                        startLocation = Location(
                            name: "My Location",
                            coordinate: locationManager.lastLocation?.coordinate
                                ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                            description: "Current Location",
                            iconName: "location.fill"
                        )
                        fromText = "My Location"

                        withAnimation {
                            isRoutePlanning = true
                            calculateAllRoutes()
                            isBottomSheetOpen = true
                        }
                    },
                    onClose: {
                        selectedLocation = nil
                    },
                    onSave: {
                        addToRecents(selected)
                    }
                )
            } else if !toResults.isEmpty {
                // Search results
                searchResultsList
            } else if !nearbyPlaces.isEmpty {
                // Nearby category results
                if let cat = selectedCategory {
                    nearbyPlacesHeader(category: cat)
                }
                nearbyPlacesList
            } else {
                // Default: category chips + recents
                idleContent
            }
        }
    }

    // MARK: - Idle Content (Category chips + Recents)
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Explore Nearby")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Category Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PlaceCategory.allCases) { category in
                        let isActive = selectedCategory == category
                        Button {
                            selectedCategory = category
                            searchNearby(category: category)
                        } label: {
                            VStack(spacing: 7) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isActive
                                                ? LinearGradient(
                                                    colors: [
                                                        category.color, category.color.opacity(0.7),
                                                    ], startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                                : LinearGradient(
                                                    colors: [
                                                        Color(white: 0.14), Color(white: 0.10),
                                                    ], startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                        )
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle().stroke(
                                                isActive ? Color.clear : Color(white: 0.22),
                                                lineWidth: 1)
                                        )
                                        .shadow(
                                            color: isActive ? category.color.opacity(0.35) : .clear,
                                            radius: 6, y: 3)
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(isActive ? .white : category.color)
                                        .symbolEffect(.bounce, value: isActive)
                                }

                                Text(category.rawValue)
                                    .font(
                                        .system(
                                            size: 11, weight: isActive ? .bold : .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(isActive ? category.color : Color(white: 0.6))
                                    .lineLimit(1)
                            }
                            .frame(width: 70)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Recents
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            recentSearches = []
                        }
                        .font(.caption)
                        .foregroundColor(Color(white: 0.5))
                    }
                    .padding(.horizontal, 16)

                    ForEach(recentSearches) { place in
                        Button {
                            selectedLocation = place
                            withAnimation {
                                region = MKCoordinateRegion(
                                    center: place.coordinate,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    if let addr = place.address {
                                        Text(addr)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if let dist = place.formattedDistance {
                                    Text(dist)
                                        .font(.caption)
                                        .foregroundColor(Color(white: 0.4))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }

            // Explore area text
            if recentSearches.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Search or explore categories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 20)
            }

            Spacer(minLength: 20)
        }
        .padding(.top, 4)
    }

    // MARK: - Search Results List
    private var searchResultsList: some View {
        List(toResults, id: \.self) { item in
            Button(action: {
                selectSearchResult(item)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color(white: 0.2))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Nearby Places
    private func nearbyPlacesHeader(category: PlaceCategory) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.headline)
            }

            Spacer()

            Button {
                nearbyPlaces = []
                selectedCategory = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var nearbyPlacesList: some View {
        Group {
            if isSearchingNearby {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else {
                List(nearbyPlaces) { place in
                    Button {
                        selectedLocation = place
                        addToRecents(place)
                        withAnimation {
                            region = MKCoordinateRegion(
                                center: place.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(place.categoryColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: place.iconName)
                                    .foregroundColor(place.categoryColor)
                                    .font(.system(size: 16))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                if let addr = place.address {
                                    Text(addr)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if let dist = place.formattedDistance {
                                Text(dist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Navigation Header
    @State private var navSheetVisible = false

    private var navigationHeader: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.35))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(destinationDisplayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(destinationDetailText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(white: 0.5))
                            .lineLimit(2)
                        Text(
                            locationManager.isSimulating
                                ? "Preview mode is advancing the route automatically"
                                : "Live guidance is tracking your route progress"
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.38))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        statusChip(
                            label: navigationStatusText,
                            systemImage: locationManager.isSimulating ? "play.fill" : "location.fill"
                        )
                        statusChip(label: progressPercentText, systemImage: "chart.bar.fill")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: turnIcon(for: currentInstructionText))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentInstructionText)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let nextInstructionText, !nextInstructionText.isEmpty {
                            Text("Then \(nextInstructionText)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.58))
                                .lineLimit(2)
                        }
                        Text(remainingCheckpointText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.green.opacity(0.9))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                HStack(spacing: 10) {
                    navigationMetricTile(
                        title: "Arrive",
                        value: arrivalTimeText,
                        systemImage: "clock.badge.checkmark",
                        accent: .green
                    )
                    navigationMetricTile(
                        title: "Distance left",
                        value: formatDistance(displayedRemainingDistance),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up.fill"
                    )
                    navigationMetricTile(
                        title: "Guidance",
                        value: remainingManeuverText,
                        systemImage: "list.number"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(Color(white: 0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Button(action: { jumpToNavigationStep(currentStepIndex - 1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentStepIndex > 0 ? .white : Color(white: 0.3))
                                .frame(width: 34, height: 34)
                                .background(Color(white: 0.15))
                                .clipShape(Circle())
                        }
                        .disabled(currentStepIndex == 0)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Step \(currentStepIndex + 1) of \(routeSteps.count)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(white: 0.55))
                                Spacer(minLength: 8)
                                Text(progressPercentText)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text(remainingCheckpointText)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(white: 0.55))

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(white: 0.15))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(
                                            width: geo.size.width * CGFloat(navigationProgress),
                                            height: 4
                                        )
                                        .animation(.spring(response: 0.4), value: navigationProgress)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: { jumpToNavigationStep(currentStepIndex + 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(
                                    currentStepIndex < routeSteps.count - 1
                                        ? .white : Color(white: 0.3)
                                )
                                .frame(width: 34, height: 34)
                                .background(Color(white: 0.15))
                                .clipShape(Circle())
                        }
                        .disabled(currentStepIndex >= routeSteps.count - 1)
                    }

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Color(white: 0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // MARK: End Navigation Button
                Button {
                    stopNavigation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("End Navigation")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: -5)
            )
            .offset(y: navSheetVisible ? 0 : 400)
            .animation(.spring(response: 0.55, dampingFraction: 0.82), value: navSheetVisible)
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navSheetVisible = true

            }
        }
    }

    /// Map turn instruction text to an appropriate SF Symbol
    private func turnIcon(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("u-turn") || lower.contains("u turn") { return "arrow.uturn.down" }
        if lower.contains("merge") { return "arrow.merge" }
        if lower.contains("ramp") || lower.contains("exit") { return "arrow.up.right" }
        if lower.contains("arrive") || lower.contains("destination") { return "flag.checkered" }
        return "arrow.up"
    }

    // MARK: - Full-Screen Compass Overlay
    private var compassOverlay: some View {
        ZStack {
            // Dark blurred background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showCompass = false
                    }
                }

            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compass")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if let dest = endLocation {
                            Text("Pointing to \(dest.name)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showCompass = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color(white: 0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Compass
                CompassView(
                    locationManager: locationManager,
                    targetCoordinate: endLocation?.coordinate
                )

                // Destination label
                if let dest = endLocation {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.white)
                            Text(dest.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        if let addr = dest.address {
                            Text(addr)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.45))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(
                                    Color(white: 0.2), lineWidth: 1))
                    )
                }

                Spacer()

                // Back to Map button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showCompass = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back to Map")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Directions Sheet
    private var directionsSheet: some View {
        NavigationView {
            List {
                if let info = routeInfo {
                    Section("Route Summary") {
                        HStack {
                            Label(formatTime(info.expectedTravelTime), systemImage: "clock")
                            Spacer()
                            Label(
                                formatDistance(info.distance), systemImage: "arrow.left.arrow.right"
                            )
                        }
                        .font(.subheadline)
                    }
                }

                Section("Directions") {
                    ForEach(Array(routeSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.black)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .clipShape(Circle())

                            Text(step.instructions.isEmpty ? "Continue" : step.instructions)
                                .font(.subheadline)
                        }
                    }
                }

                Section {
                    Button {
                        openInMaps()
                    } label: {
                        Label("Open in Apple Maps", systemImage: "map.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    showDirections = false
                }
            }
        }
    }

    // MARK: - Computed Properties

    var allLocations: [Location] {
        var locs: [Location] = []
        // Add nearby places (from category search)
        locs.append(contentsOf: nearbyPlaces)

        if let s = startLocation, !locs.contains(where: { $0.name == s.name }) {
            locs.append(s)
        }
        if let e = endLocation, !locs.contains(where: { $0.name == e.name }) {
            locs.append(e)
        }
        return locs
    }

    // MARK: - Search Methods

    func selectSearchResult(_ result: SearchResult) {
        switch result {
        case .offline(let location):
            finalizeSelection(location)
        case .online(let completion):
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            
            Task {
                do {
                    let response = try await search.start()
                    guard let item = response.mapItems.first else { return }
                    
                    let location = Location(
                        name: item.name ?? completion.title,
                        coordinate: item.placemark.coordinate,
                        description: completion.subtitle,
                        iconName: "mappin.circle.fill",
                        address: item.placemark.title,
                        category: nil,
                        distance: nil
                    )
                    
                    await MainActor.run {
                        self.finalizeSelection(location)
                    }
                } catch {
                    print("Local search failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func finalizeSelection(_ location: Location) {
        selectedLocation = location
        addToRecents(location)
        toText = location.name
        toResults = []

        withAnimation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    func searchNearby(category: PlaceCategory) {
        // For True Offline: we mock nearby places based on coordinate math.
        isSearchingNearby = true
        isBottomSheetOpen = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearchingNearby = false

            // Generate some fake "nearby" pins for the demo offline mode
            guard let center = locationManager.lastLocation?.coordinate else { return }

            var places: [Location] = []
            for i in 1...5 {
                let offsetLat = Double.random(in: -0.01...0.01)
                let offsetLon = Double.random(in: -0.01...0.01)
                let coord = CLLocationCoordinate2D(
                    latitude: center.latitude + offsetLat, longitude: center.longitude + offsetLon)

                let dist = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(
                        from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))

                let loc = Location(
                    name: "\(category.rawValue) \(i)",
                    coordinate: coord,
                    description: "Local \(category.rawValue)",
                    iconName: category.icon,
                    address: "Local area",
                    category: category,
                    distance: dist
                )
                places.append(loc)
            }

            nearbyPlaces = places.sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
        }
    }

    func addToRecents(_ location: Location) {
        recentSearches.removeAll { $0.name == location.name }
        recentSearches.insert(location, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
    }

    // MARK: - Route
    func calculateRoute() {
        guard let start = startLocation, let end = endLocation else { return }

        let route = buildOfflineRoute(start: start, end: end, mode: .drive, speed: 13.8)

        routeCoordinates = route.coords
        routeSteps = route.steps
        routeInfo = RouteInfo(expectedTravelTime: route.time, distance: route.dist)
        resetNavigationMetrics()
    }

    // MARK: - Multi-Route Calculation
    func calculateAllRoutes() {
        guard let start = startLocation, let end = endLocation else { return }

        isCalculatingRoutes = true
        routeOptions = []

        Task {
            // True Offline Routing (Direct Line Calculation)
            var driveData:
                (
                    coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval,
                    dist: Double
                )?
            var walkData:
                (
                    coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval,
                    dist: Double
                )?
            var transitData:
                (
                    coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval,
                    dist: Double
                )?

            let types = ["drive", "walk", "transit"]

            for name in types {
                let mode: ExtendedTransportMode
                let speed: Double
                switch name {
                case "drive":
                    mode = .drive
                    speed = 13.8
                case "walk":
                    mode = .walk
                    speed = 1.4
                case "transit":
                    mode = .transit
                    speed = 8.3
                default:
                    mode = .drive
                    speed = 10.0
                }

                let route = buildOfflineRoute(start: start, end: end, mode: mode, speed: speed)
                let data = (
                    coords: route.coords,
                    steps: route.steps,
                    time: route.time,
                    dist: route.dist
                )

                switch name {
                case "drive": driveData = data
                case "walk": walkData = data
                case "transit": transitData = data
                default: break
                }
            }

            await MainActor.run {
                var options: [RouteOption] = []

                // Drive + derived modes
                if let d = driveData {
                    options.append(
                        RouteOption(
                            mode: .drive, travelTime: d.time, distance: d.dist, steps: d.steps,
                            polylineCoords: d.coords, isSelected: true))
                    options.append(
                        RouteOption(
                            mode: .motorcycle, travelTime: d.time * 0.85, distance: d.dist,
                            steps: d.steps, polylineCoords: d.coords))
                    options.append(
                        RouteOption(
                            mode: .scooter, travelTime: d.time * 1.3, distance: d.dist,
                            steps: d.steps, polylineCoords: d.coords))

                    let distKm = d.dist / 1000.0
                    for provider in RideShareService.Provider.allCases {
                        let fare = RideShareService.estimateFare(
                            provider: provider, distanceKm: distKm)
                        let mode: ExtendedTransportMode = provider == .uber ? .uber : .lyft
                        options.append(
                            RouteOption(
                                mode: mode, travelTime: d.time * 1.15, distance: d.dist, steps: [],
                                polylineCoords: d.coords,
                                fareEstimate: RideShareService.formatFare(fare)))
                    }
                }

                // Walk + cycle
                if let w = walkData {
                    options.append(
                        RouteOption(
                            mode: .walk, travelTime: w.time, distance: w.dist, steps: w.steps,
                            polylineCoords: w.coords))
                    options.append(
                        RouteOption(
                            mode: .cycle, travelTime: w.time * 0.35, distance: w.dist,
                            steps: w.steps, polylineCoords: w.coords))
                }

                // Transit + ferry
                if let t = transitData {
                    options.append(
                        RouteOption(
                            mode: .transit, travelTime: t.time, distance: t.dist, steps: t.steps,
                            polylineCoords: t.coords))
                    options.append(
                        RouteOption(
                            mode: .ferry, travelTime: t.time * 1.5, distance: t.dist,
                            steps: t.steps, polylineCoords: t.coords))
                }

                self.routeOptions = options
                self.isCalculatingRoutes = false

                // Removed offline alert dependency since it's fully offline now.

                // Auto-select
                if let match = options.first(where: { $0.mode == extendedMode }) {
                    selectRouteOption(match)
                } else if let drive = options.first(where: { $0.mode == .drive }) {
                    selectRouteOption(drive)
                } else if let first = options.first {
                    selectRouteOption(first)
                }
            }
        }
    }

    func selectRouteOption(_ option: RouteOption) {
        routeCoordinates = option.polylineCoords
        routeSteps = option.steps
        routeInfo = RouteInfo(expectedTravelTime: option.travelTime, distance: option.distance)
        extendedMode = option.mode
        resetNavigationMetrics()

        // Update selection state
        routeOptions = routeOptions.map { opt in
            var updated = opt
            updated.isSelected = (opt.id == option.id)
            return updated
        }
    }

    func handleModeChange(_ mode: ExtendedTransportMode) {
        if mode.isRideShare {
            // Show ride-share route (same as driving)
            if let driveOption = routeOptions.first(where: { $0.mode == .drive }) {
                routeCoordinates = driveOption.polylineCoords
                routeSteps = driveOption.steps
                routeInfo = RouteInfo(
                    expectedTravelTime: driveOption.travelTime, distance: driveOption.distance)
                resetNavigationMetrics()
            }
        } else if let option = routeOptions.first(where: { $0.mode == mode }) {
            selectRouteOption(option)
        }
    }

    func openRideShare(mode: ExtendedTransportMode) {
        guard let start = startLocation, let end = endLocation else { return }

        let provider: RideShareService.Provider = mode == .uber ? .uber : .lyft
        RideShareService.openRideShare(
            provider: provider,
            pickup: start.coordinate,
            dropoff: end.coordinate,
            dropoffName: end.name
        )
    }

    func buildTransitSegments() {
        // Build transit segments from route steps
        guard let transitOption = routeOptions.first(where: { $0.mode == .transit }) else { return }

        let totalTime = transitOption.travelTime
        let stepCount = max(transitOption.steps.count, 1)
        let avgStepTime = totalTime / Double(stepCount)

        var segments: [TransitSegment] = []

        for (index, step) in transitOption.steps.enumerated() {
            let instruction = step.instructions.lowercased()
            let mode: TransitSegmentMode
            let color: Color
            let lineName: String

            if instruction.contains("bus") || instruction.contains("route") {
                mode = .bus
                color = .white
                lineName = "Bus"
            } else if instruction.contains("metro") || instruction.contains("subway")
                || instruction.contains("line")
            {
                mode = .metro
                color = .red
                lineName = "Metro"
            } else if instruction.contains("train") || instruction.contains("rail") {
                mode = .train
                color = .purple
                lineName = "Train"
            } else if instruction.contains("tram") {
                mode = .tram
                color = .green
                lineName = "Tram"
            } else {
                mode = .walk
                color = .gray
                lineName = ""
            }

            segments.append(
                TransitSegment(
                    mode: mode,
                    lineName: lineName,
                    departure: step.instructions.isEmpty ? "Continue" : step.instructions,
                    arrival: index < transitOption.steps.count - 1
                        ? transitOption.steps[index + 1].instructions : "Destination",
                    stops: mode == .walk ? 0 : max(2, (index % 4) + 3),
                    duration: avgStepTime,
                    color: color
                ))
        }

        if segments.isEmpty {
            segments = [
                TransitSegment(
                    mode: .walk, lineName: "", departure: "Start", arrival: "Bus Stop", stops: 0,
                    duration: totalTime * 0.1, color: .white),
                TransitSegment(
                    mode: .bus, lineName: "Bus", departure: "Bus Stop", arrival: "Transit Hub",
                    stops: 4, duration: totalTime * 0.6, color: .white),
                TransitSegment(
                    mode: .walk, lineName: "", departure: "Transit Hub", arrival: "Destination",
                    stops: 0, duration: totalTime * 0.3, color: .white),
            ]
        }

        transitSegments = segments
    }

    // MARK: - Open in Maps
    func openInMaps() {
        guard let start = startLocation, let end = endLocation else { return }

        let startPlacemark = MKPlacemark(coordinate: start.coordinate)
        let endPlacemark = MKPlacemark(coordinate: end.coordinate)

        let startItem = MKMapItem(placemark: startPlacemark)
        startItem.name = start.name

        let endItem = MKMapItem(placemark: endPlacemark)
        endItem.name = end.name

        MKMapItem.openMaps(
            with: [startItem, endItem],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Zoom
    func zoomIn() {
        var newSpan = region.span
        newSpan.latitudeDelta *= 0.5
        newSpan.longitudeDelta *= 0.5
        region.span = newSpan
    }

    func zoomOut() {
        var newSpan = region.span
        newSpan.latitudeDelta *= 2.0
        newSpan.longitudeDelta *= 2.0
        region.span = newSpan
    }

    // MARK: - Formatting
    private func formatTime(_ time: TimeInterval) -> String {
        if time > 0, time < 60 {
            return "<1m"
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: time) ?? ""
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    private func statusChip(label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(white: 0.14))
            )
            .overlay(
                Capsule()
                    .stroke(Color(white: 0.22), lineWidth: 1)
            )
    }

    private func metricTile(title: String, value: String, systemImage: String, accent: Color = .white)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.55))
                .lineLimit(1)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
    }

    private func navigationMetricTile(
        title: String,
        value: String,
        systemImage: String,
        accent: Color = .white
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.52))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(white: 0.18), lineWidth: 1)
        )
    }

    private func routePreviewSummary(info: RouteInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(destinationDisplayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(destinationDetailText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(2)
                }

                Spacer()

                statusChip(
                    label: liveActivityManager.areActivitiesAvailable
                        ? "Dynamic Island" : "On device",
                    systemImage: liveActivityManager.areActivitiesAvailable
                        ? "dot.radiowaves.left.and.right" : "iphone"
                )
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                metricTile(
                    title: "Depart",
                    value: startLocation?.name ?? "My Location",
                    systemImage: "location.fill"
                )
                metricTile(
                    title: "Arrive",
                    value: arrivalTimeText,
                    systemImage: "clock.badge.checkmark",
                    accent: .green
                )
                metricTile(
                    title: "Distance",
                    value: formatDistance(info.distance),
                    systemImage: "arrow.left.and.right"
                )
                metricTile(
                    title: "Checkpoints",
                    value: "\(max(routeCoordinates.count, routeSteps.count))",
                    systemImage: "point.3.filled.connected.trianglepath.dotted"
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: turnIcon(for: currentInstructionText))
                        .foregroundColor(.green)
                    Text(currentInstructionText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }

                if let nextInstructionText, !nextInstructionText.isEmpty {
                    Text("Then \(nextInstructionText)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.56))
                        .lineLimit(2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(label: extendedMode.rawValue, systemImage: extendedMode.icon)
                    statusChip(label: "Preview Ready", systemImage: "play.fill")
                    statusChip(label: remainingCheckpointText, systemImage: "point.3.connected.trianglepath.dotted")
                    statusChip(label: remainingManeuverText, systemImage: "list.number")
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 0.18), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func cancelRoutePlanning() {
        locationManager.stopSimulation()

        withAnimation {
            isRoutePlanning = false
            routeCoordinates = []
            routeSteps = []
            routeInfo = nil
            routeOptions = []
            startLocation = nil
            endLocation = nil
            fromText = ""
            currentStepIndex = 0
            currentRouteCoordinateIndex = 0
            remainingDistanceMeters = 0
            remainingTravelTime = 0
        }
    }

    private func startNavigation(simulating: Bool) {
        guard !routeCoordinates.isEmpty, routeInfo != nil else { return }

        locationManager.stopSimulation()
        resetNavigationMetrics()
        navSheetVisible = false

        withAnimation {
            isNavigating = true
            isRoutePlanning = false
            isBottomSheetOpen = false
            showCompass = !simulating
        }

        if let destination = endLocation {
            Task {
                await liveActivityManager.start(
                    destinationName: destination.name,
                    destinationDetail: destination.address ?? destination.description,
                    state: navigationLiveActivityState
                )
            }
        }

        if simulating {
            locationManager.startSimulation(route: routeCoordinates, speedMultiplier: 2.4)
        }
    }

    private func stopNavigation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            navSheetVisible = false
        }

        locationManager.stopSimulation()
        Task {
            await liveActivityManager.end()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isNavigating = false
            routeCoordinates = []
            routeSteps = []
            routeInfo = nil
            routeOptions = []
            currentStepIndex = 0
            currentRouteCoordinateIndex = 0
            remainingDistanceMeters = 0
            remainingTravelTime = 0
            showCompass = false
            isBottomSheetOpen = true
        }
    }

    private func resetNavigationMetrics() {
        currentStepIndex = 0
        currentRouteCoordinateIndex = 0
        remainingDistanceMeters = routeInfo?.distance ?? 0
        remainingTravelTime = routeInfo?.expectedTravelTime ?? 0
    }

    private func jumpToNavigationStep(_ targetStep: Int) {
        guard !routeSteps.isEmpty else { return }

        currentStepIndex = min(max(targetStep, 0), routeSteps.count - 1)

        if routeCoordinates.count > 1, routeSteps.count > 1 {
            let ratio = Double(currentStepIndex) / Double(routeSteps.count - 1)
            currentRouteCoordinateIndex = Int(round(ratio * Double(routeCoordinates.count - 1)))
        }

        updateNavigationMetrics()
    }

    private func updateNavigationMetrics() {
        guard let routeInfo else { return }

        if routeCoordinates.count > 1 {
            let distance = remainingDistance(from: currentRouteCoordinateIndex)
            remainingDistanceMeters = distance
            remainingTravelTime = routeInfo.expectedTravelTime * (
                max(distance, 0) / max(routeInfo.distance, 1)
            )
        } else {
            let ratio = routeSteps.count > 1
                ? Double(currentStepIndex) / Double(routeSteps.count - 1)
                : 0
            remainingDistanceMeters = routeInfo.distance * max(0, 1 - ratio)
            remainingTravelTime = routeInfo.expectedTravelTime * max(0, 1 - ratio)
        }
    }

    private func updateNavigationActivity() {
        guard isNavigating else { return }
        Task {
            await liveActivityManager.update(state: navigationLiveActivityState)
        }
    }

    private func handleLocationUpdate(_ location: CLLocation?) {
        guard let location else { return }

        if !hasSetRegion {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            hasSetRegion = true
        }

        guard isNavigating, routeCoordinates.count > 1 else { return }
        syncNavigationProgress(with: location)
    }

    private func syncNavigationProgress(with location: CLLocation) {
        let nearestIndex =
            routeCoordinates.enumerated().min { lhs, rhs in
                let lhsDistance = CLLocation(
                    latitude: lhs.element.latitude,
                    longitude: lhs.element.longitude
                ).distance(from: location)
                let rhsDistance = CLLocation(
                    latitude: rhs.element.latitude,
                    longitude: rhs.element.longitude
                ).distance(from: location)
                return lhsDistance < rhsDistance
            }?.offset ?? 0

        currentRouteCoordinateIndex = nearestIndex

        if routeSteps.count > 1 {
            let stepProgress = Double(nearestIndex) / Double(max(routeCoordinates.count - 1, 1))
            currentStepIndex = min(
                max(Int(round(stepProgress * Double(routeSteps.count - 1))), 0),
                routeSteps.count - 1
            )
        }

        updateNavigationMetrics()
    }

    private func remainingDistance(from routeIndex: Int) -> CLLocationDistance {
        guard routeCoordinates.count > 1 else { return routeInfo?.distance ?? 0 }

        let clampedIndex = min(max(routeIndex, 0), routeCoordinates.count - 1)
        guard clampedIndex < routeCoordinates.count - 1 else { return 0 }

        var total: CLLocationDistance = 0
        for index in clampedIndex..<(routeCoordinates.count - 1) {
            let start = CLLocation(
                latitude: routeCoordinates[index].latitude,
                longitude: routeCoordinates[index].longitude
            )
            let end = CLLocation(
                latitude: routeCoordinates[index + 1].latitude,
                longitude: routeCoordinates[index + 1].longitude
            )
            total += start.distance(from: end)
        }
        return total
    }

    private func buildOfflineRoute(
        start: Location,
        end: Location,
        mode: ExtendedTransportMode,
        speed: Double
    ) -> (coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval, dist: Double) {
        let startPosition = CLLocation(
            latitude: start.coordinate.latitude,
            longitude: start.coordinate.longitude
        )
        let endPosition = CLLocation(
            latitude: end.coordinate.latitude,
            longitude: end.coordinate.longitude
        )
        let distance = startPosition.distance(from: endPosition)
        let travelTime = distance / speed

        let checkpointCount = max(5, min(14, Int(distance / 220)))
        let latitudeDelta = end.coordinate.latitude - start.coordinate.latitude
        let longitudeDelta = end.coordinate.longitude - start.coordinate.longitude
        let vectorLength = max(sqrt(latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta), 0.0001)
        let perpendicularLatitude = -longitudeDelta / vectorLength
        let perpendicularLongitude = latitudeDelta / vectorLength
        let curveStrength: Double

        switch mode {
        case .walk:
            curveStrength = 0.0008
        case .transit, .ferry:
            curveStrength = 0.0014
        default:
            curveStrength = 0.0011
        }

        var coordinates: [CLLocationCoordinate2D] = []
        for index in 0..<checkpointCount {
            let progress = Double(index) / Double(checkpointCount - 1)
            let curveOffset = sin(progress * .pi) * curveStrength
            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: start.coordinate.latitude + (latitudeDelta * progress)
                        + (perpendicularLatitude * curveOffset),
                    longitude: start.coordinate.longitude + (longitudeDelta * progress)
                        + (perpendicularLongitude * curveOffset)
                )
            )
        }

        coordinates[0] = start.coordinate
        coordinates[coordinates.count - 1] = end.coordinate

        let heading = directionLabel(from: start.coordinate, to: end.coordinate)
        let midpointDistance = formatDistance(max(distance * 0.55, 120))

        let steps: [SimpleRouteStep]
        switch mode {
        case .walk:
            steps = [
                SimpleRouteStep(instructions: "Leave \(start.name) and head \(heading) on foot"),
                SimpleRouteStep(instructions: "Keep walking \(heading) for \(midpointDistance)"),
                SimpleRouteStep(instructions: "Follow the final walking path toward \(end.name)"),
                SimpleRouteStep(instructions: "Make the last approach to \(end.name)"),
                SimpleRouteStep(instructions: "Arrive at \(end.name)")
            ]
        case .transit, .ferry:
            steps = [
                SimpleRouteStep(instructions: "Walk from \(start.name) to the transit corridor"),
                SimpleRouteStep(instructions: "Board and ride \(heading) toward \(end.name)"),
                SimpleRouteStep(instructions: "Stay on board for roughly \(midpointDistance)"),
                SimpleRouteStep(instructions: "Exit transit and continue toward \(end.name)"),
                SimpleRouteStep(instructions: "Arrive at \(end.name)")
            ]
        default:
            steps = [
                SimpleRouteStep(instructions: "Depart \(start.name) and drive \(heading)"),
                SimpleRouteStep(instructions: "Continue \(heading) for \(midpointDistance)"),
                SimpleRouteStep(instructions: "Stay on the main route toward \(end.name)"),
                SimpleRouteStep(instructions: "Take the final segment to \(end.name)"),
                SimpleRouteStep(instructions: "Arrive at \(end.name)")
            ]
        }

        return (coords: coordinates, steps: steps, time: travelTime, dist: distance)
    }

    private func directionLabel(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> String {
        let latitudeDelta = end.latitude - start.latitude
        let longitudeDelta = end.longitude - start.longitude

        func axisDirection(for delta: CLLocationDegrees) -> Int {
            if delta > 0.0001 { return 1 }
            if delta < -0.0001 { return -1 }
            return 0
        }

        switch (axisDirection(for: latitudeDelta), axisDirection(for: longitudeDelta)) {
        case (1, 1): return "northeast"
        case (1, -1): return "northwest"
        case (-1, 1): return "southeast"
        case (-1, -1): return "southwest"
        case (1, 0): return "north"
        case (-1, 0): return "south"
        case (0, 1): return "east"
        case (0, -1): return "west"
        default: return "ahead"
        }
    }
}
