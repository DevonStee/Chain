#!/bin/bash
# Build Chain with local (ad-hoc) signing and install it to /Applications.
# Needs no Apple account or provisioning profile, so the install never expires.
# The Xcode project keeps its development signing settings, so build unsigned
# and sign here, inside-out, with each target's entitlements file.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP=/Applications/Chain.app
EXTENSION_ID=com.lursetawet.chain.ChainExtension
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Building Chain..."
if ! /usr/bin/xcodebuild -project "$REPO/Chain.xcodeproj" -scheme Chain -configuration Release \
    -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= build \
    > "$WORK/build.log" 2>&1; then
    tail -30 "$WORK/build.log"
    echo "Build failed; the installed Chain was not changed." >&2
    exit 1
fi

BUILT="$WORK/dd/Build/Products/Release/Chain.app"
EXTENSION="$BUILT/Contents/PlugIns/ChainExtension.appex"
find "$BUILT" -name '*.dylib' -exec /usr/bin/codesign --force --sign - --timestamp=none {} \;
/usr/bin/codesign --force --sign - --timestamp=none \
    --entitlements "$REPO/ChainExtension/Entitlements.plist" "$EXTENSION"
/usr/bin/codesign --force --sign - --timestamp=none \
    --entitlements "$REPO/Chain/Entitlements.plist" "$BUILT"
/usr/bin/codesign --verify --deep --strict "$BUILT"

pkill -x Chain || true
pkill -x ChainExtension || true
sleep 1

# The old app must be removed, not merged: cp -R into an existing bundle keeps old binaries.
if [ -e "$APP" ]; then
    mv "$APP" "$WORK/Chain-previous.app"
fi
if ! cp -R "$BUILT" "$APP" || ! /usr/bin/codesign --verify --deep --strict "$APP"; then
    rm -rf "$APP"
    if [ -e "$WORK/Chain-previous.app" ]; then
        mv "$WORK/Chain-previous.app" "$APP"
    fi
    echo "Install failed; the previous Chain was restored." >&2
    exit 1
fi

open "$APP"
sleep 2
/usr/bin/pluginkit -a "$APP/Contents/PlugIns/ChainExtension.appex"
/usr/bin/pluginkit -e use -i "$EXTENSION_ID"
killall Finder
echo "Installed $APP"
