"""Render the MWM Orb Fence sound effects to assets/sfx/*.ogg.

Modern, not 8-bit (GDD 9), space themed (owner, 2026-10-07: "rockets,
spaceships, lasers"): soft laser zaps, a thin humming beam, force-field
seals, sonar blips, shield fizzles, rocket whooshes, warp sweeps, comms
beeps, satellite pings and doppler spaceship pass-bys, all kept soft for
small kids (no alarms, no fail stings, no booms). Own synthesis (additive,
FM and modal bells, filtered and swept noise, pitch sweeps, doppler pan,
echo, convolution reverb) plus one Kenney CC0 impact sample (see
CREDITS.md). Pitched sounds use one pentatonic scale:
F# major / D# minor pentatonic (F# G# A# C# D#). The owner's mix changes key
from track to track; over the whole 66 minutes its pitch classes fit B major /
D# minor best, and this scale shares 4 of 5 notes with B major.
Output: 44.1 kHz Ogg Vorbis, mono except the stereo pass-bys (of_win,
of_pass_*). Deterministic: every random layer has a fixed seed. Files peak at
-3 dBFS; OfSfx sets the in-game level per event.

Usage:
    python3 tools/render_sfx.py --kenney <dir with kenney_impact-sounds> [--out assets/sfx]
        [--only mirror ...]   (render only these names, e.g. a newly added sound)
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


def grow_tick(variant: int) -> np.ndarray:
    """Soft tick every 3rd cell per half."""
    f = [note(5), note(6), note(7)][variant]
    d = 0.07
    x = modal(f, d, [1.0, 2.0], [1.0, 0.25], [0.012, 0.006], attack=0.0008)
    return finish(x, PEAK, fade_ms=8)


def crack(kenney: Path) -> np.ndarray:
    """Spark lost (Vanlig): small glassy crack, quiet."""
    d = 0.4
    g = hp(load_kenney(kenney, "impactGlass_light_001.ogg"), 1500.0)[: int(0.3 * SR)]
    ping = glass_bell(note(8), d, 0.12)
    x = mix((at(g, 0.0, d), 0.6), (at(ping, 0.01, d), 0.3))
    return finish(reverb(x, 0.4, 0.15, 7000.0, seed=81), PEAK)


def shimmer() -> np.ndarray:
    """Hint glow: faint shimmer."""
    d = 1.0
    t = tt(d)
    n = bp(noise(d, 151), 4000.0, 9000.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 7.0 * t)) * 0.4
    tones = modal(note(8), d, [1.0], [1.0], [0.4]) + modal(note(10), d, [1.0], [0.7], [0.3])
    x = mix((n, 1.0), (tones, 0.5)) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.2
    return finish(reverb(x, 0.6, 0.25, 9000.0, seed=153), PEAK, fade_ms=60)


def chorus(f_or_ph: np.ndarray, harmonics: int = 8, cents: float = 7.0) -> np.ndarray:
    """Two detuned band-limited saws from one phase track (radians)."""
    out = np.zeros(len(f_or_ph))
    for det in (1.0, 2.0 ** (cents / 1200.0)):
        for k in range(1, harmonics + 1):
            out += np.sin(k * f_or_ph * det) / k
    return out * 0.5


def phase(f: np.ndarray) -> np.ndarray:
    return 2.0 * np.pi * np.cumsum(f) / SR


def echo(x: np.ndarray, delay: float, fb: float, repeats: int, damp: float = 3000.0) -> np.ndarray:
    """Soft repeating echo, each repeat darker (sonar / satellite feel)."""
    d = int(delay * SR)
    out = np.pad(x, (0, d * repeats))
    tap_x = x
    for r in range(1, repeats + 1):
        tap_x = lp(tap_x, damp)
        out[r * d : r * d + len(tap_x)] += tap_x * fb**r
    return out


def ship_pass(dur: float, f_base: float, seed: int, shift: float, width: float) -> np.ndarray:
    """Spaceship passing by: detuned engine hum + air, doppler pitch drop,
    louder and brighter at the closest point, panned left to right (stereo)."""
    t = tt(dur)
    u = (t - dur * 0.5) / (dur * 0.2)
    ratio = 1.0 + shift * -np.tanh(u)
    near = 1.0 / (1.0 + u**2)
    ph = phase(f_base * ratio)
    engine = chorus(ph, 10, 9.0)
    whine = np.sin(ph * 6.0) * 0.12 + np.sin(ph * 9.03) * 0.05
    dark = lp(engine, 380.0)
    bright = lp(engine + whine, 2200.0)
    air = lp(noise(dur, seed), 900.0) * 0.5 + bp(noise(dur, seed + 1), 1500.0, 4500.0) * 0.12
    body = dark * (1.0 - near) + bright * near + air * near
    edge = np.clip(t / 0.3, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    x = body * near**1.3 * edge
    return pan(x, width * np.tanh(u * 0.9))


def pan(x: np.ndarray, p) -> np.ndarray:
    """Constant-power pan, p in -1 (left) .. 1 (right); scalar or per sample."""
    theta = (np.asarray(p, dtype=float) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(theta), x * np.sin(theta)], axis=1)


def finish_st(x: np.ndarray, peak_db: float, fade_ms: float = 60.0) -> np.ndarray:
    """finish() for stereo arrays (n, 2): same trim, fade and peak level."""
    x = np.stack([hp(x[:, 0], 35.0), hp(x[:, 1], 35.0)], axis=1)
    a = np.max(np.abs(x), axis=1)
    idx = np.nonzero(a > np.max(a) * 10 ** (-60.0 / 20.0))[0]
    if len(idx):
        x = x[: idx[-1] + 1]
    nf = min(len(x), int(fade_ms / 1000.0 * SR))
    if nf > 0:
        x[-nf:] *= (np.linspace(1.0, 0.0, nf) ** 2)[:, None]
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20.0)


def click(variant: int) -> np.ndarray:
    """UI tap: clean cockpit button click, tight tick + tiny glassy tone, under 70 ms."""
    f = [note(5), note(6), note(7)][variant]
    d = 0.07
    tick = bp(noise(0.004, 11 + variant), 2500.0, 7000.0) * env(0.004, 0.0002, 0.0008)
    tone = modal(f, d, [1.0, 2.0], [1.0, 0.2], [0.012, 0.005], attack=0.0006)
    body = sine_glide(d, 260.0, 180.0, 0.005) * env(d, 0.0008, 0.008)
    x = mix((tick, 0.35), (tone, 0.6), (body, 0.5))
    return finish(reverb(lp(x, 7000.0), 0.18, 0.06, 5000.0, seed=13 + variant), PEAK, fade_ms=8)


def servo(variant: int) -> np.ndarray:
    """Direction pick: short servo turn, a motor whirr gliding up a fifth, then a soft stop tick."""
    d = 0.24
    t = tt(d)
    f0, f1 = (note(0, -1), note(3, -1)) if variant == 0 else (note(3, -1), note(0, -1))
    f = f0 + (f1 - f0) * (0.5 - 0.5 * np.cos(np.pi * np.clip(t / 0.15, 0, 1)))
    ph = phase(f)
    whirr = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * (
        0.8 + 0.2 * np.sin(2 * np.pi * 55.0 * t)
    )
    whirr = lp(whirr, 1800.0) * np.clip(t / 0.01, 0, 1) * np.clip((0.17 - t) / 0.03, 0, 1)
    stop = modal(note(5), 0.06, [1.0], [1.0], [0.01], attack=0.0006)
    x = mix((whirr, 0.7), (at(stop, 0.16, d), 0.35))
    return finish(reverb(x, 0.2, 0.08, 5000.0, seed=17 + variant), PEAK, fade_ms=12)


def laser(variant: int) -> np.ndarray:
    """Wall start: soft laser beam fire. FM tone sweeping down onto the root
    plus a filtered air zap and a light sub push, about 300 ms."""
    d = 0.42
    t = tt(d)
    end = [note(0), note(2), note(4)][variant]
    start = end * [5.0, 5.6, 4.6][variant]
    f = end + (start - end) * np.exp(-t / [0.035, 0.03, 0.04][variant])
    ph = phase(f)
    idx = 1.6 * np.exp(-t / 0.05)
    tone = np.sin(ph + idx * np.sin(ph * 2.0)) * env(d, 0.002, 0.09)
    zap = swept_bp(noise(0.16, 21 + variant), 6500.0, 900.0, 3.0) * env(0.16, 0.001, 0.04)
    push = sine_glide(d, 140.0, 60.0, 0.02) * env(d, 0.002, 0.04)
    x = mix((lp(tone, 5500.0), 0.7), (zap, 0.45), (push, 0.5))
    return finish(reverb(x, 0.45, 0.16, 6000.0, seed=23 + variant), PEAK)


def beam() -> np.ndarray:
    """Wall grows: thin humming laser beam that climbs one octave over 1.6 s
    (GDD riser), soft chorus, a faint high shimmer. Played low."""
    d = 1.6
    t = tt(d)
    ph = phase(note(0, -1) * 2.0 ** (t / d))
    hum = lp(chorus(ph, 6, 6.0), 1400.0)
    thin = np.sin(ph * 4.0) * (0.6 + 0.4 * np.sin(2 * np.pi * 9.0 * t)) * 0.18
    shim = bp(noise(d, 31), 3500.0, 7000.0) * (0.8 + 0.2 * np.sin(2 * np.pi * 6.0 * t)) * 0.04
    amp = np.clip(t / 0.06, 0, 1) * (0.6 + 0.4 * t / d)
    tail = np.clip((d - t) / 0.08, 0, 1)
    x = (hum * 0.6 + thin + shim) * amp * tail
    return finish(x, PEAK, fade_ms=20)


def seal(variant: int) -> np.ndarray:
    """Wall complete: force-field lock-in. Quick rising 'zhoop', a soft sub
    thunk and an energy bell that hums for a moment, about 400 ms."""
    d = 0.75
    t = tt(d)
    top = [note(5), note(6)][variant]
    zh = sine_glide(0.09, top * 0.4, top, 0.03) * env(0.09, 0.004, 0.04)
    thunk = sine_glide(0.25, 95.0, 55.0, 0.03) * env(0.25, 0.002, 0.05)
    bell = glass_bell(top, d, 0.25)
    field = (
        np.sin(2 * np.pi * top * 0.5 * t)
        * (0.6 + 0.4 * np.sin(2 * np.pi * 16.0 * t))
        * env(d, 0.01, 0.18)
    )
    x = mix(
        (at(zh, 0.0, d), 0.45),
        (at(thunk, 0.06, d), 0.45),
        (at(bell, 0.07, d), 0.6),
        (at(field, 0.07, d), 0.22),
    )
    return finish(reverb(x, 0.5, 0.18, 7000.0, seed=43 + variant), PEAK)


def scifi_chime(notes: list[int], d: float, gap: float, seed: int) -> np.ndarray:
    """Crystal chime with an FM space shimmer and a soft echo."""
    x = np.zeros(int(d * SR))
    for k, n in enumerate(notes):
        f = note(n)
        b = glass_bell(f, d, 0.45) * 0.5 + fm_bell(f, d, 3.5, 1.2, 0.08, 0.3) * 0.25
        x += at(b, 0.01 + k * gap, d) * (0.8 + 0.1 * k)
    rng = np.random.default_rng(seed)
    for _ in range(2 * len(notes)):
        f = rng.uniform(3500.0, 7500.0)
        x += (
            at(
                modal(f, 0.15, [1.0], [1.0], [rng.uniform(0.02, 0.05)]),
                rng.uniform(0.05, d * 0.6),
                d,
            )
            * 0.05
        )
    return echo(x, 0.12, 0.28, 2, 3500.0)


def capture(size: str, variant: int = 0) -> np.ndarray:
    """Room captured. Small: sci-fi chime (2 notes, a soft 'bwip' first).
    Medium: 3-note chime over a short whoosh. Large: rocket launch, a low
    rumble and a whoosh rising into the 4-note crystal chime."""
    if size == "s":
        notes = [[0, 4], [2, 5]][variant]
        d = 1.0
        bwip = sine_glide(0.1, note(notes[0]) * 0.5, note(notes[0]), 0.03) * env(0.1, 0.003, 0.04)
        x = mix((at(bwip, 0.0, d), 0.3), (at(scifi_chime(notes, d, 0.09, 51), 0.05, d + 0.3), 1.0))
        return finish(reverb(lp(x, 10000.0), 0.9, 0.26, 7000.0, seed=57 + variant), PEAK, 80)
    if size == "m":
        d = 1.4
        wh = swept_bp(noise(0.5, 52), 400.0, 3500.0, 1.8) * np.sin(np.pi * tt(0.5) / 0.5) ** 2
        x = mix(
            (at(wh, 0.0, d), 0.35), (at(scifi_chime([0, 2, 4], d, 0.08, 53), 0.3, d + 0.3), 1.0)
        )
        return finish(reverb(lp(x, 10000.0), 0.9, 0.28, 7000.0, seed=59), PEAK, 80)
    d = 2.3
    lift = 0.75
    tl = tt(lift)
    rumble = lp(noise(lift, 54), 160.0, order=4) * (tl / lift) ** 1.5 * 3.0
    whoosh = swept_bp(noise(lift, 55), 250.0, 5000.0, 1.6) * (tl / lift) ** 2
    rise = np.sin(phase(note(0, -2) * 2.0 ** (2.0 * tl / lift))) * (tl / lift) ** 2
    launch = mix((rumble, 0.35), (whoosh, 0.7), (lp(rise, 1500.0), 0.25))
    launch *= np.clip((lift + 0.08 - tl) / 0.12, 0, 1)
    trail = swept_bp(noise(0.9, 56), 5000.0, 2000.0, 1.5) * env(0.9, 0.005, 0.25)
    x = mix(
        (at(launch, 0.0, d), 1.0),
        (at(trail, lift - 0.02, d), 0.25),
        (at(scifi_chime([0, 2, 4, 5], 1.4, 0.075, 57), lift - 0.05, d), 1.0),
    )
    return finish(reverb(lp(x, 10000.0), 1.0, 0.28, 7000.0, seed=61), PEAK, 100)


def sonar(variant: int) -> np.ndarray:
    """Ball bounce: soft sonar blip with two dark echoes. Very low level in game."""
    f = [note(0), note(1), note(2), note(3)][variant]
    d = 0.09
    ping = sine_glide(d, f * 1.03, f, 0.02) * env(d, 0.003, 0.025)
    ping = mix((ping, 1.0), (modal(f * 2.0, d, [1.0], [1.0], [0.01]), 0.08))
    return finish(echo(lp(ping, 3000.0), 0.075, 0.3, 2, 1800.0), PEAK, fade_ms=20)


def mirror() -> np.ndarray:
    """Mirror bounce (worlds 5-6): a short glassy ping, brighter and shorter
    than the sonar blip, with a quick upward glint so it reads as "the ball
    turned" (GDD 9, about 0.2 s plus a short tail)."""
    d = 0.2
    f = note(7)
    t = tt(d)
    glint = sine_glide(d, f * 0.94, f * 1.06, 0.03) * env(d, 0.001, 0.035)
    bell = glass_bell(f * 2.0, d, 0.05)
    air = hp(noise(d, 211), 6000.0) * env(d, 0.0005, 0.006)
    shimmer = np.sin(2 * np.pi * f * 3.0 * t) * env(d, 0.002, 0.02)
    x = mix((glint, 0.6), (bell, 0.55), (air, 0.08), (shimmer, 0.12))
    return finish(reverb(lp(x, 9000.0), 0.35, 0.18, 9000.0, seed=212), PEAK, fade_ms=40)


