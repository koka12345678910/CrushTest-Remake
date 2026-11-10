extends Node2D
## mage_frost_trail.gd — след «Ледяного шага» (руна Эваз, Ctrl): полоса льда
## по земле от точки старта до точки прихода. Живёт lifetime секунд: враги на
## ней замедлены (озноб, обновляется, пока стоят на льду), потом тает.
## Вид: светлая наледь (линия с инеем по краям), мелкие кристаллы вдоль и
## пятна инея на концах. Лежит на земле, под героями (как трещины Juice).

const MageFx := preload("res://Player_scene/mage_fx.gd")
const IceFx := preload("res://Player_scene/mage_ice_fx.gd")

var from := Vector2.ZERO
var to := Vector2.ZERO
var lifetime := 2.6
var width := 20.0
var slow_pct := 45.0
var _t := 0.0
var _check := 0.0


func setup(a: Vector2, b: Vector2, life: float) -> void:
	from = a
	to = b
	lifetime = life


func _ready() -> void:
	z_as_relative = false
	z_index = -15
	global_position = from
	var d := to - from
	var n := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	var side := Vector2(-n.y, n.x)
	var len := d.length()
	# Наледь: цепочка пятен инея (ячеистый узор, как у кольца), а не ровная
	# полоса — так след читается льдом, а не доской. Посередине — тонкая
	# светлая жилка, к концам сходит на нет
	var spots := maxi(int(len / 14.0), 2)
	for i in spots + 1:
		var k := float(i) / spots
		var at := from + d * k + side * randf_range(-3.0, 3.0) * 0.62
		var r := width * randf_range(0.55, 0.8) * (0.7 + 0.3 * sin(k * PI))
		IceFx.frost_decal(get_tree(), at, r, lifetime * 0.75, 0.5)
	var steps := maxi(int(len / 8.0), 3)
	var mid := PackedVector2Array()
	for i in steps + 1:
		var k := float(i) / steps
		mid.append(d * k + side * randf_range(-0.8, 0.8) * 0.62)
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(0.2, 1.0))
	taper.add_point(Vector2(0.8, 0.8))
	taper.add_point(Vector2(1.0, 0.0))
	var line := Line2D.new()
	line.points = mid
	line.width = 2.0
	line.width_curve = taper
	line.default_color = Color(IceFx.MID, 0.55)
	line.material = MageFx.add_material()
	add_child(line)
	# Кристаллы-шипики вдоль следа — короткие, стоят недолго
	var crystals := int(len / 22.0)
	for i in crystals:
		var k := randf_range(0.1, 0.95)
		var at := from + d * k + side * randf_range(-1.0, 1.0) * width * 0.4 * 0.62
		IceFx.spike(get_tree(), at, randf_range(7.0, 13.0), randf_range(3.5, 5.5), k * 0.15,
				randf_range(0.5, 1.1), randf_range(-0.35, 0.35))
	IceFx.frost_decal(get_tree(), from, 26.0, lifetime * 0.7, 0.45)
	IceFx.frost_decal(get_tree(), to, 34.0, lifetime * 0.7, 0.5)

	var tw := create_tween()
	modulate.a = 0.0
	tw.tween_property(self, "modulate:a", 1.0, 0.1)
	tw.tween_interval(maxf(lifetime - 1.0, 0.1))
	tw.tween_property(self, "modulate:a", 0.0, 0.9)
	tw.tween_callback(queue_free)


## Раз в 0.15 с — всех, кто стоит на наледи, морозит (короткий озноб,
## обновляется, пока враг на льду)
func _physics_process(delta: float) -> void:
	_t += delta
	_check -= delta
	if _check > 0.0 or _t > lifetime - 0.6:
		return
	_check = 0.15
	for e in IceFx.targets(get_tree()):
		var f := IceFx.feet(e)
		var c := Geometry2D.get_closest_point_to_segment(f, from, to)
		var off := f - c
		if Vector2(off.x, off.y / 0.62).length() <= width * 0.75:
			IceFx.chill(e, slow_pct, 0.4)
