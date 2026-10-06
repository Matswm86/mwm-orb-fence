# MWM Orb Fence: visual design spec

Owner: graphic-designer. Version 1, 2026-10-06. The builder reads this before touching any colour, material, light, camera or UI node. Game rules and numbers live in `docs/GDD.md`; child rules (rule N) are in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. Numbers tagged (my calc) are my own arithmetic on rendered pixels with the WCAG 2.x formula.

**Owner's pick: deep space.** GDD section 6.2 and 5.3 still describe synthwave settings (sunset, palms, road into the sun, city). Those cues are replaced by the space worlds in section 2c below, and the hidden pictures become space subjects. Game-designer should update GDD 6.2 "Setting cue" and the breather picture names to match; the mechanics per world stay exactly as in the GDD.

Mockups (all rebuilt by the scripts in `docs/mockups/src/`; Blender 4.5 runs in background mode only):

| File | What it shows |
|---|---|
| `docs/mockups/world1_mock.png` | World 1, level 3 "Sneglen", Lett, mid-play, 1080x1920: 35% captured with the hidden picture showing in the crystal, one wall growing, 2 balls, 2 Snegl tokens |
| `docs/mockups/world1_zones.png` | Same frame with zones: home square (white), HUD strip (blue line), field (yellow), direction-button hit areas (green), wrist strip (red) |
| `docs/mockups/wincard_mock.png` | Win card over the dimmed, blurred scene |
| `docs/mockups/elements.png` | Every element and state: 3 ball types, Snegl and caged states, growing / ghost / finished wall, pop bubbles, start ring, crystal cell plain and with picture, stone, both mirrors, 3 tokens, frame node, halo fallback, direction buttons, Lett and Vanlig meters, spark bar, win card |
| `docs/mockups/src/zb_parts.py` | Shared Blender builders (materials, orb, crystal tile, beam, frame, planets, nebula) |
| `docs/mockups/src/world1_mock.py`, `elements.py`, `export_assets.py` | `blender -b -P <script> -- <out>`; export writes the GLBs and textures in `assets/` |
| `docs/mockups/src/overlay.py`, `wincard.py`, `label_sheet.py`, `picture_w1.py` | Pillow: HUD and buttons, win card, element labels, the sample hidden picture |

Raw renders and `.blend` files live outside the repository, in a local scratch folder named after the working title.

---

## 1. Visual theme

**A glowing force-field grid floating in deep space above a blue ocean planet: coral orbs with rings bounce on dark glass, the child draws gold beams of light, and every closed room hardens into faceted crystal that shows a piece of a hidden space picture.**

References (take the idea, not the look):
- **Monument Valley 2 (ustwo)**: take the calm, readable staging of one small object on a big quiet backdrop, with soft gradients and a limited palette per chapter. Leave behind its pastel architecture.
- **Alto's Odyssey night levels / NASA "Blue Marble" style planet limbs**: take the big planet curve at the bottom of the frame as the horizon, which gives depth with a single card. Leave behind any photographic texture: our planet is a painted, stylised noise shader.

How it differs from the two neighbours:
- **Original JezzBall (Windows 3.x):** grey tiled field, captured area turns black, a red half and a blue half per wall, red-and-white beach-ball "atoms", black HUD with English text. We do the opposite on each point: dark glass field, captured area becomes bright crystal with a picture, one gold beam with no colour split, coral orbs with a planet ring, no text.
- **MWM Neon Bricks (synthwave beach):** magenta/orange sunset, perspective grid floor to a horizon, palms, hotpink rails, cyan as the player colour. We use no horizon line, no perspective floor, no sun, no palms; the scene is cool blue-teal space, the field is seen flat-on, and the player colour is **gold**, not cyan.

## 2. Palette

