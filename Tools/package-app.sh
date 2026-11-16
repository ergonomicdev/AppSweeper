#!/bin/bash
# Builds a universal, ad-hoc-signed Release AppSweeper.app and packages it for distribution.
# Output (in ./dist): AppSweeper.app, AppSweeper-<version>.zip, AppSweeper-<version>.dmg
# Usage: Tools/package-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# Full Xcode is required; prefer it if the selected developer dir is Command Line Tools.
if [[ "$(xcode-select -p)" != *Xcode* && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

DERIVED="$(mktemp -d)"
trap 'rm -rf "$DERIVED"' EXIT
rm -rf dist && mkdir dist

xcodebuild -project AppSweeper.xcodeproj -scheme AppSweeper -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual CODE_SIGNING_REQUIRED=NO \
  build | tail -3

cp -R "$DERIVED/Build/Products/Release/AppSweeper.app" dist/
codesign --force --deep --sign - dist/AppSweeper.app

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/AppSweeper.app/Contents/Info.plist)"
ditto -c -k --keepParent dist/AppSweeper.app "dist/AppSweeper-$VERSION.zip"

STAGE="$(mktemp -d)"
cp -R dist/AppSweeper.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "AppSweeper" -srcfolder "$STAGE" -ov -format UDZO "dist/AppSweeper-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo "Built version $VERSION:"
ls -1 dist
