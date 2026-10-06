class_name OfLevelDisc
extends OfDisc

## Map level disc (DESIGN 4): a small planet in the world's crystal tint
## showing that level's picture, a 6 px hud_edge ring; cleared = gold star
## with an ink outline at its top-right; the suggested level gets a gold
## ring that pulses at 1 Hz between 60% and 100% (never a flash).

const HUD_EDGE := Color(0.663, 0.741, 0.878)
const CRYSTAL := Color(0.498, 0.714, 1.000)
const GOLD := Color(1.000, 0.788, 0.302)

var level_id: int = 1
var picture: Texture2D
var cleared: bool = false
var suggested: bool = false
var less_motion: bool = false
var _pulse_t: float = 0.0


func _ready() -> void:
	super._ready()
	set_process(true)


func _process(delta: float) -> void:
	_press_t += delta
	_pulse_t += delta
	queue_redraw()


func _draw() -> void:
	var pressed: bool = _down or _press_t < 0.1
	var k: float = 0.94 if pressed else 1.0
	var c: Vector2 = center()
	var r: float = disc_radius * k
	draw_circle(c, r + 14.0, Color(CRYSTAL, 0.14))
	draw_circle(c, r, CRYSTAL)
	if picture != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		# Circle crop of the picture's centre square.
		var aspect: float = float(picture.get_width()) / float(picture.get_height())
		for i: int in 48:
			var ang: float = TAU * float(i) / 48.0
			var d := Vector2(cos(ang), sin(ang))
			pts.append(c + d * (r - 4.0))
			uvs.append(Vector2(0.5 + d.x * 0.5, 0.5 + d.y * 0.5 * aspect))
		draw_colored_polygon(pts, Color(1, 1, 1), uvs, picture)
	if suggested:
		var a: float = 0.8 if less_motion else 0.8 + 0.2 * sin(_pulse_t * TAU)
		draw_arc(c, r + 10.0, 0.0, TAU, 64, Color(GOLD, a), 10.0, true)
	draw_arc(c, r - 3.0, 0.0, TAU, 64, HUD_EDGE, 6.0, true)
	if cleared:
		var sc: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		var pts2: PackedVector2Array = OfDisc.star_points(sc, 44.0, 20.0)
		draw_colored_polygon(pts2, GOLD)
		pts2.append(pts2[0])
		draw_polyline(pts2, INK, 5.0, true)
