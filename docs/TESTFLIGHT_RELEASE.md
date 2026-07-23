# TestFlight ve App Store yayın kontrol listesi

## Ön koşullar

- Apple Developer Program üyeliği
- Uygulama ikonu (1024x1024)
- Gizlilik politikası URL'si (konum verisi cihazda kalır)

## Otomatik testler (CI / lokal)

- [ ] `./scripts/run_tests.sh` yeşil (unit + UI smoke)
- [ ] GitHub Actions `iOS Tests` workflow yeşil

## Xcode hazırlığı

1. Bundle ID: `com.trailhound.app`
2. Widget: `com.trailhound.app.widget`
3. Signing: Automatic + Team seç
4. Capabilities: App Groups, Background Modes (location)

## App Store Connect

1. Yeni uygulama oluştur
2. Gizlilik manifest: `PrivacyInfo.xcprivacy` dahil
3. Konum kullanım açıklaması: yolculuk kaydı
4. Ekran görüntüleri: liste, detay harita, istatistik, ayarlar

## TestFlight

1. Archive → Distribute → App Store Connect
2. Internal testing grubu
3. Aşağıdaki **fiziksel cihaz** checklist'ini tamamla (CI'da otomatiklenemez)

## Fiziksel cihaz test checklist

Bu maddeler `DeviceTestChecklist` enum'unda kod olarak da korunur (`DeviceTestChecklistTests`).

- [ ] **Bluetooth auto-start** — Eşleşmiş araca Bluetooth ile bağlanınca otomatik kayıt başlar (müzik çalmadan)
- [ ] **Bluetooth auto-stop** — Araçtan ayrılınca / Bluetooth kesilince otomatik kayıt durur
- [ ] **Unpaired device guard** — Eşleşmemiş cihazlara (AirPods vb.) bağlanınca kayıt **başlamamalı**
- [ ] **Manuel kayıt** — Uygulama içinden başlat / duraklat / bitir akışı sorunsuz
- [ ] **Widget / kısayol** — Widget veya Siri kısayolu ile kayıt başlatma / durdurma
- [ ] **Export** — JSON, CSV, GPX veya KML dışa aktarma çalışır

## Bluetooth otomatik başlatma

- Auto-start yalnızca eşleşmiş aracın Bluetooth ses rotasına bağlıdır (`AVAudioSessionPortDescription.uid` eşleşmesi).
- Ek entitlement gerekmez; yalnızca konum ve arka plan konum modu kullanılır.

## Release sırası (özet)

1. Otomatik testler yeşil
2. TestFlight internal build yükle
3. Fiziksel cihaz checklist (6 madde)
4. Archive → App Store Connect
