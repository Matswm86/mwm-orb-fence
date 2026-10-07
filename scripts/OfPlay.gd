class_name OfPlay
extends Node

## One level or Uendelig round in play: owns the OfSim, reads touches
## (direction buttons; press-see-release ghost wall in the field with snap
## and hysteresis), feeds sim events to OfWorld, OfSfx, the HUD, the 2D
## effects and the flash limiter, runs the hint rule and the onboarding hand,
## the level-clear sequence and the win / round card (GDD 3, 6.5, 8, 9).

signal map_requested
signal level_started(id: int)

## Test hooks (capture bot / headless tests only).
var autopilot: bool = false
## >= 0 forces a Vanlig spark budget (GDD 12: W1 is unlimited, so the spark
## bar and the gentle restart are covered with this test-only flag).
var test_sparks: int = -1

var sim: OfSim
var world: OfWorld
var sfx: OfSfx
var music: OfMusic
var level_id: int = 1
## Uendelig round in play; 0 = a normal level.
var endless_round: int = 0
var active: bool = false
var paused: bool = false

var hud: OfHud
var buttons: OfDirButtons
var fx: OfFieldFx
var win_card: OfWinCard
var dim_rect: ColorRect
var resume_disc: OfDisc

var _bottom: Control
var _top: Control
var _limiter := OfFlashLimiter.new()
var _bot := OfBot.new()
var _picture: Texture2D
var _clock_s: float = 0.0
var _level_t: float = 0.0
var _slowmo_t: float = -1.0
var _card_t: float = -1.0
var _card_shown: bool = false
var _holdover_until_ms: int = 0

# Input state.
var _field_ptr: int = -1
var _field_pos: Vector2 = Vector2.ZERO
var _ghost_cell: Vector2i = Vector2i(-1, -1)
var _btn_ptr: Dictionary = {}
var _ghost_ticks: Array[float] = []
var _grow_ticks: Array[float] = []

# Hints and onboarding.
var _idle_t: float = 0.0
var _last_hint_t: float = -99.0
var _hints_shown: int = 0
var _touched_field: bool = false
## The child tapped a direction button: the onboarding hand stops for good.
var _touched_dir: bool = false
var _turn_pulse_done: bool = false
var _hand_line: Dictionary = {}
var _hand_ghost: bool = false
var _snegl_was_on: bool = false
## Field of the previous Uendelig round (the warp-in drops in pitch when the
## field switches to 21 x 24, GDD 9).
var _prev_field: String = ""
var _new_best: bool = false
## Delayed sounds: [real seconds left, key, pitch] (cage chime after lock).
var _later: Array[Array] = []
## Seconds until the next quiet ambient spaceship pass-by (GDD 9 addendum).
var _ambient_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(
	w: OfWorld,
	s: OfSfx,
	m: OfMusic,
	top_frame: Control,
	bottom_frame: Control,
	center_frame: Control,
	screen_root: Control
) -> void:
	world = w
	sfx = s
	music = m
	_top = top_frame
	_bottom = bottom_frame
	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(dim_rect)
	screen_root.move_child(dim_rect, 0)
	fx = OfFieldFx.new()
	bottom_frame.add_child(fx)
	buttons = OfDirButtons.new()
	bottom_frame.add_child(buttons)
	hud = OfHud.new()
	top_frame.add_child(hud)
	win_card = OfWinCard.new()
	center_frame.add_child(win_card)
	win_card.replay_pressed.connect(_on_replay)
	win_card.map_pressed.connect(func() -> void: map_requested.emit())
	win_card.next_pressed.connect(_on_next)
	resume_disc = OfDisc.new()
	resume_disc.icon = "play"
	resume_disc.disc_radius = 120.0
	resume_disc.size = Vector2(300, 300)
	resume_disc.position = Vector2(540 - 150, 960 - 150)
	resume_disc.visible = false
	resume_disc.tapped.connect(resume)
	center_frame.add_child(resume_disc)
	show_hud(false)
	set_process(false)


func show_hud(on: bool) -> void:
	hud.visible = on
	buttons.visible = on
	fx.visible = on


func start_level(id: int) -> void:
	level_id = id
	endless_round = 0
	_prev_field = ""
	level_started.emit(id)
	_start(OfLevels.config(id, OrbFence.easy))


## Uendelig round k (GDD 6.5). Round 1 starts a new run.
func start_endless(k: int) -> void:
	level_id = 0
	if k <= 1:
		_prev_field = ""
	endless_round = maxi(k, 1)
	level_started.emit(0)
	_start(OfLevels.endless_config(endless_round, OrbFence.easy))


