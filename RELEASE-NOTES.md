# Acute Web 0.5 beta

**Acute Web by CORE** — *The web, in focus.*

## How to get it: sideloading only

Acute Web 0.5 is not on the App Store or TestFlight. It is available only for
sideloading: you sign the app yourself and install it on your own iPhone or iPad.

You need:

- A free Apple Developer account. Signing in to Xcode or a sideloading tool with
  any Apple Account gives you one. A paid Apple Developer Program membership is
  not required.
- Tools to sign and install the app. Either a Mac with Xcode, or a sideloading
  tool that signs apps with your Apple Account (for example, AltStore or
  Sideloadly). Acute does not make or endorse these tools.
- An iPhone or iPad running iOS or iPadOS 18 or later.

### Install

1. Download `acute-web-unsigned-ipa` from a passing run of the **Build** workflow
   in this repository's GitHub Actions. You need to be signed in to GitHub, and
   each download is kept for 14 days.
2. Check the download against `SHA256SUMS.txt`, for example with
   `shasum -a 256 -c SHA256SUMS.txt`.
3. Sign and install `AcuteWeb-unsigned.ipa` with your tool and your Apple Account.
   If your tool reports that the bundle identifier is unavailable, let it assign
   one for your account.
4. On the device, turn on Developer Mode (Settings › Privacy & Security ›
   Developer Mode) and restart when asked. Then trust your developer certificate
   in Settings › General › VPN & Device Management.

### Limits of a free account

- Apps signed with a free account stop opening after 7 days. Re-sign and
  reinstall the app before then. Reinstalling over the existing app with the same
  bundle identifier keeps your bookmarks, settings and downloads; deleting the
  app removes them.
- A free account can have only a few sideloaded apps installed at once.
- Apple controls these limits and can change them.

## What's new in 0.5

### iPhone Duo

- Layouts follow the size of the window and where iOS places its bars, not the
  device model.
- When the phone is closed, or open in landscape, Back, Forward, New Tab, Tabs
  and More move to a side rail clear of the camera.
- Half-open like a book, no control sits on the fold. Half-open like a laptop,
  the page fills the top half and large controls sit below the fold.

### Sidebar and tabs

- On iPad and an open iPhone Duo, the sidebar holds Bookmarks, History and
  Downloads. Tabs stay in the navigation bar; Settings › Tabs › Show tabs in
  sidebar moves them to the sidebar.
- New Tab, New Private Tab, Show All Tabs and Reopen Closed Tab are at the top of
  the More menu, under a Tabs heading.

### Privacy and security

- The app-switcher cover hides the screen whenever any private tab is open.
  Private tabs share one temporary data store that ends with the last private tab.
- Downloads ask first and only for the visible tab. They show progress and can
  retry and resume.
- Plain HTTP pages show "Not Secure". Website dialogs are limited per tab and can
  be blocked.
- Tracker blocking covers more resource types, and Settings reports when the
  blocking rules fail to load.

### Browsing

- Back and forward history menus, pull to refresh, address suggestions from your
  bookmarks and history, HTTP sign-in prompts, and pages that open windows.
- Per-site camera and microphone permissions, with a Site Settings review list.
- Bookmark folders, HTML bookmark import and export, and editable favorites.
- iPad supports multiple windows.

## Known limitations

- This is a beta. It has passed automated tests on the iOS 27.0 and 27.1
  simulators but has not yet been fully tested on physical devices.
- iPhone Duo layouts are tested only in the simulator, not on a real iPhone Duo.
  If something looks wrong on yours, please report it.
- Downloads stop if iOS suspends Acute for longer than its allowed background time.
- The interface is in English only.
- Acute cannot be set as the default browser.

Report problems through [GitHub Issues](https://github.com/iiankehn/acute-web-ios/issues).
Issues are public, so do not include browsing history or other private details.

Acute collects no telemetry or analytics. See [the privacy policy](PRIVACY.md),
which is also in Settings.
