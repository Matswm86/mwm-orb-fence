"""Difficulty-ramp sim for MWM Orb Fence levels 1-30 and endless (design aid, not game code).

Same child-bot model as wall_sim.py (think time, top-N pick, partial danger check,
planless taps), generalised to any grid, plus the rules wall_sim.py leaves out:
cage rule, Vanlig spark budget with a real gentle restart (field resets, 1.8 s),
and an optional within-level speed creep. Open field only (no stones, mirrors,
tokens, Stor or Kvikk). All results are (my calc); real children are slower.

Usage:
  python3 ramp_sim.py grid      # ball-count x layout sweep (where capture breaks)
  python3 ramp_sim.py dens      # same speed, 8-20 balls, A72 vs B56 vs C48
  python3 ramp_sim.py table     # the GDD 6.3 table, both settings
  python3 ramp_sim.py endless Vanlig|Lett [1,5,9 rounds] [raw = no caps]   # Uendelig rounds
  python3 ramp_sim.py creep     # within-level speed creep on vs off
  add  -n 60  for runs per point (default 40)
"""

import math
import random
import statistics
import sys
from multiprocessing import Pool

DT = 1 / 60
SUBSTEP_PX = 8.0
TIMEOUT_S = 600.0
RESTART_S = 1.8  # dim 0.6 + rewind 0.8 + lift 0.4

LAYOUTS = {
    # name: (cols, rows, cell px, ball radius px)
    "A72": (14, 16, 72.0, 24.0),
    "B56": (18, 20, 56.0, 22.0),
    "C48": (21, 24, 48.0, 20.0),
}
BOT = {
    "Lett": dict(wall=14.0, think=(2.0, 6.0), top=8, care=0.2, rand=0.4, cage=12),
    "Vanlig": dict(wall=10.0, think=(1.0, 3.0), top=4, care=0.6, rand=0.15, cage=8),
}

EMPTY, SOLID, BUILD, CAPT = 0, 1, 2, 3