Split about 60 / 30 / 10: 60% cool dark space and field glass (void, navy, teal nebula), 30% crystal and the hidden picture (world tint), 10% warm actors: **gold = what the child makes** (beam, chosen button, star), **coral = what the child traps** (balls). Purple is allowed only as game content (Skjold token, world 4 and 6 crystal and nebulae); UI chrome (HUD panels, buttons, win card) is navy, white, ink and gold, never purple.

### 2a. Element colours (all worlds)

| Token | Hex | Godot | Role |
|---|---|---|---|
| void | #050816 | Color(0.020, 0.031, 0.086) | Deep space base under the nebula |
| field_glass | #0A1430 | Color(0.039, 0.078, 0.188) | Force-field glass, unshaded, alpha 0.70 |
| grid | #3D7BFF | Color(0.239, 0.482, 1.000) | Grid lines, emission 0.9 (below glow threshold) |
| grid_dot | #9CC4FF | Color(0.612, 0.769, 1.000) | Grid intersection dots ("force-field nodes"), emission 2 |
| rail | #1A2238 | Color(0.102, 0.133, 0.220) | Frame rails: metallic 0.8, roughness 0.32, clear coat 0.6 |
| rail_light | #5AA9FF | Color(0.353, 0.663, 1.000) | Thin emitter line on the inner edge of the rails, emission 3 |
| node / node_lens | #2A3550 / #8FD0FF | Color(0.165, 0.208, 0.314) / Color(0.561, 0.816, 1.000) | Hex emitter at each frame corner; lens emission 6 |
| crystal_w1 | #7FB6FF | Color(0.498, 0.714, 1.000) | World 1 crystal tint (other worlds in 2c) |
| crystal_emit | #4F82E0 | Color(0.310, 0.510, 0.878) | Crystal self-glow, emission 0.32-0.38 |
| rim | #E6F3FF | Color(0.902, 0.953, 1.000) | Bright edge line along every captured/open boundary, emission 5 |
| beam | #FFC94D | Color(1.000, 0.788, 0.302) | **Player colour.** Wall dashes, origin ring, chosen direction button, target star |
| beam_core | #FFF6DA | Color(1.000, 0.965, 0.855) | Thin white-hot core inside the growing beam, emission 9 |
| orb_shell | #FF6F61 | Color(1.000, 0.435, 0.380) | Ball rim colour, halo, trail |
| orb_mid / orb_core | #FFB3A6 / #FFF4EC | Color(1.000, 0.702, 0.651) / Color(1.000, 0.957, 0.925) | Ball gradient from centre to rim (facing ramp) |
| orb_ring | #FFFFFF | Color(1, 1, 1) | The ring around every ball (shape cue "ball") |
| wall_done | #CFE4FF | Color(0.812, 0.894, 1.000) | Finished wall that did not capture: solid ice bar, faint gold core line |
| stone / stone_dark | #6B5E57 / #3A332F | Color(0.420, 0.369, 0.341) / Color(0.227, 0.200, 0.184) | Meteorite stone block, crater tint |
| mirror_face | #E8FBFF | Color(0.910, 0.984, 1.000) | Mirror diagonal: metallic 1, roughness 0.03, emission 2.5 |
| token_snegl | #5CF2B8 | Color(0.361, 0.949, 0.722) | Snegl disc (white spiral icon) |
| token_lyn | #6CD0FF | Color(0.424, 0.816, 1.000) | Lyn disc (white zigzag bolt) |
| token_skjold | #B79CFF | Color(0.718, 0.612, 1.000) | Skjold disc (white hexagon outline) |
| bubble | #E6F6FF | Color(0.902, 0.965, 1.000) | Pop bubbles: rim-only (fresnel) emission over transparent |
| cage_bar | #C9D3E6 | Color(0.788, 0.827, 0.902) | Cage bars: metallic 0.9, roughness 0.25, static |

### 2b. UI chrome

