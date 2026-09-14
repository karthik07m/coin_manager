import os
import urllib.request
import ssl
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ssl._create_default_https_context = ssl._create_unverified_context

CANVAS_SIZE = (1080, 1920)
BG_COLOR = (227, 247, 223) # Light green #E3F7DF
HILL_COLOR = (121, 193, 104) # Darker green #79C168
DEVICE_Y = 550
DEVICE_SIZE = (860, 1850)
BEZEL_WIDTH = 0 

PIGGY_BANK_PATH = "/Users/manikarthik/.gemini/antigravity-ide/brain/226fd434-5e41-4bc1-8c53-27e04cc4ec04/piggy_bank_asset_1787525350312.jpg"
SCREENSHOT_PATH = "raw_screenshots/long_screen.png"
OUT_PATH = "play_store_screenshots/budget_promo_custom.png"

ICONS = {
    "dashboard": "https://raw.githubusercontent.com/google/material-design-icons/master/png/action/dashboard/materialicons/48dp/2x/baseline_dashboard_black_48dp.png",
    "restaurant": "https://raw.githubusercontent.com/google/material-design-icons/master/png/maps/restaurant/materialicons/48dp/2x/baseline_restaurant_black_48dp.png",
    "cart": "https://raw.githubusercontent.com/google/material-design-icons/master/png/action/shopping_cart/materialicons/48dp/2x/baseline_shopping_cart_black_48dp.png",
    "bag": "https://raw.githubusercontent.com/google/material-design-icons/master/png/action/shopping_bag/materialicons/48dp/2x/baseline_shopping_bag_black_48dp.png"
}

def download_icons():
    os.makedirs("temp_icons", exist_ok=True)
    for name, url in ICONS.items():
        path = f"temp_icons/{name}.png"
        if not os.path.exists(path):
            try:
                urllib.request.urlretrieve(url, path)
            except Exception as e:
                print(f"Failed to download {name}: {e}")

def remove_white_bg(img, threshold=240):
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []
    for item in data:
        if item[0] > threshold and item[1] > threshold and item[2] > threshold:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img

def tint_image(img, color):
    img = img.convert("RGBA")
    alpha = img.split()[3]
    color_img = Image.new('RGB', img.size, color)
    color_img.putalpha(alpha)
    return color_img

def draw_rounded_rect(im, rad, color):
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

def draw_curved_hill(draw):
    bbox = (-500, 1850, CANVAS_SIZE[0] + 500, CANVAS_SIZE[1] + 800)
    draw.ellipse(bbox, fill=HILL_COLOR)

def draw_text_centered(draw, text, y_pos, font, fill=(0,0,0,255), line_spacing=10):
    lines = text.split('\n')
    current_y = y_pos
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        draw.text(((CANVAS_SIZE[0] - text_width) / 2, current_y), line, font=font, fill=fill)
        current_y += text_height + line_spacing

def create_shadow(size, rad, blur_radius, color=(0,0,0,40)):
    shadow_bg = Image.new("RGBA", (size[0] + blur_radius*4, size[1] + blur_radius*4), (0,0,0,0))
    shadow_rect = draw_rounded_rect(Image.new("RGBA", size), rad, color)
    shadow_bg.paste(shadow_rect, (blur_radius*2, blur_radius*2))
    return shadow_bg.filter(ImageFilter.GaussianBlur(blur_radius))

def get_font(size):
    try:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", size)
    except:
        return ImageFont.load_default()

def draw_floating_card(canvas):
    card_w, card_h = 480, 220
    card = Image.new("RGBA", (card_w, card_h), (0,0,0,0))
    
    shadow = create_shadow((card_w, card_h), 25, 20, (0,0,0,50))
    canvas.paste(shadow, (20, 1050), shadow)
    
    card_bg = draw_rounded_rect(Image.new("RGBA", (card_w, card_h)), 25, (255, 255, 255, 255))
    canvas.paste(card_bg, (50, 1080), card_bg)
    
    draw = ImageDraw.Draw(canvas)
    f_large = get_font(60)
    f_small = get_font(35)
    
    draw.text((70, 1120), "$1000 ", font=f_large, fill=(0,0,0,255))
    draw.text((270, 1140), "/ 1 Month", font=f_small, fill=(0,0,0,255))
    draw.text((120, 1220), "beginning  Aug 1", font=f_small, fill=(0,0,0,255))
    
    draw.line([(80, 1195), (420, 1195)], fill=(230,230,230,255), width=2)
    draw.line([(120, 1270), (430, 1270)], fill=(230,230,230,255), width=2)

