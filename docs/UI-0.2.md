# Acute Web 0.2 UI direction

0.2 develops Acute's own browser layout using Apple's Liquid Glass APIs and
native interactions. It is a development version, not a published release.

- iPhone: expanded address/navigation controls during loading or editing;
  successful page rendering condenses them to the site address, tabs and menu.
  Tap the address to edit/expand; navigation actions remain available in More.
  Start pages, failed loads and find-in-page keep full controls.
- iPad: persistent address/navigation toolbar and horizontal tab strip in wide
  windows, with a native sidebar. Narrow windows retain expanded controls.
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
sections. The iPad tab strip follows keyboard selection, honors Reduce Motion,
and widens for accessibility text sizes. When an iPad detail pane cannot fit
the single-row toolbar, its controls wrap above the persistent tab strip.
No public release is made by committing this first UI batch.

## Apple references

- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
