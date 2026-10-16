# 0.2 beta readiness gate

Reviewed against Apple's public guidance on October 14, 2026. This is an
engineering checklist, not certification of compliance or a promise of approval.
App Review Guidelines are submission requirements; Human Interface Guidelines
guide the design and accessibility review. Recheck both before submission.

The direction is now release hardening. Freeze feature scope: no Android parity,
new engines, accounts, extension systems or iPhone duo-specific work for this beta.
Keep Acute's identity while using native platform conventions and Liquid Glass
for controls/navigation, not decorative glass on every content surface.

## Current evidence and first audit findings

Build 84 validated the merged hardening baseline: 66 unit tests, 24 interface
tests, six validator tests, iPhone/iPad launches and unsigned arm64 IPA packaging.
The bundled policy, required-reason declarations, debug-fixture exclusion and
keyboard registration checks passed. Later changes need their own branch CI.

- Downloads reads `contentModificationDate` inside the app container. The manifest
  declares FileTimestamp with reason C617.1 and UserDefaults with reason CA92.1.
  Neither use is for fingerprinting.
- PRIVACY.md describes retention, backups, third-party boundaries and contact.
  The same document is bundled for offline Settings access, with a public link.
- Recovery disclosures acknowledge operating-system backups rather than claiming
  saved data can only exist on the current device.
- CI validates actual built bundles: required reasons, no tracking/collected-data
  declarations, bundled policy, camera/microphone descriptions, versions, and
  no unreviewed ATS exceptions. Scan Release executables for debug fixture
  markers. These scoped checks do not discover every API use or private API.
- Outer job budgets are 35 minutes (iPhone suite) and 20 minutes (iPad) after
  Build 83 spent about 10 minutes starting a cold test host and was cancelled
  at its earlier job boundary. Test assertions and per-test waits remain intact.
- Acute replaces the native appSettings command group and keeps the Library
  Settings entry without a second Command-comma shortcut. CI rejects duplicate
  keyboard-registration warnings; Build 84 passed this check. This does not
  establish full physical-keyboard behavior.
- No telemetry SDK, account service, background mode or alternate engine was
  found in this source pass. WebKit is used, fraudulent-site warnings are on,
  and private stores are non-persistent. These are source findings, not proof
  of all runtime privacy behavior.

## Blocking gates before beta distribution

| Area | Gate / required evidence | Status |
| --- | --- | --- |
| Completeness (2.1) | Final candidate's full CI and IPA checks pass; review retries and failures, never merge a red candidate | Required for each candidate |
| Privacy (5.1.1) | Bundled and public policy match shipping behavior; maintainer reviews identity, contact route and retention disclosures; public URL resolves without login | Build 84 validated code/resources; maintainer/metadata review pending |
| Privacy declarations | Verify required-reason API inventory on the final binary/SDKs; review Xcode privacy report and App Store Connect privacy answers, including browser/search/provider boundaries | Manual final review pending |
| Native utility / identity (4.1, 4.2) | Preserve original cat-fox branding and useful browser features; no Safari impersonation or unsupported marketing claims | Source reviewed; device review pending |
| Design / accessibility | Readable light/dark and Increase Contrast; Reduce Transparency/Motion; Dynamic Type through accessibility sizes; VoiceOver/Voice Control; keyboard focus; no hidden critical navigation or clipped controls | Physical-device audit pending |
| iPhone / iPad | Portrait/landscape, top/bottom phone controls, safe areas, keyboard appearance, iPad narrow windows/Split View, pointer and menu/shortcut behavior | Real iPad interactions unverified |
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

The next accessibility batch adds Apple's XCTest accessibility audits for the
native start page and Settings (top and bottom). It checks contrast, Dynamic
Type, hit regions, descriptions, clipping and traits, using actual simulator
light/dark appearances. It does not audit third-party websites or establish
physical VoiceOver, iPad, Reduce Transparency or all-text-size conformance.
Audits fail on reported issues; no issue-suppression handler is installed.
The start-page subtitle and attribution use primary text for clearer contrast, and the
tab count uses scalable caption text instead of a fixed eight-point font.
Build 86 passed all 24 existing functional UI tests but the new audits found
start-page subtitle contrast failures and near-threshold Settings Done contrast
in light and dark appearances. The follow-up gives the accent separate light,
dark and increased-contrast variants, with a unit check against native opaque
surfaces. Audit diagnostics report element labels and detailed issues without
suppressing failures. CI runs both appearance audits before the long functional
suite, which remains mandatory before IPA packaging; a failed audit stops that
later work. Material-backed controls still require actual UI audits;
the color calculation alone does not validate their composited appearance.
This batch is pending its own CI validation.

Build 87 passed 67 unit tests, including the resolved-palette contrast check,
and iPad launch. The start-page contrast failures were resolved, but complete
audits exposed more Settings contrast, Dynamic Type and picker-value clipping
issues. The follow-up uses explicit scalable primary text for Settings headings,
details and values, a wrapped search-engine row with a native selection list,
and a shared plain Done control with body text and a 44-point minimum target.
Favorite tiles give their untruncated text more width. Tabs exposes one
VoiceOver element with the full open count, rather than a redundant text child.
These changes require another complete candidate run; Build 87 is not a pass.

Build 88 passed 67 unit tests and iPad launch; the picker clipping report was
removed, but Settings contrast and some Dynamic Type reports remained. Explicit
semantic label colors now replace relative inherited foreground styles, and
destructive Settings actions use a separate adaptive contrast-checked red.
A largest-text UI regression measures favorite-title and Settings-description
growth and checks navigation remains usable. The audit remains fully enabled;
no remaining font report is classified as a framework false positive without
evidence. Build 88 is not a passing candidate.

Build 91 compiled the native app/test targets, passed unit tests and iPad
build/install/launch. Its native checkmark confirmation no longer produced the
previous Done-control findings. Settings contrast and Dynamic Type audits still
failed; browser interface tests and IPA generation were skipped. It is not a
passing candidate. Screenshots include text beneath the native navigation blur
and readable semantic labels; these findings need diagnosis, not blanket ignores.

The next validation separates contrast from Dynamic Type audits, measures all
three favorite titles and the Settings explanation across every supported text
size, and verifies the Tabs control exposes its count. Browser interface tests
now run independently of audit outcomes to collect menu regression evidence.
Audit failures still fail the simulator job and block device IPA generation.
No audit category or issue is suppressed by this change.

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
- XCTest accessibility audits: https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)
