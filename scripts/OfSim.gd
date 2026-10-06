class_name OfSim
extends RefCounted

## Pure game logic of one level (GDD sections 4 and 5) in field-local px:
## (0, 0) is the top-left of cell c0 r0, the field is 1008 x 1152. Grid,
## balls with per-axis swept reflection, walls growing in two halves, the
## per-half soap-bubble pop, flood-fill capture, the Snegl token, fill and
## milestones, the Vanlig spark budget with the gentle restart, the safety
## rule and the hint line chooser. No nodes and no rendering: OfPlay drives
## it, OfWorld draws it, the tests run it headless.

signal wall_started(origin: Vector2i, vertical: bool)
signal wall_grew(half: int, cell: Vector2i)
signal half_popped(half: int, cells: Array[Vector2i], at: Vector2)
signal wall_finished(cells: Array[Vector2i], vertical: bool)
signal wall_vanished
signal captured(cells: Array[Vector2i], delays: PackedFloat32Array)
signal ball_bounced(ball: int, pos: Vector2)
signal token_taken(kind: String, cell: Vector2i)
signal milestone_reached(index: int)
signal spark_lost(left: int)
signal restart_started
signal restart_reset
signal level_cleared

enum Cell { EMPTY, ROCK, MIRROR, BUILDING, WALL, CAPTURED, CAGED }
enum State { PLAY, RESTART, CLEAR }

const COLS: int = OfBalance.COLS
const ROWS: int = OfBalance.ROWS
const CELL: float = OfBalance.CELL
const BORDER: int = 255


class Ball:
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 200.0
	var radius: float = 24.0
	var bad_frames: int = 0


class Half:
	var step: Vector2i = Vector2i.ZERO
	var cells: Array[Vector2i] = []
	var progress: float = 0.0
	var done: bool = false
	var popped: bool = false


class Wall:
	var origin: Vector2i = Vector2i.ZERO
	var vertical: bool = true
	var halves: Array[Half] = []
	var age: float = 0.0


var level_id: int = 1
var easy: bool = true
var state: State = State.PLAY
var time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var grid: PackedByteArray = PackedByteArray()
## For WALL cells: 1 = up-down wall, 2 = side-side wall (drawing only).
var wall_dir: PackedByteArray = PackedByteArray()
var tokens: Dictionary = {}
var balls: Array[Ball] = []
var wall: Wall = null

var ball_count: int = 1
var ball_speed: float = 200.0
var target: float = 0.65
var wall_speed: float = 14.0
var counted_total: int = 224
var filled: int = 0
var milestones_hit: int = 0

var spark_budget: int = 0
var sparks_left: int = 0
var snegl_t: float = 0.0
var snegl_len: float = 10.0

var restart_t: float = -1.0
var restart_count: int = 0

# Stats for tests and hints.
var walls_started: int = 0
var walls_done: int = 0
var pops: int = 0
var half_pops_survived: int = 0
var safety_moves: int = 0
var pop_times: Array[float] = []

var _rows: Array[String] = []


## sparks_override >= 0 forces a Vanlig spark budget (test-only flag, GDD 12).
func setup(id: int, is_easy: bool, sparks_override: int = -1) -> void:
	level_id = id
	easy = is_easy
	_rows = OfLevels.rows(id)
	var p: Dictionary = OfLevels.params(id, is_easy)
	ball_count = int(p["balls"])
	ball_speed = float(p["speed"])
	target = float(p["target"])
	wall_speed = OfBalance.wall_speed(is_easy)
	spark_budget = OfBalance.spark_budget(is_easy, int(p["sparks"]))
	if sparks_override >= 0 and not is_easy:
		spark_budget = sparks_override
	snegl_len = OfBalance.snegl_s(is_easy)
	time = 0.0
	restart_count = 0
	_reset_board()


