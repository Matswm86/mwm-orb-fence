class_name OfEndlessDisc
extends OfDisc

## Uendelig disc on the world map (GDD 6.5, 8.1): 200 px, a coral orb with a
## looping orbit trail, no text. The best round for the current setting sits
## as a small digit on a gold star at its top-right (0 = no star).

const ORB := Color(1.000, 0.435, 0.380)
const ORB_CORE := Color(1.000, 0.957, 0.925)
const NAVY := Color(0.051, 0.102, 0.200)
const HUD_EDGE := Color(0.663, 0.741, 0.878)
const GOLD := Color(1.000, 0.788, 0.302)

var best: int = 0
var less_motion: bool = false
var _spin: float = 0.0
var _font: Font


func _ready() -> void:
	super._ready()
	_font = load("res://assets/fonts/Fredoka.ttf") as Font
	set_process(true)


func _process(delta: float) -> void:
	_press_t += delta
	if not less_motion:
		_spin += delta * 0.6
	queue_redraw()


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = 0.94 if pressed else 1.0
	var c: Vector2 = center()
	var r: float = disc_radius * k
	draw_circle(c, r, NAVY)
	draw_arc(c, r - 3.0, 0.0, TAU, 64, HUD_EDGE, 6.0, true)
	# Looping orbit trail: a tilted ellipse of dots, brighter towards the orb.
	var n: int = 28
	var orb_at := Vector2.ZERO
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + _spin
		var p: Vector2 = c + Vector2(cos(a) * r * 0.66, sin(a) * r * 0.30).rotated(-0.45)
		var f: float = float(i) / float(n - 1)
		draw_circle(p, 3.0 + 3.0 * f, Color(GOLD, 0.25 + 0.65 * f))
		orb_at = p
	draw_circle(orb_at, r * 0.2, ORB)
	draw_circle(orb_at - Vector2(r, r) * 0.05, r * 0.11, ORB_CORE)
	draw_arc(orb_at, r * 0.27, 0.0, TAU, 32, Color(1, 1, 1), 4.0, true)
	draw_circle(c, r * 0.16, Color(0.498, 0.714, 1.000))
	if best > 0:
		var sc: Vector2 = c + Vector2(r * 0.74, -r * 0.74)
		var pts: PackedVector2Array = OfDisc.star_points(sc, 48.0, 22.0)
		draw_colored_polygon(pts, GOLD)
		pts.append(pts[0])
		draw_polyline(pts, INK, 5.0, true)
		var fs: int = 34 if best < 10 else 27
		draw_string_outline(
			_font,
			sc + Vector2(-40.0, fs * 0.36),
			str(best),
			HORIZONTAL_ALIGNMENT_CENTER,
			80.0,
			fs,
			4,
			INK
		)
		draw_string(
			_font,
			sc + Vector2(-40.0, fs * 0.36),
			str(best),
			HORIZONTAL_ALIGNMENT_CENTER,
			80.0,
			fs,
			INK
		)
