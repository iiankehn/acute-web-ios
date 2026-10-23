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

## Version 0.5 beta

Acute Web 0.5 is a sideload-only beta: there is no App Store or TestFlight build.
The [release notes](RELEASE-NOTES.md) explain how to install it with a free Apple
Developer account and what changed. Work is in beta hardening. The [beta readiness gate](docs/BETA-READINESS.md)
tracks App Review requirements, design/accessibility checks, device evidence and
submission blockers separately. Passing CI is not App Store approval or a claim
that physical iPad validation is complete. [The privacy policy](PRIVACY.md) is
available in Settings and bundled for offline reading.

The interface builds on the [0.2 UI stage](docs/UI-0.2.md):
navigation uses a single row of tab/address capsules with persistent Back,
conditional Forward, and Refresh/Stop inside the selected tab. Wide windows on
iPad and an open iPhone Duo add a Library sidebar (Bookmarks, History, Downloads);
tabs stay in the navigation bar unless Settings › Tabs › Show tabs in sidebar is
on. Where iOS places bars on the side (iPhone Duo's outer display and open
landscape), Back, Forward, Tabs and More move to a side rail, and controls stay
clear of the fold. Layout follows size classes, not the device model. Custom
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
- Native downloads that ask first, with progress, completion notices, retry and resume, restart recovery, search, preview, cancellation, sharing, and confirmed file deletion.
- Find in page with live results, accessible controls, and per-tab desktop/mobile website switching.
- Link menus for new regular/private tabs; links opened from private pages retain private browsing.
- User-activated email, phone, and message links require confirmation before opening another app; private tabs warn that their protection does not extend outside Acute.
- Invalid or unsupported typed addresses show explicit feedback instead of silently doing nothing.
- Editable bookmarks with folders and HTML import/export, editable start-page favorites, searchable bookmarks/history, and local address suggestions.
- Keyboard shortcuts for address focus, reopening tabs, navigation, page search, tab switching, zoom, and the start page.
- Page-load errors and terminated website processes with explicit retry and cancellation of pending website prompts.
- Native website alert, confirmation, and text-input dialogs with per-tab cancellation.
- Allow-once or always-allow-per-site prompts for website camera and microphone access, cancelled when their tab closes, navigates, or loses selection.
- Persistent user-created bookmarks and browsing history that is off by default.
- Crash-safe restoration for regular pages and start-page tabs, preserving selection and website viewing preferences, with a user-controlled startup toggle.
- Private tabs excluded from saved sessions, recent sites, browsing history, and closed-tab recovery.
- Confirmed bulk closing for regular, private, or all tabs, with a start-page fallback if no tabs remain.
- Confirmed clearing of regular cookies, caches, and website storage without deleting private browsing or saved browser content.
- Private browsing is covered while the app is inactive for app-switcher snapshots whenever any private tab is open.
- Per-site controls for tracker blocking, JavaScript, media capture, and local website data, with a Site Settings review list. Private-tab changes are never saved.
- A clear privacy settings surface documenting Acute's zero-telemetry behavior.
- An App Store privacy manifest declaring no tracking or collected data.

## Keyboard controls

| Action | Shortcut |
| --- | --- |
| Next / previous tab | Control-Tab / Control-Shift-Tab |
| Zoom in / out | Command-= / Command-- |
| Reset zoom | Command-0 |
| Start page | Command-Shift-H |
| Find next / previous | Command-G / Command-Shift-G |
| Go to tab 1–8 / last tab | Command-1…8 / Command-9 |

Page commands follow the selected tab's current navigation and zoom state.

## Device testing artifact

After the iPhone, iPad and iPhone Duo simulator jobs pass, GitHub Actions builds the Release app for arm64
iPhones and iPads and uploads `acute-web-unsigned-ipa`. The artifact contains
`AcuteWeb-unsigned.ipa`, its SHA-256 checksum, the source commit/build number and
the release notes. The IPA must be signed with your Apple Account (Xcode or a
sideloading tool) before installation; see [the release notes](RELEASE-NOTES.md).
Running the **Build** workflow on `main` from the Actions tab (Run workflow), or pushing a
version tag such as `v0.5.0` that matches `MARKETING_VERSION`, publishes the same files as a
GitHub pre-release on the [Releases page](https://github.com/iiankehn/acute-web-ios/releases)
once every job passes. A manual run creates the `v` + `MARKETING_VERSION` tag itself. It is a
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
Acute on iPhone and iPad simulators, runs portrait and landscape layout tests on
iPad and iPhone Duo, runs accessibility audits in light and dark mode, and retains the test result bundles.
Visual review uses physical-device testing; routine screenshots are not captured.
The XCUITest suite
also covers privacy settings, private browsing, history, rotation, tab management,
and start-page customization. CI uses Xcode 27.1 on GitHub's Xcode 27 preview image: iPhone and iPad tests run
on the iOS 27.0 simulator, and an iPhone Duo job runs on the iOS 27.1 simulator
(the Duo's launch release, which supports only that device). Building locally
also needs Xcode 27.1.
The minimum supported system stays iOS 18, but iOS 18–26 are not tested (Xcode 27.1
cannot download older simulator runtimes and no such device is available), so
testers use those versions at their own risk. CI does not sign builds; TestFlight
would need a paid Apple Developer Program membership, which the project does not
use yet. Failed tests are not retried; unit tests run
twice, with the simulator restarted between runs, and both runs must pass.
