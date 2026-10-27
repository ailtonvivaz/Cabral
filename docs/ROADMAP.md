# Roadmap

Ideas gathered from [OpenIn 4](https://loshadki.app/openin4/) and [Choosy](https://choosy.app/). None of these are in 0.1.0 (see [CHANGELOG](../CHANGELOG.md)). Criterion: keep the app clean, with few rules, easy to understand.

## Next (cheap, no new screens)

- **More languages.** The String Catalog ships English and pt-BR; new languages are a good first contribution.
- **Modifier forces the picker** (OpenIn). Holding ⌥ while opening a link shows the picker even when a rule matches. Implementation: check `NSEvent.modifierFlags.contains(.option)` in `LinkHandler.handle` and treat it as `.ask`.
- **Strip trackers** (OpenIn). A single "Strip trackers" switch in Settings: removes `utm_*`, `fbclid`, `gclid`, `mc_eid` and similar from the query before opening. No configurable list.
- **Running browsers first in the picker** (Choosy). No filtering; browsers that are running (`NSWorkspace.shared.runningApplications`) are sorted before the rest, so 1/2 land on the browser in use.

## v2

- **Rules by source app** (OpenIn, Choosy). E.g. `From: Slack → Chrome`. The source app is already captured (Apple Event `keySenderPIDAttr`) for the picker. Proposed precedence: a domain rule beats an app rule. Caveat: some apps send links through helper processes (e.g. Slack), so match on the bundle ID of the "parent" app.
- **Open native apps** (OpenIn). `zoom.us/j/…` → Zoom, `meet.google.com` → app, `music.apple.com` → Music (`music://`). In the UI, native apps become targets in the same action picker.
- **Chromium profiles.** Chrome/Edge/Brave/Vivaldi with `--profile-directory=<dir>` (profiles read from `Local State`). Arc and Safari stay profile-less (see [docs/notes/browser-profiles.md](notes/browser-profiles.md)). Validate with the browser running and quit, checking both profile and URL.
- **Private window** as a target (`--incognito` / `--private-window`), same mechanism as profiles.
- **Regex rules.** Match against the whole URL (host + path), in addition to suffix domain matching. Today `*` is not handled: `site.com*` is saved as-is and never matches.

## Maybe

- **macOS Focus** choosing the target (OpenIn Focus Hints). Only as an explicit, visible rule type, never implicit.
- **Browser extension** "send this tab to another browser" (Choosy). Separate project.
- **URL API** `cabral://open?url=…` for scripts/Raycast.

## Discarded

- JavaScript scripts and regex URL rewriting (OpenIn): powerful, but contrary to "easy to understand".
- Routing email, `tel:` and files: a different product.
- Share menu, AirDrop, Handoff: rare cases for the app's goal.
