extends Node2D
## mage_beam.gd — «Ледяной луч» (руна Тейваз, X — держать): из рук мага бьёт
## луч стужи. Узел висит на маге; маг каждый кадр ставит его в точку у рук и
## задаёт направление (aim), сам луч:
##   - упирается в стены (луч по земле, рисуется на высоте рук);
##   - пробивает врагов насквозь: каждые tick секунд — урон и озноб всем на линии;
##   - рисуется слоями: широкое свечение, средний слой, белое ядро, винтовая
##     лента инея вокруг, дрожь по длине; у рук — вспышка, на конце — брызги
##     осколков, пар и свет; вдоль луча медленно сыплется иней.
## Сейд за удержание списывает маг (mage.gd::_update_beam).

const MageFx := preload("res://Player_scene/mage_fx.gd")
const IceFx := preload("res://Player_scene/mage_ice_fx.gd")
const SoundBank := preload("res://Levels/sound_bank.gd")

var caster: Node2D
var damage := 1
var tick := 0.45
var length := 230.0
var hit_width := 18.0
var slow_pct := 38.0
var slow_sec := 0.7
## Направление луча (нормаль) и смещение от рук мага до земли под ними
var aim := Vector2.RIGHT
var ground_offset := Vector2(0, 26)

var _tick_left := 0.0
var _t := 0.0
var _len := 0.0
var _power := 0.0
var _stopping := false
var _glow: Line2D
var _mid: Line2D
var _core: Line2D
var _ribbon: Line2D
var _muzzle: Sprite2D
var _end: Node2D
var _end_sparks: GPUParticles2D
var _end_mist: GPUParticles2D
var _along: GPUParticles2D
var _along_node: Node2D
var _light_start: PointLight2D
var _light_end: PointLight2D
const SEGMENTS := 18


func setup(caster_: Node2D, dmg: int, tick_: float, len_: float) -> void:
	caster = caster_
	damage = dmg
	tick = tick_
	length = len_


func _ready() -> void:
	z_index = 1
	var add := MageFx.add_material()
	_glow = _line(20.0, Color(IceFx.EDGE, 0.32), add)
	_mid = _line(9.0, Color(IceFx.MID, 0.7), add)
	_core = _line(3.2, Color(IceFx.CORE, 1.0), add)
	_ribbon = _line(1.6, Color(IceFx.MID, 0.65), add)
	# Свечение и средний слой тают к концу луча
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.15)])
	_glow.gradient = g
	_mid.gradient = g
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.55))
	wc.add_point(Vector2(0.12, 1.0))
	wc.add_point(Vector2(0.9, 0.85))
	wc.add_point(Vector2(1.0, 0.35))
	for l in [_glow, _mid, _core]:
		(l as Line2D).width_curve = wc

	_muzzle = Sprite2D.new()
	_muzzle.texture = MageFx.soft()
	_muzzle.material = add
	_muzzle.modulate = Color(IceFx.CORE.r * 1.4, IceFx.CORE.g * 1.5, IceFx.CORE.b * 1.7, 0.9)
	add_child(_muzzle)

	_end = Node2D.new()
	add_child(_end)
	_end_sparks = _stream(_end, 30, 0.35, IceFx.shard_tex(), true, func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(-1, 0, 0)
		pm.spread = 70.0
		pm.initial_velocity_min = 60.0
		pm.initial_velocity_max = 150.0
		pm.damping_min = 80.0
		pm.damping_max = 160.0
		pm.gravity = Vector3(0, 240, 0)
		pm.scale_min = 0.18
		pm.scale_max = 0.4
		pm.angle_max = 360.0
		pm.angular_velocity_min = -500.0
		pm.angular_velocity_max = 500.0
		pm.color_ramp = MageFx.ramp([Color(IceFx.CORE, 1.0), Color(IceFx.MID, 0.9), Color(IceFx.EDGE, 0.0)]))
	_end_mist = _stream(_end, 10, 0.8, MageFx.soft(), false, func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 6.0
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 120.0
		pm.initial_velocity_min = 8.0
		pm.initial_velocity_max = 26.0
		pm.damping_min = 10.0
		pm.damping_max = 20.0
		pm.scale_min = 0.3
		pm.scale_max = 0.55
		pm.scale_curve = MageFx.size_curve(0.4)
		pm.color_ramp = MageFx.ramp([Color(IceFx.MIST, 0.0), Color(IceFx.MIST, 0.3), Color(IceFx.MIST, 0.0)], [0.0, 0.2, 1.0]))

	# Иней вдоль луча: узел повёрнут по лучу, излучатель — тонкая полоса
	_along_node = Node2D.new()
	add_child(_along_node)
	_along = _stream(_along_node, 26, 0.7, MageFx.dot(), true, func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(length * 0.5, 3.0, 0.0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 60.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 18.0
		pm.gravity = Vector3(0, 30, 0)
		pm.scale_min = 0.35
		pm.scale_max = 0.8
		pm.color_ramp = MageFx.ramp([Color(IceFx.CORE, 0.0), Color(IceFx.MID, 0.8), Color(IceFx.EDGE, 0.0)], [0.0, 0.2, 1.0]))

	_light_start = _make_light(60.0, self)
	_light_end = _make_light(70.0, _end)
	create_tween().tween_property(self, "_power", 1.0, 0.12).set_ease(Tween.EASE_OUT)
	SoundBank.play_at(get_tree(), "life_exchange", global_position, -10.0, 1.4)


func _line(w: float, col: Color, mat: Material) -> Line2D:
	var l := Line2D.new()
	l.width = w
	# Цвет — через modulate: градиент Line2D заменяет default_color целиком,
	# а нам от градиента нужна только прозрачность к концу луча
	l.default_color = Color.WHITE
	l.modulate = col
	l.material = mat
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(l)
	return l


## Непрерывный излучатель (в отличие от разового MageFx.burst)
func _stream(parent: Node, amount: int, life: float, tex: Texture2D, additive: bool, setup_pm: Callable) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.texture = tex
	p.visibility_rect = MageFx.VIS_RECT
	if additive:
		p.material = MageFx.add_material()
	else:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = m
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.gravity = Vector3.ZERO
	setup_pm.call(pm)
	p.process_material = pm
	parent.add_child(p)
	p.emitting = true
	return p


func _make_light(r: float, parent: Node) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = MageFx.radial()
	l.texture_scale = r * 2.0 / 128.0
	l.color = IceFx.MID
	l.energy = 1.1
	l.blend_mode = Light2D.BLEND_MODE_ADD
	parent.add_child(l)
	return l


## Погасить: луч сжимается к рукам за ~0.15 с, частицы доигрывают
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	_end_sparks.emitting = false
	_end_mist.emitting = false
	_along.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_power", 0.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_property(_light_start, "energy", 0.0, 0.2)
	tw.tween_property(_light_end, "energy", 0.0, 0.2)
	tw.chain().tween_interval(0.8)
	tw.chain().tween_callback(queue_free)
	# Маг может исчезнуть со сцены (смерть, смена уровня) раньше — отцепляемся
	# в мир, чтобы хвост частиц доиграл на месте
	if is_instance_valid(caster) and get_parent() == caster and caster.get_parent():
		reparent(caster.get_parent())


func is_stopping() -> bool:
	return _stopping


func _physics_process(delta: float) -> void:
	_t += delta
	var dir := aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	# Луч вверх по экрану уходит за спину мага — рисуем позади него
	z_index = -1 if dir.y < -0.35 else 1
	_len = _cast_length(dir) * _power
	_draw_beam(dir)
	if _stopping or not is_instance_valid(caster):
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = tick
		_hit(dir)


## Длина до первой стены: луч ведём по ЗЕМЛЕ (под руками), стены — слой 1
func _cast_length(dir: Vector2) -> float:
	var from := global_position + ground_offset
	var to := from + dir * length
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	if is_instance_valid(caster) and caster is CollisionObject2D:
		q.exclude = [(caster as CollisionObject2D).get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit["position"]) - 4.0, 12.0)


