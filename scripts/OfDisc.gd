class_name OfDisc
extends Control

## Round icon button (DESIGN section 4): white disc, ink ring, ink icon drawn
## from shapes (no text, no fonts). Pressed: 94% + green_soft fill. Acts on
## release inside the control; the touch area is the whole control rect, the
## disc can sit anywhere in it.

signal tapped

const INK := Color(0.141, 0.129, 0.114)
const WHITE := Color(1.0, 1.0, 1.0)
const GREEN_SOFT := Color(0.890, 0.941, 0.918)
const NEXT := Color(1.000, 0.788, 0.302)

## Touches are ignored until this tick (holdover after a screen change).
static var block_until_ms: int = 0
## Played on touch-down of every disc (GDD 9 UI tap); set by OfMain.
static var tap_sound: Callable = Callable()

@export var icon: String = "play"
@export var disc_radius: float = 100.0
@export var ring_px: float = 6.0
@export var fill: Color = WHITE
## Disc centre inside the control; negative = the middle of the rect.
@export var disc_center: Vector2 = Vector2(-1, -1)

var _down: bool = false
var _press_t: float = 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


static func block_input(ms: int) -> void:
	block_until_ms = Time.get_ticks_msec() + ms


func center() -> Vector2:
	return size * 0.5 if disc_center.x < 0.0 else disc_center


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Time.get_ticks_msec() < block_until_ms:
		_down = false
		return
	if mb.pressed:
		_down = true
		_press_t = 0.0
		if tap_sound.is_valid():
			tap_sound.call()
		set_process(true)
		queue_redraw()
		accept_event()
	elif _down:
		_down = false
		queue_redraw()
		accept_event()
		if Rect2(Vector2.ZERO, size).has_point(mb.position):
			_on_tapped()


func _on_tapped() -> void:
	tapped.emit()


## Test hook and Android back: behaves like a release on the disc.
func press() -> void:
	_on_tapped()


func _process(delta: float) -> void:
	_press_t += delta
	queue_redraw()
	if _press_t > 0.12 and not _down:
		set_process(false)


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = 0.94 if pressed else 1.0
	var c: Vector2 = center()
	var r: float = disc_radius * k
	var f: Color = GREEN_SOFT if pressed and fill == WHITE else fill
	draw_circle(c, r, f)
	draw_arc(c, r - ring_px * 0.5, 0.0, TAU, 64, INK, ring_px, true)
	OfDisc.draw_icon(self, icon, c, r * 0.55, INK)


## Shared icon painter (also used by the map and win card).
static func draw_icon(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	match name:
		"play", "next":
			var pts := PackedVector2Array(
				[
					c + Vector2(-0.45, -0.6) * s,
					c + Vector2(0.65, 0.0) * s,
					c + Vector2(-0.45, 0.6) * s
				]
			)
			ci.draw_colored_polygon(pts, col)
		"replay":
			# Open "C" with the arrowhead at the top pointing clockwise.
			var a0: float = deg_to_rad(20.0)
			var a1: float = deg_to_rad(285.0)
			ci.draw_arc(c, s * 0.6, a0, a1, 40, col, s * 0.24, true)
			var p: Vector2 = c + Vector2(cos(a1), sin(a1)) * s * 0.6
			var dir := Vector2(-sin(a1), cos(a1))
			var perp := Vector2(-dir.y, dir.x)
			var tri := PackedVector2Array(
				[
					p + dir * s * 0.42,
					p + perp * s * 0.36 - dir * s * 0.05,
					p - perp * s * 0.36 - dir * s * 0.05
				]
			)
			ci.draw_colored_polygon(tri, col)
		"map":
			var p0: Vector2 = c + Vector2(-0.55, 0.5) * s
			var p1: Vector2 = c + Vector2(0.0, 0.0) * s
			var p2: Vector2 = c + Vector2(0.55, -0.5) * s
			ci.draw_line(p0, p2, col, s * 0.14, true)
			for p: Vector2 in [p0, p1, p2]:
				ci.draw_circle(p, s * 0.2, col)
		"home":
			var roof := PackedVector2Array(
				[
					c + Vector2(-0.8, -0.05) * s,
					c + Vector2(0.0, -0.8) * s,
					c + Vector2(0.8, -0.05) * s
				]
			)
			ci.draw_colored_polygon(roof, col)
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.1) * s, Vector2(1.1, 0.8) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.17, 0.25) * s, Vector2(0.34, 0.45) * s), WHITE)
		"gear":
			var pts := PackedVector2Array()
			for i: int in 32:
				var ang: float = TAU * float(i) / 32.0
				var rr: float = 0.78 if (i / 2) % 2 == 0 else 0.58
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr * s)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c, s * 0.24, WHITE)
		"left", "right":
			var d: float = -1.0 if name == "left" else 1.0
			var pts := PackedVector2Array(
				[
					c + Vector2(-0.25 * d, -0.6) * s,
					c + Vector2(0.35 * d, 0.0) * s,
					c + Vector2(-0.25 * d, 0.6) * s,
				]
			)
			ci.draw_polyline(pts, col, s * 0.22, true)
		"close":
			ci.draw_line(c + Vector2(-0.5, -0.5) * s, c + Vector2(0.5, 0.5) * s, col, s * 0.2, true)
			ci.draw_line(c + Vector2(0.5, -0.5) * s, c + Vector2(-0.5, 0.5) * s, col, s * 0.2, true)
		"updown", "sideside":
			# Double arrow with an origin dot (DESIGN 4): bar, two heads.
			var ax := Vector2(0.0, 1.0) if name == "updown" else Vector2(1.0, 0.0)
			var px := Vector2(-ax.y, ax.x)
			var half_len: float = s * 0.62
			ci.draw_line(c - ax * half_len * 0.6, c + ax * half_len * 0.6, col, s * 0.17, true)
			for sgn: float in [-1.0, 1.0]:
				var tip: Vector2 = c + ax * half_len * sgn
				var base: Vector2 = c + ax * half_len * 0.45 * sgn
				ci.draw_colored_polygon(
					PackedVector2Array([tip, base + px * s * 0.32, base - px * s * 0.32]), col
				)
			ci.draw_circle(c, s * 0.15, col)
		"music":
			# Two beamed eighth notes.
			var w: float = s * 0.14
			for hx: float in [-0.45, 0.45]:
				var head: Vector2 = c + Vector2(hx, 0.55) * s
				ci.draw_set_transform(head, -0.35, Vector2(1.3, 1.0))
				ci.draw_circle(Vector2.ZERO, s * 0.24, col)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var top: Vector2 = c + Vector2(hx + 0.26, -0.75) * s
				ci.draw_line(head + Vector2(0.26 * s, 0.0), top, col, w, true)
			ci.draw_line(
				c + Vector2(-0.19, -0.75) * s, c + Vector2(0.71, -0.75) * s, col, s * 0.24, true
			)


## Four-point sparkle (spark bar, DESIGN 4).
static func sparkle_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 8:
		var ang: float = -PI * 0.5 + TAU * float(i) / 8.0
		var rr: float = r if i % 2 == 0 else r * 0.32
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	return pts


## Diamond (meter notches).
static func diamond_points(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	return PackedVector2Array(
		[c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)]
	)


## Five-point star polygon.
static func star_points(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 10:
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	return pts
