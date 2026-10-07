extends Node

## Headless logic test (no rendering):
##   godot --headless --audio-driver Dummy res://tests/logic_test.tscn
## Env: LOGIC_SEEDS (runs per level, default 8), LOGIC_LEVELS "a-b" (default
## 1-30), LOGIC_ROUNDS "a-b" (Uendelig, default 1-14), LOGIC_ONLY "bot" |
## "units" to run one half.
## 1. The bot clears every level in Lett and Vanlig (real spark budgets) and
##    Uendelig rounds 1-14 in both settings; logs clear counts, median game
##    time, walls, pops, restarts; no moving ball ever ends inside a solid cell.
## 2. A half-hit never erases the other half.
## 3. Origin hit pops both halves.
## 4. Vanlig spark budget (test-only flag) and the gentle restart.
## 5. Snegl token: captured -> balls slow for 10 s (Lett).
## 6. Ghost extent and nearest-empty ghost cell.
## 7. Flash limiter: 4 captures in a row -> at most 3 spikes per second.
## 8. Save round trip and full_unlock / free levels.
## 9. Sound table: every effect file loads (incl. Lyn / Skjold / mirror),
##    the ambient pass-by gap is 40-90 s, sound off plays nothing.
## 10. Level table = GDD 6.3 ramp rules; grids per level (224 / 504 cells).
## 11. Cage, mirror, Lyn, Skjold, Stor / Kvikk, shaped fields.
## 12. Uendelig formulas, same-round restart, endless_best save, unlock.
## Prints "LOGIC TEST PASS" or "LOGIC TEST FAIL (n)" and exits 0 / 1.

const DT: float = 1.0 / 60.0
const MAX_T: float = 600.0

var fails: int = 0
var seeds: int = 8