| Token | Hex | Godot | Use |
|---|---|---|---|
| hud_panel | #0D1A33 | Color(0.051, 0.102, 0.200) | Meter tube body, unchosen direction disc (alpha 0.92) |
| hud_edge | #A9BDE0 | Color(0.663, 0.741, 0.878) | 4 px outline of every HUD panel and the unchosen disc |
| meter_track | #060C1C | Color(0.024, 0.047, 0.110) | Empty part of the meter |
| ink | #24211D | Color(0.141, 0.129, 0.114) | Icons, disc rings, star outline (shared with the shell) |
| white | #FFFFFF | Color(1, 1, 1) | Home disc, card discs, lit notches, % digits |
| card | #F4F8FF | Color(0.957, 0.973, 1.000) | Win card and settings panel (light, per house rule) |
| card_edge | #6E89B8 | Color(0.431, 0.537, 0.722) | 4 px card outline |
| beam (gold) | #FFC94D | Color(1.000, 0.788, 0.302) | Chosen direction disc, "next" disc, star |

### 2c. Worlds: backdrop and crystal tint

Same field, balls, beam and HUD in every world. Only the backdrop and the crystal tint change. Each world's picture background uses its crystal tint as a light-to-dark vertical ramp, so the revealed picture always reads as "this world's crystal".

| World (GDD mechanics) | Name proposal (NO / EN) | Crystal tint | Sky (void / nebula ramp) | Backdrop contents (all behind the glass) |
|---|---|---|---|---|
| 1 walls, Snegl, stone | **Månebanen** / Moon Orbit | #7FB6FF Color(0.498, 0.714, 1.000) | #050816 / #0E3D66, #0B6A78, #2B3F9E | Ocean home planet whose limb crosses the bottom (wrist strip), grey moon upper right, soft teal nebula. Shipped: `assets/textures/world1_*.png` |
| 2 cage, Stor | **Ringplaneten** / Ringed Planet | #5ED8D0 Color(0.369, 0.847, 0.816) | #04101A / #0D3A4A, #1D6B6B, #6B5A3A | Cream-amber ringed giant, ring plane cutting diagonally behind the field (the ring echoes the cage bars), small shepherd moons |
| 3 Lyn, L-field | **Stormkjempen** / Storm Giant | #7FE8B0 Color(0.498, 0.910, 0.690) | #060A14 / #1A2A4A, #2C5F6E, #7A6A9E | Banded blue-violet gas giant with a big storm eye; slow light **glows** inside the clouds (0.5 Hz fade, never a flash, counted by the flash limiter) |
| 4 Kvikk, plus-field | **Kometveien** / Comet Road | #B4A6FF Color(0.706, 0.651, 1.000) | #07061A / #20184A, #3A2C86, #1F5A7A | Asteroid belt as 3 parallax silhouette cards, 2 comets with long soft tails crossing slowly (UV scroll, 40 s per pass) |
| 5 mirror, islands | **Isspeilet** / Ice Mirror | #9FE6F2 Color(0.624, 0.902, 0.949) | #040C14 / #0E2E44, #1E6A80, #6FD3D8 | Frozen moon surface seen edge-on at the bottom with a mirror-like sheen, a pale aurora ribbon (static texture, slow UV drift) |
| 6 Skjold, finale | **Galaksehjertet** / Galaxy Heart | #9C8CFF Color(0.612, 0.549, 1.000) | #03020A / #1A1240, #3B2A7A, #C9A86A | A spiral galaxy seen at an angle, warm gold-white core, violet arms. Do not use "Stjerneporten" or a ring gate: MWM Neon Bricks world 6 already owns both |

Rule for every world: the white ball core must keep **4.5:1 or more** against the brightest backdrop spot it can cross (behind the 0.70 glass). If a backdrop element is brighter, dim that element, never brighten the ball. The gold beam keeps 3:1 the same way.

### 2d. Contrast (my calc, sampled from the rendered mocks)

