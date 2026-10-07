class_name OfFieldFx
extends Control

## 2D effects drawn over the 3D field in the bottom-anchored frame (frame
## px): the ghost wall (hexagons while a Skjold waits), the hint line, pop
## bubbles, bounce sparks, mirror glints, cage bars, tokens flying to the
## meter, the level-clear stars and the onboarding hand. Never takes touches.

const WHITE := Color(1.0, 1.0, 1.0)
const GOLD := Color(1.000, 0.788, 0.302)
const INK := Color(0.141, 0.129, 0.114)
const BUBBLE := Color(0.902, 0.965, 1.000)
const SNEGL := Color(0.361, 0.949, 0.722)
const LYN := Color(0.424, 0.816, 1.000)
const SKJOLD := Color(0.718, 0.612, 1.000)
const MIRROR_FACE := Color(0.910, 0.984, 1.000)
const CAGE_BAR := Color(0.788, 0.827, 0.902)
const DOT_STEP: float = 24.0
const GLINT_S: float = 0.15

var less_motion: bool = false
## Cell size of the level in play (72 or 48 px).
var cell: float = 72.0
## Skjold waits: the ghost is drawn with small hexagons (DESIGN 7b).
var shield_ghost: bool = false
var hand_visible: bool = false
var hand_at: Vector2 = Vector2.ZERO

# Ghost: cells (frame px centres), origin, fading/shrinking state.
var ghost_cells: Array[Vector2] = []
var ghost_origin: Vector2 = Vector2.ZERO
var ghost_vertical: bool = true
var ghost_visible: bool = false
var _ghost_in_t: float = 9.0
var _ghost_out_t: float = 9.0
var _ghost_out_mode: int = 0
var _ghost_blink_t: float = 9.0

var _hint_cells: Array[Vector2] = []
var _hint_t: float = 9.0

var _bubbles: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _flyers: Array[Dictionary] = []
## Caged rooms: rects of the caged cells (frame px), static bars.
var _cage_rects: Array[Rect2] = []
var _cage_t: float = 9.0
## Mirror glints: centre (frame px), "/" (+1) or "\\" (-1), age.
var _glints: Array[Dictionary] = []

var _hand_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _boxes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(OfBalance.DESIGN_W, OfBalance.DESIGN_H)
	_rng.seed = 77


func clear_all() -> void:
	ghost_visible = false
	_ghost_out_t = 9.0
	_hint_t = 9.0
	_bubbles.clear()
	_sparks.clear()
	_flyers.clear()
	_cage_rects.clear()
	_glints.clear()
	shield_ghost = false
	hand_visible = false


func show_ghost(cells: Array[Vector2], origin: Vector2, vertical: bool, fresh: bool) -> void:
	ghost_cells = cells
	ghost_origin = origin
	ghost_vertical = vertical
	if fresh or not ghost_visible:
		_ghost_in_t = 0.0
	ghost_visible = true
	_ghost_out_t = 9.0


## mode 0 = cancel fade (120 ms), 1 = "not yet" shrink into the dot (150 ms),
## 2 = gone at once (the wall starts).
func hide_ghost(mode: int) -> void:
	if not ghost_visible:
		return
	ghost_visible = false
	if mode == 2 or less_motion:
		_ghost_out_t = 9.0
		return
	_ghost_out_mode = mode
	_ghost_out_t = 0.0


func blink_ghost() -> void:
	_ghost_blink_t = 0.0


func show_hint(cells: Array[Vector2]) -> void:
	_hint_cells = cells
	_hint_t = 0.0


func pop_bubbles(points: Array[Vector2]) -> void:
	if less_motion:
		return
	var n: int = 0
	for p: Vector2 in points:
		var per: int = maxi(1, OfBalance.BUBBLES_PER_POP / maxi(points.size(), 1))
		for k: int in per + 1:
			if n >= OfBalance.BUBBLES_PER_POP + 4:
				break
			n += 1
			(
				_bubbles
				. append(
					{
						"p": p + Vector2(_rng.randf_range(-26, 26), _rng.randf_range(-26, 26)),
						"v": Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-90, -20)),
						"r": _rng.randf_range(8.0, 22.0),
						"t": -_rng.randf_range(0.0, 0.06),
					}
				)
			)


## Cage closed over these cells (frame px centres). Bars slide down over
## 0.3 s, or appear at once under "less motion" (GDD 9).
func add_cage(centres: Array[Vector2]) -> void:
	var h: float = cell * 0.5
	for c: Vector2 in centres:
		_cage_rects.append(Rect2(c - Vector2(h, h), Vector2(cell, cell)))
	_cage_t = 0.3 if less_motion else 0.0


func clear_cages() -> void:
	_cage_rects.clear()


func mirror_glint(c: Vector2, kind: int) -> void:
	if _glints.size() < 8:
		_glints.append({"p": c, "k": kind, "t": 0.0})


func spark(p: Vector2) -> void:
	if _sparks.size() < 12:
		_sparks.append({"p": p, "t": 0.0})


