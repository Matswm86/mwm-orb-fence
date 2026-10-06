class_name OfHud
extends Control

## HUD strip (GDD 8.2, DESIGN 4): glass fill meter with the target star,
## three milestone diamonds (25/50/75% of the target), the Vanlig % digits
## and the Vanlig spark bar. Not tappable. Lives in the top-anchored frame.

const HUD_PANEL := Color(0.051, 0.102, 0.200, 0.92)
const HUD_EDGE := Color(0.663, 0.741, 0.878)
const INK := Color(0.141, 0.129, 0.114)
const GOLD := Color(1.000, 0.788, 0.302)
const WHITE := Color(1.0, 1.0, 1.0)
const TUBE := Rect2(280, 96, 760, 80)
const TRACK := Rect2(294, 110, 732, 52)
const SPARK_Y: float = 206.0
const SPARK_X0: float = 316.0
const SPARK_DX: float = 44.0

var target: float = 0.65
var show_digits: bool = false
var spark_budget: int = 0
var sparks_left: int = 0
var less_motion: bool = false

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
	_track.position = TRACK.position
	_track.size = TRACK.size
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_mat = ShaderMaterial.new()
	_track_mat.shader = preload("res://shaders/meter.gdshader")
	_track_mat.set_shader_parameter("size_px", TRACK.size)
	_track.material = _track_mat
	add_child(_track)
	_pct = Label.new()
	_pct.add_theme_font_override("font", load("res://assets/fonts/Fredoka.ttf"))
	_pct.add_theme_font_size_override("font_size", 40)
	_pct.add_theme_color_override("font_color", WHITE)
	_pct.add_theme_color_override("font_outline_color", Color(0.024, 0.047, 0.110))
	_pct.add_theme_constant_override("outline_size", 8)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pct.position = Vector2(880, 106)
	_pct.size = Vector2(140, 60)
	_pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pct)
	# The track draws above the tube body, the marks above the track.
	var marks := Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.size = size
	marks.draw.connect(_draw_marks.bind(marks))
	add_child(marks)
	move_child(_pct, -1)
	set_process(true)


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
	return Vector2(TRACK.position.x + TRACK.size.x * target, TUBE.get_center().y)


func _process(delta: float) -> void:
	var k: float = clampf(delta / OfBalance.METER_EASE_S * 2.2, 0.0, 1.0)
	_fill_shown = lerpf(_fill_shown, _fill_goal, k)
	if absf(_fill_shown - _fill_goal) < 0.0005:
		_fill_shown = _fill_goal
	for i: int in 3:
		_notch_t[i] += delta
	_star_t += delta
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
		if c is Control and c != _track and c != _pct:
			(c as Control).queue_redraw()


func _update_pct() -> void:
	if show_digits:
		_pct.text = "%d%%" % int(round(_fill_goal * 100.0))


func _draw() -> void:
	draw_style_box(_panel_box, TUBE)


func _draw_marks(ci: Control) -> void:
	var tx: float = TRACK.position.x
	var tw: float = TRACK.size.x
	var cy: float = TUBE.get_center().y
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
	ci.draw_line(Vector2(sx, TRACK.position.y), Vector2(sx, TRACK.end.y), GOLD, 6.0)
	var sc: float = 1.0
	if _star_reached and not less_motion and _star_t < 0.3:
		sc = 1.0 + 0.18 * sin(_star_t / 0.3 * PI)
	var star: PackedVector2Array = OfDisc.star_points(Vector2(sx, cy), 50.0 * sc, 22.0 * sc)
	ci.draw_colored_polygon(star, GOLD)
	var closed_star := star.duplicate()
	closed_star.append(star[0])
	ci.draw_polyline(closed_star, INK, 5.0, true)
	# Spark bar (Vanlig levels with a budget only).
	for i: int in _spent_t.size():
		var c := Vector2(SPARK_X0 + SPARK_DX * i, SPARK_Y)
		var t: float = _spent_t[i]
		var spent: bool = i >= sparks_left
		var pts: PackedVector2Array = OfDisc.sparkle_points(c, 17.0)
		var closed2 := pts.duplicate()
		closed2.append(pts[0])
		if not spent:
			ci.draw_colored_polygon(pts, GOLD)
			ci.draw_polyline(closed2, INK, 2.0, true)
			continue
		ci.draw_polyline(closed2, HUD_EDGE, 2.0, true)
		if t >= 0.0 and t < 0.3 and not less_motion:
			# One crack + fall, 300 ms.
			var k: float = t / 0.3
			var fall := Vector2(0.0, 26.0 * k * k)
			var a := Color(GOLD, 1.0 - k)
			var left_half := PackedVector2Array(
				[
					c + Vector2(0, -17) + fall + Vector2(-4 * k, 0),
					c + Vector2(-17, 0) + fall,
					c + Vector2(0, 17) + fall
				]
			)
			var right_half := PackedVector2Array(
				[
					c + Vector2(0, -17) + fall + Vector2(4 * k, 0),
					c + Vector2(17, 0) + fall,
					c + Vector2(0, 17) + fall
				]
			)
			ci.draw_colored_polygon(left_half, a)
			ci.draw_colored_polygon(right_half, a)
