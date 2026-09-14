import os
import glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW_DIR = "raw_screenshots"
OUT_DIR = "play_store_screenshots"
CANVAS_SIZE = (1080, 1920)
SCREENSHOT_MARGIN_TOP = 420
SCREENSHOT_RESIZE = (840, 1820)
BEZEL_WIDTH = 24
BEZEL_RADIUS = 75
SCREEN_RADIUS = 60

TITLES = [
    "Take Control of Money",
    "Manage Monthly Budgets",
    "Smart AI Assistant",
    "Detailed Analytics",
    "Track All Transactions"
]

GRADIENTS = [
    ((78, 84, 200), (143, 148, 251)),
    ((17, 153, 142), (56, 239, 125)),
    ((255, 95, 109), (255, 195, 113)),
    ((29, 151, 108), (147, 249, 185)),
    ((20, 30, 48), (36, 59, 85)),
    ((236, 0, 140), (252, 103, 103)),
    ((21, 153, 87), (21, 87, 153)),
    ((161, 255, 206), (250, 253, 209))
]

def create_gradient(width, height, color1, color2):
    base = Image.new('RGB', (width, height), color1)
    top = Image.new('RGB', (width, height), color2)
    mask = Image.new('L', (width, height))
    mask_data = [int(255 * (y / height)) for y in range(height) for x in range(width)]
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    return base

def draw_rounded_rect(im, rad, color=(255,255,255,255)):
    circle = Image.new('L', (rad * 2, rad * 2), 0)
    draw = ImageDraw.Draw(circle)
    draw.ellipse((0, 0, rad * 2 - 1, rad * 2 - 1), fill=255)
    alpha = Image.new('L', im.size, 255)
    w, h = im.size
    alpha.paste(circle.crop((0, 0, rad, rad)), (0, 0))
    alpha.paste(circle.crop((0, rad, rad, rad * 2)), (0, h - rad))
    alpha.paste(circle.crop((rad, 0, rad * 2, rad)), (w - rad, 0))
    alpha.paste(circle.crop((rad, rad, rad * 2, rad * 2)), (w - rad, h - rad))
    
    color_layer = Image.new('RGBA', im.size, color)
    color_layer.putalpha(alpha)
    return color_layer

def mask_rounded(im, rad):
    circle = Image.new('L', (rad * 2, rad * 2), 0)
    draw = ImageDraw.Draw(circle)
    draw.ellipse((0, 0, rad * 2 - 1, rad * 2 - 1), fill=255)
    alpha = Image.new('L', im.size, 255)
    w, h = im.size
    alpha.paste(circle.crop((0, 0, rad, rad)), (0, 0))
    alpha.paste(circle.crop((0, rad, rad, rad * 2)), (0, h - rad))
    alpha.paste(circle.crop((rad, 0, rad * 2, rad)), (w - rad, 0))
    alpha.paste(circle.crop((rad, rad, rad * 2, rad * 2)), (w - rad, h - rad))
    im.putalpha(alpha)
    return im

def draw_text(draw, text, y_pos, canvas_width):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 95)
    except:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    draw.text(((canvas_width - text_width) / 2 + 6, y_pos + 6), text, font=font, fill=(0,0,0,100))
    draw.text(((canvas_width - text_width) / 2, y_pos), text, font=font, fill=(255,255,255,255))

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    images = glob.glob(os.path.join(RAW_DIR, "*.png"))
    images.sort()
    
    for idx, img_path in enumerate(images):
        title = TITLES[idx] if idx < len(TITLES) else TITLES[-1]
        grad = GRADIENTS[idx] if idx < len(GRADIENTS) else GRADIENTS[0]
        
        canvas = create_gradient(CANVAS_SIZE[0], CANVAS_SIZE[1], grad[0], grad[1]).convert("RGBA")
        draw_text(ImageDraw.Draw(canvas), title, 160, CANVAS_SIZE[0])
        
        raw_img = Image.open(img_path).convert("RGBA").resize(SCREENSHOT_RESIZE, Image.Resampling.LANCZOS)
        raw_img = mask_rounded(raw_img, SCREEN_RADIUS)
        
        device_w = raw_img.width + (BEZEL_WIDTH * 2)
        device_h = raw_img.height + (BEZEL_WIDTH * 2)
        device = Image.new('RGBA', (device_w, device_h), (0,0,0,0))
        bezel = draw_rounded_rect(device, BEZEL_RADIUS, color=(255,255,255,255))
        device.paste(bezel, (0,0), bezel)
        device.paste(raw_img, (BEZEL_WIDTH, BEZEL_WIDTH), raw_img)
        
        # Draw camera hole
        cam_draw = ImageDraw.Draw(device)
        cam_draw.ellipse((device_w//2 - 15, BEZEL_WIDTH//2 + 10, device_w//2 + 15, BEZEL_WIDTH//2 + 40), fill=(20,20,20,255))
        
        shadow_bg = Image.new("RGBA", CANVAS_SIZE, (0,0,0,0))
        shadow = draw_rounded_rect(device, BEZEL_RADIUS, color=(0,0,0,160))
        shadow_bg.paste(shadow, ((CANVAS_SIZE[0] - device_w) // 2 + 15, SCREENSHOT_MARGIN_TOP + 25), shadow)
        shadow_bg = shadow_bg.filter(ImageFilter.GaussianBlur(35))
        
        canvas.paste(shadow_bg, (0,0), shadow_bg)
        canvas.paste(device, ((CANVAS_SIZE[0] - device_w) // 2, SCREENSHOT_MARGIN_TOP), device)
        
        out_path = os.path.join(OUT_DIR, f"{idx+1}_play_store.png")
        canvas.convert("RGB").save(out_path, "PNG", quality=95)

if __name__ == "__main__":
    main()
