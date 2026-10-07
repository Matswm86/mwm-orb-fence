class_name OfBalance
extends RefCounted

## Every tunable number of MWM Orb Fence (GDD section 7). Distances are logic
## px on the 1080 x 1920 design frame; 1 px = 0.01 m on the play plane.
## Lett/Vanlig pairs are picked with the helpers at the bottom.

# --- Layout (GDD 3.2, 4.1; DESIGN 5) ---
const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0
const FIELD_ORIGIN := Vector2(36.0, 256.0)
## The field rect never moves (GDD 6.4b); only the grid inside it changes.
const FIELD_W: float = 1008.0
const FIELD_H: float = 1152.0
const HOME_SQUARE: float = 232.0
const WRIST_STRIP: float = 256.0
const DIR_CENTERS: Array[Vector2] = [Vector2(330.0, 1540.0), Vector2(750.0, 1540.0)]
const DIR_HIT: float = 240.0
const CHOSEN_R: float = 108.0
const UNCHOSEN_R: float = 88.0

# --- Grids (GDD 4.1, 6.4b, 7): one per field size, per level data -------
## "14x16" in worlds 1-3 and small Uendelig rounds, "21x24" in worlds 4-6
## and Uendelig from ENDLESS_FIELD_SWITCH_BALLS balls. Same 1008 x 1152 rect.
## Sizes are logic px; wall speeds cells/s per half (same px/s on both);
## cage = CAGE_CELLS; capture_m / capture_l = capture sound size thresholds
## in cells (GDD 9); spawn = [col min, col max, row min, row max].
const GRIDS: Dictionary = {
	"14x16":
	{
		"cols": 14,
		"rows": 16,
		"cell": 72.0,
		"ball_r": 24.0,
		"stor_r": 34.0,
		"kvikk_r": 18.0,
		"wall_lett": 14.0,
		"wall_vanlig": 10.0,
		"cage_lett": 12,
		"cage_vanlig": 8,
		"capture_m": 14,
		"capture_l": 40,
		"spawn": [2, 11, 2, 13],
	},
	"21x24":
	{
		"cols": 21,
		"rows": 24,
		"cell": 48.0,
		"ball_r": 20.0,
		"stor_r": 28.0,
		"kvikk_r": 15.0,
		"wall_lett": 21.0,
		"wall_vanlig": 15.0,
		"cage_lett": 27,
		"cage_vanlig": 18,
		"capture_m": 32,
		"capture_l": 90,
		"spawn": [2, 18, 2, 21],
	},
}
## Largest grid: sizes the crystal / ice MultiMesh pools (21 x 24 = 504).
const MAX_CELLS: int = 504

# --- Balls (GDD 4.2, 5.1) ---
## Reference radius of the 3D ball mesh and of the bounce pitch (GDD 9).
const BALL_RADIUS: float = 24.0
const STOR_SPEED_MULT: float = 0.8
const KVIKK_SPEED_MULT_LETT: float = 1.15
const KVIKK_SPEED_MULT_VANLIG: float = 1.3
const CAGED_BALL_SCALE: float = 0.7
const BALL_ANGLE_MIN_DEG: float = 35.0
const BALL_ANGLE_MAX_DEG: float = 55.0
const SUBSTEP_MAX_PX: float = 8.0

# --- Walls (GDD 4.3); speeds per grid above ---
const MAX_GROWING_WALLS: int = 1

# --- Sparks and gentle restart (GDD 4.4, 4.7) ---
## 3 x balls, no max (owner 2026-10-07; the old max of 24 is gone).
const SPARKS_PER_BALL: int = 3
const RESTART_DIM_S: float = 0.6
const RESTART_REWIND_S: float = 0.8
const RESTART_LIFT_S: float = 0.4
const RESTART_DIM_LEVEL: float = 0.6