| Pair | Ratio | Need |
|---|---|---|
| Ball core white vs open field glass (cell mean #254056) | 10.8:1 | 3.0 (object), 4.5 my bar for the thing a child tracks |
| Ball core vs brightest backdrop spot behind the glass (moon) | 5.1:1 | 4.5 |
| Ball shell #FF6F61 vs field glass | 4.0:1 | 3.0 |
| Beam gold vs field glass | 7.1:1 | 3.0 |
| Crystal (mean #77ADFD) vs field glass | 4.7:1 | 3.0; plus the pattern cue (facets vs grid) and the white rim line (9.6:1) |
| Snegl token vs field glass | 7.6:1 | 3.0 |
| Grid line vs glass | 2.8:1 | Deliberately under 3: decoration, static and low contrast (rule 38) |
| White % digits / white icons on hud_panel | 17.3:1 | 4.5 (rule 34) |
| hud_edge vs sky behind the HUD | 9.7:1 | 3.0 (rule 35) |
| hud_edge (unchosen disc) vs planet atmosphere behind it | 3.3:1 | 3.0 |
| Crystal fill vs meter track | 9.3:1 | 3.0 |
| Ink on gold (chosen button, next disc, star outline) | 10.5:1 | 3.0 |
| White halo ring of the chosen disc vs planet atmosphere | 6.0:1 | 3.0 |
| Ink on card / ink ring of white discs vs card | 15.1:1 | 4.5 |
| Card vs dimmed scene | 8.1:1 | 3.0 |
| Home white disc vs sky | 18.4:1 | 3.0 |

## 3. Typography

The child reads nothing (GDD 8.2): no text in gameplay, map or win card.
- **Vanlig % digits** (the only in-game text): Fredoka SemiBold 40 px, white on hud_panel. Fredoka is SIL OFL 1.1, already in `projects/mwm-play/assets/fonts/Fredoka.ttf` + `Fredoka-OFL.txt`; copy both into `assets/fonts/`.
- **Stand-alone settings and credits (adult):** Fredoka, body 40 px, labels 44 px, headings 56 px, ink on card.
- **Store art only:** a rounded geometric display face (pick at store-art time, OFL only). Never in game UI.

## 4. Components

| Component | Size and place (px at 1080x1920) | Look | Pressed / state |
|---|---|---|---|
| Home disc (stand-alone only) | dia 136, centre (104, 104), hit 0,0 to 216,216 | Same as the shell: white, 5 px ink ring, ink house 68 px | Shell guard copy (GDD 3.3) |
| Fill meter | Tube x 280-1040, y 96-176, radius 40 | hud_panel body, 4 px hud_edge, inner track meter_track inset 14 px; fill = crystal tint of the world with diagonal facet stripes (lighter tint, 36 px apart) and a thin white highlight on the fill only | Fill grows with a 200 ms ease-out |
| Target star | On the tube at the target %, outer radius 50 | Gold, 5 px ink outline, a 6 px gold tick behind it across the track | When reached: one 300 ms shimmer (not a flash) |
| Milestone notches | 25 / 50 / 75% of target, on the tube centre line | Not reached: hollow diamond, 3 px hud_edge outline. Reached: white diamond with 3 px ink edge. Shape + fill, not colour only | Light-up 300 ms (GDD 9) |
| Vanlig % | Right end of the tube, centre (990, 136) | Fredoka SemiBold 40 px white | n/a |
| Spark bar (Vanlig, budget levels) | y 192-220, from x 316, 44 px apart | **Gold 4-point sparkles** with a 2 px ink edge; a spent spark is a hollow hud_edge outline. Not diamonds (my deviation from GDD 8.2): diamonds are already the meter notches, two diamond rows would blur | Spent: one crack + fall, 300 ms |
| Direction buttons | Centres (330, 1540) and (750, 1540), hit 240x240 each | **Chosen:** 216 px gold disc, 6 px ink ring, white 5 px halo ring 12 px outside, soft drop shadow, ink double-arrow icon (bar 14 px, heads 26 px, origin dot). **Not chosen:** 176 px flat hud_panel disc, 4 px hud_edge, white outline icon at 80%. Size, ring, shadow and fill all differ (rule 36) | Touch-down 94% in 80 ms, release 120 ms; "less motion": darker tint only |
| Lyn charges on buttons | Up to 2 small gold bolt notches on the top-right of both discs | Count by shape | Each use removes one |
| Win card | x 100-980, y 360-1450, radius 56 | card fill, 4 px card_edge, soft dark shadow; picture window x 150-930, y 410-1060, radius 36, 5 px ink frame; star centre (540, 1050), radius 110, 12 px ink outline | Star lands 0.6 -> 1.08 -> 1.0 in 300 ms |
| Win card discs | y 1300: replay x 270 dia 200, map x 540 dia 200, next x 810 dia 240 | Replay and map: white, 6 px ink ring, ink icon. Next: gold, ink ring, ink play triangle (the one most visible action) | 94% + green_soft #E3F0EA fill for 100 ms, act on release |
| Resume disc | dia 240, screen centre | White, ink ring, ink play triangle, scene dimmed 50% | same |
| Map level disc | dia 200, hit 240, on a dotted "star trail" path | Small planet in the world's crystal tint showing that level's picture thumbnail, 6 px hud_edge ring; cleared = gold star with ink outline at its top-right; suggested level: gold ring pulses 1 Hz (60-100%) | 94% |
| Map world arrows | dia 200 at (160, 1560) and (920, 1560) | White disc, ink ring, ink chevron | 94% |

Nothing tappable at y >= 1664 or inside the 232 x 232 top-left square except the home disc itself (`world1_zones.png` proves it).

## 5. Layout

| Band (y px) | Content |
|---|---|
| 0-232 | Sky with stars and nebula. Home disc top-left. HUD strip x 256-1044, y 40-224 (meter, spark bar). |
| 234-256 | Top frame rail (gunmetal, inner blue emitter line); corner hex nodes. |
| 256-1408 | Field: 14 x 16 cells of 72 px, x 36-1044. |
| 1408-1430 | Bottom rail. |
| 1420-1660 | Direction buttons (hit areas). |
| 1664-1920 | Wrist strip: only the planet limb and stars. No target, no HUD. |

Logic px to 3D: 1 px = 0.01 m on the play plane z = 0; the field is 10.08 x 11.52 m. Taller screens (20:9): field and buttons anchor to the bottom (GDD 3.2); the extra height shows more sky above the field. Tablets: the sky texture is 1152x2048 and scales to cover; the planet card is wider than the screen, so side margins show more planet and stars, never stretched art.

## 6. Depth and motion

### 6a. Camera
- Camera3D looks straight down -Z at the play plane, perspective, vertical FOV 35.5 deg (camera 30 m away, 19.2 m visible height: 1 px = 0.01 m on the plane, logic and screen positions stay identical). Blender equivalent: sensor 36 mm vertical, lens 56.25 mm.
- Depth comes from layers, not tilt: field at 0 m, moon card at -60 m, planet at -125 m, nebula and stars at -150 m and beyond.
- Idle drift: +-1 deg yaw and pitch on a 14 s sine around the field centre, so the moon and planet shift against the stars. Off under "Mindre bevegelse".
- Level intro: the frame draws itself (rails grow from the four corner nodes in 0.8 s, GDD 9); the camera does not move.
- Level clear: 6% push-in and 8 px shake for 200 ms (GDD 9), camera only, never the UI layer. Off under "Mindre bevegelse".

### 6b. Motion rules
- Global flash limiter, at most 3 glow spikes per second (rule 37). A spike = emission energy jump above 2x on an area bigger than one cell (capture glow pulse, wall complete shine, level clear). Extra events in the same 333 ms get sound and particles only.
- No full-screen flash, no flicker. Grid, cage bars and backdrop are static or drift slowly.
- UI tweens 0.15-0.25 s ease-out.
- Capture fill: crystal cells grow from the wall outward in a wave over 300 ms (each cell scales 0 -> 1.05 -> 1.0 in 120 ms and its picture fades in); one soft glow pulse at the end. "Mindre bevegelse": all cells fade in together over 150 ms, no pulse.
- Balls never squash except the 10% / 80 ms pop squash from GDD 9 (off under "Mindre bevegelse").
- Snegl state: each ball wears a mint spiral that unwinds as the timer runs out (a countdown with no digits). Under "Mindre bevegelse" the spiral shortens without spinning.
- Token spin 0.5 rev/s (static under "Mindre bevegelse").

## 7. Game art

### 7a. Assets in `assets/` (own work, built by `docs/mockups/src/export_assets.py`)

GLB, Y-up, metres, origin at the centre, 1 logic px = 0.01 m. Materials inside the GLBs are placeholders; the Godot materials below replace them.

| File | Size (m) | Tris | Notes |
|---|---|---|---|
| `models/ball_orb.glb` | dia 0.48 + ring 0.74 | 2112 | Sphere + tilted ring (68 deg X, -18 deg Z). For play use a light copy: sphere 16x8 + ring 24x6 (about 550 tris); the GLB is for menus and store art |
| `models/ball_stor.glb` | dia 0.68 + 2 rings | 3264 | Stor: double ring. Same LOD advice |
| `models/crystal_tile.glb` | 0.70 x 0.70 x 0.26 | 22 | Bevelled base + off-centre low pyramid. MultiMesh, random 90-deg turn per instance |
| `models/stone_block.glb` | 0.70 x 0.70 x 0.34 | 44 | Chamfered meteorite block |
| `models/mirror_block.glb` | as stone + face | 152 | Diagonal mirror face at 45 deg; rotate the face -45 deg for `\` |
| `models/token_snegl.glb`, `token_lyn.glb`, `token_skjold.glb` | dia 0.62 | 2304 / 944 / 996 | Disc + white rim + white icon (spiral / bolt / hexagon) |
| `models/frame_node.glb` | dia 0.60 | 184 | Hex corner emitter + lens |
| `textures/world1_sky.png` | 1152 x 2048, opaque | | Nebula + stars for the far sky quad |
| `textures/world1_planet.png` | 1024 x 1024, alpha | | Ocean planet with atmosphere rim; place so its limb crosses y about 1530 |
| `textures/world1_moon.png` | 512 x 512, alpha | | Moon card, upper right, behind the field |
| `textures/pictures/w1_l3_ringplanet.png` | 1008 x 1152 | | Sample hidden picture (level 3), field-sized |

Rails are built in code from box meshes (0.22 m wide, bevel 0.05); do not scale a bevelled mesh along its length.

### 7b. Shape cue per element (rule 36: colour is never the only cue)

| Element | Shape cue |
|---|---|
| Open cell | Dark see-through glass, thin grid lines, a dot at each crossing |
| Captured cell | Opaque faceted crystal tile showing the picture, white rim line on every edge that meets open field |
| Caged room | Captured look + static vertical cage bars over it; its ball shrinks to 70% and stops |
| Ball | Round + one ring. **Stor:** bigger + two rings. **Kvikk:** smaller + a tapered tail |
| Ball under Snegl | Mint spiral wrapped around it |
| Growing wall | Dashed gold sleeve + white core + bright diamond tips at both ends + gold origin ring |
| Ghost wall (finger down) | White dotted line with a hollow origin ring (dots, not dashes) |
| Finished wall without capture | Solid continuous ice bar with a thin gold core line (solid vs dashed) |
| Pop | The popped half turns into 8-12 soap bubbles (rim-only circles) that drift and fade in 0.25 s |
| Stein | Chamfered rock block, matte, no glow |
| Speil | The rock block with one bright diagonal bar in its direction |
| Snegl / Lyn / Skjold | Spiral / zigzag bolt / hexagon, white on the disc |
| Shield waiting (Skjold) | Ghost wall drawn with small hexagons instead of dots |

### 7c. Materials and lighting (Godot 4.6, `mobile` renderer)

| Thing | How | Why |
|---|---|---|
| Sky | One unshaded quad far away with `world1_sky.png` | 1 draw call for nebula and stars |
| Planet, moon | Unshaded alpha cards at their depths (planet blend, moon alpha scissor 0.5) | Parallax for free; no lit spheres |
| Field glass + grid | **One** unshaded quad: field_glass at alpha 0.70, grid lines from `fract()` with `fwidth()` anti-aliasing, crossing dots from the same shader | The only big transparent surface; grid stays under the glow threshold |
| Crystal | MultiMesh of `crystal_tile` (max 224), StandardMaterial roughness 0.08 + clear coat, or a small shader: albedo = picture sampled at field UV from the world position, x per-instance tint (4 tints within +-6% value, slight cyan and lilac shifts for an iridescent mix), emission = albedo x 0.35. `INSTANCE_CUSTOM.x` = reveal 0..1 for the grow-in | Picture reveal costs one texture read; facets catch the key light |
| Rim lines | One ArrayMesh of thin quads rebuilt after each capture, unshaded rim colour, emission 5 | Region outline in 1 draw call |
| Balls | Unshaded core with a facing ramp (orb_core -> orb_mid -> orb_shell), unshaded white ring, plus a camera-facing additive halo quad (128 px radial gradient, 2.5x ball size) and a tapered additive trail ribbon (12 points, about 130 px) | Halo carries the glow even with post glow off |
| Beam | Core: thin unshaded box. Dashes: one quad strip with a dash shader scrolling outward from the origin; tips: small unshaded octahedra + additive quads | 3-4 draw calls per wall |
| Stone, mirror | StandardMaterial: stone roughness 0.85 with a small crater texture (256 px); mirror face metallic 1, roughness 0.03, emission 2.5 | Stone is the only matte thing: "does not glow" = "does not move" |
| Lights | One DirectionalLight, warm white 3.2, from upper-left-front, **no shadows**; one weak cool fill (0.6) from the lower left; ambient from a dark blue colour | Facets need direction; shadows would not be noticed on a flat field |
| Glow | WorldEnvironment glow on, HDR threshold 1.0, intensity 0.8, levels 2, 3 and 4 only, blend additive | One fixed post pass |
| Tonemap | Linear, exposure 1.0 | Keeps the neon saturation of the mock |

Off on mobile: SSAO, SSR, SSIL, SDFGI, volumetric fog, DOF, real-time shadows, ReflectionProbes.

### 7d. Phone budget (design ceilings; the device FPS overlay decides)

| Item | Budget |
|---|---|
| Draw calls | <= 50 in play: sky, planet, moon, glass+grid (4); frame rails and nodes (6); crystal MultiMesh (1-4); rim (1); stones/mirrors MultiMesh (2); balls x up to 8 with halo and trail (24, or 3 MultiMesh); beam (4); tokens (2); particles (4); UI (5) |
| Visible triangles | <= 40k: crystal 224 x 22 = 4.9k; 8 balls at the light LOD about 4.4k; tokens 2 x 2.3k; frame under 2k |
| Particles | Pop bubbles 12, capture sparkle 24, level-clear stars 8: pool of 6 GPUParticles3D, CPUParticles3D on the Compatibility fallback |
| Transparency | Field glass, ball halos and trails, bubbles, planet card |
| Textures | Sky 1152x2048 and pictures 1008x1152 (ETC2/ASTC), everything else <= 512 |
| Target | 60 fps on a mid-range phone. **32-bit Samsung tablet:** if it has no Vulkan, Godot's OpenGL fallback (`rendering_device/fallback_to_opengl3`) must still look right: every material above is unshaded or standard, and halo quads replace post glow. Check on the device. |

### 7e. Hidden pictures (GDD 5.3)

Flat, friendly space illustrations, 1008 x 1152 px (field size), one per level: background = the world crystal tint as a vertical ramp, big simple shapes with 4-8 px light outlines, white 4-point sparkle stars. Do not use ball coral or beam gold at full strength in pictures (those two colours belong to the actors). Suggested breather subjects: W1 L5 a sunrise over the home planet, W2 L10 the ringed planet with a rocket, W3 L15 the storm eye with a friendly satellite, W4 L20 a comet over the asteroid belt, W5 L25 the ice moon with a lander, W6 L30 the galaxy with a starship. Level 3 sample: `assets/textures/pictures/w1_l3_ringplanet.png`.

### 7f. Four questions (premium 3D rule)

| Feature | Noticed at camera distance? | Phone cost | Cheaper trick | Fits spec? | Verdict |
|---|---|---|---|---|---|
| Faceted crystal tiles with picture | Yes: it is the reward and 30-60% of the screen | 1 MultiMesh, 22 tris each, 1 texture read | Flat quads with a facet normal map (fallback if the tablet struggles) | Yes | Keep |
| Post glow | Yes, it sells "light beam" and "energy" | One fixed pass | Halo quads (kept as fallback) | Yes | Keep, 3 levels |
| Lit planets as 3D spheres | Barely: they sit behind 70% glass | Shading 2 big spheres | Pre-rendered alpha cards | Yes | Cards only |
| Real-time shadows | No: flat field, face-on camera | Shadow pass | None needed | No | Cut |
| Animated nebula | No at play speed | Full-screen shader | Static texture + camera drift parallax | Yes | Static |
| Bubble pop particles | Yes: it teaches "pops are harmless" | 12 quads | n/a | Yes | Keep |
| Ball trails | Yes: shows direction to a child who must predict | 1 ribbon per ball | n/a | Yes | Keep |
| Storm lightning (W3) | Yes, but a flash risk | Small | Slow glow pulse at 0.5 Hz inside the clouds | Rule 37 | Pulse only |

## 8. Do and don't

- Do: keep gold only for what the child makes or picks (beam, chosen button, star, next disc), coral only for balls.
- Do: keep the ball core the brightest small thing on screen; dim backdrop elements before it drops under 4.5:1.
- Do: show every state by shape (dots vs dashes vs solid, ring count, facets vs grid) as in 7b.
- Do: keep the camera flat-on; depth comes from backdrop layers.
- Don't: split a wall into two colours, turn captured area black, use grey tiles or red-white balls (JezzBall's look).
- Don't: add a horizon, perspective grid floor, sun, palms, hotpink rails or a ring gate (Neon Bricks' look); don't make cyan the player colour.
- Don't: use purple in UI chrome (panels, buttons, card); purple stays in game content.
- Don't: put text anywhere in play, map or win card; don't draw in the 232 x 232 square except the home disc.
- Don't: share this look with other MWM games.

## 9. Store assets (later)

- **Icon 512x512:** one coral ringed orb caught between two crossing gold beams over a crystal corner, on the deep-space gradient. Must read at 48 px: one orb, two beams, no text.
- **Feature graphic 1024x500:** the field at an angle over the planet limb, half crystal with a picture, a gold beam closing the last room. Name on the dark sky side.
- **Screenshots (capture bot only):** level 3 with Snegl active (spirals on the balls), level 4 with stones, the win card after level 5.

## 10. Visual tier

**Premium stylized 3D.** The hero scene is world 1 level 3 as in `world1_mock.png`; the owner signs it off from the builder's real Godot screenshot (not this mock) before worlds 2-6 are built. The one thing the builder must not change: **captured area becomes bright faceted crystal that shows the picture, edged by a white rim, while open field stays dark glass.** That contrast is the whole read of the game.

### Four questions before any visual feature
1. Will the player notice it at the real camera distance?
2. What does it cost on the phone GPU (draw calls, overdraw, shader cost)?
3. Can a cheaper trick (baked light, texture, vertex color, fake shadow) get the same look?
4. Does it fit this spec?
