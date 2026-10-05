"""Draw the pass/product icons (512x512 PNG) with PIL. Original vector-style art,
bold colours, thick dark outlines, no text except short multipliers.
Output: assets/icons/<key>.png"""
import math, pathlib
from PIL import Image, ImageDraw, ImageFont

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons"
OUT.mkdir(parents=True, exist_ok=True)
S = 512
DARK = (45, 22, 8)

def font(size):
    for f in ["C:/Windows/Fonts/ariblk.ttf", "C:/Windows/Fonts/arialbd.ttf"]:
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()

def bg(c1, c2):
    im = Image.new("RGB", (S, S), c1)
    d = ImageDraw.Draw(im)
    for r in range(360, 0, -6):
        t = r / 360
        col = tuple(int(c2[i] * (1 - t) + c1[i] * t) for i in range(3))
        d.ellipse([S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r], fill=col)
    return im

def maple(cx, cy, r, rot=0.0):
    # 5-lobed maple leaf outline as a polygon
    pts = []
    lobes = [(-90, 1.0), (-30, 0.85), (30, 0.85), (-150, 0.85), (150, 0.85)]
    n = 200
    for k in range(n):
        a = -math.pi / 2 + 2 * math.pi * k / n
        deg = math.degrees(a) % 360
        rr = 0.45
        for lob, size in lobes:
            diff = abs(((deg - (lob % 360)) + 180) % 360 - 180)
            rr = max(rr, size * math.exp(-(diff / 18) ** 2) + 0.42 * math.exp(-(diff / 40) ** 2))
        # little teeth
        rr *= 1 + 0.06 * math.sin(k * 2 * math.pi / n * 25)
        if 80 < deg < 100:
            rr = 0.25  # notch for the stem
        pts.append((cx + r * rr * math.cos(a + rot), cy + r * rr * math.sin(a + rot)))
    return pts

def draw_leaf(d, cx, cy, r, color, rot=0.0):
    pts = maple(cx, cy, r, rot)
    d.polygon(pts, fill=color, outline=DARK, width=max(4, int(r / 11)))
    # veins + stem
    for ang in (-90, -30, 30, -150, 150):
        a = math.radians(ang) + rot
        d.line([(cx, cy), (cx + r * 0.7 * math.cos(a), cy + r * 0.7 * math.sin(a))], fill=DARK, width=max(2, int(r / 22)))
    a = math.radians(90) + rot
    d.line([(cx, cy), (cx + r * 0.8 * math.cos(a), cy + r * 0.8 * math.sin(a))], fill=DARK, width=max(4, int(r / 12)))

def acorn(d, cx, cy, r):
    d.ellipse([cx - r * 0.75, cy - r * 0.35, cx + r * 0.75, cy + r * 1.15], fill=(205, 125, 55), outline=DARK, width=12)
    d.chord([cx - r, cy - r * 0.75, cx + r, cy + r * 0.45], 180, 360, fill=(120, 75, 40), outline=DARK, width=12)
    d.rectangle([cx - r * 1.0, cy - r * 0.18, cx + r * 1.0, cy - r * 0.12], fill=(120, 75, 40))
    d.line([(cx, cy - r * 0.75), (cx + r * 0.15, cy - r * 1.05)], fill=DARK, width=14)

