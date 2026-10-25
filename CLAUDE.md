@../brain/CORE.md

# Acute Web for iOS and iPadOS

Native SwiftUI browser shell on WebKit, with no third-party runtime dependencies.
Current line: 0.5 sideload-only beta (no App Store or TestFlight). Shared CORE
context is imported above from the `brain` repo; if it is missing, ask the user
to clone `iiankehn/brain` beside this repo.

## Commands

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'   # release-validator tests; runs anywhere
xcodegen generate                                         # macOS only
xcodebuild -project AcuteWeb.xcodeproj -scheme AcuteWeb \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build   # macOS + Xcode 27.1 only
```

Cloud containers are Linux: Swift cannot be built or tested here. The **Build**
workflow on the PR is the test run (iPhone, iPad and iPhone Duo simulator jobs,
then an unsigned IPA). Read code carefully and reason about compile errors
before pushing. Each CI round trip costs about 30 to 55 minutes.

## Layout

| Path | Purpose |
|---|---|
| `project.yml` | Source of truth for the Xcode project, `MARKETING_VERSION` |
| `AcuteWeb/Browser`, `Model`, `Views`, `Commands` | App code (`BrowserStore`, `BrowserTab`, `PermissionBroker`, ...) |
| `AcuteWeb/PrivacyInfo.xcprivacy` | Privacy manifest; `scripts/validate_release.py` enforces it |
| `AcuteWebTests/` | Unit tests (XCTest) |
| `AcuteWebUITests/` | Interface, layout (`AcuteWebLayoutUITests`) and accessibility audits (`AcuteWebAppearanceUITests`) |
| `docs/ARCHITECTURE.md`, `docs/BETA-READINESS.md` | Architecture and the current release gate |

## Rules

- Scope is frozen for 0.5 beta hardening (`docs/BETA-READINESS.md`): no Android
  parity work, new engines, accounts or extension systems. Record such ideas in
  `../brain/projects/acute-web.md` instead.
- Layout follows size classes and the system bar edge, never device model.
  Liquid Glass on iOS 26+ for controls and navigation only, with material fallbacks.
- Private tabs use a non-persistent `WKWebsiteDataStore` and never reach
  history, sessions, recent sites or closed-tab recovery.
- Any new API use that needs a required-reason entry must be added to
  `PrivacyInfo.xcprivacy` and `EXPECTED_REASONS` in `scripts/validate_release.py`.
- Minimum system is iOS 18, but only iOS 27 is tested. Say so; never imply otherwise.
- Do not relax test assertions or per-test waits to get CI green. Read
  `../brain/learnings/ci.md` before touching the workflow.
- Commit messages: plain imperative sentence, no prefix
  (e.g. "Restart the simulator before the browser interface tests").

## Skills

- `acute-ios-ci-triage`: diagnose a failing Build workflow run.
- `acute-ios-release`: bump the version and publish a sideload pre-release.
