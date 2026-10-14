extends Area2D
## mage_fireball.gd — синий огненный шар мага (первая атака, Attack_).
## Летит по прямой; при попадании во врага, в стену или в конце полёта
## взрывается: прямая цель получает direct_damage, все остальные враги в
## splash_radius — splash_damage.
##
## Собран целиком кодом, без .tscn — тот же приём, что у стрелы (arrow.gd).
## Урон бьёт напрямую через enemy.take_damage(dmg, маг): source — сам маг,
## чтобы враг агрился на игрока, а не на снаряд.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const ORB_SHADER := preload("res://Shaders/magic_orb.gdshader")
const PULSE_SHADER := preload("res://Shaders/magic_pulse.gdshader")
const DISTORT_SHADER := preload("res://Shaders/magic_distort.gdshader")

@export var speed := 300.0
@export var lifetime := 1.3
@export var direct_damage := 2
@export var splash_damage := 1
@export var splash_radius := 56.0
@export var color := Color(0.35, 0.65, 1.0)

var _caster: Node2D
var _direction := Vector2.RIGHT
var _age := 0.0
var _exploded := false
var _core: Sprite2D
var _visual: Node2D
var _motes: Array = []
var _haze: GPUParticles2D
var _glints: GPUParticles2D
var _spin := 0.0
var _trail: GPUParticles2D
var _light: PointLight2D


func launch(from: Vector2, direction: Vector2, caster: Node2D) -> void:
	global_position = from
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_caster = caster


func _ready() -> void:
	z_index = 10
	area_entered.connect(_on_area_entered)
	# Маска по умолчанию — слой 1 "world": стены тайлов и статические тела
	body_entered.connect(_on_body_entered)

	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# launch() зовётся сразу после add_child — направление и точка вылета
	# известны только к концу кадра, поэтому визуал строим отложенно
	_build_visuals.call_deferred()


