# Acute Web for iOS and iPadOS

Native SwiftUI browser shell using WebKit. The product principles carry across
from Acute Web for Android; the engine and interface remain native to Apple
platforms.

## Principles

- No telemetry, analytics, experiments, advertising identifiers, or automatic
  diagnostic uploads.
- Web content remains in WebKit's sandboxed content processes.
- Private tabs use a non-persistent `WKWebsiteDataStore`.
- Search input is sent only to the user-selected search provider.
- Platform-native navigation, keyboard shortcuts, window resizing, and Liquid
  Glass where available.
- No third-party runtime dependencies.

## Functional preview

The `0.1.0` preview includes:

- A native start page for regular and private tabs.
- Session-only recent sites that never include private browsing.
- Tab snapshots, duplication, reopening, reordering, and adaptive iPad layouts.
- Search-engine selection with DuckDuckGo as the default.
- On-device WebKit content rules for known tracker resources.
- Native downloads saved locally and exposed through the system share sheet.
- Find in page and per-tab desktop/mobile website switching.
- Explicit allow-once prompts for website camera and microphone access.
- Persistent user-created bookmarks and browsing history that is off by default.
- Per-site controls for tracker blocking, JavaScript, media capture, and local website data.
- A clear privacy settings surface documenting Acute's zero-telemetry behavior.

## Generate and build

The committed Xcode project is generated from `project.yml` with XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project AcuteWeb.xcodeproj -scheme AcuteWeb \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

GitHub Actions regenerates the project and performs an unsigned simulator build.
Device and TestFlight builds will require Apple Developer signing credentials.
