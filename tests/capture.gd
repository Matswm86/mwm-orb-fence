extends Node

## Dev-only screenshot bot. Run under Xvfb with a fresh user dir:
##   XDG_DATA_HOME=<tmp> CAPTURE_DIR=<dir> godot --audio-driver Dummy \
##     --display-driver x11 --resolution 1080x1920 res://tests/capture.tscn
## CAPTURE_PHASE:
##   shots (default) - level 1 start (first launch) with the hand, a real
##                     touch: ghost held, direction tap turns it, release
##                     starts the wall; level 1 gameplay; level 3 mid-capture
##                     (the hero scene); level 1 win card; map; settings;
##                     Vanlig spark bar + gentle restart; resume disc
##   inset           - fake 120 px camera cutout: home disc, HUD and map gear
##   tall            - run with --resolution 1080x2400: field stays bottom-anchored
##   shell           - inside MWM Play: Engine meta set, set_full_unlock(false),
##                     levels 1-3 only, level 3 card has no "next" and emits
##                     free_levels_finished; own home disc and gear hidden
##   worlds          - worlds 2-6: one level per world mid-capture plus L6
##                     (first of world 2) and L16 (first 21 x 24 level) (21 x 24
##                     from world 4), Vanlig L29 spark bar (42), map pages
##                     with the Uendelig disc, Uendelig HUD badge on round 9
##                     (first 21 x 24 round), a round card with a new best
##                     and the full card on round 10

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: OfMain
var _fails: int = 0


func _ready() -> void:
	if out_dir == "":
		out_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var phase: String = OS.get_environment("CAPTURE_PHASE")
	if phase == "shell":
		Engine.set_meta(&"mwm_play_shell", true)
		OrbFence.set_full_unlock(false)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	var t0: int = Time.get_ticks_msec()
	match phase:
		"inset":
			await _phase_inset()
		"tall":
			await _phase_tall()
		"shell":
			await _phase_shell()
		"worlds":
			await _phase_worlds()
		_:
			await _phase_shots()
	print(
		(
			"CAPTURE DONE in %.1f s, checks failed: %d"
			% [(Time.get_ticks_msec() - t0) / 1000.0, _fails]
		)
	)
	Engine.time_scale = 1.0
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print(("CHECK ok   " if ok else "CHECK FAIL ") + what)
	if not ok:
		_fails += 1


