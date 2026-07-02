from PIL import Image
import os

logo_path = r"C:\Users\74897\Desktop\爸妈宝\爸妈宝logo\爸妈宝logo.jpg"
mipmap_base = r"C:\bamabao\app\android\app\src\main\res"

sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

img = Image.open(logo_path)
print(f"Original: {img.size}, mode={img.mode}")

# Also generate a round/non-round version - keep as square (Android handles this)
for folder, size in sizes.items():
    dest = os.path.join(mipmap_base, folder, "ic_launcher.png")
    resized = img.resize((size, size), Image.LANCZOS)
    
    if resized.mode in ('RGBA', 'P'):
        resized = resized.convert('RGBA')
        bg = Image.new('RGBA', resized.size, (255, 255, 255, 255))
        bg.paste(resized, (0, 0), resized)
        resized = bg.convert('RGB')
    elif resized.mode != 'RGB':
        resized = resized.convert('RGB')
    
    resized.save(dest, "PNG")
    print(f"  {folder} -> {size}x{size} ✅")

print("\n✅ 所有图标生成完毕！")
