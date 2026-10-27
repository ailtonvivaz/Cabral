#!/usr/bin/env bash
#
# Cabral release: build (Developer ID, hardened runtime) → DMG → notarize → staple.
# Output: build/Cabral-<version>.dmg + build/Cabral-<version>.dmg.sha256
#
# Maintainers only. Contributors never need this script; `make build` works unsigned.
#
# One-time setup:
#   1. "Developer ID Application" cert in login keychain.
#      Verify: security find-identity -p codesigning -v
#   2. Store the App Store Connect API key (notarization) as a keychain profile once.
#      Issuer ID: App Store Connect → Users and Access → Integrations → Keys.
#        xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#            --key     /path/to/AuthKey_<KEY_ID>.p8 \
#            --key-id  <KEY_ID> \
#            --issuer  <ISSUER_UUID>
#   3. brew install create-dmg xcodegen
#
# Usage:
#   ./scripts/release.sh                  # full pipeline
#   SKIP_NOTARIZE=1 ./scripts/release.sh  # build + DMG only (Gatekeeper will warn)
#
# Env overrides:
#   TEAM_ID           default: 6B563564C5
#   SIGNING_IDENTITY  default: "Developer ID Application: Ailton Vieira Pinto Filho ($TEAM_ID)"
#   NOTARY_PROFILE    default: vivaz-notary (keychain profile, local mode)
#   APPLE_API_KEY     base64 of the .p8; with APPLE_API_KEY_ID + APPLE_API_ISSUER (CI mode).
#                     When set, these take precedence over NOTARY_PROFILE.
#   EXPECTED_VERSION  fail unless the built CFBundleShortVersionString equals this (CI tag guard)
#   SKIP_NOTARIZE     1 = build + DMG only

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Cabral"
TEAM_ID="${TEAM_ID:-6B563564C5}"
IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Ailton Vieira Pinto Filho (${TEAM_ID})}"
NOTARY_PROFILE="${NOTARY_PROFILE:-vivaz-notary}"

# CI has no keychain profile: write the API key to a temp file that never outlives the script.
NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "${APPLE_API_KEY:-}" ]]; then
    : "${APPLE_API_KEY_ID:?APPLE_API_KEY_ID required}" "${APPLE_API_ISSUER:?APPLE_API_ISSUER required}"
    KEY_DIR="$(mktemp -d)"; trap 'rm -rf "$KEY_DIR"' EXIT
    KEY_FILE="$KEY_DIR/AuthKey.p8"
    printf '%s' "$APPLE_API_KEY" | base64 --decode > "$KEY_FILE"
    NOTARY_ARGS=(--key "$KEY_FILE" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER")
fi

DERIVED="build/release"
APP_PATH="${DERIVED}/Build/Products/Release/${APP_NAME}.app"

echo "▶ Preflight"
command -v xcodegen >/dev/null || { echo "✗ xcodegen missing: brew install xcodegen" >&2; exit 1; }
command -v create-dmg >/dev/null || { echo "✗ create-dmg missing: brew install create-dmg" >&2; exit 1; }
security find-identity -p codesigning -v | grep -q "${IDENTITY}" \
    || { echo "✗ Identity not in keychain: ${IDENTITY}" >&2; exit 1; }
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    xcrun notarytool history "${NOTARY_ARGS[@]}" >/dev/null 2>&1 \
        || { echo "✗ Notary credentials missing or invalid. See setup at top of $0." >&2; exit 1; }
fi

echo "▶ Building ${APP_NAME} (Release, Developer ID)…"
xcodegen generate --quiet
rm -rf "$DERIVED"
xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "$APP_NAME" -configuration Release \
    -derivedDataPath "$DERIVED" -destination 'generic/platform=macOS' -quiet \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    ONLY_ACTIVE_ARCH=NO \
    build

echo "▶ Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/   /'
codesign -dvv "$APP_PATH" 2>&1 | grep -E "Authority=Developer|TeamIdentifier|Timestamp|Runtime" | sed 's/^/   /'

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
[[ -z "${EXPECTED_VERSION:-}" || "$VERSION" == "$EXPECTED_VERSION" ]] \
    || { echo "✗ Built $VERSION, expected $EXPECTED_VERSION" >&2; exit 1; }
DMG_PATH="build/${APP_NAME}-${VERSION}.dmg"

# Relative filename inside the .sha256 so `shasum -c` works next to the downloaded DMG.
write_sha() {
    (cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256")
    sed 's/^/   /' "$DMG_PATH.sha256"
}

echo "▶ Packaging ${DMG_PATH}…"
rm -f "$DMG_PATH"
create-dmg \
    --volname "$APP_NAME" \
    --window-size 560 380 \
    --icon-size 96 \
    --icon "${APP_NAME}.app" 150 190 \
    --app-drop-link 410 190 \
    --hide-extension "${APP_NAME}.app" \
    --no-internet-enable \
    --codesign "$IDENTITY" \
    "$DMG_PATH" \
    "$APP_PATH" >/dev/null

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    write_sha
    echo "⚠ SKIP_NOTARIZE=1 — DMG at $DMG_PATH is signed but not notarized."
    exit 0
fi

echo "▶ Notarizing (a few minutes)…"
NOTARY_PLIST="build/notary.plist"
xcrun notarytool submit "$DMG_PATH" "${NOTARY_ARGS[@]}" \
    --wait --output-format plist > "$NOTARY_PLIST" || true
STATUS=$(/usr/libexec/PlistBuddy -c 'Print :status' "$NOTARY_PLIST" 2>/dev/null || echo unknown)
SUBMISSION=$(/usr/libexec/PlistBuddy -c 'Print :id' "$NOTARY_PLIST" 2>/dev/null || echo "")
if [[ "$STATUS" != "Accepted" ]]; then
    echo "✗ Notarization status: $STATUS" >&2
    [[ -n "$SUBMISSION" ]] && xcrun notarytool log "$SUBMISSION" "${NOTARY_ARGS[@]}"
    exit 1
fi

echo "▶ Stapling…"
xcrun stapler staple "$DMG_PATH" >/dev/null
xcrun stapler validate "$DMG_PATH"
spctl --assess --type install --verbose=2 "$DMG_PATH" 2>&1 | sed 's/^/   /'

# Stapling rewrites the DMG, so the checksum is taken last.
echo "▶ Checksum…"
write_sha

echo "✅ Release ready: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