func _phase_shots() -> void:
	var play: OfPlay = main.play
	print("first launch opened screen=%s level=%d" % [main.screen, play.level_id])
	_check("level 1 starts with up-down chosen", play.buttons.chosen == 0)
	# The hand runs through press loops on its own: it must never change the
	# chosen direction (QA 2026-10-06 finding 1).
	var flipped: bool = false
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1900:
		await get_tree().process_frame
		flipped = flipped or play.buttons.chosen != 0
	await _shot("01_level1_start_hand")
	print("hand visible=%s at %s" % [play.fx.hand_visible, play.fx.hand_at])
	_check("hand runs on level 1 start", play.fx.hand_visible)
	_check("hand line is up-down", bool(play._hand_line.get("vertical", false)))
	_check("hand alone never changed the direction (1.9 s)", not flipped)
	await _dir_sticks_test(play)
	await _touch_test(play)
	# Level 1 gameplay: shot while the first wall grows, before it can clear
	# the level (one wall can clear level 1).
	main.open_level(1)
	play.autopilot = true
	await _until(func() -> bool: return play.sim.wall != null and play.sim.wall.age > 0.12, 20.0)
	play.autopilot = false
	await _shot("03_level1_gameplay")
	_check(
		"03 shows gameplay (state PLAY, no win card)",
		play.sim.state == OfSim.State.PLAY and not play.card_visible()
	)
	# Level 3 mid-capture (hero scene, world1_mock.png): about a third
	# captured, a wall growing, Snegl tokens out.
	await _hero_level3(play)
	# Level 1 to the win card (Lett).
	OrbFence.easy = true
	main.open_level(1)
	play.autopilot = true
	Engine.time_scale = 3.0
	await _until(func() -> bool: return play.sim.state == OfSim.State.CLEAR, 120.0)
	Engine.time_scale = 1.0
	print(
		(
			"level 1 cleared=%s after %.1f game-s"
			% [play.sim.state == OfSim.State.CLEAR, play.sim.time]
		)
	)
	await _wait_s(0.5)
	await _shot("05_level1_clear_reveal")
	await _until(func() -> bool: return play.card_visible(), 5.0)
	await _wait_s(0.7)
	await _shot("06_level1_wincard")
	print("cleared after win: %s, next shown=%s" % [OrbFence.cleared, play.win_card.has_next()])
	# Map with the cleared star and the suggested pulse on level 2.
	play.win_card.map_pressed.emit()
	await _wait_s(1.0)
	await _shot("07_map")
	main.settings.open()
	await _frames(3)
	await _shot("08_settings")
	main.settings.visible = false
	# Vanlig with a test-only spark budget: bar, a lost spark, the restart.
	OrbFence.easy = false
	play.test_sparks = 2
	main.open_level(2)
	play.autopilot = false
	await _wait_s(0.6)
	var lost: int = 0
	var bar_shot: bool = false
	var t: float = 0.0
	while play.sim.restart_count == 0 and t < 20.0:
		if play.sim.can_start_wall() and play.sim.state == OfSim.State.PLAY:
			var b: OfSim.Ball = play.sim.balls[0]
			play.sim.start_wall(play.sim.cell_of(b.pos), true)
			lost += 1
		await _frames(2)
		t += 0.05
		if play.sim.sparks_left == 1 and not bar_shot:
			bar_shot = true
			await _wait_s(0.35)
			await _shot("09_vanlig_spark_bar")
	await _wait_s(0.75)
	await _shot("10_gentle_restart")
	print(
		(
			"restart: count=%d state=%d dim=%.2f sparks_left=%d"
			% [play.sim.restart_count, play.sim.state, play.sim.restart_dim(), play.sim.sparks_left]
		)
	)
	await _wait_s(1.4)
	print(
		(
			"after restart: state=%d fill=%.2f sparks=%d"
			% [play.sim.state, play.sim.fill_ratio(), play.sim.sparks_left]
		)
	)
	play.test_sparks = -1
	OrbFence.easy = true
	# App to the background and back: big play disc, resumes on release.
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _frames(3)
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _frames(3)
	await _shot("11_resume_disc")
	var was_paused: bool = play.paused
	play.resume_disc.press()
	await _frames(2)
	print("pause: paused=%s -> after tap paused=%s" % [was_paused, play.paused])


## Regression for QA finding 1: while the onboarding hand runs, the child
## taps side-side; the choice must hold for at least 1 s and the hand stops.
func _dir_sticks_test(play: OfPlay) -> void:
	_touch(1, OfBalance.DIR_CENTERS[1], true)
	await _frames(3)
	_touch(1, OfBalance.DIR_CENTERS[1], false)
	await _frames(2)
	_check("side-side tap chooses side-side", play.buttons.chosen == 1)
	var held: bool = true
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1300:
		await get_tree().process_frame
		held = held and play.buttons.chosen == 1
	_check("side-side choice sticks for 1.3 s after the tap", held)
	_check("hand stopped after the direction tap", not play.fx.hand_visible)
	# Back to up-down so 02a/02b show a real turn.
	play.buttons.chosen = 0
	await _frames(2)


