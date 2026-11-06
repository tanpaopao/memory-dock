#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MemoryDock"
APP="$PWD/build/$APP_NAME.app"
BUNDLE_ID="com.yg.memorydock"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx14.0"

SWIFTC="${SWIFTC:-}"
SDK="${SDK:-}"

if [ -z "$SWIFTC" ]; then
  if command -v xcrun >/dev/null 2>&1 && xcrun --find swiftc >/dev/null 2>&1; then
    SWIFTC="$(xcrun --find swiftc)"
  else
    SWIFTC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
  fi
fi

if [ -z "$SDK" ]; then
  if command -v xcrun >/dev/null 2>&1 && xcrun --show-sdk-path >/dev/null 2>&1; then
    SDK="$(xcrun --show-sdk-path)"
  else
    SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
  fi
fi

if [ ! -x "$SWIFTC" ] || [ ! -d "$SDK" ]; then
  echo "Swift toolchain or macOS SDK not found." >&2
  echo "Set SWIFTC and SDK, or install Xcode command line tools." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling Swift sources…"
"$SWIFTC" \
  -sdk "$SDK" \
  -target "$TARGET" \
  -swift-version 5 \
  -O \
  -whole-module-optimization \
  -framework AppKit \
  -framework QuartzCore \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$APP_NAME"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

/usr/bin/plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$APP/Contents/Info.plist" >/dev/null

/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1
/usr/bin/touch "$APP"
echo "Built: $APP"
