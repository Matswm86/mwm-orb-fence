extends Node

## Headless logic test (no rendering):
##   godot --headless --audio-driver Dummy res://tests/logic_test.tscn
## 1. The bot clears levels 1-5 in Lett and Vanlig (SEEDS runs each); logs
##    median game time, walls and pops; no ball ever ends inside a solid cell.
## 2. A half-hit never erases the other half.
## 3. Origin hit pops both halves.
## 4. Vanlig spark budget (test-only flag) and the gentle restart.
## 5. Snegl token: captured -> balls slow for 10 s (Lett).
## 6. Ghost extent and nearest-empty ghost cell.
## 7. Flash limiter: 4 captures in a row -> at most 3 spikes per second.
## 8. Save round trip and full_unlock / free levels.
## 9. Sound table: every effect file loads (incl. Lyn / Skjold for later
##    worlds), the ambient pass-by gap is 40-90 s, sound off plays nothing.
## Prints "LOGIC TEST PASS" or "LOGIC TEST FAIL (n)" and exits 0 / 1.

const SEEDS: int = 12
const DT: float = 1.0 / 60.0
const MAX_T: float = 600.0

var fails: int = 0


func _ready() -> void:
	_test_bot_clears()
	_test_half_pop()
	_test_origin_pop()
	_test_sparks_restart()
	_test_snegl()
	_test_ghost()
	_test_flash_limiter()
	_test_save()
	_test_sounds()
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


func _test_bot_clears() -> void:
	print("1. bot clears levels 1-5")
	for easy: bool in [true, false]:
		for id: int in range(1, 6):
			var times: Array[float] = []
			var walls: Array[int] = []
			var pops: Array[int] = []
			var cleared: int = 0
			var inside: int = 0
			var safety: int = 0
			var survived: int = 0
			for s: int in SEEDS:
				var sim := OfSim.new()
				sim.rng.seed = 1000 + s * 7 + id
				sim.setup(id, easy)
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
				survived += sim.half_pops_survived
			times.sort()
			walls.sort()
			pops.sort()
			var med: float = times[times.size() / 2] if not times.is_empty() else -1.0
			print(
				(
					(
						"    %s L%d: cleared %d/%d, median %.1f s, walls %d, pops %d,"
						+ " half-pop walls kept %d, safety moves %d, frames inside solid %d"
					)
					% [
						"Lett  " if easy else "Vanlig",
						id,
						cleared,
						SEEDS,
						med,
						walls[walls.size() / 2],
						pops[pops.size() / 2],
						survived,
						safety,
						inside
					]
				)
			)
			_check(
				cleared == SEEDS, "%s L%d cleared every run" % ["Lett" if easy else "Vanlig", id]
			)
			_check(inside == 0, "no ball ends a frame inside a solid cell")


## One ball parked so it hits the top half of an up-down wall; the bottom
## half must still become a real wall.
func _test_half_pop() -> void:
	print("2. half pop keeps the other half")
	var sim := OfSim.new()
	sim.setup(1, true)
	var b: OfSim.Ball = sim.balls[0]
	# Ball in column 7 near the top, moving down: the top half grows into it.
	b.pos = OfSim.cell_center(Vector2i(7, 1))
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
	b.pos = OfSim.cell_center(Vector2i(7, 8))
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
	sim.balls[0].pos = OfSim.cell_center(Vector2i(10, 8))
	sim.balls[1].pos = OfSim.cell_center(Vector2i(11, 9))
	sim.balls[2].pos = OfSim.cell_center(Vector2i(12, 10))
	sim.start_wall(Vector2i(3, 8), true)
	var t: float = 0.0
	while sim.wall != null and t < 3.0:
		sim.step(DT)
		t += DT
	var fill_before: float = sim.fill_ratio()
	for i: int in 3:
		var b: OfSim.Ball = sim.balls[0]
		sim.start_wall(OfSim.cell_of(b.pos), true)
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
		b.pos = OfSim.cell_center(Vector2i(10, 6))
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
	var gc: Vector2i = sim.ghost_cell_for(OfSim.cell_center(Vector2i(3, 5)) + Vector2(0, -20))
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
	_check(st.visible_levels().size() == 5, "full_unlock true -> all 5")
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
	for key: String in ["lyn", "skjold", "snegl", "pass_by", "dir_pick", "star_land"]:
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
