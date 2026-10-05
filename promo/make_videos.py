"""Promo videos for Leaf Pile Dive from real live-game recordings (promo/raw/take2.mp4, take4.mp4,
recorded from the live game v17 with ffmpeg gdigrab, 30 fps, no mouse).
Frame-by-frame PIL rendering (ffmpeg drawtext has no fontconfig on this PC).

Two edits, each as 1080x1920 (TikTok/Shorts/Reels) and 1920x1080 (X):
  calm: straight cuts, steady captions, the game's own music + the game's own sounds
  hype: speed ramps, punch zooms, shake, white flashes, RGB split, word-pop captions,
        logo-slam end card, synthesized SFX (pure math) + the game's own sounds + music ducked
Every caption describes something the game really does.
Outputs: promo/out/leafpiledive_{calm,hype}_{vertical,16x9}.mp4"""
import math, pathlib, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.signal import butter, lfilter

ROOT = pathlib.Path(__file__).resolve().parent
RAW, OUT, TMP = ROOT / "raw", ROOT / "out", ROOT / "tmp"
OUT.mkdir(exist_ok=True); TMP.mkdir(exist_ok=True)
FONT = "C:/Windows/Fonts/ariblk.ttf"
THUMB = ROOT.parent / "assets/thumbnails/ai/thumb_g4_logo.jpg"
GAME_AUDIO = ROOT.parent / "audio/out"
FPS, SR = 30, 44100

# (source, start, end, speed): clean stretches only (no console overlay, no stuck moments)
SEGMENTS = [
    ("take4.mp4", 0.0, 6.0, 1.0),      # spawn, first rakes, leaves fly in
    ("take2.mp4", 135.5, 140.5, 1.0),  # raking fills the bag (0 -> 32)
    ("take4.mp4", 26.8, 28.9, 1.0),    # run into the pile
    ("take4.mp4", 28.9, 31.0, 0.55),   # the dive: leaf burst + "+90" (slow motion)
]
END_LEN = 3.2
SEG_STARTS, _t = [], 0.0
for _s, a, b, sp in SEGMENTS:
    SEG_STARTS.append(_t); _t += (b - a) / sp
MAIN_LEN = _t
TOTAL = MAIN_LEN + END_LEN
E_RAKE2 = SEG_STARTS[1]
E_DIVE = SEG_STARTS[3] + 0.1 / 0.55  # dive frame at take4 29.0 s
Y, W_ = (255, 205, 40), (255, 255, 255)
CAPTIONS = [(0.05, 2.6, "RAKE THE\nLEAVES", W_), (2.6, E_RAKE2, "GOLDEN LEAVES\n= x10", Y),
            (E_RAKE2, SEG_STARTS[2], "FILL YOUR BAG", W_), (SEG_STARTS[2], E_DIVE, "DIVE IN\nTHE PILE!", Y),
            (E_DIVE, MAIN_LEN, "+90 ACORNS!!", Y)]
CALM_CAPTIONS = [(0.0, 6.0, "Rake autumn leaves", W_), (6.0, 11.0, "Fill your bag", W_),
                 (11.0, MAIN_LEN, "Dive in the pile for Acorns", W_)]
PUNCHES = [(0.0, 0.0, 22, 0.0, 8), (E_RAKE2, 0.35, 18, 0.4, 8), (SEG_STARTS[2], 0.3, 14, 0.0, 6),
           (E_DIVE, 0.6, 34, 0.9, 18)]

# ---------------- sound (synthesized + the game's own sounds) ----------------
def tvec(d): return np.arange(int(d * SR)) / SR
def boom(d=1.1, f0=140, f1=38):
    t = tvec(d); f = f1 + (f0 - f1) * np.exp(-t * 9); ph = 2 * np.pi * np.cumsum(f) / SR
    return np.tanh(2.2 * (np.sin(ph) * np.exp(-t * 3.2) + 0.5 * np.random.uniform(-1, 1, t.size) * np.exp(-t * 60)))
def whoosh(d=0.45):
    t = tvec(d); n = np.random.uniform(-1, 1, t.size)
    b, a = butter(2, [400 / (SR / 2), 6000 / (SR / 2)], "band")
    return lfilter(b, a, n) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2 * 2.5
def riser(d=1.6):
    t = tvec(d); ph = 2 * np.pi * np.cumsum(200 * (10 ** (t / d))) / SR
    b, a = butter(2, 3000 / (SR / 2), "high"); n = lfilter(b, a, np.random.uniform(-1, 1, t.size))
    return (0.5 * np.sin(ph) + 0.6 * n) * (t / d) ** 2
def bling():
    t = tvec(0.7); return sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((2093, 6), (3136, 8), (4186, 10))) / 2
def pop():
    t = tvec(0.09); return np.sin(2 * np.pi * np.cumsum(500 + 1400 * t / 0.09) / SR) * np.exp(-t * 40)
def bass_drop(d=1.6):
    t = tvec(d); ph = 2 * np.pi * np.cumsum(35 + 60 * np.exp(-t * 2.5)) / SR
    return np.tanh(3 * np.sin(ph) * np.exp(-t * 1.1))
