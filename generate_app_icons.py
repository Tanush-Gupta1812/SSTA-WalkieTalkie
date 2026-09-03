import os
from PIL import Image

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

src_path = r'stitch_walkie_push_to_talk_app\walkie_app_icon\icon_cropped.png'
base_res_dir = r'frontend\walkie_talkie\android\app\src\main\res'

src_img = Image.open(src_path)

for folder, size in sizes.items():
    folder_path = os.path.join(base_res_dir, folder)
    os.makedirs(folder_path, exist_ok=True)
    out_file = os.path.join(folder_path, 'ic_launcher.png')
    
    resized = src_img.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(out_file, 'PNG')
    print(f"Generated {out_file} ({size}x{size})")

print("All icons successfully generated!")
