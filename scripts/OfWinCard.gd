class_name OfWinCard
extends Control

## Win card (GDD 8.4, DESIGN 4, wincard_mock.png): the scene blurred and
## dimmed behind a light card, the level's whole picture in a rounded ink
## frame, one big star landing on it, three icon discs (replay, map, gold
## next). No text. Never auto-advances. Positions are in the 1080 x 1920
## design frame; the owner places this control at the frame offset.

signal replay_pressed
signal map_pressed
signal next_pressed

const CARD := Color(0.957, 0.973, 1.000)
const CARD_EDGE := Color(0.431, 0.537, 0.722)
const GOLD := Color(1.000, 0.788, 0.302)
const INK := Color(0.141, 0.129, 0.114)
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const CARD_RECT := Rect2(100, 360, 880, 1090)
const PIC_RECT := Rect2(150, 410, 780, 650)
const STAR_C := Vector2(540, 1050)

var less_motion: bool = false
var _t: float = 0.0
var _replay: OfDisc
var _map: OfDisc
var _next: OfDisc
var _backdrop: ColorRect
var _backdrop_mat: ShaderMaterial
var _pic: TextureRect
var _pic_mat: ShaderMaterial
var _card_box: StyleBoxFlat
var _star: Control
var _shadow_box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(OfBalance.DESIGN_W, OfBalance.DESIGN_H)
	_backdrop = ColorRect.new()
	_backdrop.position = Vector2(-2000, -2000)
	_backdrop.size = Vector2(6000, 6000)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = preload("res://shaders/blur_dim.gdshader")
	_backdrop.material = _backdrop_mat
	add_child(_backdrop)
	_card_box = StyleBoxFlat.new()
	_card_box.bg_color = CARD
	_card_box.border_color = CARD_EDGE
	_card_box.set_border_width_all(4)
	_card_box.set_corner_radius_all(56)
	_card_box.anti_aliasing = true
	_shadow_box = StyleBoxFlat.new()
	_shadow_box.bg_color = SHADOW
	_shadow_box.set_corner_radius_all(56)
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = size
	card.draw.connect(
		func() -> void:
			card.draw_style_box(
				_shadow_box, Rect2(CARD_RECT.position + Vector2(0, 14), CARD_RECT.size)
			)
			card.draw_style_box(_card_box, CARD_RECT)
	)
	add_child(card)
	_pic = TextureRect.new()
	_pic.position = PIC_RECT.position
	_pic.size = PIC_RECT.size
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic_mat = ShaderMaterial.new()
	_pic_mat.shader = preload("res://shaders/picture_frame.gdshader")
	_pic_mat.set_shader_parameter("size_px", PIC_RECT.size)
	_pic.material = _pic_mat
	add_child(_pic)
	var star := Control.new()
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.size = size
	star.draw.connect(_draw_star.bind(star))
	add_child(star)
	_star = star
	_replay = _disc("replay", Vector2(270, 1300), 100.0, OfDisc.WHITE)
	_map = _disc("map", Vector2(540, 1300), 100.0, OfDisc.WHITE)
	_next = _disc("next", Vector2(810, 1300), 120.0, OfDisc.NEXT)
	_replay.tapped.connect(func() -> void: replay_pressed.emit())
	_map.tapped.connect(func() -> void: map_pressed.emit())
	_next.tapped.connect(func() -> void: next_pressed.emit())
	visible = false


func _disc(icon_name: String, c: Vector2, r: float, f: Color) -> OfDisc:
	var d := OfDisc.new()
	d.icon = icon_name
	d.disc_radius = r
	d.fill = f
	var hit: float = maxf(r * 2.0 + 20.0, 240.0)
	d.position = c - Vector2(hit, hit) * 0.5
	d.size = Vector2(hit, hit)
	add_child(d)
	return d


func show_card(picture: Texture2D, has_next: bool) -> void:
	_pic.texture = picture
	_next.visible = has_next
	# Without a next disc, replay and map sit centred as a pair.
	var replay_x: float = 270.0 if has_next else 360.0
	var map_x: float = 540.0 if has_next else 720.0
	_replay.position.x = replay_x - _replay.size.x * 0.5
	_map.position.x = map_x - _map.size.x * 0.5
	_t = 0.0
	visible = true
	modulate.a = 1.0 if less_motion else 0.0
	set_process(true)
	queue_redraw()


func hide_card() -> void:
	visible = false
	set_process(false)


func has_next() -> bool:
	return _next.visible


func _process(delta: float) -> void:
	_t += delta
	if not less_motion:
		modulate.a = clampf(_t / OfBalance.WIN_CARD_FADE_S, 0.0, 1.0)
	_star.queue_redraw()
	if _t > 1.0:
		set_process(false)


func _draw_star(ci: Control) -> void:
	# Star lands 0.6 -> 1.08 -> 1.0 in 300 ms (DESIGN 4).
	var k: float = clampf((_t - 0.15) / 0.3, 0.0, 1.0)
	var sc: float = 1.0
	if not less_motion:
		sc = lerpf(0.6, 1.08, k / 0.7) if k < 0.7 else lerpf(1.08, 1.0, (k - 0.7) / 0.3)
		if _t < 0.15:
			return
	var outer: float = 110.0 * sc
	var pts: PackedVector2Array = OfDisc.star_points(STAR_C, outer, outer * 0.46)
	ci.draw_colored_polygon(pts, GOLD)
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, 12.0, true)
