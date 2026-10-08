extends Node2D
## mage_sweep.gd — ближняя атака мага (Attack_2_): поток магии, который рука
## проводит по диагонали перед магом. Синяя пелена-полумесяц "прорисовывается"
## вслед за рукой, в середине взмаха бьёт всех врагов в секторе перед магом
## и сильно отбрасывает их. Собран целиком кодом, как и огненный шар.
##
## Направление прохода подогнано под анимацию Attack_2_: при взгляде вниз
## поток идёт от левого плеча к правому низу, вправо — снизу вверх-вправо,
## вверх — справа налево. Во всех случаях это одно и то же вращение
## относительно взгляда: от (взгляд + start_offset) к (взгляд + end_offset).

const SHADER := preload("res://Shaders/magic_sweep.gdshader")
const SEGMENTS := 28

@export var inner_radius := 12.0
@export var outer_radius := 64.0
@export var start_offset_deg := 100.0
@export var end_offset_deg := -65.0
@export var sweep_time := 0.22
@export var fade_time := 0.32
## Сектор поражения: радиус и половина угла от направления взгляда
@export var hit_reach := 70.0
@export var hit_half_angle_deg := 80.0
@export var color := Color(0.3, 0.6, 1.0)

var damage := 1
var knockback := 330.0

var _caster: Node2D
var _facing := Vector2.DOWN
var _mat: ShaderMaterial
var _sparks: GPUParticles2D
var _light: PointLight2D
var _progress := 0.0
var _hit_done := false


func setup(caster: Node2D, facing: Vector2, dmg: int, push: float) -> void:
	_caster = caster
	_facing = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	damage = dmg
	knockback = push


func _ready() -> void:
	z_index = 11
	# Центр дуги — грудь мага, а не ноги
	position = Vector2(0, -6)

	var mesh_node := MeshInstance2D.new()
	mesh_node.mesh = _build_arc()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("fade", 1.0)
	_mat.set_shader_parameter("color_edge", color)
	mesh_node.material = _mat
	add_child(mesh_node)

	# Искры с головы потока — остаются в мире (local_coords = false)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sparks = GPUParticles2D.new()
	_sparks.amount = 36
	_sparks.lifetime = 0.4
	_sparks.local_coords = false
	_sparks.material = add_mat
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 10.0
	pm.direction = Vector3(_facing.x, _facing.y, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 70.0
	pm.damping_min = 60.0
	pm.damping_max = 120.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 2.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.85, 0.97, 1.0, 1.0), Color(color, 0.85), Color(0.1, 0.2, 0.9, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_sparks.process_material = pm
	_sparks.texture = _dot_texture()
	add_child(_sparks)
	_sparks.global_position = _head_position(0.0)

	_light = PointLight2D.new()
	_light.color = color
	_light.energy = 0.0
	_light.texture = _radial_texture()
	_light.texture_scale = outer_radius * 2.6 / 128.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	_light.position = _facing * outer_radius * 0.45
	add_child(_light)

	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, sweep_time)
	t.parallel().tween_property(_light, "energy", 1.4, sweep_time * 0.6)
	t.tween_callback(func(): _sparks.emitting = false)
	t.tween_method(func(v: float): _mat.set_shader_parameter("fade", v), 1.0, 0.0, fade_time)
	t.parallel().tween_property(_light, "energy", 0.0, fade_time)
	t.tween_interval(_sparks.lifetime)
	t.tween_callback(queue_free)


func _set_progress(v: float) -> void:
	_progress = v
	_mat.set_shader_parameter("progress", v)
	if is_instance_valid(_sparks):
		_sparks.global_position = _head_position(v)
	# Удар — когда поток прошёл середину, т.е. оказался прямо перед магом
	if not _hit_done and v >= 0.5:
		_hit_done = true
		_apply_hit()


func _angle_at(t: float) -> float:
	var a := _facing.angle()
	return a + deg_to_rad(lerpf(start_offset_deg, end_offset_deg, t))


func _head_position(t: float) -> Vector2:
	var r := (inner_radius + outer_radius) * 0.5
	return global_position + Vector2.from_angle(_angle_at(t)) * r


func _build_arc() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var dir := Vector2.from_angle(_angle_at(t))
		# Полумесяц: к концам дуга сужается, в середине — шире
		var swell := sin(t * PI) * 0.35 + 0.65
		verts.append(dir * inner_radius)
		uvs.append(Vector2(t, 0.0))
		verts.append(dir * (inner_radius + (outer_radius - inner_radius) * swell))
		uvs.append(Vector2(t, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh


func _apply_hit() -> void:
	if not is_instance_valid(_caster):
		return
	var origin := _caster.global_position
	var half := deg_to_rad(hit_half_angle_deg)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		var to: Vector2 = e.global_position - origin
		if to.length() > hit_reach:
			continue
		if to.length() > 4.0 and absf(_facing.angle_to(to)) > half:
			continue
		e.take_damage(damage, _caster)
		# Свой отброс — сильнее стандартного (enemy.take_damage даёт 150)
		if not e.is_dead and "knockback_velocity" in e:
			var push_dir := to.normalized() if to.length() > 0.001 else _facing
			e.knockback_velocity = push_dir * knockback


func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 4
	t.height = 4
	return t


func _radial_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t
