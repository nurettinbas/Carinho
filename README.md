# Carinho

**Privacy-first trip recorder for iOS** — track drives with GPS, estimate fuel cost, and keep every mile on your device. No account, no cloud, no third-party SDKs.

Carinho is a native SwiftUI app built with SwiftData. It records routes locally, works offline, and can start or stop automatically when your car connects via **Bluetooth**, **CarPlay**, or **motion detection**.

[English](#features) · [Türkçe](#özellikler)

---

## Features

### Recording
- Manual start/stop, pause/resume
- Auto-recording via automotive motion + speed thresholds
- **Bluetooth** and **CarPlay** (wired & wireless) vehicle triggers
- Vehicle profiles with fuel/EV cost per trip
- Siri Shortcuts: *Start trip*, *Stop trip*, *Pause trip*
- Widget + Live Activity controls
- CarPlay minimal UI (status, pause, stop)
- Watch companion hooks (WatchConnectivity)

### Privacy & data
- All trips stored locally with **SwiftData**
- Offline-first recording; geocoding retries when online
- Home/work saved places with privacy radius (route clipping)
- Optional Face ID app lock
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

## Requirements

| | |
|---|---|
| **Xcode** | 15+ |
| **iOS** | 17.0+ |
| **Dependencies** | None (Apple frameworks only) |

---

## Getting started

```bash
git clone https://github.com/YOUR_USERNAME/Carinho.git
cd Carinho
open Carinho.xcodeproj
```

1. Select an **iPhone** simulator or device
2. Update **Signing & Capabilities** with your Team (bundle ID: `com.carinho.app`)
3. Ensure App Group `group.com.carinho.app` is enabled for app + widget targets
4. Press **⌘R** to run

### Simulator quick test

1. Tap **Start** in the app
2. **Features → Location → Freeway Drive**
3. Stop after 1–2 minutes, or use **Settings → Demo** sample trip

### Siri Shortcuts

After first launch, open **Shortcuts** → find Carinho → add:
- *Start trip* — `Hey Siri, Carinho start trip`
- *Stop trip* / *Pause trip*

Or use **Settings → Recording → Open Shortcuts** in the app.

---

## Project structure

```
Carinho/
├── App/              # App entry, runtime bootstrap, CarPlay lifecycle
├── Models/           # SwiftData models (Trip, VehicleProfile, …)
├── Services/         # Location, recording, Bluetooth, geocoding, export
├── Views/            # SwiftUI screens
├── Intents/          # App Intents & Siri Shortcuts
├── Utilities/        # L10n, PDF reports, migrations
CarinhoShared/        # App Group bridge (widget, Live Activity, deep links)
CarinhoWidget/        # WidgetKit + Live Activity extension
CarinhoTests/         # Unit tests
docs/                 # Battery optimization, TestFlight checklist
```

**Stack:** SwiftUI · SwiftData · MapKit · CoreLocation · CoreMotion · App Intents · WidgetKit · ActivityKit · CarPlay

---

## Documentation

- [Battery optimization](docs/BATTERY_OPTIMIZATION.md)
- [TestFlight release checklist](docs/TESTFLIGHT_RELEASE.md)

---

## Özellikler (Türkçe)

Carinho, yolculuklarınızı **yalnızca cihazınızda** kaydeden gizlilik odaklı bir sürüş günlüğüdür.

- GPS ile rota ve mesafe takibi
- Bluetooth / CarPlay ile otomatik başlat-bitir
- Siri: *Yolculuğu başlat*, *durdur*, *duraklat*
- Widget ve Live Activity
- İş/kişisel kategori, yakıt/EV maliyet tahmini
- JSON, CSV, GPX, KML, aylık iş PDF export
- Türkçe ve İngilizce arayüz

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
