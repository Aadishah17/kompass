import SwiftUI
import MapKit

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
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

// TransportMode kept for backward compatibility, primary modes now in ExtendedTransportMode
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
    
    // Network
    @StateObject private var networkManager = NetworkManager()
    
    // Navigation
    @State private var isNavigating = false
    @State private var isRoutePlanning = false
    @State private var currentStepIndex = 0
    
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
                
                // Route Info Bar
                if let info = routeInfo, isRoutePlanning && !isNavigating {
                    routeInfoBar(info: info)
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
            
            // MARK: - Bottom Sheet
            BottomSheetView(
                isOpen: $isBottomSheetOpen,
                maxHeight: UIScreen.main.bounds.height * 0.7,
                minHeight: isNavigating ? 0 : 80
            ) {
                bottomSheetContent
            }
            
            // MARK: - Navigation Header
            if isNavigating && !routeSteps.isEmpty {
                navigationHeader
            }
            
            // MARK: - Dynamic Island
            if isNavigating && !routeSteps.isEmpty {
                DynamicIslandView(
                    currentInstruction: routeSteps[currentStepIndex].instructions.isEmpty
                        ? "Continue on route"
                        : routeSteps[currentStepIndex].instructions,
                    nextInstruction: currentStepIndex + 1 < routeSteps.count
                        ? routeSteps[currentStepIndex + 1].instructions
                        : nil,
                    etaSeconds: routeInfo?.expectedTravelTime ?? 0,
                    distanceMeters: routeInfo?.distance ?? 0,
                    stepIndex: currentStepIndex,
                    totalSteps: routeSteps.count
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .ignoresSafeArea(.container, edges: .top)
            }
            
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
            guard let location = location, !hasSetRegion else { return }
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            hasSetRegion = true
        }
        .onChange(of: toText) { newValue in
            toCompleter.query = newValue
            toCompleter.isOffline = networkManager.isEffectiveOffline
            toCompleter.allLocations = allLocations
        }
        .onReceive(toCompleter.$completions) { completions in
            toResults = completions
        }
        .alert("Offline Mode", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Some features like search and routing need an internet connection. Your map, compass, GPS location, and saved places still work offline.")
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
                    Text(locationManager.currentAddress.isEmpty ? "" : locationManager.currentAddress)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.45))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(white: 0.1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color(white: 0.18), lineWidth: 1)
            )
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
            .onChange(of: extendedMode) { newMode in
                handleModeChange(newMode)
            }
            
            // From / To Inputs
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    TextField("From: My Location", text: $fromText)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white)
                        .onTapGesture { activeField = .from; isBottomSheetOpen = true }
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
                        .onTapGesture { activeField = .to; isBottomSheetOpen = true }
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
            
            // Actions
            HStack {
                Button("Cancel") {
                    withAnimation {
                        isRoutePlanning = false
                        routeCoordinates = []
                        routeSteps = []
                        routeInfo = nil
                        routeOptions = []
                        startLocation = nil
                        endLocation = nil
                        fromText = ""
                    }
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
                    Button {
                        withAnimation {
                            isNavigating = true
                            isRoutePlanning = false
                            currentStepIndex = 0
                            showCompass = true
                        }
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
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.1))
                .shadow(color: Color.black.opacity(0.08), radius: 8)
        )
        .padding(.horizontal, 12)
        .padding(.top, 52)
    }
    
    // MARK: - Route Info Bar
    private func routeInfoBar(info: RouteInfo) -> some View {
        HStack(spacing: 20) {
            // ETA
            VStack(spacing: 2) {
                Text(formatTime(info.expectedTravelTime))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("ETA")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider().frame(height: 30)
            
            // Distance
            VStack(spacing: 2) {
                Text(formatDistance(info.distance))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Distance")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider().frame(height: 30)
            
            // Arrival Time
            VStack(spacing: 2) {
                let arrival = Date().addingTimeInterval(info.expectedTravelTime)
                Text(arrival, style: .time)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Arrival")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Show steps
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.1))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.18), lineWidth: 1))
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
            Toggle("Simulate Offline", isOn: $networkManager.isSimulatedOffline)
            
            if !routeCoordinates.isEmpty {
                Toggle("Simulate Drive", isOn: Binding(
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
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
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
                if extendedMode == .transit, let _ = routeOptions.first(where: { $0.mode == .transit }) {
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
                            coordinate: locationManager.lastLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
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
                                            ? LinearGradient(colors: [category.color, category.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [Color(white: 0.14), Color(white: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle().stroke(isActive ? Color.clear : Color(white: 0.22), lineWidth: 1)
                                        )
                                        .shadow(color: isActive ? category.color.opacity(0.35) : .clear, radius: 6, y: 3)
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(isActive ? .white : category.color)
                                        .symbolEffect(.bounce, value: isActive)
                                }
                                
                                Text(category.rawValue)
                                    .font(.system(size: 11, weight: isActive ? .bold : .medium, design: .rounded))
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
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
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
                
                // MARK: Turn Instruction Card
                HStack(spacing: 14) {
                    // Direction icon
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: turnIcon(for: routeSteps[currentStepIndex].instructions))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routeSteps[currentStepIndex].instructions.isEmpty
                             ? "Continue on route"
                             : routeSteps[currentStepIndex].instructions)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        

                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Divider
                Rectangle()
                    .fill(Color(white: 0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                
                // MARK: Step Progress Row
                HStack(spacing: 16) {
                    // Step navigation
                    HStack(spacing: 12) {
                        Button(action: { if currentStepIndex > 0 { currentStepIndex -= 1 } }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentStepIndex > 0 ? .white : Color(white: 0.3))
                                .frame(width: 34, height: 34)
                                .background(Color(white: 0.15))
                                .clipShape(Circle())
                        }
                        .disabled(currentStepIndex == 0)
                        
                        // Progress
                        VStack(spacing: 4) {
                            Text("Step \(currentStepIndex + 1) / \(routeSteps.count)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(white: 0.55))
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(white: 0.15))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: geo.size.width * CGFloat(currentStepIndex + 1) / CGFloat(max(routeSteps.count, 1)), height: 4)
                                        .animation(.spring(response: 0.4), value: currentStepIndex)
                                }
                            }
                            .frame(height: 4)
                            .frame(width: 80)
                        }
                        
                        Button(action: { if currentStepIndex < routeSteps.count - 1 { currentStepIndex += 1 } }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentStepIndex < routeSteps.count - 1 ? .white : Color(white: 0.3))
                                .frame(width: 34, height: 34)
                                .background(Color(white: 0.15))
                                .clipShape(Circle())
                        }
                        .disabled(currentStepIndex >= routeSteps.count - 1)
                    }
                    
                    Spacer()
                    
                    // ETA
                    if let info = routeInfo {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTime(info.expectedTravelTime))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(formatDistance(info.distance))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(white: 0.45))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                
                // Divider
                Rectangle()
                    .fill(Color(white: 0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                
                // MARK: End Navigation Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        navSheetVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isNavigating = false
                        routeCoordinates = []
                        routeSteps = []
                        routeInfo = nil
                        currentStepIndex = 0
                    }
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
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.2), lineWidth: 1))
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
                            Label(formatDistance(info.distance), systemImage: "arrow.left.arrow.right")
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
        case .online(let completion):
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            
            search.start { response, error in
                guard let response = response, let item = response.mapItems.first else { return }
                
                DispatchQueue.main.async {
                    let location = Location.from(mapItem: item, userLocation: locationManager.lastLocation)
                    finalizeSelection(location)
                }
            }
            
        case .offline(let location):
            finalizeSelection(location)
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
        isSearchingNearby = true
        isBottomSheetOpen = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearchingNearby = false
                guard let response = response else {
                    if networkManager.isEffectiveOffline {
                        showOfflineAlert = true
                    }
                    return
                }
                
                nearbyPlaces = response.mapItems.map { item in
                    var loc = Location.from(mapItem: item, userLocation: locationManager.lastLocation)
                    if loc.category == nil {
                        loc = Location(
                            name: loc.name,
                            coordinate: loc.coordinate,
                            description: loc.description,
                            iconName: category.icon,
                            address: loc.address,
                            category: category,
                            phoneNumber: loc.phoneNumber,
                            rating: loc.rating,
                            isOpen: loc.isOpen,
                            distance: loc.distance,
                            url: loc.url
                        )
                    }
                    return loc
                }
                .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
            }
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
        
        let startPlacemark = MKPlacemark(coordinate: start.coordinate)
        let endPlacemark = MKPlacemark(coordinate: end.coordinate)
        
        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem(placemark: startPlacemark)
        directionRequest.destination = MKMapItem(placemark: endPlacemark)
        directionRequest.transportType = transportType.mkTransportType
        
        let directions = MKDirections(request: directionRequest)
        
        Task {
            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    let pointCount = route.polyline.pointCount
                    var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
                    route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
                    
                    let steps = route.steps.map { SimpleRouteStep(instructions: $0.instructions) }
                    let info = RouteInfo(expectedTravelTime: route.expectedTravelTime, distance: route.distance)
                    
                    await MainActor.run {
                        self.routeCoordinates = coordinates
                        self.routeSteps = steps
                        self.routeInfo = info
                    }
                }
            } catch {
                print("Error getting directions: \(error.localizedDescription)")
                await MainActor.run {
                    if networkManager.isEffectiveOffline {
                        showOfflineAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Multi-Route Calculation
    func calculateAllRoutes() {
        guard let start = startLocation, let end = endLocation else { return }
        
        isCalculatingRoutes = true
        routeOptions = []
        
        let startPlacemark = MKPlacemark(coordinate: start.coordinate)
        let endPlacemark = MKPlacemark(coordinate: end.coordinate)
        
        Task {
            // Calculate the 3 base transport types sequentially (MKRoute isn't Sendable)
            var driveData: (coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval, dist: Double)?
            var walkData: (coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval, dist: Double)?
            var transitData: (coords: [CLLocationCoordinate2D], steps: [SimpleRouteStep], time: TimeInterval, dist: Double)?
            
            let types: [(String, MKDirectionsTransportType)] = [
                ("drive", .automobile),
                ("walk", .walking),
                ("transit", .transit)
            ]
            
            for (name, mkType) in types {
                // HYBRID MODE: Try online first, fallback to offline if it fails
                var onlineRouteFound = false
                
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: startPlacemark)
                request.destination = MKMapItem(placemark: endPlacemark)
                request.transportType = mkType
                
                let directions = MKDirections(request: request)
                
                do {
                    let response = try await directions.calculate()
                    if let route = response.routes.first {
                        let count = route.polyline.pointCount
                        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
                        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
                        let steps = route.steps.map { SimpleRouteStep(instructions: $0.instructions) }
                        let data = (coords: coords, steps: steps, time: route.expectedTravelTime, dist: route.distance)
                        
                        switch name {
                        case "drive": driveData = data
                        case "walk": walkData = data
                        case "transit": transitData = data
                        default: break
                        }
                        onlineRouteFound = true
                    }
                } catch {
                    print("Online routing failed for \(name) (Offline Mode active): \(error.localizedDescription)")
                }
                
                if !onlineRouteFound {
                    // Fallback: Offline Direct Line
                    let coords = [start.coordinate, end.coordinate]
                    let loc1 = CLLocation(latitude: start.coordinate.latitude, longitude: start.coordinate.longitude)
                    let loc2 = CLLocation(latitude: end.coordinate.latitude, longitude: end.coordinate.longitude)
                    let dist = loc1.distance(from: loc2)
                    
                    // Estimate speed (m/s)
                    let speed: Double
                    switch name {
                    case "drive": speed = 13.8 // ~50 km/h
                    case "walk": speed = 1.4   // ~5 km/h
                    case "transit": speed = 8.3 // ~30 km/h
                    default: speed = 10.0
                    }
                    
                    let time = dist / speed
                    let steps = [SimpleRouteStep(instructions: "Go directly to destination")]
                    let data = (coords: coords, steps: steps, time: time, dist: dist)
                    
                    switch name {
                    case "drive": driveData = data
                    case "walk": walkData = data
                    case "transit": transitData = data
                    default: break
                    }
                }
            }
            
            await MainActor.run {
                var options: [RouteOption] = []
                
                // Drive + derived modes
                if let d = driveData {
                    options.append(RouteOption(mode: .drive, travelTime: d.time, distance: d.dist, steps: d.steps, polylineCoords: d.coords, isSelected: true))
                    options.append(RouteOption(mode: .motorcycle, travelTime: d.time * 0.85, distance: d.dist, steps: d.steps, polylineCoords: d.coords))
                    options.append(RouteOption(mode: .scooter, travelTime: d.time * 1.3, distance: d.dist, steps: d.steps, polylineCoords: d.coords))
                    
                    let distKm = d.dist / 1000.0
                    for provider in RideShareService.Provider.allCases {
                        let fare = RideShareService.estimateFare(provider: provider, distanceKm: distKm)
                        let mode: ExtendedTransportMode = provider == .uber ? .uber : .lyft
                        options.append(RouteOption(mode: mode, travelTime: d.time * 1.15, distance: d.dist, steps: [], polylineCoords: d.coords, fareEstimate: RideShareService.formatFare(fare)))
                    }
                }
                
                // Walk + cycle
                if let w = walkData {
                    options.append(RouteOption(mode: .walk, travelTime: w.time, distance: w.dist, steps: w.steps, polylineCoords: w.coords))
                    options.append(RouteOption(mode: .cycle, travelTime: w.time * 0.35, distance: w.dist, steps: w.steps, polylineCoords: w.coords))
                }
                
                // Transit + ferry
                if let t = transitData {
                    options.append(RouteOption(mode: .transit, travelTime: t.time, distance: t.dist, steps: t.steps, polylineCoords: t.coords))
                    options.append(RouteOption(mode: .ferry, travelTime: t.time * 1.5, distance: t.dist, steps: t.steps, polylineCoords: t.coords))
                }
                
                self.routeOptions = options
                self.isCalculatingRoutes = false
                
                if options.isEmpty && networkManager.isEffectiveOffline {
                    showOfflineAlert = true
                    return
                }
                
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
                routeInfo = RouteInfo(expectedTravelTime: driveOption.travelTime, distance: driveOption.distance)
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
            } else if instruction.contains("metro") || instruction.contains("subway") || instruction.contains("line") {
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
            
            segments.append(TransitSegment(
                mode: mode,
                lineName: lineName,
                departure: step.instructions.isEmpty ? "Continue" : step.instructions,
                arrival: index < transitOption.steps.count - 1 ? transitOption.steps[index + 1].instructions : "Destination",
                stops: mode == .walk ? 0 : Int.random(in: 2...8),
                duration: avgStepTime,
                color: color
            ))
        }
        
        if segments.isEmpty {
            segments = [
                TransitSegment(mode: .walk, lineName: "", departure: "Start", arrival: "Bus Stop", stops: 0, duration: totalTime * 0.1, color: .white),
                TransitSegment(mode: .bus, lineName: "Bus", departure: "Bus Stop", arrival: "Transit Hub", stops: 4, duration: totalTime * 0.6, color: .white),
                TransitSegment(mode: .walk, lineName: "", departure: "Transit Hub", arrival: "Destination", stops: 0, duration: totalTime * 0.3, color: .white)
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
        
        MKMapItem.openMaps(with: [startItem, endItem], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
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
}
