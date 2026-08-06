"""爸妈宝穿戴设备产品图生成 - K1系列（手表+戒指）"""
from PIL import Image, ImageDraw, ImageFilter
import os, math

OUT = r"C:\bamabao\web\mall"
os.makedirs(OUT, exist_ok=True)
SIZE = 600

def lerp(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def rounded_bg(img, radius=40):
    mask = Image.new('L', img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, img.size[0]-1, img.size[1]-1], radius=radius, fill=255)
    img.putalpha(mask)
    return img

# ─── 爸妈宝Watch K1 ───
def make_watch():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0))
    draw = ImageDraw.Draw(img)

    # 背景：科技蓝渐变
    for y in range(SIZE):
        draw.line([(0,y),(SIZE,y)], fill=lerp((13,71,161),(66,165,245), y/SIZE) + (255,))

    # 表带（上下）
    strap = (30, 30, 34)
    draw.rounded_rectangle([215, 40, 385, 150], radius=25, fill=strap)   # 上带
    draw.rounded_rectangle([215, 450, 385, 560], radius=25, fill=strap)  # 下带
    # 表带孔
    for y in range(70, 150, 22):
        draw.ellipse([285, y, 315, y+30], fill=(20,20,22))

    # 表体
    draw.rounded_rectangle([180, 140, 420, 460], radius=45, fill=(230,233,238))
    # 表框
    draw.rounded_rectangle([190, 150, 410, 450], radius=40, fill=(24,28,34))
    # 屏幕
    draw.rounded_rectangle([210, 170, 390, 430], radius=30, fill=(8,12,20))

    # 屏幕内容：时间 + 心率
    draw.ellipse([250, 220, 350, 320], outline=(255,255,255,80), width=2)
    # 心率曲线
    pts = []
    for i in range(60):
        x = 220 + i * 2.7
        y = 300 + math.sin(i/6) * 18 + (8 if 25 < i < 35 else 0)
        pts.append((x, y))
    draw.line(pts, fill=(80,220,140), width=3)
    draw.ellipse([270, 340, 330, 400], outline=(255,255,255,60), width=1)
    draw.text((280, 355), "24", fill=(255,255,255))

    # 品牌名
    draw.text((255, 405), "BAMAOBAO", fill=(255,255,255,120))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img = rounded_bg(img, 50)
    img.save(os.path.join(OUT, "watch_k1.png"))
    img.resize((300,300), Image.LANCZOS).save(os.path.join(OUT, "watch_k1_small.png"))
    print("✅ 爸妈宝Watch K1")

# ─── 爸妈宝Ring K1 ───
def make_ring():
    img = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0))
    draw = ImageDraw.Draw(img)

    # 背景：深紫渐变
    for y in range(SIZE):
        draw.line([(0,y),(SIZE,y)], fill=lerp((26,35,126),(63,81,181), y/SIZE) + (255,))

    # 戒指主体（钛合金色环）
    draw.ellipse([90, 120, 510, 540], fill=(196,199,208))
    draw.ellipse([150, 180, 450, 480], fill=(140,143,152))
    # 内圈
    draw.ellipse([190, 220, 410, 440], fill=(26,28,34))

    # 内圈传感器（心率环+光）
    cx, cy = 300, 330
    draw.ellipse([cx-80, cy-80, cx+80, cy+80], outline=(90,220,150), width=3)
    for i in range(8):
        ang = i * math.pi/4
        x1 = cx + 40*math.cos(ang); y1 = cy + 40*math.sin(ang)
        x2 = cx + 62*math.cos(ang); y2 = cy + 62*math.sin(ang)
        draw.line([(x1,y1),(x2,y2)], fill=(120,230,170), width=3)
    draw.ellipse([cx-12, cy-12, cx+12, cy+12], fill=(90,220,150))

    # 品牌字（外圈上方）
    draw.text((245, 115), "BAMAOBAO", fill=(255,255,255,150))
    # 下方小字 K1
    draw.text((280, 545), "K1 RING", fill=(255,255,255,120))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img = rounded_bg(img, 50)
    img.save(os.path.join(OUT, "ring_k1.png"))
    img.resize((300,300), Image.LANCZOS).save(os.path.join(OUT, "ring_k1_small.png"))
    print("✅ 爸妈宝Ring K1")

if __name__ == '__main__':
    make_watch()
    make_ring()
    print(f"📁 产品图目录: {OUT}")
