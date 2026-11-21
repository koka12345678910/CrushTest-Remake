extends Node2D
## moths.gd — мотыльки у фонарей и факелов (Immersion/Moths).
##
## У нескольких ближайших к камере ламп и факелов кружат мотыльки: каждый
## по своей петле, с рывками и трепетом крыльев (мерцает). Светятся цветом
## своего огня, рисуются поверх всего (они в воздухе у огня). У больших
## костров и пожаров их нет — там жарко, там летят искры.

@export var per_light := 4
@export var max_lights := 10
@export var prefixes: PackedStringArray = ["Lantern", "Torch", "Candle"]

var stats := {}

var _lights: Array[PointLight2D] = []
var _active: Array[PointLight2D] = []
var _pick_t := 0.0
var _t := 0.0
var _seeds := {}


func setup(map: Node) -> void:
	top_level = true
	z_as_relative = false
	z_index = 46
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	var night := map.get_node_or_null("Night")
	if night:
		for l in night.get_children():
			if not l is PointLight2D:
				continue
			for p in prefixes:
				if String(l.name).begins_with(p):
					_lights.append(l)
					_seeds[l] = randf() * 100.0
					break
	stats = {"lights": _lights.size()}


func _process(delta: float) -> void:
	_t += delta
	_pick_t -= delta
	if _pick_t <= 0.0:
		_pick_t = 0.5
		_pick()
	queue_redraw()


func _pick() -> void:
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var view := Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size).grow(80.0)
	var c := view.get_center()
	var cands: Array = []
	for l in _lights:
		if is_instance_valid(l) and l.is_visible_in_tree() and l.energy > 0.05 and view.has_point(l.global_position):
			cands.append([l.global_position.distance_squared_to(c), l])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	_active.clear()
	for i in mini(cands.size(), max_lights):
		_active.append(cands[i][1])


func _draw() -> void:
	for l in _active:
		if not is_instance_valid(l):
			continue
		var base := l.global_position + Vector2(0, -4)
		var s: float = _seeds.get(l, 0.0)
		var col := l.color.lerp(Color(1, 0.95, 0.85), 0.55)
		var e := clampf(l.energy, 0.2, 1.2)
		for i in per_light:
			var ph := s + i * 2.39
			var t := _t * (0.8 + 0.25 * sin(ph * 3.1)) + ph
			var rx := 10.0 + 9.0 * fposmod(ph * 0.37, 1.0)
			var ry := 7.0 + 5.0 * fposmod(ph * 0.61, 1.0)
			# Петля вокруг огня + рывки: мотыльки бьются о свет
			var p := Vector2(sin(t * 1.7) * rx + sin(t * 5.3 + i) * 3.0,
					cos(t * 1.3 + i) * ry + sin(t * 6.7) * 2.5 - 4.0)
			# Трепет крыльев: то видно, то нет
			var flap := 0.45 + 0.55 * absf(sin(t * 23.0 + i))
			var near := 1.0 - clampf(p.length() / 26.0, 0.0, 1.0) * 0.5
			var a := 0.75 * flap * near * e
			draw_circle(base + p, 0.9, Color(col.r, col.g, col.b, a))
			draw_circle(base + p + Vector2(0.9, 0), 0.6, Color(col.r, col.g, col.b, a * 0.6))
