extends Area2D
## druid_seed.gd — Шип-семя Сольвейг (ЛКМ, druid.gd::_cast_seed): светло-
## зелёный сгусток живой силы с шипом-семенем внутри. Летит по прямой, за
## ним тянутся пыльца и листья; во врага — урон и всплеск зелени, в стену
## или в конце полёта — рассыпается пыльцой.
##
## Та же техника, что огненный шар Эйрика (mage_fireball.gd): ядро —
## шейдер magic_orb (перекрашен), частицы, свет. Собран кодом, без .tscn.

const DruidFx := preload("res://Player_scene/druid_fx.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")
const ORB_SHADER := preload("res://Shaders/magic_orb.gdshader")

var speed := 320.0
var lifetime := 1.2
var damage := 1
var dissolve_time := 0.22

var _caster: Node2D
var _direction := Vector2.RIGHT
var _age := 0.0
var _done := false
var _visual: Node2D
var _core: Sprite2D
var _seed_sprite: Node2D
var _trail: GPUParticles2D
var _leaf_trail: GPUParticles2D
var _light: PointLight2D
var _spin := 0.0


func launch(from: Vector2, direction: Vector2, caster: Node2D) -> void:
	global_position = from
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_caster = caster


func _ready() -> void:
	z_index = 10
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	_build_visuals.call_deferred()


func _build_visuals() -> void:
	_visual = Node2D.new()
	_visual.rotation = _direction.angle()
	add_child(_visual)

	# Ядро — шар с хвостом (шейдер мага, светло-зелёный)
	_core = Sprite2D.new()
	_core.texture = DruidFx.white()
	var size := Vector2(70.0, 34.0)
	_core.scale = size / 4.0
	_core.position = Vector2(-(0.68 - 0.5) * size.x, 0.0)
	var om := ShaderMaterial.new()
	om.shader = ORB_SHADER
	om.set_shader_parameter("size", size)
	om.set_shader_parameter("seed", randf() * 50.0)
	om.set_shader_parameter("radius", 5.5)
	om.set_shader_parameter("tail_length", 36.0)
	om.set_shader_parameter("color_core", DruidFx.CORE)
	om.set_shader_parameter("color_mid", DruidFx.MID)
	om.set_shader_parameter("color_edge", DruidFx.EDGE)
	_core.material = om
	_visual.add_child(_core)

	# Семя-шип в сердцевине: тёмная капля острием вперёд, крутится
	_seed_sprite = _SeedShape.new()
	_visual.add_child(_seed_sprite)

	# Хвост пыльцы — остаётся в мире
	_trail = GPUParticles2D.new()
	_trail.visibility_rect = MageFx.VIS_RECT
	_trail.amount = 30
	_trail.lifetime = 0.55
	_trail.local_coords = false
	_trail.material = MageFx.add_material()
	_trail.texture = MageFx.dot()
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0
	pm.direction = Vector3(-_direction.x, -_direction.y, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(0, -12, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.scale_curve = MageFx.size_curve(0.1)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.8
	pm.color_ramp = DruidFx.ramp_glow(0.85)
	_trail.process_material = pm
	add_child(_trail)

	# Редкие листья срываются с хвоста и кружатся
	_leaf_trail = GPUParticles2D.new()
	_leaf_trail.visibility_rect = MageFx.VIS_RECT
	_leaf_trail.amount = 5
	_leaf_trail.lifetime = 0.8
	_leaf_trail.local_coords = false
	_leaf_trail.texture = DruidFx.leaf()
	var lm := CanvasItemMaterial.new()
	lm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_leaf_trail.material = lm
	var lpm := ParticleProcessMaterial.new()
	lpm.particle_flag_disable_z = true
	lpm.direction = Vector3(-_direction.x, -_direction.y, 0)
	lpm.spread = 60.0
	lpm.initial_velocity_min = 10.0
	lpm.initial_velocity_max = 30.0
	lpm.gravity = Vector3(0, 30, 0)
	lpm.angle_max = 360.0
	lpm.angular_velocity_min = -300.0
	lpm.angular_velocity_max = 300.0
	lpm.scale_min = 0.6
	lpm.scale_max = 1.0
	lpm.color_ramp = MageFx.ramp([Color(DruidFx.MID, 1.0), Color(DruidFx.LEAF, 0.9), Color(DruidFx.DEEP, 0.0)], [0.0, 0.6, 1.0])
	_leaf_trail.process_material = lpm
	add_child(_leaf_trail)

	_light = DruidFx.light(self, 36.0, 1.3)

	# Вспышка у руки
	var muzzle := DruidFx.holder(get_tree(), global_position, 0.8, 12)
	DruidFx.flash(muzzle, 26.0, 0.15)
	DruidFx.sparks(muzzle, 8, 110.0, 0.3, _direction, 35.0)
	DruidFx.leaves(muzzle, 3, 60.0, 0.6, _direction, 50.0)
	DruidFx.light_pulse(muzzle, 46.0, 1.3, 0.25)


func _process(delta: float) -> void:
	if _done or _visual == null:
		return
	_spin += delta * 14.0
	_seed_sprite.rotation = sin(_spin * 0.5) * 0.25
	_light.energy = 1.2 + 0.15 * sin(_spin * 1.9) + 0.08 * sin(_spin * 4.1)


func _physics_process(delta: float) -> void:
	if _done:
		return
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		_finish(null)


func _on_area_entered(area: Area2D) -> void:
	if _done or not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := area.get_parent()
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if "is_dead" in enemy and enemy.is_dead:
		return
	_finish(enemy)


func _on_body_entered(body: Node) -> void:
	if _done or body == _caster:
		return
	_finish(null)


func _finish(hit: Node2D) -> void:
	_done = true
	set_deferred("monitoring", false)
	var at := global_position
	if is_instance_valid(hit):
		if "player" in hit and hit.player == null and is_instance_valid(_caster):
			hit.player = _caster
		hit.take_damage(damage, _caster)
		DruidFx.hit_burst(get_tree(), at, _direction)
		if is_instance_valid(_caster) and _caster.has_method("_on_seed_hit"):
			_caster._on_seed_hit(hit)
	else:
		var h := DruidFx.holder(get_tree(), at, 1.2, 11)
		DruidFx.flash(h, 16.0, 0.12)
		DruidFx.pollen(h, 10, 5.0, 0.8, 24.0)
		DruidFx.light_pulse(h, 38.0, 0.9, 0.3)
	if _visual == null:
		queue_free()
		return
	_trail.emitting = false
	_leaf_trail.emitting = false
	var orb := _core.material as ShaderMaterial
	var t := create_tween().set_parallel(true)
	t.tween_property(_visual, "scale", Vector2.ONE * 1.35, dissolve_time).set_ease(Tween.EASE_OUT)
	t.tween_property(_visual, "modulate:a", 0.0, dissolve_time).set_ease(Tween.EASE_IN)
	t.tween_method(func(v: float): orb.set_shader_parameter("intensity", v), 1.0, 0.0, dissolve_time)
	t.tween_property(_light, "energy", 0.0, dissolve_time)
	await get_tree().create_timer(maxf(dissolve_time, _trail.lifetime) + 0.3).timeout
	queue_free()


## Семя: тёмно-зелёная капля с острым носом и светлой каймой
class _SeedShape extends Node2D:
	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(5.5, 0), Vector2(0.5, -2.4), Vector2(-3.0, -1.6),
				Vector2(-4.0, 0), Vector2(-3.0, 1.6), Vector2(0.5, 2.4)])
		draw_colored_polygon(pts, Color(0.16, 0.42, 0.12))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.85, 1.0, 0.7, 0.9), 0.8, true)
