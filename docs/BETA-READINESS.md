# 0.2 beta readiness gate

Reviewed against Apple's public guidance on October 14, 2026. This is an
engineering checklist, not certification of compliance or a promise of approval.
App Review Guidelines are submission requirements; Human Interface Guidelines
guide the design and accessibility review. Recheck both before submission.

The direction is now release hardening. Freeze feature scope: no Android parity,
new engines, accounts or extension systems for this beta. iPhone Duo support was
added to scope on October 22 because the device ships October 23 (see below).
Keep Acute's identity while using native platform conventions and Liquid Glass
for controls/navigation, not decorative glass on every content surface.

## Current evidence and first audit findings

Build 81 validated the prior merged baseline: 64 unit tests, 23 interface tests,
iPhone/iPad launches and unsigned arm64 IPA packaging. It does not validate the
changes in this audit batch. Their own branch CI must pass before merge.

- Downloads reads `contentModificationDate` inside the app container. The manifest
  previously declared only UserDefaults. Add FileTimestamp with reason C617.1;
  retain UserDefaults reason CA92.1. Neither use is for fingerprinting.
- The existing privacy baseline lacked an in-app policy entry and complete
  retention/backup/contact explanations. Expand PRIVACY.md and bundle the same
  document for offline reading via Settings, with a current public-policy link.
- Replace the absolute recovery claim "only on this device" with local-storage
  wording that acknowledges operating-system backups.
- Validate actual built bundles: required reasons, no tracking/collected-data
  declarations, bundled policy, camera/microphone descriptions, versions, and
  no unreviewed ATS exceptions. Scan Release executables for debug fixture
  markers. These scoped checks do not discover every API use or private API.
- Branch Build 83 passed 66 unit tests (including both new policy tests), all
  five validator tests, and iPad build/install/launch. Cold iPhone test-host
  startup consumed about 10 minutes before the unit suite itself ran in about
  34 seconds. The UI run was cancelled at the 20-minute job boundary after four
  passing cases; no full UI/IPA success is claimed. Increase only the outer job
  budgets to 35 minutes (iPhone suite) and 20 minutes (iPad), without relaxing
  test assertions or per-test waits, then validate the new candidate in full.
- The same log exposed duplicate Command-comma registrations: the system
  Settings item and Acute's Library Settings command. Replace the native
  appSettings command group with Acute's Settings action and keep the Library
  entry without a second shortcut. Capture test logs and fail validation if
  UIKit reports duplicate keyboard shortcuts. This is registration coverage,
  not a claim of full physical-keyboard testing.
- No telemetry SDK, account service, background mode or alternate engine was
  found in this source pass. WebKit is used, fraudulent-site warnings are on,
  and private stores are non-persistent. These are source findings, not proof
  of all runtime privacy behavior.

## October 21 audit batch

A source audit of interface, usability, completeness, security and privacy found
the issues below. This batch addresses them in code. It was written without a
local Xcode toolchain, so its branch CI is the first compile and test run; none
of it is device-verified yet.

- Privacy: the app-switcher cover now applies whenever any private tab exists,
  because private titles appear in the tab row, sidebar and overview. Site
  Privacy changes made in private tabs stay in memory and end with private
  browsing. Private tabs share one non-persistent store, released with the last
  private tab.
- Downloads ask first, only for the visible tab in the active window; hidden
  frames cannot start them. Progress, size, a completion notice, retry/resume
  and a background-time request were added. Downloads still stop if iOS
  suspends the app for longer than the granted background time.
- Website dialogs are limited per tab and can be blocked until the page changes.
- Connection security is derived from `hasOnlySecureContent` as well as the
  scheme, plain HTTP shows "Not Secure", and private tabs keep the indicator.
- WebKit policy interruptions (102/204) no longer replace pages with an error;
  common failures have plain-language explanations; HTTPS connection failures
  can retry over HTTP after a warning. Certificate failures never offer this.
  Whether WebKit permits plain HTTP without an ATS web-content exception still
  needs a device check; no ATS exception was added.
- Typing in the address field is no longer overwritten by page changes. Restored
  background tabs load when first selected; tabs whose content process was
  reclaimed reload when selected.
- Tracker rules also cover media, fonts, pings and embedded tracker frames, and
  a rule-compilation failure is shown in Settings instead of being silent.
- Added HTTP authentication prompts, website-opened windows that keep
  `window.opener` and close themselves, always-allow camera/microphone per site,
  queued permission prompts, a Site Settings review list (with www treated as
  the same site), back/forward history menus, pull to refresh, local address
  suggestions, select-all on focus, tab-capsule close buttons, Command-G and
  Command-1…9, editable favorites, bookmark folders and HTML import/export, and
  a prompt to clear history when saving is turned off.