func _ready() -> void:
	seeds = int(_env("LOGIC_SEEDS", "8"))
	var only: String = _env("LOGIC_ONLY", "")
	if only != "units":
		var lv: PackedInt32Array = _range_env("LOGIC_LEVELS", 1, 30)
		var rd: PackedInt32Array = _range_env("LOGIC_ROUNDS", 1, 14)
		_test_bot_clears(lv[0], lv[1])
		_test_bot_endless(rd[0], rd[1])
	if only != "bot":
		_test_half_pop()
		_test_origin_pop()
		_test_sparks_restart()
		_test_snegl()
		_test_ghost()
		_test_flash_limiter()
		_test_save()
		_test_sounds()
		_test_table()
		_test_cage()
		_test_mirror()
		_test_lyn_skjold()
		_test_specials()
		_test_endless()
	if fails == 0:
		print("LOGIC TEST PASS")
	else:
		print("LOGIC TEST FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func _env(key: String, dflt: String) -> String:
	var v: String = OS.get_environment(key)
	return dflt if v == "" else v


func _range_env(key: String, a: int, b: int) -> PackedInt32Array:
	var v: String = OS.get_environment(key)
	if v == "":
		return PackedInt32Array([a, b])
	var parts: PackedStringArray = v.split("-")
	var lo: int = int(parts[0])
	var hi: int = int(parts[1]) if parts.size() > 1 else lo
	return PackedInt32Array([lo, hi])


## Runs the bot on one config `seeds` times; returns the clear count.
func _bot_runs(label: String, make: Callable, easy: bool) -> int:
	var times: Array[float] = []
	var walls: Array[int] = []
	var pops: Array[int] = []
	var cleared: int = 0
	var inside: int = 0
	var safety: int = 0
	var restarts: int = 0
	var caged: int = 0
	var mirrors: int = 0
	var balls: int = 0
	var field: String = ""
	for s: int in seeds:
		var sim := OfSim.new()
		sim.rng.seed = 1000 + s * 7 + label.hash() % 1000
		sim.setup_config(make.call(), easy)
		balls = sim.ball_count
		field = sim.field
		var bot := OfBot.new()
		while sim.state != OfSim.State.CLEAR and sim.time < MAX_T:
			bot.tick(sim, DT)
			sim.step(DT)
			if not sim.balls_clear_of_solids():
				inside += 1
		if sim.state == OfSim.State.CLEAR:
			cleared += 1
			times.append(sim.time)
		walls.append(sim.walls_started)
		pops.append(sim.pops)
		safety += sim.safety_moves
		restarts += sim.restart_count
		caged += sim.balls_caged
		mirrors += sim.mirror_turns
	times.sort()
	walls.sort()
	pops.sort()
	var med: float = times[times.size() / 2] if not times.is_empty() else -1.0
	print(
		(
			(
				"    %s %s %s %2d balls: cleared %d/%d, median %.1f s, walls %d, pops %d,"
				+ " restarts %d, caged %d, mirror turns %d, safety %d, frames inside %d"
			)
			% [
				"Lett  " if easy else "Vanlig",
				label,
				field,
				balls,
				cleared,
				seeds,
				med,
				walls[walls.size() / 2],
				pops[pops.size() / 2],
				restarts,
				caged,
				mirrors,
				safety,
				inside
			]
		)
	)
	_check(cleared == seeds, "%s %s cleared every run" % ["Lett" if easy else "Vanlig", label])
	_check(inside == 0, "no moving ball ends a frame inside a solid cell")
	return cleared


func _test_bot_clears(first: int, last: int) -> void:
	print("1a. bot clears levels %d-%d (%d runs each)" % [first, last, seeds])
	var total: Array[int] = [0, 0]
	for easy: bool in [true, false]:
		for id: int in range(first, last + 1):
			var n: int = _bot_runs(
				"L%-2d" % id, func() -> Dictionary: return OfLevels.config(id, easy), easy
			)
			total[0 if easy else 1] += n
	var want: int = (last - first + 1) * seeds
	print("    TOTAL levels: Lett %d/%d, Vanlig %d/%d" % [total[0], want, total[1], want])


func _test_bot_endless(first: int, last: int) -> void:
	print("1b. bot clears Uendelig rounds %d-%d (%d runs each)" % [first, last, seeds])
	var total: Array[int] = [0, 0]
	for easy: bool in [true, false]:
		for k: int in range(first, last + 1):
			var n: int = _bot_runs(
				"R%-2d" % k, func() -> Dictionary: return OfLevels.endless_config(k, easy), easy
			)
			total[0 if easy else 1] += n
	var want: int = (last - first + 1) * seeds
	print("    TOTAL rounds: Lett %d/%d, Vanlig %d/%d" % [total[0], want, total[1], want])


## One ball parked so it hits the top half of an up-down wall; the bottom
## half must still become a real wall.
func _test_half_pop() -> void:
	print("2. half pop keeps the other half")
	var sim := OfSim.new()
	sim.setup(1, true)
	var b: OfSim.Ball = sim.balls[0]
	# Ball in column 7 near the top, moving down: the top half grows into it.
	b.pos = sim.cell_center(Vector2i(7, 1))
	b.dir = Vector2(0.0001, 1.0).normalized()
	var popped: Array[int] = []
	sim.half_popped.connect(
		func(h: int, _c: Array[Vector2i], _a: Vector2) -> void: popped.append(h)
	)
	var kept: Array = []
	sim.wall_finished.connect(func(cells: Array[Vector2i], _v: bool) -> void: kept.append(cells))
	sim.start_wall(Vector2i(7, 12), true)
	var t: float = 0.0
	while sim.wall != null and t < 5.0:
		sim.step(DT)
		t += DT
	_check(popped.size() == 1 and popped[0] == 0, "only the touched (top) half popped")
	var ok: bool = kept.size() == 1
	if ok:
		var cells: Array = kept[0]
		ok = cells.has(Vector2i(7, 15)) and cells.has(Vector2i(7, 12))
		ok = ok and not cells.has(Vector2i(7, 2))
	_check(ok, "bottom half + origin became WALL (%s)" % [kept])
	_check(sim.get_cell(Vector2i(7, 2)) == OfSim.Cell.EMPTY, "popped cells are empty again")


func _test_origin_pop() -> void:
	print("3. origin hit pops both halves")
	var sim := OfSim.new()
	sim.setup(1, true)
	var b: OfSim.Ball = sim.balls[0]
	b.pos = sim.cell_center(Vector2i(7, 8))
	var vanished: Array[int] = [0]
	sim.wall_vanished.connect(func() -> void: vanished[0] += 1)
	sim.start_wall(Vector2i(7, 8), true)
	_check(vanished[0] == 1 and sim.wall == null, "wall on a ball vanishes at once")
	_check(sim.pops == 1, "one pop counted (%d)" % sim.pops)
	_check(sim.get_cell(Vector2i(7, 8)) == OfSim.Cell.EMPTY, "origin empty again")


func _test_sparks_restart() -> void:
	print("4. Vanlig spark budget and gentle restart (test-only flag)")
	var sim := OfSim.new()
	sim.setup(2, false, 2)
	_check(sim.spark_budget == 2 and sim.sparks_left == 2, "budget 2 set by the flag")
	var restarts: Array[int] = [0]
	var resets: Array[int] = [0]
	sim.restart_started.connect(func() -> void: restarts[0] += 1)
	sim.restart_reset.connect(func() -> void: resets[0] += 1)
	# First make some fill so the reset is visible.
	sim.balls[0].pos = sim.cell_center(Vector2i(10, 8))
	sim.balls[1].pos = sim.cell_center(Vector2i(11, 9))
	sim.balls[2].pos = sim.cell_center(Vector2i(12, 10))
	sim.start_wall(Vector2i(3, 8), true)
	var t: float = 0.0
	while sim.wall != null and t < 3.0:
		sim.step(DT)
		t += DT
	var fill_before: float = sim.fill_ratio()
	for i: int in 3:
		var b: OfSim.Ball = sim.balls[0]
		sim.start_wall(sim.cell_of(b.pos), true)
		sim.step(DT)
	_check(sim.sparks_left == 0, "two pops spent both sparks")
	_check(restarts[0] == 1 and sim.state == OfSim.State.RESTART, "third pop starts a restart")
	var max_dim: float = 0.0
	t = 0.0
	while sim.state == OfSim.State.RESTART and t < 5.0:
		sim.step(DT)
		t += DT
		max_dim = maxf(max_dim, sim.restart_dim())
	_check(
		t < 2.0,
		"restart under 2 s (%.2f s, dim peak %.2f)" % [t, max_dim * OfBalance.RESTART_DIM_LEVEL]
	)
	_check(resets[0] == 1, "board reset once")
	_check(
		sim.sparks_left == 2 and sim.fill_ratio() == 0.0 and fill_before > 0.0,
		"bar refilled, fill back to 0 (was %.2f)" % fill_before
	)
	var lett := OfSim.new()
	lett.setup(2, true, 2)
	_check(lett.spark_budget == 0, "Lett ignores the flag: never a budget")


func _test_snegl() -> void:
	print("5. Snegl token")
	var sim := OfSim.new()
	sim.setup(3, true)
	var taken: Array[String] = []
	sim.token_taken.connect(func(k: String, _c: Vector2i) -> void: taken.append(k))
	for b: OfSim.Ball in sim.balls:
		b.pos = sim.cell_center(Vector2i(10, 6))
	sim.start_wall(Vector2i(6, 8), true)
	var t: float = 0.0
	while sim.wall != null and t < 3.0:
		sim.step(DT)
		t += DT
	_check(taken.has("snegl"), "Snegl at c3 r3 taken by capturing the left side")
	_check(absf(sim.snegl_factor() - OfBalance.SNEGL_FACTOR) < 0.001, "balls run at x0.6")
	var t2: float = 0.0
	while sim.snegl_t > 0.0 and t2 < 20.0 and sim.state == OfSim.State.PLAY:
		sim.step(DT)
		t2 += DT
	_check(
		absf(t2 + t - OfBalance.SNEGL_S_LETT) < 0.6, "lasts about 10 s in Lett (%.1f)" % (t + t2)
	)


func _test_ghost() -> void:
	print("6. ghost line")
	var sim := OfSim.new()
	sim.setup(4, true)
	var ext: Array[Vector2i] = sim.ghost_extent(Vector2i(3, 2), true)
	_check(ext.size() == 5, "ghost in c3 stops at the stone at r5 (%d cells)" % ext.size())
	var gc: Vector2i = sim.ghost_cell_for(sim.cell_center(Vector2i(3, 5)) + Vector2(0, -20))
	_check(gc == Vector2i(3, 4), "finger on a stone -> nearest empty cell (%s)" % gc)
	var ext2: Array[Vector2i] = sim.ghost_extent(Vector2i(0, 5), false)
	_check(ext2.size() == 3, "side-side ghost in r5 from c0 stops at c3 (%d)" % ext2.size())


func _test_flash_limiter() -> void:
	print("7. flash limiter")
	var lim := OfFlashLimiter.new()
	var granted: int = 0
	for i: int in 4:
		if lim.allow(10.0 + i * 0.1):
			granted += 1
	_check(granted == 3, "4 captures in 0.4 s -> 3 glow spikes")
	_check(lim.allow(11.05), "a spike is allowed again after 1 s")


func _test_save() -> void:
	print("8. save and unlock")
	var st: OfState = OrbFence
	var keep_cleared: Array[int] = st.cleared.duplicate()
	var keep_easy: bool = st.easy
	st.cleared = [1, 3]
	st.easy = false
	st.music_volume = 0.42
	st.save_game()
	st.cleared = []
	st.easy = true
	st.load_game()
	_check(st.cleared == [1, 3] and not st.easy, "cleared + difficulty survive a reload")
	_check(absf(st.music_volume - 0.42) < 0.001, "music slider saved")
	st.set_full_unlock(false)
	_check(st.visible_levels() == [1, 2, 3], "full_unlock false -> levels 1-3")
	_check(st.next_level_after(3) == 0, "no next after level 3 when locked")
	st.set_full_unlock(true)
	_check(st.visible_levels().size() == 30, "full_unlock true -> all 30")
	st.cleared = keep_cleared
	st.easy = keep_easy
	st.music_volume = 0.6
	st.save_game()


func _test_sounds() -> void:
	print("9. sound table")
	var missing: Array[String] = []
	var count: int = 0
	for key: String in OfSfx.SOUNDS:
		for file: String in OfSfx.SOUNDS[key][0]:
			count += 1
			if not ResourceLoader.exists(OfSfx.DIR + file + ".ogg"):
				missing.append(file)
	if not ResourceLoader.exists(OfSfx.DIR + OfSfx.ZIP_FILE + ".ogg"):
		missing.append(OfSfx.ZIP_FILE)
	_check(missing.is_empty(), "%d effect files all load (missing: %s)" % [count, missing])
	for key: String in ["lyn", "skjold", "snegl", "pass_by", "dir_pick", "star_land", "mirror"]:
		_check(OfSfx.SOUNDS.has(key), "sound for '%s' is in the table" % key)
	_check(
		OfBalance.AMBIENT_PASS_MIN_S >= 40.0 and OfBalance.AMBIENT_PASS_MAX_S <= 90.0,
		"ambient pass-by every 40-90 s"
	)
	var sfx := OfSfx.new()
	add_child(sfx)
	sfx.enabled = false
	sfx.play("pass_by")
	var any: bool = false
	for p: AudioStreamPlayer in sfx._players:
		any = any or p.playing
	_check(not any, "sound off -> the pass-by does not play")
	sfx.queue_free()


## Level table against the GDD 6.3 ramp rules, grids and maps.
func _test_table() -> void:
	print("10. level table = GDD 6.3 rules, grid per level")
	_check(OfLevels.count() == 30, "30 levels")
	var bad: Array[String] = []
	for id: int in range(1, 31):
		var w: int = OfLevels.world_of(id)
		var l: int = (id - 1) % 5 + 1
		var breather: bool = l == 5
		for easy: bool in [true, false]:
			var p: Dictionary = OfLevels.params(id, easy)
			var balls: int = OfBalance.level_balls(easy, w, l)
			var speed: float = OfBalance.level_speed(easy, w, l)
			var tgt: float = OfBalance.TARGET_LETT if easy else OfBalance.TARGET_VANLIG
			if breather:
				tgt = OfBalance.TARGET_BREATHER_LETT if easy else OfBalance.TARGET_BREATHER_VANLIG
			var sparks: int = 0
			if not easy and w > 1 and not breather:
				sparks = 3 * balls
			if (
				int(p["balls"]) != balls
				or absf(float(p["speed"]) - speed) > 0.01
				or absf(float(p["target"]) - tgt) > 0.001
				or int(p["sparks"]) != sparks
				or int(p["stor"]) + int(p["kvikk"]) > balls
			):
				bad.append("L%d %s" % [id, "lett" if easy else "vanlig"])
		var f: String = OfLevels.field_of(id)
		if f != ("14x16" if w <= 3 else "21x24"):
			bad.append("L%d field %s" % [id, f])
		var g: Dictionary = OfBalance.grid(f)
		var rows: Array[String] = OfLevels.rows(id)
		if rows.size() != int(g["rows"]):
			bad.append("L%d rows %d" % [id, rows.size()])
		for r: String in rows:
			if r.length() != int(g["cols"]):
				bad.append("L%d row width %d" % [id, r.length()])
				break
		if bool(OfLevels.get_level(id)["cage"]) != (id >= 6):
			bad.append("L%d cage" % id)
	_check(bad.is_empty(), "balls, speeds, targets, sparks, fields match the rules (%s)" % [bad])
	_check(OfLevels.params(4, false)["balls"] == 4, "Vanlig L4 = 4 balls (was 3)")
	_check(OfLevels.params(5, false)["balls"] == 4, "Vanlig L5 = 4 balls (was 2)")
	_check(OfLevels.params(29, false)["sparks"] == 42, "Vanlig L29 sparks 42 (no 24 cap)")
	var s1 := OfSim.new()
	s1.setup(1, true)
	var s16 := OfSim.new()
	s16.setup(16, true)
	_check(s1.counted_total == 224 and s1.cell == 72.0, "L1: 14 x 16, 224 cells, 72 px")
	_check(
		s16.counted_total == 504 and s16.cell == 48.0 and s16.cols == 21 and s16.rows == 24,
		"L16: 21 x 24, 504 cells, 48 px"
	)
	_check(
		is_equal_approx(s1.wall_speed * s1.cell, s16.wall_speed * s16.cell),
		"wall px/s the same on both grids (%.0f)" % (s16.wall_speed * s16.cell)
	)
	var plain_r: float = 0.0
	for b: OfSim.Ball in s16.balls:
		if b.kind == OfSim.Kind.PLAIN:
			plain_r = b.radius
	_check(plain_r == 20.0, "plain ball radius 20 on 21 x 24")
	var s18 := OfSim.new()
	s18.setup(18, false)
	_check(s18.counted_total == 504 - 4 * 36, "L18 plus field: 4 corners of 6 x 6 removed")
	_check(
		(
			s18.get_cell(Vector2i(0, 0)) == OfSim.Cell.OUT
			and s18.ghost_extent(Vector2i(10, 0), true).size() == 24
		),
		"OUT cells are solid; the middle column runs the full height"
	)
	_check(
		s16.cage_max == 27 and OfBalance.cage_cells(false, "21x24") == 18,
		"cage 27 / 18 cells on 21 x 24"
	)
	_check(
		(
			OfSfx.capture_key(31, 32, 90) == "capture_s"
			and OfSfx.capture_key(32, 32, 90) == "capture_m"
			and OfSfx.capture_key(90, 32, 90) == "capture_l"
		),
		"capture sound thresholds 32 / 90 on the big grid"
	)
	var hud := OfHud.new()
	add_child(hud)
	hud.reset(0.75, true, 42)
	var last: Vector2 = hud.spark_slot(41)
	_check(last.x + last.y <= 1040.0 and last.y >= 6.0, "42 sparks fit the bar (%s)" % last)
	hud.set_endless(3, 0, false)
	last = hud.spark_slot(41)
	_check(last.x + last.y <= 860.0, "Uendelig spark bar ends by x 860 (%s)" % last)
	hud.queue_free()


## Cage rule (GDD 4.5): a wall leaves a ball in a room of <= cage cells.
func _test_cage() -> void:
	print("11a. cage rule")
	var sim := OfSim.new()
	sim.setup(6, false)
	# Keep one ball, put it in the top-left corner pocket; wall across row 2
	# from c0 to c2 then column 3 ... simplest: a side-side wall in row 1 on
	# the left of the stone at c3 r3 is not enough, so build it by hand.
	while sim.balls.size() > 2:
		sim.balls.pop_back()
	sim.ball_count = 2
	var b0: OfSim.Ball = sim.balls[0]
	b0.pos = sim.cell_center(Vector2i(0, 0))
	b0.dir = Vector2(0.7, 0.7).normalized()
	var b1: OfSim.Ball = sim.balls[1]
	b1.pos = sim.cell_center(Vector2i(10, 10))
	var caged_n: Array[int] = [0]
	sim.caged.connect(func(_c: Array[Vector2i], idx: Array[int]) -> void: caged_n[0] += idx.size())
	# Pre-build an L: column 2 rows 0-2 and row 2 cols 0-1 as WALL, then the
	# capture pass runs from a finished wall.
	for c: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]:
		sim._set_cell(c, OfSim.Cell.WALL)
	var cells: Array[Vector2i] = [Vector2i(2, 2)]
	sim._set_cell(Vector2i(2, 2), OfSim.Cell.WALL)
	sim._capture(cells)
	_check(caged_n[0] == 1 and b0.caged, "ball in a 4-cell room is caged (Vanlig max 8)")
	_check(sim.get_cell(Vector2i(0, 0)) == OfSim.Cell.CAGED, "its cells are CAGED")
	var p0: Vector2 = b0.pos
	for i: int in 30:
		sim.step(DT)
	_check(b0.pos == p0, "a caged ball never moves")
	_check(not b1.caged, "the free ball is not caged")
	var lv1 := OfSim.new()
	lv1.setup(1, false)
	_check(not lv1.cage_on and lv1.cage_max == 8, "no cage in level 1 (from level 6)")


