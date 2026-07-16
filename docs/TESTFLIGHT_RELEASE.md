# TestFlight ve App Store yayın kontrol listesi

## Ön koşullar

- Apple Developer Program üyeliği
- Uygulama ikonu (1024x1024)
- Gizlilik politikası URL'si (konum verisi cihazda kalır)

## Xcode hazırlığı

1. Bundle ID: `com.trailhound.app`
2. Widget: `com.trailhound.app.widget`
3. Signing: Automatic + Team seç
4. Capabilities: App Groups, Background Modes (location), CarPlay

## App Store Connect

1. Yeni uygulama oluştur
2. Gizlilik manifest: `PrivacyInfo.xcprivacy` dahil
3. Konum kullanım açıklaması: yolculuk kaydı
4. Ekran görüntüleri: liste, detay harita, istatistik, ayarlar

## TestFlight

1. Archive → Distribute → App Store Connect
2. Internal testing grubu
3. Gerçek sürüş testi checklist:
   - CarPlay (kablolu / kablosuz) ile otomatik kayıt başlat/durdur
   - Klasik Bluetooth-only (CarPlay’siz) ile otomatik kayıt **başlamamalı**
   - Manuel kayıt, widget, export

## CarPlay

- [Apple CarPlay başvurusu](https://developer.apple.com/contact/carplay/)
- App Review notlarında Driving Task kullanım gerekçesi
- Auto-start yalnızca CarPlay sinyallerine bağlıdır (sahne veya `.carAudio`)