func _build_visuals() -> void:
	# Весь визуал шара — в узле _visual, повёрнутом по полёту: хвост пламени
	# сам смотрит назад
	_visual = Node2D.new()
	_visual.rotation = _direction.angle()
	add_child(_visual)

	# Ядро: плазма, ореол и хвост пламени (Shaders/magic_orb.gdshader)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_core = Sprite2D.new()
	_core.texture = ImageTexture.create_from_image(img)
	var size := Vector2(84.0, 40.0)
	_core.scale = size / 4.0
	# Шар (orb_x = 0.68) — в точке узла, хвост уходит назад
	_core.position = Vector2(-(0.68 - 0.5) * size.x, 0.0)
	var om := ShaderMaterial.new()
	om.shader = ORB_SHADER
	om.set_shader_parameter("size", size)
	om.set_shader_parameter("seed", randf() * 50.0)
	_core.material = om
	_visual.add_child(_core)

	# Огоньки, кружащие вокруг шара
	for i in 3:
		var mote := Sprite2D.new()
		mote.texture = MageFx.dot()
		mote.material = MageFx.add_material()
		mote.modulate = Color(MageFx.CORE.r * 1.5, MageFx.CORE.g * 1.5, MageFx.CORE.b * 1.8)
		mote.scale = Vector2.ONE * 0.45
		_core.add_sibling(mote)
		_motes.append(mote)

	# Хвост из угольков — остаются в мире (local_coords = false)
	var add_mat := MageFx.add_material()
	_trail = GPUParticles2D.new()
	_trail.visibility_rect = MageFx.VIS_RECT
	_trail.amount = 36
	_trail.lifetime = 0.5
	_trail.local_coords = false
	_trail.material = add_mat
	_trail.texture = MageFx.dot()
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0
	pm.direction = Vector3(-_direction.x, -_direction.y, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -14, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.scale_curve = MageFx.size_curve(0.1)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.color_ramp = MageFx.ramp([Color(MageFx.CORE, 1.0), Color(MageFx.MID, 0.85), Color(MageFx.EDGE, 0.0)])
	_trail.process_material = pm
	add_child(_trail)

	# Дымка за шаром: мягкие тёмно-синие клубы, медленно расплываются
	_haze = GPUParticles2D.new()
	_haze.visibility_rect = MageFx.VIS_RECT
	_haze.amount = 14
	_haze.lifetime = 0.7
	_haze.local_coords = false
	_haze.texture = MageFx.soft()
	var hm := ParticleProcessMaterial.new()
	hm.particle_flag_disable_z = true
	hm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	hm.emission_sphere_radius = 3.0
	hm.direction = Vector3(-_direction.x, -_direction.y, 0)
	hm.spread = 25.0
	hm.initial_velocity_min = 4.0
	hm.initial_velocity_max = 12.0
	hm.gravity = Vector3(0, -6, 0)
	hm.scale_min = 0.22
	hm.scale_max = 0.36
	hm.scale_curve = MageFx.size_curve(0.3)
	hm.angle_max = 360.0
	hm.color_ramp = MageFx.ramp([Color(MageFx.EDGE, 0.0), Color(MageFx.EDGE, 0.28), Color(MageFx.SMOKE, 0.0)], [0.0, 0.25, 1.0])
	_haze.process_material = hm
	_haze.material = MageFx.add_material()
	add_child(_haze)

	# Блики: редкие яркие звёздочки, вспыхивают и гаснут
	_glints = GPUParticles2D.new()
	_glints.visibility_rect = MageFx.VIS_RECT
	_glints.amount = 6
	_glints.lifetime = 0.25
	_glints.local_coords = false
	_glints.material = MageFx.add_material()
	_glints.texture = MageFx.dot()
	var gm := ParticleProcessMaterial.new()
	gm.particle_flag_disable_z = true
	gm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	gm.emission_sphere_radius = 9.0
	gm.gravity = Vector3.ZERO
	gm.scale_min = 0.9
	gm.scale_max = 1.8
	gm.scale_curve = MageFx.size_curve(0.15)
	gm.color_ramp = MageFx.ramp([Color(1, 1, 1, 1), Color(MageFx.CORE, 0.8), Color(MageFx.MID, 0.0)])
	_glints.process_material = gm
	add_child(_glints)

	# Свет — подсвечивает тёмную карту вокруг шара и чуть дрожит
	_light = PointLight2D.new()
	_light.color = color
	_light.energy = 1.2
	_light.texture = MageFx.radial()
	_light.texture_scale = 0.75
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)

	# Вспышка у руки при вылете
	var muzzle := MageFx.holder(get_tree(), global_position, 0.6, 12)
	MageFx.flash(muzzle, 30.0, 0.16)
	MageFx.sparks(muzzle, 10, 120.0, 0.3, _direction, 35.0)
	MageFx.light_pulse(muzzle, 50.0, 1.3, 0.25)


func _process(delta: float) -> void:
	if _exploded or _visual == null:
		return
	_spin += delta * 9.0
	for i in _motes.size():
		var a := _spin + i * TAU / _motes.size()
		# Орбита сплюснута — огоньки кружат "вокруг" шара в 3/4 виде
		(_motes[i] as Node2D).position = Vector2(cos(a) * 9.0, sin(a) * 4.0)
		(_motes[i] as CanvasItem).modulate.a = 0.6 + 0.4 * sin(a * 2.0)
	_light.energy = 1.1 + 0.15 * sin(_spin * 2.7) + 0.08 * sin(_spin * 5.3)


## Движение — в физическом кадре (фиксированный шаг): при просадке FPS шар
## не "перепрыгивает" узкий хёртбокс врага за один кадр
func _physics_process(delta: float) -> void:
	if _exploded:
		return
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		_explode(null)


func _on_area_entered(area: Area2D) -> void:
	if _exploded or not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := area.get_parent()
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if "is_dead" in enemy and enemy.is_dead:
		return
	_explode(enemy)


func _on_body_entered(body: Node) -> void:
	if _exploded or body == _caster:
		return
	_explode(null)


