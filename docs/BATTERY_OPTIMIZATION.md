# Pil optimizasyonu notları

## Uygulanan stratejiler

1. **Idle:** Eşleşmiş araç yokken `LocationService` tamamen kapalı.
2. **Bağlantı beklerken:** `startVehicleConnectionMonitoring()` — yüz metre doğruluk, 25 m filtre; süreç arka planda canlı kalır ki Bluetooth ses rotası değişimi yakalanabilsin.
3. **Kayıt sırasında:** `startTracking()` — navigasyon doğruluğu, 5 m filtre.
4. **Geocoding:** Yalnızca trip başlangıç/bitişinde; offline'da pending, ağ gelince retry.
5. **Polyline:** 1000+ noktada Douglas-Peucker sadeleştirme.
6. **Timer:** Yalnızca aktif kayıtta 1 sn elapsed timer.
7. **Kayıt animasyonu:** Düşük güç modunda 15 FPS; `reduceMotion` desteklenir.

## Instruments ile doğrulama

1. Gerçek iPhone bağla.
2. Xcode → Product → Profile → Energy Log.
3. Senaryolar: 30 dk sürüş kaydı, arka plan, Bluetooth otomatik başlatma.
4. Hedef: kayıt dışında Location Services sürekli aktif olmamalı.

## Arka plan görev denetimi

- Auto-start tetikleyicisi: **yalnızca eşleşmiş araç** (Bluetooth ses rotası, `uid` eşleşmesi).
- `BluetoothTriggerService`: `AVAudioSession` rota değişimini dinler (A2DP/HFP/LE/carAudio); CoreBluetooth taraması yok.
- Live Activity: yalnızca kayıt sırasında.

## TestFlight öncesi kontrol listesi

- [ ] 2+ saat gerçek sürüşte pil tüketimi kabul edilebilir
- [ ] Kayıt bitince GPS duruyor
- [ ] Eşleşmiş araca Bluetooth ile bağlanınca otomatik kayıt başlıyor (müzik çalmadan), kopunca (doğrulama sonrası) duruyor
- [ ] Eşleşmemiş cihazlara (AirPods vb.) bağlanınca otomatik kayıt **başlamıyor**