## Mirror: "/" maps (vx, vy) -> (-vy, -vx); "\" maps to (vy, vx).
func _test_mirror() -> void:
	print("11b. mirrors")
	var sim := OfSim.new()
	sim.setup(21, true)
	var mc := Vector2i(5, 6)
	_check(sim.mirror_at(mc) == 1, "c5 r6 on L21 is a '/' mirror")
	_check(sim.mirror_at(Vector2i(15, 6)) == -1, "c15 r6 is a '\\' mirror")
	while sim.balls.size() > 1:
		sim.balls.pop_back()
	var b: OfSim.Ball = sim.balls[0]
	var d0 := Vector2(0.8, 0.6)
	b.dir = d0
	b.pos = sim.cell_center(mc) + Vector2(-sim.cell * 0.5 - b.radius - 2.0, 0.0)
	var turns: Array[int] = [0]
	sim.mirror_bounced.connect(func(_i: int, _c: Vector2i) -> void: turns[0] += 1)
	for i: int in 10:
		sim.step(DT)
		if turns[0] > 0:
			break
	_check(turns[0] == 1, "ball moving right turns at the mirror")
	_check(b.dir.is_equal_approx(Vector2(-0.6, -0.8)), "'/' turned (0.8, 0.6) to %s" % b.dir)
	var ang: float = rad_to_deg(atan2(absf(b.dir.y), absf(b.dir.x)))
	_check(ang >= 35.0 and ang <= 55.0, "angle stays in 35-55 deg (%.1f)" % ang)
	_check(sim.counted_total == 500, "mirrors are not counted (500 of 504)")