def fizzle(variant: int) -> np.ndarray:
    """Ball hits a growing wall: soft energy-shield fizzle. Friendly bubbly
    blips plus a short electric sparkle that thins out, never a buzzer."""
    d = 0.4
    rng = np.random.default_rng(70 + variant)
    x = np.zeros(int(d * SR))
    for k in range(5):
        f0 = rng.uniform(600.0, 1300.0)
        bd = 0.05
        t = tt(bd)
        bl = np.sin(phase(f0 * (1.0 + 1.8 * t / bd))) * env(bd, 0.002, 0.014)
        x += at(bl, k * 0.04 + rng.uniform(0.0, 0.02), d) * rng.uniform(0.5, 1.0)
    crackle = np.zeros(int(d * SR))
    for _ in range(40):
        i = int(rng.uniform(0.0, 0.25) * SR)
        crackle[i] += rng.uniform(-1.0, 1.0) * np.exp(-i / (0.08 * SR))
    crackle = bp(crackle, 2500.0, 7000.0)
    hiss = swept_bp(noise(d, 74 + variant), 5000.0, 1500.0, 2.0) * env(d, 0.003, 0.07)
    x = mix((lp(x, 6000.0), 1.0), (crackle, 0.35), (hiss, 0.25))
    return finish(reverb(x, 0.3, 0.12, 6000.0, seed=75 + variant), PEAK)