- Accessibility: the tab-count badge and tab capsules scale with Dynamic Type.
- Release: iPad multiple windows (shared library, separate tabs per window),
  `ITSAppUsesNonExemptEncryption = NO`, a string catalog for localization
  (translations are not included), test isolation through injected defaults,
  and CI no longer retries failed tests.

## October 22 iPhone Duo batch

iPhone Duo work moved into scope. Following Apple's Duo guidance, the app now
chooses layouts from size classes and the system's vertical-bar edge instead of
the device model. Where iOS places bars on the side, navigation buttons move to a
side rail that avoids the outer camera. Controls stay clear of the fold, and
tabletop posture uses a control deck below the fold. The wide-window sidebar is
now the Library on both iPad and iPhone Duo, with an opt-in Tabs section. CI
moved to Xcode 27.1 on GitHub's Xcode 27 preview image. iPhone and iPad run on the
iOS 27.0 simulator because the iOS 27.1 simulator runtime supports only iPhone Duo;
a new iPhone Duo job downloads that runtime. Rail-edge choice and fold behavior still need checking in Device
Hub and on a device; the CI simulator boots in a single pose.

## Blocking gates before beta distribution

| Area | Gate / required evidence | Status |
| --- | --- | --- |
| Completeness (2.1) | Final candidate's full CI and IPA checks pass; review retries and failures, never merge a red candidate | Required for each candidate |
| Privacy (5.1.1) | Bundled and public policy match shipping behavior; maintainer reviews identity, contact route and retention disclosures; public URL resolves without login | Audit changes pending validation/review |
| Privacy declarations | Verify required-reason API inventory on the final binary/SDKs; review Xcode privacy report and App Store Connect privacy answers, including browser/search/provider boundaries | Manual final review pending |
| Native utility / identity (4.1, 4.2) | Preserve original cat-fox branding and useful browser features; no Safari impersonation or unsupported marketing claims | Source reviewed; device review pending |
| Design / accessibility | Readable light/dark and Increase Contrast; Reduce Transparency/Motion; Dynamic Type through accessibility sizes; VoiceOver/Voice Control; keyboard focus; no hidden critical navigation or clipped controls | Physical-device audit pending |
| iPhone / iPad | Portrait/landscape, top/bottom phone controls, safe areas, keyboard appearance, iPad narrow windows/Split View, pointer and menu/shortcut behavior | Real iPad interactions unverified |
| iPhone Duo | Closed and open in both orientations, half-open book and tabletop, rail edge and camera clearance, fold avoidance, Library sidebar and Show tabs in sidebar, Split View on the inner display | Device Hub and device checks pending |
| Supported OS | Exercise the oldest supported iOS 18 and currently shipping iOS/iPadOS on available devices/simulators; SDK compilation and iOS 26.2 CI alone do not establish compatibility | Pending |
| Browsing | Real HTTPS sites, redirects, history navigation, slow/offline recovery, IPv6-only network (2.5.5), login, file uploads, media and downloads | Device matrix pending |
| Consent / isolation | Camera/mic allow/deny/revoke, cancellation, inactive-tab handling, private/regular isolation, app-switcher shield with sheets, data clearing and relaunch | Automated core coverage; device validation pending |
| Installation / updates | Install and update final signed candidate without unintended loss of bookmarks/settings/downloads; confirm displayed version/build and icon appearances | Final candidate pending |
| Distribution | Pick sideload testing or TestFlight explicitly. Current unsigned IPA is not an App Store archive. TestFlight needs appropriate distribution signing, App Store Connect setup and beta review where applicable | Not configured by this audit |
| Listing / review | Accurate privacy/support URLs, age rating for unrestricted web access, copyright, current screenshots, review contact, export-compliance answers and review notes | Not submitted |

Do not mark a pending gate passed because the UI looks good or CI is green.
Do not claim default-browser support without its required entitlement and setup.
The app has no Acute account system; account deletion rules must be re-evaluated
if that changes. Search, camera/mic and network access must remain contextual,
with clear purpose descriptions and system permission enforcement.

Normal development still avoids routine screenshots. If App Store/TestFlight
metadata requires visual assets, prepare accurate candidate-specific assets as
a separate submission task. Do not publish a beta as a finished App Store app.

## Defect and release policy

- Block beta for crashes, data loss, private-data leaks, misleading disclosures,
  unusable primary navigation, inaccessible core actions and incomplete review
  metadata/signing for the selected distribution path.
- Fix findings in coherent batches on branches; add regression coverage where
  practical. Merge only after checking the exact candidate's full CI results.
- Keep a device-test record with candidate/build, OS/device, steps, result and
  unresolved issues. Never infer physical iPad results from the CI launch check.
- Re-audit privacy, permissions, HIG behavior and metadata whenever a change
  affects them. Do not add analytics or automatic support uploads.

## Apple references

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Designing for iOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- Adopting Liquid Glass: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- Required reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Approved API categories/reasons: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Settings command placement: https://developer.apple.com/documentation/swiftui/commandgroupplacement/appsettings
