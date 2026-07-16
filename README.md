# Trailhound

**Privacy-first trip recorder for iOS** — track drives with GPS, estimate fuel cost, and keep every mile on your device. No account, no cloud, no third-party SDKs.

Trailhound is a native SwiftUI app built with SwiftData. It records routes locally, works offline, and starts automatically the moment your paired car connects via **CarPlay** (wired or wireless) — and stops when it disconnects.

[English](#features) · [Türkçe](#özellikler)

---

## Features

### Recording
- Manual start/stop, pause/resume
- **Connect-start / disconnect-stop**: recording begins automatically when the paired vehicle connects on **CarPlay** and ends when CarPlay disconnects (no motion or speed checks)
- **CarPlay** (wired & wireless) auto-start — detected via CarPlay scene and/or `.carAudio` route (classic Bluetooth-only audio is not used as a trigger)
- Vehicle profiles with fuel/EV cost per trip
- Siri Shortcuts: *Start trip*, *Pause trip*, *Resume trip*, *End trip*
- Widget + Live Activity controls
- CarPlay minimal UI (status, pause, stop)

### Privacy & data
- All trips stored locally with **SwiftData** (file protection on store)
- Offline-first recording; geocoding retries when online
- Home/work saved places with privacy radius (route clipping)
- Optional Face ID app lock (device passcode required)
- Optional confirmation before widget/shortcut/deep-link recording start
- Configurable auto-delete (30/90/365 days)
- Export: JSON, CSV, GPX, KML, monthly business PDF

### Maps & analytics
- MapKit route polylines with speed-colored segments
- Trip stops (dwell detection), route thumbnails
- Swift Charts stats, trends, monthly goals
- Frequent routes, category filters, trip merge/split

### Organization
- Personal / business categories (+ custom)
- Vehicle management (petrol, diesel, hybrid, EV)
- In-app notifications inbox
- Turkish & English UI (Localizable.xcstrings)

---

## Platform support

| Platform | Minimum version | Status |
|----------|-----------------|--------|
| **iPhone (iOS)** | **17.0** | ✅ Primary target |
| **iPadOS** | 17.0 | ⚠️ Runs as iPhone app (not optimized for iPad) |
| **CarPlay** | iOS 17.0+ | ✅ Wired & wireless |
| **Widget + Live Activity** | iOS 17.0+ | ✅ Home Screen & Lock Screen |
| **Siri / Shortcuts** | iOS 17.0+ | ✅ App Intents (4 recording actions) |
| **macOS / visionOS / tvOS** | — | ❌ Not supported |

### Why iOS 17?

Trailhound uses **SwiftData**, **App Intents**, **Live Activities**, and modern **WidgetKit** APIs that require iOS 17. The project does not build for iOS 16 or earlier.

### Device & permissions

| Requirement | Used for |
|-------------|----------|
| GPS (Always / When In Use) | Route recording, background trips, keeping the connection monitor alive |
| CarPlay (scene / `.carAudio`) | Auto-start connect/disconnect trigger |
| Notifications | Trip started/ended alerts |
| Face ID (optional) | App lock |
| CarPlay entitlement | In-car status & controls |

**Physical iPhone recommended** for real-world testing (GPS, CarPlay, background recording). Simulator is fine for UI and basic location simulation.

---

## Requirements (development)

| | |
|---|---|
| **Xcode** | 15.0+ (iOS 17 SDK) |
| **Swift** | 5.0 (strict concurrency enabled) |
| **iOS deployment target** | 17.0 |
| **Dependencies** | None (Apple frameworks only) |
| **Bundle IDs** | `com.trailhound.app` · `com.trailhound.app.widget` |
| **App Group** | `group.com.trailhound.app` |

---

## Getting started

```bash
git clone https://github.com/YOUR_USERNAME/Trailhound.git
cd Trailhound
open Trailhound.xcodeproj
```

1. Select an **iPhone** simulator or device
2. Update **Signing & Capabilities** with your Team (bundle ID: `com.trailhound.app`)
3. Ensure App Group `group.com.trailhound.app` is enabled for app + widget targets
4. Press **⌘R** to run

### Simulator quick test

1. Tap **Start** in the app
2. **Features → Location → Freeway Drive**
3. Stop after 1–2 minutes

### Siri Shortcuts

Requires **iOS 17+** and **Siri enabled**. After first launch:

1. Open **Shortcuts** → search **Trailhound**
2. Add the four actions: **Start trip**, **Pause trip**, **Resume trip**, **End trip**
3. Or use **Settings → Recording → Open Shortcuts** in the app

**English Siri examples:** *“Start trip in Trailhound”*, *“Pause trip in Trailhound”*

**Turkish Siri examples:** *“Trailhound yolculuğu başlat”*, *“Trailhound yolculuğu duraklat”*, *“Trailhound yolculuğu sürdür”*, *“Trailhound yolculuğu bitir”*

> Siri language and system language can differ. Shortcuts list follows system language; voice phrases follow Siri language.

---

## Project structure

```
Trailhound/
├── App/              # App entry, runtime bootstrap, CarPlay lifecycle
├── Models/           # SwiftData models (Trip, VehicleProfile, …)
├── Services/         # Location, recording, CarPlay connection, geocoding, export
├── Views/            # SwiftUI screens
├── Intents/          # App Intents & Siri Shortcuts
├── Utilities/        # L10n, PDF reports, migrations
TrailhoundShared/        # App Group bridge (widget, Live Activity, deep links)
TrailhoundWidget/        # WidgetKit + Live Activity extension
TrailhoundTests/         # Unit tests
docs/                 # Battery optimization, TestFlight checklist
```

**Stack:** SwiftUI · SwiftData · MapKit · CoreLocation · App Intents · WidgetKit · ActivityKit · CarPlay

---

## Documentation

- [Battery optimization](docs/BATTERY_OPTIMIZATION.md)
- [TestFlight release checklist](docs/TESTFLIGHT_RELEASE.md)

---

## Özellikler (Türkçe)

Trailhound, yolculuklarınızı **yalnızca cihazınızda** kaydeden gizlilik odaklı bir sürüş günlüğüdür.

- GPS ile rota ve mesafe takibi
- **CarPlay** (kablolu / kablosuz) ile otomatik başlat-bitir
- Siri: *Yolculuğu başlat*, *duraklat*, *sürdür*, *bitir*
- Widget ve Live Activity
- İş/kişisel kategori, yakıt/EV maliyet tahmini
- JSON, CSV, GPX, KML, aylık iş PDF export
- Türkçe ve İngilizce arayüz

### Platform desteği

| Platform | Minimum sürüm | Durum |
|----------|---------------|-------|
| **iPhone (iOS)** | **17.0** | ✅ Ana hedef |
| **iPadOS** | 17.0 | ⚠️ iPhone uygulaması olarak çalışır |
| **CarPlay** | iOS 17.0+ | ✅ Kablolu ve kablosuz |
| **Widget + Live Activity** | iOS 17.0+ | ✅ Ana ekran ve kilit ekranı |
| **Siri / Kısayollar** | iOS 17.0+ | ✅ 4 kayıt eylemi |
| **macOS / visionOS / tvOS** | — | ❌ Desteklenmiyor |

**iOS 17 zorunlu** — SwiftData, App Intents ve Live Activity bu sürümü gerektirir. iOS 16 ve altı desteklenmez.

Gerçek sürüş ve CarPlay testleri için **fiziksel iPhone** önerilir.

---

## Contributing

Issues and pull requests are welcome. Please open an issue before large changes.

---

## License

[MIT](LICENSE) — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with Swift · No analytics · No tracking · Your roads, your data.</sub>
</p>
