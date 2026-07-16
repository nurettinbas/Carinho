#!/usr/bin/env python3
"""Export Trailhound App Icon layers for Icon Composer (Liquid Glass)."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow required: pip install pillow", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ROOT / "Design" / "AppIconLayers"
EXPORT = LAYERS / "exported"
MASTER_ICON = ROOT / "Trailhound" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
SYMBOL_OUT = ROOT / "Trailhound" / "Trailhound.icon" / "Assets" / "Symbol.png"
TEMPLATE_SYMBOL = LAYERS / "TrailhoundTemplate.icon" / "Assets" / "Symbol.png"


def export_foreground_from_master() -> Path:
    """Strip blue fill from AppIcon.png → transparent Symbol for Liquid Glass."""
    img = Image.open(MASTER_ICON).convert("RGBA")
    px = img.load()
    w, h = img.size

    samples = []
    for y in range(h // 4, 3 * h // 4, 8):
        for x in range(w // 4, 3 * w // 4, 8):
            r, g, b, _ = px[x, y]
            if b > r + 30 and b > 100:
                samples.append((r, g, b))
    if not samples:
        br, bgc, bb = (72, 152, 216)
    else:
        br = int(sum(c[0] for c in samples) / len(samples))
        bgc = int(sum(c[1] for c in samples) / len(samples))
        bb = int(sum(c[2] for c in samples) / len(samples))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            dist = abs(r - br) + abs(g - bgc) + abs(b - bb)
            blue_dom = (b - r) > 35 and b > 120
            near_fill = dist < 90 and blue_dom
            sky = b > 150 and g > 130 and r < 150 and (b - r) > 40 and luma < 215
            is_bg = near_fill or sky
            if luma >= 215 and (b - r) < 60:
                is_bg = False
            if is_bg:
                continue
            alpha = int(max(0, min(255, (luma - 130) / (255 - 130) * 255)))
            if luma > 225:
                alpha = 255
            if alpha < 16:
                continue
            out_px[x, y] = (255, 255, 255, alpha)

    EXPORT.mkdir(parents=True, exist_ok=True)
    path = EXPORT / "00-foreground-from-master.png"
    out.save(path, "PNG")
    SYMBOL_OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(SYMBOL_OUT, "PNG")
    TEMPLATE_SYMBOL.parent.mkdir(parents=True, exist_ok=True)
    out.save(TEMPLATE_SYMBOL, "PNG")
    return path


def export_legacy_copy() -> Path:
    EXPORT.mkdir(parents=True, exist_ok=True)
    out = EXPORT / "AppIcon-legacy-blue.png"
    Image.open(MASTER_ICON).convert("RGBA").save(out, "PNG")
    return out


def main() -> None:
    paths = [
        export_foreground_from_master(),
        export_legacy_copy(),
    ]
    for path in paths:
        print(path)


if __name__ == "__main__":
    main()
