"""Rough wall-success and clear-time sim for MWM Orb Fence world 1 (design aid, not game code).

Bot model of a child: after each wall ends it "thinks" for THINK_S, then picks one of
the top-N wall lines by captured gain, with a chance to ignore ball danger (kids do not
predict bounces) and a random origin inside the line's middle 60%.
Results are (my calc); real children will be slower.

Usage: python3 wall_sim.py [runs_per_level]
"""

import math
import random
import statistics
import sys

CELL = 72.0
COLS, ROWS = 14, 16
R = 24.0
DT = 1 / 60
SUBSTEP_PX = 8.0

# Level maps: 16 strings of 14 chars. '.' empty, '#' rock, 'S' Sakte token (empty cell).
EMPTY_MAP = ["." * 14 for _ in range(16)]


def with_marks(marks: dict) -> list:
    rows = [list(r) for r in EMPTY_MAP]
    for (c, r), ch in marks.items():
        rows[r][c] = ch
    return ["".join(r) for r in rows]


L4_ROCKS = {}
for c, r in [(3, 5), (4, 5), (9, 5), (10, 5), (3, 10), (4, 10), (9, 10), (10, 10)]:
    L4_ROCKS[(c, r)] = "#"

MAPS = {
    1: EMPTY_MAP,
    2: EMPTY_MAP,
    3: with_marks({(3, 3): "S", (10, 12): "S"}),
    4: with_marks(L4_ROCKS),
    5: EMPTY_MAP,
}

# setting -> per level (balls, ball_speed px/s, target fraction)
LEVELS = {
    "Lett": {
        1: (1, 200, 0.65),
        2: (2, 200, 0.65),
        3: (2, 200, 0.65),
        4: (2, 200, 0.65),
        5: (2, 200, 0.60),
    },
    "Vanlig": {
        1: (2, 320, 0.75),
        2: (3, 320, 0.75),
        3: (3, 320, 0.75),
        4: (3, 320, 0.75),
        5: (2, 320, 0.70),
    },
}
SETTING = {
    # wall cells/s per end; calm = ball speed factor while a wall grows (tested 0.5-1.0 with
    # --calm: pops fell only 1.9 -> 1.6 per run on Lett L2, so the game ships without it);
    # think time s; top-N choice; chance the bot checks ball danger; chance of a planless tap
    "Lett": dict(wall=14.0, calm=1.0, think=(2.0, 6.0), top=8, care=0.2, rand=0.4),
    "Vanlig": dict(wall=10.0, calm=1.0, think=(1.0, 3.0), top=4, care=0.6, rand=0.15),
}
SAKTE_FACTOR, SAKTE_S = 0.6, 8.0

EMPTY, SOLID, BUILD, CAPT = 0, 1, 2, 3


