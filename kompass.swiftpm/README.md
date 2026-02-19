# Kompass

Kompass is a modern, dark-themed iOS navigation application built with SwiftUI and MapKit. It features a sleek interface designed for AMOLED screens and robust offline capabilities for simulated environments.

## Key Features

- **Offline Search & Routing**: 
  - Seamlessly switches between online `MKLocalSearch` and a local offline database.
  - **Hybrid Routing**: Prioritizes `MKDirections` (roads) even in simulated offline mode if the device has connectivity, falling back to direct-line navigation only when necessary.
  - **Note**: The app defaults to "Offline Mode" for testing. Toggle this in the map style menu.

- **Dynamic Island Integration**:
  - Displays real-time navigation instructions and ETA in the Dynamic Island.
  - Expands to show detailed step-by-step guidance.
  - **Fix**: Positioned to perfectly overlap the device notch/island.

- **Premium Dark Aesthetics**:
  - Pure black backgrounds and high-contrast elements for a premium look.
  - Custom UI components including a floating search bar and bottom sheet.

- **Multi-Modal Transport**:
  - Supports Driving, Walking, Transit, and Ride-Share options.
  - Visual route plotting with mode-specific estimates.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository.
2. Open the project in Xcode.
3. Select the `kompass` scheme.
4. Run on an iOS Simulator (recommended: iPhone 15 Pro or later for Dynamic Island features).

## Usage

### Simulating Offline Mode
The app includes a network simulation feature to test offline capabilities without disconnecting your device.
1. Tap the **Map Layers** button (stack icon) on the right.
2. Toggle **"Simulate Offline"**.
3. Search for locations (e.g., "Eiffel Tower") to see local results and generate offline routes.

### Navigation
1. Search for a destination or select a point of interest.
2. Tap **Directions**.
3. Choose your transport mode and tap **Go**.
4. Follow the on-screen path and Dynamic Island updates.

## Technologies

- **SwiftUI**: Core UI framework.
- **MapKit**: Mapping and geocoding services.
- **Combine**: Asynchronous event handling.
- **CoreLocation**: User location tracking.
