#!/bin/bash
# Installs an iOS simulator runtime for the given major version when the runner lacks one,
# trying the newest point releases first. Usage: install_ios_runtime.sh 18
set -euo pipefail
major="${1:?usage: install_ios_runtime.sh MAJOR}"
versions=("$major.6" "$major.5" "$major.4" "$major.3" "$major.2" "$major.1" "$major.0")

has_runtime() { xcrun simctl list runtimes | grep -q "iOS $major\."; }

if has_runtime; then
  echo "An iOS $major simulator runtime is already installed"
else
  echo "Installed Xcodes and runtimes:"
  ls -d /Applications/Xcode*.app || true
  xcrun simctl runtime list || true
  # Xcode downloads only the runtimes its own catalog lists, which may exclude older majors.
  for version in "${versions[@]}"; do
    echo "Trying xcodebuild for the iOS $version simulator runtime"
    if xcodebuild -downloadPlatform iOS -buildVersion "$version"; then break; fi
  done
  # xcodes fetches runtime images straight from Apple's download servers.
  if ! has_runtime && command -v xcodes >/dev/null; then
    for version in "${versions[@]}"; do
      echo "Trying xcodes for the iOS $version simulator runtime"
      if xcodes runtimes install "iOS $version"; then break; fi
    done
  fi
  # Restart the simulator service so it can create devices on the new runtime.
  killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
  sleep 5
  if ! has_runtime; then
    echo "::error::No iOS $major simulator runtime could be installed for this Xcode."
    exit 1
  fi
fi
xcrun simctl list runtimes