func _explode(direct_hit: Node2D) -> void:
	_exploded = true
	set_deferred("monitoring", false)
	var center := global_position
	# Разбиваемые предметы (Levels/props/breakable_prop.gd) отвечают тем же,
	# что враги: is_dead, take_damage, global_position
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("breakable"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if e == direct_hit:
			e.take_damage(direct_damage, _caster)
		elif center.distance_to(e.global_position) <= splash_radius:
			e.take_damage(splash_damage, _caster)
	_spawn_burst(center)
	# Шар гаснет, хвост и дымка доживают своё
	if _visual == null:
		queue_free()
		return
	_visual.visible = false
	_trail.emitting = false
	_haze.emitting = false
	_glints.emitting = false
	var t := create_tween()
	t.tween_property(_light, "energy", 0.0, 0.2)
	await get_tree().create_timer(_haze.lifetime + 0.1).timeout
	queue_free()


## Взрыв — отдельный узел в мире: шар уже исчезает, а взрыв доигрывает на
## месте. Слои: вспышка, ударное кольцо с искажением воздуха, искры-штрихи,
## поднимающиеся угольки, клубы дыма, ожог на земле и короткий свет
func _spawn_burst(at: Vector2) -> void:
	var h := MageFx.holder(get_tree(), at, 2.2, 11)
	MageFx.flash(h, splash_radius * 1.3, 0.18)
	MageFx.light_pulse(h, splash_radius * 1.6, 2.2, 0.5)
	MageFx.sparks(h, 34, 190.0, 0.5)
	MageFx.embers(h, 16, splash_radius * 0.35, 1.2)
	MageFx.smoke(h, 9, splash_radius * 0.3, 46.0, 1.0)

	# Ударное кольцо (тот же шейдер, что у импульса) — быстрое и узкое
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var quad_tex := ImageTexture.create_from_image(img)
	var side := splash_radius * 2.2 / 0.95
	var ring := Sprite2D.new()
	ring.texture = quad_tex
	ring.scale = Vector2(side, side * 0.8) / 4.0
	var rm := ShaderMaterial.new()
	rm.shader = PULSE_SHADER
	rm.set_shader_parameter("color_edge", color)
	rm.set_shader_parameter("intensity", 1.6)
	rm.set_shader_parameter("ring_width", 0.07)
	rm.set_shader_parameter("seed", randf() * 10.0)
	rm.set_shader_parameter("noise_tex", MageFx.noise_tex())
	ring.material = rm
	h.add_child(ring)
	# Искажение воздуха по тому же фронту
	var dist := Sprite2D.new()
	dist.texture = quad_tex
	dist.scale = ring.scale * 1.05
	var dm := ShaderMaterial.new()
	dm.shader = DISTORT_SHADER
	dm.set_shader_parameter("strength", 0.008)
	dist.material = dm
	h.add_child(dist)
	var rt := h.create_tween().set_parallel(true)
	rt.tween_method(_set_pair.bind(rm, dm, "progress"), 0.0, 1.0, 0.26).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	rt.tween_method(_set_pair.bind(rm, dm, "fade"), 1.0, 0.0, 0.32).set_delay(0.08)

	# Ожог на земле: тёмное пятно с тлеющей голубой кромкой, гаснет за 2 с.
	# Ниже персонажей и объектов, над землёй
	var scorch := Sprite2D.new()
	scorch.texture = MageFx.soft()
	scorch.modulate = Color(0.02, 0.03, 0.08, 0.6)
	scorch.scale = Vector2(1.0, 0.6) * splash_radius * 1.1 / 64.0
	scorch.z_as_relative = false
	scorch.z_index = -17
	scorch.position = Vector2(0, 6)
	h.add_child(scorch)
	var glow := Sprite2D.new()
	glow.texture = MageFx.soft()
	glow.material = MageFx.add_material()
	glow.modulate = Color(MageFx.EDGE.r, MageFx.EDGE.g, MageFx.EDGE.b, 0.5)
	glow.scale = scorch.scale * 0.7
	glow.z_as_relative = false
	glow.z_index = -16
	glow.position = scorch.position
	h.add_child(glow)
	var st := h.create_tween().set_parallel(true)
	st.tween_property(glow, "modulate:a", 0.0, 1.0)
	st.tween_property(scorch, "modulate:a", 0.0, 1.4).set_delay(0.7)

	if is_instance_valid(_caster) and _caster.has_method("shake_camera"):
		_caster.shake_camera(1.5, 0.12)


## Один и тот же параметр в двух шейдерах (кольцо и искажение идут вместе).
## Метод, а не лямбда: шейдеры живут на узле взрыва, а не на шаре — шар к
## этому моменту уже удаляется, но твин принадлежит узлу взрыва
static func _set_pair(v: float, a: ShaderMaterial, b: ShaderMaterial, key: String) -> void:
	a.set_shader_parameter(key, v)
	b.set_shader_parameter(key, v)
