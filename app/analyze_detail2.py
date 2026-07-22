from PIL import Image

design = Image.open(r'C:\Users\74897\.openclaw\general-manager-agent\design_phone_430.png')
current = Image.open(r'C:\bamabao\app\build\vp.png')

print(f"Design: {design.size}")
print(f"Current: {current.size}")
print()

def is_orange(r,g,b):
    """Tolerant orange test - matches design's orange range"""
    return r > 240 and g > 140 and g < 175 and b < 80

def is_white(r,g,b):
    return r > 248 and g > 248 and b > 248

def is_green_fill(r,g,b):
    return r > 80 and r < 95 and g > 190 and g < 210 and b > 135 and b < 155

def is_bg_green(r,g,b):
    return r > 220 and g > 235 and b > 200

# ============================================================
# 1. TOP BAR
# ============================================================
print("="*60)
print("1. TOP BAR")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Find top orange pixels (with tolerance)
    orange_rows = []
    for y in range(200):
        r,g,b = img.getpixel((215, y))
        if is_orange(r,g,b):
            orange_rows.append(y)
    
    if orange_rows:
        print(f"  Orange bar rows: Y={min(orange_rows)} to Y={max(orange_rows)}")
        print(f"  Height: {max(orange_rows)-min(orange_rows)+1}px")
        
        # Rounded bottom - scan for gradient below orange
        last_orange = max(orange_rows)
        for y in range(last_orange+1, last_orange+60):
            r,g,b = img.getpixel((215, y))
            if is_white(r,g,b) or is_bg_green(r,g,b) or (r==0 and g==0 and b==0):
                # end of bar influence
                pass
            if not is_orange(r,g,b) and not (r>250 and g>240 and b>220):
                # gradient/transition
                pass
            if is_white(r,g,b):
                print(f"  White starts at Y={y}")
                break
            elif is_bg_green(r,g,b):
                print(f"  Background green starts at Y={y}: ({r},{g},{b})")
                break
        
        # Bar corners - left and right edge
        # Check at Y = min(orange_rows) + 5
        cy = min(orange_rows) + 5
        left_corner = None
        for x in range(430):
            r,g,b = img.getpixel((x, cy))
            if is_orange(r,g,b):
                left_corner = x
                break
        right_corner = None
        for x in range(429, -1, -1):
            r,g,b = img.getpixel((x, cy))
            if is_orange(r,g,b):
                right_corner = x
                break
        if left_corner is not None:
            print(f"  Bar horizontal: x={left_corner} to x={right_corner}")
            print(f"  Bar left margin: {left_corner}px, right margin: {429-right_corner}px")

# ============================================================
# 2. GREETING CARD
# ============================================================
print("\n" + "="*60)
print("2. GREETING CARD & ALL CARDS")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Find all white segments (use x=80, left of center, to avoid close icons)
    white_segs = []
    in_w = False
    ws = 0
    for y in range(0, img.height):
        r,g,b = img.getpixel((80, y))
        is_w = is_white(r,g,b)
        if is_w and not in_w:
            ws = y
            in_w = True
        elif not is_w and in_w:
            if y - ws > 30:
                white_segs.append((ws, y-1))
            in_w = False
    if in_w:
        if img.height - ws > 30:
            white_segs.append((ws, img.height-1))
    
    # First card is top area later
    # Actually, let me just print all white segments
    print(f"  White segments (filtered, >30px height):")
    for i, (s,e) in enumerate(white_segs):
        print(f"    #{i}: Y={s} to Y={e} = {e-s+1}px")
    
    # Card corner radius test - sample near corners of first drug card
    if len(white_segs) >= 3:
        card_s, card_e = white_segs[1]  # first significant card after greeting area
        print(f"\n  First white block corner - at x=16, Y={card_s-2}: {img.getpixel((20, card_s-2))}")
        print(f"  At x=30, Y={card_s-2}: {img.getpixel((30, card_s-2))}")

# ============================================================
# 3. CIRCLES
# ============================================================
print("\n" + "="*60)
print("3. CIRCLES")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    
    # Find first green filled circle
    for y in range(200, 800):
        r,g,b = img.getpixel((42, y))
        if is_green_fill(r,g,b):
            # Find bounds
            xl, xr = 42, 42
            while xl > 0:
                r2,g2,b2 = img.getpixel((xl-1, y))
                if not is_green_fill(r2,g2,b2): break
                xl -= 1
            while xr < 80:
                r2,g2,b2 = img.getpixel((xr+1, y))
                if not is_green_fill(r2,g2,b2): break
                xr += 1
            yt, yb = y, y
            while yt > 0:
                r2,g2,b2 = img.getpixel((42, yt-1))
                if not is_green_fill(r2,g2,b2): break
                yt -= 1
            while yb < img.height-1:
                r2,g2,b2 = img.getpixel((42, yb+1))
                if not is_green_fill(r2,g2,b2): break
                yb += 1
            circle_d = max(xr-xl+1, yb-yt+1)
            print(f"  Green fill: x={xl}-{xr}, Y={yt}-{yb}, diameter={circle_d}px")
            
            # Check for white checkmark
            for cx in range(xl, xr+1, 2):
                for cy in range(yt, yb+1, 2):
                    r2,g2,b2 = img.getpixel((cx, cy))
                    if (r2,g2,b2) == (255,255,255):
                        print(f"    White pixel at x={cx}, Y={cy}")
                        break
                else:
                    continue
                break
            break
    
    # Find orange ring
    for y in range(200, 800):
        r,g,b = img.getpixel((42, y))
        if is_orange(r,g,b):
            # Check if it's a ring (has non-orange inside)
            xl, xr = 42, 42
            while xl > 0:
                r2,g2,b2 = img.getpixel((xl-1, y))
                if not is_orange(r2,g2,b2): break
                xl -= 1
            while xr < 80:
                r2,g2,b2 = img.getpixel((xr+1, y))
                if not is_orange(r2,g2,b2): break
                xr += 1
            yt, yb = y, y
            while yt > 0:
                r2,g2,b2 = img.getpixel((42, yt-1))
                if not is_orange(r2,g2,b2): break
                yt -= 1
            while yb < img.height-1:
                r2,g2,b2 = img.getpixel((42, yb+1))
                if not is_orange(r2,g2,b2): break
                yb += 1
            
            # Check inside
            mid_x = (xl + xr) // 2
            mid_y = (yt + yb) // 2
            inner = img.getpixel((mid_x, mid_y))
            stroke = xr - xl + 1
            print(f"  Orange ring: x={xl}-{xr}, Y={yt}-{yb} (stroke={stroke}px)")
            print(f"    Inner center: {inner}")
            
            # Get the ring stroke width (thickness)
            # At any point on the ring, measure horizontal thickness
            ring_thickness = None
            for sc in range(yt, yb):
                for cx in range(xl, xr):
                    r2,g2,b2 = img.getpixel((cx, sc))
                    if is_orange(r2,g2,b2):
                        # measure horizontal run
                        s = cx
                        while s < xr:
                            r3,g3,b3 = img.getpixel((s+1, sc))
                            if not is_orange(r3,g3,b3): break
                            s += 1
                        run = s - cx + 1
                        if ring_thickness is None or run < ring_thickness:
                            ring_thickness = run
                        break
            if ring_thickness:
                print(f"    Ring stroke thickness: ~{ring_thickness}px")
            
            break