def draw_category_icons(canvas):
    colors = [
        (220, 240, 220, 255), 
        (200, 210, 230, 255), 
        (190, 230, 190, 255), 
        (255, 180, 200, 255)  
    ]
    icon_names = ["dashboard", "restaurant", "cart", "bag"]
    
    y = 380
    start_x = 220
    spacing = 160
    size = 130
    
    for i in range(4):
        x = start_x + (spacing * i)
        
        shadow = create_shadow((size, size), 30, 15, (0,0,0,30))
        canvas.paste(shadow, (x - 30, y - 30), shadow)
        
        base = draw_rounded_rect(Image.new("RGBA", (size, size)), 35, colors[i])
        canvas.paste(base, (x, y), base)
        
        if i == 0:
            border_rect = draw_rounded_rect(Image.new("RGBA", (size+6, size+6)), 38, (20,40,20,255))
            canvas.paste(border_rect, (x-3, y-3), border_rect)
            canvas.paste(base, (x, y), base)

        icon_path = f"temp_icons/{icon_names[i]}.png"
        if os.path.exists(icon_path):
            img_icon = Image.open(icon_path).convert("RGBA").resize((70, 70), Image.Resampling.LANCZOS)
            img_icon = tint_image(img_icon, (40, 40, 40))
            canvas.paste(img_icon, (x + 30, y + 30), img_icon)

def main():
    download_icons()
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    
    canvas = Image.new("RGBA", CANVAS_SIZE, BG_COLOR)
    draw = ImageDraw.Draw(canvas)
    
    title_font = get_font(110)
    draw_text_centered(draw, "Create a Budget\nfor You", 120, title_font)
    
    draw_category_icons(canvas)
    
    if os.path.exists(SCREENSHOT_PATH):
        raw_img = Image.open(SCREENSHOT_PATH).convert("RGBA")
        w, h = raw_img.size
        
        # We need to remove the big green "CATEGORY BUDGET" card in the middle 
        # so the category breakdown list is visible within the phone frame!
        w, h = raw_img.size
        
        # Part 1: Top of the screen
        # Cropping from y=130 (below status bar) to y=950 to pull the list up more
        part1 = raw_img.crop((0, 130, w, 950))
        
        # Part 2: Category Breakdown list (starts around y=1750)
        part2 = raw_img.crop((0, 1750, w, h))
        
        # Stitch them together
        stitched_h = part1.height + part2.height
        stitched = Image.new("RGBA", (w, stitched_h))
        stitched.paste(part1, (0, 0))
        stitched.paste(part2, (0, part1.height))
        
        # Now calculate how much we need for the device frame
        target_aspect = DEVICE_SIZE[1] / DEVICE_SIZE[0]
        target_h = int(w * target_aspect)
        
        if stitched_h < target_h:
            # Pad bottom to prevent squishing
            padded = Image.new("RGBA", (w, target_h), (20, 20, 22, 255))
            padded.paste(stitched, (0, 0))
            stitched = padded
            stitched_h = target_h
        
        raw_img = stitched.crop((0, 0, w, min(stitched_h, target_h)))
        raw_img = raw_img.resize(DEVICE_SIZE, Image.Resampling.LANCZOS)
        
        raw_img = mask_rounded(raw_img, 60)
        
        device_x = (CANVAS_SIZE[0] - DEVICE_SIZE[0]) // 2
        shadow = create_shadow(DEVICE_SIZE, 60, 40, (0,0,0,50))
        canvas.paste(shadow, (device_x - 80, DEVICE_Y - 80), shadow)
        canvas.paste(raw_img, (device_x, DEVICE_Y), raw_img)
    else:
        print(f"Warning: Screenshot not found at {SCREENSHOT_PATH}")
    
    draw_floating_card(canvas)
    
    if os.path.exists(PIGGY_BANK_PATH):
        piggy = Image.open(PIGGY_BANK_PATH)
        piggy = remove_white_bg(piggy, threshold=230)
        bbox = piggy.getbbox()
        if bbox:
            piggy = piggy.crop(bbox)
        piggy = piggy.resize((250, int(250 * piggy.height / piggy.width)), Image.Resampling.LANCZOS)
        p_x = CANVAS_SIZE[0] - piggy.width + 50
        p_y = CANVAS_SIZE[1] - piggy.height - 10
        shadow = create_shadow((piggy.width-100, piggy.height-100), 50, 30, (0,0,0,60))
        canvas.paste(shadow, (p_x+20, p_y+80), shadow)
        canvas.paste(piggy, (p_x, p_y), piggy)
    
    canvas.convert("RGB").save(OUT_PATH, "PNG", quality=95)
    print(f"Saved {OUT_PATH}")

if __name__ == "__main__":
    main()
