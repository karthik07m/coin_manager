#!/usr/bin/env python3
import json
from pathlib import Path
import cv2
import numpy as np
import scipy.interpolate as interp
import resvg_py
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
APP_ICON_DIR = ROOT / "assets" / "app_icon"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_RES = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_RES = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WEB_RES = ROOT / "web"

APP_GREEN = "#2ECC71"
WHITE = "#FFFFFF"

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


def smooth_pts(pts, num_pts, s):
    x = np.append(pts[:, 0], pts[0, 0])
    y = np.append(pts[:, 1], pts[0, 1])
    d = np.cumsum(np.hypot(np.diff(x, prepend=x[0]), np.diff(y, prepend=y[0])))
    tck, u = interp.splprep([x, y], u=d, s=s, per=True)
    u_new = np.linspace(u.min(), u.max(), num_pts)
    x_new, y_new = interp.splev(u_new, tck)
    d_str = f"M {x_new[0]:.2f} {y_new[0]:.2f} "
    for px, py in zip(x_new[1:], y_new[1:]):
        d_str += f"L {px:.2f} {py:.2f} "
    d_str += "Z"
    return d_str


def generate_master_svgs(coin_symbol="C", target_width=720):
    raw_path = APP_ICON_DIR / "master_piggy_raw.png"
    img = cv2.imread(str(raw_path))
    SCALE = 8
    large = cv2.resize(img, (492 * SCALE, 428 * SCALE), interpolation=cv2.INTER_CUBIC)
    gray = cv2.cvtColor(large, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    blurred = cv2.GaussianBlur(thresh, (19, 19), 4.5)
    _, thresh_smooth = cv2.threshold(blurred, 128, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(thresh_smooth, cv2.RETR_TREE, cv2.CHAIN_APPROX_NONE)

    # 0: outer stroke, 1: tail hole, 2: body cavity, 3: eye, 4: coin cavity
    d0 = smooth_pts(contours[0].reshape(-1, 2), 1400, 350)
    d1 = smooth_pts(contours[1].reshape(-1, 2), 150, 40)
    d2 = smooth_pts(contours[2].reshape(-1, 2), 1200, 300)
    d3 = smooth_pts(contours[3].reshape(-1, 2), 150, 30)
    d4 = smooth_pts(contours[4].reshape(-1, 2), 400, 100)

    x0, y0, w0, h0 = cv2.boundingRect(contours[0])
    scale = target_width / w0
    target_height = h0 * scale

    pad_x = (1024 - target_width) / 2
    pad_y = (1024 - target_height) / 2
    transform = f"translate({pad_x:.2f}, {pad_y:.2f}) scale({scale:.4f}) translate({-x0}, {-y0})"

    coin_cx = 1888.0
    coin_cy = 1132.5

    # 1. Full Icon SVG (Solid green background + crisp white strokes + white 'C')
    svg_full = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" fill="{APP_GREEN}" />
  <g transform="{transform}">
    <!-- Authentic Piggy Bank Outline with Slot Bar and Coin Insertion -->
    <path d="{d0} {d1} {d2} {d4}" fill="{WHITE}" fill-rule="evenodd" />
    <!-- Happy Eye Arc -->
    <path d="{d3}" fill="{WHITE}" />
    <!-- Bold 'C' in Coin -->
    <text x="{coin_cx}" y="{coin_cy + 14:.1f}" font-family="Arial Rounded MT Bold, SF Pro Rounded, system-ui, sans-serif" font-size="360" font-weight="900" fill="{WHITE}" text-anchor="middle" dominant-baseline="central">{coin_symbol}</text>
  </g>
</svg>"""

    # 2. Transparent Foreground SVG (for Android adaptive icons)
    svg_foreground = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <g transform="{transform}">
    <path d="{d0} {d1} {d2} {d4}" fill="{WHITE}" fill-rule="evenodd" />
    <path d="{d3}" fill="{WHITE}" />
    <text x="{coin_cx}" y="{coin_cy + 14:.1f}" font-family="Arial Rounded MT Bold, SF Pro Rounded, system-ui, sans-serif" font-size="360" font-weight="900" fill="{WHITE}" text-anchor="middle" dominant-baseline="central">{coin_symbol}</text>
  </g>
</svg>"""

    return svg_full, svg_foreground


def save_resized(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(size, int):
        size = (size, size)
    img.resize(size, Image.Resampling.LANCZOS).save(path)


def update_apple_icons(img, dir_path):
    contents_path = dir_path / "Contents.json"
    if not contents_path.exists():
        return

    with open(contents_path, "r") as f:
        data = json.load(f)

    for image_info in data.get("images", []):
        filename = image_info.get("filename")
        if not filename:
            continue

        size_str = image_info.get("size", "0x0")
        scale_str = image_info.get("scale", "1x")

        base_size = float(size_str.split("x")[0])
        scale = float(scale_str.replace("x", ""))

        target_size = int(base_size * scale)
        save_resized(img, dir_path / filename, target_size)


def main():
    print("Generating master SVGs...")
    APP_ICON_DIR.mkdir(parents=True, exist_ok=True)

    svg_full, svg_foreground = generate_master_svgs(coin_symbol="C", target_width=720)

    full_path = APP_ICON_DIR / "coinly_android_icon_1024.png"
    fg_path = APP_ICON_DIR / "coinly_android_foreground_1024.png"

    print("Rendering 1024x1024 raster icons...")
    with open(full_path, "wb") as f:
        f.write(resvg_py.svg_to_bytes(svg_full))
    with open(fg_path, "wb") as f:
        f.write(resvg_py.svg_to_bytes(svg_foreground))

    icon = Image.open(full_path).convert("RGBA")
    foreground = Image.open(fg_path).convert("RGBA")

    print("Saving Play Store 512x512...")
    save_resized(icon, APP_ICON_DIR / "coinly_play_store_icon_512.png", 512)

    print("Updating Android mipmap resources...")
    for folder, size in LEGACY_SIZES.items():
        save_resized(icon, ANDROID_RES / folder / "ic_launcher.png", size)

    for folder, size in FOREGROUND_SIZES.items():
        save_resized(foreground, ANDROID_RES / folder / "ic_launcher_foreground.png", size)

    print("Updating iOS & macOS assets...")
    update_apple_icons(icon, IOS_RES)
    update_apple_icons(icon, MACOS_RES)

    print("Updating Web icons...")
    if WEB_RES.exists():
        save_resized(icon, WEB_RES / "favicon.png", 64)
        icons_dir = WEB_RES / "icons"
        if icons_dir.exists():
            save_resized(icon, icons_dir / "Icon-192.png", 192)
            save_resized(icon, icons_dir / "Icon-512.png", 512)
            save_resized(icon, icons_dir / "Icon-maskable-192.png", 192)
            save_resized(icon, icons_dir / "Icon-maskable-512.png", 512)

    print("SUCCESS: All app icons successfully generated and updated across Android, iOS, macOS, and Web!")


if __name__ == "__main__":
    main()