func _test_lyn_skjold() -> void:
	print("11c. Lyn and Skjold")
	var sim := OfSim.new()
	sim.setup(11, true)
	sim.tokens.clear()
	sim.tokens[Vector2i(0, 0)] = "lyn"
	for b: OfSim.Ball in sim.balls:
		b.pos = sim.cell_center(Vector2i(10, 10))
	sim.start_wall(Vector2i(3, 8), true)
	var t: float = 0.0
	while sim.wall != null and t < 3.0:
		sim.step(DT)
		t += DT
	_check(sim.lyn_charges == 2, "Lyn captured -> 2 fast walls")
	var w_speed: float = sim.wall_speed
	sim.start_wall(Vector2i(6, 8), true)
	_check(
		sim.wall.fast and is_equal_approx(sim.effective_wall_speed(), w_speed * 2.5),
		"next wall grows 2.5x"
	)
	_check(sim.lyn_charges == 1, "one charge left")
	# Skjold: a ball driven into the growing wall does not pop it.
	var sk := OfSim.new()
	sk.setup(26, true)
	sk.shield_ready = true
	while sk.balls.size() > 1:
		sk.balls.pop_back()
	var b: OfSim.Ball = sk.balls[0]
	b.pos = sk.cell_center(Vector2i(2, 2))
	sk.start_wall(Vector2i(10, 12), true)
	_check(sk.wall.shielded and not sk.shield_ready, "shield spent on the next wall")
	t = 0.0
	while t < 0.3:
		sk.step(DT)
		t += DT
	b.pos = sk.cell_center(Vector2i(8, 9))
	b.dir = Vector2(0.8, 0.6)
	while sk.wall != null and t < 6.0:
		sk.step(DT)
		t += DT
	_check(
		sk.pops == 0 and sk.shield_blocks > 0,
		"shielded wall never pops (%d blocks)" % sk.shield_blocks
	)
	_check(sk.walls_done == 1, "shielded wall completes")


