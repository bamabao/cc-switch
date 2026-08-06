"""生成K1系列产品溯源二维码"""
import os, sys
sys.path.insert(0, r"C:\bamabao\backend")

import qrcode
from PIL import Image, ImageDraw

QR_DIR = r"C:\bamabao\web\mall\qr"
os.makedirs(QR_DIR, exist_ok=True)

# 产品：代码 → (SKU, 溯源码, 名称)
products = [
    ("BMBW-K1-BLACK", "TRC-WATCH-K1-001", "爸妈宝Watch K1 智能手表"),
    ("BMBR-K1-TITANIUM", "TRC-RING-K1-001", "爸妈宝Ring K1 智能指环"),
]

BASE_URL = "http://192.168.10.3:8888/trace.html?code="

for sku, trace_code, name in products:
    # 二维码内容 = 追溯页面URL（扫码直接打开）
    url = f"{BASE_URL}{trace_code}"
    qr = qrcode.QRCode(version=2, box_size=10, border=2)
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0d47a1", back_color="white").convert("RGB")

    # 下方加产品名+溯源码
    canvas = Image.new("RGB", (img.width, img.height + 50), "white")
    canvas.paste(img, (0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.text((10, img.height + 8), f"{name} | {trace_code}", fill="black")
    draw.text((10, img.height + 28), f"扫描查真伪·全链路追溯", fill="gray")

    path = os.path.join(QR_DIR, f"{sku}_qr.png")
    canvas.save(path)
    print(f"✅ {name} 二维码: {path}")
    print(f"   内容: {url}")

print(f"\n📁 二维码目录: {QR_DIR}")
