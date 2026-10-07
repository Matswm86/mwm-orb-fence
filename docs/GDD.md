# MWM Orb Fence: game design doc

Version 2, 2026-10-07, game-designer (v1 2026-10-06; v2 adds the owner's 2026-10-07 decisions: the 30-level ramp, the 21 x 24 field, Uendelig and the space sound set). Store-safe wall-building game for the MWM Play family app (ages 4-7 and 8+, one-time unlock, no ads, offline). The owner chose the name **MWM Orb Fence** on 2026-10-05.

Target: Android, portrait 1080x1920, Godot 4.6. Stand-alone app first, then a game inside MWM Play. Visuals and renderer tier belong to graphic-designer (`docs/DESIGN.md`); this doc only lists game-feel hooks. Background music is an owner-supplied synthwave/cyberpunk mix played low (owner).

Legend: **(owner)** = decided by the owner, do not reopen. **(rule N)** = numbered rule in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. **(my calc)** = my own simulation or arithmetic, not a source. **(my call)** = a design choice I made; change it freely. **(guess)** = a target the builder and owner verify.

**What carries over from our own `projects/jezzball/scripts/Game.gd`** (our GDScript, not Microsoft's): the cell grid, walls growing from one cell in two directions until each end meets something solid, flood-fill capture of every region with no ball in it, per-axis ball reflection off solid cells, and "completed walls + captured cells" as the fill measure. **What does not carry over:** the old name and anything containing "Jezz", the Windows 3.x grey/red look, "atoms", "LIVES", "LEVEL CLEARED" and every other English HUD string, lives that scale with the level, the press-and-swipe direction input, and the rule that a ball touching a growing wall erases the whole wall and costs a life.

---

## 1. Pitch

Draw glowing walls across a neon room to fence in the bouncing balls, and every room you close lights up a piece of a hidden space picture; a ball that bumps a wall only pops it like a soap bubble, so a small child never loses.

## 2. Core loop

**Pick** (direction: up-down or side-side) -> **place** (press in the field, see the line, let go) -> **grow** (the wall races to both edges) -> **capture** (rooms without balls fill and reveal the picture) -> **clear** (fill meter reaches the star line, win card) -> next level or stop.

No score, no timer, no currency, no lives counter in Lett. One star per cleared level, always earned by clearing (rule 30). The win card is the natural stopping point for the play limit (owner).

## 3. Controls

One thumb, portrait, tap and drag only (rules 9-11). No swipe, long press, double tap or tilt in gameplay.

### 3.1 The input decision

The current jezzball build sets wall direction by swiping between press and release (25 px), and a plain tap silently reuses the last direction. **That does not suit a 4-year-old** (my call, reasoning from rules 9, 12, 15, 16):
- One gesture carries two decisions (where and which way), and the direction is invisible until the finger moves.
- A small wobble of a child's finger (over 25 px) flips the direction by accident; a careful tap reuses a direction the child cannot see.
- Swipes are not allowed in our games (DESIGN.md shared rules).

**Kid-safe input (both Lett and Vanlig, one scheme to learn):**
1. **Two big direction buttons** under the field: "up-down" and "side-side". Picking is a plain tap. The chosen button is raised, larger and ringed; the other is flat (shape and size, not only colour, rule 36). It is a choice between two pictures, not a toggle whose icon might mean "now" or "next".
2. **Press-see-release in the field.** Touch-down in the field shows a **ghost wall** at once: a dotted line through the cell under the finger, in the chosen direction, running exactly as far as the real wall would go. The finger can slide to move the ghost (it snaps cell by cell). **Letting go starts the wall** (act on release, rule 15). Sliding off the field and letting go cancels with no penalty.

Precision demand is low: any line roughly in the right place works, and the ghost shows the result before the child commits. Cells are 72 px (4.6 mm), below the 12.7 mm target floor, but the field is not a set of targets: the whole field is one 1008 x 1152 px drag surface and the child adjusts by sliding (rule 12).

### 3.2 Zones (logic px at 1080x1920)

| Zone | Rect | What happens |
|---|---|---|
| Shell home square | x 0-232, y 0-232 | Nothing of the game is drawn or tappable here. The stand-alone build draws its own home disc in the same place and size as the shell's (rule 20); hidden when `Engine.get_meta(&"mwm_play_shell")` is set. |
| HUD strip | x 256-1044, y 40-224 | Fill meter (and the Vanlig spark bar). Not tappable. |
| Field | x 36-1044, y 256-1408 | 14 columns x 16 rows of 72 px cells. Touch-down here = ghost wall. |
| Direction buttons | Discs 216 px drawn, centres (330, 1540) and (750, 1540); hit areas 240 x 240 (x 210-450 and 630-870, y 1420-1660) | Tap to choose direction. |
| Wrist strip | y >= 1664 | Touches that START here are ignored (rule 6). Decorative only. |

Gap between field bottom (1408) and button hit areas (1420): 12 px dead zone (my call).

Taller screens (20:9, canvas about 1080x2400): field and button row are anchored to the bottom (button row bottom = screen height - 260), HUD stays at the top, extra height sits between HUD and field as sky. Tablets about 1200 wide: the 1008 px field stays centred, side margins grow. Camera cutout: push the home disc below `DisplayServer.get_display_safe_area()` but keep its hit area running to the screen edge (copy the ball-connect fix).

### 3.3 Inputs

| Input | Where | Effect |
|---|---|---|
| Touch down | Field | Becomes the active field pointer (latest touch wins, rule 14). Ghost wall appears the same frame with a soft "tick-in" (rule 19). Ghost cell = cell under the finger; if that cell is not empty, the nearest empty cell within 1 cell; if none, no ghost and a muted "tuk". |
| Drag | Active field pointer | Ghost follows the finger. It moves to a new cell only when the finger is 0.6 cell into it (hysteresis, so a shaky finger does not make the ghost jitter). |
| Release | Inside field, ghost shown, no wall growing | Wall starts at the ghost cell. |
| Release | Inside field, a wall is still growing | No new wall (max 1 growing wall, my call). The ghost shrinks into its origin dot over 150 ms with a soft "not yet" blip. Walls finish in at most 1.1 s in Lett and 1.5 s in Vanlig (my calc: 15 cells / 14 or 10 cells/s), so the wait is short. |
| Release | Outside field | Cancel. Ghost fades over 120 ms, no sound. |
| Tap | Direction button | Touch-down: button presses to 94% + soft "click". Release inside its hit area: that direction is chosen; if a ghost is showing (other finger in the field), it turns at once. This allows two-person play (section 13). |
| Tap home disc / Android back | Top-left | Stand-alone: copies the shell guard (first tap: ring fills over 2.0 s, game keeps running; second tap between 0.3 s and 2.0 s leaves to the world map). In the shell the shell owns this. |
| App sent to background | | Pause. On return, a 240 px "play" disc in the centre resumes on release. |

Holdover filter: ignore all touches for 300 ms after any screen change (rule 8). Default direction at every level start: up-down (my call).

## 4. Rules and physics (logic px; render may be 2D or 3D, logic is a flat grid)

### 4.1 Grid

- Field origin (36, 256), cell 72 px, 14 x 16 cells = 224 cells in worlds 1-3; worlds 4-6 and big Uendelig rounds use 21 x 24 cells of 48 px in the same rect (6.4b). A ring of border cells sits outside (drawn as the frame, not counted).
- Cell states: `EMPTY`, `ROCK` (level data, never counted), `MIRROR` (level data, never counted), `BUILDING`, `WALL`, `CAPTURED`, `CAGED`.
- **Fill** = (WALL + CAPTURED + CAGED cells) / (all cells that are not ROCK or MIRROR). The level is clear the moment fill >= the level's target.

### 4.2 Balls

- Radius 24 (Stor 34, Kvikk 18). Constant speed per ball.
- Spawn: random empty cell in columns 2-11, rows 2-13, not on a token, never two balls in one cell. Direction: random angle 35-55 degrees from horizontal, random signs. Per-axis reflection keeps the angle in that band for the whole level, so a ball never travels flat or straight up (no anti-stuck rules needed beyond 4.6).
- Movement: sub-steps of at most 8 px. Per step move X, test the ball's bounding box against cells, reflect X on contact; then the same for Y (our `Game.gd` method, made swept).
- Solid to balls: border, ROCK, WALL, CAPTURED, CAGED and **BUILDING** (see 4.4).
- Balls do not collide with each other; they pass over each other (my call, as in our `Game.gd`).

### 4.3 Walls

- A wall starts as one BUILDING cell (the origin) and grows two halves in opposite directions at `WALL_SPEED` cells/s per half (Lett 14, Vanlig 10). A half stops when its next cell is not EMPTY.
- When both halves have stopped (or popped), every BUILDING cell of a non-popped half becomes WALL. Then capture runs: flood-fill every EMPTY region; a region with no ball centre in it becomes CAPTURED. Then the cage rule runs (4.5, from level 6).
- A half that completes stays even if the other half popped (it can still close a room).
- Max 1 growing wall at a time (my call; our `Game.gd` allows many, which multiplies pops for small children).

### 4.4 Ball hits a growing wall: the gentle mechanic (the wall-hit decision)

- **The ball bounces off the growing wall** like any wall (my call; in our `Game.gd` it passes into it). The child sees cause and effect: the ball bumps, the line breaks.
- **Only the touched half pops.** Its BUILDING cells turn back to EMPTY in a soap-bubble burst (0.25 s, cells non-solid at once). The other half keeps growing and becomes a real wall if it completes. Touching the origin cell pops both halves.
- **A wall growing into a ball** counts as the ball touching it (same pop).
- **Lett: a pop costs nothing, ever.** No lives, no counter, no restart. After 2 pops within 10 s, the hint glow shows a safer line (section 8.3).
- **Vanlig: a pop costs one spark.** Spark budget per level = 3 x ball count (owner 2026-10-07; the old max of 24 is dropped, so L28-30 get 42). World 1 and every breather level have unlimited sparks; Uendelig refills 3 x balls every round (6.5). When the bar is empty, the next pop starts a **gentle restart**: the screen dims to 60% over 0.6 s, walls and fill slide back out over 0.8 s, the bar refills, balls respawn, dim lifts over 0.4 s. No text, no "game over", no failure sound (a soft rewind whoosh). Under 2 s total.
- Rule 31 (no game over for 4-7) holds in both settings: there is no game over screen at all.

Why not slow the balls while a wall grows ("calm time") in Lett: I simulated it. Ball speed x0.5 to x1.0 during growth changed pops on Lett level 2 only from 1.9 to 1.6 per level and did not change clear time (my calc, `tools/wall_sim.py --calm`). Lett already has slow balls (200 px/s = 2.8 cells/s) and fast walls (14 cells/s), so it is cut.

### 4.5 Cage ("Bur", from level 6)

After capture, any region that still holds balls and has at most `CAGE_CELLS` cells (Lett 12, Vanlig 8) becomes CAGED: its cells count toward fill, its balls stop, shrink to 70% and sit still behind a bar pattern. Caged balls never move or pop walls again. This turns "trap the ball" into a real reward for a tight fence (my call; the classic genre has no such rule).

### 4.6 Safety

If a ball's bounding box overlaps a solid cell for 2 frames in a row, or its position is NaN, move it to the centre of the nearest EMPTY cell in its own region, keeping its velocity. No sound.

### 4.7 Spark budget evidence (my calc)

`tools/wall_sim.py --sparks`, Vanlig, open field, target 75%, a careless bot (it checks ball danger 60% of the time and only until a ball's first bounce, so these are pessimistic):

| Balls, speed | Pops per level (median) | Restart chance at budget balls+2 | 2 x balls + 1 | **3 x balls** |
|---|---|---|---|---|
| 3, 340 px/s | 4 | 33% | 20% | **8%** |
| 4, 360 | 6 | 37% | 18% | **5%** |
| 5, 380 | 9 | 58% | 32% | **17%** |
| 6, 400 | 13 | 78% | 47% | **20%** |
| 8, 440 | 20 | 93% | 57% | **28%** |

A flat 3 like Neon Bricks' net would restart most Vanlig attempts, and our old `max(3, level + 2)` lives formula is the "balls + 2" column. 3 x balls keeps restarts rare in worlds 2-3 and occasional in 5-6. The owner chose 3 x balls on 2026-10-07; the restart chances for the final ball counts are in 6.3 (`tools/ramp_sim.py`, which simulates the real restart).

## 5. Elements

Every element has a shape cue, so colour is never the only cue (rule 36). Colour notes are hints for graphic-designer.

### 5.1 Field and ball elements

| Code | Name (NO / EN) | Shape cue | Behaviour | First level |
|---|---|---|---|---|
| `.` | Tomt / Empty | Faint grid dot per cell | Free space. Captured cells reveal the level picture. | 1 |
| `#` | Stein / Stone | Solid block with chamfered corners | Solid to balls, stops walls, not counted in fill. Shapes the field. | 4 |
| `/` `\` | Speil / Mirror | Stone with a bright diagonal face in that direction | Solid, not counted. A ball touching it turns 90 degrees: `/` maps (vx, vy) to (-vy, -vx), `\` maps to (vy, vx); 0.2 s per-ball cooldown. Walls stop at it. | 21 |
| (ball) | Ball | Round, glossy, a small ring around it | Speed per level table. | 1 |
| (ball) | Stor / Big | Larger (radius 34), a double ring | Speed x0.8. Easier to see, harder to fit through gaps. | 8 |
| (ball) | Kvikk / Quick | Smaller (radius 18), a short motion tail | Speed x1.3 (Lett x1.15). | 16 |

### 5.2 Power-up tokens (our own twist: you get them by capturing them)

A token floats in one empty cell (drawn 60 px, slow 0.5 rev/s spin). Balls pass over it. **It activates when its cell becomes CAPTURED, CAGED or part of a completed WALL**, so it uses the core verb and adds no new input (my call). Max 2 tokens per level, except L29 with 3 (one of each, table 6.3). Same token again = timer refresh, not stack.

| Name (NO / EN) | Icon | Effect | Twist | First level |
|---|---|---|---|---|
| **Snegl / Snail** (vertical slice) | Snail shell spiral | All balls x0.6 speed for 8 s (Lett 10 s). | Each ball grows a small snail-shell swirl; the swirl unwinds as time runs out, a countdown with no digits. Music and effects pitch down slightly, wind back up over 0.5 s. | 3 |
| Lyn / Bolt | Zigzag bolt | The next 2 walls grow 2.5x faster. | The direction buttons get a bolt notch per charge left (2, then 1): count by shape. | 11 |
| Skjold / Shield | Hexagon | The next wall cannot pop; balls just bounce off it. | The ghost wall is drawn with a hex pattern while the shield waits. | 26 |

### 5.3 Picture reveal

Each level has a hidden neon picture (graphic-designer: planets, moons, rockets, comets, etc.; subjects per level in DESIGN.md). CAPTURED and CAGED cells show the picture under a soft glass tint. On clear, the rest of the picture fades in, and the win card shows it whole. This is the reward that makes going past the target feel good without a score.

## 6. Progression

### 6.1 Rules

- 6 worlds x 5 levels = 30 hand-made levels, plus the endless mode **Uendelig** (6.5, owner 2026-10-07).
- Every world: **L1** one new element, **L2** practise it, **L3** one new token or rule, **L4** combine, **L5** breather (same ball count as L4, world base speed, lower target, Vanlig sparks unlimited, a picture-first level).
- **Difficulty ramp (owner 2026-10-07):** more balls as the levels get harder, JezzBall-style, and faster balls world by world; Lett climbs slower than Vanlig. The ball count never goes down from one level to the next (breathers ease speed, target and sparks instead, my call). Exact rules in 6.3.
- No sequential lock (same as Neon Bricks): any level can be picked from the map; the lowest uncleared level pulses at 1 Hz as the suggestion; nothing is ever shown locked.
- **Free part (owner):** the game holds `full_unlock: bool`, default `true`. The MWM Play adapter sets it on `enter()` through a public hook `set_full_unlock(on: bool)`.
  - `full_unlock == false`: the map shows only world 1 levels 1-3. Level discs 4-5 and world arrows are not drawn at all. Clearing level 3 shows the normal win card with replay + home only (no "next") and emits `free_levels_finished`; the shell then shows its "Du har spilt alle banene her" card.
  - `full_unlock == true`: all 30 levels. The stand-alone build never calls the hook, so it is fully open.

### 6.2 Worlds

Names and settings follow DESIGN.md 2c (deep space, owner's pick 2026-10-06); backdrops and picture subjects are graphic-designer's.

| World | Name (NO / EN) | Setting (DESIGN.md 2c) | Field | New element (L1) | New token or rule (L3) |
|---|---|---|---|---|---|
| 1 | Månebanen / Moon Orbit | Ocean home planet, grey moon | 14 x 16 | Walls, turning (L2), Stone (L4) | Snegl |
| 2 | Ringplaneten / Ringed Planet | Ringed giant, ring plane behind the field | 14 x 16 | Cage rule (L6), Stor ball (L8) | (L6 is the rule) |
| 3 | Stormkjempen / Storm Giant | Banded gas giant, storm eye | 14 x 16 | Lyn (L11), L-shaped field (L13) | Lyn |
| 4 | Kometveien / Comet Road | Asteroid belt, slow comets | **21 x 24** | Kvikk ball (L16), plus-shaped field (L18) | (field shape) |
| 5 | Isspeilet / Ice Mirror | Frozen moon, aurora | 21 x 24 | Mirror (L21), ice islands (L23) | (islands) |
| 6 | Galaksehjertet / Galaxy Heart | Spiral galaxy, gold core | 21 x 24 | Skjold (L26) | Skjold |

The finer field from world 4 is section 6.4b.

### 6.3 Level table (difficulty ramp, owner 2026-10-07)

**Ramp rules** (the table is these rules written out; `tools/ramp_sim.py`, `table()`):

| | Lett (4-7) | Vanlig (8+) |
|---|---|---|
| Balls, world 1 | 1, 2, 2, 2, 2 | 2, 3, 3, 4, 4 |
| Balls, world w = 2..6 (L1, L2, L3, L4, L5) | n, n, n+1, n+1, n+1 with n = w | n, n, n+1, n+1, n+1 with n = 2w + 1 |
| Balls, range | 1 -> 7 (+1 about every 4 levels) | 2 -> 14 (+1 about every 2 levels) |
| World base speed, px/s (W1..W6) | 200, 210, 220, 230, 240, 250 | 320, 340, 360, 380, 400, 420 |
| Speed inside a world | base + 5 per level L1-L4 (W1 flat); L5 = base | base + 10 per level L1-L4 (W1 flat); L5 = base |
| Speed, range | 200 -> 265 px/s (+33%) | 320 -> 450 px/s (+41%) |
| Target | 65%, breathers 60% | 75%, breathers 70% |
| Sparks | none (pops are free) | 3 x balls (owner); world 1 and breathers unlimited |
| Field | 14 x 16 (72 px) in W1-3, 21 x 24 (48 px) in W4-6, same 1008 x 1152 px rect (6.4b) | same |

Ball counts: total (special balls in brackets: S = Stor, K = Kvikk; specials count inside the total). Speed in px/s (the special ball's own multiplier applies on top). Target = fill %. Sparks: Vanlig budget (inf = unlimited). Sim columns: median clear time of the child bot, and for Vanlig the share of attempts with at least one gentle restart; every one of the 60 rows cleared in 60 of 60 runs (my calc, run below).

| # | W | Name | New / focus | Field and map | Tokens | Lett balls / speed / target | Vanlig balls / speed / target | Vanlig sparks | Sim Lett median | Sim Vanlig median / restart |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Første strek | Place a wall | 14x16 open | | 1 / 200 / 65% | 2 / 320 / 75% | inf | 11 s | 16 s / 0 |
| 2 | 1 | Snu veggen | Turn the wall (buttons) | 14x16 open | | 2 / 200 / 65% | 3 / 320 / 75% | inf | 24 s | 20 s / 0 |
| 3 | 1 | Sneglen | Snegl token | 14x16 open | 2 Snegl | 2 / 200 / 65% | 3 / 320 / 75% | inf | 24 s | 20 s / 0 |
| 4 | 1 | Steinene | Stone | 14x16, 8 stones (6.4) | | 2 / 200 / 65% | **4** / 320 / 75% | inf | 24 s | 25 s / 0 |
| 5 | 1 | Soloppgang | Breather (sunrise picture) | 14x16 open | | 2 / 200 / 60% | **4** / 320 / 70% | inf | 23 s | 20 s / 0 |
| 6 | 2 | Buret | Cage rule | 14x16, 4 corner stones (cage pockets) | | 2 / 210 / 65% | 5 / 340 / 75% | 15 | 26 s | 29 s / 5% |
| 7 | 2 | Tre i buret | Cage practise | 14x16 open | 1 Snegl | 2 / 215 / 65% | 5 / 350 / 75% | 15 | 23 s | 32 s / 5% |
| 8 | 2 | Kjempen | Stor ball | 14x16 open | | 3 (1 S) / 220 / 65% | 6 (1 S) / 360 / 75% | 18 | 33 s | 43 s / 12% |
| 9 | 2 | Kjempene | Stor + cage + stones | 14x16, 6 stones | 1 Snegl | 3 (2 S) / 225 / 65% | 6 (2 S) / 370 / 75% | 18 | 29 s | 39 s / 10% |
| 10 | 2 | Ringraketten | Breather (ringed planet + rocket) | 14x16 open | 1 Snegl | 3 / 210 / 60% | 6 / 340 / 70% | inf | 33 s | 36 s / 0 |
| 11 | 3 | Lynet | Lyn token | 14x16 open | 2 Lyn | 3 / 220 / 65% | 7 / 360 / 75% | 21 | 33 s | 44 s / 12% |
| 12 | 3 | Lynrask | Lyn practise | 14x16, 4 stones | 2 Lyn | 3 / 225 / 65% | 7 / 370 / 75% | 21 | 29 s | 42 s / 10% |
| 13 | 3 | Hjørnet | L-shaped field | 14x16 L (6x6 block removed top-right) | 1 Snegl | 4 / 230 / 65% | 8 / 380 / 75% | 24 | 37 s | 53 s / 25% |
| 14 | 3 | Lyn i hjørnet | Combine | 14x16 L + 4 stones | 1 Lyn, 1 Snegl | 4 (1 S) / 235 / 65% | 8 (1 S) / 390 / 75% | 24 | 41 s | 60 s / 32% |
| 15 | 3 | Stormøyet | Breather (storm eye + satellite) | 14x16 open | 1 Lyn | 4 / 220 / 60% | 8 / 360 / 70% | inf | 36 s | 48 s / 0 |
| 16 | 4 | Kvikke | Kvikk ball, first 21x24 field | 21x24 open | 1 Snegl | 4 (1 K) / 230 / 65% | 9 (1 K) / 380 / 75% | 27 | 36 s | 55 s / 8% |
| 17 | 4 | Kvikk og stor | Kvikk + Stor | 21x24, 4 stone blocks of 2x2 | 1 Snegl | 4 (1 K, 1 S) / 235 / 65% | 9 (2 K, 1 S) / 390 / 75% | 27 | 33 s | 58 s / 12% |
| 18 | 4 | Korset | Plus-shaped field | 21x24 plus (6x6 cells removed at each corner) | 1 Lyn | 5 / 240 / 65% | 10 / 400 / 75% | 30 | 50 s | 62 s / 22% |
| 19 | 4 | Beltet | Combine | 21x24 plus + 4 stone blocks of 2x2 | 1 Lyn, 1 Snegl | 5 (1 K) / 245 / 65% | 10 (2 K) / 410 / 75% | 30 | 41 s | 66 s / 27% |
| 20 | 4 | Kometen | Breather (comet over the belt) | 21x24 open | 1 Snegl | 5 / 230 / 60% | 10 / 380 / 70% | inf | 44 s | 51 s / 0 |
| 21 | 5 | Speilet | Mirror | 21x24, 4 mirrors | 1 Snegl | 5 / 240 / 65% | 11 / 400 / 75% | 33 | 50 s | 69 s / 18% |
| 22 | 5 | Speilsal | Mirror practise | 21x24, 8 mirrors | 1 Lyn | 5 / 245 / 65% | 11 / 410 / 75% | 33 | 41 s | 74 s / 20% |
| 23 | 5 | Isflakene | Ice islands | 21x24, 6 islands of 3x3 stones | 1 Snegl, 1 Lyn | 6 / 250 / 65% | 12 / 420 / 75% | 36 | 50 s | 80 s / 28% |
| 24 | 5 | Isspeil | Combine | 21x24 islands + 4 mirrors | 1 Lyn, 1 Snegl | 6 (1 S, 1 K) / 255 / 65% | 12 (1 S, 2 K) / 430 / 75% | 36 | 51 s | 77 s / 23% |
| 25 | 5 | Ismånen | Breather (ice moon + lander) | 21x24 open | 2 Snegl | 6 / 240 / 60% | 12 / 400 / 70% | inf | 46 s | 62 s / 0 |
| 26 | 6 | Skjoldet | Skjold token | 21x24 open | 2 Skjold | 6 / 250 / 65% | 13 / 420 / 75% | 39 | 50 s | 86 s / 28% |
| 27 | 6 | Skjold og lyn | Skjold + Lyn | 21x24, 4 stone blocks of 2x2 | 1 Skjold, 1 Lyn | 6 (1 K) / 255 / 65% | 13 (2 K) / 430 / 75% | 39 | 51 s | 85 s / 27% |
| 28 | 6 | Labyrinten | Shapes + mirrors | 21x24 plus + 4 mirrors | 1 Skjold, 1 Snegl | 7 (1 S) / 260 / 65% | 14 (1 S, 1 K) / 440 / 75% | 42 | 63 s | 103 s / 45% |
| 29 | 6 | Alt på en gang | Everything | 21x24 L (9x9 removed top-right) + 3 islands of 3x3 + 2 mirrors | 1 of each | 7 (1 S, 1 K) / 265 / 65% | 14 (2 S, 2 K) / 450 / 75% | 42 | 62 s | 99 s / 45% |
| 30 | 6 | Galaksen | Finale, generous (galaxy + starship) | 21x24 open | 2 Skjold | 7 / 250 / 60% | 14 / 420 / 70% | inf | 53 s | 84 s / 0 |

Bold = changed from the shipped world-1 slice (`OfLevels.gd` has Vanlig L4 = 3 and L5 = 2 balls); the builder updates those two values. Map sizes in world 4-6 are in 21 x 24 cells: a 2x2 stone block (96 px) and a 3x3 island (144 px) are the 72 px stone and 2x2 island of worlds 1-3 at the finer grid; a mirror is one 48 px cell.

**How the sim numbers were made (all my calc):** `python3 tools/ramp_sim.py table -n 60`, 2026-10-07, 60 runs per level and setting. The sim plays every level on an **open field** with plain balls: no stones, shaped fields, mirrors, tokens, Stor or Kvikk (tokens and stones mostly help, Kvikk balls make it harder), so levels with a map or specials are approximations; rows with the same config give the same numbers (L2-L4 Lett). The bot is a model of a child (Lett: 40% of its walls are planless taps, 2-6 s thinking between walls; Vanlig: careless 40% of the time, 1-3 s thinking), but it never hesitates, misreads or wanders off, so **treat every time as a floor**: a real 4-year-old will likely take 2-3x longer. Lett medians stay at or under about 1 minute (bot) all the way to level 30; Vanlig restarts stay at or under about 1 in 3 attempts except L28-29 (45%, the two hardest levels; 13 balls there would give about 28%, open question 3).

### 6.4 World 1 maps (vertical slice, build these exactly)

Format: 14 characters per row = columns c0-c13, rows r0 (top, y 256) to r15. Codes from 5.1, plus `S` = Snegl token on an empty cell.

**Level 1: Første strek**, **Level 2: Snu veggen**, **Level 5: Soloppgang**: all 16 rows are `..............` (open field, 224 cells).

**Level 3: Sneglen** (open field, 2 Snegl tokens): every row `..............` except
```
r3  ...S..........
r12 ..........S...
```
Tokens sit in opposite corners' zones, so the first capture on either side tends to grab one.

**Level 4: Steinene** (8 stones, 216 counted cells): every row `..............` except
```
r5  ...##....##...
r10 ...##....##...
```
Four short stone bars: walls stop at them, so the child sees that stones also close rooms.

Level data file (suggested, builder's call): one JSON per level with `field` (`"14x16"` or `"21x24"`), `rows` (16 strings of 14, or 24 strings of 21), `tokens` (inside rows), `lett` and `vanlig` objects `{balls, stor, kvikk, speed, target, sparks}` (sparks 0 = unlimited), `cage` (bool, true from level 6), `picture` (resource id). Values from 6.3.

### 6.4b Field capacity and the 21 x 24 field

**Where the 14 x 16 field breaks (my calc,** `ramp_sim.py grid` and `dens`, 40 runs per row, open field, Vanlig 75% target, 3 sparks per ball**):**

| Balls (Vanlig, 400 px/s) | 14 x 16, 72 px: median / clear / restart | 21 x 24, 48 px: median / clear / restart |
|---|---|---|
| 8 | 53 s / 100% / 20% | 46 s / 100% / 2% |
| 10 | 69 s / 100% / 18% | (59 s / 100% / 2% at 320 px/s) |
| 12 | 86 s / 100% / 38% | 69 s / 100% / 10% |
| 14 | 165 s / **95%** / 50% | (83 s / 100% / 15% at 320 px/s) |
| 16 | 195 s / **92%** / 60% | 110 s / 100% / 45% |
| 20 | 600 s cap / **40%** / 85% | 270 s / **85%** / 68% |

Lett (240 px/s, 65%) on 14 x 16 still clears 100% with 8 balls (median 64 s), so Lett alone never needs the finer field.

**Reading:** on 14 x 16 capture strains from 12 balls (restart chance doubles) and breaks at 14 (some runs never clear in 10 minutes). With speed also rising, the safe ceiling is **8 balls** (L13-14 at 380-390 px/s: 25-32% restarts). The 21 x 24 field holds to about 16 balls and breaks around 18-20.

**Decision (my call):** one field per world so each level keeps one map for both settings ("same 30 maps", 10.1). Worlds 1-3 use 14 x 16; **worlds 4-6 use 21 x 24** (Vanlig reaches 9 balls at L16). Uendelig switches by ball count: 14 x 16 up to 8 balls, 21 x 24 from 9.

| Key | 14 x 16 (W1-3) | 21 x 24 (W4-6, Uendelig from 9 balls) | Note |
|---|---|---|---|
| `COLS x ROWS` | 14 x 16 = 224 cells | 21 x 24 = 504 cells | |
| `CELL` | 72 px | 48 px | Field rect unchanged: origin (36, 256), 1008 x 1152 px, so zones (3.2), HUD and buttons do not move |
| `BALL_RADIUS` | 24 | 20 (simmed) | Stor 28, Kvikk 15 on 21 x 24 (same 1.42x / 0.75x ratios, my call, not simmed) |
| Ball speed | px/s from 6.3 | px/s from 6.3 | Speeds are px/s on both fields, so "faster" is what the eye sees |
| `WALL_SPEED` | Lett 14 / Vanlig 10 cells/s | Lett 21 / Vanlig 15 cells/s | Same px/s (1008 / 720) so the wall-versus-ball race does not change with the grid |
| `CAGE_CELLS` | Lett 12 / Vanlig 8 | Lett 27 / Vanlig 18 | Same area in px |
| Spawn zone | cols 2-11, rows 2-13 | cols 2-18, rows 2-21 | As simmed |
| `GHOST_HYSTERESIS` | 0.6 cell (43 px) | 0.6 cell (29 px) | |
| Capture sound size thresholds (9) | m >= 14, l >= 40 cells | m >= 32, l >= 90 cells | Same area |
| Crystal MultiMesh (DESIGN 7) | max 224 | max 504 | graphic-designer / builder: 504 x 22 tris |

### 6.5 Uendelig (endless mode, owner 2026-10-07)

**Pitch:** one run of rounds on an open field; every round adds one ball and one speed step; the run never ends by losing; the best round is saved.

**Unlock and entry:** a 200 px "Uendelig" disc (an orb with a looping orbit trail, no text) sits on every world-map page at (540, 1560), between the world arrows. It appears once level 5 is cleared in either setting, and only when `full_unlock` is true (never in the free part). Before that it is not drawn (nothing is ever shown locked). It shows the best round for the current setting as a small digit on a gold star at its top-right (0 = no star).

**Rounds** (k = 1, 2, 3 ...):

| | Lett | Vanlig |
|---|---|---|
| Balls in round k | k | k + 1 |
| Speed in round k | 200 + 5 (k - 1) px/s | 320 + 10 (k - 1) px/s |
| Cap (reached at) | 10 balls, 245 px/s (round 10) | 13 balls, 430 px/s (round 12) |
| Field | 14 x 16 up to 8 balls (rounds 1-8), 21 x 24 from 9 balls (round 9+) | 14 x 16 rounds 1-7, 21 x 24 from round 8 |
| Target | 65% every round | 75% every round |
| Sparks | none | 3 x balls, refilled at every round start (from round 1, owner rule) |
| Cage rule | on | on |
| Map | open field, plain balls (no Stor or Kvikk); from round 3 one Snegl token on a random empty spawn-zone cell | same |
| Picture | round k reveals the breather picture of world ((k - 1) mod 6) + 1 (L5, L10 ... L30) | same |

**At the cap:** balls and speed stop growing; rounds keep counting with the cap values, so a strong player can push the best round as high as they like. Why these caps (my calc, endless runs below): Vanlig round 12 (13 balls, 430) clears 100% with a 32% restart chance; one step more (14 balls, 440) doubles the median to 142 s and restarts half the rounds, and the plateau is replayed every round after the cap. Lett round 10 (10 balls, 245) has a bot median of 78 s; 12 balls is 94 s and 14 balls 111 s, too long for 4-7 once real-child slowness (2-3x) is added. The cap stays under the 21 x 24 capacity (6.4b).

**No game over:** Lett pops cost nothing. Vanlig: an empty spark bar plus a pop starts the gentle restart (4.4) of **the same round** (same ball count and speed, field and fill reset, sparks refilled); the round number never goes down. The only way out is the home disc / Android back (3.3), which ends the run.

**Round clear:** the normal clear sequence (9) with the win stinger, then a small **round card**: the round's picture, the round number as a big digit on a gold star, and two discs at y 1300: home (x 340, 200 px) and next round (x 740, 240 px, most visible). No auto-advance (rule 26). Every 5th round the card is the full win card (8.4) with spoken praise. The game emits `endless_card_shown(round: int)` on every round card so the shell's play limit can end the session there, like `level_card_shown`.

**New best:** when a cleared round beats the saved best, the star on the card gets a gold ring that pops in (300 ms) with the comms beep at its highest pitch step plus the satellite ping (9). No text, no "record".

**HUD in Uendelig:** the fill meter shortens to x 280-860; a **round badge** (disc, diameter 150, centre (960, 136)) shows the current round as a large digit in both settings, with a small best-round digit on a gold star under it (y 192-220, Vanlig only; in Vanlig the spark bar uses x 280-860). Round 1-9 one digit, 10+ two digits at 80% size. The badge pulses once (300 ms, flash limiter) when a round starts.

**Round start:** warp-in sound (9); when the field switches from 14 x 16 to 21 x 24 the frame redraws itself over 0.8 s (same as level intro) and the warp-in plays at pitch x0.84, so the finer grid reads as "a bigger space", not a glitch.

**Save:** `endless_best` in the save file (8.6), per setting, updated on every round clear that beats it. A run in progress is not saved; leaving the app or the mode ends the run (quitting costs nothing, rule 28).

**Sim of the Uendelig ramp (my calc,** `ramp_sim.py endless Vanlig|Lett`, 40 runs per round, bot medians**):**

| Round | Vanlig balls / px/s / field: median / restart | Lett balls / px/s / field: median |
|---|---|---|
| 1 | 2 / 320 / 14x16: 16 s / 12% | 1 / 200 / 14x16: 11 s |
| 3 | 4 / 340 / 14x16: 28 s / 8% | 3 / 210 / 14x16: 36 s |
| 5 | 6 / 360 / 14x16: 45 s / 12% | 5 / 220 / 14x16: 52 s |
| 7 | 8 / 380 / 14x16: 55 s / 28% | 7 / 230 / 14x16: 67 s |
| 8 | 9 / 390 / 21x24: 59 s / 15% | 8 / 235 / 14x16: 68 s |
| 9 | 10 / 400 / 21x24: 63 s / 22% | 9 / 240 / 21x24: 79 s |
| 10 | 11 / 410 / 21x24: 77 s / 22% | 10 / 245 / 21x24: 78 s (cap) |
| 11 | 12 / 420 / 21x24: 80 s / 30% | = cap |
| 12+ | 13 / 430 / 21x24: 90 s / 32% (cap) | = cap |

Every round cleared in 40 of 40 runs. A bot run to round 10 takes about 8 min (Vanlig) or 9 min (Lett) of play (my calc, sum of medians), so the best round grows over several sittings.

## 7. Numbers (single balance table)

All tunables live in one const block or data file (studio rule).

| Key | Lett (4-7) | Vanlig (8+) | Unit | Note |
|---|---|---|---|---|
| `FIELD_ORIGIN` | (36, 256) | same | px | Top-left of cell c0 r0 |
| `CELL` | 72 (W1-3), 48 (W4-6) | same | px | 6.4b |
| `COLS / ROWS` | 14 / 16 (W1-3), 21 / 24 (W4-6) | same | | 224 / 504 cells; Uendelig by ball count (6.5) |
| `BALL_RADIUS` | 24 / 20 | 24 / 20 | px | 14 x 16 / 21 x 24 |
| `STOR_RADIUS / SPEED_MULT` | 34 (28) / 0.8 | 34 (28) / 0.8 | | Bracket = 21 x 24 |
| `KVIKK_RADIUS / SPEED_MULT` | 18 (15) / 1.15 | 18 (15) / 1.3 | | Bracket = 21 x 24 |
| `WORLD_BASE_SPEED` | 200 / 210 / 220 / 230 / 240 / 250 | 320 / 340 / 360 / 380 / 400 / 420 | px/s | W1-W6 |
| `LEVEL_SPEED_STEP` | 5 | 10 | px/s | Added per level L1-L4 in W2-6; L5 = base; W1 flat. Table 6.3 |
| `BALLS` | W1 1,2,2,2,2; then w,w,w+1,w+1,w+1 | W1 2,3,3,4,4; then 2w+1,2w+1,2w+2,2w+2,2w+2 | | w = world 2-6. Table 6.3 |
| `ENDLESS_BALLS` | k, cap 10 | k + 1, cap 13 | | k = round |
| `ENDLESS_SPEED` | 200 + 5 (k - 1), cap 245 | 320 + 10 (k - 1), cap 430 | px/s | |
| `ENDLESS_FIELD_SWITCH_BALLS` | 9 | 9 | | 21 x 24 from 9 balls |
| `BALL_ANGLE_DEG` | 35-55 | 35-55 | deg from horizontal | Random per ball |
| `SUBSTEP_MAX_PX` | 8 | 8 | px | |
| `WALL_SPEED` | 14 (21 on 21 x 24) | 10 (15 on 21 x 24) | cells/s per half | Same px/s on both fields |
| `MAX_GROWING_WALLS` | 1 | 1 | | |
| `TARGET` | 65% (breathers 60%) | 75% (breathers 70%) | | Owner 2026-10-07; Uendelig has no breathers |
| `SPARKS` | unlimited | 3 x balls, no max; unlimited in W1 + breathers; Uendelig 3 x balls every round | | Owner 2026-10-07. `OfBalance.SPARKS_MAX` (24) goes |
| `CAGE_CELLS` | 12 (27) | 8 (18) | cells | From level 6; bracket = 21 x 24 |
| `SNEGL_FACTOR / SECONDS` | 0.6 / 10 | 0.6 / 8 | | |
| `LYN_FACTOR / WALLS` | 2.5 / 2 | 2.5 / 2 | | |
| `SKJOLD_WALLS` | 1 | 1 | | |
| `MIRROR_COOLDOWN` | 0.2 | 0.2 | s | Per ball |
| `GHOST_HYSTERESIS` | 0.6 | 0.6 | cell | 43 px / 29 px |
| `HINT_IDLE_S` | 7 | 12 | s | No wall started |
| `HINT_AFTER_POPS` | 2 in 10 s | off | | |
| `POP_ANIM` | 0.25 | 0.25 | s | Cells non-solid at once |
| `RESTART_DIM / REWIND / LIFT` | n/a | 0.6 / 0.8 / 0.4 | s | Gentle restart |
| `MAX_FLASHES_PER_S` | 3 | 3 | | Global limiter, rule 37 |
| `HOLDOVER_MS` | 300 | 300 | ms | Rule 8 |
| `FREE_LEVELS` | 3 | 3 | | Only when `full_unlock` is false |

## 8. Screens, onboarding and session shape

### 8.1 World map

Same pattern as Neon Bricks: one world per page, 5 level discs (diameter 200, hit area 240) on a neon path between y 400 and 1500, never in the top-left 232 square or below y 1664. Cleared level: disc holds a star and a thumbnail of its picture. Suggested next level: 1 Hz pulse. World change: arrow discs (200 px) at y 1560, x 160 and 920. Uendelig disc (200 px) at (540, 1560) once level 5 is cleared and `full_unlock` is true (6.5). No swipe, no scroll (rule 20). Stand-alone only: gear disc top-right opens settings.

### 8.2 HUD

- **Fill meter:** a horizontal glass tube x 280-1040, y 96-176. It fills from the left as the field fills. A **star** marks the target line. Four notches mark 25/50/75/100% of the target (shape cue, rule 36). Lett shows no digits; Vanlig shows the fill % in small digits at the right end (my call).
- **Spark bar (Vanlig, levels with a budget):** a row of small diamond segments under the meter, y 192-220; each pop removes one with a single crack (one flash, not a strobe). Segment width = min(32, bar width / budget) px with a 2 px gap, so 42 sparks still fit (18 px each on the 760 px bar). Unlimited levels draw no bar.
- **Round badge (Uendelig only):** see 6.5.
- No level number, no text.

### 8.3 First 60 seconds (no text anywhere)

- 0 s: first ever launch skips the map and opens level 1. One ball drifts slowly. Up-down is pre-chosen.
- 1.0 s: a hand icon presses on a good spot (chosen by the hint rule below), the ghost line appears under it, the hand lifts, the ghost blinks once. Loops every 2.4 s until the child touches the field. Voice line (when recorded): "Trykk og slipp for å lage en vegg" ("Press and let go to make a wall").
- First wall: grows with a rising zip, completes, the empty side fills with a wipe and shows a piece of the picture, meter jumps. The child learns "close a room, get a picture".
- First pop (ball bumps the wall): soap-bubble burst, the ball bounces on, nothing else happens. The child learns pops are harmless.
- After the first capture: the side-side button pulses for 2 s (1 Hz), once. Level 2 makes turning the focus: its first hint line is side-side, and the side-side button glows with it.
- About 11 s (bot, my calc; likely 20-40 s for a real 4-year-old): meter reaches the star, win card.
- **Hint rule** (idle hint, rule 18): after `HINT_IDLE_S` with no wall started, or Lett 2 pops in 10 s, glow the best line for 1.5 s and the matching direction button. Best line = among all straight runs of empty cells (one per column segment and row segment), the one that captures the most cells right now if completed, skipping lines that a ball would reach before the wall finishes (predict each ball forward in a straight line until its first bounce); ties go to the shorter line. Same scoring as the sim bot (`tools/wall_sim.py`, `choose()`, with danger check always on).

### 8.4 Win card (natural stopping point, owner)

- Level clear sequence (section 9), then the card 1.4 s after the last capture.
- Shows: the level's full picture, one big star landing on it, and three icon discs at y 1300: replay (x 270, 200 px), map/home (x 540, 200 px), next (x 810, 240 px, most visible). No text.
- Spoken praise of the action (rule 32, when recorded): "Du stengte inne alle ballene!" ("You fenced in all the balls!").
- Never auto-advances (rule 26). The game emits `level_card_shown(level_id)`; the shell's play limit may end the session here.
- After level 30: no "next" disc. After level 3 with `full_unlock` false: no "next" disc, emit `free_levels_finished`.

### 8.5 Session shape

A level takes about 15 s to 2 min. A child plays 4-10 levels per sitting and stops at a card. Pull to come back: the unfinished picture gallery on the map and the next world's new element. No streaks, daily rewards, timers or "come back" messages (rule 27).

### 8.6 Save (`user://orb_fence_save.json`)

```json
{
  "version": 1,
  "cleared": [1, 2, 3],
  "difficulty": "lett",
  "endless_best": {"lett": 0, "vanlig": 0},
  "settings": {"sfx": true, "music": true, "haptics": false, "less_motion": false}
}
```
Missing `endless_best` (older saves) reads as 0 for both. Save on level clear, on an Uendelig round clear that beats the best, on difficulty or setting change, on leaving and on `NOTIFICATION_APPLICATION_PAUSED`. Mid-level state is not saved: a left level starts fresh (quitting costs nothing, rule 28). `settings` are only read in the stand-alone build; inside MWM Play the shell's settings win.

## 9. Feel

Sound direction: **space, modern, not 8-bit** (owner 2026-10-07: "rockets, spaceships, lasers"). Soft laser zaps, a thin humming beam, force-field seals, sonar blips, shield fizzles, rocket and warp whooshes, comms beeps, satellite pings and doppler spaceship pass-bys, all kept soft for small children: no alarms, no booms, no buzzers, no "fail" stings. The set is shipped (commit 7138dad): `assets/sfx/of_*.ogg`, rendered by `tools/render_sfx.py` (own synthesis plus one Kenney CC0 glass sample in the spark crack, see `CREDITS.md`), played by `scripts/OfSfx.gd`. Pitched sounds use F# major pentatonic (F# G# A# C# D#), which shares 4 of 5 notes with B major, the best fit to the owner's synthwave mix overall. Files peak at -3 dBFS; `OfSfx` sets each event's level (column "dB" = the `SOUNDS` table value, on top of `BASE_DB` -5 and the player's slider), so at the default slider the loudest events peak near -12 dBFS and the music stays at least 6 dB under effects (rule 33). Each play picks a random variant and a small random pitch shift (the "spread") so repeats do not tire the ear.

"Mindre bevegelse" (less motion, rule 39) column says what replaces the effect. Sound names below are the `OfSfx` keys; file lengths include reverb tails (my measurement with ffprobe).

| Event | Visual | Sound: key -> files, what it is, length, dB | Haptic (only if on; default off, rule 33) | Mindre bevegelse |
|---|---|---|---|---|
| UI tap (map, card, home, any disc) | Button presses to 94% in 80 ms, springs back 120 ms | `tap` -> `of_tap_1..3`: cockpit button click, tight tick + tiny glassy tone, 0.15 s, -4, spread 3%, on touch-down | 10 ms | No scale; button tints darker |
| **Direction pick** (button release) | Chosen button rises and rings | `dir_pick` -> `of_dir_1..2`: servo turn, motor whirr gliding up a fifth then a soft stop tick, 0.33 s, -10; side-side plays one pentatonic step higher (x1.1225) | 10 ms | same |
| Field touch-down (ghost appears) | Dotted ghost line fades in over 60 ms, origin dot | `tick_in` -> `of_tick_in`: quiet high soft pluck, 0.06 s, -10 | none | same |
| Ghost moves one cell | Line slides to the new cell in 50 ms | `ghost_tick` -> `of_tick_in` at -20, spread 8%, max 10 per second | none | Line jumps, no slide |
| Release while a wall grows | Ghost shrinks into its dot, 150 ms | `notyet` -> `of_notyet`: low muted blip, 0.11 s, -8 | none | Ghost just disappears |
| **Wall start** | Origin cell lights up with a small ring burst (1 ring, 200 ms) | `wall_start` -> `of_laser_1..3`: soft laser fire, FM tone sweeping down onto the root + filtered air zap + light sub push, 0.52-0.55 s, -4 | 12 ms | Ring replaced by a steady glow |
| **Wall grows** | Each new cell slides out of the previous one; bright tip on each half | Beam: `of_beam` on its own player: thin humming laser beam climbing one octave over 1.6 s, -18; fades out in 80 ms when the wall ends or both halves pop. Plus `grow_tick` -> `of_grow_tick_1..3` every 3rd cell per half, pitch +4% per tick, -20, max 10/s | none | Cells appear without slide; sound same |
| **Wall complete** | Whole wall settles with a 120 ms shine pass along its length | `lock` -> `of_seal_1..2`: force-field seal, quick rising "zhoop", soft sub thunk, an energy bell that hums on, 0.93-1.0 s, -4 | 18 ms | No shine pass; wall brightens once |
| **Area captured** | Crystal wave from the wall across the room over 300 ms, picture shows; one soft glow pulse | By room size (14 x 16 / 21 x 24 cells): small (< 14 / < 32) `capture_s` -> `of_capture_s_1..2`: 2-note sci-fi chime with a soft "bwip", 1.5 s, -3; medium `capture_m` -> `of_capture_m`: 3-note chime over a short whoosh, 2.1 s, -2; big (>= 40 / >= 90) `capture_l` -> `of_capture_l`: **rocket launch**, low rumble and whoosh rising into a 4-note crystal chime, 2.7 s, -1 | 20 ms | Room fills instantly with a 150 ms fade, no pulse |
| **Ball bounce** (wall, stone, crystal) | Tiny spark at the contact point, 100 ms | `bounce` -> `of_sonar_1..4`: soft sonar blip with two dark echoes, 0.23 s, -20; pitch x(24 / radius) so Stor is lower and Kvikk higher; max 6 bounce sounds per second in total, the rest dropped | none | same |
| Mirror bounce (W5-6) | Mirror face glints along its diagonal, 150 ms | **Not rendered yet.** Add `mirror` -> `of_mirror` to `render_sfx.py` before world 5: glassy ping, about 0.2 s, -14 (my call). Until then play `bounce` at pitch x1.5 | none | same |
| **Ball hits growing wall** (pop) | Popped half bursts into 8-12 soft bubbles that drift and fade over 0.25 s; the ball squashes 10% for 80 ms | `pop` -> `of_fizzle_1..3`: energy-shield fizzle, friendly bubbly blips + a short electric sparkle that thins out, 0.42-0.47 s, -6, spread 6% | 15 ms | No bubbles: the half fades out in 150 ms |
| Spark lost (Vanlig) | One diamond cracks and falls, 300 ms | `crack` -> `of_crack`: small glassy crack (Kenney CC0 glass layer, high-passed), 0.5 s, -12 | 15 ms | Diamond disappears |
| Gentle restart (Vanlig) | Dim + walls and fill slide back out (4.4) | Beam stops, then `rewind` -> `of_rewind`: soft warp rewind, reversed bell, tone sliding down an octave with slowing wobble, 1.17 s, -5 | none | Instant dim and reset |
| **% milestone** (25/50/75% of target) | The notch on the meter lights up and the meter shimmers once, 300 ms | `milestone` -> `of_comms`: radio comms double beep with a soft key-up squelch, 0.63 s, -6; one pentatonic step higher per milestone (x1.0, 1.12, 1.26) | none | Notch lights, no shimmer |
| Token captured | Token flies to the meter, its effect icon appears on the balls or buttons | `snegl` -> `of_snegl`: time-warp whoosh (tone slides down, wobble slows 8 -> 2 Hz), 1.57 s, -3; while Snegl runs all effects play at pitch x0.94 and the music winds down and back over 0.5 s. `lyn` -> `of_lyn`: thruster boost, ignition puff + tone rising two octaves + bell, 1.29 s, -3. `skjold` -> `of_skjold`: shield power-up hum, warm chord swelling up + bell, 1.78 s, -4 | 15 ms | Token fades at its cell, no flight |
| Cage closes (from L6) | Bars slide down over the room, ball shrinks to 70% | **No own file** (my call: none needed): `lock` at pitch x1.26 followed after 120 ms by the room's capture chime | 20 ms | Bars appear instantly |
| **Level clear** | Balls freeze; time scale 0.3 for 0.5 s real time; the rest of the picture fades in over 0.8 s; each ball pops into a star that flies to the meter (staggered 120 ms apart); camera push-in 6%, shake 8 px for 200 ms | Beam stops, then `win` -> `of_win` (stereo): **a spaceship flies by left to right, then a warm fanfare chord with a rising bell arpeggio**, 4.0 s, -1; music ducks for 3.5 s (`stinger_started`) | 40 ms | Freeze and picture fade kept, no flight, push-in or shake |
| Win card | Star lands on the picture, 300 ms | `star_land` -> `of_star_ping`: satellite ping, pure high ping with ring-mod sidebands and soft repeating echoes, 0.83 s, -7; then spoken praise (when recorded) | none | Star appears |
| Hint glow | Line and button glow at 1 Hz for 1.5 s | `shimmer` -> `of_shimmer`: faint shimmer, 1.28 s, -16 | none | Static glow |
| Level intro | Field frame draws itself around the edge, 0.8 s | `intro` -> `of_warp_in`: hyperspace warp-in, rising whoosh and stretching tone, then a drop out of warp onto a soft bell, 1.95 s, -13 | none | Cut, and no sound (as built) |
| Ambient (during play) | none | `pass_by` -> `of_pass_1..2` (stereo): a spaceship passes left to right, doppler drop, 4.5 / 5.5 s, -16; once every 40-90 s at random (`AMBIENT_PASS_MIN_S / MAX_S`), only while a level is in play | none | same |
| Uendelig round start | As level intro | `intro`; on the round where the field switches to 21 x 24 at pitch x0.84 | none | Cut |
| Uendelig round clear / new best | As level clear; new best: gold ring pops onto the card's star, 300 ms | `win` as level clear; new best adds `milestone` at its top step (x2.0) then `star_land` 200 ms later | 40 ms | Ring appears |

Flash safety: a global limiter allows at most 3 bright flashes per second (rule 37); extra events inside the same 333 ms get sound and particles but no glow spike. No full-screen flashes. No high-contrast moving or flickering stripes (rule 38): the grid and the cage bars are static and low contrast.

## 10. Difficulty settings

### 10.1 Lett (ages 4-7, default) vs Vanlig (ages 8+)

| Aspect | Lett | Vanlig |
|---|---|---|
| Ball hits growing wall | Half pops, no cost ever | Half pops, costs 1 spark; empty bar + pop = gentle restart (W1 and breathers unlimited) |
| Balls (levels) | 1-7 (+1 about every 4 levels) | 2-14 (+1 about every 2 levels) |
| Ball speed | 200-265 px/s | 320-450 px/s |
| Uendelig | +1 ball, +5 px/s per round, cap 10 balls / 245 | +1 ball, +10 px/s per round, cap 13 balls / 430 |
| Wall speed | 14 cells/s per half | 10 cells/s per half |
| Target | 60-68% | 70-75% |
| Cage size | up to 12 cells (27 on 21 x 24) | up to 8 cells (18 on 21 x 24) |
| Hint | after 7 s idle or 2 pops in 10 s | after 12 s idle |
| Fill digits | none | small % digits |
| Same 30 maps | yes (one field per world) | yes |

Rule 16 (no reflex demands at the easiest level) holds: in Lett a wall at 14 cells/s outruns a 200 px/s ball by 5x, and a pop costs nothing.

### 10.2 Where the setting lives

Same as MWM Neon Bricks (follow whatever the owner decides there): inside MWM Play, a "Orb Fence: Lett / Vanlig" row in the parent area and the adapter calls `set_difficulty(easy: bool)` on `enter()`. Stand-alone: the gear on the world map opens Lett/Vanlig, sound, music and "Mindre bevegelse". Difficulty takes effect from the next level start. Vibration is not in this build: it would need the Android vibrate permission, and the stand-alone game asks for no permissions.

## 11. Shell hooks (summary for the builder)

- Read `Engine.get_meta(&"mwm_play_shell")`: hide own home disc, own sound button and own settings gear.
- `set_full_unlock(on: bool)` (default true), `set_difficulty(easy: bool)` (default Lett), `set_shell_inset(Vector2(232, 232))` (no-op: nothing sits there), plus the shell's four settings (sfx, music, haptics, less motion).
- Signals up: `level_card_shown(level_id: int)`, `endless_card_shown(round: int)` (Uendelig round card, 6.5; the adapter treats it like `level_card_shown`), `free_levels_finished()`.
- Public `save_game()` for the adapter's `exit()`.
- Unique class names with a `Orb Fence` prefix (no `Game`, `Main`, `Ball` bare names).

## 12. Vertical slice (what godot-android-dev builds first)

In: world 1 map page; levels 1-5 exactly as in 6.4; grid, balls, wall growth, per-half pop, capture, picture reveal (placeholder pictures are fine until graphic-designer delivers); two direction buttons; ghost wall with snap and hysteresis; Snegl token; stones; fill meter with star and notches; win card; hint rule and hand onboarding; Lett/Vanlig switch; the Vanlig spark bar and gentle restart (W1 is unlimited, so cover them with a headless test and a test-only level flag); `full_unlock` flag and both signals; "Mindre bevegelse"; save file; flash limiter; shell home square kept free.

Out: worlds 2-6, cage, Stor and Kvikk balls, mirrors, Lyn and Skjold, voice lines (blocked on a native Norwegian voice), store art.

Slice acceptance hints for game-qa: Lett level 1 clears with no instruction (kids walk-through, sound off); no touch target below y 1664 or inside 232 x 232; direction buttons hit areas >= 240 px; a half-hit never erases the other half (log check); no ball ever ends inside a solid cell (log check); never more than 3 flashes in any 1 s window when 4 rooms capture in a row; no English text on any child screen.

## 13. Play together tip (rule 42, draft)

"Del på jobben: én velger retning med knappene, den andre trykker hvor veggen skal stå." ("Split the job: one picks the direction with the buttons, the other presses where the wall goes.") The input supports this: a direction tap turns a ghost that another finger is holding.

## 14. Open questions for the owner

Answered 2026-10-07 (owner, final): Vanlig = 3 sparks per ball then gentle restart; cage rule from L6; targets 65 / 75%; more balls level by level; faster across worlds; Lett climbs slower; Uendelig with +1 ball and a speed step per round, best round saved, no game over.

1. **Breather targets:** the breathers (L5, L10 ... L30) keep 60% Lett / 70% Vanlig from v1, under your 65 / 75%. Keep the softer breathers, or 65 / 75% on every level?
2. **Lett on the finer field:** worlds 4-6 switch both settings to the 21 x 24 field (48 px cells, slightly smaller balls) so every level keeps one map. Lett alone would fit on 14 x 16 to the end (8 balls clear 100%, my calc), at the cost of two maps per level in worlds 4-6. One field per world (my pick), or keep Lett on the big cells?
3. **Vanlig L28-29 (14 balls):** the sim restarts 45% of attempts there (13 balls: about 28%). Keep 14 as the finale peak, or stop at 13?
4. **Uendelig unlock:** after level 5 (end of world 1, my pick), from the start, or after level 30?
5. **Round number in Lett:** Uendelig shows the round as a digit in both settings (6.5). OK for 4-7, or a picture count (orbs) in Lett?
