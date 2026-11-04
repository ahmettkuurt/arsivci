# Üçüncü taraf bileşenler

## 7-Zip

Arşivci, 7-Zip'in macOS komut satırı sürümünü (`7zz`) uygulamanın içinde taşır
(`Arşivci.app/Contents/MacOS/7zz`). Bilgisayarda 7-Zip kuruluysa (ör. Homebrew) o sürüm
tercih edilir; değilse gömülü sürüm kullanılır.

- Telif: © 1999-2026 Igor Pavlov
- Lisans: GNU LGPL (bazı bölümler unRAR kısıtlaması, BSD 3-clause ve BSD 2-clause) — bkz. [7-Zip-License.txt](7-Zip-License.txt)
- Kaynak kodu ve resmi sürümler: https://www.7-zip.org · https://github.com/ip7z/7zip
- Paketlenen sürüm `scripts/build-app.sh` içinde sabitlenmiş ve SHA-256 ile doğrulanır.

## RAR

RAR, win.rar GmbH'nin tescilli biçimidir. RAR arşivleri, macOS'un yerleşik `bsdtar`
(libarchive) motoru ve 7-Zip ile açılır. RAR **oluşturmak** için RARLAB'ın `rar` aracı
gerekir; lisansı gereği bu araç Arşivci ile birlikte dağıtılmaz. Kullanıcının bilgisayarında
kuruluysa Arşivci onu algılar ve RAR biçimini etkinleştirir.
