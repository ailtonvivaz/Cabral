<h1 align="center">Cabral</h1>

<p align="center"><strong>Every link finds its browser.</strong></p>

<p align="center">
A tiny macOS app that poses as your default browser and forwards each link to the right
real browser, by domain or with a quick picker.
</p>

<p align="center">
  <a href="https://github.com/ailtonvivaz/Cabral/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/ailtonvivaz/Cabral?sort=semver"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-black">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-orange">
</p>

> Available in English and Brazilian Portuguese; Cabral follows your macOS language.

<!-- TODO: screenshots (docs/images/picker.png and docs/images/settings.png, light appearance, throwaway config) -->

## Why

You use more than one browser: one for personal stuff, one for work, maybe one per client.
Every link from Slack, Mail or the terminal still opens in whichever browser is the system
default. Cabral sits in that slot and sends each link where it belongs. It never renders a
page itself; it only decides, then hands the URL over.

## Features

- Registers as the macOS default browser (`http`/`https`) and forwards each link to a real
  browser.
- Domain rules that also cover subdomains: `company.com` matches `app.company.com`, but not
  `notcompany.com`. When several rules match, the most specific domain wins.
- Each rule either opens a specific browser or **Ask**s. An **Others** fallback handles links
  that match no rule.
- A glass picker that appears at the mouse pointer without stealing focus from the app you
  are in. It shows the host, the full URL and the app that sent the link.
  - <kbd>1</kbd>–<kbd>9</kbd> pick a browser, <kbd>←</kbd>/<kbd>→</kbd> then <kbd>Return</kbd>
    also work, <kbd>Esc</kbd> or a click elsewhere cancels.
  - "Always use for &lt;host&gt;" turns the choice into a rule.
- Links that arrive together are queued and handled one at a time.
- Unwraps Microsoft Teams, Outlook Safe Links and Google result redirects (`google.com/url?q=…`)
  before routing, so rules apply to the real destination.
- Settings window: default-browser banner, inline rule editing, duplicate detection, a warning
  for rules that point at a browser that is no longer installed, and a URL tester that shows
  which rule would win.
- If a browser is missing or fails to open, Cabral shows an alert and then the picker, so the
  link is never lost.
- Rules are stored locally in a small JSON file (see [Configuration](#configuration)).
- Signed with Developer ID and notarized.

Cabral is an accessory app: there is no Dock icon and no menu-bar icon while it works. The
Dock icon appears only while the Settings window is open.

## Requirements

- macOS 26 Tahoe or later.
- Universal binary (Apple silicon and Intel).

## Install

1. Download `Cabral-x.y.z.dmg` from [Releases](https://github.com/ailtonvivaz/Cabral/releases/latest).
2. Open it and drag **Cabral** to **Applications**.

The DMG is Developer ID signed and notarized. A `.sha256` checksum sits next to it on the
release page: `shasum -a 256 -c Cabral-x.y.z.dmg.sha256`.

There is no auto-update yet; watch the repository's releases to hear about new versions.
A Homebrew cask is planned.

## First run

1. Open Cabral. The Settings window appears.
2. Click **Make Default** and confirm in the dialog macOS shows.
   If that fails, set it by hand: **System Settings › Desktop & Dock › Default web browser › Cabral**.
3. Add rules with the **+** button in the toolbar: type a domain, pick a browser or
   **Ask**.
4. Choose what **Others** does for links that match no rule.

To reopen Settings later, launch Cabral again from Applications or Spotlight. Closing the
window keeps Cabral running in the background; quit it with <kbd>⌘Q</kbd> while Settings is open.

## How routing works

1. Only `http` and `https` links are handled; anything else is ignored.
2. Known redirect wrappers (Teams, Safe Links, Google) are unwrapped, including nested ones.
3. The host is normalized: lowercased, without scheme, port, path or trailing dot.
4. Of the rules whose domain equals the host or is a parent domain of it, the longest wins.
   With no match, **Others** applies.
5. The chosen browser opens the URL, or the picker appears when the action is **Ask**.

Example:

| Rule              | Action |
| ----------------- | ------ |
| `google.com`      | Chrome |
| `docs.google.com` | Safari |
| Others            | Ask    |

- `https://docs.google.com/x` → Safari (the more specific rule wins).
- `https://mail.google.com` → Chrome.
- `https://example.org` → the picker.

Use the **Test URL** button in Settings to try this with your own rules.

## Configuration

Rules live in `~/Library/Application Support/Cabral/config.json`. Settings is the intended
editor; if you edit the file by hand, quit Cabral first, because it rewrites the file on every
change.

```json
{
  "fallback" : "ask",
  "rules" : [
    { "action" : "com.google.Chrome", "domain" : "google.com", "id" : "3F2504E0-4F89-11D3-9A0C-0305E82C3301" },
    { "action" : "ask", "domain" : "example.com", "id" : "7C9E6679-7425-40DE-944B-E07FC1F90AE7" }
  ],
  "version" : 1
}
```

- `action` and `fallback` are either `"ask"` or the bundle identifier of a browser.
- `domain` is a bare host; it also matches its subdomains.
- `id` is any UUID.

If the file is not valid JSON in the expected format, Cabral moves it aside as
`config.corrupt-<date>.json` and starts with an empty configuration. If it cannot even read or
move the file, Cabral starts empty and does not save changes, so the file is never overwritten.

## Privacy

- No network requests and no telemetry. Cabral never fetches the links it routes.
- Your rules exist only in the local `config.json` above.
- The name of the app that sent a link is read locally, from the Apple Event that delivered it,
  and is only shown in the picker.
- Cabral is not sandboxed: it needs LaunchServices to discover browsers, to become the default
  browser (`setDefaultApplication`) and to read the sender's process ID. The hardened runtime
  is on.

## Uninstall

1. Choose another default browser in **System Settings › Desktop & Dock**.
2. Quit Cabral and delete `/Applications/Cabral.app`.
3. Delete `~/Library/Application Support/Cabral`.

## Limitations

These are not supported yet; most are planned, see the [roadmap](docs/ROADMAP.md):

- Browser profiles and private windows (rules target a browser app).
- Rules by source app, regex or path. Rules match domains only, and wildcards such as `*` are
  not supported: enter a plain domain like `company.com`.

## Build from source

Requires Xcode 26 or later (tested with 27.2) and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
make run       # generate the project, build Debug and open it
make test      # run the unit tests
make lint      # swift-format, strict
make install   # build Release and copy it to /Applications
```

The Xcode project is generated from `project.yml`; never edit `Cabral.xcodeproj` or
`Cabral/Info.plist` directly. No Apple Developer account is needed: local builds are
ad-hoc signed.

Every build you run also registers itself with LaunchServices as an `http` handler, so stale
copies under `build/` can show up in **Default web browser**. Run `make clean` to delete them;
if an entry lingers, unregister it with
`/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u <path-to-app>`.

Maintainers: signed and notarized releases are described in [docs/RELEASING.md](docs/RELEASING.md).

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[roadmap](docs/ROADMAP.md) first. Translations into new languages are a great first contribution.

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 Ailton Vieira Pinto Filho.

Named after Pedro Álvares Cabral, the Portuguese navigator whose fleet reached Brazil in 1500;
hence the caravel.
