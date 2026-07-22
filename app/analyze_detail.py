from PIL import Image, ImageDraw
import sys

design = Image.open(r'C:\Users\74897\.openclaw\general-manager-agent\design_phone_430.png')
current = Image.open(r'C:\bamabao\app\build\vp.png')

print(f"Design: {design.size}")
print(f"Current: {current.size}")
print()

# ============================================================
# 1. TOP BAR
# ============================================================
print("="*60)
print("1. TOP BAR")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Find orange bar
    first = None
    for y in range(100):
        r,g,b = img.getpixel((215, y))
        if (r,g,b) == (255,159,64):
            first = y
            break
    if first is None:
        print("  No orange at center, check side")
        for y in range(100):
            r,g,b = img.getpixel((50, y))
            if (r,g,b) == (255,159,64):
                first = y
                break
    
    # Find end of pure orange
    last_orange = first
    for y in range(first, 200):
        r,g,b = img.getpixel((215, y))
        if sum(abs(r-255)+abs(g-159)+abs(b-64)) < 15:
            last_orange = y
        else:
            break
    print(f"  Pure orange: Y={first} to Y={last_orange} = {last_orange-first+1}px")
    
    # What is below orange (the rounded bottom area)
    for y in range(last_orange+1, last_orange+50):
        r,g,b = img.getpixel((215, y))
        if (r,g,b) != (255,159,64):
            print(f"  Below orange at Y={y}: ({r},{g},{b})")
            # scan down to find where background reappears
            for y2 in range(y, y+60):
                r2,g2,b2 = img.getpixel((215, y2))
                if r2 == 255 and g2 == 255 and b2 == 255 or (r2 > 220 and g2 > 240 and b2 > 200):
                    print(f"  Background/white at Y={y2}: ({r2},{g2},{b2})")
                    print(f"  Total bar height (orange+rounding): {y2-first}px")
                    break
            break

# ============================================================
# 2. GREETING CARD
# ============================================================
print("\n" + "="*60)
print("2. GREETING CARD")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Find first abundant white horizontal segment
    white_runs = []
    in_white = False
    ws = 0
    for y in range(50, 500):
        r,g,b = img.getpixel((100, y))
        is_white = (r > 250 and g > 250 and b > 250)
        if is_white and not in_white:
            ws = y
            in_white = True
        elif not is_white and in_white:
            if y - ws > 20:
                white_runs.append((ws, y-1))
            in_white = False
    
    for ws, we in white_runs:
        length = we - ws + 1
        if length > 70:
            print(f"  White card: Y={ws} to Y={we} = {length}px")
            # shadow below
            for y in range(we+1, we+25):
                r,g,b = img.getpixel((215, y))
                if r < 250:
                    print(f"  Shadow at Y={y}: ({r},{g},{b})")
                    break
            # text positions
            for y in range(ws, we):
                r,g,b = img.getpixel((100, y+15))
                if r < 100:
                    print(f"  Dark title text at Y={y+15}")
                    break
            for y in range(ws, we):
                r,g,b = img.getpixel((200, y))
                if r > 200 and g < 100 and b < 100:
                    print(f"  RED text at approx Y={y}")
                    break
            break

# ============================================================
# 3. DRUG CARDS (look for all white segments below greeting)
# ============================================================
print("\n" + "="*60)
print("3. DRUG CARDS")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    white_runs = []
    in_white = False
    ws_w = 0
    for y in range(200, min(img.height, 900)):
        r,g,b = img.getpixel((80, y))
        is_white = (r > 250 and g > 250 and b > 250)
        if is_white and not in_white:
            ws_w = y
            in_white = True
        elif not is_white and in_white:
            if y - ws_w > 50:
                white_runs.append((ws_w, y-1))
            in_white = False
    if in_white:
        white_runs.append((ws_w, min(img.height, 900)-1))
    
    # Filter out greeting card (first card is greeting)
    if white_runs:
        # skip first one (greeting)
        drug_cards = white_runs[1:] if len(white_runs) > 1 else []
        print(f"  Found {len(drug_cards)} cards after greeting:")
        for i, (s,e) in enumerate(drug_cards):
            print(f"    Card {i+1}: Y={s} to Y={e} = {e-s+1}px")
            # gap from previous
            if i > 0:
                prev_e = drug_cards[i-1][1]
                print(f"      Gap: {s - prev_e}px")

