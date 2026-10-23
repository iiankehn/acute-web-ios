# Acute Web Architecture

Acute Web is a native SwiftUI application with WebKit providing the rendering,
networking, storage, and web-content process boundary required on iOS and
iPadOS.

## Browser state

`BrowserStore` owns tab selection, session-only recent sites, closed-tab
recovery, and shared preferences. Each `BrowserTab` owns exactly one
`WKWebView`. Regular tabs use WebKit's default website data store; private tabs
use a non-persistent store.

## Privacy boundary

Acute does not add a browsing proxy, account service, analytics SDK, telemetry
pipeline, or remote rule-classification service. Tracker protection is compiled
into a `WKContentRuleList` and evaluated inside WebKit. Search queries go only
to the search provider selected by the user. `PermissionBroker` defaults media
capture requests to denial until an allow-once prompt is accepted.

`BookmarkStore`, `HistoryStore`, and `SitePrivacyStore` keep their small Codable
models in local application preferences. History persistence is opt-in and the
recording path rejects private tabs before reaching `HistoryStore`. Per-site
JavaScript decisions are applied through `WKWebpagePreferences`; media blocking
is enforced before presenting the allow-once permission broker.

## Platform behavior

`BrowserChromeMode` chooses the controls from size classes and the system's
vertical-bar edge: a compact capsule row, a wide row, or a side rail.
`FoldLayout` turns iPhone Duo's reserved fold regions into book or tabletop
layouts. Regular-width windows use a split view whose sidebar is the Library
(with an optional Tabs section). SwiftUI materials provide the compatibility
appearance on older systems; Liquid Glass is used for the custom controls.
WebKit provides native find, download, and preferred-content-mode behavior;
downloads remain in the app's local Documents container.

## Build model

`project.yml` is the source of truth for the Xcode project. GitHub Actions uses
XcodeGen, Xcode 27.1, iOS 27.0 iPhone and iPad simulators and an iOS 27.1 iPhone Duo
simulator, chosen by
`scripts/select_simulator.py`. The iPhone job runs unit and interface tests, the
iPhone Duo job runs unit tests and the layout interface tests, and the iPad job
runs the layout interface tests and launches the app. The layout tests
(`AcuteWebLayoutUITests`) check portrait and landscape. `AcuteWebAppearanceUITests` runs
accessibility audits in light and dark mode and checks the largest text size. An iOS 18
job repeats the unit and interface suites on the oldest supported system, and version
tags publish the IPA as a GitHub pre-release. Visual review uses the
physical device without routine screenshot capture. Only after those jobs pass does CI package an unsigned arm64 IPA
from a Release device build. Device signing and installation are separate.

The [0.1 foundation gate](FOUNDATION-0.1.md) distinguishes automated coverage
from the real-device checks required before calling the product complete.