def run(setting: str, level: int, seed: int, calm_override=None, wall_override=None):
    rnd = random.Random(seed)
    cfg = SETTING[setting]
    nballs, speed, target = LEVELS[setting][level]
    calm = cfg["calm"] if calm_override is None else calm_override
    wall_speed = cfg["wall"] if wall_override is None else wall_override
    # padded grid with border ring
    W, H = COLS + 2, ROWS + 2
    g = [[SOLID] * H for _ in range(W)]
    tokens = set()
    for r, row in enumerate(MAPS[level]):
        for c, ch in enumerate(row):
            g[c + 1][r + 1] = SOLID if ch == "#" else EMPTY
            if ch == "S":
                tokens.add((c + 1, r + 1))
    playable = sum(1 for x in range(1, W - 1) for y in range(1, H - 1) if g[x][y] != SOLID)
    balls = []
    while len(balls) < nballs:
        cx, cy = rnd.randint(3, COLS - 2), rnd.randint(3, ROWS - 2)
        if g[cx][cy] != EMPTY:
            continue
        a = math.radians(rnd.uniform(35, 55))
        sx, sy = rnd.choice([-1, 1]), rnd.choice([-1, 1])
        balls.append([(cx + 0.5) * CELL, (cy + 0.5) * CELL, sx * math.cos(a), sy * math.sin(a)])

    def cells_of(x, y):
        x0, x1 = int((x - R) // CELL), int((x + R - 0.001) // CELL)
        y0, y1 = int((y - R) // CELL), int((y + R - 0.001) // CELL)
        return [(i, j) for i in range(x0, x1 + 1) for j in range(y0, y1 + 1)]

    def flood_regions(grid):
        seen = set()
        regions = []
        for x in range(1, W - 1):
            for y in range(1, H - 1):
                if grid[x][y] == EMPTY and (x, y) not in seen:
                    st, reg = [(x, y)], []
                    seen.add((x, y))
                    while st:
                        cx, cy = st.pop()
                        reg.append((cx, cy))
                        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                            if grid[nx][ny] == EMPTY and (nx, ny) not in seen:
                                seen.add((nx, ny))
                                st.append((nx, ny))
                    regions.append(reg)
        return regions

    def ball_cells():
        return {(int(b[0] // CELL), int(b[1] // CELL)) for b in balls}

    def segments():
        segs = []
        for x in range(1, W - 1):
            y = 1
            while y < H - 1:
                if g[x][y] == EMPTY:
                    s = y
                    while g[x][y] == EMPTY:
                        y += 1
                    segs.append([(x, k) for k in range(s, y)])
                y += 1
        for y in range(1, H - 1):
            x = 1
            while x < W - 1:
                if g[x][y] == EMPTY:
                    s = x
                    while g[x][y] == EMPTY:
                        x += 1
                    segs.append([(k, y) for k in range(s, x)])
                x += 1
        return [s for s in segs if len(s) >= 2]

    def predict_hits(seg, origin_idx):
        t_need = max(origin_idx, len(seg) - 1 - origin_idx) / wall_speed + 0.2
        segset = set(seg)
        for b in balls:
            x, y, dx, dy = b
            v = speed * calm
            t = 0.0
            while t < t_need:
                x += dx * v * 0.05
                y += dy * v * 0.05
                t += 0.05
                cs = cells_of(x, y)
                if any(c in segset for c in cs):
                    return True
                if any(g[c[0]][c[1]] in (SOLID, CAPT) for c in cs):
                    break  # stop predicting after first bounce
        return False

    def choose():
        bc = ball_cells()
        cands = []
        for seg in segments():
            g2 = [col[:] for col in g]
            for c in seg:
                g2[c[0]][c[1]] = SOLID
            gain, minor = 0, 0
            regs = flood_regions(g2)
            ballregs = []
            for reg in regs:
                if not any(c in bc for c in reg):
                    gain += len(reg)
                else:
                    ballregs.append(len(reg))
            if len(ballregs) >= 2:
                minor = min(ballregs)
            score = gain + 0.25 * minor + len(seg) * 0.05
            n = len(seg)
            lo, hi = int(n * 0.2), max(int(n * 0.2), int(math.ceil(n * 0.8)) - 1)
            oi = rnd.randint(lo, hi)
            if rnd.random() < cfg["care"] and predict_hits(seg, oi):
                score *= 0.2
            cands.append((score, seg, oi))
        cands.sort(key=lambda c: -c[0])
        if not cands:
            return None
        if rnd.random() < cfg["rand"]:
            return rnd.choice(cands)  # child taps somewhere without a plan
        top = cands[: cfg["top"]]
        wts = [max(0.01, c[0]) for c in top]
        return rnd.choices(top, weights=wts)[0]

    t = 1.0  # intro
    wall = None
    think = rnd.uniform(*cfg["think"])
    walls = pops = 0
    sakte_t = 0.0
    filled = 0
    while t < 900:
        t += DT
        # bot
        if wall is None:
            think -= DT
            if think <= 0:
                pick = choose()
                if pick is None:
                    break
                _, seg, oi = pick
                halves = [seg[: oi + 1][::-1], seg[oi:]]  # each starts at origin
                wall = {"h": [[h, 0.0, False, False] for h in halves], "cells": set()}
                walls += 1
                for h in wall["h"]:
                    h[1] = 1.0  # origin placed
                o = seg[oi]
                g[o[0]][o[1]] = BUILD
        # walls grow
        if wall is not None:
            for h in wall["h"]:
                cells, prog, done, popped = h
                if done or popped:
                    continue
                newp = prog + wall_speed * DT
                for i in range(int(prog), int(newp)):
                    if i >= len(cells):
                        h[2] = True
                        break
                    c = cells[i]
                    if g[c[0]][c[1]] != EMPTY:
                        h[2] = True
                        break
                    g[c[0]][c[1]] = BUILD
                if int(newp) >= len(cells):
                    h[2] = True
                h[1] = newp
            if all(h[2] or h[3] for h in wall["h"]):
                keep = set()
                for h in wall["h"]:
                    if h[2] and not h[3]:
                        keep.update(h[0][: int(min(h[1], len(h[0])))])
                for h in wall["h"]:
                    for c in h[0]:
                        if g[c[0]][c[1]] == BUILD:
                            g[c[0]][c[1]] = SOLID if c in keep else EMPTY
                if keep:
                    bc = ball_cells()
                    for reg in flood_regions(g):
                        if not any(c in bc for c in reg):
                            for c in reg:
                                g[c[0]][c[1]] = CAPT
                                if c in tokens:
                                    tokens.discard(c)
                                    sakte_t = SAKTE_S
                wall = None
                think = rnd.uniform(*cfg["think"])
                filled = sum(
                    1
                    for x in range(1, W - 1)
                    for y in range(1, H - 1)
                    if g[x][y] in (CAPT,) or (g[x][y] == SOLID and MAPS[level][y - 1][x - 1] != "#")
                )
                if filled / playable >= target:
                    return t, walls, pops
        # balls
        f = (calm if wall is not None else 1.0) * (SAKTE_FACTOR if sakte_t > 0 else 1.0)
        sakte_t = max(0.0, sakte_t - DT)
        v = speed * f
        steps = max(1, math.ceil(v * DT / SUBSTEP_PX))
        sdt = DT / steps
        for b in balls:
            for _ in range(steps):
                for ax in (0, 1):
                    b[ax] += b[2 + ax] * v * sdt
                    hit = False
                    for c in cells_of(b[0], b[1]):
                        st = g[c[0]][c[1]]
                        if st in (SOLID, CAPT):
                            hit = True
                        elif st == BUILD and wall is not None:
                            hit = True
                            for h in wall["h"]:
                                if c in h[0][: int(min(h[1], len(h[0])))] and not h[3]:
                                    if c == h[0][0]:  # origin: both halves pop
                                        for hh in wall["h"]:
                                            hh[3] = True
                                    else:
                                        h[3] = True
                                    pops += 1
                            for h in wall["h"]:
                                if h[3]:
                                    for cc in h[0][1:]:
                                        if g[cc[0]][cc[1]] == BUILD:
                                            g[cc[0]][cc[1]] = EMPTY
                            if all(h[3] for h in wall["h"]):
                                o = wall["h"][0][0][0]
                                g[o[0]][o[1]] = EMPTY
                    if hit:
                        b[ax] -= b[2 + ax] * v * sdt
                        b[2 + ax] = -b[2 + ax]
    return t, walls, pops


def summarise(setting, level, n, **kw):
    res = [run(setting, level, 1000 + s, **kw) for s in range(n)]
    ts = sorted(r[0] for r in res)
    walls = statistics.mean(r[1] for r in res)
    pops = statistics.mean(r[2] for r in res)
    return ts[len(ts) // 2], ts[int(0.9 * len(ts))], walls, pops


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    for setting in ("Lett", "Vanlig"):
        for lv in MAPS:
            med, p90, walls, pops = summarise(setting, lv, n)
            ok = 1 - pops / walls if walls else 0
            print(
                f"{setting:6} L{lv}: median {med:5.0f}s p90 {p90:5.0f}s walls {walls:4.1f} pops {pops:4.1f} (half-hits/run)"
            )
    if "--sparks" in sys.argv:
        # Vanlig spark budget check on later-world ball counts (map 2 = open field, target 75%)
        for balls, spd in [(3, 340), (4, 360), (5, 380), (6, 400), (8, 440)]:
            LEVELS["Vanlig"][2] = (balls, spd, 0.75)
            pops = sorted(run("Vanlig", 2, 2000 + s)[2] for s in range(n))
            for name, b in [
                ("balls+2", balls + 2),
                ("2*balls+1", 2 * balls + 1),
                ("3*balls", 3 * balls),
            ]:
                p = sum(1 for x in pops if x > b) / len(pops)
                print(
                    f"Vanlig {balls} balls {spd} px/s: budget {name}={b}: P(restart) {p:.0%}, pops median {pops[n // 2]}"
                )
    if "--calm" in sys.argv:
        for calm in (1.0, 0.8, 0.6, 0.5):
            med, p90, walls, pops = summarise("Lett", 2, n, calm_override=calm)
            print(
                f"Lett L2 calm {calm}: median {med:.0f}s p90 {p90:.0f}s walls {walls:.1f} pops {pops:.1f}"
            )


if __name__ == "__main__":
    main()