func _start(c: Dictionary) -> void:
	var easy: bool = OrbFence.easy
	var lm: bool = OrbFence.less_motion
	sim = OfSim.new()
	sim.rng.randomize()
	sim.setup_config(c, easy, test_sparks)
	_connect_sim()
	_picture = load(String(c["picture"])) as Texture2D
	world.show_gameplay(true)
	world.set_less_motion(lm)
	world.bind_level(sim, _picture, int(c["world"]))
	world.start_intro()
	world.reset_camera_fx()
	hud.less_motion = lm
	hud.reset(sim.target, not easy, sim.spark_budget)
	hud.set_tint(OfLevels.world(int(c["world"]))["tint"])
	if endless_round > 0:
		hud.set_endless(endless_round, OrbFence.best_round(easy), _limiter.allow(_clock_s))
	else:
		hud.set_endless(0, 0, false)
	buttons.less_motion = lm
	buttons.chosen = 0
	buttons.lyn_charges = 0
	fx.less_motion = lm
	fx.cell = sim.cell
	fx.clear_all()
	win_card.less_motion = lm
	win_card.hide_card()
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	show_hud(true)
	Engine.time_scale = 1.0
	sfx.pitch_mult = 1.0
	music.set_pitch(1.0, 0.1)
	_slowmo_t = -1.0
	_card_t = -1.0
	_card_shown = false
	_field_ptr = -1
	_ghost_cell = Vector2i(-1, -1)
	_btn_ptr.clear()
	_level_t = 0.0
	_idle_t = 0.0
	_last_hint_t = -99.0
	_hints_shown = 0
	_touched_field = false
	_touched_dir = false
	_turn_pulse_done = false
	_hand_line = {}
	_hand_ghost = false
	_snegl_was_on = false
	_new_best = false
	_later.clear()
	_rng.randomize()
	_ambient_t = _next_ambient_s()
	paused = false
	_holdover_until_ms = Time.get_ticks_msec() + OfBalance.HOLDOVER_MS
	OfDisc.block_input(OfBalance.HOLDOVER_MS)
	active = true
	set_process(true)
	if not lm:
		var switched: bool = endless_round > 0 and _prev_field == "14x16" and sim.field == "21x24"
		sfx.play("intro", OfBalance.ENDLESS_SWITCH_PITCH if switched else 1.0)
	_prev_field = sim.field
	if OrbFence.first_launch:
		OrbFence.first_launch = false
		OrbFence.save_game()


func stop() -> void:
	active = false
	set_process(false)
	Engine.time_scale = 1.0
	sfx.zip_stop()
	sfx.pitch_mult = 1.0
	music.set_pitch(1.0, 0.1)
	fx.clear_all()
	win_card.hide_card()
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	show_hud(false)
	world.reset_camera_fx()


func card_visible() -> bool:
	return _card_shown


func _connect_sim() -> void:
	sim.wall_started.connect(_on_wall_started)
	sim.wall_grew.connect(_on_wall_grew)
	sim.half_popped.connect(_on_half_popped)
	sim.wall_finished.connect(_on_wall_finished)
	sim.wall_vanished.connect(_on_wall_vanished)
	sim.captured.connect(_on_captured)
	sim.caged.connect(_on_caged)
	sim.ball_bounced.connect(_on_bounce)
	sim.mirror_bounced.connect(_on_mirror)
	sim.token_taken.connect(_on_token)
	sim.milestone_reached.connect(_on_milestone)
	sim.spark_lost.connect(_on_spark_lost)
	sim.restart_started.connect(_on_restart)
	sim.restart_reset.connect(_on_restart_reset)
	sim.level_cleared.connect(_on_cleared)


## Field-local px -> bottom-frame px.
static func field_px(p: Vector2) -> Vector2:
	return p + OfBalance.FIELD_ORIGIN


func cell_px(c: Vector2i) -> Vector2:
	return field_px(sim.cell_center(c))


## The meter star in bottom-frame px (it lives in the top frame).
func star_in_bottom() -> Vector2:
	return hud.star_pos() + _top.position - _bottom.position


# ---------------------------------------------------------------- loop


