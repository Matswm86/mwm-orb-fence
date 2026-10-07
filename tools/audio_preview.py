"""Listen-proxy: render docs/audio_preview.ogg and print loudness numbers.

Mixes every sound effect over 20 s of the owner's music at the game's DEFAULT volumes. The levels
are read from the GDScript sources (OfSfx.SOUNDS / BASE_DB / ZIP_DB, OfMusic.BASE_DB, the default
sliders in OfState), so this file never holds its own copy of a number. The music window is the
loudest 20 s of the whole mix (the owner says it gets intense), found from 400 ms RMS.

Usage:
    python3 tools/audio_preview.py [--out docs/audio_preview.ogg]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
WINDOW_S = 20.0

# (time s, sound name, pitch) - one short game: touch, wall, captures, pops, tokens, a rare
# ambient ship pass-by, clear. Lyn and Skjold are not in world 1 yet; they are here to be heard.
SCHEDULE = [
    (0.4, "intro", 1.0),
    (1.6, "tap", 1.0),
    (2.2, "tick_in", 1.0),
    (2.45, "ghost_tick", 1.0),
    (2.6, "ghost_tick", 1.0),
    (2.75, "dir_pick", 1.1225),
    (3.0, "wall_start", 1.0),
    (3.0, "ZIP", 1.0),
    (3.22, "grow_tick", 1.0),
    (3.43, "grow_tick", 1.12),
    (3.65, "grow_tick", 1.24),
    (3.95, "lock", 1.0),
    (4.0, "capture_m", 1.0),
    (4.5, "milestone", 1.0),
    (5.0, "pass_by", 1.0),
    (5.6, "tick_in", 1.0),
    (6.0, "wall_start", 1.0),
    (6.0, "ZIP", 1.0),
    (6.5, "pop", 1.0),
    (7.2, "notyet", 1.0),
    (8.0, "tap", 1.0),
    (8.6, "wall_start", 1.0),
    (8.6, "ZIP", 1.0),
    (9.6, "lock", 1.0),
    (9.65, "capture_l", 1.0),
    (10.1, "milestone", 1.1225),
    (10.2, "snegl", 1.0),
    (11.2, "lyn", 1.0),
    (11.5, "crack", 1.0),
    (12.0, "rewind", 1.0),
    (13.0, "skjold", 1.0),
    (13.6, "shimmer", 1.0),
    (14.4, "wall_start", 1.0),
    (14.4, "ZIP", 1.0),
    (15.3, "lock", 1.0),
    (15.35, "capture_s", 1.0),
    (15.8, "milestone", 1.2599),
    (16.3, "win", 1.0),
    (18.4, "star_land", 1.0),
]
BOUNCE_EVERY_S = 0.55
ZIP_LEN_S = 0.95


def _num(text: str, pattern: str) -> float:
    m = re.search(pattern, text)
    if not m:
        raise ValueError(f"not found: {pattern}")
    return float(m.group(1))


def read_levels() -> dict:
    sfx = (ROOT / "scripts/OfSfx.gd").read_text()
    mus = (ROOT / "scripts/OfMusic.gd").read_text()
    st = (ROOT / "scripts/OfState.gd").read_text()
    sounds = {}
    for m in re.finditer(r'"(\w+)": \[\[([^\]]*)\], ([-\d.]+), ([-\d.]+)\]', sfx):
        files = re.findall(r'"(\w+)"', m.group(2))
        sounds[m.group(1)] = (files, float(m.group(4)))
    return {
        "sounds": sounds,
        "sfx_base": _num(sfx, r"const BASE_DB: float = ([-\d.]+)"),
        "zip_db": _num(sfx, r"const ZIP_DB: float = ([-\d.]+)"),
        "music_base": _num(mus, r"const BASE_DB: float = ([-\d.]+)"),
        "sfx_slider": _num(st, r"var sfx_volume: float = ([\d.]+)"),
        "music_slider": _num(st, r"var music_volume: float = ([\d.]+)"),
    }


def decode(path: Path, start: float = 0.0, dur: float | None = None) -> np.ndarray:
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start)]
    if dur is not None:
        cmd += ["-t", str(dur)]
    cmd += ["-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-12))


def short_term_max(x: np.ndarray, win_s: float = 0.4) -> float:
    n = int(win_s * SR)
    if len(x) < n:
        return db(np.sqrt(np.mean(x**2)))
    c = np.cumsum(np.concatenate([[0.0], x**2]))
    return db(np.sqrt(np.max(c[n:] - c[:-n]) / n))


def lufs(x: np.ndarray) -> float:
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "x.wav"
        sf.write(str(wav), x.astype(np.float32), SR)
        out = subprocess.run(
            ["ffmpeg", "-nostats", "-i", str(wav), "-af", "ebur128", "-f", "null", "-"],
            capture_output=True,
            text=True,
        ).stderr
    m = re.findall(r"I:\s+([-\d.]+) LUFS", out)
    return float(m[-1]) if m else float("nan")


def loudest_window(path: Path) -> float:
    """Start time (s) of the loudest WINDOW_S of the music, from a fast low-rate pass."""
    low = 4000
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(low), "-f", "f32le", "-"],
        capture_output=True,
        check=True,
    ).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    n = int(WINDOW_S * low)
    c = np.cumsum(np.concatenate([[0.0], x**2]))
    e = c[n:] - c[:-n]
    return float(np.argmax(e[:: low // 4]) * 0.25)


def decode_sfx(path: Path) -> tuple[np.ndarray, float]:
    """An effect file as mono (stereo files: (L + R) / 2, which is how loud a
    centred sound plays next to a mono effect) plus its loudest-channel peak
    in dBFS. ffmpeg's own -ac 1 sums L + R, 6 dB too hot for centred sound."""
    ch = int(
        subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries"]
            + ["stream=channels", "-of", "csv=p=0", str(path)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    )
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ar", str(SR), "-f", "f32le", "-"],
        capture_output=True,
        check=True,
    ).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64).reshape(-1, ch)
    return x.mean(axis=1), db(float(np.max(np.abs(x))))


