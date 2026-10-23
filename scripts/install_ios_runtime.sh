#!/bin/bash
# Installs an iOS simulator runtime for the given major version when the runner lacks one,
# trying the newest point releases first. Usage: install_ios_runtime.sh 18
set -euo pipefail
major="${1:?usage: install_ios_runtime.sh MAJOR}"
if xcrun simctl list runtimes | grep -q "iOS $major\."; then
  echo "An iOS $major simulator runtime is already installed"
else
  installed=""
  for version in "$major.6" "$major.5" "$major.4" "$major.3" "$major.2" "$major.1" "$major.0"; do
    echo "Trying to download the iOS $version simulator runtime"
    if xcodebuild -downloadPlatform iOS -buildVersion "$version"; then
      installed="$version"
      break
    fi
  done
  if [ -z "$installed" ]; then
    echo "::error::No iOS $major simulator runtime could be downloaded for this Xcode."
    exit 1
  fi
  # Restart the simulator service so it can create devices on the new runtime.
  killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
fi
xcrun simctl list runtimes
