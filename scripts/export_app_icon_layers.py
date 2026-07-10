#!/usr/bin/env python3
"""Export App Icon layers as 1024 PNGs for Icon Composer import."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow required: pip install pillow", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ROOT / "Design" / "AppIconLayers"
EXPORT = LAYERS / "exported"
MASTER_ICON = ROOT / "Carinho" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"


def draw_heart(draw: ImageDraw.ImageDraw, color: str = "#FFFFFF", width: int = 30) -> None:
    draw.line(
        [
            (512, 748),
            (188, 332),
            (308, 168),
            (512, 318),
            (716, 168),
            (836, 332),
            (512, 748),
        ],
        fill=color,
        width=width,
        joint="curve",
    )


def draw_steering_wheel(draw: ImageDraw.ImageDraw, color: str = "#FFFFFF", width: int = 26) -> None:
    cx, cy, r = 512, 612, 118
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=width)
    draw.ellipse((cx - 42, cy - 42, cx + 42, cy + 42), outline=color, width=width)
    draw.line((512, 494, 512, 570), fill=color, width=width)
    draw.line((394, 612, 470, 612), fill=color, width=width)
    draw.line((554, 612, 630, 612), fill=color, width=width)
    draw.line((512, 654, 512, 730), fill=color, width=width)


def draw_road(draw: ImageDraw.ImageDraw) -> None:
    points = [
        (512, 612),
        (512, 560),
        (470, 520),
        (430, 470),
        (400, 360),
        (470, 310),
        (620, 250),
        (700, 290),
    ]
    draw.line(points, fill="#FFFFFF", width=34, joint="curve")
    draw.line(points, fill="#7EC8E8", width=12, joint="curve")


def blank_canvas() -> Image.Image:
    return Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))


def export_layer(name: str, painter) -> Path:
    img = blank_canvas()
    painter(ImageDraw.Draw(img))
    out = EXPORT / f"{name}.png"
    img.save(out, "PNG")
    return out


def export_composite() -> Path:
    img = blank_canvas()
    draw = ImageDraw.Draw(img)
    draw_heart(draw)
    draw_steering_wheel(draw)
    draw_road(draw)
    out = EXPORT / "preview-composite.png"
    img.save(out, "PNG")
    return out


def export_foreground_from_master() -> Path:
    """Mevcut AppIcon.png içinden mavi arka planı kaldırır — Icon Composer için en doğru kaynak."""
    img = Image.open(MASTER_ICON).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if b > 160 and g > 140 and r < 120 and (b - r) > 80:
                px[x, y] = (r, g, b, 0)
    out = EXPORT / "00-foreground-from-master.png"
    img.save(out, "PNG")
    return out


def export_legacy_blue() -> Path:
    """Mevcut düz mavi ikon — iOS 18 ve öncesi fallback."""
    img = Image.new("RGBA", (1024, 1024), "#4FC3F7")
    draw = ImageDraw.Draw(img)
    draw_heart(draw)
    draw_steering_wheel(draw)
    draw_road(draw)
    out = EXPORT / "AppIcon-legacy-blue.png"
    img.save(out, "PNG")
    return out


def main() -> None:
    EXPORT.mkdir(parents=True, exist_ok=True)
    paths = [
        export_foreground_from_master(),
        export_layer("01-heart", lambda d: draw_heart(d)),
        export_layer("02-steering-wheel", lambda d: draw_steering_wheel(d)),
        export_layer("03-road", draw_road),
        export_composite(),
        export_legacy_blue(),
    ]
    for path in paths:
        print(path)


if __name__ == "__main__":
    main()
