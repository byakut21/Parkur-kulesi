# Parkur Kulesi

Sürekli yükselen lavdan kaçarken sonsuz bir kuleye tırmandığın, hızlı tempolu bir 3D parkur/platform oyunu.
Godot 4.3 (GDScript) ile yapıldı; Android'de (APK) ve tarayıcıda çalışır.

## Nasıl oynanır

| Tuş | Eylem |
| --- | --- |
| W A S D / ok tuşları | Koş |
| Fare (ya da Q / E) | Kamerayı döndür |
| Boşluk | Zıpla (basılı tutarsan daha yükseğe) |
| Havada duvara değerken Boşluk | Duvar zıplama |
| Shift / C / Ctrl (koşarken) | Kay: hız kazanır, alçak tavanların altından geçersin |
| Shift basılı tut | Çömelerek yürü |
| Kayarken Boşluk | Uzun atlayış |
| Esc / P | Duraklat |
| R / Enter | Öldükten sonra yeniden başla |

| M | Sesi aç / kapat |

**Telefonda:** ekranın sol yarısında parmağını kaydırarak koş, sağ yarısında kaydırarak kamerayı çevir,
sağ alttaki **ZIPLA** ve **KAY** butonlarını kullan. Üstteki ‖ butonu oyunu duraklatır.

Gamepad de desteklenir (sol çubuk koşma, sağ çubuk kamera, A zıplama, B kayma).

**Amaç:** Lav 4 saniye sonra yükselmeye başlar ve gittikçe hızlanır. Olabildiğince yükseğe çık.
Skor = en yüksek nokta × 10 + toplanan kristal × 50. En iyi skor kaydedilir.

Kule her oyunda rastgele üretilir ve şu parçalardan oluşur:

- **Atlama platformları:** yükseldikçe küçülür, aralar açılır.
- **Duvar zıplama bacası:** iki karşılıklı duvar; duvardan duvara sekerek çıkılır. Aynı duvardan art arda sekilmez.
- **Kayma tüneli:** alçak tavanın altından ancak kayarak (ya da çömelerek) geçilir.
- **Hareketli platformlar.**
- Her 25 metrede bir geniş dinlenme platformu.

## Çalıştırma

### Android (APK)

`main` dalına her gönderimde GitHub Actions APK üretir ve depodaki **Releases → "Parkur Kulesi — son sürüm"**
sayfasına `parkur-kulesi.apk` olarak koyar. Telefondan bu sayfayı açıp APK'yı indir ve kur
(ilk seferde "bilinmeyen kaynaklardan yükleme" izni istenir). Her PR'da da Actions çalışmasının
**Artifacts** kısmında `parkur-kulesi-apk` bulunur.

İmza: depoda `ANDROID_KEYSTORE_BASE64` ve `ANDROID_KEYSTORE_PASSWORD` gizli değişkenleri (alias: `parkur`)
tanımlıysa onunla imzalanır. Tanımlı değilse her derlemede geçici bir anahtar üretilir; bu durumda yeni sürümü
kurmadan önce eskisini kaldırmak gerekir.

### Tarayıcıda

`main` dalına her gönderimde GitHub Actions web sürümünü `gh-pages` dalına yükler;
oyun `https://byakut21.github.io/Parkur-kulesi/` adresinde açılır. (Açılmazsa bir kez
**Settings → Pages → Source: Deploy from a branch → gh-pages** seçilmeli.)

Her PR'da da derleme yapılır; Actions çalışmasının **Artifacts** kısmından `parkur-kulesi-web` zip'ini indirip
yerelde açabilirsin:

```bash
cd parkur-kulesi-web
python3 -m http.server 8000
# tarayıcıda http://localhost:8000 aç
```

(Dosyayı doğrudan çift tıklayarak açmak çalışmaz; bir web sunucusu gerekir.)

### Godot editöründe

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir (standart sürüm, .NET gerekmez).
2. Godot'u aç → **Import** → bu klasördeki `project.godot` dosyasını seç.
3. **F5** ile çalıştır.

Web export'u kendin almak için: Editor → Manage Export Templates → 4.3 şablonlarını indir,
sonra Project → Export → **Web** → Export Project.

### Testler

```bash
godot --headless -s res://tests/mechanics_test.gd
```

Kayma tüneli, duvar zıplama bacası ve kule üretimini başsız olarak dener.

## Karakter, müzik ve sesler

- Karakter: Quaternius "Ultimate Modular Men Pack" içindeki *Casual_Hoodie* modeli (CC0 / kamu malı),
  çocuk boyuna küçültüldü, renkleri koddan değiştirildi. Bkz. `assets/character/CREDITS.txt`.
- Müzik ve ses efektleri bu proje için `tools/make_audio.py` ile sentezlendi (özgün, harici örnek yok).
  Yeniden üretmek için: `python3 tools/make_audio.py assets/audio` (numpy + ffmpeg gerekir).

## Proje yapısı

```
scenes/main.tscn       Ana sahne (tek düğüm, gerisi koddan kurulur)
scripts/main.gd        Oyun akışı, lav, skor, giriş tuşları, ortam
scripts/player.gd      Karakter kontrolü ve kamera
scripts/tower.gd       Sonsuz, rastgele kule üretimi
scripts/kid.gd         Karakter modeli ve animasyonları
scripts/touch_controls.gd  Dokunmatik kontroller
scripts/sound.gd       Müzik ve ses efektleri
scripts/hud.gd         Arayüz
scripts/gem.gd         Kristaller
scripts/mover.gd       Hareketli platform
tests/                 Başsız mekanik testleri
```

Oyun dengesini değiştirmek için ayarlar ilgili dosyaların başındaki sabitlerde:
zıplama/kayma `player.gd`, lav hızı `main.gd`, platform aralıkları `tower.gd`.
