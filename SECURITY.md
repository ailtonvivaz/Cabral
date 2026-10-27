# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Report privately via
[GitHub private vulnerability reporting](https://github.com/ailtonvivaz/Cabral/security/advisories/new).
This is a single-maintainer project: expect an acknowledgement within 7 days, best effort.

In scope, for example:
- a crafted URL that bypasses the http/https check, or is unwrapped into a non-web scheme;
- routing that opens a different URL than the one received;
- a crafted `config.json` leading to code execution;
- problems with the signature or notarization of release artifacts.

Out of scope: the behaviour of the target browsers themselves.

When sharing configuration, redact your domains from
`~/Library/Application Support/Cabral/config.json`.
