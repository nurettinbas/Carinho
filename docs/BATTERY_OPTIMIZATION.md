# Pil optimizasyonu notları

## Uygulanan stratejiler

1. **Idle:** Eşleşmiş araç yokken `LocationService` tamamen kapalı.
2. **Bağlantı beklerken:** `startVehicleConnectionMonitoring()` — yüz metre doğruluk, 25 m filtre; süreç arka planda canlı kalır ki CarPlay sahne / `.carAudio` değişimi yakalanabilsin.
3. **Kayıt sırasında:** `startTracking()` — navigasyon doğruluğu, 5 m filtre.
4. **Geocoding:** Yalnızca trip başlangıç/bitişinde; offline'da pending, ağ gelince retry.
5. **Polyline:** 1000+ noktada Douglas-Peucker sadeleştirme.
6. **Timer:** Yalnızca aktif kayıtta 1 sn elapsed timer.
7. **CarPlay UI:** Yalnızca CarPlay bağlıyken `refreshCarPlayUI()` çağrılır.
8. **Kayıt animasyonu:** Düşük güç modunda 15 FPS; `reduceMotion` desteklenir.

## Instruments ile doğrulama

1. Gerçek iPhone bağla.
2. Xcode → Product → Profile → Energy Log.
3. Senaryolar: 30 dk sürüş kaydı, arka plan, CarPlay otomatik başlatma.
4. Hedef: kayıt dışında Location Services sürekli aktif olmamalı.

## Arka plan görev denetimi

- Auto-start tetikleyicisi: **yalnızca CarPlay** (`CPTemplateApplicationScene` + `.carAudio` route).
- `BluetoothTriggerService`: klasik A2DP/HFP ile kayıt başlatmaz; `.carAudio` probe için kalır (CoreBluetooth taraması yok).
- Live Activity: yalnızca kayıt sırasında.

## TestFlight öncesi kontrol listesi

- [ ] 2+ saat gerçek sürüşte pil tüketimi kabul edilebilir
- [ ] Kayıt bitince GPS duruyor
- [ ] CarPlay bağlanınca otomatik kayıt başlıyor, kopunca (doğrulama sonrası) duruyor
- [ ] Klasik Bluetooth (CarPlay’siz) müzik açılınca otomatik kayıt **başlamıyor**
