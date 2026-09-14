from PIL import Image

def create_padded_icon(input_path, output_path, size=1024):
    img = Image.open(input_path).convert("RGBA")
    
    # The logo has a green background and a white piggy bank.
    # Let's extract the white parts. We assume anything close to white is foreground, rest is transparent.
    data = img.getdata()
    new_data = []
    for item in data:
        # If the pixel is mostly white
        if item[0] > 200 and item[1] > 200 and item[2] > 200:
            new_data.append((255, 255, 255, 255))
        else:
            new_data.append((255, 255, 255, 0))
    img.putdata(new_data)
    
    # Now we need to scale the extracted logo to fit safely in a 1024x1024 box.
    # Adaptive icons usually recommend the main subject fits within a 66% safe zone.
    safe_size = int(size * 0.60)
    
    # Calculate aspect ratio
    aspect = img.width / img.height
    if aspect > 1:
        new_w = safe_size
        new_h = int(safe_size / aspect)
    else:
        new_h = safe_size
        new_w = int(safe_size * aspect)
        
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Create the transparent 1024x1024 canvas
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    
    # Paste the logo in the center
    offset_x = (size - new_w) // 2
    offset_y = (size - new_h) // 2
    canvas.paste(img, (offset_x, offset_y), img)
    
    canvas.save(output_path)
    
    # Create a non-transparent version for iOS
    ios_canvas = Image.new("RGBA", (size, size), (46, 204, 113, 255))
    ios_canvas.paste(img, (offset_x, offset_y), img)
    ios_canvas.save(output_path.replace('_padded_', '_ios_'))
    print("Icons generated!")

create_padded_icon('/Users/manikarthik/.gemini/antigravity-ide/brain/910c8a35-668b-4b74-a687-a3635b71674c/.user_uploaded/media_1787517533143.png', 'assets/app_icon/coinly_android_icon_padded_1024.png')
