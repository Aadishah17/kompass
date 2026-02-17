#!/bin/bash
set -e

# Device ID for the connected iPhone
DEVICE_ID="00008120-000935311AEB401E"

echo "Building app for physical iPhone..."
# Navigate to the package directory
cd "/Users/student/Desktop/Aadi Shah/kompass.swiftpm"

# Build for generic iOS device (physical)
# Note: Physical devices require signing. We'll try to use ad-hoc signing but it will likely fail installation.
xcodebuild -scheme kompass -destination "platform=iOS,id=$DEVICE_ID" -derivedDataPath ".build_iphone" build CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE="Manual"

echo "Installing on iPhone..."
APP_PATH=$(find .build_iphone -name "kompass.app" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "Error: App bundle not found!"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Use devicectl to install and launch
echo "Installing to device $DEVICE_ID..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" || {
    echo "Installation failed. This usually means a valid developer provisioning profile is required for physical devices."
    exit 1
}

echo "Launching on device $DEVICE_ID..."
xcrun devicectl device process launch --device "$DEVICE_ID" "com.aadishah.kompass"
