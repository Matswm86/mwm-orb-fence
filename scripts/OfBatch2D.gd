class_name OfBatch2D
extends RefCounted

## Collects flat 2D shapes into one triangle array, drawn with a single
## canvas command (one draw call, one canvas object) by flush(). Used for
## shapes that come in dozens per frame: spark bar, ghost dots, pop bubbles
## (QA 2026-10-07 finding 1: one draw_* per shape cost 50-95 draw calls).
## Outlines get a 1 px alpha feather on both sides as their anti-aliasing.
## Triangles draw in the order they were added.

const FEATHER_PX: float = 1.0
const MITER_MAX: float = 2.0

var pts := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


func is_empty() -> bool:
	return idx.is_empty()


## Filled convex or star-shaped polygon as a fan from c (c must see every
## edge, as for a sparkle or a star around its centre).
func add_fan(c: Vector2, poly: PackedVector2Array, col: Color) -> void:
	var base: int = pts.size()
	pts.append(c)
	cols.append(col)
	var n: int = poly.size()
	for k: int in n:
		pts.append(poly[k])
		cols.append(col)
		idx.append_array([base, base + 1 + k, base + 1 + (k + 1) % n])


## Filled disc with `sides` sides.
func add_disc(c: Vector2, r: float, col: Color, sides: int = 20) -> void:
	var ring := PackedVector2Array()
	for i: int in sides:
		var a: float = TAU * float(i) / float(sides)
		ring.append(c + Vector2(cos(a), sin(a)) * r)
	add_fan(c, ring, col)


## Closed outline through poly, `width` px, as one continuous strip with
## mitred corners (no overlap at the joints, so translucent outlines keep
## an even alpha), anti-aliased by a feather of FEATHER_PX on both sides.
## Sharp tips clamp the miter at MITER_MAX.
func add_loop(poly: PackedVector2Array, width: float, col: Color) -> void:
	var n: int = poly.size()
	if n < 2:
		return
	var h: float = width * 0.5
	var clear := Color(col, 0.0)
	var base: int = pts.size()
	for k: int in n:
		var p: Vector2 = poly[k]
		var d0: Vector2 = (p - poly[(k - 1 + n) % n]).normalized()
		var d1: Vector2 = (poly[(k + 1) % n] - p).normalized()
		var n0 := Vector2(-d0.y, d0.x)
		var n1 := Vector2(-d1.y, d1.x)
		var m: Vector2 = n0 + n1
		m = n1 if m.length_squared() < 0.0001 else m.normalized()
		var sc: float = minf(1.0 / maxf(m.dot(n1), 0.0001), MITER_MAX)
		# Per point: outer +, core +, core -, outer -.
		for v: Array in [
			[p + m * (h + FEATHER_PX) * sc, clear],
			[p + m * h * sc, col],
			[p - m * h * sc, col],
			[p - m * (h + FEATHER_PX) * sc, clear],
		]:
			pts.append(v[0])
			cols.append(v[1])
	for k: int in n:
		var i: int = base + k * 4
		var j: int = base + ((k + 1) % n) * 4
		for q: int in 3:
			idx.append_array([i + q, j + q, j + q + 1, i + q, j + q + 1, i + q + 1])


## Circle outline with `sides` segments.
func add_ring(c: Vector2, r: float, width: float, col: Color, sides: int = 28) -> void:
	var ring := PackedVector2Array()
	for i: int in sides:
		var a: float = TAU * float(i) / float(sides)
		ring.append(c + Vector2(cos(a), sin(a)) * r)
	add_loop(ring, width, col)


## Draws everything collected so far on ci (call from ci's draw) and clears.
func flush(ci: CanvasItem) -> void:
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
	pts.clear()
	cols.clear()
	idx.clear()