func _process(_delta: float) -> void:
	if not active:
		return
	var real_dt: float = minf(get_process_delta_time() / maxf(Engine.time_scale, 0.01), 0.1)
	if paused:
		return
	_clock_s += real_dt
	_slowmo(real_dt)
	var game_dt: float = real_dt * Engine.time_scale
	if autopilot and not _card_shown:
		var pick: Dictionary = _bot.tick(sim, game_dt)
		if not pick.is_empty():
			buttons.chosen = 0 if bool(pick["vertical"]) else 1
			_idle_t = 0.0
	if not _card_shown:
		sim.step(game_dt)
		_ambient(real_dt)
	buttons.lyn_charges = sim.lyn_charges
	fx.shield_ghost = sim.shield_ready
	_run_later(real_dt)
	world.sync(sim, real_dt, game_dt)
	world.sync_camera(real_dt)
	hud.set_fill(sim.fill_ratio())
	dim_rect.color = Color(0, 0, 0, sim.restart_dim() * OfBalance.RESTART_DIM_LEVEL)
	_level_t += real_dt
	if sim.state == OfSim.State.PLAY:
		_idle_t += real_dt
		_update_hints()
	_update_snegl()
	if _card_t >= 0.0 and not _card_shown:
		_card_t += real_dt
		if _card_t >= OfBalance.WIN_CARD_DELAY_S:
			_show_card()


func _slowmo(real_dt: float) -> void:
	if _slowmo_t < 0.0:
		return
	_slowmo_t += real_dt
	if _slowmo_t < OfBalance.CLEAR_SLOWMO_S and not OrbFence.less_motion:
		Engine.time_scale = OfBalance.CLEAR_SLOWMO_SCALE
	else:
		Engine.time_scale = 1.0
		_slowmo_t = -1.0


## A rare, very quiet spaceship flies past (left to right) while the level is
## in play. OfSfx drops it when sound is off.
func _ambient(real_dt: float) -> void:
	if sim.state != OfSim.State.PLAY:
		return
	_ambient_t -= real_dt
	if _ambient_t <= 0.0:
		_ambient_t = _next_ambient_s()
		sfx.play("pass_by")


func _run_later(dt: float) -> void:
	for item: Array in _later:
		item[0] = float(item[0]) - dt
		if float(item[0]) <= 0.0:
			sfx.play(String(item[1]), float(item[2]))
	_later = _later.filter(func(item: Array) -> bool: return float(item[0]) > 0.0)


func _next_ambient_s() -> float:
	return _rng.randf_range(OfBalance.AMBIENT_PASS_MIN_S, OfBalance.AMBIENT_PASS_MAX_S)


func _update_snegl() -> void:
	var on: bool = sim.snegl_t > 0.0
	if on == _snegl_was_on:
		return
	_snegl_was_on = on
	var p: float = OfBalance.SNEGL_PITCH if on else 1.0
	sfx.pitch_mult = p
	music.set_pitch(p, OfBalance.SNEGL_PITCH_WIND_S)


# ---------------------------------------------------------------- hints


func _update_hints() -> void:
	# Onboarding hand: level 1, until the child first touches the field or a
	# direction button. It shows a line in the CURRENTLY chosen direction and
	# never changes the choice (GDD 3.3: up-down is pre-chosen).
	var want_hand: bool = (
		level_id == 1
		and not _touched_field
		and not _touched_dir
		and sim.walls_started == 0
		and _level_t >= OfBalance.HAND_FIRST_S
		and not autopilot
	)
	if want_hand and not fx.hand_visible:
		_hand_line = sim.best_line(buttons.chosen, true)
		fx.restart_hand()
	fx.hand_visible = want_hand and not _hand_line.is_empty()
	if fx.hand_visible:
		fx.hand_at = cell_px(_hand_line["origin"])
		var pressing: bool = fx.hand_pressing()
		if pressing and not _hand_ghost and _field_ptr < 0:
			_hand_ghost = true
			_show_ghost_for(_hand_line["origin"], true)
			_ghost_cell = Vector2i(-1, -1)
		elif not pressing and _hand_ghost:
			_hand_ghost = false
			fx.blink_ghost()
			fx.hide_ghost(0)
		return
	if _hand_ghost:
		_hand_ghost = false
		fx.hide_ghost(0)
	if autopilot or not sim.can_start_wall():
		return
	var lett_pops: bool = (
		sim.easy and sim.recent_pops(OfBalance.HINT_POP_WINDOW_S) >= OfBalance.HINT_POPS
	)
	var idle: bool = _idle_t >= OfBalance.hint_idle_s(sim.easy)
	var since: float = _clock_s - _last_hint_t
	if (idle or (lett_pops and since > OfBalance.HINT_POP_WINDOW_S)) and since > 2.0:
		show_hint()


