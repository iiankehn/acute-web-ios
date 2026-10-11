# Acute Web 0.1 foundation gate

0.1 is a standalone, functional iPhone/iPad browser, not an Android-parity release.
This checklist records implementation and verification separately. A feature
being coded does not mean it has passed the current build or device testing.

| Foundation | Implemented and automated coverage | Device checks still required |
| --- | --- | --- |
| Navigation and search | Address parsing, search providers, invalid-input feedback, retry and cancelled-navigation handling | Real websites, redirects, back/forward, keyboard and slow/offline connections |
| Tabs | Regular/private tabs, duplicate/reorder/reopen, bulk close, selection and last-tab fallback | Rapid switching, landscape, memory pressure |
| Session recovery | Regular pages/start pages, selection, zoom and desktop mode; legacy decoding and private exclusion | Force-quit/relaunch with multiple loaded pages |
| Bookmarks/history | Editing, search, persistence, URL validation, optional history and confirmed clearing | Add/edit/delete from real pages; verify private visits stay absent |
| Downloads | WebKit-to-file integration, staging, collision handling, recovery, preview/share/cancel/delete | Large files, interrupted transfers, Files sharing and Quick Look |
| Private browsing | Non-persistent stores, history/session/closed-tab exclusion, inactive-window shield | Sign-in isolation and app-switcher snapshot with sheets open |
| Website privacy | Compiled tracker rules, per-site JavaScript/media controls, regular/private data clearing isolation | Representative blocked resources and sign-out behavior |
| Permissions/dialogs | Allow-once media and alert/confirm/prompt queues; cancellation on lifecycle changes | Camera/microphone system permission prompts and file-upload forms |
| External links | Allowlisted activated links, confirmation/private warning and inactive-tab rejection | Email, phone and Messages handlers; no-handler failure |
| Keyboard/page controls | Find in page, zoom, desktop mode and keyboard commands | Physical keyboard, focus behavior and desktop-only sites |
| Adaptive/accessibility behavior | Native controls/labels, touch targets and portrait/landscape UI tests | iPad split view, large Dynamic Type, VoiceOver, light/dark contrast |
| Distribution | 0.1.0 metadata, privacy manifest and unsigned arm64 IPA after CI passes | Install/update on iPhone, preserve data, verify version/build |

## Release gate

- All unit and interface tests pass; any retries must be reviewed.
- iPhone and iPad simulator builds launch; the arm64 device package is valid.
- The device checks above are completed or a limitation is explicitly documented.
- No telemetry, diagnostics uploads, account service, or new platform-parity scope.
- UI visual polish follows foundational completion; functional accessibility/layout
  failures remain blockers rather than cosmetic work.

Password management, account sync, extensions, tab groups and read-aloud are
outside 0.1. This file is not a claim that the release gate has already passed.
