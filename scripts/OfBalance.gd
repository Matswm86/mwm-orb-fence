class_name OfBalance
extends RefCounted

## Every tunable number of MWM Orb Fence (GDD section 7). Distances are logic
## px on the 1080 x 1920 design frame; 1 px = 0.01 m on the play plane.
## Lett/Vanlig pairs are picked with the helpers at the bottom.

# --- Layout (GDD 3.2, 4.1; DESIGN 5) ---
const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0
const FIELD_ORIGIN := Vector2(36.0, 256.0)
const CELL: float = 72.0
const COLS: int = 14
const ROWS: int = 16
const FIELD_W: float = CELL * COLS
const FIELD_H: float = CELL * ROWS
const HOME_SQUARE: float = 232.0
const WRIST_STRIP: float = 256.0
const DIR_CENTERS: Array[Vector2] = [Vector2(330.0, 1540.0), Vector2(750.0, 1540.0)]
const DIR_HIT: float = 240.0
const CHOSEN_R: float = 108.0
const UNCHOSEN_R: float = 88.0

# --- Balls (GDD 4.2) ---
const BALL_RADIUS: float = 24.0
const BALL_ANGLE_MIN_DEG: float = 35.0
const BALL_ANGLE_MAX_DEG: float = 55.0
const SUBSTEP_MAX_PX: float = 8.0
const SPAWN_COL_MIN: int = 2
const SPAWN_COL_MAX: int = 11
const SPAWN_ROW_MIN: int = 2
const SPAWN_ROW_MAX: int = 13

# --- Walls (GDD 4.3) ---
const WALL_SPEED_LETT: float = 14.0
const WALL_SPEED_VANLIG: float = 10.0
const MAX_GROWING_WALLS: int = 1

# --- Sparks and gentle restart (GDD 4.4, 4.7) ---
const SPARKS_PER_BALL: int = 3
const SPARKS_MAX: int = 24
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


static func wall_speed(easy: bool) -> float:
	return WALL_SPEED_LETT if easy else WALL_SPEED_VANLIG


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
	return mini(SPARKS_PER_BALL * balls, SPARKS_MAX)
