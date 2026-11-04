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

echo "▶ 7-Zip ekleniyor…"
# Bilgisayarda 7-Zip kuruluysa uygulama onu kullanır; yoksa bu gömülü sürüm devreye girer.
SEVENZIP_VERSION="26.05"
SEVENZIP_SHA256="12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570"
SEVENZIP_URL="https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION}/7z${SEVENZIP_VERSION//./}-mac.tar.xz"
SZ_DIR="build/7zip"
mkdir -p "$SZ_DIR"
curl -fsSL "$SEVENZIP_URL" -o "$SZ_DIR/7z.tar.xz"
echo "$SEVENZIP_SHA256  $SZ_DIR/7z.tar.xz" | shasum -a 256 -c - >/dev/null \
  || { echo "7-Zip paketinin doğrulaması başarısız!"; exit 1; }
tar -xf "$SZ_DIR/7z.tar.xz" -C "$SZ_DIR" 7zz License.txt
cp "$SZ_DIR/7zz" "$APP/Contents/MacOS/7zz"
chmod +x "$APP/Contents/MacOS/7zz"
cp "$SZ_DIR/License.txt" "$APP/Contents/Resources/7-Zip-Lisans.txt"
rm -rf "$SZ_DIR"

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
# Önce gömülü 7-Zip, sonra uygulamanın kendisi
codesign --force --sign - "$APP/Contents/MacOS/7zz"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

echo "✅ $APP (sürüm $VERSION)"
