# Pil optimizasyonu notları

## Uygulanan stratejiler

1. **Idle:** Eşleşmiş araç yokken `LocationService` tamamen kapalı.
2. **Bağlantı beklerken:** `startVehicleConnectionMonitoring()` — yüz metre doğruluk, 25 m filtre; süreç arka planda canlı kalır ki Bluetooth/CarPlay route değişimi anında yakalansın.
3. **Kayıt sırasında:** `startTracking()` — navigasyon doğruluğu, 5 m filtre.
4. **Geocoding:** Yalnızca trip başlangıç/bitişinde; offline'da pending, ağ gelince retry.
5. **Polyline:** 1000+ noktada Douglas-Peucker sadeleştirme.
6. **Timer:** Yalnızca aktif kayıtta 1 sn elapsed timer.
7. **CarPlay UI:** Yalnızca CarPlay bağlıyken `refreshCarPlayUI()` çağrılır.
8. **Kayıt animasyonu:** Düşük güç modunda 15 FPS; `reduceMotion` desteklenir.

## Instruments ile doğrulama

1. Gerçek iPhone bağla.
2. Xcode → Product → Profile → Energy Log.
3. Senaryolar: 30 dk sürüş kaydı, arka plan, otomatik başlatma.
4. Hedef: kayıt dışında Location Services sürekli aktif olmamalı.

## Arka plan görev denetimi

- `BluetoothTriggerService`: Bluetooth audio route değişikliğini dinler (`AVAudioSession`); CoreBluetooth taraması yok.
- CarPlay: `CPTemplateApplicationScene` durumu + `.carAudio` route ile algılanır.
- Live Activity: yalnızca kayıt sırasında.

## TestFlight öncesi kontrol listesi

- [ ] 2+ saat gerçek sürüşte pil tüketimi kabul edilebilir
- [ ] Kayıt bitince GPS duruyor
- [ ] Araç bağlanınca otomatik kayıt anında başlıyor, kopunca duruyor
