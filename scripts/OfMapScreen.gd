class_name OfMapScreen
extends Control

## World map (GDD 8.1, DESIGN 4): one world per page, five level discs on
## a dotted star trail between y 400 and 1500, over the world's backdrop.
## Arrow discs at y 1560 (x 160 and 920) change the world; the Uendelig disc
## sits between them at (540, 1560) once level 5 is cleared in the full game
## (GDD 6.5). No padlocks: every visible level can be picked; the lowest
## uncleared one pulses. Free part: world 1 levels 1-3 only, no arrows.
## Stand-alone only: a gear at the top-right (two-tap guard, like the home
## disc) opens the settings.

signal level_chosen(level_id: int)
signal endless_chosen
signal settings_pressed
signal page_changed(world: int)

const TRAIL := Color(0.663, 0.741, 0.878)
const GOLD := Color(1.000, 0.788, 0.302)
## Disc centres for levels 1-5 of a page (bottom to top), clear of the
## 232 px home square, the gear and the arrow / Uendelig row at y 1560
## (their hit areas start at y 1460; level hit areas end by y 1450).
const DISC_POS: Array[Vector2] = [
	Vector2(330, 1330),
	Vector2(740, 1110),
	Vector2(340, 890),
	Vector2(740, 670),
	Vector2(420, 450),
]
const GEAR_HIT: float = 216.0
const ROW_Y: float = 1560.0

var gear: OfHomeDisc
var less_motion: bool = false
## World shown, 1-6.
var page: int = 1
var endless: OfEndlessDisc
var _discs: Array[OfLevelDisc] = []
var _prev: OfDisc
var _next: OfDisc
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
	_prev = _row_disc("left", 160.0)
	_prev.tapped.connect(func() -> void: show_page(page - 1))
	_next = _row_disc("right", 920.0)
	_next.tapped.connect(func() -> void: show_page(page + 1))
	endless = OfEndlessDisc.new()
	endless.disc_radius = 100.0
	endless.size = Vector2(240, 200)
	endless.position = Vector2(540.0, ROW_Y) - endless.size * 0.5
	endless.tapped.connect(func() -> void: endless_chosen.emit())
	add_child(endless)
	set_safe_dy(0.0)


func _row_disc(icon_name: String, x: float) -> OfDisc:
	var d := OfDisc.new()
	d.icon = icon_name
	d.disc_radius = 100.0
	# 200 tall so the hit area ends at y 1660, above the wrist strip.
	d.size = Vector2(240, 200)
	d.position = Vector2(x, ROW_Y) - d.size * 0.5
	add_child(d)
	return d


func world_count() -> int:
	var n: int = OrbFence.visible_levels().size()
	return maxi(1, ceili(float(n) / float(OfBalance.LEVELS_PER_WORLD)))


## Opens the world page of the suggested level.
func refresh() -> void:
	var sug: int = OrbFence.suggested_level()
	page = OfLevels.world_of(sug) if sug > 0 else page
	show_page(page)


## Rebuilds the discs of world w from the save and the unlock flag.
func show_page(w: int) -> void:
	page = clampi(w, 1, world_count())
	for d: OfLevelDisc in _discs:
		d.queue_free()
	_discs.clear()
	var st: OfState = OrbFence
	var suggest: int = st.suggested_level()
	var first: int = (page - 1) * OfBalance.LEVELS_PER_WORLD + 1
	var tint: Color = OfLevels.world(page)["tint"]
	for id: int in st.visible_levels():
		if id < first or id >= first + OfBalance.LEVELS_PER_WORLD:
			continue
		var d := OfLevelDisc.new()
		d.level_id = id
		d.picture = OfLevels.picture(id)
		d.cleared = st.is_cleared(id)
		d.suggested = id == suggest
		d.less_motion = less_motion
		d.tint = tint
		d.disc_radius = 100.0
		var hit: float = 240.0
		d.size = Vector2(hit, hit)
		d.position = DISC_POS[id - first] - d.size * 0.5
		d.tapped.connect(func() -> void: level_chosen.emit(id))
		add_child(d)
		_discs.append(d)
	gear.visible = not st.in_shell()
	_prev.visible = page > 1
	_next.visible = page < world_count()
	endless.visible = st.endless_unlocked()
	endless.best = st.best_round(st.easy)
	endless.less_motion = less_motion
	endless.queue_redraw()
	queue_redraw()
	page_changed.emit(page)


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
