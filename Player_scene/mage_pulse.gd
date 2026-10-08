extends Node2D
## mage_pulse.gd — один импульс мага (Attack_3_): синяя ударная волна-кольцо
## вокруг мага. Атака делает два импульса (см. mage.gd::_cast_pulses):
## первый — маленький и короткий, второй — большая волна, которая уходит
## далеко и по пути рассеивается (шире, рванее, тусклее).
##
## Бьёт ФРОНТ волны: враг получает удар в тот момент, когда кольцо до него
## дошло, а не мгновенно по всей площади. Чем дальше враг, тем слабее его
## отбросит — волна к краю выдыхается. Собран целиком кодом.

const SHADER := preload("res://Shaders/magic_pulse.gdshader")

@export var color := Color(0.3, 0.6, 1.0)

var radius := 50.0
var expand_time := 0.2
var fade_time := 0.18
## 0 — держит форму, 1 — к краю пути расплывается и тает (см. шейдер)
var dissipate := 0.0
var damage := 1
var knockback := 260.0
var brightness := 1.0

var _caster: Node2D
var _mat: ShaderMaterial
var _light: PointLight2D
var _hit_ids := {}
var _front := 0.0


## r — докуда дойдёт волна (px), time — за сколько, dis — рассеивание 0..1,
## glow — яркость (вспышка, искры, свет)
func setup(caster: Node2D, r: float, time: float, dis: float, dmg: int, push: float, glow: float) -> void:
	_caster = caster
	radius = r
	expand_time = time
	dissipate = dis
	damage = dmg
	knockback = push
	brightness = glow
	fade_time = time * 0.5


func _ready() -> void:
	z_index = 11
	# Центр волны — корпус мага, чуть выше точки опоры
	position = Vector2(0, -4)

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var quad := Sprite2D.new()
	quad.texture = ImageTexture.create_from_image(img)
	# Квадрат 2r x 2r; по вертикали чуть сплюснут — круг на земле в 3/4 виде.
	# Фронт в шейдере доходит до 0.95 стороны — подгоняем, чтобы ровно до r
	var side := radius * 2.0 / 0.95
	quad.scale = Vector2(side, side * 0.8) / 4.0
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("fade", 1.0)
	_mat.set_shader_parameter("color_edge", color)
	_mat.set_shader_parameter("seed", randf() * 10.0)
	_mat.set_shader_parameter("intensity", 1.1 + 0.6 * brightness)
	_mat.set_shader_parameter("dissipate", dissipate)
	# Узкое кольцо у большой волны — иначе на большом квадрате оно толстое
	_mat.set_shader_parameter("ring_width", clampf(9.0 / radius, 0.05, 0.16))
	quad.material = _mat
	add_child(quad)

	# Искры — вылетают из мага и гаснут примерно у края волны
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var sparks := GPUParticles2D.new()
	sparks.amount = int(24 + 36 * brightness)
	sparks.lifetime = expand_time + 0.15
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.local_coords = false
	sparks.material = add_mat
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 8.0
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = radius / expand_time * 0.9
	pm.initial_velocity_max = radius / expand_time * 1.5
	pm.damping_min = radius / expand_time * 1.2
	pm.damping_max = radius / expand_time * 2.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.9
	pm.scale_max = 2.2
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.9, 0.98, 1.0, 1.0), Color(color, 0.85), Color(0.1, 0.2, 0.9, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	sparks.process_material = pm
	sparks.texture = _dot_texture()
	add_child(sparks)
	sparks.emitting = true

	_light = PointLight2D.new()
	_light.color = color
	_light.energy = 1.4 + 0.8 * brightness
	_light.texture = _radial_texture()
	_light.texture_scale = minf(radius, 90.0) * 2.8 / 128.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)

	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, expand_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_light, "energy", 0.0, expand_time + fade_time)
	t.tween_method(func(v: float): _mat.set_shader_parameter("fade", v), 1.0, 0.0, fade_time)
	t.tween_interval(0.2)
	t.tween_callback(queue_free)


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
	_front = v * radius
	_hit_front()


## Бьём всех, до кого уже дошёл фронт волны (каждого один раз)
func _hit_front() -> void:
	if not is_instance_valid(_caster):
		return
	var origin := _caster.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		var id: int = e.get_instance_id()
		if _hit_ids.has(id):
			continue
		var to: Vector2 = e.global_position - origin
		# Та же сплюснутость, что у кольца: по вертикали волна чуть короче
		var dist := Vector2(to.x, to.y / 0.8).length()
		if dist > _front:
			continue
		_hit_ids[id] = true
		e.take_damage(damage, _caster)
		if not e.is_dead and "knockback_velocity" in e:
			var dir := to.normalized() if to.length() > 0.001 else Vector2.DOWN
			# К краю пути волна выдыхается — дальних толкает слабее
			var falloff := 1.0 - dissipate * 0.6 * clampf(dist / radius, 0.0, 1.0)
			e.knockback_velocity = dir * knockback * falloff


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