def rewind() -> np.ndarray:
    """Gentle restart: soft 'rewind' warp, a reversed bell and a tone sliding
    down an octave with slowing wobble, 1.3 s (no fail sting)."""
    d = 1.35
    b = glass_bell(note(0), 1.0, 0.4)
    swell = b[::-1][: int(0.6 * SR)] * np.linspace(0.1, 1.0, int(0.6 * SR))
    t = tt(1.1)
    air = swept_bp(noise(1.1, 91), 5000.0, 400.0, 1.6) * np.sin(np.pi * t / 1.1) ** 2
    wob_rate = 7.0 - 5.0 * t / 1.1
    f = note(0, -1) * 2.0 ** (-t / 1.1) * (1.0 + 0.02 * np.sin(phase(wob_rate)))
    tone = lp(chorus(phase(f), 6, 8.0), 1500.0) * env(1.1, 0.25, 0.4)
    x = mix((at(swell, 0.0, d), 0.45), (at(air, 0.05, d), 0.8), (at(tone, 0.1, d), 0.25))
    return finish(lp(x, 4500.0, order=4), PEAK, fade_ms=120)


def comms() -> np.ndarray:
    """% milestone: radio/comms double beep with a soft key-up squelch
    (pitched one step up per milestone in game)."""
    d = 0.6
    f = note(5)
    beep = modal(f, 0.09, [1.0, 2.0], [1.0, 0.12], [0.05, 0.02], attack=0.004)
    beep2 = modal(f * PENTA[1] / PENTA[0], 0.11, [1.0, 2.0], [1.0, 0.12], [0.06, 0.02], 0.004)
    squelch = bp(noise(0.03, 101), 900.0, 3200.0) * env(0.03, 0.001, 0.008)
    x = mix((squelch, 0.12), (at(beep, 0.02, d), 0.8), (at(beep2, 0.13, d), 0.9))
    return finish(reverb(x, 0.5, 0.2, 7000.0, seed=103), PEAK, fade_ms=60)


