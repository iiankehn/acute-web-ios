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

## Platform behavior

The application uses a compact tab grid on iPhone and a native split-view tab
sidebar on iPad. SwiftUI materials provide the compatibility appearance on
older systems; Xcode 26 builds adopt Liquid Glass for the custom address field.
WebKit provides native find, download, and preferred-content-mode behavior;
downloads remain in the app's local Documents container.

## Build model

`project.yml` is the source of truth for the Xcode project. GitHub Actions uses
XcodeGen and a generic iOS Simulator destination so compilation does not depend
on a specific simulator model being installed on the hosted runner.
