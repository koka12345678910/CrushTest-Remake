extends Node2D
## druid_vine.gd — Хлёст лозы (ПКМ, druid.gd::_start_vine). Из руки
## Сольвейг вылетает светящаяся лоза с листьями, хлещет до первого врага на
## линии (или до конца досягаемости), обвивает его, рывком подтягивает к ней и
## на миг связывает (enemy.apply_root), потом сматывается обратно.
##
## Рисуется кодом в координатах мира: узел стоит в точке руки, лоза — волна
## вдоль направления; кора тёмная, жилка светлая, листья по бокам.

const DruidFx := preload("res://Player_scene/druid_fx.gd")

var reach := 150.0
var damage := 1
var posture := 25.0
var pull := 210.0
var root_time := 1.0

var _caster: Node2D
var _dir := Vector2.RIGHT
var _target: Node2D
var _len := 0.0
var _out := 0.0
var _t := 0.0
var _struck := false
var _leaves: Array = []
var _light: PointLight2D


func setup(caster: Node2D, from: Vector2, dir: Vector2, target: Node2D) -> void:
	_caster = caster
	global_position = from
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	_target = target
	if is_instance_valid(target):
		var to := target.global_position + Vector2(0, -10) - from
		_dir = to.normalized()
		_len = minf(to.length(), reach)
	else:
		_len = reach


func _ready() -> void:
	z_index = 11
	for i in 6:
		_leaves.append({"k": randf_range(0.15, 0.9), "side": 1.0 if i % 2 == 0 else -1.0, "rot": randf_range(0.3, 0.9)})
	DruidFx.flash(self, 18.0, 0.12)
	# Свет идёт по лозе к кончику
	_light = DruidFx.light(self, 44.0, 1.3)
	var t := create_tween()
	t.tween_property(self, "_out", 1.0, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(_strike)
	t.tween_interval(0.12)
	t.tween_property(self, "_out", 0.0, 0.2).set_ease(Tween.EASE_IN)
	t.tween_interval(0.4)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	# Лоза держится за руку (Сольвейг может сдвинуться — не рвётся)
	if is_instance_valid(_caster) and _caster.has_method("_hand_point"):
		global_position = _caster._hand_point()
	if _light:
		_light.position = _dir * _len * _out * 0.7
		_light.energy = 1.3 * clampf(_out * 1.5, 0.0, 1.0)
	queue_redraw()


func _strike() -> void:
	_struck = true
	var tip := global_position + _dir * _len
	var h := DruidFx.holder(get_tree(), tip, 1.0, 12)
	DruidFx.flash(h, 22.0, 0.14)
	DruidFx.leaves(h, 6, 90.0, 0.8, -_dir, 80.0)
	DruidFx.sparks(h, 8, 130.0, 0.3, -_dir, 60.0)
	DruidFx.light_pulse(h, 50.0, 1.6, 0.3)
	# Эхо чужой лозы (кооп): хватка и рывок уже у хозяина — здесь только вид
	if Net.is_echo(_caster):
		return
	if not is_instance_valid(_target) or _target.get("is_dead") == true:
		return
	if "player" in _target and _target.player == null and is_instance_valid(_caster):
		_target.player = _caster
	if damage > 0:
		_target.take_damage(damage, _caster)
	if not is_instance_valid(_target) or _target.get("is_dead") == true:
		return
	if _target.has_method("take_posture_damage"):
		_target.take_posture_damage(posture)
	# Рывок к Сольвейг, а сразу за ним — хватка корнями (корни гасят отлёт,
	# поэтому связываем чуть позже, когда рывок отыграл)
	if "knockback_velocity" in _target:
		_target.knockback_velocity = -_dir * pull
	var tgt := _target
	get_tree().create_timer(0.22).timeout.connect(func():
		if is_instance_valid(tgt) and tgt.has_method("apply_root"):
			tgt.apply_root(root_time))


func _draw() -> void:
	var cur := _len * _out
	if cur < 2.0:
		return
	var n := maxi(int(cur / 6.0), 3)
	var side := _dir.orthogonal()
	var pts := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		# Волна гаснет к кончику, пока лоза летит, и почти пропадает после удара
		var amp := 4.0 * sin(k * PI) * (0.4 if _struck else 1.0)
		pts.append(_dir * cur * k + side * sin(k * 9.0 - _t * 18.0) * amp)
	# Ореол вокруг лозы — мягкое зелёное свечение
	for i in n:
		var k := float(i) / n
		draw_line(pts[i], pts[i + 1], Color(DruidFx.MID, 0.18), lerpf(9.0, 4.0, k), true)
	# Кора
	for i in n:
		var k := float(i) / n
		draw_line(pts[i], pts[i + 1], Color(0.06, 0.08, 0.03, 0.9), lerpf(5.6, 2.8, k), true)
		draw_line(pts[i], pts[i + 1], Color(0.26, 0.42, 0.14), lerpf(4.2, 1.8, k), true)
	# Светящаяся жилка
	for i in n:
		var k := float(i) / n
		var wave := 0.6 + 0.4 * sin(_t * 14.0 - k * 8.0)
		draw_line(pts[i], pts[i + 1], Color(DruidFx.MID.lerp(DruidFx.CORE, wave * 0.5), 0.85), lerpf(1.6, 0.8, k), true)
	# Листья вдоль лозы
	for l in _leaves:
		var idx := clampi(int(l["k"] * n), 0, n)
		if float(idx) / n > _out + 0.02:
			continue
		var p: Vector2 = pts[idx]
		var ang: float = _dir.angle() + l["side"] * l["rot"]
		var tip := p + Vector2.from_angle(ang) * 6.0
		var mid := (p + tip) * 0.5
		var w := Vector2.from_angle(ang).orthogonal() * 2.0
		draw_colored_polygon(PackedVector2Array([p, mid + w, tip, mid - w]), Color(DruidFx.LEAF, 0.95))
	# Огонёк на кончике
	draw_circle(pts[n], 2.2, Color(DruidFx.CORE, 0.95))
	draw_circle(pts[n], 4.5, Color(DruidFx.MID, 0.3))
