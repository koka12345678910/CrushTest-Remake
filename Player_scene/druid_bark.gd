extends Node2D
## druid_bark.gd — видимый щит Коры (X, druid.gd::_start_bark) на том, кого
## он бережёт: вокруг тела кружат пластинки коры и листья, светится мягкий
## зелёный ореол. Чем меньше осталось щита, тем реже и тусклее пластинки.
## Разбит ударом — щепки и листья разлетаются (shatter), истёк — тает (fade).

const DruidFx := preload("res://Player_scene/druid_fx.gd")

## 0..1 — сколько щита осталось (ставит druid.gd)
var strength := 1.0
## Центр тела относительно героя
var center := Vector2(0, -6)

var _t := 0.0
var _alpha := 0.0
var _light: PointLight2D
var _plates: Array = []

const PLATES := 7


func _ready() -> void:
	z_index = 1
	position = center
	for i in PLATES:
		_plates.append({"a": TAU * i / PLATES, "leaf": i % 2 == 1, "bob": randf() * TAU})
	_light = DruidFx.light(self, 30.0, 0.0)
	create_tween().tween_property(self, "_alpha", 1.0, 0.25)
	DruidFx.flash(self, 30.0, 0.18)
	DruidFx.leaves(self, 6, 60.0, 0.7)
	DruidFx.light_pulse(self, 50.0, 1.4, 0.35)


func _process(delta: float) -> void:
	_t += delta
	_light.energy = (0.55 + 0.1 * sin(_t * 3.0)) * _alpha * (0.4 + 0.6 * strength)
	queue_redraw()


func _draw() -> void:
	var a := _alpha * (0.45 + 0.55 * strength)
	# Ореол
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.25))
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 40, Color(DruidFx.MID, 0.22 * a), 3.0)
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 40, Color(DruidFx.CORE, 0.18 * a), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Пластинки коры и листья по сплюснутой орбите; задние — бледнее
	var shown := maxi(int(ceil(PLATES * (0.35 + 0.65 * strength))), 2)
	for i in shown:
		var p: Dictionary = _plates[i]
		var ang: float = p["a"] + _t * 1.6
		var pos := Vector2(cos(ang) * 15.0, sin(ang) * 6.0 + sin(_t * 2.0 + p["bob"]) * 2.0)
		var behind := sin(ang) < 0.0
		var k := (0.45 if behind else 1.0) * a
		var rot := ang + PI * 0.5
		if p["leaf"]:
			_leaf(pos, rot, Color(DruidFx.LEAF, 0.9 * k))
		else:
			_plate(pos, rot, k)


func _plate(at: Vector2, rot: float, k: float) -> void:
	var x := Vector2.from_angle(rot) * 3.0
	var y := Vector2.from_angle(rot).orthogonal() * 2.0
	var pts := PackedVector2Array([at - x - y, at + x - y * 0.7, at + x + y, at - x + y * 0.8])
	draw_colored_polygon(pts, Color(DruidFx.BARK, 0.95 * k))
	draw_line(at - x, at + x, Color(DruidFx.MID, 0.7 * k), 0.8, true)


func _leaf(at: Vector2, rot: float, col: Color) -> void:
	var d := Vector2.from_angle(rot) * 3.5
	var w := d.orthogonal() * 0.45
	draw_colored_polygon(PackedVector2Array([at - d, at + w, at + d, at - w]), col)


## Щит разбит ударом: щепки, листья, вспышка — и узел исчезает
func shatter() -> void:
	set_process(false)
	var h := DruidFx.holder(get_tree(), global_position, 1.2, 12)
	DruidFx.flash(h, 26.0, 0.14)
	DruidFx.leaves(h, 10, 110.0, 0.9)
	DruidFx.MageFx.burst(h, 12, 0.6, DruidFx.MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 50.0
		pm.initial_velocity_max = 130.0
		pm.gravity = Vector3(0, 260, 0)
		pm.scale_min = 0.8
		pm.scale_max = 1.6
		pm.color_ramp = DruidFx.MageFx.ramp([Color(DruidFx.BARK, 1.0), Color(DruidFx.BARK, 0.9), Color(DruidFx.BARK, 0.0)], [0.0, 0.7, 1.0])
	, false)
	DruidFx.light_pulse(h, 46.0, 1.2, 0.3)
	queue_free()


## Щит истёк: тихо тает
func fade() -> void:
	var t := create_tween()
	t.tween_property(self, "_alpha", 0.0, 0.35)
	t.tween_callback(queue_free)
