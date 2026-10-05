"""Synthesize every sound in Leaf Pile Dive from pure math (numpy): no samples.
Writes 16-bit mono WAVs to audio/out/. Run: python audio/make_audio.py"""
import pathlib, wave
import numpy as np

SR = 44100
OUT = pathlib.Path(__file__).resolve().parent / "out"
OUT.mkdir(exist_ok=True)
rng = np.random.default_rng(7)

def t(sec):
    return np.arange(int(SR * sec)) / SR

def env(n, a=0.005, r=0.2, sustain=None):
    x = np.ones(n)
    ai = max(1, int(SR * a))
    x[:ai] = np.linspace(0, 1, ai)
    tail = np.exp(-np.arange(n) / (SR * r)) if sustain is None else np.ones(n)
    return x * tail

def lowpass(x, cutoff):
    # one-pole low-pass; cutoff may be an array (sweeps)
    y = np.zeros_like(x)
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y

def highpass(x, cutoff):
    return x - lowpass(x, cutoff)

def tone(freq, sec, kind="sine"):
    tt = t(sec)
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(freq, tt.shape)) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    raise ValueError(kind)

def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")

def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out

def at(x, sec, total):
    out = np.zeros(int(SR * total))
    i = int(SR * sec)
    out[i : i + len(x)] += x[: len(out) - i]
    return out

def note(m):
    return 440 * 2 ** ((m - 69) / 12)

# swish: band-passed noise with a fast sweep (the rake)
n = rng.standard_normal(int(SR * 0.22))
sweep = np.linspace(900, 4200, len(n))
sw = highpass(lowpass(n, sweep), 500) * env(len(n), 0.03, 0.06)
save("swish", sw, 0.6)

# pop: leaf rustle tick + soft pitched blip
rust = highpass(rng.standard_normal(int(SR * 0.08)), 2500) * env(int(SR * 0.08), 0.002, 0.02)
blip = tone(np.linspace(900, 500, int(SR * 0.09)), 0.09, "sine") * env(int(SR * 0.09), 0.002, 0.03)
save("pop", mix(rust * 0.6, blip), 0.6)

# gold: bright bell arpeggio (golden leaf)
tot = 0.7
g = np.zeros(int(SR * tot))
for k, m in enumerate([84, 88, 91, 96]):
    b = (tone(note(m), 0.5) + 0.4 * tone(note(m) * 2.76, 0.5)) * env(int(SR * 0.5), 0.002, 0.18)
    g += at(b, k * 0.06, tot)
save("gold", g, 0.7)

# dive: whump (sine drop) + big leaf crunch (noise burst, low-passed sweep down)
tot = 1.2
boom = tone(np.linspace(140, 38, int(SR * 0.6)), 0.6) * env(int(SR * 0.6), 0.003, 0.22)
crunch_n = rng.standard_normal(int(SR * 0.9))
crunch = lowpass(crunch_n, np.linspace(6000, 600, len(crunch_n))) * env(len(crunch_n), 0.004, 0.25)
crackle = highpass(rng.standard_normal(int(SR * 0.9)), 3000) * (rng.random(int(SR * 0.9)) > 0.985) * env(int(SR * 0.9), 0.001, 0.3) * 3
save("dive", mix(boom * 1.0, crunch * 0.7, crackle * 0.5), 0.95)

# buy: two-note chime up
tot = 0.5
c1 = tone(note(76), 0.35, "tri") * env(int(SR * 0.35), 0.002, 0.12)
c2 = tone(note(83), 0.4, "tri") * env(int(SR * 0.4), 0.002, 0.15)
save("buy", mix(at(c1, 0, tot), at(c2, 0.09, tot)), 0.6)

# error: soft low double buzz
e1 = lowpass(tone(note(45), 0.12, "square"), 900) * env(int(SR * 0.12), 0.003, 0.08)
save("error", mix(at(e1, 0, 0.3), at(e1, 0.14, 0.3)), 0.5)