def resample_pitch(x: np.ndarray, pitch: float) -> np.ndarray:
    if abs(pitch - 1.0) < 1e-3:
        return x
    idx = np.arange(0, len(x) - 1, pitch)
    return np.interp(idx, np.arange(len(x)), x)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=ROOT / "docs" / "audio_preview.ogg")
    args = ap.parse_args()
    lv = read_levels()
    music_path = ROOT / "assets/music/orb_fence_theme.ogg"
    full = decode(music_path)
    start = loudest_window(music_path)
    seg = full[int(start * SR) : int((start + WINDOW_S) * SR)]
    music_gain_db = lv["music_base"] + db(lv["music_slider"])
    sfx_gain_db = lv["sfx_base"] + db(lv["sfx_slider"])
    music = seg * 10 ** (music_gain_db / 20.0)
    fx = np.zeros(len(music) + SR * 4)
    peaks: dict[str, float] = {}
    rng = np.random.default_rng(3)
    sched = list(SCHEDULE)
    t = 0.3
    while t < WINDOW_S - 0.5:
        sched.append((t, "bounce", 1.0))
        t += BOUNCE_EVERY_S
    for at_s, name, pitch in sched:
        if name == "ZIP":
            zf = re.search(r'const ZIP_FILE := "(\w+)"', (ROOT / "scripts/OfSfx.gd").read_text())
            x = decode(ROOT / "assets/sfx" / f"{zf.group(1)}.ogg")[: int(ZIP_LEN_S * SR)].copy()
            x[-int(0.08 * SR) :] *= np.linspace(1.0, 0.0, int(0.08 * SR))
            g = lv["zip_db"] + sfx_gain_db
            key = "zip (riser)"
        else:
            files, level = lv["sounds"][name]
            x, ch_peak = decode_sfx(ROOT / "assets/sfx" / f"{files[rng.integers(len(files))]}.ogg")
            x = resample_pitch(x, pitch)
            g = level + sfx_gain_db
            key = name
            # Stereo files (ship pass-bys): the mono mix hides a hard-panned
            # channel, so the peak also counts the loudest single channel.
            peaks[key] = max(peaks.get(key, -200.0), ch_peak + g)
        x = x * 10 ** (g / 20.0)
        i = int(at_s * SR)
        fx[i : i + len(x)] += x
        peaks[key] = max(peaks.get(key, -200.0), db(np.max(np.abs(x))))
    fx = fx[: len(music)]
    mix = music + fx
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "mix.wav"
        sf.write(str(wav), mix.astype(np.float32), SR, subtype="PCM_16")
        subprocess.run(
            [
                "ffmpeg",
                "-v",
                "error",
                "-y",
                "-i",
                str(wav),
                "-c:a",
                "libvorbis",
                "-q:a",
                "3",
                str(args.out),
            ],
            check=True,
        )
    raw_rms = db(np.sqrt(np.mean(full**2)))
    print(f"wrote {args.out.relative_to(ROOT)}")
    print(
        f"levels: music BASE_DB {lv['music_base']:+.1f} + slider {lv['music_slider']:.2f} "
        f"= {music_gain_db:+.1f} dB; effects BASE_DB {lv['sfx_base']:+.1f} + slider "
        f"{lv['sfx_slider']:.2f} = {sfx_gain_db:+.1f} dB (files peak -3 dBFS)"
    )
    print(f"music file (whole 66 min, mono sum): mean RMS {raw_rms:.1f} dBFS, LUFS n/a here")
    print(f"music window: loudest 20 s starts at {start / 60:.1f} min")
    print(
        f"music in game, loudest 20 s: mean RMS {db(np.sqrt(np.mean(music**2))):.1f} dBFS, "
        f"max 400 ms RMS {short_term_max(music):.1f} dBFS, peak {db(np.max(np.abs(music))):.1f} dBFS, "
        f"{lufs(music):.1f} LUFS"
    )
    print(f"music in game, whole mix at default: mean RMS {raw_rms + music_gain_db:.1f} dBFS")
    loud = max(peaks.values())
    print(
        f"effects: loudest peak {loud:.1f} dBFS ({max(peaks, key=peaks.get)}), "
        f"effects-only {lufs(fx):.1f} LUFS, max 400 ms RMS {short_term_max(fx):.1f} dBFS"
    )
    for k in sorted(peaks, key=peaks.get, reverse=True):
        print(f"   {k:12s} peak {peaks[k]:6.1f} dBFS")
    mpk = db(np.max(np.abs(music)))
    print(
        f"gap: loudest effect peak - music peak = {loud - mpk:.1f} dB; "
        f"- music max 400 ms RMS = {loud - short_term_max(music):.1f} dB; "
        f"- music mean RMS = {loud - db(np.sqrt(np.mean(music**2))):.1f} dB"
    )
    print(
        f"preview mix: peak {db(np.max(np.abs(mix))):.1f} dBFS, {lufs(mix):.1f} LUFS, "
        f"max 400 ms RMS {short_term_max(mix):.1f} dBFS"
    )


if __name__ == "__main__":
    main()