# --- Tokens (GDD 5.2) ---
const SNEGL_FACTOR: float = 0.6
const SNEGL_S_LETT: float = 10.0
const SNEGL_S_VANLIG: float = 8.0
const TOKEN_SPIN_REV_S: float = 0.5
const SNEGL_PITCH: float = 0.94
const SNEGL_PITCH_WIND_S: float = 0.5
const LYN_FACTOR: float = 2.5
const LYN_WALLS: int = 2
const SKJOLD_WALLS: int = 1
const MIRROR_COOLDOWN_S: float = 0.2
## Max tokens on one level (GDD 5.2 says 2; table 6.3 L29 has 1 of each = 3).
const MAX_TOKENS: int = 3

# --- Difficulty ramp (GDD 6.3, 7) ---
const WORLD_BASE_SPEED_LETT: Array[float] = [200.0, 210.0, 220.0, 230.0, 240.0, 250.0]
const WORLD_BASE_SPEED_VANLIG: Array[float] = [320.0, 340.0, 360.0, 380.0, 400.0, 420.0]
const LEVEL_SPEED_STEP_LETT: float = 5.0
const LEVEL_SPEED_STEP_VANLIG: float = 10.0
const TARGET_LETT: float = 0.65
const TARGET_VANLIG: float = 0.75
const TARGET_BREATHER_LETT: float = 0.60
const TARGET_BREATHER_VANLIG: float = 0.70
## Cage rule from this level on (GDD 4.5).
const CAGE_FROM_LEVEL: int = 6
const LEVELS_PER_WORLD: int = 5
const WORLDS: int = 6

# --- Uendelig (GDD 6.5, 7) ---
const ENDLESS_BALLS_CAP_LETT: int = 10
const ENDLESS_BALLS_CAP_VANLIG: int = 13
const ENDLESS_SPEED_BASE_LETT: float = 200.0
const ENDLESS_SPEED_BASE_VANLIG: float = 320.0
const ENDLESS_SPEED_STEP_LETT: float = 5.0
const ENDLESS_SPEED_STEP_VANLIG: float = 10.0
const ENDLESS_SPEED_CAP_LETT: float = 245.0
const ENDLESS_SPEED_CAP_VANLIG: float = 430.0
const ENDLESS_FIELD_SWITCH_BALLS: int = 9
const ENDLESS_SNEGL_FROM_ROUND: int = 3
## Every 5th round shows the full win card (GDD 6.5).
const ENDLESS_FULL_CARD_EVERY: int = 5
## The disc on the map appears once this level is cleared (GDD 6.5).
const ENDLESS_UNLOCK_LEVEL: int = 5
const ENDLESS_SWITCH_PITCH: float = 0.84
## Cage close (GDD 9): lock at this pitch, then the capture chime later.
const CAGE_LOCK_PITCH: float = 1.26
const CAGE_CHIME_DELAY_S: float = 0.12

# --- Input (GDD 3.3) ---
const GHOST_HYSTERESIS: float = 0.6
const HOLDOVER_MS: int = 300
const GHOST_TICK_MAX_PER_S: int = 10

# --- Hints (GDD 8.3) ---
const HINT_IDLE_S_LETT: float = 7.0
const HINT_IDLE_S_VANLIG: float = 12.0
const HINT_POPS: int = 2
const HINT_POP_WINDOW_S: float = 10.0
const HINT_GLOW_S: float = 1.5
const HAND_FIRST_S: float = 1.0
const HAND_LOOP_S: float = 2.4
const TURN_PULSE_S: float = 2.0

# --- Feel (GDD 9, DESIGN 6) ---
const MAX_FLASHES_PER_S: int = 3
const POP_ANIM_S: float = 0.25
const BUBBLES_PER_POP: int = 10
const CAPTURE_WAVE_S: float = 0.3
const CELL_GROW_S: float = 0.12
const CAPTURE_PULSE_S: float = 0.35
const BOUNCE_SOUNDS_PER_S: int = 6
const GROW_TICK_EVERY: int = 3
const GROW_TICKS_MAX_PER_S: int = 10
const CLEAR_SLOWMO_SCALE: float = 0.3
const CLEAR_SLOWMO_S: float = 0.5
const CLEAR_PICTURE_FADE_S: float = 0.8
const CLEAR_STAR_STAGGER_S: float = 0.12
const WIN_CARD_DELAY_S: float = 1.4
const WIN_CARD_FADE_S: float = 0.25
const PUSH_IN: float = 0.06
const SHAKE_PX: float = 8.0
const SHAKE_S: float = 0.2
const INTRO_FRAME_S: float = 0.8
const DRIFT_DEG: float = 1.0
const DRIFT_PERIOD_S: float = 14.0
const METER_EASE_S: float = 0.2
const MILESTONES: Array[float] = [0.25, 0.5, 0.75]
## Rare ambient spaceship pass-by during play, random gap in seconds.
const AMBIENT_PASS_MIN_S: float = 40.0
const AMBIENT_PASS_MAX_S: float = 90.0