func _draw_beam(dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var core := PackedVector2Array()
	var ribbon := PackedVector2Array()
	for i in SEGMENTS + 1:
		var k := float(i) / SEGMENTS
		var p := dir * _len * k
		# Дрожь: две волны разной частоты бегут по лучу; у рук почти нет
		var j := (sin(k * 23.0 - _t * 31.0) * 1.2 + sin(k * 9.0 + _t * 17.0) * 0.8) * minf(k * 4.0, 1.0)
		pts.append(p + side * j)
		core.append(p + side * j * 0.4)
		# Лента инея — винт вокруг луча
		var tw := sin(k * 26.0 - _t * 22.0) * 6.0 * minf(k * 5.0, 1.0)
		ribbon.append(p + side * tw)
	_glow.points = pts
	_mid.points = pts
	_core.points = core
	_ribbon.points = ribbon
	var pulse := 1.0 + 0.12 * sin(_t * 40.0) + 0.06 * sin(_t * 13.0)
	_glow.width = 20.0 * pulse * _power
	_mid.width = 9.0 * pulse * _power
	_core.width = 3.2 * _power
	_ribbon.modulate.a = 0.65 * _power
	_muzzle.scale = Vector2.ONE * (0.32 + 0.06 * sin(_t * 35.0)) * _power
	_end.position = dir * _len
	_end.rotation = dir.angle()
	_end.visible = _power > 0.05
	_along_node.position = dir * _len * 0.5
	_along_node.rotation = dir.angle()
	var pm := _along.process_material as ParticleProcessMaterial
	pm.emission_box_extents = Vector3(maxf(_len * 0.5, 1.0), 3.0, 0.0)
	if not _stopping:
		_light_start.energy = 1.0 * _power
		_light_end.energy = 1.2 * _power


## Удар по всем на линии луча (по земле, с запасом hit_width)
func _hit(dir: Vector2) -> void:
	var from := global_position + ground_offset
	var to := from + dir * _len
	var any := false
	for e in IceFx.targets(get_tree()):
		var f := IceFx.feet(e)
		var c := Geometry2D.get_closest_point_to_segment(f, from, to)
		var off := f - c
		if Vector2(off.x, off.y / 0.8).length() <= hit_width:
			IceFx.hit(caster, e, damage, c - dir * 10.0, 40.0, slow_pct, slow_sec)
			any = true
	if any and is_instance_valid(caster) and caster.has_method("shake_camera"):
		caster.shake_camera(1.2, 0.08)
