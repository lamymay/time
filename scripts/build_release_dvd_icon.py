#!/usr/bin/env python3
"""
发布用 App Icon：纯黑底 + 10:10 拖尾（多帧、线性变大变亮；适度叠影增强连续性）。
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICON_SET = ROOT / "time/Assets.xcassets/AppIcon.appiconset"
OUT = ICON_SET / "AppIcon-1024.png"
CAND = ROOT / "IconCandidates/icon-release-dvd-trail-1024.png"
SIZE = 1024

# macOS AppIcon.appiconset 各档（像素边长）
MAC_ICON_SIZES: dict[str, int] = {
    "icon_16.png": 16,
    "icon_16@2x.png": 32,
    "icon_32.png": 32,
    "icon_32@2x.png": 64,
    "icon_128.png": 128,
    "icon_128@2x.png": 256,
    "icon_256.png": 256,
    "icon_256@2x.png": 512,
    "icon_512.png": 512,
    "icon_512@2x.png": 1024,
}
BLACK = (0, 0, 0, 255)
LABEL = "10:10"

TRAIL_START = (92.0, 214.0)
TRAIL_END = (908.0, 762.0)
SIZE_MIN = 34
SIZE_MAX = 168
GRAY_MIN = 128
GRAY_MAX = 255
STAMP_COUNT = 12
# 拖尾前段略透明，叠影时亮度过冲更平滑
ALPHA_MIN = 138
ALPHA_MAX = 255

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def trail_stamps(count: int = STAMP_COUNT) -> list[tuple[float, float, int, int, int]]:
    """中心沿对角线等分 t；字号/灰度/透明度均线性。"""
    x0, y0 = TRAIL_START
    x1, y1 = TRAIL_END
    denom = max(count - 1, 1)
    stamps: list[tuple[float, float, int, int, int]] = []

    for i in range(count):
        t = i / denom
        cx = lerp(x0, x1, t)
        cy = lerp(y0, y1, t)
        font_size = int(round(lerp(SIZE_MIN, SIZE_MAX, t)))
        gray = int(round(lerp(GRAY_MIN, GRAY_MAX, t)))
        alpha = int(round(lerp(ALPHA_MIN, ALPHA_MAX, t)))
        stamps.append((cx, cy, font_size, gray, alpha))
    return stamps


def render_time_stamp(font_size: int, gray: int, alpha: int) -> Image.Image:
    font = load_font(font_size)
    pad = max(6, font_size // 12)
    probe = ImageDraw.Draw(Image.new("L", (8, 8)))
    bbox = probe.textbbox((0, 0), LABEL, font=font)
    tw = bbox[2] - bbox[0] + pad * 2
    th = bbox[3] - bbox[1] + pad * 2
    layer = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(
        (pad - bbox[0], pad - bbox[1]),
        LABEL,
        font=font,
        fill=(gray, gray, gray, alpha),
    )
    return layer


def main() -> None:
    canvas = Image.new("RGBA", (SIZE, SIZE), BLACK)
    stamps = trail_stamps()

    for cx, cy, font_size, gray, alpha in stamps:
        logo = render_time_stamp(font_size, gray, alpha)
        x = int(cx - logo.size[0] / 2)
        y = int(cy - logo.size[1] / 2)
        canvas.alpha_composite(logo, (x, y))

    out = Image.new("RGB", (SIZE, SIZE), "#000000")
    out.paste(canvas, mask=canvas.split()[3])

    ICON_SET.mkdir(parents=True, exist_ok=True)
    CAND.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, "PNG", optimize=True)
    out.save(CAND, "PNG", optimize=True)

    resample = Image.Resampling.LANCZOS
    for name, edge in MAC_ICON_SIZES.items():
        scaled = out.resize((edge, edge), resample)
        scaled.save(ICON_SET / name, "PNG", optimize=True)

    sizes = [s[2] for s in stamps]
    grays = [s[3] for s in stamps]
    print(
        f"Wrote {OUT} + {len(MAC_ICON_SIZES)} mac sizes "
        f"({len(stamps)}× {LABEL}; sizes={sizes}, grays={grays})"
    )


if __name__ == "__main__":
    main()
