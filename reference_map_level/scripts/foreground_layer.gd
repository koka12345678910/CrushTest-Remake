extends Node2D
## foreground_layer.gd — передний план с параллаксом: тёмные размытые кроны,
## ветки, папоротник и верёвки с флажками между камерой и героем.
##
## Каждый элемент привязан к точке мира A, но рисуется в C + k·(A − C), где C —
## центр камеры, k > 1: при беге он проносится быстрее земли и кажется ближе к
## глазу. Чистая зона вокруг героя — в шейдере (shaders/foreground.gdshader).
## Элементы раскладывает immersion.gd (_build_foreground) через add_part/add_rope.
## Рисуется одним канвас-айтемом: каждый кадр только то, что попало в кадр.

const CELL := 512.0
## Непрозрачность крыш (bottom) — легче листвы: широкое тёмное пятно у края
## кадра давит сильнее веток
const BOTTOM_ALPHA := 0.8

var atlas: Texture2D
## имя части -> Rect2 в атласе
var parts := {}
var wind_strength := 1.0

## Элементы: {"type": 0 часть / 1 верёвка, "a": якорь, "b": второй конец верёвки,
## "part", "scale", "rot", "flip", "k", "phase", "col"}
var _items: Array[Dictionary] = []
## Vector2i -> PackedInt32Array индексов
var _grid := {}
var _max_reach := 0.0


## bottom — только в нижней части кадра (ближе к камере): так рисуются свесы
## крыш, сверху кадра ближнего к глазу дома быть не может; плюс без качания
func add_part(at: Vector2, part: String, scale_k: float, rot: float, flip: bool, k: float, bottom := false) -> void:
	if not parts.has(part):
		return
	var r: Rect2 = parts[part]
	_add({"type": 0, "a": at, "part": part, "scale": scale_k, "rot": rot, "flip": flip, "k": k,
		"phase": randf() * TAU, "reach": r.size.length() * scale_k * k * 0.5, "bottom": bottom})


func add_rope(a: Vector2, b: Vector2, k: float, colors: PackedColorArray) -> void:
	_add({"type": 1, "a": a, "b": b, "k": k, "phase": randf() * TAU, "col": colors,
		"reach": a.distance_to(b) * k * 0.5 + 40.0})


func _add(it: Dictionary) -> void:
	var i := _items.size()
	_items.append(it)
	var at: Vector2 = it["a"]
	if it["type"] == 1:
		at = (it["a"] + it["b"]) * 0.5
	it["c"] = at
	var key := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
	if not _grid.has(key):
		_grid[key] = PackedInt32Array()
	_grid[key].append(i)
	_max_reach = maxf(_max_reach, it["reach"])


func item_count() -> int:
	return _items.size()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if atlas == null and _items.is_empty():
		return
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var vs := vp.get_visible_rect().size
	var c: Vector2 = inv * (vs * 0.5)
	var half: Vector2 = inv.basis_xform(vs * 0.5).abs()
	# Якорь A виден, если C + k(A − C) в кадре: A в пределах C ± half/k (k ≥ 1),
	# плюс размер самого элемента
	var reach := half + Vector2(_max_reach, _max_reach)
	var lo := Vector2i(floori((c.x - reach.x) / CELL), floori((c.y - reach.y) / CELL))
	var hi := Vector2i(floori((c.x + reach.x) / CELL), floori((c.y + reach.y) / CELL))
	var t := Time.get_ticks_msec() / 1000.0
	var view := Rect2(c - half, half * 2.0)
	for gy in range(lo.y, hi.y + 1):
		for gx in range(lo.x, hi.x + 1):
			var key := Vector2i(gx, gy)
			if not _grid.has(key):
				continue
			for i in _grid[key]:
				var it: Dictionary = _items[i]
				var k: float = it["k"]
				var d: Vector2 = c + (it["c"] - c) * k
				var rr: float = it["reach"]
				if not view.grow(rr).has_point(d):
					continue
				if it["type"] == 0:
					var fade := 1.0
					if it.get("bottom", false):
						# Центр куска — ниже героя: проступает от трети до половины
						# нижней половины кадра
						fade = smoothstep(c.y + half.y * 0.2, c.y + half.y * 0.5, d.y) * BOTTOM_ALPHA
						if fade <= 0.0:
							continue
					_draw_part(it, c, t, fade)
				else:
					_draw_rope(it, c, t)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_part(it: Dictionary, c: Vector2, t: float, fade := 1.0) -> void:
	var k: float = it["k"]
	var a: Vector2 = it["a"]
	var d := c + (a - c) * k
	var r: Rect2 = parts[it["part"]]
	var ph: float = it["phase"]
	var sway := 0.0
	if not it.get("bottom", false):
		sway = (sin(t * 0.55 + ph) * 0.7 + sin(t * 1.3 + ph * 2.0) * 0.3) * 0.035 * wind_strength
	var s: float = it["scale"] * k
	var sc := Vector2(-s if it["flip"] else s, s)
	draw_set_transform(d, it["rot"] + sway, sc)
	draw_texture_rect_region(atlas, Rect2(-r.size * 0.5, r.size), r, Color(1, 1, 1, fade))


func _draw_rope(it: Dictionary, c: Vector2, t: float) -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var k: float = it["k"]
	var a: Vector2 = c + (it["a"] - c) * k
	var b: Vector2 = c + (it["b"] - c) * k
	var ph: float = it["phase"]
	var len := a.distance_to(b)
	var sway := sin(t * 0.8 + ph) * 0.5 + 0.5
	var sag := Vector2(sin(t * 0.6 + ph) * 6.0 * wind_strength, len * 0.12 + 6.0 * sway)
	var mid := (a + b) * 0.5 + sag
	var n := maxi(int(len / 10.0), 8)
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
	var rope_col := Color(0.06, 0.05, 0.045, 1.0)
	draw_polyline(pts, rope_col, 2.4 * k, true)
	# Флажки: треугольники висят на верёвке и качаются по ветру
	var cols: PackedColorArray = it["col"]
	var step := maxi(int(n / maxf(len / 30.0, 1.0)), 1)
	var fi := 0
	for i in range(step, n, step):
		var p := pts[i]
		var dir := (pts[mini(i + 1, n)] - pts[i - 1]).normalized()
		var down := Vector2(-dir.y, dir.x)
		if down.y < 0.0:
			down = -down
		var flap := sin(t * 3.1 + ph + i * 0.7) * 0.25 * wind_strength
		down = down.rotated(flap)
		var w := 7.0 * k
		var hgt := 14.0 * k
		var col: Color = cols[fi % cols.size()]
		fi += 1
		draw_colored_polygon(PackedVector2Array([p - dir * w, p + dir * w, p + down * hgt]), col)
