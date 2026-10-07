class_name OfHud
extends Control

## HUD strip (GDD 8.2, DESIGN 4): glass fill meter with the target star,
## three milestone diamonds (25/50/75% of the target), the Vanlig % digits
## and the Vanlig spark bar (it shrinks its sparkles so up to 42 fit). In
## Uendelig (GDD 6.5) the meter and spark bar end at x 860 and a round badge
## (disc 150 px at (960, 136)) shows the round; in Vanlig a small gold star
## under it shows the best round. Not tappable. Lives in the top frame.

const HUD_PANEL := Color(0.051, 0.102, 0.200, 0.92)
const HUD_EDGE := Color(0.663, 0.741, 0.878)
const INK := Color(0.141, 0.129, 0.114)
const GOLD := Color(1.000, 0.788, 0.302)
const WHITE := Color(1.0, 1.0, 1.0)
const TUBE_FULL := Rect2(280, 96, 760, 80)
const TUBE_ENDLESS := Rect2(280, 96, 580, 80)
const INSET: float = 14.0
const SPARK_Y: float = 206.0
const SPARK_X0: float = 316.0
const SPARK_DX: float = 44.0
const SPARK_R: float = 17.0
const BADGE_C := Vector2(960, 136)
const BADGE_R: float = 75.0
const BEST_C := Vector2(1008, 196)

var target: float = 0.65
var show_digits: bool = false
var spark_budget: int = 0
var sparks_left: int = 0
var less_motion: bool = false
## Uendelig: round badge on, meter shortened. round 0 = not in Uendelig.
var endless_round: int = 0
var endless_best: int = 0