# full: gentle ding-dong (bag full)
d1 = tone(note(79), 0.4) * env(int(SR * 0.4), 0.002, 0.2)
d2 = tone(note(74), 0.5) * env(int(SR * 0.5), 0.002, 0.25)
save("full", mix(at(d1, 0, 0.8), at(d2, 0.2, 0.8)), 0.55)

# unlock: rising major arpeggio + shimmer
tot = 1.0
u = np.zeros(int(SR * tot))
for k, m in enumerate([67, 71, 74, 79, 83]):
    b = tone(note(m), 0.45, "tri") * env(int(SR * 0.45), 0.003, 0.2)
    u += at(b, k * 0.08, tot)
sh = highpass(rng.standard_normal(int(SR * tot)), 6000) * env(int(SR * tot), 0.2, 0.3) * 0.15
save("unlock", u + sh, 0.75)

# season: little fanfare (triad hits + final chord)
tot = 1.8
f = np.zeros(int(SR * tot))
for start, chord in [(0, [60, 64, 67]), (0.18, [62, 65, 69]), (0.36, [64, 67, 72]), (0.6, [65, 69, 72, 77])]:
    dur = 1.1 if start == 0.6 else 0.16
    for m in chord:
        b = (tone(note(m), dur, "saw") * 0.4 + tone(note(m), dur, "tri"))
        b = lowpass(b, 2500) * env(len(b), 0.004, 0.5 if dur > 1 else 0.1)
        f += at(b, start, tot)
save("season", f, 0.8)

# music: 32 s autumn lo-fi loop (8 bars of 4 s, 60 bpm feel at 120 bpm eighths)
BPM = 90
beat = 60 / BPM
bars = 12
total = bars * 4 * beat
mus = np.zeros(int(SR * total))
prog = [(57, [57, 60, 64, 67]), (53, [53, 57, 60, 64]), (48, [48, 52, 55, 59]), (55, [55, 59, 62, 65])]  # Am7 Fmaj7 Cmaj7 G7
for bar in range(bars):
    root, chord = prog[bar % 4]
    t0 = bar * 4 * beat
    # soft pad
    pad = sum(tone(note(m), 4 * beat, "tri") for m in chord) * 0.12
    pad = lowpass(pad, 1200) * np.minimum(1, np.linspace(0, 6, len(pad))) * np.minimum(1, np.linspace(6, 0, len(pad)))
    mus += at(pad, t0, total)
    # bass on beats 1 and 3
    for b in (0, 2):
        bs = tone(note(root - 12), beat * 1.6, "sine") * env(int(SR * beat * 1.6), 0.01, 0.6) * 0.5
        mus += at(bs, t0 + b * beat, total)
    # pluck arpeggio (eighths)
    pattern = [0, 2, 1, 3, 2, 1, 3, 2]
    for k, idx in enumerate(pattern):
        m = chord[idx] + 12
        pl = tone(note(m), 0.5, "tri") * env(int(SR * 0.5), 0.002, 0.16) * 0.22
        mus += at(pl, t0 + k * beat / 2, total)
    # soft kick + brushed hat
    for b in range(4):
        if b in (0, 2):
            k_ = tone(np.linspace(110, 45, int(SR * 0.18)), 0.18) * env(int(SR * 0.18), 0.002, 0.06) * 0.5
            mus += at(k_, t0 + b * beat, total)
        h = highpass(rng.standard_normal(int(SR * 0.05)), 7000) * env(int(SR * 0.05), 0.001, 0.015) * 0.12
        mus += at(h, t0 + b * beat + beat / 2, total)
# seamless loop: tiny fade at both ends
fade = int(SR * 0.02)
mus[:fade] *= np.linspace(0, 1, fade)
mus[-fade:] *= np.linspace(1, 0, fade)
save("music", mus, 0.8)