## Glow the best line for 1.5 s and the matching direction button.
func show_hint() -> void:
	var only: int = -1
	if level_id == 2 and _hints_shown == 0:
		only = 1
	var line: Dictionary = sim.best_line(only, true)
	if line.is_empty():
		return
	_hints_shown += 1
	_last_hint_t = _clock_s
	_idle_t = 0.0
	var pts: Array[Vector2] = []
	for c: Vector2i in line["cells"]:
		pts.append(cell_px(c))
	fx.show_hint(pts)
	buttons.glow(0 if bool(line["vertical"]) else 1, OfBalance.HINT_GLOW_S)
	sfx.play("shimmer")


# ---------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	if not active or paused or _card_shown:
		return
	var st := event as InputEventScreenTouch
	if st:
		_on_touch(st)
		return
	var dr := event as InputEventScreenDrag
	if dr and dr.index == _field_ptr:
		_field_pos = dr.position - world.frame_offset()
		_move_ghost()


func _in_field(p: Vector2) -> bool:
	var r := Rect2(OfBalance.FIELD_ORIGIN, Vector2(OfBalance.FIELD_W, OfBalance.FIELD_H))
	return r.has_point(p)


func _on_touch(st: InputEventScreenTouch) -> void:
	var p: Vector2 = st.position - world.frame_offset()
	if st.pressed:
		_on_press(st, p)
	else:
		_on_release(st, p)


func _on_press(st: InputEventScreenTouch, p: Vector2) -> void:
	if Time.get_ticks_msec() < _holdover_until_ms:
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	if st.position.y >= vh - OfBalance.WRIST_STRIP:
		return
	var b: int = OfDirButtons.hit(p)
	if b >= 0:
		_btn_ptr[st.index] = b
		_touched_dir = true
		buttons.set_down(b, true)
		sfx.play("tap")
		return
	if not _in_field(p) or sim.state != OfSim.State.PLAY:
		return
	# Latest touch wins (rule 14).
	_field_ptr = st.index
	_field_pos = p
	_touched_field = true
	_idle_t = 0.0
	_hand_ghost = false
	fx.hand_visible = false
	var c: Vector2i = sim.ghost_cell_for(p - OfBalance.FIELD_ORIGIN)
	if c.x < 0:
		_ghost_cell = Vector2i(-1, -1)
		fx.hide_ghost(2)
		sfx.play("notyet", 1.2, -6.0)
		return
	_show_ghost_for(c, true)
	sfx.play("tick_in")


func _on_release(st: InputEventScreenTouch, p: Vector2) -> void:
	if _btn_ptr.has(st.index):
		var bi: int = _btn_ptr[st.index]
		_btn_ptr.erase(st.index)
		buttons.set_down(bi, false)
		if OfDirButtons.hit(p) == bi:
			_choose_dir(bi)
		return
	if st.index != _field_ptr:
		return
	_field_ptr = -1
	var origin: Vector2i = _ghost_cell
	_ghost_cell = Vector2i(-1, -1)
	if origin.x < 0 or not _in_field(p):
		# Sliding off the field and letting go cancels, no penalty, no sound.
		fx.hide_ghost(0)
		return
	if not sim.can_start_wall():
		fx.hide_ghost(1)
		sfx.play("notyet")
		return
	fx.hide_ghost(2)
	sim.start_wall(origin, buttons.chosen == 0)


func _choose_dir(i: int) -> void:
	if buttons.chosen == i:
		return
	buttons.chosen = i
	sfx.play("dir_pick", 1.0 if i == 0 else 1.1225)
	if _field_ptr >= 0 and _ghost_cell.x >= 0:
		_show_ghost_for(_ghost_cell, false)


func _show_ghost_for(c: Vector2i, fresh: bool) -> void:
	_ghost_cell = c
	var vertical: bool = buttons.chosen == 0
	var pts: Array[Vector2] = []
	for gc: Vector2i in sim.ghost_extent(c, vertical):
		pts.append(cell_px(gc))
	fx.show_ghost(pts, cell_px(c), vertical, fresh)