var _tube: Rect2 = TUBE_FULL
var _trk: Rect2 = Rect2(294, 110, 732, 52)
var _badge_t: float = 9.0
var _round_lbl: Label
var _best_lbl: Label
var _fill_shown: float = 0.0
var _fill_goal: float = 0.0
var _milestones: int = 0
var _notch_t: Array[float] = [9.0, 9.0, 9.0]
var _star_t: float = 9.0
var _star_reached: bool = false
var _spent_t: Array[float] = []
var _track: ColorRect
var _track_mat: ShaderMaterial
var _pct: Label
var _panel_box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(OfBalance.DESIGN_W, 260.0)
	_panel_box = StyleBoxFlat.new()
	_panel_box.bg_color = HUD_PANEL
	_panel_box.border_color = HUD_EDGE
	_panel_box.set_border_width_all(4)
	_panel_box.set_corner_radius_all(40)
	_panel_box.anti_aliasing = true
	_track = ColorRect.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_mat = ShaderMaterial.new()
	_track_mat.shader = preload("res://shaders/meter.gdshader")
	_track.material = _track_mat
	add_child(_track)
	_pct = _label(40, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_pct.size = Vector2(140, 60)
	_round_lbl = _label(84, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_round_lbl.size = Vector2(BADGE_R * 2.0, BADGE_R * 2.0)
	_round_lbl.position = BADGE_C - _round_lbl.size * 0.5
	_best_lbl = _label(24, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_best_lbl.add_theme_color_override("font_outline_color", INK)
	_best_lbl.add_theme_constant_override("outline_size", 3)
	_best_lbl.size = Vector2(60, 40)
	_best_lbl.position = BEST_C - _best_lbl.size * 0.5 + Vector2(0, 2)
	_set_layout()
	# The track draws above the tube body, the marks above the track.
	var marks := Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.size = size
	marks.draw.connect(_draw_marks.bind(marks))
	add_child(marks)
	move_child(_pct, -1)
	move_child(_round_lbl, -1)
	move_child(_best_lbl, -1)
	set_process(true)


func _label(px: int, col: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load("res://assets/fonts/Fredoka.ttf"))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.024, 0.047, 0.110))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _set_layout() -> void:
	_tube = TUBE_ENDLESS if endless_round > 0 else TUBE_FULL
	_trk = Rect2(_tube.position + Vector2(INSET, INSET), _tube.size - Vector2(INSET, INSET) * 2.0)
	_track.position = _trk.position
	_track.size = _trk.size
	_track_mat.set_shader_parameter("size_px", _trk.size)
	_pct.position = Vector2(_tube.end.x - 160.0, 106)
	_round_lbl.visible = endless_round > 0
	_best_lbl.visible = endless_round > 0 and show_digits and endless_best > 0
	if endless_round > 0:
		_round_lbl.text = str(endless_round)
		# 10+ two digits at 80% size (GDD 6.5).
		_round_lbl.add_theme_font_size_override("font_size", 84 if endless_round < 10 else 67)
		_best_lbl.text = str(endless_best)


## Uendelig on (round >= 1) or off (0). The badge pulses once per round
## start (pulse = the flash limiter allowed it).
## Meter fill in the world's crystal tint (DESIGN 4), stripes a lighter tint.
func set_tint(tint: Color) -> void:
	_track_mat.set_shader_parameter("tint", tint)
	_track_mat.set_shader_parameter("stripe", tint.lerp(Color(1, 1, 1), 0.4))


func set_endless(round_k: int, best: int, pulse: bool) -> void:
	endless_round = round_k
	endless_best = best
	_set_layout()
	if pulse and not less_motion:
		_badge_t = 0.0


func reset(level_target: float, digits: bool, budget: int) -> void:
	target = level_target
	show_digits = digits
	spark_budget = budget
	sparks_left = budget
	_fill_shown = 0.0
	_fill_goal = 0.0
	_milestones = 0
	_notch_t = [9.0, 9.0, 9.0]
	_star_t = 9.0
	_star_reached = false
	_spent_t.clear()
	for i: int in budget:
		_spent_t.append(-1.0)
	_pct.visible = digits
	_set_layout()
	_update_pct()


func set_fill(fill_ratio: float) -> void:
	_fill_goal = clampf(fill_ratio, 0.0, 1.0)
	if less_motion:
		_fill_shown = _fill_goal


func light_milestone(index: int) -> void:
	_milestones = maxi(_milestones, index + 1)
	if index >= 0 and index < 3:
		_notch_t[index] = 0.0


func star_reached() -> void:
	if not _star_reached:
		_star_reached = true
		_star_t = 0.0


func spend_spark(left: int) -> void:
	sparks_left = left
	var idx: int = left
	if idx >= 0 and idx < _spent_t.size():
		_spent_t[idx] = 0.0


func refill_sparks() -> void:
	sparks_left = spark_budget
	for i: int in _spent_t.size():
		_spent_t[i] = -1.0


## Screen-frame position of the target star (for the clear stars and token).
func star_pos() -> Vector2:
	return Vector2(_trk.position.x + _trk.size.x * target, _tube.get_center().y)


func _process(delta: float) -> void:
	var k: float = clampf(delta / OfBalance.METER_EASE_S * 2.2, 0.0, 1.0)
	_fill_shown = lerpf(_fill_shown, _fill_goal, k)
	if absf(_fill_shown - _fill_goal) < 0.0005:
		_fill_shown = _fill_goal
	for i: int in 3:
		_notch_t[i] += delta
	_star_t += delta
	_badge_t += delta
	for i: int in _spent_t.size():
		if _spent_t[i] >= 0.0:
			_spent_t[i] += delta
	_track_mat.set_shader_parameter("fill", _fill_shown)
	var sh: float = 0.0
	if not less_motion and _star_t < 0.3:
		sh = 1.0 - _star_t / 0.3
	_track_mat.set_shader_parameter("shimmer", sh)
	_update_pct()
	queue_redraw()
	for c: Node in get_children():
		if c is Control and c != _track and not c is Label:
			(c as Control).queue_redraw()


func _update_pct() -> void:
	if show_digits:
		_pct.text = "%d%%" % int(round(_fill_goal * 100.0))


func _draw() -> void:
	draw_style_box(_panel_box, _tube)


## Centre x and sparkle radius of spark i: 44 px apart from x 316 when the
## budget fits, closer and smaller when it does not (up to 42 sparks).
func spark_slot(i: int) -> Vector2:
	var x0: float = SPARK_X0 if endless_round == 0 else 300.0
	var x1: float = 1040.0 - SPARK_R if endless_round == 0 else 860.0 - SPARK_R
	var n: int = maxi(_spent_t.size(), 1)
	var dx: float = SPARK_DX
	if n > 1:
		dx = minf(SPARK_DX, (x1 - x0) / float(n - 1))
	return Vector2(x0 + dx * float(i), minf(SPARK_R, dx * 0.42))


func _draw_marks(ci: Control) -> void:
	var tx: float = _trk.position.x
	var tw: float = _trk.size.x
	var cy: float = _tube.get_center().y
	# Notches at 25/50/75% of the target (shape + fill, not colour only).
	for i: int in 3:
		var x: float = tx + tw * target * OfBalance.MILESTONES[i]
		var lit: bool = i < _milestones
		var s: float = 1.0
		if lit and not less_motion and _notch_t[i] < 0.3:
			s = 1.0 + 0.35 * sin(_notch_t[i] / 0.3 * PI)
		var pts: PackedVector2Array = OfDisc.diamond_points(Vector2(x, cy), 11.0 * s, 16.0 * s)
		var closed := pts.duplicate()
		closed.append(pts[0])
		if lit:
			ci.draw_colored_polygon(pts, WHITE)
			ci.draw_polyline(closed, INK, 3.0, true)
		else:
			ci.draw_polyline(closed, HUD_EDGE, 3.0, true)
	# Target star with a gold tick across the track.
	var sx: float = tx + tw * target
	ci.draw_line(Vector2(sx, _trk.position.y), Vector2(sx, _trk.end.y), GOLD, 6.0)
	var sc: float = 1.0
	if _star_reached and not less_motion and _star_t < 0.3:
		sc = 1.0 + 0.18 * sin(_star_t / 0.3 * PI)
	var star: PackedVector2Array = OfDisc.star_points(Vector2(sx, cy), 50.0 * sc, 22.0 * sc)
	ci.draw_colored_polygon(star, GOLD)
	var closed_star := star.duplicate()
	closed_star.append(star[0])
	ci.draw_polyline(closed_star, INK, 5.0, true)
	# Spark bar (Vanlig levels with a budget only).
	if endless_round > 0:
		_draw_badge(ci)
	for i: int in _spent_t.size():
		var slot: Vector2 = spark_slot(i)
		var c := Vector2(slot.x, SPARK_Y)
		var sr: float = slot.y
		var t: float = _spent_t[i]
		var spent: bool = i >= sparks_left
		# Small sparkles (big budgets) get a fatter waist and no ink edge, so
		# the gold still reads and spent ones stay dimmer than live ones.
		var small: bool = sr < 12.0
		var pts: PackedVector2Array = OfDisc.sparkle_points(c, sr, 0.45 if small else 0.32)
		var closed2 := pts.duplicate()
		closed2.append(pts[0])
		if not spent:
			ci.draw_colored_polygon(pts, GOLD)
			if not small:
				ci.draw_polyline(closed2, INK, 2.0, true)
			continue
		ci.draw_polyline(
			closed2, Color(HUD_EDGE, 0.55) if small else HUD_EDGE, 1.5 if small else 2.0, true
		)
		if t >= 0.0 and t < 0.3 and not less_motion:
			# One crack + fall, 300 ms.
			var k: float = t / 0.3
			var fall := Vector2(0.0, 26.0 * k * k)
			var a := Color(GOLD, 1.0 - k)
			var left_half := PackedVector2Array(
				[
					c + Vector2(0, -sr) + fall + Vector2(-4 * k, 0),
					c + Vector2(-sr, 0) + fall,
					c + Vector2(0, sr) + fall
				]
			)
			var right_half := PackedVector2Array(
				[
					c + Vector2(0, -sr) + fall + Vector2(4 * k, 0),
					c + Vector2(sr, 0) + fall,
					c + Vector2(0, sr) + fall
				]
			)
			ci.draw_colored_polygon(left_half, a)
			ci.draw_colored_polygon(right_half, a)


## Round badge: hud_panel disc with a hud_edge ring, the round digit is a
## Label on top; Vanlig adds the best round on a small gold star.
func _draw_badge(ci: Control) -> void:
	var sc: float = 1.0
	if _badge_t < 0.3:
		sc = 1.0 + 0.12 * sin(_badge_t / 0.3 * PI)
	var r: float = BADGE_R * sc
	ci.draw_circle(BADGE_C, r, HUD_PANEL)
	ci.draw_arc(BADGE_C, r - 2.0, 0.0, TAU, 64, HUD_EDGE, 4.0, true)
	_round_lbl.scale = Vector2(sc, sc)
	_round_lbl.pivot_offset = _round_lbl.size * 0.5
	if _best_lbl.visible:
		var star: PackedVector2Array = OfDisc.star_points(BEST_C, 27.0, 13.0)
		ci.draw_colored_polygon(star, GOLD)
		star.append(star[0])
		ci.draw_polyline(star, INK, 3.0, true)