def text(d, xy, s, size, fill=(255, 255, 255)):
    f = font(size)
    d.text(xy, s, font=f, fill=fill, stroke_width=max(6, size // 10), stroke_fill=DARK, anchor="mm")

def bag(d, cx, cy, r, color=(205, 165, 110)):
    d.polygon([(cx - r, cy - r * 0.5), (cx + r, cy - r * 0.5), (cx + r * 0.85, cy + r * 1.1), (cx - r * 0.85, cy + r * 1.1)], fill=color, outline=DARK, width=14)
    d.polygon([(cx - r, cy - r * 0.5), (cx - r * 0.7, cy - r * 0.9), (cx + r * 0.7, cy - r * 0.9), (cx + r, cy - r * 0.5)], fill=(225, 190, 140), outline=DARK, width=12)

def rake(d, cx, cy, r, color=(200, 210, 225)):
    d.line([(cx - r * 0.9, cy + r * 0.9), (cx + r * 0.5, cy - r * 0.5)], fill=DARK, width=34)
    d.line([(cx - r * 0.9, cy + r * 0.9), (cx + r * 0.5, cy - r * 0.5)], fill=(170, 115, 65), width=20)
    hx, hy = cx + r * 0.55, cy - r * 0.55
    d.polygon([(hx - r * 0.65, hy - r * 0.05), (hx + r * 0.05, hy - r * 0.75), (hx + r * 0.2, hy - r * 0.6), (hx - r * 0.5, hy + r * 0.1)], fill=color, outline=DARK, width=10)
    for k in range(5):
        t = k / 4
        px, py = hx - r * 0.6 + t * r * 0.7, hy - r * 0.02 - t * r * 0.7
        d.line([(px, py), (px + r * 0.28, py + r * 0.28)], fill=DARK, width=16)
        d.line([(px, py), (px + r * 0.26, py + r * 0.26)], fill=color, width=8)

def save(im, key):
    im.save(OUT / f"{key}.png")
    print("wrote", key)

ORANGE, RED, YELLOW = (255, 130, 30), (235, 60, 45), (255, 200, 40)

# 2x Leaves
im = bg((255, 180, 70), (255, 235, 150)); d = ImageDraw.Draw(im)
draw_leaf(d, 200, 230, 150, RED, -0.35); draw_leaf(d, 310, 260, 150, ORANGE, 0.3)
text(d, (380, 420), "2x", 150); save(im, "Leaves2x")
# Big Bag
im = bg((120, 190, 120), (200, 245, 190)); d = ImageDraw.Draw(im)
bag(d, 256, 250, 150); draw_leaf(d, 200, 150, 70, ORANGE, -0.4); draw_leaf(d, 300, 140, 70, RED, 0.4); draw_leaf(d, 250, 120, 60, YELLOW)
text(d, (390, 420), "2x", 130); save(im, "BigBag")
# Auto Rake
im = bg((90, 150, 230), (180, 220, 255)); d = ImageDraw.Draw(im)
rake(d, 250, 270, 190)
for k in range(8):
    a = k * math.pi / 4
    d.line([(370, 380), (370 + 70 * math.cos(a), 380 + 70 * math.sin(a))], fill=DARK, width=36)
d.ellipse([310, 320, 430, 440], fill=(240, 240, 250), outline=DARK, width=12); d.ellipse([350, 360, 390, 400], fill=DARK)
save(im, "AutoRake")
# VIP
im = bg((150, 80, 200), (230, 180, 255)); d = ImageDraw.Draw(im)
pts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    rr = 200 if k % 2 == 0 else 85
    pts.append((256 + rr * math.cos(a), 270 + rr * math.sin(a)))
d.polygon(pts, fill=(255, 210, 50), outline=DARK, width=14)
text(d, (256, 285), "VIP", 110); save(im, "VIP")
# Fill My Bag
im = bg((255, 150, 60), (255, 225, 140)); d = ImageDraw.Draw(im)
bag(d, 256, 270, 160)
for i, (x, y, c) in enumerate([(180, 170, RED), (256, 140, ORANGE), (330, 170, YELLOW), (215, 110, ORANGE), (300, 105, RED)]):
    draw_leaf(d, x, y, 62, c, (i - 2) * 0.3)
save(im, "FillBag")
# 2x Acorns
im = bg((160, 110, 70), (240, 200, 150)); d = ImageDraw.Draw(im)
acorn(d, 190, 230, 110); acorn(d, 320, 250, 110); text(d, (380, 430), "2x", 140); save(im, "Potion2x")
# Acorn Crate
im = bg((110, 160, 90), (200, 235, 170)); d = ImageDraw.Draw(im)
d.rectangle([90, 250, 422, 450], fill=(175, 115, 60), outline=DARK, width=14)
for y in (300, 350, 400):
    d.line([(90, y), (422, y)], fill=DARK, width=6)
for x, y in [(160, 210), (250, 190), (340, 215), (205, 150), (300, 150)]:
    acorn(d, x, y, 55)
save(im, "AcornCrate")
# Unlock Next Yard
im = bg((80, 170, 140), (180, 240, 210)); d = ImageDraw.Draw(im)
for x in (90, 380):
    d.rectangle([x, 150, x + 42, 440], fill=(240, 230, 210), outline=DARK, width=10)
d.rectangle([132, 200, 380, 400], fill=(90, 230, 120), outline=DARK, width=14)
d.polygon([(200, 300), (300, 230), (300, 270), (360, 270), (360, 330), (300, 330), (300, 370)], fill=(255, 255, 255), outline=DARK, width=10)
draw_leaf(d, 400, 120, 70, ORANGE, 0.3)
save(im, "UnlockYard")
