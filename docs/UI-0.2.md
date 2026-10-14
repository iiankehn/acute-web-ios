# Acute Web 0.2 UI direction

0.2 develops Acute's own browser layout using Apple's Liquid Glass APIs and
native interactions. It is a development version, not a published release.

- iPhone: a single row of glass capsules combines tabs, address and navigation.
  Back stays visible; Forward appears when available. The selected capsule has
  Refresh/Stop and shows its address field during loading/editing or its title
  after rendering. Other tabs are separate capsules in the same horizontal row.
- iPad: the same single row stays at the top, with a sidebar in wide windows.
  Native SwiftUI commands organize the iPadOS menu bar into Tabs, Navigate, Page
  and Library, retaining keyboard shortcuts on earlier supported systems.
- Group custom navigation glass with `GlassEffectContainer` on iOS 26; retain
  system material fallbacks on iOS 18/19. Respect Reduce Motion.
- Keep the clear cat-fox branding and an Acute layout distinct from Safari.
- Defer iPhone duo-specific optimization.

## Verification

CI exercises phone condensation/expansion using a local HTML fixture, existing
rotation/navigation workflows, and iPhone/iPad launches. Visual review and device
checks still need light/dark mode, Reduce Transparency, increased text size,
VoiceOver, keyboard/pointer use, narrow iPad windows and real website loads.

The next UI batch compacts the start-page brand header and favorites, exposes
bookmark addresses, and uses simple system content surfaces rather than glass
on every card. The tab switcher uses larger previews, open/private counts and
accessibility-size card widths. iPad sidebar actions open Library and Downloads.
Library and Downloads now use consistent inset lists, readable multiline titles
and addresses/filenames, accent icon tiles and compact native navigation titles.
Site Privacy identifies the current host and regular/private mode above its
controls. Physical-device visual review remains in scope for 0.2.
Settings and the bookmark editor use compact native titles and clearer form
sections. The capsule row follows tab selection and scales its height with text
size. Additional capsules scroll horizontally instead of creating another row.
Custom glass controls use opaque system surfaces with Reduce Transparency.
Toolbar labels define their full 44-point hit areas. Find-in-page uses the
same navigation surface, with a local-page test covering find/close behavior
from condensed phone controls.
The address/navigation layer floats over WebKit content, letting Liquid Glass
sample the actual page as it scrolls beneath the bar. Measured scroll insets
keep the page's initial position accessible and preserve scrolled positions
when navigation changes height. Start pages and load errors reserve readable
space beneath navigation. Reduce Transparency still uses an opaque surface.
The condensed phone address capsule identifies the selected page by title and
host. Editing adds a Clear Address control that keeps keyboard focus and clears
only the draft, without unloading the current page. Reload/Stop remains inside
both expanded and condensed address bars, including during editing. Failed loads
use the existing retry path; empty start pages disable the page-load control.

## Device validation status

The Home Screen icon now uses a layered Icon Composer bundle: transparent,
neutral silver cat-fox art with generous padding, a neutral system-rendered background,
and restrained lighting. iOS applies the user's Home Screen appearance/tint.
The icon must still be checked after installing the next IPA in default, dark,
clear and tinted Home Screen modes; no device appearance result is claimed.

iPhone testing is available. iPad has only been built and launched in CI;
physical iPad testing has not yet been performed. Keyboard/pointer use, Split
View, resizing and visual appearance on a real iPad remain unverified.

## Browsing Layout preferences

Acute's settings offer Top or Bottom phone controls with small position previews,
optional automatic condensation, and page-title or address-only compact labels.
Preferences persist locally and update immediately. iPad retains its persistent
top navigation; phone-position preferences do not change its layout.

Download rows stack filenames and labeled actions at accessibility text sizes;
active transfers show an indeterminate activity indicator. More offers Tab
Management, Page Tools, Saved Content and Privacy submenus plus Settings.
Private-browsing guidance describes history,
recovery and retained downloads in plain language.
No public release is made by committing this first UI batch.

The transparent silver mark also appears on the start page, Settings and empty
tab previews. Brand headers stack at accessibility text sizes; saved-page and
tab titles gain space to wrap. Start-page search offers a Clear action that
keeps keyboard focus. Find results stack above their navigation controls at
large text sizes, and selected tabs expose the native VoiceOver selection trait.

The tab overview supports local title/address search and All, Regular and Private
filters, with visible/total counts and explicit empty states. At accessibility
text sizes the filter uses a menu to give labels space. The iPad sidebar also
searches open tabs; reordering is disabled while search results are filtered.
Search does not switch or close tabs, and bulk-close confirmations explicitly
include tabs hidden by filters. Metadata changes refresh results while pages load.
Empty tab-search results offer Clear Search directly; recovery does not depend
on whether the system search presentation includes a Cancel button.
Clear Search also ends native search presentation so the keyboard dismisses
and the overview's Done action returns. Regression coverage checks that exit.

Loading progress sits inside the address capsule alongside the persistent Stop
control. Failed pages identify the requested host and provide Retry, Edit Address
and Start Page actions. The error content scrolls beneath the selected navigation
position; recovery actions wrap vertically when space or text size requires it.
A local failure fixture covers editing the draft and returning to the start page
without depending on a real website or network failure.

Phone layout choices include a visible checkmark, stronger selected outline and
VoiceOver selection trait. Their preview cards stack at accessibility text sizes.
Site connection headers also stack and wrap long host names. Global and per-site
website-data clearing actions show activity while their existing confirmations
and asynchronous deletion behavior remain in place.

Back and More remain outside the scrolling tab region. While editing, or on
very narrow phones with Forward visible, the separate overview button yields
space to the address; Show All Tabs remains in Tab Management. Page Tools offers
Done Editing. Inactive capsules support duplicate/close via their context menus;
the full overview retains search, regular/private filters and bulk confirmation.
Local interface fixtures cover same-row history controls and capsule switching.
The history fixture serves two real local documents through a debug-only WebKit
scheme handler, so Back/Forward assertions exercise the actual navigation list.
The add-tab capsule has a distinct accessible name from the New Tab menu action.

Library and Downloads share a Clear Search recovery action that ends native
search presentation, including searches of an empty collection. Library uses a
menu instead of cramped segments at accessibility text sizes. Bookmarks have a
visible 44-point edit action; the editor can clear the address without losing
focus and still disables Save for invalid addresses. Cancellation leaves the
saved bookmark unchanged. UI regression tests cover both search exits and the
bookmark editing/validation/cancellation flow. Branch CI must pass before merge;
physical iPhone and iPad presentation remains device-test work.

## Apple references

- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
