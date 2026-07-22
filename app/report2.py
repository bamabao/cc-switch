from PIL import Image

design = Image.open(r'C:\Users\74897\.openclaw\general-manager-agent\design_phone_430.png')
current = Image.open(r'C:\bamabao\app\build\vp.png')

def is_orange(r,g,b): return r > 240 and g > 140 and g < 175 and b < 80
def is_green_fill(r,g,b): return r > 80 and r < 100 and g > 185 and g < 215 and b > 130 and b < 160

# DESIGN: measure green circle at x=42
print("=== DESIGN GREEN CIRCLE ===")
for y in range(570, 620):
    r,g,b = design.getpixel((42, y))
    if is_green_fill(r,g,b):
        xl, xr = 42, 42
        while xl > 10:
            r2,g2,b2 = design.getpixel((xl-1, y))
            if not is_green_fill(r2,g2,b2): break
            xl -= 1
        while xr < 80:
            r2,g2,b2 = design.getpixel((xr+1, y))
            if not is_green_fill(r2,g2,b2): break
            xr += 1
        yt, yb = y, y
        while yt > y-30:
            r2,g2,b2 = design.getpixel((42, yt-1))
            if not is_green_fill(r2,g2,b2): break
            yt -= 1
        while yb < y+30:
            r2,g2,b2 = design.getpixel((42, yb+1))
            if not is_green_fill(r2,g2,b2): break
            yb += 1
        print(f"  Green circle: x={xl}-{xr}, Y={yt}-{yb} = {xr-xl+1}x{yb-yt+1}")
        # Inside color (checkmark?)
        mid_x, mid_y = (xl+xr)//2, (yt+yb)//2
        print(f"  Center pixel: {design.getpixel((mid_x, mid_y))}")
        # Vertical center line pixels
        mid_x = (xl+xr)//2
        for cy in range(yt, yb+1):
            print(f"    Y={cy}: {design.getpixel((mid_x, cy))}")
        break

print()
print("=== DESIGN ORANGE RING ===")
for y in range(400, 440):
    r,g,b = design.getpixel((42, y))
    if is_orange(r,g,b):
        xl, xr = 42, 42
        while xl > 10:
            r2,g2,b2 = design.getpixel((xl-1, y))
            if not is_orange(r2,g2,b2): break
            xl -= 1
        while xr < 80:
            r2,g2,b2 = design.getpixel((xr+1, y))
            if not is_orange(r2,g2,b2): break
            xr += 1
        yt, yb = y, y
        while yt > y-30:
            r2,g2,b2 = design.getpixel((42, yt-1))
            if not is_orange(r2,g2,b2): break
            yt -= 1
        while yb < y+30:
            r2,g2,b2 = design.getpixel((42, yb+1))
            if not is_orange(r2,g2,b2): break
            yb += 1
        print(f"  Orange ring: x={xl}-{xr}, Y={yt}-{yb} = {xr-xl+1}x{yb-yt+1}")
        # Check interior
        mid_x, mid_y = (xl+xr)//2, (yt+yb)//2
        print(f"  Center pixel: {design.getpixel((mid_x, mid_y))}")
        # Scan a horizontal line through middle
        for cx in range(xl-1, xr+2):
            print(f"    x={cx}: {design.getpixel((cx, mid_y))}")
        break

print()
print("=== DESIGN RECORD ENTRY CARD ===")
# Find the green card between greeting and drugs
for y in range(200, 300):
    r,g,b = design.getpixel((60, y))
    if r > 210 and g > 230 and b > 195 and r < 240:
        yt = y
        for y2 in range(yt+30, 400):
            r2,g2,b2 = design.getpixel((60, y2))
            if r2 > 245 and g2 > 245 and b2 > 240:
                print(f"  Green card: Y={yt} to Y={y2} = {y2-yt}px")
                # Arrow?
                for x in range(360, 410):
                    for cy in range(yt, y2):
                        px = design.getpixel((x, cy))
                        if px == (158, 158, 158):
                            print(f"  Arrow at x={x}, Y={cy}")
                            break
                    else:
                        continue
                    break
                # Text
                for cy in range(yt, y2):
                    r3,g3,b3 = design.getpixel((80, cy))
                    if r3 < 80 and g3 < 90:
                        print(f"  Dark text at Y={cy}: ({r3},{g3},{b3})")
                        break
                break
        break

print()
print("=== DESIGN RIGHT ARROW ICONS ===")
for y in range(250, 800):
    r,g,b = design.getpixel((400, y))
    if (r,g,b) == (158,158,158):
        print(f"  Gray pixel at x=400, Y={y}")
        # Check if it's a ">" arrow shape - scan surrounding
        for dx in [-3,-2,-1,0,1,2,3]:
            print(f"    x=400+{dx}: {design.getpixel((400+dx, y))}")
        break

print()
print("=== DESIGN SUBTITLE TEXT ===")
# "今日用药  共 4 种药品" area
for y in range(350, 400):
    r,g,b = design.getpixel((200, y))
    if r < 60 and g < 60 and b < 60:
        print(f"  Dark text at x=200,Y={y}: ({r},{g},{b})")
        # Also check above
        for y2 in range(y-5, y):
            print(f"    Y={y2}: {design.getpixel((200, y2))}")
        break

# Also try x=360 for the right aligned "共 4 种药品"
for y in range(350, 400):
    r,g,b = design.getpixel((360, y))
    if r < 100 and g < 100 and b < 100:
        print(f"  Gray text at x=360,Y={y}: ({r},{g},{b})")
        break

print()
print("=== CURRENT STATE CIRCLES (for comparison) ===")
# Already know: green=24x22, orange=8x4 (too small)
print("  Green fill: 24x22 (measured earlier)")
print("  Orange ring: 8x4 (stroke ~2px)")