## A real touch through Input: press in the field, hold (ghost), drag one
## cell, tap the side-side button with a second finger (ghost turns),
## release (wall starts). Then a touch in the wrist strip does nothing.
func _touch_test(play: OfPlay) -> void:
	_check("02a starts from up-down", play.buttons.chosen == 0)
	var p := Vector2(540, 900)
	_touch(0, p, true)
	await _frames(4)
	for i: int in 6:
		p += Vector2(14, 0)
		_drag(0, p, Vector2(14, 0))
		await _frames(1)
	await _frames(4)
	print(
		(
			"ghost: visible=%s cell=%s cells=%d (finger moved 84 px = 1.17 cells)"
			% [play.fx.ghost_visible, play._ghost_cell, play.fx.ghost_cells.size()]
		)
	)
	await _shot("02a_ghost_updown")
	_check("02a ghost is vertical", play.fx.ghost_vertical)
	_touch(1, OfBalance.DIR_CENTERS[1], true)
	await _frames(3)
	_touch(1, OfBalance.DIR_CENTERS[1], false)
	await _frames(4)
	print(
		(
			"side-side tapped: chosen=%d ghost vertical=%s"
			% [play.buttons.chosen, play.fx.ghost_vertical]
		)
	)
	await _shot("02b_ghost_turned_sideside")
	_check("02b ghost turned horizontal", not play.fx.ghost_vertical)
	var walls0: int = play.sim.walls_started
	_touch(0, p, false)
	await _frames(6)
	print("release in field: walls started %d -> %d" % [walls0, play.sim.walls_started])
	await _shot("02c_wall_growing")
	await _wait_s(1.5)
	var walls1: int = play.sim.walls_started
	_touch(0, Vector2(540, 1800), true)
	await _frames(2)
	_touch(0, Vector2(540, 1800), false)
	await _frames(2)
	print("touch in wrist strip: walls %d -> %d (expect same)" % [walls1, play.sim.walls_started])


func _hero_level3(play: OfPlay) -> void:
	OrbFence.easy = true
	var tries: int = 0
	while tries < 6:
		tries += 1
		main.open_level(3)
		play.autopilot = true
		await _wait_s(0.9)
		var ok: bool = await _until(
			func() -> bool:
				return (
					play.sim.fill_ratio() >= 0.28
					and play.sim.wall != null
					and play.sim.wall.age > 0.12
					and play.sim.state == OfSim.State.PLAY
				),
			40.0
		)
		if ok and play.sim.fill_ratio() < 0.5:
			break
	play.autopilot = false
	Engine.time_scale = 1.0
	await _frames(1)
	await _shot("04_level3_midcapture")
	print(
		(
			"level 3 hero: fill %.0f%% of %d cells, tokens left %d, snegl %.1f s, wall growing=%s, tries %d"
			% [
				play.sim.fill_ratio() * 100.0,
				play.sim.counted_total,
				play.sim.tokens.size(),
				play.sim.snegl_t,
				play.sim.wall != null,
				tries
			]
		)
	)


## Autopilot until fill is in [lo, hi) with a wall growing; returns the
## fill reached. Retries the level up to 6 times.
func _mid_capture(start: Callable, lo: float, hi: float) -> float:
	var play: OfPlay = main.play
	var tries: int = 0
	while tries < 6:
		tries += 1
		start.call()
		play.autopilot = true
		Engine.time_scale = 2.0
		await _wait_s(0.5)
		var ok: bool = await _until(
			func() -> bool:
				return (
					play.sim.fill_ratio() >= lo
					and play.sim.wall != null
					and play.sim.wall.age > 0.06
					and play.sim.state == OfSim.State.PLAY
				),
			40.0
		)
		if ok and play.sim.fill_ratio() < hi:
			break
	play.autopilot = false
	Engine.time_scale = 1.0
	await _frames(1)
	return play.sim.fill_ratio()


