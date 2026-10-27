# Contributing to Cabral

Thanks for helping. Cabral is a small app on purpose, so please read this first.

## Philosophy

The [roadmap](docs/ROADMAP.md) states the criterion for every change: *keep the app clean,
with few rules, easy to understand.* One clear setting beats a scripting system.

- Open an issue before starting a feature PR, so we can agree on scope first.
- Check the roadmap's **Discarded** list before proposing a feature.
- Bug fixes and small polish can go straight to a PR.

## Good first contributions

- **Translations.** UI strings live in `Cabral/Localizable.xcstrings` (English source, pt-BR
  translated). Add a language by editing the catalog in Xcode.
- **New link wrappers** in `LinkUnwrapper` (`Cabral/Model.swift`), for redirect pages that carry
  the real URL in a query parameter. Include a sanitized example URL in the PR and a test case.
- **Bug reports for specific browsers**, with the browser version and whether it was running.

## Setup

- macOS 26 or later, Xcode 26 or later (tested with 27.2).
- `brew install xcodegen`, then `make run`.
- No Apple Developer account is needed: local builds are ad-hoc signed.
- The Xcode project is generated from `project.yml`. Never commit `Cabral.xcodeproj` or
  `Cabral/Info.plist` (both are ignored); edit `project.yml` instead.

Useful targets: `make build`, `make run`, `make test`, `make lint`, `make format`,
`make install`, `make clean`.

## Style

- Swift 6 with `MainActor` as the default isolation. Pure logic stays `nonisolated`
  (`Model.swift`, `Router.swift`) so it is easy to test.
- No third-party dependencies without discussion first.
- No network calls. The README promises none, and that promise is part of the product.
- Run `make format` and `make lint` before pushing; CI runs the linter in strict mode.
- Comments explain *why*, not *what*.
- UI strings are written in English in code and translated in `Cabral/Localizable.xcstrings`;
  run `make build` and update the catalog in Xcode when you add or change one.

## Testing

`make test` must pass. Changes to `Router`, `Domain`, `LinkUnwrapper` or the config format need
tests in `CabralTests/`.

Some behaviour can only be checked by hand. Before opening a PR that touches link handling or UI:

- Set Cabral (your Debug build) as the default browser.
- Open links from another app: `open https://example.com`, Mail, a chat app.
- Test with the target browser **both running and quit**, and check the URL that actually
  opened, not just that the app came to the front.
- Check the picker's keyboard paths (1–9, ←/→ + Return, Esc), that "Always use for…"
  creates a rule, and the missing-browser warning.

Every build registers with LaunchServices as an `http` handler. If old copies pile up in
**Default web browser**, run `make clean` (and `lsregister -u <path-to-app>` for any leftovers).

## Commits and pull requests

- [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `refactor:`,
  `chore:`, `docs:`, `ci:`, `test:`.
- One topic per PR.
- Attach screenshots for UI changes.
- Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md).

## Releases

Releases are maintainer-only; see [docs/RELEASING.md](docs/RELEASING.md).

## License

Contributions are accepted under the [MIT license](LICENSE) (inbound = outbound); there is no
CLA. Never attach your real `config.json` to an issue or PR: redact your domains.
