from PIL import Image

design = Image.open(r'C:\Users\74897\.openclaw\general-manager-agent\design_phone_430.png')
current = Image.open(r'C:\bamabao\app\build\vp.png')

def is_orange(r,g,b): return r > 240 and g > 140 and g < 175 and b < 80
def is_green_fill(r,g,b): return r > 80 and r < 95 and g > 190 and g < 210 and b > 135 and b < 155
def is_bg_green(r,g,b): return r > 210 and g > 230 and b > 195

print("="*65)
print("PIXEL-LEVEL COMPARISON: DESIGN vs CURRENT")
print("="*65)

print(f"""
┌─────────────────────┬──────────┬───────────┬──────────┐
│ MEASUREMENT         │ DESIGN   │ CURRENT   │ DELTA    │
├─────────────────────┼──────────┼───────────┼──────────┤""")

# 1. Top bar
print(f"│ Top bar height     │ 105px    │ 72px      │ -33px    │")
print(f"│ Top bar shadow     │ Y=105-120│ none      │ MISSING  │")

# 2. Bottom buttons
print(f"│ Bottom btn height  │ ~64px    │ 23px      │ -41px    │")
print(f"│ Btn text v-pos     │ Y=830    │ Y=858     │ +28px    │")

# 3. Circle indicators
# Design: scan for orange/green circles
print("\n│--- CIRCLES ---")
# Get design circle sizes
for y in range(250, 900):
    r,g,b = design.getpixel((42, y))
    if is_orange(r,g,b):
        xl, xr = 42, 42
        while xl > 5:
            r2,g2,b2 = design.getpixel((xl-1, y))
            if not is_orange(r2,g2,b2): break
            xl -= 1
        while xr < 80:
            r2,g2,b2 = design.getpixel((xr+1, y))
            if not is_orange(r2,g2,b2): break
            xr += 1
        yt, yb = y, y
        while yt > 0:
            r2,g2,b2 = design.getpixel((42, yt-1))
            if not is_orange(r2,g2,b2): break
            yt -= 1
        while yb < design.height-1:
            r2,g2,b2 = design.getpixel((42, yb+1))
            if not is_orange(r2,g2,b2): break
            yb += 1
        print(f"│ Orange ring        │ {xr-xl+1}x{yb-yt+1}px │ 8x4px    │ too thin!│")
        # Check stroke
        break

for y in range(250, 900):
    r,g,b = design.getpixel((42, y))
    if is_green_fill(r,g,b):
        xl, xr = 42, 42
        while xl > 5:
            r2,g2,b2 = design.getpixel((xl-1, y))
            if not is_green_fill(r2,g2,b2): break
            xl -= 1
        while xr < 80:
            r2,g2,b2 = design.getpixel((xr+1, y))
            if not is_green_fill(r2,g2,b2): break
            xr += 1
        yt, yb = y, y
        while yt > 0:
            r2,g2,b2 = design.getpixel((42, yt-1))
            if not is_green_fill(r2,g2,b2): break
            yt -= 1
        while yb < design.height-1:
            r2,g2,b2 = design.getpixel((42, yb+1))
            if not is_green_fill(r2,g2,b2): break
            yb += 1
        print(f"│ Green fill         │ {xr-xl+1}x{yb-yt+1}px │ 24x22px │ small!  │")
        break

# 4. Card borders
print("│ Card corner radius  │ >12px    │ 16px     │ ok       │")
print(f"│ Card height         │ ~96px    │ 96px     │ ok       │")

# 5. Shadow checks
print(f"│ Card shadow         │ YES      │ weak     │ weak     │")
print(f"│ Button 3D shadow    │ YES      │ none     │ MISSING  │")

print("└─────────────────────┴──────────┴───────────┴──────────┘")
print()

# Design specific: Measure bottom button precisely
print("="*65)
print("DESIGN BOTTOM BUTTON DEEP DIVE")
print("="*65)
btn_regions = []
in_btn = False
bs = 0
for y in range(780, 900):
    r,g,b = design.getpixel((80, y))
    if is_orange(r,g,b):
        if not in_btn:
            bs = y
            in_btn = True
    else:
        if in_btn and y - bs > 20:
            btn_regions.append((bs, y-1))
        in_btn = False

print(f"  Button 1: Y={btn_regions[0][0]} to Y={btn_regions[0][1]} ({btn_regions[0][1]-btn_regions[0][0]+1}px)")
print(f"  Button text at Y=830")
# Shadow below button
for y in range(btn_regions[0][1]+1, btn_regions[0][1]+20):
    r,g,b = design.getpixel((80, y))
    print(f"  Shadow at Y={y}: ({r},{g},{b})")
    break

# Button edge color
print(f"  Button edge x=79,Y={btn_regions[0][0]+20}: {design.getpixel((79, btn_regions[0][0]+20))}")

# Between buttons - gap
gap = btn_regions[1][0] - btn_regions[0][1]
print(f"  Gap between buttons: {gap}px")

# Another button at x=350
print()
print("  Second button (x=350):")
in_btn2 = False
for y in range(780, 900):
    r,g,b = design.getpixel((350, y))
    if is_orange(r,g,b):
        if not in_btn2:
            print(f"    Starts at Y={y}")
            in_btn2 = True
    else:
        if in_btn2 and y-bs > 10:
            print(f"    Ends at Y={y-1} ({y-bs}px)")
            break

print()
print("="*65)
print("CURRENT BOTTOM BUTTON DEEP DIVE")
print("="*65)
in_btn = False
for y in range(800, 932):
    r,g,b = current.getpixel((80, y))
    if r == 255 and g == 159 and b == 64:
        if not in_btn:
            print(f"  Starts at Y={y}")
            in_btn = True
    else:
        if in_btn:
            print(f"  Ends at Y={y-1} ({y-bs}px)")
            break

# Any shadow below orange?
for y in range(856, 880):
    r,g,b = current.getpixel((80, y))
    print(f"  Y={y}: ({r},{g},{b})")

print()
print("="*65)
print("DESIGN TOP BAR ROUNDED CORNERS")
print("="*65)

# Check rounded corners at the bottom of top bar
for x in [20, 40, 100, 200, 300, 400, 410]:
    for y in range(100, 150):
        r,g,b = design.getpixel((x, y))
        if r < 250:
            print(f"  x={x}: non-white at Y={y} ({r},{g},{b})")
            break

# Card shadow intensity check
print()
print("="*65)
print("SHADOW INTENSITY (design)")
print("="*65)
# Between top bar bottom and first card
for y in range(120, 140):
    r,g,b = design.getpixel((215, y))
    print(f"  Y={y}: ({r},{g},{b})")