# ============================================================
# 4. CIRCLE INDICATORS
# ============================================================
print("\n" + "="*60)
print("4. CIRCLE INDICATORS (pixel-level)")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Left side x=34-50 should have circle indicators inside cards
    # Scan vertical center of each card
    for x_check in [42]:
        circle_found = False
        for y in range(250, min(800, img.height-1)):
            r,g,b = img.getpixel((x_check, y))
            # Check for non-white, non-background color
            if r == 255 and g == 159 and b == 64:  # orange ring pixel
                # Find circle bounds
                # Left/right bounds
                xl, xr = x_check, x_check
                while xl > 10:
                    r2,g2,b2 = img.getpixel((xl-1, y))
                    if (r2,g2,b2) != (255,159,64): break
                    xl -= 1
                while xr < 80:
                    r2,g2,b2 = img.getpixel((xr+1, y))
                    if (r2,g2,b2) != (255,159,64): break
                    xr += 1
                # Top/bottom bounds
                yt, yb = y, y
                while yt > 0:
                    r2,g2,b2 = img.getpixel((x_check, yt-1))
                    if (r2,g2,b2) != (255,159,64): break
                    yt -= 1
                while yb < img.height-1:
                    r2,g2,b2 = img.getpixel((x_check, yb+1))
                    if (r2,g2,b2) != (255,159,64): break
                    yb += 1
                
                circle_w = xr - xl + 1
                circle_h = yb - yt + 1
                print(f"  Orange ring at x={xl}-{xr}, Y={yt}-{yb} ({circle_w}x{circle_h})")
                print(f"    Inside (x={x_check}, Y={(yt+yb)//2}): {img.getpixel((x_check, (yt+yb)//2))}")
                
                # Check stroke width - look for non-orange pixels inside
                for cx in range(xl+1, xr):
                    r2,g2,b2 = img.getpixel((cx, y))
                    if (r2,g2,b2) != (255,159,64):
                        print(f"    Inside color x={cx},Y={y}: ({r2},{g2},{b2})")
                        break
                
                circle_found = True
                break
            elif r == 89 and g == 201 and b == 146:  # green fill
                xl, xr = x_check, x_check
                while xl > 10:
                    r2,g2,b2 = img.getpixel((xl-1, y))
                    if (r2,g2,b2) != (89,201,146): break
                    xl -= 1
                while xr < 80:
                    r2,g2,b2 = img.getpixel((xr+1, y))
                    if (r2,g2,b2) != (89,201,146): break
                    xr += 1
                yt, yb = y, y
                while yt > 0:
                    r2,g2,b2 = img.getpixel((x_check, yt-1))
                    if (r2,g2,b2) != (89,201,146): break
                    yt -= 1
                while yb < img.height-1:
                    r2,g2,b2 = img.getpixel((x_check, yb+1))
                    if (r2,g2,b2) != (89,201,146): break
                    yb += 1
                circle_w = xr - xl + 1
                circle_h = yb - yt + 1
                print(f"  Green fill at x={xl}-{xr}, Y={yt}-{yb} ({circle_w}x{circle_h})")
                
                # Check for white checkmark
                for cx in range(xl, xr+1):
                    for cy in range(yt, yb+1):
                        r2,g2,b2 = img.getpixel((cx, cy))
                        if (r2,g2,b2) == (255,255,255):
                            print(f"    WHITE pixel (checkmark) at x={cx},Y={cy}")
                            break
                    else:
                        continue
                    break
                
                circle_found = True
                break
        if not circle_found:
            # Try other x positions
            pass

# ============================================================
# 5. RECORD ENTRY CARD (green background)
# ============================================================
print("\n" + "="*60)
print("5. RECORD ENTRY (green card)")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    green_runs = []
    in_green = False
    gs = 0
    for y in range(50, min(700, img.height)):
        r,g,b = img.getpixel((100, y))
        is_green = (r > 210 and g > 235 and b > 200 and r < 240)
        if is_green and not in_green:
            gs = y
            in_green = True
        elif not is_green and in_green:
            if y - gs > 20:
                green_runs.append((gs, y-1))
            in_green = False
    if in_green:
        green_runs.append((gs, min(700, img.height)-1))
    
    if green_runs:
        print(f"  Green background segments:")
        for s,e in green_runs:
            print(f"    Y={s} to Y={e} = {e-s+1}px")

# ============================================================
# 6. BOTTOM BUTTONS
# ============================================================
print("\n" + "="*60)
print("6. BOTTOM BUTTONS")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    btn_segments = []
    in_btn = False
    bs = 0
    for y in range(600, img.height):
        r,g,b = img.getpixel((80, y))
        is_btn = (r == 255 and g == 159 and b == 64)
        if is_btn and not in_btn:
            bs = y
            in_btn = True
        elif not is_btn and in_btn:
            if y - bs > 10:
                btn_segments.append((bs, y-1))
            in_btn = False
    if in_btn:
        btn_segments.append((bs, img.height-1))
    
    if btn_segments:
        print(f"  Button segments at x=80:")
        for s,e in btn_segments:
            print(f"    Y={s} to Y={e} = {e-s+1}px")
            # text inside
            for y in range(s, e):
                r,g,b = img.getpixel((100, y))
                if r > 240 and g > 230:
                    print(f"    Text at Y={y}")
                    break

# ============================================================
# 7. MARGINS / SPACING summary
# ============================================================
print("\n" + "="*60)
print("7. SPACING SUMMARY")
print("="*60)

for label, img in [('Design', design), ('Current', current)]:
    print(f"\n--- {label} ---")
    # Vertical stripe at x=16 (left margin) - should be background
    # and x=414 (right margin)
    for x_check in [16, 414]:
        for y in range(0, min(200, img.height)):
            r,g,b = img.getpixel((x_check, y))
            if r > 200 and g > 220 and b > 190:
                print(f"  x={x_check}: Background-green at Y={y}: ({r},{g},{b})")
                break

# ============================================================
# 8. SIDE-BY-SIDE DIFF
# ============================================================
print("\n" + "="*60)
print("8. MAIN DIFFERENCES")
print("="*60)

# Compare key metrics
for i, (label, img) in enumerate([('Design', design), ('Current', current)]):
    h = img.height
    w = img.width
    
    # Background check
    bg_colors = {}
    for y in range(80, h, 50):
        for x in [10, w-10]:
            r,g,b = img.getpixel((x, y))
            if (r,g,b) not in [(255,255,255), (255,159,64), (89,201,146)]:
                if r > 200 and g > 220:
                    bg_colors[(r,g,b)] = bg_colors.get((r,g,b), 0) + 1
    
    if bg_colors:
        most_common = max(bg_colors, key=bg_colors.get)
        print(f"  {label}: Background ~({most_common[0]},{most_common[1]},{most_common[2]})")

PYEOF