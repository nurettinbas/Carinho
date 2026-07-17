# TestFlight ve App Store yayın kontrol listesi

## Ön koşullar

- Apple Developer Program üyeliği
- Uygulama ikonu (1024x1024)
- Gizlilik politikası URL'si (konum verisi cihazda kalır)

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
3. Gerçek sürüş testi checklist:
   - Eşleşmiş araca Bluetooth ile bağlanınca otomatik kayıt başla (müzik çalmadan)
   - Araçtan ayrılınca / Bluetooth kesilince otomatik kayıt dur
   - Eşleşmemiş cihazlara (AirPods vb.) bağlanınca kayıt **başlamamalı**
   - Manuel kayıt, widget, export

## Bluetooth otomatik başlatma

- Auto-start yalnızca eşleşmiş aracın Bluetooth ses rotasına bağlıdır (`AVAudioSessionPortDescription.uid` eşleşmesi).
- Ek entitlement gerekmez; yalnızca konum ve arka plan konum modu kullanılır.
