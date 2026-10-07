class_name OfDirButtons
extends Control

## The two direction buttons under the field (GDD 3.1, DESIGN 4). Chosen:
## 216 px gold disc, ink ring, white halo ring, soft shadow, ink double
## arrow. Not chosen: 176 px flat navy disc, hud_edge ring, white outline
## arrow at 80%. Size, ring, shadow and fill all differ (rule 36). Touches
## are read by OfPlay (multi-touch: one finger can turn the ghost another
## finger holds), this control only draws.

const INK := Color(0.141, 0.129, 0.114)
const GOLD := Color(1.000, 0.788, 0.302)
const WHITE := Color(1.0, 1.0, 1.0)
const HUD_PANEL := Color(0.051, 0.102, 0.200, 0.92)
const HUD_EDGE := Color(0.663, 0.741, 0.878)
const ICONS: Array[String] = ["updown", "sideside"]

## 0 = up-down, 1 = side-side.
var chosen: int = 0
## Lyn charges left (0-2): gold bolt notches at the top-right of both discs
## (count by shape, DESIGN 4).
var lyn_charges: int = 0
var less_motion: bool = false
var _down: Array[bool] = [false, false]
var _press_t: Array[float] = [9.0, 9.0]
## Hint glow (1.5 s at 1 Hz) and the one-time turn pulse (2 s at 1 Hz).
var _glow_t: Array[float] = [9.0, 9.0]
var _glow_len: Array[float] = [0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(OfBalance.DESIGN_W, OfBalance.DESIGN_H)
	set_process(true)


## Index of the button whose 240 x 240 hit area holds p (frame px), or -1.
static func hit(p: Vector2) -> int:
	for i: int in 2:
		var c: Vector2 = OfBalance.DIR_CENTERS[i]
		var h: float = OfBalance.DIR_HIT * 0.5
		if absf(p.x - c.x) <= h and absf(p.y - c.y) <= h:
			return i
	return -1


func set_down(i: int, on: bool) -> void:
	if i < 0:
		return
	_down[i] = on
	if on:
		_press_t[i] = 0.0


func glow(i: int, seconds: float) -> void:
	if i < 0 or i > 1:
		return
	_glow_t[i] = 0.0
	_glow_len[i] = seconds


func _process(delta: float) -> void:
	for i: int in 2:
		_press_t[i] += delta
		_glow_t[i] += delta
	queue_redraw()


func _draw() -> void:
	for i: int in 2:
		var c: Vector2 = OfBalance.DIR_CENTERS[i]
		var pressed: bool = _down[i] or _press_t[i] < 0.12
		var k: float = 0.94 if pressed and not less_motion else 1.0
		var glow_a: float = 0.0
		if _glow_t[i] < _glow_len[i]:
			glow_a = 0.6 + 0.4 * sin(_glow_t[i] * TAU - PI * 0.5) if not less_motion else 0.8
			glow_a *= 1.0 - smoothstep(_glow_len[i] - 0.3, _glow_len[i], _glow_t[i])
		if i == chosen:
			var r: float = OfBalance.CHOSEN_R * k
			if glow_a > 0.0:
				draw_circle(c, r + 34.0, Color(GOLD, 0.30 * glow_a))
			draw_circle(c + Vector2(0, 9), r + 4.0, Color(0.0, 0.0, 0.0, 0.35))
			draw_arc(c, r + 14.5, 0.0, TAU, 72, WHITE, 5.0, true)
			var fill: Color = GOLD
			if pressed and less_motion:
				fill = GOLD.darkened(0.15)
			draw_circle(c, r, fill)
			draw_arc(c, r - 3.0, 0.0, TAU, 72, INK, 6.0, true)
			OfDisc.draw_icon(self, ICONS[i], c, r * 0.62, INK)
		else:
			var r2: float = OfBalance.UNCHOSEN_R * k
			if glow_a > 0.0:
				draw_circle(c, r2 + 30.0, Color(GOLD, 0.35 * glow_a))
				draw_arc(c, r2 + 8.0, 0.0, TAU, 72, Color(GOLD, glow_a), 6.0, true)
			var fill2: Color = HUD_PANEL
			if pressed and less_motion:
				fill2 = HUD_PANEL.darkened(0.3)
			draw_circle(c, r2, fill2)
			draw_arc(c, r2 - 2.0, 0.0, TAU, 72, HUD_EDGE, 4.0, true)
			_outline_arrow(ICONS[i], c, r2 * 0.62, Color(WHITE, 0.8))
		_draw_lyn_notches(c)


func _draw_lyn_notches(c: Vector2) -> void:
	for n: int in lyn_charges:
		var p: Vector2 = c + Vector2(70.0 + 34.0 * float(n), -84.0)
		draw_circle(p, 17.0, INK)
		draw_circle(p, 14.0, GOLD)
		draw_polyline(OfFieldFx.bolt_points(p, 9.0), INK, 3.5, true)


## Outline version of the double arrow for the unchosen disc: the same
## shape as the chosen icon (one bar, two heads), drawn as a thin outline.
func _outline_arrow(name: String, c: Vector2, s: float, col: Color) -> void:
	var ax := Vector2(0.0, 1.0) if name == "updown" else Vector2(1.0, 0.0)
	var px := Vector2(-ax.y, ax.x)
	var half_len: float = s * 0.62
	draw_line(c - ax * half_len * 0.45, c + ax * half_len * 0.45, col, 5.0, true)
	for sgn: float in [-1.0, 1.0]:
		var tip: Vector2 = c + ax * half_len * sgn
		var base: Vector2 = c + ax * half_len * 0.45 * sgn
		var tri := PackedVector2Array([tip, base + px * s * 0.32, base - px * s * 0.32, tip])
		draw_polyline(tri, col, 4.0, true)
