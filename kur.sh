#!/bin/bash
# Arşivci'yi kendi Mac'inde derleyip DMG oluşturmak için.
# (Hazır DMG için GitHub'daki Releases sayfasından indirebilirsin.)
# Geliştirici: Ahmet Kurt
set -euo pipefail
cd "$(dirname "$0")"

bash scripts/build-app.sh "${1:-1.0.0}"

echo "▶ DMG oluşturuluyor…"
if ! python3 -c "import dmgbuild" 2>/dev/null; then
  python3 -m pip install --user --quiet dmgbuild 2>/dev/null \
    || python3 -m pip install --user --quiet --break-system-packages dmgbuild
fi
tiffutil -cathidpicheck Resources/dmg-background.png Resources/dmg-background@2x.png -out build/background.tiff >/dev/null
python3 -m dmgbuild -s scripts/dmg-settings.py \
  -D app="build/Arşivci.app" \
  -D background=build/background.tiff \
  "Arşivci" build/Arsivci.dmg

echo ""
echo "✅ Hazır: $PWD/build/Arsivci.dmg"
open build/Arsivci.dmg
