class_name OfMapScreen
extends Control

## World 1 map page (GDD 8.1, DESIGN 4): five level discs on a dotted star
## trail between y 400 and 1500, over the world's backdrop. No padlocks:
## every visible level can be picked; the lowest uncleared one pulses.
## Stand-alone only: a gear at the top-right (two-tap guard, like the home
## disc) opens the settings.

signal level_chosen(level_id: int)
signal settings_pressed

const TRAIL := Color(0.663, 0.741, 0.878)
const GOLD := Color(1.000, 0.788, 0.302)
## Disc centres for levels 1-5 (bottom to top), clear of the 232 px home
## square, the gear and the wrist strip.
const DISC_POS: Array[Vector2] = [
	Vector2(330, 1430),
	Vector2(740, 1190),
	Vector2(340, 950),
	Vector2(740, 710),
	Vector2(420, 470),
]
const GEAR_HIT: float = 216.0

var gear: OfHomeDisc
var less_motion: bool = false
var _discs: Array[OfLevelDisc] = []
var _safe_dy: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(OfBalance.DESIGN_W, OfBalance.DESIGN_H)
	gear = OfHomeDisc.new()
	gear.icon = "gear"
	gear.disc_radius = 68.0
	gear.ring_px = 5.0
	gear.confirmed.connect(func() -> void: settings_pressed.emit())
	add_child(gear)
	set_safe_dy(0.0)


## Rebuilds the discs from the save and the unlock flag.
func refresh() -> void:
	for d: OfLevelDisc in _discs:
		d.queue_free()
	_discs.clear()
	var st: OfState = OrbFence
	var suggest: int = st.suggested_level()
	for id: int in st.visible_levels():
		var d := OfLevelDisc.new()
		d.level_id = id
		d.picture = OfLevels.picture(id)
		d.cleared = st.is_cleared(id)
		d.suggested = id == suggest
		d.less_motion = less_motion
		d.disc_radius = 100.0
		var hit: float = 240.0
		d.size = Vector2(hit, hit)
		d.position = DISC_POS[id - 1] - d.size * 0.5
		d.tapped.connect(func() -> void: level_chosen.emit(id))
		add_child(d)
		_discs.append(d)
	gear.visible = not st.in_shell()
	queue_redraw()


func disc_for(id: int) -> OfLevelDisc:
	for d: OfLevelDisc in _discs:
		if d.level_id == id:
			return d
	return null


## Gear sits in the top-right screen corner; its touch area runs to the
## corner and grows down by the camera cutout depth (ball-connect 7ad7d50).
## frame_pos = where this design frame sits on the screen.
func set_safe_dy(dy: float, frame_pos: Vector2 = Vector2.ZERO) -> void:
	_safe_dy = dy
	gear.position = Vector2(OfBalance.DESIGN_W - GEAR_HIT + frame_pos.x, -frame_pos.y)
	gear.size = Vector2(GEAR_HIT, GEAR_HIT + dy)
	gear.disc_center = Vector2(GEAR_HIT - 104.0, 104.0 + dy)
	gear.queue_redraw()


## Dotted star trail between the discs.
func _draw() -> void:
	var n: int = _discs.size()
	if n < 1:
		return
	var pts := PackedVector2Array()
	pts.append(DISC_POS[0] + Vector2(-120, 170))
	for i: int in n:
		pts.append(DISC_POS[i])
	for i: int in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps: int = int(a.distance_to(b) / 30.0)
		for k: int in steps:
			var t: float = float(k) / float(steps)
			var e: float = t * t * (3.0 - 2.0 * t)
			var p := Vector2(lerpf(a.x, b.x, e), lerpf(a.y, b.y, t))
			if p.distance_to(a) < 112.0 and i > 0 or p.distance_to(b) < 112.0:
				continue
			var big: bool = k % 4 == 0
			if big:
				draw_colored_polygon(OfDisc.sparkle_points(p, 11.0), Color(GOLD, 0.85))
			else:
				draw_circle(p, 4.5, Color(TRAIL, 0.8))