def snegl() -> np.ndarray:
    """Snegl token: 'time warp' whoosh. A chorus tone slides down while its
    wobble slows from 8 to 2 Hz, with a swept air whoosh and a soft bell."""
    d = 1.2
    t = tt(d)
    rate = 8.0 - 6.0 * t / d
    f = note(0) * 2.0 ** (-t / d) * (1.0 + 0.03 * np.sin(phase(rate)))
    tone = lp(chorus(phase(f), 6, 10.0), 2200.0) * env(d, 0.03, 0.4)
    air = swept_bp(noise(d, 111), 4500.0, 500.0, 2.2) * np.sin(np.pi * t / d) ** 2
    x = mix((tone, 0.8), (air, 0.5), (glass_bell(note(5), d, 0.25), 0.22))
    return finish(reverb(x, 0.8, 0.25, 5000.0, seed=113), PEAK, fade_ms=100)


def lyn() -> np.ndarray:
    """Lyn token (later worlds): thruster boost. A short ignition puff, a tone
    rising two octaves and a bright bell at the top."""
    d = 1.0
    t = tt(0.45)
    puff = lp(noise(0.45, 121), 1200.0) * env(0.45, 0.01, 0.12)
    thrust = swept_bp(noise(0.45, 122), 400.0, 4500.0, 1.8) * (t / 0.45) ** 0.7
    thrust *= np.clip((0.45 - t) / 0.08, 0, 1)
    rise = np.sin(phase(note(0, -1) * 2.0 ** (2.0 * t / 0.45))) * (t / 0.45)
    rise *= np.clip((0.45 - t) / 0.06, 0, 1)
    x = mix(
        (puff, 0.4),
        (thrust, 0.6),
        (lp(rise, 3000.0), 0.3),
        (at(glass_bell(note(7), 0.6, 0.25), 0.4, d), 0.5),
    )
    return finish(reverb(x, 0.6, 0.2, 7000.0, seed=123), PEAK, fade_ms=80)