def game(name):
    with wave.open(str(GAME_AUDIO / f"{name}.wav")) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768

def write_wav(path, x):
    x = np.tanh(1.2 * x / max(1e-6, np.abs(x).max())) * 0.95
    st = np.stack([x, x], 1)
    with wave.open(str(path), "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())

def mix_track(hype):
    buf = np.zeros(int((TOTAL + 1) * SR))
    def put(x, t, g):
        s = int(t * SR); buf[s:s + x.size] += g * x[: max(0, buf.size - s)]
    # game music under everything (looped), quieter in the hype cut; fades out under the end card
    mus = game("music"); m = np.tile(mus, int(TOTAL * SR / mus.size) + 2)[: buf.size]
    env = np.ones(buf.size); fs = int((MAIN_LEN + 1.0) * SR); env[fs:] = np.linspace(1, 0, buf.size - fs)
    music = m * env * (0.35 if hype else 0.55)
    # the game's own rake/pop sounds on the raking stretches, gold bling, dive boom
    for t in np.arange(0.4, 5.8, 0.55): put(game("swish"), t, 0.35); put(game("pop"), t + 0.12, 0.3)
    for t in np.arange(E_RAKE2 + 0.3, E_RAKE2 + 4.8, 0.55): put(game("swish"), t, 0.35); put(game("pop"), t + 0.12, 0.3)
    put(game("gold"), 3.0, 0.5); put(game("dive"), E_DIVE, 0.9)
    if hype:
        put(boom(), 0.0, 0.8); put(pop(), 0.05, 0.5); put(pop(), 2.6, 0.5)
        put(whoosh(), E_RAKE2 - 0.3, 0.6); put(boom(0.7, 180, 50), E_RAKE2, 0.5); put(bling(), 3.0, 0.3)
        put(riser(E_DIVE - SEG_STARTS[2]), SEG_STARTS[2], 0.45); put(pop(), SEG_STARTS[2], 0.45)
        put(boom(1.4), E_DIVE, 1.0); put(bass_drop(), E_DIVE, 0.8); put(bling(), E_DIVE + 0.2, 0.35)
        put(whoosh(0.4), MAIN_LEN - 0.25, 0.6); put(boom(1.2), MAIN_LEN, 0.8); put(pop(), MAIN_LEN + 0.45, 0.5)
    sfx = buf.copy()
    if hype:  # duck the music under the effects (simple envelope sidechain)
        e = np.abs(sfx); k = int(0.25 * SR); e = np.convolve(e, np.ones(k) / k, mode="same")
        music = music * (1 - 0.7 * np.clip(e / (e.max() + 1e-6) * 3, 0, 1))
    return (sfx + music)[: int(TOTAL * SR)]

# ---------------- video ----------------
def punch_state(t):
    z = sx = sy = fl = rgb = 0.0
    for te, zs, sh, f, r in PUNCHES:
        dt = t - te
        if dt < -0.05 or dt > 1.0: continue
        k = (dt + 0.05) / 0.05 if dt < 0 else math.exp(-dt / 0.22)
        z += zs * k; fl = max(fl, f * (math.exp(-dt / 0.12) if dt >= 0 else 0)); rgb = max(rgb, r * k)
        a = sh * (math.exp(-dt / 0.18) if dt >= 0 else 0); sx += a * math.sin(dt * 91 + te); sy += a * math.cos(dt * 77 + te * 2)
    return z, sx, sy, fl, rgb

def caption_img(text, color, size, stroke=12):
    f = ImageFont.truetype(FONT, size)
    box = [int(math.ceil(v)) for v in ImageDraw.Draw(Image.new("RGBA", (1, 1))).multiline_textbbox((0, 0), text, font=f, align="center", spacing=6, stroke_width=stroke)]
    im = Image.new("RGBA", (box[2] - box[0] + 40, box[3] - box[1] + 40), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.multiline_text((20 - box[0] + 8, 20 - box[1] + 10), text, font=f, align="center", spacing=6, fill=(0, 0, 0, 150), stroke_width=stroke, stroke_fill=(0, 0, 0, 150))
    d.multiline_text((20 - box[0], 20 - box[1]), text, font=f, align="center", spacing=6, fill=color, stroke_width=stroke, stroke_fill=(60, 25, 5))
    return im

def frames(src, a, b, sp):
    w, h = 1920, 1080
    p = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", str(a), "-t", str(b - a + 0.3), "-i", str(RAW / src),
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-r", str(FPS), "-"], stdout=subprocess.PIPE)
    n_out = int(round((b - a) / sp * FPS)); idx = -1; cur = None
    for i in range(n_out):
        want = int(i * sp)
        while idx < want:
            buf = p.stdout.read(w * h * 3)
            if len(buf) < w * h * 3: break
            cur = np.frombuffer(buf, np.uint8).reshape(h, w, 3); idx += 1
        yield cur
    p.stdout.close(); p.wait()

def render(kind, name, W, H, vertical):
    hype = kind == "hype"
    caps = CAPTIONS if hype else CALM_CAPTIONS
    cache = {}
    cap_size = (96 if vertical else 100) if hype else (70 if vertical else 64)
    cap_y = int(H * (0.72 if vertical else 0.80))
    base_w = 608 if vertical else 1920
    vid = TMP / f"{kind}_{name}_v.mp4"
    enc = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                            "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", str(vid)], stdin=subprocess.PIPE)
    fi = 0
    for (src, a, b, sp), t0 in zip(SEGMENTS, SEG_STARTS):
        for k, frame in enumerate(frames(src, a, b, sp)):
            if frame is None: continue
            t = t0 + k / FPS
            z, sx, sy, fl, rgb = punch_state(t) if hype else (0, 0, 0, 0, 0)
            zz = 1 + z; cw, ch = base_w / zz, 1080 / zz
            cx = min(max(960 + sx, cw / 2), 1920 - cw / 2); cy = min(max(560 + sy, ch / 2), 1080 - ch / 2)
            im = Image.fromarray(frame).crop((int(cx - cw / 2), int(cy - ch / 2), int(cx + cw / 2), int(cy + ch / 2))).resize((W, H), Image.BILINEAR)
            if hype and (rgb > 0.5 or fl > 0.01):
                arr = np.asarray(im).astype(np.int16)
                if rgb > 0.5:
                    r = int(rgb); arr = arr.copy(); arr[:, :, 0] = np.roll(arr[:, :, 0], r, 1); arr[:, :, 2] = np.roll(arr[:, :, 2], -r, 1)
                if fl > 0.01: arr = arr + (255 - arr) * fl
                im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
            for s, e, text, col in caps:
                if s <= t < e:
                    if (text, col) not in cache: cache[(text, col)] = caption_img(text, col, cap_size, 12 if hype else 8)
                    c = cache[(text, col)]; dt = t - s
                    sc = (1.0 + 0.6 * math.exp(-dt / 0.07) * (1 if dt < 0.25 else 0)) if hype else 1.0
                    sc *= min(1.0, W * 0.94 / c.width)
                    cs = c.resize((max(1, int(c.width * sc)), max(1, int(c.height * sc))), Image.BILINEAR)
                    if hype and "!!" in text: cs = cs.rotate(4 * math.sin(fi * 0.15), resample=Image.BILINEAR, expand=True)
                    im.paste(cs, ((W - cs.width) // 2, cap_y - cs.height // 2), cs)
            enc.stdin.write(im.tobytes()); fi += 1
    # end card
    th = Image.open(THUMB).convert("RGB")
    bg = th.resize((W if not vertical else int(H * 16 / 9), H)).filter(ImageFilter.GaussianBlur(28)).point(lambda v: int(v * 0.55))
    bg = bg.crop(((bg.width - W) // 2, 0, (bg.width - W) // 2 + W, H))
    fg_w = W if vertical else int(W * 0.7); fg = th.resize((fg_w, int(fg_w * 9 / 16)))
    play = caption_img("PLAY NOW\nON ROBLOX" if vertical else "PLAY NOW ON ROBLOX", Y, 92 if vertical else 80)
    srch = caption_img("search: Leaf Pile Dive", W_, 50 if vertical else 46)
    fg_y = (H - fg.height) // 2 - (120 if vertical else 110)
    for k in range(int(END_LEN * FPS)):
        dt = k / FPS; frame = bg.copy()
        sc = 1 + (0.9 * math.exp(-dt / 0.08) if hype else 0); shake = 30 * math.exp(-dt / 0.15) if hype else 0
        f2 = fg.resize((int(fg.width * sc), int(fg.height * sc)), Image.BILINEAR)
        frame.paste(f2, ((W - f2.width) // 2 + int(shake * math.sin(dt * 90)), fg_y + (fg.height - f2.height) // 2 + int(shake * math.cos(dt * 70))))
        if dt >= (0.45 if hype else 0.0):
            py = fg_y + fg.height + (40 if vertical else 10)
            frame.paste(play, ((W - play.width) // 2, py), play); frame.paste(srch, ((W - srch.width) // 2, py + play.height - 10), srch)
        arr = np.asarray(frame).astype(np.int16)
        if hype: arr = np.clip(arr + (255 - arr) * 0.8 * math.exp(-dt / 0.1), 0, 255)
        enc.stdin.write(arr.astype(np.uint8).tobytes())
    enc.stdin.close(); enc.wait()
    wav = TMP / f"{kind}_audio.wav"
    if not wav.exists(): write_wav(wav, mix_track(hype))
    final = OUT / f"leafpiledive_{kind}_{name}.mp4"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(vid), "-i", str(wav), "-map", "0:v", "-map", "1:a",
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(final)], check=True)
    print(final, f"{TOTAL:.1f}s")

if __name__ == "__main__":
    np.random.seed(7)
    for k in ("calm", "hype"):
        (TMP / f"{k}_audio.wav").unlink(missing_ok=True)
    print({"rake2": round(E_RAKE2, 2), "dive": round(E_DIVE, 2), "main": round(MAIN_LEN, 2)})
    for kind in ("calm", "hype"):
        render(kind, "vertical", 1080, 1920, True)
        render(kind, "16x9", 1920, 1080, False)
