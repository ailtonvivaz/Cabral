# Notes: browser profiles

> These are findings from early experiments, kept for whoever picks up profile support
> (see [ROADMAP](../ROADMAP.md), v2 "Chromium profiles"). **None of this ships in Cabral
> today**: every rule targets a browser app, never a profile.

## What we learned

### Chrome and other Chromium browsers

Chrome opened the URL in the right profile when launched with
`--profile-directory=<dir>`. The value is the profile's internal directory name, such as
`Default` or `Profile 1`, not the name shown in Chrome's UI. Profiles can be discovered from
the browser's `Local State` file, but its location and format are product details: treat
discovery as a convenience, let the user review the result, and test it.

The app should try to reuse the instance that is already running. Test every supported
browser both while it is running and while it is quit, and check **both the profile and the
URL**. Merely opening the app does not count as success. Do not apply Chrome's arguments to
every Chromium browser automatically without a browser-specific test.

### Arc

Experiments with `--profile-directory` did not work as profile routing for Arc. Forcing a new
instance with `open -n` showed a warning that only one instance can be open; without it, Arc
opened but did not reliably honour the URL and the profile. Treat Arc as **one target per
app**, with no profile selection. Users who want to pick a Space or profile per domain inside
Arc should use Arc's own **Air Traffic Control**. Never present a detected Arc profile as an
option that promises to work.

### Safari

Choosing a Safari profile by scripting its menus was fragile and failed in real use. Open
Safari normally, without a profile selector. The UI must make this limitation clear rather
than offer a setting the app cannot honour.

## Implementation cautions

- Register for `http` and `https`, then check that macOS really made Cabral the default
  browser. If the automatic change fails, show manual instructions.
- Persist rules and targets locally, with stable IDs, so a rule keeps pointing at the right
  target after a rename or reorder.
- Never allow Cabral itself as a target: it would create an open loop.
- Discover installed apps by bundle identifier and path, and tolerate browsers that were
  removed. Profile discovery is optional.
- Do not create duplicate targets on every rescan. Show what was found and allow editing or
  removal.
- Open links in the existing instance when the browser supports it; verify the running and
  quit cases separately.
- Start with the proven target kinds only: a browser without a profile, and Chrome with a
  profile (Arc and Safari stay profile-less). Expand per browser only after real tests.