def skjold() -> np.ndarray:
    """Skjold token (later worlds): shield power-up hum. A warm chord swells
    up with an opening filter and a slowing shimmer, then a bell."""
    d = 1.3
    t = tt(d)
    chord = np.zeros(len(t))
    for n in (0, 2, 3):
        chord += chorus(phase(np.full(len(t), note(n, -1))), 6, 7.0)
    sw = np.clip(t / 0.7, 0, 1) ** 1.5 * np.clip((d - t) / 0.45, 0, 1)
    rate = 14.0 - 10.0 * np.clip(t / 0.8, 0, 1)
    chord = lp(chord, 1800.0) * sw * (0.75 + 0.25 * np.sin(phase(rate)))
    x = mix((chord, 0.3), (at(glass_bell(note(5), 0.6, 0.3), 0.7, d), 0.5))
    return finish(reverb(x, 0.7, 0.22, 6000.0, seed=133), PEAK, fade_ms=100)


def warp_in() -> np.ndarray:
    """Level start: hyperspace warp-in. Rising whoosh and stretching tone,
    then a quick drop out of warp onto a soft bell, 1.5 s."""
    d = 1.6
    w = 0.9
    t = tt(w)
    sw = (t / w) ** 2 * np.clip((w - t) / 0.06, 0, 1)
    air = swept_bp(noise(w, 161), 300.0, 6000.0, 2.0) * sw
    tone = lp(chorus(phase(note(0, -1) * 2.0 ** (1.5 * t / w)), 6, 12.0), 2500.0) * sw
    drop = sine_glide(0.35, note(5) * 1.8, note(0), 0.05) * env(0.35, 0.003, 0.08)
    thump = sine_glide(0.3, 110.0, 55.0, 0.03) * env(0.3, 0.002, 0.06)
    x = mix(
        (at(air, 0.0, d), 0.6),
        (at(tone, 0.0, d), 0.25),
        (at(drop, w - 0.02, d), 0.4),
        (at(thump, w, d), 0.3),
        (at(glass_bell(note(5), 0.6, 0.25), w + 0.05, d), 0.35),
    )
    return finish(reverb(x, 0.8, 0.25, 6000.0, seed=163), PEAK, fade_ms=100)


