# Acute Web 0.2 — sideload beta candidate

Prepared October 16, 2026. This is a candidate for device acceptance, not a
published beta. No new app features or UI changes are included in this preparation.

## Candidate identity

| Field | Value |
| --- | --- |
| App version / build | 0.2.0 / 85 |
| Source | `4b24698eba49c574799aeeba37032c31888b2c27` |
| Build | [GitHub Actions Build 85](https://github.com/iiankehn/acute-web-ios/actions/runs/38687122320) |
| Device artifact | [Unsigned IPA archive](https://github.com/iiankehn/acute-web-ios/actions/runs/38687122320/artifacts/11951626110) |
| Bundle identifier before signing | `com.acuteweb.browser.ios` |
| Declared support | iOS/iPadOS 18 or later; ARM64 iPhone and iPad |
| Signing | Unsigned; the tester's sideloading tool must sign it |

Build 85 remains the app baseline. PRs #5 and #6 were closed at the owner's
request. Their accessibility/UI experiments are excluded. Do not resume that
investigation as part of launch preparation. Closing those PRs does not prove
that the baseline is free of accessibility defects.

The original artifact archive's SHA-256 is
`21c1ef04c45c9701fe52fa80386d374de00abfe8bb5ccd3acb05d6429d62d763`.
Its `SHA256SUMS.txt` identifies the unchanged IPA. Re-signing changes the file;
record any distributed signed file's checksum separately.

## Install for acceptance testing

1. Download and extract the candidate package. Select `AcuteWeb-unsigned.ipa`,
   not the outer ZIP, in your existing sideloading tool's IPA import flow.
2. Use your working signing setup. If updating an existing installation, retain
   the same signing identity and app identity where supported. Do not uninstall
   it to troubleshoot an update: that can remove its local data.
3. Open Acute and confirm Settings shows `0.2.0 (85)`. A signing tool may rewrite
   identifiers; record that fact with the test results.
4. Complete the device checks below. Keep credentials and private browsing
   content out of screenshots, logs and public issue reports.
5. Follow the signing tool's refresh/expiration guidance. Signing and refresh
   behavior are separate from Acute's browser functionality. See the
   [official AltStore Classic guide](https://faq.altstore.io/altstore-classic/your-altstore).

Installing an older build over a newer development build is a downgrade.
Acceptance must confirm saved data survives; this preparation does not establish
backward data compatibility or guarantee a sideloading tool accepts that update.

## Evidence already available

| Layer | Evidence | Limit |
| --- | --- | --- |
| Source | Build 85 commit fixed; restored checkout matches it | Later archived changes are not included |
| Compilation | Native app/test compilation, iPad simulator build and Release device build passed | Does not establish all supported OS/device behavior |
| Automated tests | Unit job succeeded with retries; 24 interface tests passed without failures; six validator tests passed | Download and cookie fixtures timed out in earlier unit executions; not a clean first-pass unit run |
| Simulator | iPhone/iPad install and launch checks passed | Not physical-device verification |
| Packaging | Original archive/IPA checksums, ZIP integrity, arm64 Mach-O device platform, version, privacy manifest, bundled policy equality and Release debug-fixture checks verified | IPA is unsigned; no physical install/upgrade result is inferred |
| Device acceptance | Pending for this exact candidate | Prior on-device builds do not validate Build 85 |

## Device acceptance record

Use an iPhone and an iPad. Record device, OS, version/build, signing tool,
installation type (fresh/update/downgrade), date and pass/fail with each result.
Use test content only. Record failures as known issues; do not mark untested
rows passed. The maintainer performs these checks on physical devices.

| Check | Expected result | iPhone | iPad |
| --- | --- | --- | --- |
| Install/update and relaunch | Opens as 0.2.0 (85); existing bookmarks, settings and downloaded files survive an update/downgrade | Pending | Pending |
| Address, search and navigation | HTTPS page and search load; Back/Forward, Reload/Stop, edit/clear address and tab switching work | Pending | Pending |
| Phone/tablet layout | Portrait/landscape, keyboard and phone top/bottom controls remain usable; iPad sidebar/narrow window and keyboard/pointer work where available | Pending | Pending |
| Saved content | Add/edit a bookmark; enable history, visit a test page, find and clear that history; relaunch and confirm intended persistence | Pending | Pending |
| Download recovery | Download a harmless file; open/share it, relaunch and reopen it; delete it and confirm it is gone from Acute and its Downloads folder | Pending | Pending |
| Private isolation | Private test page stays out of history/recovery; private tabs are covered when inactive and absent after force-quit/relaunch | Pending | Pending |
| Website-data clearing | Regular test cookies clear after confirmation; open private session and bookmarks/downloads remain intact | Pending | Pending |
| Website permissions | Camera/microphone allow and deny choices are site-specific; closing/switching the requesting tab cancels outstanding prompts | Pending | Pending |
| Readability and controls | Check light/dark, large text, VoiceOver labels/actions, Reduce Transparency and Reduce Motion; report unusable controls | Pending | Pending |
| Recovery | Offline/failed page offers usable retry/edit actions; returning online recovers without losing saved data | Pending | Pending |

## Publication gate

Preparation is complete when the candidate package and notes are available.
Public beta distribution is still blocked on the device record and maintainer
approval of the known limitations. No App Store/TestFlight submission is part
of this sideload launch.

After acceptance, prepare a GitHub prerelease referencing the exact Build 85
commit, attach the unchanged unsigned IPA, checksum and release notes, and keep
it explicitly marked beta. Check support/privacy links and download integrity.
Review the draft before publishing; update any website only after the download
is live. Do not tag this documentation branch as the binary's source.

If device acceptance exposes a launch blocker, isolate that reproducible defect
on a new branch from the restored baseline. Do not reopen the shelved UI work.