# ============================================================
# 4. BOTTOM BUTTONS
# ============================================================
print("\n" + "="*60)
print("4. BOTTOM BUTTONS")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Find orange at bottom
    for x_check in [80, 350]:
        for y in range(600, img.height):
            r,g,b = img.getpixel((x_check, y))
            if is_orange(r,g,b):
                btn_top = y
                # Find bottom
                for y2 in range(btn_top, min(img.height, btn_top+100)):
                    r2,g2,b2 = img.getpixel((x_check, y2))
                    if not is_orange(r2,g2,b2):
                        print(f"  Button at x={x_check}: Y={btn_top}-{y2-1} = {y2-btn_top}px")
                        # Text
                        for y3 in range(btn_top, y2):
                            r3,g3,b3 = img.getpixel((x_check+20, y3))
                            if r3 > 240 and g3 > 230:
                                print(f"    Text at Y={y3}")
                                break
                        break
                break

# ============================================================
# 5. SHADOWS
# ============================================================
print("\n" + "="*60)
print("5. SHADOWS")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    
    # Card shadow - look for near-white but not white pixels below white segments
    white_segs_shadow = []
    in_w = False
    ws = 0
    for y in range(0, min(800, img.height)):
        r,g,b = img.getpixel((160, y))
        is_w = is_white(r,g,b)
        if is_w and not in_w:
            ws = y
            in_w = True
        elif not is_w and in_w:
            if y - ws > 30:
                white_segs_shadow.append((ws, y-1))
            in_w = False
    
    for s,e in white_segs_shadow:
        if e > 250 and e < 750:  # card area
            # Check pixels just below
            for y in range(e+1, min(e+15, img.height)):
                r,g,b = img.getpixel((160, y))
                if not is_white(r,g,b) and r > 200:
                    print(f"  Shadow below card at Y={e}: Y={y} -> ({r},{g},{b})")
                    break

# ============================================================
# 6. ARROW ICONS
# ============================================================
print("\n" + "="*60)
print("6. ARROW ICONS & TEXT SIZE")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    
    # Look for right-pointing arrows (gray > or >> at right side of cards)
    for x_check in [360, 370, 380, 390, 400]:
        for y in range(300, 600):
            r,g,b = img.getpixel((x_check, y))
            if r == 158 and g == 158 and b == 158:
                print(f"  Gray arrow pixel at x={x_check}, Y={y}: ({r},{g},{b})")
                break
    
    # Text in drug cards - find "1粒" or "1片" or dosage info
    print(f"  Drug name text sample x=110,Y=404: {img.getpixel((110, 404))}")
    print(f"  Dosage text sample x=110,Y=430: {img.getpixel((110, 430))}")
    
    # Red text
    for y in range(200, 400):
        r,g,b = img.getpixel((200, y))
        if r > 200 and g < 100 and b < 100:
            print(f"  RED text at x=200, Y={y}: ({r},{g},{b})")
            break
    
    # Title text
    for y in range(300, 400):
        r,g,b = img.getpixel((160, y))
        if r < 80 and g < 80 and b < 80:
            print(f"  Dark text '今日用药' at x=160, Y={y}: ({r},{g},{b})")
            break

# ============================================================
# 7. BOTTOM SPACING
# ============================================================
print("\n" + "="*60)
print("7. BOTTOM SPACING & NAV BAR")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    
    # Last content pixel
    for y in range(img.height-1, 0, -1):
        r,g,b = img.getpixel((215, y))
        if r < 255 or g < 255 or b < 255:
            print(f"  Last non-white pixel: Y={y}: ({r},{g},{b})")
            break
    
    # Check bottom area
    if img.height > 900:
        print(f"  Bottom 32px (Y={img.height-32}-{img.height-1}):")
        for y in range(img.height-32, img.height, 4):
            r,g,b = img.getpixel((215, y))
            print(f"    Y={y}: ({r},{g},{b})")

print()
print("="*60)
print("DIFFERENCES SUMMARY")
print("="*60)

# Compare key metrics side by side