def win() -> np.ndarray:
    """Level clear (stereo): a spaceship flies by left to right, then a warm
    fanfare chord with a rising bell arpeggio, 3.2 s."""
    d = 3.4
    fly = ship_pass(1.8, note(0, -2), 171, 0.07, 0.85)
    fly = np.vstack([fly, np.zeros((int(d * SR) - len(fly), 2))])
    chord = np.zeros(int(d * SR))
    t = tt(d)
    for n, o in [(0, -1), (2, -1), (3, -1), (0, 0)]:
        chord += chorus(phase(np.full(len(t), note(n, o))), 10, 8.0)
    cut = 600.0 + 1800.0 * np.exp(-np.maximum(t - 0.6, 0.0) / 0.5)
    brass = np.zeros(len(chord))
    y = 0.0
    for i in range(len(chord)):
        a = 1.0 - np.exp(-2.0 * np.pi * cut[i] / SR)
        y += a * (chord[i] - y)
        brass[i] = y
    brass *= np.clip((t - 0.6) / 0.08, 0, 1) * np.exp(-np.maximum(t - 0.7, 0.0) / 1.1)
    bells = np.zeros(int(d * SR))
    for k, n in enumerate([5, 6, 7, 8, 9, 10]):
        bells += at(glass_bell(note(n), 2.0, 0.55), 0.65 + k * 0.11, d) * (0.5 + 0.05 * k)
    rng = np.random.default_rng(131)
    for _ in range(20):
        f = rng.uniform(3500.0, 8000.0)
        bells += (
            at(modal(f, 0.2, [1.0], [1.0], [rng.uniform(0.02, 0.06)]), rng.uniform(1.0, 2.2), d)
            * 0.04
        )
    music = reverb(lp(mix((brass, 0.09), (bells, 1.0)), 11000.0), 1.8, 0.32, 7000.0, seed=137)
    n = len(music)
    fly = np.vstack([fly, np.zeros((max(0, n - len(fly)), 2))])[:n]
    x = fly * 0.45 + pan(music, 0.0) * np.sqrt(2.0)
    return finish_st(x, PEAK, fade_ms=200)