## A Snegl icon (or a clear star) flies from `from` to `to` (frame px).
func fly(kind: String, from: Vector2, to: Vector2, delay: float, dur: float) -> void:
	_flyers.append({"kind": kind, "a": from, "b": to, "t": -delay, "d": dur})


func flying() -> int:
	return _flyers.size()


func _process(delta: float) -> void:
	_ghost_in_t += delta
	_ghost_out_t += delta
	_ghost_blink_t += delta
	_hint_t += delta
	_hand_t += delta
	for b: Dictionary in _bubbles:
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) > 0.0:
			b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta
	_bubbles = _bubbles.filter(
		func(b: Dictionary) -> bool: return float(b["t"]) < OfBalance.POP_ANIM_S + 0.1
	)
	for s: Dictionary in _sparks:
		s["t"] = float(s["t"]) + delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 0.1)
	_cage_t += delta
	for g: Dictionary in _glints:
		g["t"] = float(g["t"]) + delta
	_glints = _glints.filter(func(g: Dictionary) -> bool: return float(g["t"]) < GLINT_S)
	for f: Dictionary in _flyers:
		f["t"] = float(f["t"]) + delta
	_flyers = _flyers.filter(
		func(f: Dictionary) -> bool: return float(f["t"]) < float(f["d"]) + 0.05
	)
	queue_redraw()


func _draw() -> void:
	_draw_cages()
	_draw_glints()
	_draw_hint()
	_draw_ghost()
	for b: Dictionary in _bubbles:
		var t: float = float(b["t"])
		if t < 0.0:
			continue
		var k: float = clampf(t / (OfBalance.POP_ANIM_S + 0.1), 0.0, 1.0)
		var r: float = float(b["r"]) * (0.7 + 0.5 * k)
		draw_arc(b["p"], r, 0.0, TAU, 28, Color(BUBBLE, (1.0 - k) * 0.95), 3.0, true)
		draw_circle(
			(b["p"] as Vector2) + Vector2(-r * 0.35, -r * 0.35),
			r * 0.16,
			Color(WHITE, (1.0 - k) * 0.8)
		)
	for s: Dictionary in _sparks:
		var a: float = 1.0 - float(s["t"]) / 0.1
		draw_colored_polygon(OfDisc.sparkle_points(s["p"], 12.0), Color(1.0, 0.85, 0.8, a * 0.8))
	for f: Dictionary in _flyers:
		var t: float = float(f["t"])
		if t < 0.0:
			continue
		var k: float = clampf(t / float(f["d"]), 0.0, 1.0)
		var e: float = k * k * (3.0 - 2.0 * k)
		var a: Vector2 = f["a"]
		var b: Vector2 = f["b"]
		var p: Vector2 = a.lerp(b, e) + Vector2(0.0, -140.0 * sin(PI * e))
		var kind: String = String(f["kind"])
		if kind == "snegl":
			draw_circle(p, 30.0, SNEGL)
			draw_arc(p, 30.0, 0.0, TAU, 32, WHITE, 4.0, true)
			_spiral(p, 18.0)
		elif kind == "lyn":
			draw_circle(p, 30.0, LYN)
			draw_arc(p, 30.0, 0.0, TAU, 32, WHITE, 4.0, true)
			draw_polyline(bolt_points(p, 18.0), WHITE, 4.0, true)
		elif kind == "skjold":
			draw_circle(p, 30.0, SKJOLD)
			draw_arc(p, 30.0, 0.0, TAU, 32, WHITE, 4.0, true)
			draw_polyline(hex_points(p, 16.0, true), WHITE, 4.0, true)
		else:
			var sc: float = lerpf(1.0, 0.55, e)
			var pts: PackedVector2Array = OfDisc.star_points(p, 34.0 * sc, 15.0 * sc)
			draw_colored_polygon(pts, GOLD)
			pts.append(pts[0])
			draw_polyline(pts, INK, 3.0, true)
	if hand_visible:
		_draw_hand()


## Zigzag bolt (Lyn icon) as an open polyline.
static func bolt_points(c: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			c + Vector2(0.35, -1.0) * s,
			c + Vector2(-0.3, 0.05) * s,
			c + Vector2(0.3, -0.05) * s,
			c + Vector2(-0.35, 1.0) * s,
		]
	)