func _test_specials() -> void:
	print("11d. Stor and Kvikk balls")
	var sim := OfSim.new()
	sim.setup(29, false)
	var n_s: int = 0
	var n_k: int = 0
	for b: OfSim.Ball in sim.balls:
		if b.kind == OfSim.Kind.STOR:
			n_s += 1
			_check(b.radius == 28.0 and is_equal_approx(b.speed, 450.0 * 0.8), "Stor r28 x0.8")
		elif b.kind == OfSim.Kind.KVIKK:
			n_k += 1
			_check(b.radius == 15.0 and is_equal_approx(b.speed, 450.0 * 1.3), "Kvikk r15 x1.3")
	_check(n_s == 2 and n_k == 2 and sim.balls.size() == 14, "L29 Vanlig: 14 balls, 2 S, 2 K")
	var lt := OfSim.new()
	lt.setup(8, true)
	_check(lt.balls[0].kind == OfSim.Kind.STOR and lt.balls[0].radius == 34.0, "L8 Lett Stor r34")
	var k16 := OfSim.new()
	k16.setup(16, true)
	_check(is_equal_approx(k16.balls[0].speed, 230.0 * 1.15), "Kvikk Lett x1.15")
	_check(sim.tokens.size() == 3, "L29 has one of each token")


func _test_endless() -> void:
	print("12. Uendelig")
	var ok: bool = true
	for k: int in range(1, 20):
		var l: Dictionary = OfLevels.endless_config(k, true)
		var v: Dictionary = OfLevels.endless_config(k, false)
		ok = ok and int(l["balls"]) == mini(k, 10) and int(v["balls"]) == mini(k + 1, 13)
		ok = ok and is_equal_approx(float(l["speed"]), minf(200.0 + 5.0 * (k - 1), 245.0))
		ok = ok and is_equal_approx(float(v["speed"]), minf(320.0 + 10.0 * (k - 1), 430.0))
		ok = ok and String(l["field"]) == ("21x24" if k >= 9 else "14x16")
		ok = ok and String(v["field"]) == ("21x24" if k >= 8 else "14x16")
		ok = ok and int(l["sparks"]) == 0 and int(v["sparks"]) == 3 * int(v["balls"])
		ok = ok and int(l["random_snegl"]) == (1 if k >= 3 else 0)
		ok = ok and float(l["target"]) == 0.65 and float(v["target"]) == 0.75
		ok = ok and bool(l["cage"])
	_check(ok, "rounds 1-19: balls, speed, caps, field switch, sparks, Snegl, target")
	_check(
		OfLevels.endless_config(7, true)["picture"] == OfLevels.picture_path(5),
		"round 7 shows the world 1 breather picture again"
	)
	var sim := OfSim.new()
	sim.setup_config(OfLevels.endless_config(3, false), false)
	_check(sim.tokens.size() == 1, "round 3 has one random Snegl")
	sim.sparks_left = 0
	var b: OfSim.Ball = sim.balls[0]
	sim.start_wall(sim.cell_of(b.pos), true)
	var t: float = 0.0
	while sim.state == OfSim.State.RESTART and t < 5.0:
		sim.step(DT)
		t += DT
	_check(
		sim.restart_count == 1 and sim.ball_count == 4 and sim.sparks_left == 12,
		"empty bar + pop restarts the same round (4 balls, 12 sparks)"
	)
	var st: OfState = OrbFence
	var keep: Dictionary = st.endless_best.duplicate()
	var keep_cleared: Array[int] = st.cleared.duplicate()
	st.endless_best = {"lett": 0, "vanlig": 0}
	_check(st.report_round(true, 4) and not st.report_round(true, 3), "best only goes up")
	st.endless_best = {"lett": 0, "vanlig": 0}
	st.load_game()
	_check(st.best_round(true) == 4 and st.best_round(false) == 0, "endless_best saved per setting")
	var f := FileAccess.open(OfState.SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"version": 1, "cleared": [1], "difficulty": "lett"}')
	f.close()
	st.load_game()
	_check(st.best_round(true) == 0 and st.best_round(false) == 0, "old save -> best 0")
	st.cleared = [1, 2, 3, 4]
	_check(not st.endless_unlocked(), "Uendelig hidden before level 5")
	st.cleared = [5]
	_check(st.endless_unlocked(), "Uendelig after level 5")
	st.set_full_unlock(false)
	_check(not st.endless_unlocked(), "never in the free part")
	st.set_full_unlock(true)
	var got: Array[int] = []
	st.endless_card_shown.connect(func(k: int) -> void: got.append(k))
	st.endless_card_shown.emit(2)
	_check(got == [2], "endless_card_shown(round) signal exists")
	st.endless_best = keep
	st.cleared = keep_cleared
	st.save_game()