## Ghost follows the finger cell by cell; it moves to a new cell only when
## the finger is 0.6 cell into it (GDD 3.3 hysteresis).
func _move_ghost() -> void:
	if _ghost_cell.x < 0:
		var c0: Vector2i = sim.ghost_cell_for(_field_pos - OfBalance.FIELD_ORIGIN)
		if c0.x >= 0 and _in_field(_field_pos):
			_show_ghost_for(c0, true)
		return
	var f: Vector2 = _field_pos - OfBalance.FIELD_ORIGIN
	var cell: float = sim.cell
	var hy: float = OfBalance.GHOST_HYSTERESIS * cell
	var cur: Vector2i = _ghost_cell
	var nx: int = cur.x
	var ny: int = cur.y
	var fx_i: int = floori(f.x / cell)
	var fy_i: int = floori(f.y / cell)
	if fx_i > cur.x:
		nx = maxi(cur.x, floori((f.x - hy) / cell))
	elif fx_i < cur.x:
		nx = mini(cur.x, floori((f.x + hy) / cell))
	if fy_i > cur.y:
		ny = maxi(cur.y, floori((f.y - hy) / cell))
	elif fy_i < cur.y:
		ny = mini(cur.y, floori((f.y + hy) / cell))
	var want := Vector2i(clampi(nx, 0, sim.cols - 1), clampi(ny, 0, sim.rows - 1))
	if want == cur:
		return
	var c: Vector2i = want
	if sim.get_cell(c) != OfSim.Cell.EMPTY:
		c = sim.ghost_cell_for(f)
		if c.x < 0 or c == cur:
			return
	_show_ghost_for(c, false)
	if _rate_ok(_ghost_ticks, OfBalance.GHOST_TICK_MAX_PER_S):
		sfx.play("ghost_tick")


func _rate_ok(times: Array[float], per_s: int) -> bool:
	while not times.is_empty() and _clock_s - times[0] >= 1.0:
		times.pop_front()
	if times.size() >= per_s:
		return false
	times.append(_clock_s)
	return true


# ---------------------------------------------------------------- sim events


func _on_wall_started(_origin: Vector2i, _vertical: bool) -> void:
	_idle_t = 0.0
	world.on_wall_started()
	sfx.play("wall_start")
	sfx.zip_start()


func _on_wall_grew(_half: int, _cell: Vector2i) -> void:
	if sim.wall == null:
		return
	var n: int = 0
	for h: OfSim.Half in sim.wall.halves:
		n = maxi(n, h.cells.size())
	if n % OfBalance.GROW_TICK_EVERY == 0 and _rate_ok(_grow_ticks, OfBalance.GROW_TICKS_MAX_PER_S):
		sfx.play("grow_tick", 1.0 + 0.04 * n)


func _on_half_popped(_half: int, cells: Array[Vector2i], at: Vector2) -> void:
	var pts: Array[Vector2] = []
	for c: Vector2i in cells:
		pts.append(cell_px(c))
	if pts.is_empty():
		pts.append(field_px(at))
	fx.pop_bubbles(pts)
	sfx.play("pop")
	var best: int = -1
	var best_d: float = INF
	for i: int in sim.balls.size():
		var d: float = sim.balls[i].pos.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = i
	world.on_ball_squash(best)
	if sim.wall == null:
		sfx.zip_stop()


func _on_wall_finished(_cells: Array[Vector2i], _vertical: bool) -> void:
	sfx.zip_stop()
	sfx.play("lock")
	world.on_wall_finished(sim)


func _on_wall_vanished() -> void:
	sfx.zip_stop()
	world.on_wall_vanished()


func _on_captured(cells: Array[Vector2i], delays: PackedFloat32Array) -> void:
	var spike: bool = _limiter.allow(_clock_s)
	world.on_captured(sim, cells, delays, spike)
	sfx.capture(cells.size(), int(sim.grid_value("capture_m")), int(sim.grid_value("capture_l")))
	if level_id == 1 and not _turn_pulse_done:
		_turn_pulse_done = true
		buttons.glow(1, OfBalance.TURN_PULSE_S)


## Cage closes (GDD 9): lock at x1.26, then the room's capture chime 120 ms
## later; bars slide down over the room, its balls shrink and stop.
func _on_caged(cells: Array[Vector2i], _balls: Array[int]) -> void:
	world.on_caged(sim, cells)
	var pts: Array[Vector2] = []
	for c: Vector2i in cells:
		pts.append(cell_px(c))
	fx.add_cage(pts)
	sfx.play("lock", OfBalance.CAGE_LOCK_PITCH)
	var key: String = sfx.capture_key(
		cells.size(), int(sim.grid_value("capture_m")), int(sim.grid_value("capture_l"))
	)
	_later.append([OfBalance.CAGE_CHIME_DELAY_S, key, 1.0])