func _reset_board() -> void:
	grid.resize(COLS * ROWS)
	wall_dir.resize(COLS * ROWS)
	wall_dir.fill(0)
	tokens.clear()
	counted_total = 0
	for r: int in ROWS:
		var row: String = _rows[r]
		for c: int in COLS:
			var ch: String = row[c]
			var s: int = Cell.EMPTY
			if ch == "#":
				s = Cell.ROCK
			elif ch == "/" or ch == "\\":
				s = Cell.MIRROR
			elif ch == "S":
				tokens[Vector2i(c, r)] = "snegl"
			grid[r * COLS + c] = s
			if s != Cell.ROCK and s != Cell.MIRROR:
				counted_total += 1
	wall = null
	filled = 0
	milestones_hit = 0
	snegl_t = 0.0
	sparks_left = spark_budget
	pop_times.clear()
	state = State.PLAY
	restart_t = -1.0
	_spawn_balls()


func _spawn_balls() -> void:
	balls.clear()
	var used: Dictionary = {}
	var guard: int = 0
	while balls.size() < ball_count and guard < 1000:
		guard += 1
		var c := Vector2i(
			rng.randi_range(OfBalance.SPAWN_COL_MIN, OfBalance.SPAWN_COL_MAX),
			rng.randi_range(OfBalance.SPAWN_ROW_MIN, OfBalance.SPAWN_ROW_MAX)
		)
		if get_cell(c) != Cell.EMPTY or tokens.has(c) or used.has(c):
			continue
		used[c] = true
		var b := Ball.new()
		b.pos = cell_center(c)
		var a: float = deg_to_rad(
			rng.randf_range(OfBalance.BALL_ANGLE_MIN_DEG, OfBalance.BALL_ANGLE_MAX_DEG)
		)
		var sx: float = 1.0 if rng.randf() < 0.5 else -1.0
		var sy: float = 1.0 if rng.randf() < 0.5 else -1.0
		b.dir = Vector2(cos(a) * sx, sin(a) * sy)
		b.speed = ball_speed
		b.radius = OfBalance.BALL_RADIUS
		balls.append(b)


# ---------------------------------------------------------------- grid


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func get_cell(c: Vector2i) -> int:
	if not in_grid(c):
		return BORDER
	return grid[c.y * COLS + c.x]


func _set_cell(c: Vector2i, s: int) -> void:
	grid[c.y * COLS + c.x] = s


static func is_ball_solid(s: int) -> bool:
	return s != Cell.EMPTY


func fill_ratio() -> float:
	return float(filled) / float(maxi(counted_total, 1))


## Fill as a share of the target (the meter's 0..1 up to the star).
func progress() -> float:
	return clampf(fill_ratio() / target, 0.0, 1.0)


func snegl_factor() -> float:
	return OfBalance.SNEGL_FACTOR if snegl_t > 0.0 else 1.0


func snegl_left() -> float:
	return clampf(snegl_t / snegl_len, 0.0, 1.0)


func can_start_wall() -> bool:
	return state == State.PLAY and wall == null


