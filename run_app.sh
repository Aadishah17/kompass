#!/bin/bash
set -e

# Device ID for iPhone 17 Pro
DEVICE_ID="81502B78-E72D-4F9F-8D78-FD90FF15F269"

echo "Booting simulator..."
xcrun simctl boot "$DEVICE_ID" || true
open -a Simulator

echo "Building app..."
# Navigate to the package directory
cd "/Users/student/Desktop/Aadi Shah/kompass.swiftpm"

# Build
xcodebuild -scheme kompass -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath ".build" build

echo "Installing and launching..."
APP_PATH=$(find .build -name "kompass.app" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "Error: App bundle not found!"
    exit 1
fi

echo "Found app at: $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch "$DEVICE_ID" "com.aadishah.kompass"
