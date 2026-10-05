"""Cover-crop + Lanczos upscale the raw AI images to exact sizes, light unsharp mask,
and build 150 px review sheets. raw/thumb_*.png -> ai/thumb_*.jpg (1920x1080, <3 MB);
raw/icon_*.png -> ai/icon_*_512.png (512x512)."""
import pathlib
from PIL import Image, ImageFilter

AI = pathlib.Path(__file__).resolve().parent.parent / "assets" / "thumbnails" / "ai"
RAW = AI / "raw"

def cover(im, w, h):
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    l, t = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((l, t, l + w, t + h))

thumbs, icons = [], []
for f in sorted(RAW.glob("*.png")):
    im = Image.open(f).convert("RGB")
    if f.stem.startswith("thumb"):
        out = cover(im, 1920, 1080).filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
        p = AI / f"{f.stem}.jpg"
        out.save(p, quality=90)
        thumbs.append(p)
    elif f.stem.startswith("icon"):
        out = cover(im, 512, 512).filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=2))
        p = AI / f"{f.stem}_512.png"
        out.save(p)
        icons.append(p)
    print(p.name, p.stat().st_size // 1024, "KB")

def sheet(paths, size, name):
    if not paths:
        return
    ims = [Image.open(p).convert("RGB") for p in paths]
    ims = [i.resize((size, round(size * i.height / i.width)), Image.LANCZOS) for i in ims]
    W = sum(i.width for i in ims) + 10 * (len(ims) + 1)
    H = max(i.height for i in ims) + 20
    s = Image.new("RGB", (W, H), (30, 30, 30))
    x = 10
    for i in ims:
        s.paste(i, (x, 10)); x += i.width + 10
    s.save(AI / name)

sheet(thumbs, 267, "_review_thumbs_150.png")  # thumbnails as they appear small (~267x150)
sheet(icons, 150, "_review_icons_150.png")
