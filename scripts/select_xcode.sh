#!/bin/bash
# Selects the newest installed Xcode matching a version prefix, or fails with the installed list.
# With --ios-runtime, also installs that Xcode's iOS simulator runtime when the image lacks it.
set -euo pipefail
want="${1:-27.1}"
candidates=$(ls -d /Applications/Xcode_"$want"*.app 2>/dev/null | sort -r || true)
if [ -z "$candidates" ]; then
  echo "::error::Xcode $want is not installed on this runner image."
  ls -d /Applications/Xcode*.app || true
  exit 1
fi
xcode=$(echo "$candidates" | head -n 1)
sudo xcode-select -s "$xcode/Contents/Developer"
xcodebuild -version
if [ "${2:-}" = "--ios-runtime" ]; then
  runtime="iOS-${want//./-}"
  if ! xcrun simctl list runtimes | grep -q "$runtime"; then
    echo "Installing the iOS $want simulator runtime for this Xcode"
    xcodebuild -downloadPlatform iOS
    # Restart the simulator service so it can create devices on the new runtime.
    killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
  fi
fi
xcrun simctl list runtimes