func _phase_worlds() -> void:
	var play: OfPlay = main.play
	OrbFence.easy = true
	var picks: Array = [
		[6, true],
		[8, true],
		[13, true],
		[16, true],
		[18, true],
		[22, true],
		[24, false],
		[28, true]
	]
	for pk: Array in picks:
		var id: int = pk[0]
		OrbFence.easy = bool(pk[1])
		var fill: float = await _mid_capture(func() -> void: main.open_level(id), 0.3, 0.6)
		var w: int = OfLevels.world_of(id)
		await _shot("20_w%d_L%d_%s_mid" % [w, id, "lett" if OrbFence.easy else "vanlig"])
		if OS.get_environment("CAPTURE_DEBUG") != "":
			Engine.time_scale = 0.01
			await _wait_s(0.6)
			await _shot("20_w%d_L%d_later" % [w, id])
			Engine.time_scale = 1.0
		var caged: int = 0
		for b: OfSim.Ball in play.sim.balls:
			caged += 1 if b.caged else 0
		print(
			(
				"L%d %s: field %s, fill %.0f%% of %d, balls %d (caged %d), tokens %d, mirrors turned %d"
				% [
					id,
					"Lett" if OrbFence.easy else "Vanlig",
					play.sim.field,
					fill * 100.0,
					play.sim.counted_total,
					play.sim.balls.size(),
					caged,
					play.sim.tokens.size(),
					play.sim.mirror_turns
				]
			)
		)
		if play.sim.wall != null:
			var wl: OfSim.Wall = play.sim.wall
			print(
				(
					"  wall origin %s vertical %s fast %s shielded %s halves %d/%d cells"
					% [
						wl.origin,
						wl.vertical,
						wl.fast,
						wl.shielded,
						wl.halves[0].cells.size(),
						wl.halves[1].cells.size()
					]
				)
			)
		_check("L%d grid %s" % [id, play.sim.field], play.sim.field == OfLevels.field_of(id))
	# Vanlig L29: 14 balls and the 42-spark bar after a few pops.
	OrbFence.easy = false
	main.open_level(29)
	await _wait_s(0.6)
	var spent: int = 0
	var t: float = 0.0
	while play.sim.sparks_left > 38 and t < 10.0:
		if play.sim.can_start_wall():
			var b: OfSim.Ball = play.sim.balls[3]
			play.sim.start_wall(play.sim.cell_of(b.pos), true)
			spent += 1
		await _frames(2)
		t += 0.04
	await _wait_s(0.4)
	await _shot("21_w6_L29_vanlig_sparks")
	print(
		(
			"L29 Vanlig sparks %d of %d, balls %d"
			% [play.sim.sparks_left, play.sim.spark_budget, play.sim.balls.size()]
		)
	)
	_check("L29 Vanlig budget 42", play.sim.spark_budget == 42)
	# Map pages with the Uendelig disc (level 5 cleared, best round 7 Lett).
	OrbFence.easy = true
	OrbFence.cleared = [1, 2, 3, 4, 5]
	OrbFence.endless_best = {"lett": 7, "vanlig": 0}
	main.open_map()
	await _wait_s(0.6)
	main.map.show_page(2)
	await _wait_s(0.6)
	await _shot("22_map_world2_endless_disc")
	_check("Uendelig disc shown after level 5", main.map.endless.visible)
	main.map.show_page(6)
	await _wait_s(0.6)
	await _shot("23_map_world6")
	# Uendelig round 9 (Lett): first 21 x 24 round, badge in the HUD.
	main.open_endless()
	play.start_endless(8)
	var fill9: float = await _mid_capture(func() -> void: play.start_endless(9), 0.25, 0.6)
	await _shot("24_endless_r9_lett_mid")
	print(
		(
			"Uendelig round %d: field %s, balls %d, speed %.0f, fill %.0f%%"
			% [
				play.endless_round,
				play.sim.field,
				play.sim.balls.size(),
				play.sim.ball_speed,
				fill9 * 100.0
			]
		)
	)
	_check("round 9 Lett on 21 x 24", play.sim.field == "21x24" and play.sim.balls.size() == 9)
	# Clear it: new best (9 > 7) -> round card with the gold ring.
	var shown: Array[int] = []
	OrbFence.endless_card_shown.connect(func(k: int) -> void: shown.append(k))
	play.autopilot = true
	Engine.time_scale = 3.0
	await _until(func() -> bool: return play.card_visible(), 120.0)
	Engine.time_scale = 1.0
	await _wait_s(1.0)
	await _shot("25_endless_round_card_new_best")
	print("round card: endless_card_shown=%s best=%d" % [shown, OrbFence.best_round(true)])
	_check("endless_card_shown(9) emitted", shown == [9])
	_check("best round saved as 9", OrbFence.best_round(true) == 9)
	# Next -> round 10 (cap), clear -> full card (every 5th round).
	play.win_card.next_pressed.emit()
	await _wait_s(0.3)
	_check("next starts round 10", play.endless_round == 10)
	Engine.time_scale = 3.0
	await _until(func() -> bool: return play.card_visible(), 150.0)
	Engine.time_scale = 1.0
	await _wait_s(1.0)
	await _shot("26_endless_round10_full_card")
	# Vanlig Uendelig HUD: badge + best star + spark bar on the short meter.
	OrbFence.easy = false
	OrbFence.endless_best = {"lett": 9, "vanlig": 5}
	play.autopilot = false
	play.start_endless(6)
	await _wait_s(1.2)
	await _shot("27_endless_r6_vanlig_hud")
	OrbFence.easy = true