## Cells a wall from `c` in that direction would cover if no ball stopped
## it (the ghost line).
func ghost_extent(c: Vector2i, vertical: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if get_cell(c) != Cell.EMPTY:
		return out
	out.append(c)
	var step := Vector2i(0, 1) if vertical else Vector2i(1, 0)
	for s: Vector2i in [step, -step]:
		var n: Vector2i = c + s
		while get_cell(n) == Cell.EMPTY:
			out.append(n)
			n += s
	return out


## Ghost cell for a finger at field-local p: the cell under it, or the
## nearest empty cell within one cell; (-1, -1) when none.
func ghost_cell_for(p: Vector2) -> Vector2i:
	var c: Vector2i = cell_of(p)
	if get_cell(c) == Cell.EMPTY:
		return c
	var best := Vector2i(-1, -1)
	var best_d: float = INF
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var n := Vector2i(c.x + dx, c.y + dy)
			if get_cell(n) != Cell.EMPTY:
				continue
			var d: float = cell_center(n).distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = n
	return best


# ---------------------------------------------------------------- walls


func start_wall(origin: Vector2i, vertical: bool) -> bool:
	if not can_start_wall() or get_cell(origin) != Cell.EMPTY:
		return false
	wall = Wall.new()
	wall.origin = origin
	wall.vertical = vertical
	var step := Vector2i(0, 1) if vertical else Vector2i(1, 0)
	for s: Vector2i in [-step, step]:
		var h := Half.new()
		h.step = s
		wall.halves.append(h)
	_set_cell(origin, Cell.BUILDING)
	walls_started += 1
	wall_started.emit(origin, vertical)
	if _any_ball_overlaps(origin):
		_pop_at(origin, cell_center(origin))
	return true


func _grow(dt: float) -> void:
	if wall == null:
		return
	wall.age += dt
	for i: int in wall.halves.size():
		var h: Half = wall.halves[i]
		if h.done or h.popped:
			continue
		h.progress += wall_speed * dt
		while h.cells.size() < int(h.progress) and not h.done and not h.popped:
			var nxt: Vector2i = wall.origin + h.step * (h.cells.size() + 1)
			if get_cell(nxt) != Cell.EMPTY:
				h.done = true
				break
			if _any_ball_overlaps(nxt):
				# A wall growing into a ball counts as the ball touching it.
				_pop_half(i, cell_center(nxt))
				break
			_set_cell(nxt, Cell.BUILDING)
			h.cells.append(nxt)
			wall_grew.emit(i, nxt)
		if wall == null:
			return
		if not h.popped and get_cell(wall.origin + h.step * (h.cells.size() + 1)) != Cell.EMPTY:
			h.done = true
	_maybe_finish()


func _pop_at(c: Vector2i, at: Vector2) -> void:
	if wall == null:
		return
	if c == wall.origin:
		# Touching the origin pops both halves: one pop, one spark.
		_pop_half(0, at, false)
		_pop_half(1, at, false)
		_count_pop()
		_maybe_finish()
		return
	for i: int in wall.halves.size():
		if wall.halves[i].cells.has(c):
			_pop_half(i, at)
			return


func _pop_half(i: int, at: Vector2, count: bool = true) -> void:
	if wall == null:
		return
	var h: Half = wall.halves[i]
	if h.popped:
		return
	h.popped = true
	var freed: Array[Vector2i] = []
	for c: Vector2i in h.cells:
		if get_cell(c) == Cell.BUILDING:
			_set_cell(c, Cell.EMPTY)
			freed.append(c)
	var other: Half = wall.halves[1 - i]
	if other.popped:
		_set_cell(wall.origin, Cell.EMPTY)
		freed.append(wall.origin)
	half_popped.emit(i, freed, at)
	if count:
		_count_pop()
		_maybe_finish()


func _count_pop() -> void:
	pops += 1
	pop_times.append(time)
	_spend_spark()


func _maybe_finish() -> void:
	if wall == null:
		return
	for h: Half in wall.halves:
		if not (h.done or h.popped):
			return
	var w: Wall = wall
	wall = null
	var kept: Array[Vector2i] = []
	var any_kept: bool = false
	for h: Half in w.halves:
		if not h.popped:
			any_kept = true
			kept.append_array(h.cells)
	if not any_kept:
		wall_vanished.emit()
		return
	if w.halves[0].popped or w.halves[1].popped:
		half_pops_survived += 1
	kept.append(w.origin)
	var dcode: int = 1 if w.vertical else 2
	for c: Vector2i in kept:
		_set_cell(c, Cell.WALL)
		wall_dir[c.y * COLS + c.x] = dcode
	walls_done += 1
	wall_finished.emit(kept, w.vertical)
	_capture(kept)


# ---------------------------------------------------------------- capture


func _capture(new_wall: Array[Vector2i]) -> void:
	var ball_cells: Dictionary = {}
	for b: Ball in balls:
		ball_cells[cell_of(b.pos)] = true
	var taken: Array[Vector2i] = []
	for reg: Array[Vector2i] in _empty_regions(grid):
		var has_ball: bool = false
		for c: Vector2i in reg:
			if ball_cells.has(c):
				has_ball = true
				break
		if not has_ball:
			taken.append_array(reg)
	for c: Vector2i in taken:
		_set_cell(c, Cell.CAPTURED)
	var delays := PackedFloat32Array()
	if not taken.is_empty():
		delays = _wave_delays(taken, new_wall)
		captured.emit(taken, delays)
	for c: Vector2i in new_wall + taken:
		if tokens.has(c):
			var kind: String = tokens[c]
			tokens.erase(c)
			if kind == "snegl":
				snegl_t = snegl_len
			token_taken.emit(kind, c)
	_recount()


## Each captured cell starts its grow-in after a delay that follows its
## distance from the new wall, so the fill wipes out from the wall.
func _wave_delays(cells: Array[Vector2i], from: Array[Vector2i]) -> PackedFloat32Array:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	var inside: Dictionary = {}
	for c: Vector2i in cells:
		inside[c] = true
	for c: Vector2i in from:
		dist[c] = 0
		queue.append(c)
	var head: int = 0
	var max_d: int = 1
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for n: Vector2i in [
			c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN
		]:
			if inside.has(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				max_d = maxi(max_d, int(dist[n]))
				queue.append(n)
	var span: float = OfBalance.CAPTURE_WAVE_S - OfBalance.CELL_GROW_S
	var out := PackedFloat32Array()
	for c: Vector2i in cells:
		var d: int = int(dist.get(c, max_d))
		out.append(span * float(d - 1) / float(maxi(max_d - 1, 1)))
	return out


func _recount() -> void:
	var n: int = 0
	for s: int in grid:
		if s == Cell.WALL or s == Cell.CAPTURED or s == Cell.CAGED:
			n += 1
	filled = n
	var prog: float = progress()
	while (
		milestones_hit < OfBalance.MILESTONES.size()
		and prog >= OfBalance.MILESTONES[milestones_hit]
	):
		milestones_hit += 1
		milestone_reached.emit(milestones_hit - 1)
	if fill_ratio() >= target - 0.00001 and state == State.PLAY:
		state = State.CLEAR
		level_cleared.emit()


## 4-connected regions of EMPTY cells in g.
static func _empty_regions(g: PackedByteArray) -> Array[Array]:
	var seen := PackedByteArray()
	seen.resize(COLS * ROWS)
	seen.fill(0)
	var out: Array[Array] = []
	for start: int in COLS * ROWS:
		if g[start] != Cell.EMPTY or seen[start] == 1:
			continue
		var reg: Array[Vector2i] = []
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var c := Vector2i(i % COLS, i / COLS)
			reg.append(c)
			for n: Vector2i in [
				c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN
			]:
				if not in_grid(n):
					continue
				var j: int = n.y * COLS + n.x
				if g[j] == Cell.EMPTY and seen[j] == 0:
					seen[j] = 1
					stack.append(j)
		out.append(reg)
	return out


# ---------------------------------------------------------------- sparks


func _spend_spark() -> void:
	if spark_budget <= 0 or state != State.PLAY:
		return
	if sparks_left > 0:
		sparks_left -= 1
		spark_lost.emit(sparks_left)
		return
	_start_restart()


func _start_restart() -> void:
	state = State.RESTART
	restart_t = 0.0
	restart_count += 1
	restart_started.emit()


## 0..1 dim of the gentle restart (0 outside a restart).
func restart_dim() -> float:
	if restart_t < 0.0:
		return 0.0
	var a: float = OfBalance.RESTART_DIM_S
	var b: float = a + OfBalance.RESTART_REWIND_S
	if restart_t < a:
		return restart_t / a
	if restart_t < b:
		return 1.0
	return clampf(1.0 - (restart_t - b) / OfBalance.RESTART_LIFT_S, 0.0, 1.0)


## 0..1 progress of the rewind slide (walls and fill slide back out).
func restart_rewind() -> float:
	if restart_t < 0.0:
		return 0.0
	return clampf((restart_t - OfBalance.RESTART_DIM_S) / OfBalance.RESTART_REWIND_S, 0.0, 1.0)


func _step_restart(dt: float) -> void:
	var before: float = restart_t
	restart_t += dt
	var reset_at: float = OfBalance.RESTART_DIM_S + OfBalance.RESTART_REWIND_S
	if before < reset_at and restart_t >= reset_at:
		var keep_t: float = restart_t
		var keep_count: int = restart_count
		_reset_board()
		restart_count = keep_count
		state = State.RESTART
		restart_t = keep_t
		restart_reset.emit()
	if restart_t >= reset_at + OfBalance.RESTART_LIFT_S:
		restart_t = -1.0
		state = State.PLAY


# ---------------------------------------------------------------- balls


func step(dt: float) -> void:
	if dt <= 0.0:
		return
	time += dt
	match state:
		State.CLEAR:
			return
		State.RESTART:
			_step_restart(dt)
			return
	snegl_t = maxf(0.0, snegl_t - dt)
	_grow(dt)
	if state != State.PLAY:
		return
	var f: float = snegl_factor()
	for i: int in balls.size():
		_move_ball(i, balls[i], dt, f)
		if state != State.PLAY:
			return
	_safety()


func _move_ball(i: int, b: Ball, dt: float, factor: float) -> void:
	var dist: float = b.speed * factor * dt
	var n: int = maxi(1, ceili(dist / OfBalance.SUBSTEP_MAX_PX))
	var d: float = dist / float(n)
	for k: int in n:
		for ax: int in 2:
			var delta: float = b.dir[ax] * d
			b.pos[ax] += delta
			var hit: bool = false
			var building: Array[Vector2i] = []
			for c: Vector2i in overlap_cells(b.pos, b.radius):
				var s: int = get_cell(c)
				if is_ball_solid(s):
					hit = true
					if s == Cell.BUILDING:
						building.append(c)
			if hit:
				b.pos[ax] -= delta
				b.dir[ax] = -b.dir[ax]
				ball_bounced.emit(i, b.pos)
				for c: Vector2i in building:
					_pop_at(c, b.pos)
				if state != State.PLAY:
					return


static func overlap_cells(p: Vector2, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0: int = floori((p.x - r) / CELL)
	var x1: int = floori((p.x + r - 0.001) / CELL)
	var y0: int = floori((p.y - r) / CELL)
	var y1: int = floori((p.y + r - 0.001) / CELL)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out


func _any_ball_overlaps(c: Vector2i) -> bool:
	for b: Ball in balls:
		if overlap_cells(b.pos, b.radius).has(c):
			return true
	return false


## Safety (GDD 4.6): a ball inside a solid cell for 2 frames, or with a NaN
## position, moves to the centre of the nearest empty cell, same velocity.
func _safety() -> void:
	for b: Ball in balls:
		var bad: bool = is_nan(b.pos.x) or is_nan(b.pos.y)
		if not bad:
			for c: Vector2i in overlap_cells(b.pos, b.radius):
				if is_ball_solid(get_cell(c)):
					bad = true
					break
		b.bad_frames = b.bad_frames + 1 if bad else 0
		if b.bad_frames >= 2:
			var start: Vector2i = Vector2i(COLS / 2, ROWS / 2)
			if not is_nan(b.pos.x) and not is_nan(b.pos.y):
				start = cell_of(b.pos)
			var c: Vector2i = _nearest_empty(start)
			if c.x >= 0:
				b.pos = cell_center(c)
			b.bad_frames = 0
			safety_moves += 1


func _nearest_empty(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for r: int in ROWS:
		for c: int in COLS:
			if grid[r * COLS + c] != Cell.EMPTY:
				continue
			var d: int = absi(c - from.x) + absi(r - from.y)
			if d < best_d:
				best_d = d
				best = Vector2i(c, r)
	return best


## True when no ball overlaps a solid cell (used by the tests' log check).
func balls_clear_of_solids() -> bool:
	for b: Ball in balls:
		for c: Vector2i in overlap_cells(b.pos, b.radius):
			if is_ball_solid(get_cell(c)):
				return false
	return true


## Lett: 2 pops within 10 s asks for a hint (GDD 8.3).
func recent_pops(window_s: float) -> int:
	var n: int = 0
	for t: float in pop_times:
		if time - t <= window_s:
			n += 1
	return n


# ---------------------------------------------------------------- hint line


## Best line (GDD 8.3): among all straight runs of empty cells, the one
## that captures the most cells right now if completed, skipping lines a
## ball would reach before the wall finishes; ties go to the shorter line.
## only_dir: -1 any, 0 up-down only, 1 side-side only.
## Returns {} when there is no empty cell at all.
func best_line(only_dir: int = -1, check_danger: bool = true) -> Dictionary:
	var ball_cells: Dictionary = {}
	for b: Ball in balls:
		ball_cells[cell_of(b.pos)] = true
	var best: Dictionary = {}
	var best_score: float = -1.0
	var fallback: Dictionary = {}
	var fallback_score: float = -1.0
	for seg: Dictionary in _segments(only_dir):
		var cells: Array[Vector2i] = seg["cells"]
		var g2: PackedByteArray = grid.duplicate()
		for c: Vector2i in cells:
			g2[c.y * COLS + c.x] = Cell.WALL
		var gain: int = 0
		var ball_regions: Array[int] = []
		for reg: Array[Vector2i] in _empty_regions(g2):
			var has_ball: bool = false
			for c: Vector2i in reg:
				if ball_cells.has(c):
					has_ball = true
					break
			if has_ball:
				ball_regions.append(reg.size())
			else:
				gain += reg.size()
		var minor: int = 0
		if ball_regions.size() >= 2:
			ball_regions.sort()
			minor = ball_regions[0]
		var n: int = cells.size()
		# Captured cells first; then splitting the balls apart; ties -> shorter.
		var score: float = float(gain) * 10.0 + float(minor) * 2.5 - float(n) * 0.01
		var oi: int = n / 2
		var pick: Dictionary = {
			"origin": cells[oi], "vertical": seg["vertical"], "cells": cells, "gain": gain
		}
		var danger: bool = check_danger and _line_in_danger(cells, oi)
		if not danger and score > best_score:
			best_score = score
			best = pick
		if score > fallback_score:
			fallback_score = score
			fallback = pick
	return best if not best.is_empty() else fallback


func _segments(only_dir: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if only_dir != 1:
		for c: int in COLS:
			var r: int = 0
			while r < ROWS:
				if get_cell(Vector2i(c, r)) == Cell.EMPTY:
					var cells: Array[Vector2i] = []
					while r < ROWS and get_cell(Vector2i(c, r)) == Cell.EMPTY:
						cells.append(Vector2i(c, r))
						r += 1
					out.append({"cells": cells, "vertical": true})
				r += 1
	if only_dir != 0:
		for r: int in ROWS:
			var c: int = 0
			while c < COLS:
				if get_cell(Vector2i(c, r)) == Cell.EMPTY:
					var cells: Array[Vector2i] = []
					while c < COLS and get_cell(Vector2i(c, r)) == Cell.EMPTY:
						cells.append(Vector2i(c, r))
						c += 1
					out.append({"cells": cells, "vertical": false})
				c += 1
	return out


## Predict each ball forward in a straight line until its first bounce; true
## when one reaches the line before the wall would finish.
func _line_in_danger(cells: Array[Vector2i], oi: int) -> bool:
	var t_need: float = float(maxi(oi, cells.size() - 1 - oi)) / wall_speed + 0.25
	var on_line: Dictionary = {}
	for c: Vector2i in cells:
		on_line[c] = true
	var f: float = snegl_factor()
	for b: Ball in balls:
		var p: Vector2 = b.pos
		var t: float = 0.0
		var dt: float = 0.04
		var pad: float = b.radius + 6.0
		while t < t_need:
			p += b.dir * b.speed * f * dt
			t += dt
			var stop: bool = false
			for c: Vector2i in overlap_cells(p, pad):
				if on_line.has(c):
					return true
				if is_ball_solid(get_cell(c)):
					stop = true
			if stop:
				break
	return false
