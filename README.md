# Acute Web for iOS and iPadOS

<p align="center">
  <img src="AcuteWeb/AppIcon.icon/Assets/AcuteCatFox.png" alt="Acute Web silver cat-fox mark" width="180">
</p>

Native SwiftUI browser shell using WebKit. The product principles carry across
from Acute Web for Android; the engine and interface remain native to Apple
platforms.

**Acute Web by CORE** — *The web, in focus.*

Acute Web uses the clear-glass cat-fox exclusively. The primary `AppIcon.icon`
separates the neutral silver mark from the system-rendered enclosure, with
space around the silhouette. iOS 26 renders its default, dark, clear and tinted
Home Screen appearances; the user's Home Screen appearance and tint choices
control the installed icon independently of the browser's interface theme.
The asset catalog retains the older flat icon for compatibility. The unused
legacy `BETA` asset is not the primary icon for current development builds.

## Principles

- No telemetry, analytics, experiments, advertising identifiers, or automatic
  diagnostic uploads.
- Web content remains in WebKit's sandboxed content processes.
- Private tabs use a non-persistent `WKWebsiteDataStore`.
- Search input is sent only to the user-selected search provider.
- Platform-native navigation, keyboard shortcuts, window resizing, and Liquid
  Glass where available.
- No third-party runtime dependencies.

## Version 0.2 interface work

Work is moving into beta hardening. The [beta readiness gate](docs/BETA-READINESS.md)
tracks App Review requirements, design/accessibility checks, device evidence and
submission blockers separately. Passing CI is not App Store approval or a claim
that physical iPad validation is complete. [The privacy policy](PRIVACY.md) is
available in Settings and bundled for offline reading.

The current development build begins the [0.2 UI stage](docs/UI-0.2.md):
navigation uses a single row of tab/address capsules with persistent Back,
conditional Forward, and Refresh/Stop inside the selected tab. Wide iPad
windows retain a sidebar and use native menu-bar commands. Custom
navigation uses grouped Liquid Glass on iOS 26 with system-material fallbacks.

## Version 0.1 foundation

The `0.1.0` foundation implements the following. This is a development build,
not a published release; see [the foundation checklist](docs/FOUNDATION-0.1.md)
for verification coverage and the remaining device checks.

- A native start page for regular and private tabs, with controls to show bookmarks, favorites, and recent session sites.
- A start-page action that preserves tab position and private mode.
- Per-tab page zoom from 50% to 200%, restored for regular tabs; new tabs start at 100%.
- Session-only recent sites that never include private browsing.
- Tab snapshots, duplication, reopening, reordering, and adaptive iPad layouts.
- Search-engine selection with DuckDuckGo as the default.
- On-device WebKit content rules matching known tracker resource hosts, applied before main-frame navigation.
- Native downloads with restart recovery, search, preview, cancellation, sharing, and confirmed file deletion.
- Find in page with live results, accessible controls, and per-tab desktop/mobile website switching.
- Link menus for new regular/private tabs; links opened from private pages retain private browsing.
- User-activated email, phone, and message links require confirmation before opening another app; private tabs warn that their protection does not extend outside Acute.
- Invalid or unsupported typed addresses show explicit feedback instead of silently doing nothing.
- Editable bookmarks and searchable bookmarks/history.
- Keyboard shortcuts for address focus, reopening tabs, navigation, page search, tab switching, zoom, and the start page.
- Page-load errors and terminated website processes with explicit retry and cancellation of pending website prompts.
- Native website alert, confirmation, and text-input dialogs with per-tab cancellation.
- Explicit allow-once prompts for website camera and microphone access, cancelled when their tab closes, navigates, or loses selection.
- Persistent user-created bookmarks and browsing history that is off by default.
- Crash-safe restoration for regular pages and start-page tabs, preserving selection and website viewing preferences, with a user-controlled startup toggle.
- Private tabs excluded from saved sessions, recent sites, browsing history, and closed-tab recovery.
- Confirmed bulk closing for regular, private, or all tabs, with a start-page fallback if no tabs remain.
- Confirmed clearing of regular cookies, caches, and website storage without deleting private browsing or saved browser content.
- Private browsing is covered while the app is inactive for app-switcher snapshots.
- Per-site controls for tracker blocking, JavaScript, media capture, and local website data.
- A clear privacy settings surface documenting Acute's zero-telemetry behavior.
- An App Store privacy manifest declaring no tracking or collected data.

## Keyboard controls

| Action | Shortcut |
| --- | --- |
| Next / previous tab | Control-Tab / Control-Shift-Tab |
| Zoom in / out | Command-= / Command-- |
| Reset zoom | Command-0 |
| Start page | Command-Shift-H |

Page commands follow the selected tab's current navigation and zoom state.

## Device testing artifact

After both simulator jobs pass, GitHub Actions builds the Release app for arm64
iPhones and iPads and uploads `acute-web-unsigned-ipa`. The artifact contains
`AcuteWeb-unsigned.ipa`, its SHA-256 checksum, and the source commit/build number.
The IPA must be signed by your sideloading tool before installation. It is a
device build; the separate simulator artifacts cannot be installed on a phone.

## Generate and build

The committed Xcode project is generated from `project.yml` with XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project AcuteWeb.xcodeproj -scheme AcuteWeb \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

GitHub Actions regenerates the project, compiles the app and full XCUITest target,
runs the unit and full interface suites, validates the bundled privacy manifest, installs and launches
Acute on iPhone and iPad simulators, and retains the test result bundles.
Visual review uses physical-device testing; routine screenshots are not captured.
The XCUITest suite
also covers privacy settings, private browsing, history, rotation, tab management,
and start-page customization. CI uses Xcode 26.3 and an iOS 26.2 simulator so Liquid Glass code is
compiled and exercised. Device and TestFlight builds require Apple Developer signing
credentials. Failed unit tests get one retry in a fresh test process;
both attempts remain in the test result bundle.
