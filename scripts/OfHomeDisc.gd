class_name OfHomeDisc
extends OfDisc

## Stand-alone home disc (top-left shell square) and the settings gear
## (GDD 3.3, DESIGN 4).
## Copies the MWM Play guard: the first tap grows the disc and fills a ring
## over 2.0 s while the game keeps running; a second tap between 0.3 s and
## 2.0 s confirms. Hidden when the game runs inside MWM Play.

signal confirmed

const HALO := Color(1.0, 1.0, 1.0, 0.25)
const RING_FILL := Color(1.000, 0.788, 0.302)

var _guard_t: float = -1.0


func _on_tapped() -> void:
	if _guard_t >= 0.0 and _guard_t <= OfBalance.HOME_GUARD_S:
		if _guard_t >= OfBalance.HOME_GUARD_MIN_S:
			_guard_t = -1.0
			queue_redraw()
			confirmed.emit()
		return
	_guard_t = 0.0
	set_process(true)
	tapped.emit()


func is_guarding() -> bool:
	return _guard_t >= 0.0


func _process(delta: float) -> void:
	_press_t += delta
	if _guard_t >= 0.0:
		_guard_t += delta
		if _guard_t > OfBalance.HOME_GUARD_S:
			_guard_t = -1.0
	queue_redraw()
	if _guard_t < 0.0 and _press_t > 0.12 and not _down:
		set_process(false)


func _draw() -> void:
	if _guard_t < 0.0:
		super._draw()
		return
	var c: Vector2 = center()
	var r: float = 82.0
	draw_circle(c, 104.0, HALO)
	draw_circle(c, r, WHITE)
	draw_arc(c, r - ring_px * 0.5, 0.0, TAU, 64, INK, ring_px, true)
	var k: float = clampf(_guard_t / OfBalance.HOME_GUARD_S, 0.0, 1.0)
	draw_arc(c, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * k, 64, RING_FILL, 10.0, true)
	OfDisc.draw_icon(self, icon, c, r * 0.55, INK)