def run(args):
    """One level attempt chain until clear or timeout.

    args: (setting, layout, balls, speed, target, budget, cage_on, creep, seed)
    creep: (rate per s, cap) multiplies speed by min(1 + rate * t_level, cap); None = off.
    budget 0 = unlimited sparks.
    Returns (time_s, cleared, walls, pops, restarts).
    """
    setting, layout, nballs, speed, target, budget, cage_on, creep, seed = args
    rnd = random.Random(seed)
    cfg = BOT[setting]
    cols, rows, cell, rad = LAYOUTS[layout]
    # walls keep the same px/s on every layout (72 px reference) and the cage keeps the
    # same area, so a finer grid changes only granularity, not the wall-vs-ball race
    wall_speed = cfg["wall"] * 72.0 / cell
    cage_max = round(cfg["cage"] * (72.0 / cell) ** 2) if cage_on else 0
    W, H = cols + 2, rows + 2
    playable = cols * rows

    def fresh():
        g = [[SOLID] * H for _ in range(W)]
        for x in range(1, W - 1):
            for y in range(1, H - 1):
                g[x][y] = EMPTY
        balls = []
        used = set()
        while len(balls) < nballs:
            cx = rnd.randint(3, cols - 2)
            cy = rnd.randint(3, rows - 2)
            if (cx, cy) in used and len(used) < (cols - 4) * (rows - 4):
                continue
            used.add((cx, cy))
            a = math.radians(rnd.uniform(35, 55))
            sx, sy = rnd.choice([-1, 1]), rnd.choice([-1, 1])
            balls.append([(cx + 0.5) * cell, (cy + 0.5) * cell, sx * math.cos(a), sy * math.sin(a)])
        return g, balls

    g, balls = fresh()

    def cells_of(x, y):
        x0, x1 = int((x - rad) // cell), int((x + rad - 0.001) // cell)
        y0, y1 = int((y - rad) // cell), int((y + rad - 0.001) // cell)
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
        return {(int(b[0] // cell), int(b[1] // cell)) for b in balls}

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

    def predict_hits(seg, oi, v):
        t_need = max(oi, len(seg) - 1 - oi) / wall_speed + 0.2
        segset = set(seg)
        for b in balls:
            x, y, dx, dy = b
            t = 0.0
            while t < t_need:
                x += dx * v * 0.05
                y += dy * v * 0.05
                t += 0.05
                cs = cells_of(x, y)
                if any(c in segset for c in cs):
                    return True
                if any(g[c[0]][c[1]] != EMPTY for c in cs):
                    break
        return False

    def choose(v):
        bc = ball_cells()
        cands = []
        for seg in segments():
            g2 = [col[:] for col in g]
            for c in seg:
                g2[c[0]][c[1]] = SOLID
            gain, ballregs = 0, []
            for reg in flood_regions(g2):
                nb = sum(1 for c in reg if c in bc)
                if nb == 0:
                    gain += len(reg)
                elif len(reg) <= cage_max:
                    gain += len(reg) + 4 * nb  # catching a ball is the child's goal
                else:
                    ballregs.append(len(reg))
            minor = min(ballregs) if len(ballregs) >= 2 else 0
            score = gain + 0.25 * minor + len(seg) * 0.05
            n = len(seg)
            lo, hi = int(n * 0.2), max(int(n * 0.2), int(math.ceil(n * 0.8)) - 1)
            oi = rnd.randint(lo, hi)
            if rnd.random() < cfg["care"] and predict_hits(seg, oi, v):
                score *= 0.2
            cands.append((score, seg, oi))
        if not cands:
            return None
        cands.sort(key=lambda c: -c[0])
        if rnd.random() < cfg["rand"]:
            return rnd.choice(cands)
        top = cands[: cfg["top"]]
        return rnd.choices(top, weights=[max(0.01, c[0]) for c in top])[0]

    t = 1.0
    t_level = 0.0  # time since the current attempt started (creep clock)
    wall = None
    think = rnd.uniform(*cfg["think"])
    walls = pops = restarts = 0
    pops_attempt = 0
    while t < TIMEOUT_S:
        t += DT
        t_level += DT
        f = 1.0
        if creep:
            f = min(1.0 + creep[0] * t_level, creep[1])
        v = speed * f
        if wall is None:
            think -= DT
            if think <= 0:
                pick = choose(v)
                if pick is None:
                    break
                _, seg, oi = pick
                halves = [seg[: oi + 1][::-1], seg[oi:]]
                wall = {"h": [[h, 1.0, False, False] for h in halves]}
                walls += 1
                o = seg[oi]
                g[o[0]][o[1]] = BUILD
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
                    bc = {}
                    for i, b in enumerate(balls):
                        bc.setdefault((int(b[0] // cell), int(b[1] // cell)), []).append(i)
                    caged = set()
                    for reg in flood_regions(g):
                        inside = [i for c in reg for i in bc.get(c, [])]
                        if not inside or len(reg) <= cage_max:
                            for c in reg:
                                g[c[0]][c[1]] = CAPT
                            caged.update(inside)
                    if caged:
                        balls = [b for i, b in enumerate(balls) if i not in caged]
                wall = None
                think = rnd.uniform(*cfg["think"])
                filled = sum(
                    1 for x in range(1, W - 1) for y in range(1, H - 1) if g[x][y] != EMPTY
                )
                if filled / playable >= target:
                    return t, True, walls, pops, restarts
        steps = max(1, math.ceil(v * DT / SUBSTEP_PX))
        sdt = DT / steps
        restart_now = False
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
                                if not h[3] and c in h[0][: int(min(h[1], len(h[0])))]:
                                    if c == h[0][0]:
                                        for hh in wall["h"]:
                                            hh[3] = True
                                    else:
                                        h[3] = True
                                    pops += 1
                                    pops_attempt += 1
                                    if budget and pops_attempt > budget:
                                        restart_now = True
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
        if restart_now:
            restarts += 1
            g, balls = fresh()
            wall = None
            pops_attempt = 0
            t += RESTART_S
            t_level = 0.0
            think = rnd.uniform(*cfg["think"])
    return t, False, walls, pops, restarts


def batch(pool, cfgs, n):
    """cfgs: list of arg tuples without seed. Returns list of summary dicts."""
    jobs = [c + (5000 + s,) for c in cfgs for s in range(n)]
    res = pool.map(run, jobs, chunksize=1)
    out = []
    for i, c in enumerate(cfgs):
        rs = res[i * n : (i + 1) * n]
        ts = sorted(r[0] for r in rs)
        out.append(
            dict(
                cfg=c,
                med=ts[n // 2],
                p90=ts[int(0.9 * n)],
                clear=sum(r[1] for r in rs) / n,
                pops=statistics.mean(r[3] for r in rs),
                rst=sum(1 for r in rs if r[4] > 0) / n,
                rst_mean=statistics.mean(r[4] for r in rs),
            )
        )
    return out


def fmt(d):
    s, lay, b, v, tg, bud, cage, creep = d["cfg"]
    cps = v / LAYOUTS[lay][2]
    cr = f" creep {creep[0] * 100:.1f}%/s cap x{creep[1]}" if creep else ""
    return (
        f"{s:6} {lay} {b:2d} balls {v:3.0f} px/s ({cps:4.1f} c/s) tgt {tg:.0%} budget {bud:2d}{cr}: "
        f"median {d['med']:5.0f}s p90 {d['p90']:5.0f}s clear {d['clear']:4.0%} "
        f"pops {d['pops']:5.1f} restart>=1 {d['rst']:4.0%} (mean {d['rst_mean']:.1f})"
    )


# 30-level ramp (GDD 6.3), built from per-world rules:
#   Lett   balls per world  W1 1,2,2,2,2  then (n, n, n+1, n+1, n+1), n = 2..6
#   Vanlig balls per world  W1 2,3,3,4,4  then (n, n, n+1, n+1, n+1), n = 5,7,9,11,13
#   ball count never drops: the breather (L5) keeps L4's count and eases speed,
#   sparks and target instead
#   speed = world base + step * (level-in-world - 1) for L1-L4, breather (L5) = world base
#   field per world (one map per level for both settings): W1-3 A72 (14x16),
#   W4-6 C48 (21x24, same 1008x1152 px rect); targets 65 / 75, breathers 60 / 70
LETT_BASE = [200, 210, 220, 230, 240, 250]
VANLIG_BASE = [320, 340, 360, 380, 400, 420]
LETT_STEP = [0, 5, 5, 5, 5, 5]
VANLIG_STEP = [0, 10, 10, 10, 10, 10]
WORLD_LAYOUT = ["A72", "A72", "A72", "C48", "C48", "C48"]


def table():
    rows = {}
    for w in range(6):
        if w == 0:
            lb, vb = [1, 2, 2, 2, 2], [2, 3, 3, 4, 4]
        else:
            n_l, n_v = w + 1, 2 * w + 3
            lb = [n_l, n_l, n_l + 1, n_l + 1, n_l + 1]
            vb = [n_v, n_v, n_v + 1, n_v + 1, n_v + 1]
        for i in range(5):
            lv = w * 5 + i + 1
            br = i == 4
            ls = LETT_BASE[w] + (0 if br else LETT_STEP[w] * i)
            vs = VANLIG_BASE[w] + (0 if br else VANLIG_STEP[w] * i)
            budget = 0 if (w == 0 or br) else 3 * vb[i]
            rows[lv] = dict(
                layout=WORLD_LAYOUT[w],
                lb=lb[i],
                ls=ls,
                lt=0.60 if br else 0.65,
                vb=vb[i],
                vs=vs,
                vt=0.70 if br else 0.75,
                budget=budget,
                cage=lv >= 6,
            )
    return rows


# Uendelig (endless, GDD 6.5): round k (1-based) adds one ball and one speed step.
#   Vanlig: balls k + 1, speed 320 + 10 (k - 1); Lett: balls k, speed 200 + 5 (k - 1)
#   field: A72 while balls <= 8, C48 from 9 balls; caps below (plateau, no game over).
#   Vanlig cap 13 balls / 430 px/s (round 12): 14 balls / 440 px/s restarts 50% of
#   rounds and the plateau is replayed every round after the cap (my calc).
ENDLESS = {
    "Vanlig": dict(b0=2, v0=320, dv=10, bcap=13, vcap=430, tgt=0.75),
    "Lett": dict(b0=1, v0=200, dv=5, bcap=10, vcap=245, tgt=0.65),
}
FIELD_SWITCH_BALLS = 9


def endless_cfg(setting, k):
    e = ENDLESS[setting]
    b = min(e["b0"] + k - 1, e["bcap"])
    v = min(e["v0"] + e["dv"] * (k - 1), e["vcap"])
    lay = "A72" if b < FIELD_SWITCH_BALLS else "C48"
    budget = 3 * b if setting == "Vanlig" else 0
    return (setting, lay, b, v, e["tgt"], budget, True, None)


def main():
    n = 40
    if "-n" in sys.argv:
        n = int(sys.argv[sys.argv.index("-n") + 1])
    mode = sys.argv[1] if len(sys.argv) > 1 else "grid"
    with Pool(11) as pool:
        if mode == "grid":
            cfgs = []
            for lay, spd_l, spd_v in (("A72", 220, 400), ("B56", 200, 360), ("C48", 180, 320)):
                for b in (3, 4, 5, 6, 7):
                    cfgs.append(("Lett", lay, b, spd_l, 0.65, 0, True, None))
                for b in (4, 6, 8, 10, 12, 14):
                    cfgs.append(("Vanlig", lay, b, spd_v, 0.75, 3 * b, True, None))
            for d in batch(pool, cfgs, n):
                print(fmt(d), flush=True)
        elif mode == "dens":
            cfgs = []
            for b in (8, 12, 16, 20):
                for lay in ("A72", "B56", "C48"):
                    cfgs.append(("Vanlig", lay, b, 400, 0.75, 3 * b, True, None))
            for b in (4, 6, 8):
                for lay in ("A72", "C48"):
                    cfgs.append(("Lett", lay, b, 240, 0.65, 0, True, None))
            for d in batch(pool, cfgs, n):
                print(fmt(d), flush=True)
        elif mode == "table":
            rows = table()
            cfgs = []
            for lv, r in rows.items():
                cfgs.append(("Lett", r["layout"], r["lb"], r["ls"], r["lt"], 0, r["cage"], None))
                cfgs.append(
                    ("Vanlig", r["layout"], r["vb"], r["vs"], r["vt"], r["budget"], r["cage"], None)
                )
            for i, d in enumerate(batch(pool, cfgs, n)):
                print(f"L{i // 2 + 1:2d} " + fmt(d), flush=True)
        elif mode == "endless":
            # python3 ramp_sim.py endless [Vanlig|Lett] [1,2,3 rounds]; uncapped with "raw"
            setting = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] in ENDLESS else "Vanlig"
            ks = range(1, 21)
            for a in sys.argv[2:]:
                if a[0].isdigit() and "," in a:
                    ks = [int(x) for x in a.split(",")]
            if "raw" in sys.argv:
                for e in ENDLESS.values():
                    e["bcap"], e["vcap"] = 99, 9999
            cfgs = [endless_cfg(setting, k) for k in ks]
            for k, d in zip(ks, batch(pool, cfgs, n)):
                print(f"R{k:2d} " + fmt(d), flush=True)
        elif mode == "creep":
            cases = [
                ("Lett", "B56", 4, 230, 0.65, 0, True),
                ("Vanlig", "A72", 6, 380, 0.75, 18, True),
                ("Vanlig", "B56", 10, 440, 0.75, 30, True),
                ("Vanlig", "C48", 12, 470, 0.75, 36, True),
            ]
            cfgs = []
            for c in cases:
                for cr in (None, (0.005, 1.3), (0.01, 1.5)):
                    cfgs.append(c + (cr,))
            for d in batch(pool, cfgs, n):
                print(fmt(d), flush=True)
        elif mode == "w6":
            cfgs = [
                ("Vanlig", "C48", b, v, 0.75, 3 * b, True, None)
                for b, v in (
                    (13, 460),
                    (13, 480),
                    (13, 490),
                    (14, 460),
                    (14, 470),
                    (12, 490),
                    (12, 500),
                )
            ]
            for d in batch(pool, cfgs, n):
                print(fmt(d), flush=True)
        elif mode == "custom":
            # python3 ramp_sim.py custom Setting Layout balls speed target budget [cage 0/1]
            a = sys.argv[2:]
            cfg = (a[0], a[1], int(a[2]), float(a[3]), float(a[4]), int(a[5]), a[6] != "0", None)
            print(fmt(batch(pool, [cfg], n)[0]))


if __name__ == "__main__":
    main()