func _phase_inset() -> void:
	main.fake_safe_top = 120.0
	main.apply_safe_area()
	await _wait_s(1.4)
	await _shot("12_inset_play")
	print("home disc centre %s, hit size %s" % [main.home.disc_center, main.home.size])
	var field_top: float = main.bottom_frame.position.y + OfBalance.FIELD_ORIGIN.y
	_check(
		"home hit stays >= 200 px and above the field top (%.0f)" % field_top,
		main.home.size.x >= 200.0 and main.home.size.y >= 200.0 and main.home.size.y <= field_top
	)
	# QA finding 2: a touch in field cells c0-c2 just under the cutout starts
	# a wall but must not arm the home guard; a second tap must not leave.
	var play: OfPlay = main.play
	var spot := Vector2(150, 285)
	var walls0: int = play.sim.walls_started
	_touch(0, spot, true)
	await _frames(3)
	_check("overlap touch shows a ghost", play.fx.ghost_visible)
	_touch(0, spot, false)
	await _frames(3)
	_check("overlap touch starts a wall", play.sim.walls_started == walls0 + 1)
	_check("overlap touch does not arm home", not main.home.is_guarding())
	await _wait_s(0.7)
	_touch(0, spot, true)
	await _frames(3)
	_touch(0, spot, false)
	await _frames(3)
	_check(
		"second overlap tap stays in play, home not armed",
		main.screen == "play" and not main.home.is_guarding()
	)
	main.open_map()
	await _wait_s(1.0)
	await _shot("13_inset_map")


func _phase_tall() -> void:
	await _wait_s(1.4)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	await _shot("14_tall_%dx%d" % [int(vs.x), int(vs.y)])
	print("viewport %s, bottom frame %s" % [vs, main.bottom_frame.position])


func _phase_shell() -> void:
	var shown: Array[int] = []
	var free_done: Array[int] = [0]
	OrbFence.level_card_shown.connect(func(id: int) -> void: shown.append(id))
	OrbFence.free_levels_finished.connect(func() -> void: free_done[0] += 1)
	main.open_map()
	await _wait_s(0.8)
	await _shot("15_shell_map")
	var ids: Array[int] = []
	for id: int in range(1, 6):
		if main.map.disc_for(id) != null:
			ids.append(id)
	print(
		(
			"shell map levels %s, gear visible=%s, home visible=%s"
			% [ids, main.map.gear.visible, main.home.visible]
		)
	)
	main.open_level(3)
	print("shell play: home visible=%s, sfx enabled=%s" % [main.home.visible, main.sfx.enabled])
	main.play.autopilot = true
	Engine.time_scale = 3.0
	await _until(func() -> bool: return main.play.card_visible(), 120.0)
	Engine.time_scale = 1.0
	await _wait_s(0.6)
	await _shot("16_shell_level3_card")
	print(
		(
			"shell card: level_card_shown=%s free_levels_finished=%d next shown=%s"
			% [shown, free_done[0], main.play.win_card.has_next()]
		)
	)
	var wc: OfWinCard = main.play.win_card
	_check(
		"shell L3 card: replay and map centred as a pair",
		(
			is_equal_approx(wc._replay.position.x + wc._replay.size.x * 0.5, 360.0)
			and is_equal_approx(wc._map.position.x + wc._map.size.x * 0.5, 720.0)
		)
	)
	Engine.remove_meta(&"mwm_play_shell")


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos + main.world.frame_offset()
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos + main.world.frame_offset()
	e.relative = rel
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait_s(s: float) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(s * 1000.0):
		await get_tree().process_frame


func _wait_game(s: float) -> void:
	var t: float = 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


## Waits (real time, max `limit` s) until cond is true; returns it.
func _until(cond: Callable, limit: float) -> bool:
	var start: int = Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - start > int(limit * 1000.0):
			return false
		await get_tree().process_frame
	return true


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir + "/" + name + ".png"
	img.save_png(path)
	print("SHOT ", path)
