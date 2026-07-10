# TestFlight ve App Store yayın kontrol listesi

## Ön koşullar

- Apple Developer Program üyeliği
- Uygulama ikonu (1024x1024)
- Gizlilik politikası URL'si (konum verisi cihazda kalır)

## Xcode hazırlığı

1. Bundle ID: `com.carinho.app`
2. Widget: `com.carinho.app.widget`
3. Watch: `com.carinho.app.watchkitapp` *(planned — not in Xcode project yet)*
4. Signing: Automatic + Team seç
5. Capabilities: App Groups, Background Modes (location), CarPlay

## App Store Connect

1. Yeni uygulama oluştur
2. Gizlilik manifest: `PrivacyInfo.xcprivacy` dahil
3. Konum kullanım açıklaması: yolculuk kaydı
4. Ekran görüntüleri: liste, detay harita, istatistik, ayarlar

## TestFlight

1. Archive → Distribute → App Store Connect
2. Internal testing grubu
3. Gerçek sürüş testi checklist: otomatik kayıt, Bluetooth, export

## CarPlay

- [Apple CarPlay başvurusu](https://developer.apple.com/contact/carplay/)
- App Review notlarında Driving Task kullanım gerekçesi
