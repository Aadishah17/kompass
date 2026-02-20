# Kompass: True Offline Navigation 🧭

Kompass is a premium, fully offline navigation application built for iOS using Swift Playgrounds and SwiftUI. Originally a standard map app, it has been intentionally re-architected to break free from network dependencies, offering a pinpoint-accurate routing and tracking experience using only your device's hardware satellites.

## 🌟 Key Features

### 📡 True Offline Architecture

Kompass operates 100% independent of cellular or Wi-Fi data.

- **No Online Fallbacks:** The `NetworkManager` and all reachability checks have been aggressively purged.
- **Offline Local Search:** No reliance on Apple's online `MKLocalSearchCompleter`. The app mathematically calculates "Nearby Places" around your current coordinate and instantly filters local datasets with zero latency.
- **Offline Routing Engine:** Stripped out Apple's server-based `MKDirections` in favor of a mathematical Cartesian/Haversine offline calculator. It computes a direct-line route, predicts ETA based on standard travel speeds (50 km/h driving, 5 km/h walking), and outputs precise navigational steps entirely from your local device.

### 📍 Pinpoint GPS Accuracy

- **Survey-Grade Precision:** Navigates via `kCLLocationAccuracyBestForNavigation` forcing your device's GPS hardware to run at maximum power to secure the tightest satellite lock.
- **Micro-Movement Tracking:** The distance filter is disabled (`kCLDistanceFilterNone`), meaning the UI reacts to your movements in real-time instantly without waiting for chunked threshold updates.
- **High-Precision Parsing:** Outputs location data to 6-decimal degrees (e.g. `37.334600, -122.009000`), a standard used in high-level surveying software.

### 🎨 "Humanified" AMOLED UI

A beautiful interface built specifically to look premium on OLED screens:

- **Glassmorphism:** The sliding Bottom Sheet utilizes `.ultraThinMaterial` backings, 32-point continuous curves, and subtle inner gradients to blur over the map elegantly.
- **Fluid Physics:** Drag gestures logic natively calculated and wrapped in `.spring()` animations for butter-smooth interactions.
- **Custom Map Engine Rendering:** Standard map elements are muted, while the navigation track draws as a glassy dark gray (`UIColor(white: 0.25, alpha: 0.6)`) overlaid with a glowing white animated pulse line.
- **Dynamic Island Native:** The navigation pill gracefully respects all iPhone models and safely anchors below hardware sensor cutouts (Notch / Dynamic Island) without clipping.

## 🛠️ Installation & Usage

### Running Locally (Swift Playgrounds / Xcode)

1. Clone or download this repository.
2. Open the `kompass.swiftpm` package in **Swift Playgrounds** on iPad/Mac or **Xcode** on a Mac.
3. Build and Run on a physical device. *(Note: Simulator testing is supported, though offline accuracy features are best tested on real GPS hardware).*

### Dependencies

- **SwiftUI & MapKit** (Natively bundled, no external pods/packages required).

## 🚀 How It Works Under The Hood

Unlike traditional MapKit wrappers, Kompass simulates what a robust navigation ecosystem would look like when placed in a complete dead-zone.

- `LocationManager.swift` manages the raw CoreLocation data, instantly pushing out `didUpdateLocations` updates to the pipeline without attempting backward `CLGeocoder` DNS lookups.
- `ContentView.swift` handles the complex bridging of MKMapView's UIKit layer into SwiftUI, rendering out smooth track paths over top of the custom coordinate array generated during route calculations.

---
*Built with precision and crafted for the offline explorer.* 🏔️
