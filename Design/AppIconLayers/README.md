# Trailhound — Liquid Glass App Icon

Bu klasör, **Icon Composer** (Xcode 26+) ile Liquid Glass ikon üretmek için kaynaklardır.

## Aktif ikon

| Dosya | Rol |
|-------|-----|
| `Trailhound/Trailhound.icon` | iOS 26+ Liquid Glass (şeffaf `Symbol.png` + mavi fill) |
| `Trailhound/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | iOS 18 ve öncesi düz 1024 ikon |

Katmanlar:

| Dosya | İçerik |
|-------|--------|
| `exported/00-foreground-from-master.png` | Şeffaf zemin üzerinde beyaz köpek + yol |
| `exported/AppIcon-legacy-blue.png` | Mavi arka planlı düz ikon kopyası |
| `exported/preview-liquid-glass-layers.png` | Fill + symbol önizlemesi |

Yeniden üretmek:

```bash
python3 scripts/export_app_icon_layers.py
```

## Icon Composer

1. Xcode → Open Developer Tool → **Icon Composer**
2. `Trailhound/Trailhound.icon` dosyasını aç
3. Clear / Tinted önizlemelerinde cam efektini kontrol et (`is-glass` açık)
4. Kaydet → Xcode’da Cmd+B

Target → **General** → **App Icon** = `Trailhound`

## Tasarım notları

- Logo **şeffaf zemin üzerinde** beyaz silüet; cam efekti sistem / Icon Composer verir
- Gölge ve parlamayı fazla bake etme — Liquid Glass runtime’da ekler
- App Store marketing için düz 1024 PNG (`AppIcon.png`) hâlâ gerekir
