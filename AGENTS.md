# AGENTS.md

Cabral: a macOS accessory app (no Dock or menu-bar icon) that registers as the default browser
and forwards each http/https link to a real browser, by domain rule or via a picker.

## Layout (`Cabral/`)

- `main.swift`, `AppDelegate.swift`: entry point, URL Apple Events, sender app, reopen → Settings.
- `LinkHandler.swift`: unwrap, route, open; picker queue; missing-browser fallback.
- `Router.swift`, `Model.swift`: pure routing. `Action`, `Rule`, `Config` (the `config.json`
  format), `Domain` (normalize/match), `LinkUnwrapper`.
- `PickerPanel.swift`, `PickerView.swift`: the non-activating glass picker.
- `SettingsWindow.swift`, `SettingsView.swift`, `RuleRow.swift`: Settings and the URL tester.
- `Store.swift`: JSON persistence in `~/Library/Application Support/Cabral/config.json`.
- `BrowserCatalog.swift`: browser discovery, default-browser check and switch.
- `MainMenu.swift`: the menu shown while Settings is open.
- `CabralTests/`: Swift Testing unit tests.

## Commands

`make project` (XcodeGen), `make build`, `make run`, `make test`, `make lint`, `make format`,
`make clean`, `make install`.

## Rules

- Edit `project.yml`; never the generated `Cabral.xcodeproj` or `Cabral/Info.plist`.
- Keep routing pure and `nonisolated`; UI and AppKit code is `MainActor`.
- No dependencies and no network calls, ever (README privacy promise).
- Never offer Cabral itself as a target browser.
- `config.json` is a public contract (`version: 1`): change it compatibly and add tests.
- UI strings are English in code; every user-facing string gets a pt-BR entry in `Cabral/Localizable.xcstrings`.
- Verify link handling with the target browser both running and quit, checking the URL.
- Conventional Commits. Run `make format`, `make lint` and `make test` before committing.
- Never run `make release` or `scripts/release.sh`; releases are maintainer-only.
- Quit Icon Composer before editing `Cabral/AppIcon.icon`: it overwrites the bundle.
- Never paste real user config, domains or signing material into code, docs, tests or issues.
