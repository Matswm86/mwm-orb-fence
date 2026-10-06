"""Render the MWM Orb Fence sound effects to assets/sfx/*.ogg.

Modern, not 8-bit (GDD 9): soft analog-style plucks, glassy bells, airy noise
sweeps, gentle sub thumps and short reverb tails. Own synthesis (additive,
FM and modal bells, filtered noise, convolution reverb) plus a few Kenney CC0
impact samples (see CREDITS.md). Pitched sounds use one pentatonic scale:
F# major / D# minor pentatonic (F# G# A# C# D#). The owner's mix changes key
from track to track; over the whole 66 minutes its pitch classes fit B major /
D# minor best, and this scale shares 4 of 5 notes with B major.
Output: 44.1 kHz mono Ogg Vorbis. Deterministic: every random layer has a
fixed seed. Files peak at -3 dBFS; OfSfx sets the in-game level per event.

Usage:
    python3 tools/render_sfx.py --kenney <dir with kenney_impact-sounds> [--out assets/sfx]
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
# F# major pentatonic from F#4, equal temperament (matches the music).
ROOT = 369.99
STEPS = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
PENTA = [ROOT * 2 ** (s / 12.0) for s in STEPS]
PEAK = -3.0


# ------------------------------------------------------------------ helpers


def tt(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def env(dur: float, attack: float, tau: float) -> np.ndarray:
    t = tt(dur)
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    a = 0.5 - 0.5 * np.cos(np.pi * a)
    # Taper the last 25% to zero so a cut segment never clicks.
    tail = np.clip((dur - t) / (0.25 * dur), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / tau) * (0.5 - 0.5 * np.cos(np.pi * tail))


def fit(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.pad(x, (0, n - len(x)))


def mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, g in parts:
        out[: len(p)] += p * g
    return out


def at(x: np.ndarray, start: float, total: float) -> np.ndarray:
    out = np.zeros(int(total * SR))
    i = int(start * SR)
    seg = x[: max(0, len(out) - i)]
    out[i : i + len(seg)] += seg
    return out


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="lowpass", fs=SR, output="sos"), x)


def hp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="highpass", fs=SR, output="sos"), x)


def noise(dur: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(dur * SR))


def swept_bp(x: np.ndarray, f0: float, f1: float, q: float = 2.0) -> np.ndarray:
    """State-variable band-pass whose centre glides from f0 to f1 (exponential)."""
    n = len(x)
    fc = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    out = np.zeros(n)
    low = band = 0.0
    damp = 1.0 / q
    for i in range(n):
        f = 2.0 * np.sin(np.pi * fc[i] / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        out[i] = band
    return out


def sine_glide(dur: float, f0: float, f1: float, glide: float) -> np.ndarray:
    t = tt(dur)
    f = f1 + (f0 - f1) * np.exp(-t / max(glide, 1e-4))
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def modal(f: float, dur: float, ratios, amps, taus, attack: float = 0.001) -> np.ndarray:
    t = tt(dur)
    out = np.zeros(len(t))
    for r, a, tau in zip(ratios, amps, taus, strict=True):
        if f * r < SR * 0.45:
            out += a * np.sin(2.0 * np.pi * f * r * t) * env(dur, attack, tau)
    return out


def fm_bell(
    f: float, dur: float, ratio: float, index: float, idx_tau: float, tau: float
) -> np.ndarray:
    t = tt(dur)
    mod = index * np.exp(-t / idx_tau) * np.sin(2.0 * np.pi * f * ratio * t)
    return np.sin(2.0 * np.pi * f * t + mod) * env(dur, 0.002, tau)


def soft_saw(f: float, dur: float, harmonics: int = 18) -> np.ndarray:
    """Band-limited saw (additive), so no aliasing and no 8-bit edge."""
    t = tt(dur)
    out = np.zeros(len(t))
    for k in range(1, harmonics + 1):
        if f * k > 9000.0:
            break
        out += np.sin(2.0 * np.pi * f * k * t) / k
    return out


def reverb(x: np.ndarray, rt: float, wet: float, damp: float = 6000.0, seed: int = 7) -> np.ndarray:
    """Convolution with a synthetic room: dense decaying noise, darker over time."""
    n = int(rt * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    bright = rng.uniform(-1, 1, n)
    dark = lp(rng.uniform(-1, 1, n), damp * 0.35)
    mixw = np.exp(-t / (rt * 0.25))
    ir = (bright * mixw + dark * 2.0 * (1.0 - mixw)) * np.exp(-6.9 * t / rt)
    ir = lp(ir, damp)
    pre = int(0.012 * SR)
    ir = np.concatenate([np.zeros(pre), ir])
    ir /= np.sqrt(np.sum(ir**2)) + 1e-9
    w = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
    dry = np.pad(x, (0, len(w) - len(x)))
    return dry * (1.0 - wet * 0.5) + w * wet


def finish(
    x: np.ndarray, peak_db: float, fade_ms: float = 30.0, floor_db: float = -60.0
) -> np.ndarray:
    x = hp(x, 35.0)
    # Trim the silent tail, then fade.
    a = np.abs(x)
    thr = np.max(a) * 10 ** (floor_db / 20.0)
    idx = np.nonzero(a > thr)[0]
    if len(idx):
        x = x[: idx[-1] + 1]
    nf = min(len(x), int(fade_ms / 1000.0 * SR))
    if nf > 0:
        x[-nf:] *= np.linspace(1.0, 0.0, nf) ** 2
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20.0)
    return x


def load_kenney(root: Path, name: str) -> np.ndarray:
    hits = list(root.rglob(name))
    if not hits:
        raise FileNotFoundError(f"Kenney sample not found: {name}")
    data, sr = sf.read(str(hits[0]), always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        mono = signal.resample_poly(mono, SR, sr)
    return mono / (np.max(np.abs(mono)) + 1e-9)


# ------------------------------------------------------------------ sounds


def note(i: int, octave: int = 0) -> float:
    return PENTA[i] * 2.0**octave


def pluck(f: float, dur: float, bright: float = 0.5, tau: float = 0.12) -> np.ndarray:
    """Soft analog pluck: band-limited saw through a decaying low-pass."""
    t = tt(dur)
    x = soft_saw(f, dur, 14) * 0.5 + np.sin(2 * np.pi * f * t)
    cutoff = f * (1.5 + 6.0 * bright * np.exp(-t / (tau * 0.5)))
    out = np.zeros(len(x))
    y = 0.0
    for i in range(len(x)):
        a = 1.0 - np.exp(-2.0 * np.pi * cutoff[i] / SR)
        y += a * (x[i] - y)
        out[i] = y
    return out * env(dur, 0.002, tau)


def glass_bell(f: float, dur: float, tau: float = 0.5) -> np.ndarray:
    """Glassy bell: inharmonic modal partials plus a soft FM shimmer."""
    body = modal(
        f,
        dur,
        [1.0, 2.76, 5.4, 8.93],
        [1.0, 0.42, 0.18, 0.07],
        [tau, tau * 0.45, tau * 0.2, tau * 0.1],
    )
    shim = fm_bell(f * 2.0, dur, 1.41, 0.6, 0.05, tau * 0.35)
    det = modal(f * 1.003, dur, [1.0], [0.35], [tau * 0.8])
    return body + shim * 0.18 + det


def tap(variant: int) -> np.ndarray:
    """UI tap: soft rounded synth tom click, under 80 ms."""
    f = [note(0, -1), note(2, -1)][variant]
    d = 0.08
    body = sine_glide(d, f * 1.9, f, 0.008) * env(d, 0.001, 0.022)
    click = bp(noise(0.006, 11 + variant), 1800.0, 5000.0) * env(0.006, 0.0003, 0.0012)
    x = mix((body, 1.0), (click, 0.18))
    return finish(reverb(lp(x, 5000.0), 0.25, 0.08, 4000.0, seed=13 + variant), PEAK, fade_ms=10)


def tick_in() -> np.ndarray:
    """Field touch-down (ghost appears): quiet high soft pluck, under 60 ms."""
    f = note(5)
    d = 0.06
    x = sine_glide(d, f * 1.06, f, 0.004) * env(d, 0.0015, 0.014)
    x = mix((x, 1.0), (modal(f * 2.0, d, [1.0], [1.0], [0.008]), 0.2))
    return finish(x, PEAK, fade_ms=8)


def notyet() -> np.ndarray:
    """Release while a wall grows: low muted 'not yet' blip, 100 ms."""
    f = note(0, -2)
    d = 0.11
    x = sine_glide(d, f * 1.12, f * 0.94, 0.05) * env(d, 0.004, 0.035)
    x = mix((x, 1.0), (sine_glide(d, f * 2.24, f * 1.88, 0.05) * env(d, 0.004, 0.02), 0.15))
    return finish(lp(x, 900.0), PEAK, fade_ms=15)


def wall_start() -> np.ndarray:
    """Wall start: punchy filtered sub thump + pluck on the root, 150 ms."""
    d = 0.32
    thump = sine_glide(d, 120.0, 52.0, 0.02) * env(d, 0.002, 0.045)
    pl = pluck(note(0), d, 0.6, 0.07)
    click = bp(noise(0.008, 21), 1200.0, 4000.0) * env(0.008, 0.0005, 0.002)
    x = mix((thump, 0.9), (pl, 0.55), (click, 0.1))
    return finish(reverb(x, 0.35, 0.12, 4500.0, seed=23), PEAK)


def zip_riser() -> np.ndarray:
    """Wall grows: one continuous soft riser, pitch climbs one octave over 1.6 s."""
    d = 1.6
    t = tt(d)
    f = note(0) * 2.0 ** (t / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    det = np.sin(ph * 1.004) * 0.6
    air = swept_bp(noise(d, 31), 1500.0, 6000.0, 2.5) * 0.6
    amp = np.clip(t / 0.05, 0, 1) * (0.55 + 0.45 * t / d)
    tail = np.clip((d - t) / 0.08, 0, 1)
    x = (lp(tone + det, 3200.0) * 0.6 + air) * amp * tail
    return finish(x, PEAK, fade_ms=20)


def grow_tick(variant: int) -> np.ndarray:
    """Soft tick every 3rd cell per half."""
    f = [note(5), note(6), note(7)][variant]
    d = 0.07
    x = modal(f, d, [1.0, 2.0], [1.0, 0.25], [0.012, 0.006], attack=0.0008)
    return finish(x, PEAK, fade_ms=8)


def lock(kenney: Path) -> np.ndarray:
    """Wall complete: clean click-clack with a bright bell on top, 250 ms."""
    d = 0.6
    c1 = bp(noise(0.012, 41), 1500.0, 6000.0) * env(0.012, 0.0004, 0.003)
    c2 = bp(noise(0.012, 42), 1000.0, 4500.0) * env(0.012, 0.0004, 0.003)
    plate = hp(load_kenney(kenney, "impactPlate_light_000.ogg"), 1200.0)[: int(0.2 * SR)]
    bell = glass_bell(note(5), d, 0.22)
    x = mix(
        (at(c1, 0.0, d), 0.35),
        (at(c2, 0.045, d), 0.3),
        (at(plate, 0.0, d), 0.12),
        (at(bell, 0.03, d), 0.7),
    )
    return finish(reverb(x, 0.5, 0.18, 7000.0, seed=43), PEAK)


def capture(size: str) -> np.ndarray:
    """Area captured: crystal chime + warm rising swell; small 2 notes, big 4-note arpeggio."""
    notes = {"s": [0, 4], "m": [0, 2, 4], "l": [0, 2, 4, 5]}[size]
    d = {"s": 0.9, "m": 1.1, "l": 1.4}[size]
    gap = {"s": 0.09, "m": 0.08, "l": 0.075}[size]
    x = np.zeros(int(d * SR))
    for k, n in enumerate(notes):
        f = note(n)
        b = glass_bell(f, d, 0.45) * 0.55 + pluck(f, d, 0.35, 0.25) * 0.3
        x += at(b, 0.01 + k * gap, d) * (0.8 + 0.1 * k)
    pad = np.zeros(int(d * SR))
    for n in notes[:3]:
        pad += soft_saw(note(n, -1), d, 10)
    t = tt(d)
    swell = np.clip(t / (d * 0.35), 0, 1) ** 1.5 * np.clip((d - t) / (d * 0.5), 0, 1)
    pad = lp(pad, 1400.0) * swell * 0.07
    sparkle = np.zeros(len(x))
    rng = np.random.default_rng(50 + len(notes))
    for _ in range(3 * len(notes)):
        f = rng.uniform(3500.0, 7500.0)
        sparkle += at(
            modal(f, 0.15, [1.0], [1.0], [rng.uniform(0.02, 0.05)]), rng.uniform(0.05, d * 0.6), d
        )
    x = mix((x, 1.0), (pad, 1.0), (sparkle, 0.06))
    return finish(reverb(lp(x, 10000.0), 0.9, 0.28, 7000.0, seed=57), PEAK, fade_ms=80)


def bounce(variant: int) -> np.ndarray:
    """Ball bounce: soft rubbery boop, very low level in game."""
    f = [note(0, -1), note(1, -1), note(2, -1)][variant]
    d = 0.12
    x = sine_glide(d, f * 1.6, f, 0.012) * env(d, 0.002, 0.03)
    x = mix((x, 1.0), (sine_glide(d, f * 3.2, f * 2.0, 0.01) * env(d, 0.001, 0.012), 0.12))
    return finish(lp(x, 2500.0), PEAK, fade_ms=15)


def pop(variant: int) -> np.ndarray:
    """Ball hits a growing wall: soap-bubble plip-plop cluster, light and friendly."""
    d = 0.35
    rng = np.random.default_rng(70 + variant)
    x = np.zeros(int(d * SR))
    for k in range(6):
        f0 = rng.uniform(500.0, 1300.0)
        bd = 0.05
        t = tt(bd)
        f = f0 * (1.0 + 2.2 * t / bd)
        bl = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(bd, 0.002, 0.014)
        x += at(bl, k * 0.035 + rng.uniform(0.0, 0.02), d) * rng.uniform(0.5, 1.0)
    x = lp(x, 6000.0)
    return finish(reverb(x, 0.3, 0.12, 6000.0, seed=75 + variant), PEAK)


def crack(kenney: Path) -> np.ndarray:
    """Spark lost (Vanlig): small glassy crack, quiet."""
    d = 0.4
    g = hp(load_kenney(kenney, "impactGlass_light_001.ogg"), 1500.0)[: int(0.3 * SR)]
    ping = glass_bell(note(8), d, 0.12)
    x = mix((at(g, 0.0, d), 0.6), (at(ping, 0.01, d), 0.3))
    return finish(reverb(x, 0.4, 0.15, 7000.0, seed=81), PEAK)


def rewind() -> np.ndarray:
    """Gentle restart: soft tape-rewind whoosh, 1.2 s (no fail sting)."""
    d = 1.25
    b = glass_bell(note(0), 1.0, 0.4)
    swell = b[::-1][: int(0.6 * SR)] * np.linspace(0.1, 1.0, int(0.6 * SR))
    air = swept_bp(noise(1.1, 91), 5000.0, 400.0, 1.6)
    air *= np.sin(np.pi * np.clip(tt(1.1) / 1.1, 0, 1)) ** 2
    t = tt(1.1)
    wob = np.sin(2 * np.pi * np.cumsum(note(0, -1) * (1.0 - 0.5 * t / 1.1)) / SR) * env(
        1.1, 0.2, 0.4
    )
    x = mix((at(swell, 0.0, d), 0.5), (at(air, 0.05, d), 0.9), (at(wob, 0.1, d), 0.15))
    return finish(lp(x, 4500.0, order=4), PEAK, fade_ms=120)


def milestone() -> np.ndarray:
    """% milestone: short ascending 3-note chime (pitched one step up per milestone in game)."""
    d = 0.9
    x = np.zeros(int(d * SR))
    for k, n in enumerate([5, 6, 7]):
        x += at(glass_bell(note(n), d, 0.3), k * 0.07, d) * (0.8 + 0.1 * k)
    return finish(reverb(x, 0.7, 0.22, 8000.0, seed=101), PEAK, fade_ms=60)


def snegl() -> np.ndarray:
    """Snegl token: slow descending 'wob'."""
    d = 0.9
    t = tt(d)
    f = (
        note(0)
        * 2.0 ** (-t / d)
        * (1.0 + 0.03 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.3, 0, 1))
    )
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = (np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)) * env(d, 0.02, 0.35)
    top = glass_bell(note(5), d, 0.25) * 0.25
    x = mix((lp(x, 2200.0), 1.0), (top, 1.0))
    return finish(reverb(x, 0.8, 0.25, 5000.0, seed=111), PEAK, fade_ms=100)


def win() -> np.ndarray:
    """Level clear: 2 s bright win arpeggio over a warm pad, with a sub hit."""
    d = 3.0
    pad = np.zeros(int(d * SR))
    for n, o in [(0, -1), (2, -1), (3, -1), (0, 0), (1, 0)]:
        for cents in (-6.0, 6.0):
            pad += soft_saw(note(n, o) * 2 ** (cents / 1200.0), d, 12)
    pad = lp(pad, 2000.0) * env(d, 0.3, 1.0) * 0.06
    x = pad
    for k, n in enumerate([5, 6, 7, 8, 9, 10]):
        b = glass_bell(note(n), 2.0, 0.55) * 0.5 + pluck(note(n), 2.0, 0.4, 0.3) * 0.25
        x = x + at(b, 0.05 + k * 0.11, d) * (0.55 + 0.05 * k)
    rng = np.random.default_rng(131)
    for _ in range(26):
        f = rng.uniform(3500.0, 8000.0)
        x = (
            x
            + at(modal(f, 0.2, [1.0], [1.0], [rng.uniform(0.02, 0.06)]), rng.uniform(0.4, 1.8), d)
            * 0.05
        )
    thump = sine_glide(0.5, 110.0, 50.0, 0.04) * env(0.5, 0.003, 0.12)
    x = mix((x, 1.0), (thump, 0.35))
    return finish(reverb(lp(x, 11000.0), 1.8, 0.32, 7000.0, seed=137), PEAK, fade_ms=200)


def sparkle() -> np.ndarray:
    """Win card: soft sparkle as the star lands."""
    d = 1.0
    rng = np.random.default_rng(141)
    x = np.zeros(int(d * SR))
    for k in range(9):
        n = [5, 7, 8, 9, 10][k % 5]
        x += at(glass_bell(note(n), 0.5, 0.15), 0.02 + k * 0.045 + rng.uniform(0, 0.02), d) * (
            1.0 - k / 12.0
        )
    return finish(reverb(x, 0.9, 0.3, 9000.0, seed=143), PEAK, fade_ms=80)


def shimmer() -> np.ndarray:
    """Hint glow: faint shimmer."""
    d = 1.0
    t = tt(d)
    n = bp(noise(d, 151), 4000.0, 9000.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 7.0 * t)) * 0.4
    tones = modal(note(8), d, [1.0], [1.0], [0.4]) + modal(note(10), d, [1.0], [0.7], [0.3])
    x = mix((n, 1.0), (tones, 0.5)) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.2
    return finish(reverb(x, 0.6, 0.25, 9000.0, seed=153), PEAK, fade_ms=60)


def intro() -> np.ndarray:
    """Level intro: gentle rising swell as the frame draws itself."""
    d = 1.2
    t = tt(d)
    pad = np.zeros(len(t))
    for n in (0, 2, 4):
        pad += soft_saw(note(n, -1), d, 10)
    sw = np.clip(t / 0.8, 0, 1) ** 2 * np.clip((d - t) / 0.4, 0, 1)
    pad = lp(pad, 1600.0) * sw * 0.15
    air = swept_bp(noise(d, 161), 600.0, 5000.0, 2.0) * sw * 0.5
    x = mix((pad, 1.0), (air, 1.0), (at(glass_bell(note(5), 0.6, 0.25), 0.75, d), 0.3))
    return finish(reverb(x, 0.8, 0.25, 6000.0, seed=163), PEAK, fade_ms=100)


def build(kenney: Path) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for v in range(2):
        out[f"tap_{v + 1}"] = tap(v)
    for v in range(3):
        out[f"grow_tick_{v + 1}"] = grow_tick(v)
        out[f"bounce_{v + 1}"] = bounce(v)
        out[f"pop_{v + 1}"] = pop(v)
    out["tick_in"] = tick_in()
    out["notyet"] = notyet()
    out["wall_start"] = wall_start()
    out["zip"] = zip_riser()
    out["lock"] = lock(kenney)
    for s in ("s", "m", "l"):
        out[f"capture_{s}"] = capture(s)
    out["crack"] = crack(kenney)
    out["rewind"] = rewind()
    out["milestone"] = milestone()
    out["snegl"] = snegl()
    out["win"] = win()
    out["sparkle"] = sparkle()
    out["shimmer"] = shimmer()
    out["intro"] = intro()
    return out


def write_ogg(x: np.ndarray, path: Path, quality: str = "4") -> None:
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "x.wav"
        sf.write(str(wav), x.astype(np.float32), SR, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", "1", "-ar", str(SR)]
            + ["-c:a", "libvorbis", "-q:a", quality, str(path)],
            check=True,
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--kenney", type=Path, required=True, help="folder holding kenney_impact-sounds"
    )
    ap.add_argument(
        "--out", type=Path, default=Path(__file__).resolve().parent.parent / "assets" / "sfx"
    )
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, x in build(args.kenney).items():
        write_ogg(x, args.out / f"of_{name}.ogg")
        print(f"of_{name}.ogg  {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main()
