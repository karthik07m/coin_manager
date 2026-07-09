#!/usr/bin/env python3
from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
APP_ICON_DIR = ROOT / "assets" / "app_icon"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"

LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(4))


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size, size], radius=radius, fill=255)
    return mask


def radial_background(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    center_x = size * 0.34
    center_y = size * 0.22
    max_d = math.sqrt((size - center_x) ** 2 + (size - center_y) ** 2)
    start = (35, 40, 48, 255)
    mid = (15, 17, 21, 255)
    end = (7, 8, 11, 255)

    for y in range(size):
        for x in range(size):
            d = math.sqrt((x - center_x) ** 2 + (y - center_y) ** 2) / max_d
            if d < 0.55:
                color = mix(start, mid, d / 0.55)
            else:
                color = mix(mid, end, (d - 0.55) / 0.45)
            px[x, y] = color
    return img


def paste_alpha(base, layer):
    base.alpha_composite(layer)


def draw_soft_shadow(base, bbox, radius, opacity, blur):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(bbox, radius=radius, fill=(0, 0, 0, opacity))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    paste_alpha(base, shadow)


def draw_linear_gradient_ellipse(size, bbox, colors):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse(bbox, fill=255)
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = grad.load()
    x1, y1, x2, y2 = bbox
    for y in range(max(0, y1), min(size, y2 + 1)):
        for x in range(max(0, x1), min(size, x2 + 1)):
            t = ((x - x1) + (y - y1)) / ((x2 - x1) + (y2 - y1))
            if t < 0.46:
                color = mix(colors[0], colors[1], t / 0.46)
            else:
                color = mix(colors[1], colors[2], (t - 0.46) / 0.54)
            px[x, y] = color
    layer = Image.composite(grad, layer, mask)
    return layer


def font(size):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Verdana Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw_finance_mark(base, include_background):
    size = base.size[0]
    s = size / 1024

    if include_background:
        bg = radial_background(size)
        mask = rounded_mask(size, int(228 * s))
        base.alpha_composite(Image.composite(bg, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))

        glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse(
            [int(218 * s), int(142 * s), int(850 * s), int(794 * s)],
            fill=(46, 204, 113, 70),
        )
        paste_alpha(base, glow.filter(ImageFilter.GaussianBlur(int(58 * s))))

        sheen = Image.new("RGBA", base.size, (0, 0, 0, 0))
        ImageDraw.Draw(sheen).pieslice(
            [int(-120 * s), int(-180 * s), int(720 * s), int(620 * s)],
            start=200,
            end=340,
            fill=(255, 255, 255, 20),
        )
        paste_alpha(base, sheen.filter(ImageFilter.GaussianBlur(int(18 * s))))

    draw_soft_shadow(
        base,
        [int(214 * s), int(272 * s), int(806 * s), int(714 * s)],
        int(94 * s),
        120,
        int(34 * s),
    )

    card = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle(
        [int(198 * s), int(258 * s), int(826 * s), int(700 * s)],
        radius=int(92 * s),
        fill=(24, 27, 33, 255),
        outline=(64, 71, 82, 180),
        width=max(1, int(4 * s)),
    )
    d.rounded_rectangle(
        [int(236 * s), int(306 * s), int(786 * s), int(394 * s)],
        radius=int(42 * s),
        fill=(35, 40, 48, 255),
    )
    d.rounded_rectangle(
        [int(284 * s), int(332 * s), int(486 * s), int(354 * s)],
        radius=int(11 * s),
        fill=(46, 204, 113, 235),
    )
    d.rounded_rectangle(
        [int(536 * s), int(332 * s), int(700 * s), int(354 * s)],
        radius=int(11 * s),
        fill=(255, 215, 0, 220),
    )
    d.line(
        [
            (int(284 * s), int(604 * s)),
            (int(380 * s), int(538 * s)),
            (int(472 * s), int(566 * s)),
            (int(612 * s), int(458 * s)),
            (int(724 * s), int(490 * s)),
        ],
        fill=(255, 215, 0, 210),
        width=int(22 * s),
        joint="curve",
    )
    for x, y in [(380, 538), (472, 566), (612, 458), (724, 490)]:
        d.ellipse(
            [int((x - 15) * s), int((y - 15) * s), int((x + 15) * s), int((y + 15) * s)],
            fill=(255, 231, 92, 255),
        )
    paste_alpha(base, card)

    coin_shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(coin_shadow).ellipse(
        [int(260 * s), int(374 * s), int(766 * s), int(884 * s)],
        fill=(0, 0, 0, 135),
    )
    paste_alpha(base, coin_shadow.filter(ImageFilter.GaussianBlur(int(30 * s))))

    rim = draw_linear_gradient_ellipse(
        size,
        [int(252 * s), int(328 * s), int(772 * s), int(848 * s)],
        [(174, 255, 211, 255), (46, 204, 113, 255), (6, 77, 39, 255)],
    )
    paste_alpha(base, rim)

    face = draw_linear_gradient_ellipse(
        size,
        [int(300 * s), int(376 * s), int(724 * s), int(800 * s)],
        [(199, 255, 225, 255), (55, 219, 129, 255), (26, 148, 80, 255)],
    )
    paste_alpha(base, face)

    d = ImageDraw.Draw(base)
    for r, alpha, width in [(218, 110, 7), (178, 88, 4)]:
        d.ellipse(
            [int((512 - r) * s), int((588 - r) * s), int((512 + r) * s), int((588 + r) * s)],
            outline=(211, 255, 229, alpha),
            width=max(1, int(width * s)),
        )

    mark_font = font(int(430 * s))
    mark = "C"
    mark_bbox = d.textbbox((0, 0), mark, font=mark_font, stroke_width=0)
    mark_w = mark_bbox[2] - mark_bbox[0]
    mark_h = mark_bbox[3] - mark_bbox[1]
    mark_x = int(514 * s - mark_w / 2 - mark_bbox[0])
    mark_y = int(606 * s - mark_h / 2 - mark_bbox[1])
    d.text(
        (mark_x, mark_y - int(8 * s)),
        mark,
        font=mark_font,
        fill=(211, 255, 229, 92),
    )
    d.text(
        (mark_x, mark_y + int(8 * s)),
        mark,
        font=mark_font,
        fill=(4, 48, 28, 190),
    )
    d.text(
        (mark_x, mark_y),
        mark,
        font=mark_font,
        fill=(6, 61, 34, 255),
    )

    d.ellipse(
        [int(336 * s), int(392 * s), int(446 * s), int(502 * s)],
        fill=(255, 244, 153, 210),
    )
    d.ellipse(
        [int(356 * s), int(412 * s), int(426 * s), int(482 * s)],
        fill=(55, 219, 129, 120),
    )

    highlight = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(highlight).ellipse(
        [int(306 * s), int(358 * s), int(650 * s), int(554 * s)],
        fill=(255, 255, 255, 48),
    )
    highlight = highlight.rotate(-24, resample=Image.Resampling.BICUBIC, center=(int(478 * s), int(456 * s)))
    paste_alpha(base, highlight.filter(ImageFilter.GaussianBlur(int(6 * s))))


def make_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_finance_mark(img, include_background=True)
    return img


def make_foreground(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_finance_mark(img, include_background=False)
    return img


def save_resized(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.Resampling.LANCZOS).save(path)


def main():
    APP_ICON_DIR.mkdir(parents=True, exist_ok=True)
    icon = make_icon(1024)
    foreground = make_foreground(1024)

    icon.save(APP_ICON_DIR / "coinly_android_icon_1024.png")
    foreground.save(APP_ICON_DIR / "coinly_android_foreground_1024.png")

    for folder, size in LEGACY_SIZES.items():
        save_resized(icon, ANDROID_RES / folder / "ic_launcher.png", size)

    for folder, size in FOREGROUND_SIZES.items():
        save_resized(foreground, ANDROID_RES / folder / "ic_launcher_foreground.png", size)


if __name__ == "__main__":
    main()
