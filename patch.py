from PIL import Image, ImageDraw, ImageFont

def get_font(size):
    try:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size)
    except:
        return ImageFont.load_default()

img = Image.open('raw_screenshots/long_screen.png').convert("RGBA")
draw = ImageDraw.Draw(img)

# Let's draw a grid to help find the coordinates
for y in range(600, 800, 20):
    draw.line([(0, y), (500, y)], fill=(255, 0, 0, 255), width=2)
    draw.text((10, y), str(y), fill=(255, 0, 0, 255))
    
for x in range(100, 400, 50):
    draw.line([(x, 600), (x, 800)], fill=(0, 255, 0, 255), width=2)
    draw.text((x, 600), str(x), fill=(0, 255, 0, 255))

img.crop((0, 600, 500, 800)).save('/Users/manikarthik/.gemini/antigravity-ide/brain/226fd434-5e41-4bc1-8c53-27e04cc4ec04/scratch/test.png')
print("Done")
