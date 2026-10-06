# MWM Orb Fence: game design doc

Version 1, 2026-10-06, game-designer. Store-safe wall-building game for the MWM Play family app (ages 4-7 and 8+, one-time unlock, no ads, offline). The owner chose the name **MWM Orb Fence** on 2026-10-05.

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

- Field origin (36, 256), cell 72 px, 14 x 16 cells = 224 cells. A ring of border cells sits outside (drawn as the frame, not counted).
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
- **Vanlig: a pop costs one spark.** Spark budget per level = 3 x ball count, max 24 (my call from the sim, 4.7). World 1 and every breather level have unlimited sparks. When the bar is empty, the next pop starts a **gentle restart**: the screen dims to 60% over 0.6 s, walls and fill slide back out over 0.8 s, the bar refills, balls respawn, dim lifts over 0.4 s. No text, no "game over", no failure sound (a soft rewind whoosh). Under 2 s total.
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

A flat 3 like Neon Bricks' net would restart most Vanlig attempts, and our old `max(3, level + 2)` lives formula is the "balls + 2" column. 3 x balls keeps restarts rare in worlds 2-3 and occasional in 5-6.

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

A token floats in one empty cell (drawn 60 px, slow 0.5 rev/s spin). Balls pass over it. **It activates when its cell becomes CAPTURED, CAGED or part of a completed WALL**, so it uses the core verb and adds no new input (my call). Max 2 tokens per level. Same token again = timer refresh, not stack.

| Name (NO / EN) | Icon | Effect | Twist | First level |
|---|---|---|---|---|
| **Snegl / Snail** (vertical slice) | Snail shell spiral | All balls x0.6 speed for 8 s (Lett 10 s). | Each ball grows a small snail-shell swirl; the swirl unwinds as time runs out, a countdown with no digits. Music and effects pitch down slightly, wind back up over 0.5 s. | 3 |
| Lyn / Bolt | Zigzag bolt | The next 2 walls grow 2.5x faster. | The direction buttons get a bolt notch per charge left (2, then 1): count by shape. | 11 |
| Skjold / Shield | Hexagon | The next wall cannot pop; balls just bounce off it. | The ghost wall is drawn with a hex pattern while the shield waits. | 26 |

### 5.3 Picture reveal

Each level has a hidden neon picture (graphic-designer: planets, moons, rockets, comets, etc.; subjects per level in DESIGN.md). CAPTURED and CAGED cells show the picture under a soft glass tint. On clear, the rest of the picture fades in, and the win card shows it whole. This is the reward that makes going past the target feel good without a score.

## 6. Progression

### 6.1 Rules

- 6 worlds x 5 levels = 30 hand-made levels (no endless in v1, my call).
- Every world: **L1** one new element, **L2** practise it, **L3** one new token or rule, **L4** combine, **L5** breather (fewer balls, lower target, Vanlig sparks unlimited, a picture-first level).
- No sequential lock (same as Neon Bricks): any level can be picked from the map; the lowest uncleared level pulses at 1 Hz as the suggestion; nothing is ever shown locked.
- **Free part (owner):** the game holds `full_unlock: bool`, default `true`. The MWM Play adapter sets it on `enter()` through a public hook `set_full_unlock(on: bool)`.
  - `full_unlock == false`: the map shows only world 1 levels 1-3. Level discs 4-5 and world arrows are not drawn at all. Clearing level 3 shows the normal win card with replay + home only (no "next") and emits `free_levels_finished`; the shell then shows its "Du har spilt alle banene her" card.
  - `full_unlock == true`: all 30 levels. The stand-alone build never calls the hook, so it is fully open.

### 6.2 Worlds

