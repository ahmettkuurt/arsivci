#!/bin/bash
# Arşivci.app'i derler (Apple Silicon + Intel evrensel) ve logoyu ekler.
# Kullanım: scripts/build-app.sh [sürüm]   →  build/Arşivci.app
# Geliştirici: Ahmet Kurt
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
NAME="Arşivci"
APP="build/$NAME.app"
SOURCES=(Sources/Arsivci.swift Sources/Arayuz.swift)

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Swift derleyicisi bulunamadı. Önce:  xcode-select --install"
  exit 1
fi

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▶ Derleniyor (arm64 + x86_64)…"
swiftc -O -parse-as-library -target arm64-apple-macos13.0  "${SOURCES[@]}" -o build/Arsivci-arm64
swiftc -O -parse-as-library -target x86_64-apple-macos13.0 "${SOURCES[@]}" -o build/Arsivci-x86_64
lipo -create build/Arsivci-arm64 build/Arsivci-x86_64 -output "$APP/Contents/MacOS/Arsivci"
rm -f build/Arsivci-arm64 build/Arsivci-x86_64

cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString Arşivci $VERSION — Ahmet Kurt tarafından yapıldı" "$APP/Contents/Info.plist"

echo "▶ Logo hazırlanıyor…"
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▶ İmzalanıyor (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "✅ $APP (sürüm $VERSION)"
