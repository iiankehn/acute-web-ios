# Acute Web for iOS and iPadOS

Native SwiftUI browser shell using WebKit. The product principles carry across from Acute Web for Android; the engine and interface remain native to Apple platforms.

## Principles

- No telemetry, analytics, experiments, advertising identifiers, or automatic diagnostic uploads.
- Web content remains in WebKit's sandboxed content processes.
- Private tabs use a non-persistent `WKWebsiteDataStore`.
- Search input is sent only to the user-selected search provider.
- Platform-native navigation, keyboard shortcuts, window resizing, and Liquid Glass where available.
- No third-party runtime dependencies.

## Generate and build

The committed Xcode project is generated from `project.yml` with XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project AcuteWeb.xcodeproj -scheme AcuteWeb \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

GitHub Actions regenerates the project and performs an unsigned simulator build. Device and TestFlight builds will require Apple Developer signing credentials.
