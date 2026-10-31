#!/usr/bin/env bash
#
# Cabral appcast: EdDSA-signs the release DMG and writes a signed Sparkle feed for it.
# Output: build/appcast.xml, uploaded to the GitHub Release next to the DMG. The app reads it
# from https://github.com/ailtonvivaz/Cabral/releases/latest/download/appcast.xml, so drafts and
# prereleases never reach users.
#
# Maintainers only; CI runs it after scripts/release.sh (see docs/RELEASING.md).
#
# Env:
#   SPARKLE_ED_PRIVATE_KEY  required: the private key exported with `generate_keys -x`
#                           (base64 of the 32-byte Ed25519 seed). Never printed.
#   SPARKLE_BIN             required: directory with Sparkle's generate_appcast and sign_update
#   TAG                     required: the release tag, e.g. v0.2.0
#   OPENSSL                 optional: an OpenSSL 3 binary (default: openssl)

set -euo pipefail

cd "$(dirname "$0")/.."

: "${SPARKLE_ED_PRIVATE_KEY:?SPARKLE_ED_PRIVATE_KEY required}"
: "${SPARKLE_BIN:?SPARKLE_BIN required}" "${TAG:?TAG required}"
OPENSSL="${OPENSSL:-openssl}"
REPO_URL="https://github.com/ailtonvivaz/Cabral"
VERSION="${TAG#v}"
DMG="build/Cabral-${VERSION}.dmg"
APP_PLIST="build/release/Build/Products/Release/Cabral.app/Contents/Info.plist"

[[ -f "$DMG" ]] || { echo "✗ $DMG missing: run scripts/release.sh first" >&2; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

echo "▶ Checking the signing key against the app's SUPublicEDKey…"
EXPECTED=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PLIST" 2>/dev/null || true)
[[ -n "$EXPECTED" ]] || { echo "✗ SUPublicEDKey is empty: set SPARKLE_PUBLIC_ED_KEY in project.yml" >&2; exit 1; }
# A PKCS#8 wrapper around the 32-byte seed lets OpenSSL derive the public key.
{
    printf '302e020100300506032b657004220420' | xxd -r -p
    printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | base64 --decode
} > "$WORK/key.der"
[[ $(wc -c < "$WORK/key.der") -eq 48 ]] \
    || { echo "✗ SPARKLE_ED_PRIVATE_KEY is not a base64 32-byte Ed25519 seed (generate_keys -x)" >&2; exit 1; }
ACTUAL=$("$OPENSSL" pkey -inform DER -in "$WORK/key.der" -pubout -outform DER | tail -c 32 | base64)
rm -f "$WORK/key.der"
[[ "$ACTUAL" == "$EXPECTED" ]] \
    || { echo "✗ SPARKLE_ED_PRIVATE_KEY does not match SUPublicEDKey $EXPECTED" >&2; exit 1; }

echo "▶ Generating the appcast…"
mkdir "$WORK/feed"
cp "$DMG" "$WORK/feed/"
# Release notes: this version's CHANGELOG section, as Markdown next to the DMG.
awk -v v="$VERSION" '/^## \[/{p=index($0,"## [" v "]")==1; next} /^\[.*\]: /{p=0} p' CHANGELOG.md \
    > "$WORK/feed/Cabral-${VERSION}.md"
[[ -s "$WORK/feed/Cabral-${VERSION}.md" ]] || rm "$WORK/feed/Cabral-${VERSION}.md"
printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "${REPO_URL}/releases/download/${TAG}/" \
    --embed-release-notes \
    --link "$REPO_URL" \
    --maximum-versions 1 \
    "$WORK/feed"

echo "▶ Verifying…"
FEED="$WORK/feed/appcast.xml"
grep -q "sparkle:edSignature=" "$FEED" || { echo "✗ The update is not EdDSA-signed" >&2; exit 1; }
grep -q "<sparkle:version>$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST")</sparkle:version>" "$FEED" \
    || { echo "✗ The appcast does not describe this build" >&2; exit 1; }
printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" --verify --ed-key-file - "$FEED" \
    || { echo "✗ The appcast signature does not verify (SURequireSignedFeed)" >&2; exit 1; }

cp "$FEED" build/appcast.xml
echo "✅ Appcast ready: build/appcast.xml"
