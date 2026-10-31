# Releasing

Maintainer-only. Contributors never need any of this: `make build` works unsigned.

A release is a Developer ID signed, notarized and stapled `Cabral-X.Y.Z.dmg`, plus its
`Cabral-X.Y.Z.dmg.sha256` and a signed Sparkle feed, `appcast.xml`, attached to a GitHub
Release whose notes come from [CHANGELOG.md](../CHANGELOG.md).

Installed copies of Cabral read
`https://github.com/ailtonvivaz/Cabral/releases/latest/download/appcast.xml` (`SUFeedURL` in
`project.yml`). "Latest" is the newest published, non-prerelease release, so draft and
prerelease (`-suffix`) releases never reach users through Sparkle.

## 1. Versioning

- [SemVer](https://semver.org). `MARKETING_VERSION` (user-facing) and
  `CURRENT_PROJECT_VERSION` (build number, always increasing) each live on a single line in
  `project.yml`.
- The tag must equal `v$MARKETING_VERSION`. A `-suffix` (e.g. `v0.2.0-beta.1`) makes a
  prerelease.
- To cut a version:
  1. Move the `[Unreleased]` entries in `CHANGELOG.md` into a new `## [X.Y.Z] - YYYY-MM-DD`
     section, update the compare links at the bottom, and commit.
  2. `make bump V=X.Y.Z`: sets `MARKETING_VERSION`, increments `CURRENT_PROJECT_VERSION`,
     commits `chore: release vX.Y.Z` and creates the annotated tag. It refuses a dirty tree or
     a missing CHANGELOG section.
  3. `git push origin main --follow-tags`.

**v0.1.0 is the exception:** `project.yml` already says 0.1.0 with build 1, so tag it by hand
(`git tag -a v0.1.0 -m "Cabral 0.1.0"`) instead of running `make bump`.

## 2. CI release (`.github/workflows/release.yml`)

- **Pushing a `v*` tag** builds, signs, notarizes, staples, generates the signed appcast
  (`scripts/appcast.sh`), and publishes a GitHub Release with the DMG, its checksum and
  `appcast.xml`. The notes are the CHANGELOG section for that version; if the
  section is missing, GitHub's generated notes are used instead.
- **Running the workflow by hand** (`workflow_dispatch`, input `tag`, e.g. `v0.1.0`) does the
  same for an existing tag but publishes a **draft** release. Run it **on the tag itself**:
  `gh workflow run release.yml --ref vX.Y.Z -f tag=vX.Y.Z`, or pick the tag under "Use workflow
  from" in the Actions UI. The `release` environment only accepts `v*` tags, so a run on `main`
  is rejected (and the workflow also fails early if `--ref` and `tag` differ).
- The workflow fails early if the tag does not match `MARKETING_VERSION`.

Recommended first release, with a required reviewer on the `release` environment:

1. Push the tag. The tag-triggered run waits for approval: reject it.
2. Run the workflow by hand on that tag (`--ref vX.Y.Z`, see above) to get a draft.
3. Download the DMG and verify it (section 5), then publish the draft:
   `gh release edit vX.Y.Z --draft=false`.

Without a required reviewer, pushing the tag publishes the release straight away.

## 3. The `release` environment and its secrets

Create an environment named `release` (Settings › Environments). Limit its deployments to tags
matching `v*`, and optionally add yourself as a required reviewer. The built-in `GITHUB_TOKEN`
is enough to create the release; no personal access token is needed.

Add these secrets to the environment (`gh secret set <NAME> --env release`):

| Secret                       | What it is                                                         | How to produce it |
| ---------------------------- | ------------------------------------------------------------------ | ----------------- |
| `APPLE_CERTIFICATE`          | Base64 of the "Developer ID Application" certificate + private key, exported as `.p12` | Keychain Access › export the identity as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_PASSWORD` | Password chosen when exporting the `.p12`                          | Set during export |
| `APPLE_SIGNING_IDENTITY`     | Full identity name, `Developer ID Application: <Name> (<TEAM_ID>)` | `security find-identity -p codesigning -v` |
| `KEYCHAIN_PASSWORD`          | Password for the temporary keychain on the runner                  | `openssl rand -base64 24` |
| `APPLE_API_KEY`              | Base64 of the App Store Connect API key (`AuthKey_<KEY_ID>.p8`)    | App Store Connect › Users and Access › Integrations › Team Keys; then `base64 -i AuthKey_<KEY_ID>.p8 \| pbcopy` |
| `APPLE_API_KEY_ID`           | The key's ID                                                       | Shown next to the key in App Store Connect |
| `APPLE_API_ISSUER`           | The team's issuer UUID                                             | Shown above the key list in App Store Connect |
| `SPARKLE_ED_PRIVATE_KEY`     | Sparkle's EdDSA private key (base64 Ed25519 seed) that signs updates and the appcast | See [Sparkle signing key](#sparkle-signing-key) below |

Never commit `.p8`, `.p12` or certificate files; `.gitignore` excludes them and CI fails if
one is tracked. Delete the local `.p12` and base64 copies once the secrets are saved.

### Sparkle signing key

One key, created once. Installed copies trust only the public half, so **losing the private
key or replacing it strands every installed copy**: they would have to update by hand. Back it
up (e.g. in a password manager).

Sparkle's tools are in the release tarball (`Sparkle-2.10.1.tar.xz` from
[Sparkle's releases](https://github.com/sparkle-project/Sparkle/releases), folder `bin/`):

```sh
./bin/generate_keys            # creates the key in your login keychain, prints the public key
./bin/generate_keys -p         # prints the public key again later
```

1. Put the public key in `project.yml` as `SPARKLE_PUBLIC_ED_KEY` and commit it. It is public;
   the private key never leaves the keychain, the backup and the GitHub secret.
2. Save the private key as the environment secret, through a file that never touches the repo:

   ```sh
   ./bin/generate_keys -x "$TMPDIR/sparkle.key"
   gh secret set SPARKLE_ED_PRIVATE_KEY --env release < "$TMPDIR/sparkle.key"
   rm -P "$TMPDIR/sparkle.key"
   ```

`scripts/appcast.sh` refuses to sign when the secret's public half differs from
`SUPublicEDKey` in the built app, and `scripts/release.sh` refuses a build without a public key.

## 4. Local fallback

Use this if CI notarization fails. You need the Developer ID certificate in your login
keychain and `brew install xcodegen create-dmg`.

One-time setup, storing the API key as a notarytool keychain profile (the script's default
profile name is `vivaz-notary`; override it with `NOTARY_PROFILE`):

```sh
xcrun notarytool store-credentials <profile> \
    --key    /path/to/AuthKey_<KEY_ID>.p8 \
    --key-id <KEY_ID> \
    --issuer <ISSUER_UUID>
```

Then:

```sh
make release    # build/Cabral-X.Y.Z.dmg and build/Cabral-X.Y.Z.dmg.sha256

# Signed appcast (build/appcast.xml); needs openssl 3 and Sparkle's bin/ (see section 3).
./bin/generate_keys -x "$TMPDIR/sparkle.key"
SPARKLE_ED_PRIVATE_KEY="$(cat "$TMPDIR/sparkle.key")" SPARKLE_BIN=/path/to/Sparkle/bin \
    OPENSSL="$(brew --prefix openssl@3)/bin/openssl" TAG=vX.Y.Z ./scripts/appcast.sh
rm -P "$TMPDIR/sparkle.key"

# Notes go outside the repo: an untracked file would make the next `make bump` refuse to run.
awk -v v="X.Y.Z" '/^## \[/{p=index($0,"## [" v "]")==1; next} /^\[.*\]: /{p=0} p' CHANGELOG.md > "$TMPDIR/notes.md"
gh release create vX.Y.Z build/Cabral-X.Y.Z.dmg build/Cabral-X.Y.Z.dmg.sha256 build/appcast.xml \
    --verify-tag --title "Cabral X.Y.Z" --notes-file "$TMPDIR/notes.md"
```

`SKIP_NOTARIZE=1 ./scripts/release.sh` builds and packages without notarizing, which is useful
to test the pipeline; Gatekeeper will warn about that DMG, so never publish it.

## 5. Verifying a download

```sh
shasum -a 256 -c Cabral-X.Y.Z.dmg.sha256
spctl -a -t install -vv Cabral-X.Y.Z.dmg    # expect: accepted, source=Notarized Developer ID
```

To check an update end to end, keep the previous version installed, publish the new release,
then choose **Check for Updates…** in the old copy: it should offer the new version, install it
and relaunch. `appcast.xml` on the release page must list the new version and an
`sparkle:edSignature` for the DMG.

## 6. Sparkle and code signing

Sparkle's helpers (`Autoupdate`, `Updater.app`) ship ad-hoc signed. `scripts/release.sh`
re-signs them, the framework and then the app with the Developer ID, the hardened runtime and
a timestamp, so notarization accepts them. Cabral is not sandboxed, so it never uses Sparkle's
XPC services; the script removes them from the bundle instead of signing them.

To upgrade Sparkle, change `exactVersion` in `project.yml` and both `SPARKLE_VERSION` and
`SPARKLE_SHA256` (of `Sparkle-X.Y.Z.tar.xz`) in `.github/workflows/release.yml`; CI fails if
the versions differ.

## 7. Why the workflows pin Xcode 26.2

The workflows set `DEVELOPER_DIR` to Xcode 26.2 on the `macos-26` runner instead of using the
image's default Xcode:

- `Cabral/AppIcon.icon` (an Icon Composer bundle) needs the Xcode 26+ `actool` on a macOS 26
  host to compile.
- With the image's newer default Xcode (26.5 at the time), `notarytool` submissions failed with HTTP 500;
  Xcode 26.2's `notarytool` worked.

Revisit the pin when the runner image changes, or if the code starts needing a newer SDK.
