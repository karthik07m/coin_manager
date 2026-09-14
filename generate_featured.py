from PIL import Image

def create_featured_graphic():
    # 1. Create a 1024x500 green background canvas
    canvas = Image.new("RGBA", (1024, 500), (46, 204, 113, 255))
    
    # 2. Load the transparent white logo we created earlier
    logo = Image.open('assets/app_icon/coinly_android_icon_padded_1024.png').convert("RGBA")
    
    # 3. The logo canvas is 1024x1024. The actual piggy bank inside it is roughly 60% (600x600).
    # We want the piggy bank to be around 350px tall to fit nicely in the 500px height.
    # So we'll scale the 1024x1024 logo image down to 500x500, which makes the piggy bank ~300px.
    logo = logo.resize((500, 500), Image.Resampling.LANCZOS)
    
    # 4. Paste the logo into the exact center of the 1024x500 canvas
    offset_x = (1024 - 500) // 2
    offset_y = (500 - 500) // 2
    
    canvas.paste(logo, (offset_x, offset_y), logo)
    
    # 5. Save the final graphic
    canvas.save('play_store_featured_graphic.png')
    print("Featured graphic generated!")

create_featured_graphic()