static func hex_points(c: Vector2, r: float, closed: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if closed:
		pts.append(pts[0])
	return pts


## Static vertical bars over each caged cell, low contrast (rule 38).
func _draw_cages() -> void:
	if _cage_rects.is_empty():
		return
	var k: float = clampf(_cage_t / 0.3, 0.0, 1.0)
	var col := Color(CAGE_BAR, 0.75)
	var bars: int = 3
	for r: Rect2 in _cage_rects:
		var bottom: float = r.position.y + r.size.y * k
		for i: int in bars:
			var x: float = r.position.x + r.size.x * (float(i) + 0.5) / float(bars)
			draw_line(Vector2(x, r.position.y), Vector2(x, bottom), col, 4.0)


func _draw_glints() -> void:
	for g: Dictionary in _glints:
		var a: float = 1.0 - float(g["t"]) / GLINT_S
		var c: Vector2 = g["p"]
		var h: float = cell * 0.42
		var d := Vector2(h, -h) if int(g["k"]) > 0 else Vector2(h, h)
		draw_line(c - d, c + d, Color(MIRROR_FACE, 0.9 * a), 6.0, true)


func _spiral(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i: int in 30:
		var t: float = float(i) / 29.0
		var ang: float = t * TAU * 1.6
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * (0.15 + 0.85 * t))
	draw_polyline(pts, WHITE, 3.5, true)


func _dots(cells: Array[Vector2], vertical: bool, col: Color, rad: float, shrink: float) -> void:
	if cells.is_empty():
		return
	var axis := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	var lo: float = INF
	var hi: float = -INF
	for c: Vector2 in cells:
		var v: float = c.dot(axis)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	lo -= cell * 0.5 - 10.0
	hi += cell * 0.5 - 10.0
	var o: float = ghost_origin.dot(axis)
	var perp: Vector2 = ghost_origin - axis * o
	var v: float = lo
	while v <= hi + 0.1:
		if absf(v - o) > 26.0:
			var pv: float = lerpf(v, o, shrink)
			if shield_ghost:
				draw_polyline(hex_points(perp + axis * pv, rad + 3.0, true), col, 2.5, true)
			else:
				draw_circle(perp + axis * pv, rad, col)
		v += DOT_STEP


func _draw_ghost() -> void:
	var a: float = 0.0
	var shrink: float = 0.0
	if ghost_visible:
		a = 1.0 if less_motion else clampf(_ghost_in_t / 0.06, 0.0, 1.0)
		if _ghost_blink_t < 0.4:
			a *= 0.35 + 0.65 * absf(cos(_ghost_blink_t / 0.4 * PI))
	elif _ghost_out_t < 0.15:
		if _ghost_out_mode == 1:
			shrink = _ghost_out_t / 0.15
			a = 1.0 - shrink * 0.5
		else:
			a = 1.0 - _ghost_out_t / 0.12
	if a <= 0.0:
		return
	_dots(ghost_cells, ghost_vertical, Color(WHITE, 0.9 * a), 6.0, shrink)
	var rr: float = 22.0 * (1.0 - shrink * 0.6)
	draw_arc(ghost_origin, rr, 0.0, TAU, 40, Color(WHITE, a), 5.0, true)


func _draw_hint() -> void:
	var len_s: float = OfBalance.HINT_GLOW_S
	if _hint_t >= len_s or _hint_cells.is_empty():
		return
	var a: float = 0.8 if less_motion else 0.55 + 0.45 * sin(_hint_t * TAU - PI * 0.5)
	a *= 1.0 - smoothstep(len_s - 0.3, len_s, _hint_t)
	var first: Vector2 = _hint_cells[0]
	var last: Vector2 = _hint_cells[_hint_cells.size() - 1]
	var axis: Vector2 = (last - first).normalized() if last != first else Vector2(0.0, 1.0)
	var ext: float = cell * 0.5 - 6.0
	draw_line(first - axis * ext, last + axis * ext, Color(GOLD, 0.22 * a), 34.0, true)
	draw_line(first - axis * ext, last + axis * ext, Color(GOLD, 0.75 * a), 8.0, true)


## Onboarding hand (GDD 8.3): presses on the hint spot every 2.4 s.
func _draw_hand() -> void:
	var loop: float = OfBalance.HAND_LOOP_S
	var t: float = fmod(_hand_t, loop)
	var lift: float = 0.0
	if t < 0.4:
		lift = 1.0 - t / 0.4
	elif t > 1.6:
		lift = clampf((t - 1.6) / 0.4, 0.0, 1.0)
	var c: Vector2 = hand_at + Vector2(46.0, 92.0) + Vector2(14.0, 30.0) * lift
	var parts: Array = [
		[Rect2(-46, -10, 96, 90), 30.0],
		[Rect2(-12, -92, 34, 100), 17.0],
		[Rect2(22, -36, 30, 56), 15.0],
		[Rect2(50, -26, 28, 50), 14.0],
		[Rect2(-74, 0, 52, 30), 15.0],
	]
	if lift < 0.2:
		draw_arc(hand_at, 30.0, 0.0, TAU, 32, Color(WHITE, 0.8), 5.0, true)
	for pass_i: int in 2:
		for p: Array in parts:
			var r: Rect2 = p[0]
			var rad: float = float(p[1])
			var grow: float = 7.0 if pass_i == 0 else 0.0
			var rr := Rect2(
				c + r.position - Vector2(grow, grow), r.size + Vector2(grow, grow) * 2.0
			)
			_round_rect(rr, rad + grow, INK if pass_i == 0 else WHITE)


func restart_hand() -> void:
	_hand_t = 0.0


## True during the part of the hand loop where it presses down.
func hand_pressing() -> bool:
	var t: float = fmod(_hand_t, OfBalance.HAND_LOOP_S)
	return t >= 0.4 and t <= 1.6


func _round_rect(r: Rect2, rad: float, col: Color) -> void:
	var key := "%d_%s" % [int(rad), col.to_html()]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		_boxes[key] = sb
	draw_style_box(sb, r)
