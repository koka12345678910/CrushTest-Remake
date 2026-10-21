extends Node2D
## lightning_bolt.gd — видимый удар молнии (гроза, Levels/directional_light_2d.gd).
## Создаётся кодом: LightningBolt.strike(tree, at, near) — at — точка удара на
## земле (мир), near — удар рядом с героем (полный: свет, земля, звук рядом)
## или дальний (бледный разряд у края вида, без последствий).
##
## Разряд — ломаная от неба к земле (середина ломаной сдвигается рекурсивно —
## так рисуют молнию: крупные изломы и мелкая дрожь), с 2-3 ответвлениями.
## Как у настоящей молнии — двойной всполох: вспыхнул, погас на миг, ударил
## снова чуть иначе изогнутым каналом и истаял. В точке удара — свет, от
## которого герой отбрасывает тень (маска теней героя 16, как у костров).

const MageFx := preload("res://Player_scene/mage_fx.gd")

var near := true
var _target := Vector2.ZERO
var _glow: Line2D
var _core: Line2D
var _branches := []
var _light: PointLight2D
var _mat: CanvasItemMaterial


static func strike(tree: SceneTree, at: Vector2, is_near := true) -> Node2D:
	var root := tree.current_scene if tree.current_scene else tree.root
	var b: Node2D = load("res://VFX/VFX_scene/lightning_bolt.gd").new()
	b.near = is_near
	b._target = at
	root.add_child(b)
	return b


func _ready() -> void:
	z_as_relative = false
	z_index = 95
	global_position = Vector2.ZERO
	modulate = _ambient_comp()
	_mat = CanvasItemMaterial.new()
	_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var k := 1.0 if near else 0.45
	_glow = _line(14.0 * k, Color(0.45, 0.6, 1.0, 0.32 * k))
	_core = _line(2.6 * k, Color(0.92, 0.96, 1.0, 0.95 * k))
	for i in randi_range(2, 3):
		_branches.append(_line(1.4 * k, Color(0.75, 0.85, 1.0, 0.7 * k)))
	_shape()

	_light = PointLight2D.new()
	_light.texture = MageFx.radial()
	_light.texture_scale = (260.0 if near else 140.0) * 2.0 / 128.0
	_light.color = Color(0.78, 0.86, 1.0)
	_light.energy = 0.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	if near:
		_light.shadow_enabled = true
		_light.shadow_item_cull_mask = 16
		_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	add_child(_light)
	_light.global_position = _target

	visible = false
	_play()


func _line(width: float, col: Color) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = col
	l.material = _mat
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.55))
	wc.add_point(Vector2(1, 1))
	l.width_curve = wc
	add_child(l)
	return l


## Канал молнии: из-за верхнего края вида к точке удара
func _shape() -> void:
	var top := _target + Vector2(randf_range(-90.0, 90.0), -520.0)
	var pts := _bolt(top, _target, 7, 38.0)
	_core.points = pts
	_glow.points = pts
	for b in _branches:
		var i := randi_range(int(pts.size() * 0.2), int(pts.size() * 0.7))
		var from: Vector2 = pts[i]
		var dir := (pts[mini(i + 1, pts.size() - 1)] - from).normalized().rotated(randf_range(-0.9, 0.9))
		var to := from + dir * randf_range(60.0, 140.0)
		(b as Line2D).points = _bolt(from, to, 4, 14.0)


## Срединное смещение: отрезок пополам, середина в сторону, и так depth раз
func _bolt(a: Vector2, b: Vector2, depth: int, jitter: float) -> PackedVector2Array:
	var pts := [a, b]
	var j := jitter
	for d in depth:
		var out := [pts[0]]
		for i in range(1, pts.size()):
			var p: Vector2 = pts[i - 1]
			var q: Vector2 = pts[i]
			var mid := (p + q) * 0.5
			var n := (q - p).orthogonal().normalized()
			out.append(mid + n * randf_range(-j, j))
			out.append(q)
		pts = out
		j *= 0.55
	return PackedVector2Array(pts)


## Двойной всполох: удар — темно — второй удар по новому каналу — тает
func _play() -> void:
	var e := 3.4 if near else 1.2
	visible = true
	_light.energy = e
	await get_tree().create_timer(0.06).timeout
	visible = false
	_light.energy = e * 0.25
	await get_tree().create_timer(0.05).timeout
	_shape()
	visible = true
	_light.energy = e * 0.85
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.32).set_delay(0.07).set_ease(Tween.EASE_IN)
	t.tween_property(_light, "energy", 0.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t.finished
	queue_free()


## Ночной CanvasModulate гасит всё в мире — молния должна бить в полную силу
func _ambient_comp() -> Color:
	var scene := get_tree().current_scene
	if scene:
		for ch in scene.get_children():
			if ch is CanvasModulate and ch.visible:
				var c: Color = ch.color
				return Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)
	return Color.WHITE
