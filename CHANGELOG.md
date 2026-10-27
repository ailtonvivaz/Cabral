# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-27

### Added
- Registers as the macOS default browser (http/https) and forwards each link to a real browser; Cabral never renders web content.
- Domain rules that also cover subdomains (`company.com` matches `app.company.com`, not `notcompany.com`); the most specific domain wins.
- Per-rule action: a specific browser or **Ask**; an **Others** fallback for unmatched links.
- Glass picker at the mouse pointer: host, full URL and sender app; keys 1–9, ←/→ + Return, Esc; "Always use for `<host>`" creates a rule.
- Links that arrive together are queued and handled one by one.
- Unwraps Microsoft Teams, Outlook Safe Links and Google redirect URLs before routing.
- Settings window: default-browser banner, inline rule editing, duplicate detection, missing-browser warning, live URL tester.
- Alert plus picker fallback when a browser is missing or fails to open.
- Rules stored locally in `~/Library/Application Support/Cabral/config.json`, in a versioned format (`"version": 1`); a file that does not decode is moved aside as `config.corrupt-<date>.json`, and one that cannot be read or moved is left untouched.
- English UI with a Brazilian Portuguese translation (String Catalog); follows the macOS language.
- Unit tests for domain matching, routing, link unwrapping and config coding.
- Signed (Developer ID) and notarized DMG with a SHA-256 checksum.

[Unreleased]: https://github.com/ailtonvivaz/Cabral/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ailtonvivaz/Cabral/releases/tag/v0.1.0
