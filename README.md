# Acute Web for iOS and iPadOS

<p align="center">
  <img src="AcuteWeb/Assets.xcassets/AppIcon.appiconset/AcuteWebIcon-Clear.png" alt="Acute Web clear-glass cat-fox mark" width="180">
</p>

Native SwiftUI browser shell using WebKit. The product principles carry across
from Acute Web for Android; the engine and interface remain native to Apple
platforms.

**Acute Web by CORE** — *The web, in focus.*

Acute Web uses the clear-glass cat-fox exclusively. Stable builds use the
unbadged clear icon, while beta builds use the matching clear `BETA` icon. The
system derives its supported Home Screen appearances from this clear master.

## Principles

- No telemetry, analytics, experiments, advertising identifiers, or automatic
  diagnostic uploads.
- Web content remains in WebKit's sandboxed content processes.
- Private tabs use a non-persistent `WKWebsiteDataStore`.
- Search input is sent only to the user-selected search provider.
- Platform-native navigation, keyboard shortcuts, window resizing, and Liquid
  Glass where available.
- No third-party runtime dependencies.

## Version 1.0

Version `1.0.0` includes:

- A native start page for regular and private tabs.
- Session-only recent sites that never include private browsing.
- Tab snapshots, duplication, reopening, reordering, and adaptive iPad layouts.
- Search-engine selection with DuckDuckGo as the default.
- On-device WebKit content rules for known tracker resources.
- Native downloads saved locally and exposed through the system share sheet.
- Find in page and per-tab desktop/mobile website switching.
- Explicit allow-once prompts for website camera and microphone access.
- Persistent user-created bookmarks and browsing history that is off by default.
- Crash-safe restoration for regular tabs, with a user-controlled startup toggle.
- Private tabs excluded from saved sessions, recent sites, and browsing history.
- Per-site controls for tracker blocking, JavaScript, media capture, and local website data.
- A clear privacy settings surface documenting Acute's zero-telemetry behavior.
- An App Store privacy manifest declaring no tracking or collected data.

## Generate and build

The committed Xcode project is generated from `project.yml` with XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project AcuteWeb.xcodeproj -scheme AcuteWeb \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

GitHub Actions regenerates the project, compiles the app and full XCUITest target,
runs the unit suite, validates the bundled privacy manifest, installs and launches
Acute on iPhone and iPad simulators, and retains both start-page screenshots with
the test result bundle. The XCUITest suite
also covers privacy settings, private browsing, and history for local or release
validation. CI uses Xcode 26.3 and an iOS 26.2 simulator so Liquid Glass code is
compiled and exercised. Device and TestFlight builds require Apple Developer signing
credentials.