**Settings, world names and picture subjects in this table are SUPERSEDED by DESIGN.md (deep space, owner's pick 2026-10-06): Månebanen, Ringplaneten, Stormkjempen, Kometveien, Isspeilet, Galaksehjertet. Mechanics per world below still hold.**

| World | Name (NO / EN) | Setting cue for graphic-designer | New element (L1) | New token or rule (L3) |
|---|---|---|---|---|
| 1 | Neonrommet / Neon Room | Grid floor, sunset glow | Walls, turning (L2), Stone (L4) | Snegl |
| 2 | Burhagen / Cage Garden | Neon palms, night garden | Cage rule (L6), Stor ball (L8) | (L6 is the rule) |
| 3 | Lynbyen / Bolt City | Skyline, rain lights | Lyn (L11), L-shaped field (L13) | Lyn |
| 4 | Kveldsveien / Evening Road | Road into the sun | Kvikk ball (L16), plus-shaped field (L18) | (field shape) |
| 5 | Speilsjøen / Mirror Lake | Water reflections, moon | Mirror (L21), stone islands (L23) | (islands) |
| 6 | Stjerneporten / Star Gate | Space, rings | Skjold (L26) | Skjold |

### 6.3 Level table

Ball counts: total (special balls in brackets: S = Stor, K = Kvikk). Speed in px/s. Target = fill %. Sparks: Vanlig budget (inf = unlimited; Lett is always unlimited). Target time = median clear time. Restart = share of Vanlig attempts with at least one gentle restart.

| # | W | Name | New / focus | Field | Tokens | Lett balls / speed / target | Vanlig balls / speed / target | Vanlig sparks | Target time Lett / Vanlig | Restart Vanlig |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | Første strek | Place a wall | Open | | 1 / 200 / 65% | 2 / 320 / 75% | inf | 11 / 13 s (my calc) | 0 |
| 2 | 1 | Snu veggen | Turn the wall (buttons) | Open | | 2 / 200 / 65% | 3 / 320 / 75% | inf | 18 / 22 s (my calc) | 0 |
| 3 | 1 | Sneglen | Snegl token | Open | 2 Snegl | 2 / 200 / 65% | 3 / 320 / 75% | inf | 19 / 21 s (my calc) | 0 |
| 4 | 1 | Steinene | Stone | 8 stones | | 2 / 200 / 65% | 3 / 320 / 75% | inf | 22 / 20 s (my calc) | 0 |
| 5 | 1 | Kveldssol | Breather (sun picture) | Open | | 2 / 200 / 60% | 2 / 320 / 70% | inf | 17 / 12 s (my calc) | 0 |
| 6 | 2 | Buret | Cage rule | 4 corner stones (cage pockets) | | 2 / 210 / 65% | 3 / 340 / 75% | 9 | 25 / 25 s | 8% (my calc) |
| 7 | 2 | Tre i buret | Cage practise | Open | 1 Snegl | 3 / 210 / 65% | 4 / 340 / 75% | 12 | 32 / 25 s | 5% (my calc, at 360 px/s) |
| 8 | 2 | Kjempen | Stor ball | Open | | 3 (1 S) / 210 / 65% | 4 (1 S) / 340 / 75% | 12 | 32 / 28 s | 6% (guess) |
| 9 | 2 | Kjempene | Stor + cage + stones | 6 stones | 1 Snegl | 3 (2 S) / 210 / 68% | 4 (2 S) / 340 / 75% | 12 | 35 / 30 s | 8% (guess) |
| 10 | 2 | Palmene | Breather (palm picture) | Open | 1 Snegl | 2 / 210 / 60% | 3 / 340 / 70% | inf | 20 / 18 s | 0 |
| 11 | 3 | Lynet | Lyn token | Open | 2 Lyn | 3 / 220 / 65% | 4 / 360 / 75% | 12 | 30 / 25 s | 5% (my calc) |
| 12 | 3 | Lynrask | Lyn practise | 4 stones | 2 Lyn | 3 / 220 / 65% | 5 / 360 / 75% | 15 | 32 / 35 s | 12% (guess) |
| 13 | 3 | Hjørnet | L-shaped field | L (6x6 block removed top-right) | 1 Snegl | 3 / 220 / 65% | 4 / 360 / 75% | 12 | 30 / 28 s | 8% (guess) |
| 14 | 3 | Lyn i hjørnet | Combine | L + 4 stones | 1 Lyn, 1 Snegl | 3 (1 S) / 220 / 68% | 5 (1 S) / 360 / 75% | 15 | 35 / 38 s | 15% (guess) |
| 15 | 3 | Regnbyen | Breather (city picture) | Open | 1 Lyn | 2 / 220 / 60% | 3 / 360 / 70% | inf | 20 / 18 s | 0 |
| 16 | 4 | Kvikke | Kvikk ball | Open | 1 Snegl | 3 (1 K) / 220 / 65% | 5 (1 K) / 380 / 75% | 15 | 32 / 38 s | 17% (my calc) |
| 17 | 4 | Kvikk og stor | Kvikk + Stor | 4 stones | 1 Snegl | 3 (1 K, 1 S) / 220 / 65% | 5 (2 K, 1 S) / 380 / 75% | 15 | 35 / 40 s | 18% (guess) |
| 18 | 4 | Korset | Plus-shaped field | Plus (4x4 corners removed) | 1 Lyn | 3 / 220 / 65% | 5 / 380 / 75% | 15 | 32 / 38 s | 15% (guess) |
| 19 | 4 | Gatene | Combine | Plus + 4 stones | 1 Lyn, 1 Snegl | 4 (1 K) / 220 / 68% | 6 (2 K) / 380 / 75% | 18 | 45 / 45 s | 20% (guess) |
| 20 | 4 | Solveien | Breather (road picture) | Open | 1 Snegl | 3 / 220 / 60% | 4 / 380 / 70% | inf | 28 / 22 s | 0 |
| 21 | 5 | Speilet | Mirror | 4 mirrors | 1 Snegl | 3 / 230 / 65% | 5 / 400 / 75% | 15 | 35 / 40 s | 17% (guess) |
| 22 | 5 | Speilsal | Mirror practise | 8 mirrors | 1 Lyn | 4 / 230 / 65% | 6 / 400 / 75% | 18 | 45 / 45 s | 20% (my calc, open field) |
| 23 | 5 | Øyene | Stone islands | 6 islands of 2x2 stones | 1 Snegl, 1 Lyn | 4 / 230 / 65% | 6 / 400 / 75% | 18 | 45 / 45 s | 20% (guess) |
| 24 | 5 | Speiløyene | Combine | Islands + 4 mirrors | 1 Lyn, 1 Snegl | 4 (1 S, 1 K) / 230 / 68% | 7 (1 S, 2 K) / 400 / 75% | 21 | 50 / 55 s | 25% (guess) |
| 25 | 5 | Månen | Breather (moon picture) | Open | 2 Snegl | 3 / 230 / 60% | 4 / 400 / 70% | inf | 28 / 25 s | 0 |
| 26 | 6 | Skjoldet | Skjold token | Open | 2 Skjold | 4 / 240 / 65% | 6 / 420 / 75% | 18 | 45 / 45 s | 20% (guess) |
| 27 | 6 | Skjold og lyn | Skjold + Lyn | 4 stones | 1 Skjold, 1 Lyn | 4 (1 K) / 240 / 65% | 7 (2 K) / 420 / 75% | 21 | 50 / 55 s | 25% (guess) |
| 28 | 6 | Labyrinten | Shapes + mirrors | Plus + 4 mirrors | 1 Skjold, 1 Snegl | 4 (1 S) / 240 / 65% | 7 (1 S, 1 K) / 420 / 75% | 21 | 50 / 55 s | 25% (guess) |
| 29 | 6 | Alt på en gang | Everything | L + islands + 2 mirrors | 1 of each | 5 (1 S, 1 K) / 240 / 68% | 8 (2 S, 2 K) / 440 / 75% | 24 | 55 / 60 s | 28% (my calc, open field) |
| 30 | 6 | Stjernefinale | Finale, generous (star picture) | Open | 2 Skjold | 4 / 240 / 60% | 6 / 420 / 70% | inf | 40 / 40 s | 0 |

Where the numbers come from (all my calc unless marked guess): `tools/wall_sim.py 100` for levels 1-5 (100 runs per level and setting); the extra open-field runs in that script's `--sparks` mode and a variant run on 2026-10-06 (Lett 3 balls 220 px/s 70%: median 32 s; 4 balls 240: 45 s; 5 balls 240: 55 s; Vanlig 4 balls 340: 25 s; 6 balls 400: 43 s; 8 balls 440: 58 s) anchor levels 6-30. Shaped fields, cages and tokens are not simulated for levels 6-30, so those times are guesses. The bot is a model of a child (40% of its walls in Lett are planless taps, it thinks 2-6 s between walls), but it never hesitates, misreads or wanders off, so **treat every time as a floor**: a real 4-year-old will likely take 2-3x longer. Rule of thumb for later maps: keep the Lett median under 2 minutes.

### 6.4 World 1 maps (vertical slice, build these exactly)

Format: 14 characters per row = columns c0-c13, rows r0 (top, y 256) to r15. Codes from 5.1, plus `S` = Snegl token on an empty cell.

**Level 1: Første strek**, **Level 2: Snu veggen**, **Level 5: Kveldssol**: all 16 rows are `..............` (open field, 224 cells).

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

Level data file (suggested, builder's call): one JSON per level with `rows` (16 strings of 14), `tokens` (inside rows), `lett` and `vanlig` objects `{balls, stor, kvikk, speed, target, sparks}` (sparks 0 = unlimited), `cage` (bool, true from level 6), `picture` (resource id). Values from 6.3.

## 7. Numbers (single balance table)

All tunables live in one const block or data file (studio rule).

| Key | Lett (4-7) | Vanlig (8+) | Unit | Note |
|---|---|---|---|---|
| `FIELD_ORIGIN` | (36, 256) | same | px | Top-left of cell c0 r0 |
| `CELL` | 72 | 72 | px | |
| `COLS / ROWS` | 14 / 16 | same | | 224 cells |
| `BALL_RADIUS` | 24 | 24 | px | |
| `STOR_RADIUS / SPEED_MULT` | 34 / 0.8 | 34 / 0.8 | | |
| `KVIKK_RADIUS / SPEED_MULT` | 18 / 1.15 | 18 / 1.3 | | |
| `BALL_SPEED` | 200 / 210 / 220 / 220 / 230 / 240 by world | 320 / 340 / 360 / 380 / 400 / 420 (L29 440) | px/s | Table 6.3 |
| `BALL_ANGLE_DEG` | 35-55 | 35-55 | deg from horizontal | Random per ball |
| `SUBSTEP_MAX_PX` | 8 | 8 | px | |
| `WALL_SPEED` | 14 | 10 | cells/s per half | |
| `MAX_GROWING_WALLS` | 1 | 1 | | |
| `TARGET` | 65% (breathers 60%, some L4s 68%) | 75% (breathers 70%) | | Table 6.3 |
| `SPARKS` | unlimited | 3 x balls, max 24; unlimited in W1 + breathers | | 4.7 |
| `CAGE_CELLS` | 12 | 8 | cells | From level 6 |
| `SNEGL_FACTOR / SECONDS` | 0.6 / 10 | 0.6 / 8 | | |
| `LYN_FACTOR / WALLS` | 2.5 / 2 | 2.5 / 2 | | |
| `SKJOLD_WALLS` | 1 | 1 | | |
| `MIRROR_COOLDOWN` | 0.2 | 0.2 | s | Per ball |
| `GHOST_HYSTERESIS` | 0.6 | 0.6 | cell | |
| `HINT_IDLE_S` | 7 | 12 | s | No wall started |
| `HINT_AFTER_POPS` | 2 in 10 s | off | | |
| `POP_ANIM` | 0.25 | 0.25 | s | Cells non-solid at once |
| `RESTART_DIM / REWIND / LIFT` | n/a | 0.6 / 0.8 / 0.4 | s | Gentle restart |
| `MAX_FLASHES_PER_S` | 3 | 3 | | Global limiter, rule 37 |
| `HOLDOVER_MS` | 300 | 300 | ms | Rule 8 |
| `FREE_LEVELS` | 3 | 3 | | Only when `full_unlock` is false |

## 8. Screens, onboarding and session shape

### 8.1 World map

Same pattern as Neon Bricks: one world per page, 5 level discs (diameter 200, hit area 240) on a neon path between y 400 and 1500, never in the top-left 232 square or below y 1664. Cleared level: disc holds a star and a thumbnail of its picture. Suggested next level: 1 Hz pulse. World change: arrow discs (200 px) at y 1560, x 160 and 920. No swipe, no scroll (rule 20). Stand-alone only: gear disc top-right opens settings.

### 8.2 HUD

- **Fill meter:** a horizontal glass tube x 280-1040, y 96-176. It fills from the left as the field fills. A **star** marks the target line. Four notches mark 25/50/75/100% of the target (shape cue, rule 36). Lett shows no digits; Vanlig shows the fill % in small digits at the right end (my call).
- **Spark bar (Vanlig, levels with a budget):** a row of small diamond segments under the meter, y 192-220; each pop removes one with a single crack (one flash, not a strobe). Unlimited levels draw no bar.
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
  "settings": {"sfx": true, "music": true, "haptics": false, "less_motion": false}
}
```
Save on level clear, on difficulty or setting change, on leaving and on `NOTIFICATION_APPLICATION_PAUSED`. Mid-level state is not saved: a left level starts fresh (quitting costs nothing, rule 28). `settings` are only read in the stand-alone build; inside MWM Play the shell's settings win.

## 9. Feel

Sound direction for the sound designer (owner): **modern, not 8-bit chiptune.** Soft analog-style synth plucks, glassy bells, airy noise sweeps, gentle sub thumps, short reverb tails, all sitting under and around an owner-supplied synthwave/cyberpunk music bed played low. Pitched sounds use one pentatonic scale; set its root to the key of the owner's mix (unknown to me). Effects peak around -12 dBFS; music stays at least 6 dB under effects (rule 33). Nothing harsh or alarm-like: no buzzers, no "fail" stings.

"Mindre bevegelse" (less motion, rule 39) column says what replaces the effect.

| Event | Visual | Sound | Haptic (only if on; default off, rule 33) | Mindre bevegelse |
|---|---|---|---|---|
| UI tap (any button: direction, map, card) | Button presses to 94% in 80 ms, springs back 120 ms | Soft rounded "click", synth tom with a short body, < 80 ms, on touch-down | 10 ms | No scale; button tints darker |
| Field touch-down (ghost appears) | Dotted ghost line fades in over 60 ms, origin dot | Quiet "tick-in", high soft pluck, < 60 ms | none | same |
| Ghost moves one cell | Line slides to the new cell in 50 ms | Very quiet tick, max 10 per second | none | Line jumps, no slide |
| Release while a wall grows | Ghost shrinks into its dot, 150 ms | Low muted "not yet" blip, 100 ms | none | Ghost just disappears |
| **Wall start** | Origin cell lights up with a small ring burst (1 ring, 200 ms) | Punchy filtered "thump + pluck", root note, 150 ms | 12 ms | Ring replaced by a steady glow |
| **Wall grow tick** | Each new cell slides out of the previous one; bright tip on each half | One continuous rising "zip" riser per wall (pitch climbs about one octave over the wall's growth time), plus a soft tick every 3rd cell per half, max 10 ticks/s | none | Cells appear without slide; sound same |
| **Wall complete** | Whole wall settles with a 120 ms shine pass along its length | Clean "lock" sound: a short click-clack with a bright bell on top, 250 ms | 18 ms | No shine pass; wall brightens once |
| **Area captured** | Fill wipes out from the wall across the room over 300 ms, revealing the picture; one soft glow pulse at the end | Warm rising chord swell; size scales with room size (small room: 2 notes, big room: 4-note arpeggio), 400-700 ms | 20 ms | Room fills instantly with a 150 ms fade, no pulse |
| **Ball bounce** (wall, stone, filled area) | Tiny spark at the contact point, 100 ms | Soft rubbery "boop", very low level, pitch varies slightly per ball size (Stor lower, Kvikk higher); at most 6 bounce sounds per second total (drop the rest) | none | same |
| Mirror bounce | Mirror face glints along its diagonal, 150 ms | Glassy "ting" | none | same |
| **Ball hits growing wall** (pop) | Popped half bursts into 8-12 soft bubbles that drift and fade over 0.25 s; the ball squashes 10% for 80 ms | Soap-bubble "plip-plop" cluster, light and friendly, 250 ms, never a buzzer | 15 ms | No bubbles: the half fades out in 150 ms |
| Spark lost (Vanlig) | One diamond cracks and falls, 300 ms | Small glassy crack, quiet | 15 ms | Diamond disappears |
| Gentle restart (Vanlig) | Dim + walls and fill slide back out (4.4) | Soft tape-rewind whoosh, 1.2 s | none | Instant dim and reset |
| **% milestone** (25/50/75% of target) | The notch on the meter lights up and the meter shimmers once, 300 ms | Short ascending chime, 3 notes, one step higher per milestone | none | Notch lights, no shimmer |
| Token captured | Token flies to the meter, its effect icon appears on the balls or buttons | Snegl: slow descending "wob"; Lyn: crackle + rising zap; Skjold: hum-up with a bell | 15 ms | Token fades at its cell, no flight |
| Cage closes | Bars slide down over the room, ball shrinks to 70% | Soft metallic "clunk-ding" + small happy arpeggio | 20 ms | Bars appear instantly |
| **Level clear** | Balls freeze; time scale 0.3 for 0.5 s real time; the rest of the picture fades in over 0.8 s; each ball pops into a star that flies to the meter (staggered 120 ms apart); camera push-in 6%, shake 8 px for 200 ms | Music ducks to a filtered pad, then a 2 s bright win arpeggio with a warm pad and a sub hit | 40 ms | Freeze and picture fade kept, no flight, push-in or shake |
| Win card | Star lands on the picture, 300 ms | Soft sparkle + spoken praise | none | Star appears |
| Hint glow | Line and button glow at 1 Hz for 1.5 s | Faint shimmer | none | Static glow |
| Level intro | Field frame draws itself around the edge, 0.8 s | Gentle rising swell | none | Cut |

Flash safety: a global limiter allows at most 3 bright flashes per second (rule 37); extra events inside the same 333 ms get sound and particles but no glow spike. No full-screen flashes. No high-contrast moving or flickering stripes (rule 38): the grid and the cage bars are static and low contrast.

## 10. Difficulty settings

### 10.1 Lett (ages 4-7, default) vs Vanlig (ages 8+)

| Aspect | Lett | Vanlig |
|---|---|---|
| Ball hits growing wall | Half pops, no cost ever | Half pops, costs 1 spark; empty bar + pop = gentle restart (W1 and breathers unlimited) |
| Balls | 1-5 | 2-8 |
| Ball speed | 200-240 px/s (2.8-3.3 cells/s) | 320-440 px/s |
| Wall speed | 14 cells/s per half | 10 cells/s per half |
| Target | 60-68% | 70-75% |
| Cage size | up to 12 cells | up to 8 cells |
| Hint | after 7 s idle or 2 pops in 10 s | after 12 s idle |
| Fill digits | none | small % digits |
| Same 30 maps | yes | yes |

Rule 16 (no reflex demands at the easiest level) holds: in Lett a wall at 14 cells/s outruns a 200 px/s ball by 5x, and a pop costs nothing.

### 10.2 Where the setting lives

Same as MWM Neon Bricks (follow whatever the owner decides there): inside MWM Play, a "Orb Fence: Lett / Vanlig" row in the parent area and the adapter calls `set_difficulty(easy: bool)` on `enter()`. Stand-alone: the gear on the world map opens Lett/Vanlig, sound, music, vibration and "Mindre bevegelse". Takes effect from the next level start.

## 11. Shell hooks (summary for the builder)

- Read `Engine.get_meta(&"mwm_play_shell")`: hide own home disc, own sound button and own settings gear.
- `set_full_unlock(on: bool)` (default true), `set_difficulty(easy: bool)` (default Lett), `set_shell_inset(Vector2(232, 232))` (no-op: nothing sits there), plus the shell's four settings (sfx, music, haptics, less motion).
- Signals up: `level_card_shown(level_id: int)`, `free_levels_finished()`.
- Public `save_game()` for the adapter's `exit()`.
- Unique class names with a `Orb Fence` prefix (no `Game`, `Main`, `Ball` bare names).

## 12. Vertical slice (what godot-android-dev builds first)

In: world 1 map page; levels 1-5 exactly as in 6.4; grid, balls, wall growth, per-half pop, capture, picture reveal (placeholder pictures are fine until graphic-designer delivers); two direction buttons; ghost wall with snap and hysteresis; Snegl token; stones; fill meter with star and notches; win card; hint rule and hand onboarding; Lett/Vanlig switch; the Vanlig spark bar and gentle restart (W1 is unlimited, so cover them with a headless test and a test-only level flag); `full_unlock` flag and both signals; "Mindre bevegelse"; save file; flash limiter; shell home square kept free.

Out: worlds 2-6, cage, Stor and Kvikk balls, mirrors, Lyn and Skjold, voice lines (blocked on a native Norwegian voice), store art.

Slice acceptance hints for game-qa: Lett level 1 clears with no instruction (kids walk-through, sound off); no touch target below y 1664 or inside 232 x 232; direction buttons hit areas >= 240 px; a half-hit never erases the other half (log check); no ball ever ends inside a solid cell (log check); never more than 3 flashes in any 1 s window when 4 rooms capture in a row; no English text on any child screen.

## 13. Play together tip (rule 42, draft)

"Del på jobben: én velger retning med knappene, den andre trykker hvor veggen skal stå." ("Split the job: one picks the direction with the buttons, the other presses where the wall goes.") The input supports this: a direction tap turns a ghost that another finger is holding.

## 14. Open questions for the owner

1. **Vanlig cost for a popped wall:** I propose a spark budget of 3 per ball (max 24) and a gentle restart when it runs out (sim: restart on 5-28% of attempts, worlds 2-6). Alternatives: no cost in Vanlig either (no restart anywhere in the game), or a flat 3 like Neon Bricks' net (sim: 33-93% restarts, too harsh). Which?
2. **Cage rule:** trapping a ball in a tiny room locks it up and removes it from play (from level 6). It is not part of the classic genre and makes later levels easier, but it rewards the most natural child goal, "catch the ball". Keep it?
3. **Level length:** the sim bot clears world 1 in 11-22 s per level (a real young child maybe 20-60 s), so a sitting is many short wins with frequent win cards. Keep it short, or raise the targets (for example Lett 70%, Vanlig 80%) for longer levels?