func _on_mirror(i: int, c: Vector2i) -> void:
	if i < sim.balls.size():
		sfx.mirror(sim.balls[i].radius)
	if not OrbFence.less_motion:
		fx.mirror_glint(cell_px(c), sim.mirror_at(c))


func _on_bounce(i: int, pos: Vector2) -> void:
	if i < sim.balls.size():
		sfx.bounce(sim.balls[i].radius)
	fx.spark(field_px(pos))


func _on_token(kind: String, cell: Vector2i) -> void:
	world.on_token_taken(cell)
	sfx.play(kind)
	if kind == "lyn":
		buttons.lyn_charges = sim.lyn_charges
	if OrbFence.less_motion:
		return
	fx.fly(kind, cell_px(cell), star_in_bottom(), 0.0, 0.5)


func _on_milestone(index: int) -> void:
	hud.light_milestone(index)
	sfx.milestone(index)


func _on_spark_lost(left: int) -> void:
	hud.spend_spark(left)
	sfx.play("crack")


func _on_restart() -> void:
	sfx.zip_stop()
	sfx.play("rewind")
	fx.hide_ghost(2)
	_field_ptr = -1
	_ghost_cell = Vector2i(-1, -1)


func _on_restart_reset() -> void:
	hud.reset(sim.target, not sim.easy, sim.spark_budget)
	fx.clear_cages()


func _on_cleared() -> void:
	_limiter.allow(_clock_s)
	_slowmo_t = 0.0
	sfx.zip_stop()
	sfx.play("win")
	hud.set_fill(sim.fill_ratio())
	hud.star_reached()
	world.reveal_all(sim)
	fx.hide_ghost(2)
	fx.hand_visible = false
	_field_ptr = -1
	if not OrbFence.less_motion:
		for i: int in sim.balls.size():
			fx.fly(
				"star",
				field_px(sim.balls[i].pos),
				star_in_bottom(),
				0.15 + i * OfBalance.CLEAR_STAR_STAGGER_S,
				0.6
			)
	if endless_round > 0:
		_new_best = OrbFence.report_round(sim.easy, endless_round)
	else:
		OrbFence.mark_cleared(level_id)
	_card_t = 0.0


func _show_card() -> void:
	_card_shown = true
	Engine.time_scale = 1.0
	_slowmo_t = -1.0
	if endless_round > 0:
		_show_round_card()
		return
	var nxt: int = OrbFence.next_level_after(level_id)
	win_card.show_card(_picture, nxt != 0)
	sfx.play("star_land")
	OfDisc.block_input(OfBalance.HOLDOVER_MS)
	OrbFence.level_card_shown.emit(level_id)
	if not OrbFence.full_unlock and level_id == OfBalance.FREE_LEVELS:
		OrbFence.free_levels_finished.emit()


## Uendelig round card (GDD 6.5): picture, round digit on the gold star,
## home + next; every 5th round the full win card. New best: a gold ring
## pops onto the star, comms beep at its top step, then the satellite ping.
func _show_round_card() -> void:
	var full: bool = endless_round % OfBalance.ENDLESS_FULL_CARD_EVERY == 0
	win_card.show_round_card(_picture, endless_round, _new_best, full)
	if _new_best:
		sfx.play("milestone", 2.0)
		_later.append([0.2, "star_land", 1.0])
	else:
		sfx.play("star_land")
	OfDisc.block_input(OfBalance.HOLDOVER_MS)
	OrbFence.endless_card_shown.emit(endless_round)


func _on_next() -> void:
	if endless_round > 0:
		start_endless(endless_round + 1)
		return
	var nxt: int = OrbFence.next_level_after(level_id)
	if nxt != 0:
		start_level(nxt)


func _on_replay() -> void:
	if endless_round > 0:
		start_endless(endless_round)
	else:
		start_level(level_id)


# ---------------------------------------------------------------- pause


func pause() -> void:
	if not active:
		return
	paused = true
	Engine.time_scale = 1.0
	_field_ptr = -1
	_ghost_cell = Vector2i(-1, -1)
	fx.hide_ghost(2)
	sfx.zip_stop()


## Back from the background: big play disc, scene dimmed 50%; resumes on
## release.
func show_resume() -> void:
	if not active or not paused:
		return
	if _card_shown:
		paused = false
		return
	resume_disc.visible = true
	dim_rect.color = Color(0, 0, 0, 0.5)


func resume() -> void:
	paused = false
	resume_disc.visible = false
	dim_rect.color = Color(0, 0, 0, 0)
	_holdover_until_ms = Time.get_ticks_msec() + OfBalance.HOLDOVER_MS