def star_ping() -> np.ndarray:
    """Win card: satellite ping as the star lands, a pure high ping with
    ring-mod sidebands and soft repeating echoes."""
    d = 0.35
    t = tt(d)
    f = note(7)
    ping = np.sin(2 * np.pi * f * t) * (1.0 + 0.25 * np.sin(2 * np.pi * f * 1.5 * t))
    ping = ping * env(d, 0.002, 0.07)
    tw = modal(note(10), d, [1.0], [1.0], [0.04])
    x = mix((ping, 0.8), (tw, 0.2))
    return finish(reverb(echo(x, 0.16, 0.4, 3, 4500.0), 0.6, 0.2, 9000.0, seed=143), PEAK, 80)


def pass_by(variant: int) -> np.ndarray:
    """Rare ambient spaceship pass-by during play (stereo, left to right)."""
    d = [4.5, 5.5][variant]
    f = [note(0, -2), note(3, -3)][variant]
    x = ship_pass(d, f, 181 + variant, [0.05, 0.06][variant], 0.9)
    x = np.stack([lp(x[:, 0], 2500.0), lp(x[:, 1], 2500.0)], axis=1)
    return finish_st(x, PEAK, fade_ms=300)


def build(kenney: Path) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for v in range(3):
        out[f"tap_{v + 1}"] = click(v)
        out[f"laser_{v + 1}"] = laser(v)
        out[f"grow_tick_{v + 1}"] = grow_tick(v)
        out[f"fizzle_{v + 1}"] = fizzle(v)
    for v in range(2):
        out[f"dir_{v + 1}"] = servo(v)
        out[f"seal_{v + 1}"] = seal(v)
        out[f"capture_s_{v + 1}"] = capture("s", v)
        out[f"pass_{v + 1}"] = pass_by(v)
    for v in range(4):
        out[f"sonar_{v + 1}"] = sonar(v)
    out["tick_in"] = tick_in()
    out["notyet"] = notyet()
    out["beam"] = beam()
    out["capture_m"] = capture("m")
    out["capture_l"] = capture("l")
    out["crack"] = crack(kenney)
    out["rewind"] = rewind()
    out["comms"] = comms()
    out["snegl"] = snegl()
    out["lyn"] = lyn()
    out["skjold"] = skjold()
    out["win"] = win()
    out["star_ping"] = star_ping()
    out["shimmer"] = shimmer()
    out["warp_in"] = warp_in()
    out["mirror"] = mirror()
    return out


def write_ogg(x: np.ndarray, path: Path, quality: str = "4") -> None:
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "x.wav"
        sf.write(str(wav), x.astype(np.float32), SR, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", str(x.ndim), "-ar", str(SR)]
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
    ap.add_argument("--only", nargs="*", default=None, help="render only these names")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, x in build(args.kenney).items():
        if args.only is not None and name not in args.only:
            continue
        write_ogg(x, args.out / f"of_{name}.ogg")
        st = " stereo" if x.ndim == 2 else ""
        print(f"of_{name}.ogg  {len(x) / SR:.2f} s{st}")


if __name__ == "__main__":
    main()
