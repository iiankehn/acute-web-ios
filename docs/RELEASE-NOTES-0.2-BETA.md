# Acute Web 0.2 beta — draft release notes

**Candidate: 0.2.0 (85). Not published. Device acceptance pending.**

Acute Web by CORE is a native browser for iPhone and iPad, built with SwiftUI
and WebKit. This beta brings Acute's tab/address capsules, grouped page and
library actions, and native Liquid Glass controls on supported systems.

## Included

- A single navigation row with Back, conditional Forward, tab/address capsules,
  and Refresh/Stop. Phone controls can sit at the top or bottom.
- iPad sidebar navigation and native keyboard/menu commands.
- Bookmarks, optional browsing history, regular-tab recovery and private tabs.
- Downloads with preview, sharing, cancellation, deletion and recovery after
  relaunch; Find on Page, page zoom and desktop/mobile website requests.
- Search-provider selection, local tracker-blocking rules and per-site privacy
  controls. Browsing history is off by default.
- An in-app privacy policy and no Acute telemetry or automatic diagnostic uploads.

## Before installing

The download is an unsigned ARM64 IPA for iOS/iPadOS 18 or later. Sign and
install it with your sideloading tool. Signing, expiration and refresh behavior
depend on that tool and your setup. Preserve the existing installation when
testing an update; uninstalling can remove local browser data.

## Beta limitations

- Physical iPhone/iPad acceptance for this candidate is still pending. Declared
  iOS 18 support is not a claim that every supported OS/device has been tested.
- The unit-test job passed with retries after download/cookie fixture timeouts.
  Download recovery and website-data isolation require explicit device checks.
- The later experimental accessibility/UI branch is excluded. Accessibility,
  large text and iPad interaction quality are not certified by the passing CI.
- Private browsing does not conceal activity from websites or network providers.
  Downloaded or exported files remain until separately deleted. Tracker blocking
  uses a limited local host list and does not block all tracking.
- This build has no Acute cloud sync, handoff or private-tab locking. It is not
  an App Store or TestFlight release and does not claim default-browser support.

Report reproducible issues at
[GitHub Issues](https://github.com/iiankehn/acute-web-ios/issues), including the
build, device, OS and steps. Issues are public; omit credentials, private
addresses and browsing history. Read the
[privacy policy](https://github.com/iiankehn/acute-web-ios/blob/main/PRIVACY.md).