# --- Home guard (GDD 3.3, copies the MWM Play shell) ---
const HOME_GUARD_S: float = 2.0
const HOME_GUARD_MIN_S: float = 0.3

# --- Free part (GDD 6.1) ---
const FREE_LEVELS: int = 3

# --- Rendering (DESIGN 6a) ---
const PX_TO_M: float = 0.01
const CAM_DIST: float = 30.0
const CAM_Y: float = 9.6
const CAM_NEAR: float = 1.0


static func grid(field: String) -> Dictionary:
	return GRIDS.get(field, GRIDS["14x16"])


static func wall_speed(easy: bool, field: String = "14x16") -> float:
	var g: Dictionary = grid(field)
	return float(g["wall_lett"] if easy else g["wall_vanlig"])


static func cage_cells(easy: bool, field: String = "14x16") -> int:
	var g: Dictionary = grid(field)
	return int(g["cage_lett"] if easy else g["cage_vanlig"])


static func kvikk_mult(easy: bool) -> float:
	return KVIKK_SPEED_MULT_LETT if easy else KVIKK_SPEED_MULT_VANLIG


static func snegl_s(easy: bool) -> float:
	return SNEGL_S_LETT if easy else SNEGL_S_VANLIG


static func hint_idle_s(easy: bool) -> float:
	return HINT_IDLE_S_LETT if easy else HINT_IDLE_S_VANLIG


## Vanlig spark budget for a level: 0 = unlimited (Lett, world 1, breathers).
static func spark_budget(easy: bool, level_sparks: int) -> int:
	if easy:
		return 0
	return level_sparks


static func default_budget(balls: int) -> int:
	return SPARKS_PER_BALL * balls


## Ball speed of level l (1-5) in world w (1-6), GDD 6.3: W1 flat; W2-6
## base + step per level L1-L4, L5 (breather) = base.
static func level_speed(easy: bool, w: int, l: int) -> float:
	var base: float = (WORLD_BASE_SPEED_LETT if easy else WORLD_BASE_SPEED_VANLIG)[w - 1]
	if w == 1 or l == LEVELS_PER_WORLD:
		return base
	return base + (LEVEL_SPEED_STEP_LETT if easy else LEVEL_SPEED_STEP_VANLIG) * float(l - 1)


## Ball count of level l in world w, GDD 6.3.
static func level_balls(easy: bool, w: int, l: int) -> int:
	if w == 1:
		return ([1, 2, 2, 2, 2] if easy else [2, 3, 3, 4, 4])[l - 1]
	var n: int = w if easy else 2 * w + 1
	return n if l <= 2 else n + 1


static func endless_balls(easy: bool, k: int) -> int:
	if easy:
		return mini(k, ENDLESS_BALLS_CAP_LETT)
	return mini(k + 1, ENDLESS_BALLS_CAP_VANLIG)


static func endless_speed(easy: bool, k: int) -> float:
	if easy:
		return minf(
			ENDLESS_SPEED_BASE_LETT + ENDLESS_SPEED_STEP_LETT * float(k - 1), ENDLESS_SPEED_CAP_LETT
		)
	return minf(
		ENDLESS_SPEED_BASE_VANLIG + ENDLESS_SPEED_STEP_VANLIG * float(k - 1),
		ENDLESS_SPEED_CAP_VANLIG
	)
