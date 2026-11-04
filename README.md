<p align="center">
  <img src="docs/logo.png" width="160" alt="Arşivci logosu">
</p>

<h1 align="center">Arşivci</h1>

<p align="center">
  <b>Mac için WinRAR benzeri arşiv uygulaması — her dosya türüyle çalışır.</b><br>
  Sıkıştır · Aç · Çıkar<br><br>
  <a href="../../releases/latest"><b>⬇️ Arsivci.dmg indir</b></a>
</p>

<p align="center"><i>Ahmet Kurt tarafından yapıldı.</i></p>

---

![Arşivci arayüzü](docs/arayuz.png)

## Özellikler

- **Sıkıştır:** Her tür dosya ve klasör → ZIP, 7Z, TAR.GZ, TAR.XZ, TAR.BZ2, TAR. İsteğe bağlı şifre.
- **Aç ve çıkar:** ZIP, RAR (RAR5 dahil), 7Z, TAR, GZ, BZ2, XZ, ZST, ISO, CAB, CPIO, XAR, PKG, DEB, RPM, LHA, JAR, APK, IPA…
- **Seçerek çıkar:** Arşivin içeriğini listele, yalnızca istediğin dosyaları çıkar.
- **Arşivi test et:** Bozuk olup olmadığını kontrol eder.
- **Sürükle-bırak:** Pencereye, Dock simgesine ya da Finder'da *Birlikte Aç → Arşivci*.
- **7-Zip dahili:** Şifreli ZIP/7Z ve ek biçimler kutudan çıktığı gibi çalışır.
- **RAR oluşturma:** Bilgisayarda lisanslı RAR aracı varsa otomatik etkinleşir.
- Açık ve koyu mod, Türkçe arayüz.

## Kurulum

1. [Releases](../../releases/latest) sayfasından **Arsivci.dmg** dosyasını indir.
2. Çift tıkla ve açılan pencerede **Arşivci**'yi **Uygulamalar** kartına sürükle.

![DMG kurulum penceresi](docs/dmg.png)

> **İlk açılışta uyarı çıkarsa:** Uygulama Apple tarafından onaylanmış (notarize) değil.
> *Sistem Ayarları → Gizlilik ve Güvenlik* bölümünün altında **"Yine de Aç"** düğmesine bas.
> Ya da Terminal'de: `xattr -cr /Applications/Arşivci.app`

**Gereksinim:** macOS 13 (Ventura) veya üstü · Apple Silicon ve Intel.

## 7-Zip dahili

Arşivci, [7-Zip](https://www.7-zip.org)'i uygulamanın içinde taşır; ek bir şey kurmanız gerekmez.
Bilgisayarınızda zaten 7-Zip varsa (ör. `brew install sevenzip`) Arşivci onu kullanır, yoksa
kendi içindekini kullanır. Bu sayede AES-256 şifreli ZIP, şifreli 7Z ve DMG/WIM gibi ek biçimler
her zaman hazırdır. Hangi motorun kullanıldığı pencerenin alt şeridinde görünür.

## RAR oluşturma

RAR arşivlerini **açmak** için hiçbir şey gerekmez. RAR arşivi **oluşturmak** ise WinRAR'ın
sahibi RARLAB'ın lisanslı `rar` aracını gerektirir; lisansı gereği bu araç Arşivci'nin içine
konamaz. Kurmak için:

```bash
brew install --cask rar
```

Kurulduktan sonra Arşivci'yi yeniden açın; biçim listesindeki **RAR** kilidi kalkar.
Deneme süresi 40 gündür. Sürekli kullanım için [rarlab.com](https://www.rarlab.com)'dan lisans
alıp size gönderilen `rarreg.key` dosyasını ev klasörünüze `.rarreg.key` adıyla koyun.

## Kaynaktan derleme

```bash
git clone <bu-depo>
cd arsivci
bash kur.sh            # build/Arsivci.dmg oluşturur
```

Xcode Komut Satırı Araçları gerekir (`xcode-select --install`).

## Sürümler otomatik

`main`'e kod içeren her gönderimde GitHub Actions sürüm numarasını kendiliğinden bir artırır
(1.1.8 → 1.1.9 → 1.2.0…; her hane 9'dan sonra bir üst haneye geçer), uygulamayı derler, DMG'yi oluşturur ve Releases'e yükler.
Sürüm notları o sürümdeki commit mesajlarından otomatik hazırlanır. Yalnızca README veya
`docs/` değişiklikleri yeni sürüm oluşturmaz.

Büyük bir sürüme geçmek için `VERSION` dosyasını değiştirmeniz yeterli:

```bash
echo "2.0.0" > VERSION
git commit -am "Arşivci 2.0"
git push
```

## Notlar

- 7-Zip © Igor Pavlov, GNU LGPL lisansıyla dahildir — bkz. [ThirdParty](ThirdParty/).
- RAR, win.rar GmbH'nin tescilli biçimidir.

## Proje yapısı

```
Sources/     Swift kaynak kodu (Arsivci.swift: arşiv motoru, Arayuz.swift: arayüz)
Resources/   Info.plist, logo, DMG arka planı
ThirdParty/  Dahil edilen 7-Zip'in lisansı
scripts/     build-app.sh (derleme), dmg-settings.py (DMG penceresi)
.github/     Otomatik DMG + Release iş akışı
```

---

<p align="center">© 2026 Ahmet Kurt</p>
