# Carinho — Liquid Glass App Icon

Bu klasör, **Icon Composer** (Xcode 26+) ile şeffaf arka planlı Liquid Glass ikon üretmek için katman kaynaklarıdır.

## Katmanlar

| Dosya | İçerik |
|-------|--------|
| `exported/00-foreground-from-master.png` | **Önerilen** — mevcut ikondan şeffaf arka planlı logo |
| `01-heart.svg` | Kalp çerçevesi (vektör, ince ayar için) |
| `02-steering-wheel.svg` | Direksiyon |
| `03-road.svg` | Yol çizgisi + hafif mavi vurgu |
| `preview-composite.svg` | Tüm katmanların önizlemesi (arka plan yok) |

PNG dışa aktarmak için:

```bash
python3 scripts/export_app_icon_layers.py
```

Çıktılar: `Design/AppIconLayers/exported/*.png`

## Icon Composer adımları

1. **Icon Composer** uygulamasını aç (Xcode → Open Developer Tool → Icon Composer).
2. Projede `Carinho/Carinho.icon` dosyası zaten var — doğrudan aç ve ince ayar yap.
3. Clear / Tinted önizlemelerinde cam efektini kontrol et; gerekirse katmana **Glass** materyal ver.
4. Kaydet → Xcode’da yeniden derle.

Otomatik oluşturmak için (geliştirici):

```bash
python3 scripts/export_app_icon_layers.py
iconkit generate sf --symbol "heart.fill" --background "#42A5F5" --output Design/AppIconLayers/CarinhoTemplate.icon
# Logo katmanını Carinho.icon/Assets/Symbol.png olarak kopyala
```

5. Target → **General** → **App Icon** = `Carinho` (zaten ayarlı).

## Eski iOS için fallback

`Assets.xcassets/AppIcon.appiconset` içindeki mevcut **mavi arka planlı** `AppIcon.png` dosyasını **silme**. iOS 18 ve öncesi bu düz ikonu kullanır; iOS 26+ `.icon` dosyasını tercih eder.

İstersen `exported/AppIcon-legacy-blue.png` ile mevcut görünümü yeniden üretebilirsin.

## Tasarım notları

- Logo **şeffaf zemin üzerinde** beyaz çizgi; cam efekti Icon Composer’da verilir.
- Gölge, parlama ve kenar yuvarlamayı **önceden bake etme** — sistem ekler.
- App Store için 1024 düz PNG hâlâ gerekli; `.icon` bunun yerine geçmez, tamamlar.

## Widget / bildirim

Widget ve Live Activity ikonları ayrı asset’lerdir; sadece ana uygulama ikonu `.icon` ile güncellenir.
