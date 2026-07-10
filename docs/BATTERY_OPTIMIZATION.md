# Pil optimizasyonu notları

## Uygulanan stratejiler

1. **Idle:** `LocationService` tamamen kapalı.
2. **Automotive beklerken:** `startLowPowerMonitoring()` — yüz metre doğruluk, 50 m filtre.
3. **Kayıt sırasında:** `startTracking()` — 10 m doğruluk, 10 m filtre.
4. **Geocoding:** Yalnızca trip başlangıç/bitişinde; offline'da pending, ağ gelince retry.
5. **Polyline:** 1000+ noktada Douglas-Peucker sadeleştirme.
6. **Timer:** Yalnızca aktif kayıtta 1 sn elapsed timer.

## Instruments ile doğrulama

1. Gerçek iPhone bağla.
2. Xcode → Product → Profile → Energy Log.
3. Senaryolar: 30 dk sürüş kaydı, arka plan, otomatik başlatma.
4. Hedef: kayıt dışında Location Services sürekli aktif olmamalı.

## Arka plan görev denetimi

- `CMMotionActivityManager` automotive izleme: düşük maliyet.
- `BluetoothTriggerService` scan: yalnızca ayarlarda araç seçiliyken anlamlı; pil etkisi için tarama aralığı sistem tarafından yönetilir.
- Live Activity: yalnızca kayıt sırasında.

## TestFlight öncesi kontrol listesi

- [ ] 2+ saat gerçek sürüşte pil tüketimi kabul edilebilir
- [ ] Kayıt bitince GPS duruyor
- [ ] Otomatik kayıt gecikmesi < 30 sn (automotive + hız)
