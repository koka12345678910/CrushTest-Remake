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
const DISTORT_SHADER := preload("res://Shaders/magic_distort.gdshader")
const CIRCLE_SHADER := preload("res://Shaders/magic_circle.gdshader")
const MageFx := preload("res://Player_scene/mage_fx.gd")

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
var _echo_mat: ShaderMaterial
var _dist_mat: ShaderMaterial
## Рисовать ли рунический круг под магом (первый импульс заклинания)
var rune_circle := false
var _center := Vector2(0, -4)
var _feet := Vector2.ZERO
## Длительность кадра клипа Attack_3_ (из mage.gd) — по ней живёт рунический круг
var _frame := 1.0 / 15.0


## r — докуда дойдёт волна (px), time — за сколько, dis — рассеивание 0..1,
## glow — яркость (вспышка, искры, свет)
## center — центр волны относительно мага (центр его тела на картинке),
## feet — точка под ногами, туда ложится рунический круг; frame — длительность
## кадра клипа в секундах
func setup(caster: Node2D, r: float, time: float, dis: float, dmg: int, push: float, glow: float, circle := false, center := Vector2(0, -4), feet := Vector2(0, 0), frame := 1.0 / 15.0) -> void:
	_center = center
	_feet = feet
	_frame = frame
	rune_circle = circle
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
	# Центр волны — середина тела мага на картинке (center из setup,
	# см. mage.gd::_body_anchor)
	position = _center

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
	_mat.set_shader_parameter("noise_tex", MageFx.noise_tex())
	# Узкое кольцо у большой волны — иначе на большом квадрате оно толстое
	_mat.set_shader_parameter("ring_width", clampf(9.0 / radius, 0.05, 0.16))
	quad.material = _mat
	add_child(quad)

	# Искры — вылетают из мага и гаснут примерно у края волны
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var sparks := GPUParticles2D.new()
	sparks.visibility_rect = MageFx.VIS_RECT
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


	# Вторая волна — тонкое кольцо, идёт вдогонку первой и чуть отстаёт
	var echo := Sprite2D.new()
	echo.texture = quad.texture
	echo.scale = quad.scale * 0.9
	_echo_mat = ShaderMaterial.new()
	_echo_mat.shader = SHADER
	_echo_mat.set_shader_parameter("progress", 0.0)
	_echo_mat.set_shader_parameter("fade", 1.0)
	_echo_mat.set_shader_parameter("color_edge", MageFx.MID)
	_echo_mat.set_shader_parameter("seed", randf() * 10.0)
	_echo_mat.set_shader_parameter("intensity", 0.5 + 0.3 * brightness)
	_echo_mat.set_shader_parameter("dissipate", dissipate)
	_echo_mat.set_shader_parameter("noise_tex", MageFx.noise_tex())
	_echo_mat.set_shader_parameter("ring_width", clampf(4.0 / radius, 0.025, 0.07))
	echo.material = _echo_mat
	add_child(echo)

	# Искажение воздуха по фронту — картинка за волной "плывёт"
	var dist := Sprite2D.new()
	dist.texture = quad.texture
	dist.scale = quad.scale * 1.04
	_dist_mat = ShaderMaterial.new()
	_dist_mat.shader = DISTORT_SHADER
	_dist_mat.set_shader_parameter("strength", 0.006 + 0.008 * brightness)
	_dist_mat.set_shader_parameter("width", clampf(14.0 / radius, 0.08, 0.2))
	dist.material = _dist_mat
	add_child(dist)

	# Пыль, которую поднимает фронт: мягкие клубы летят наружу вместе с волной.
	# Не аддитивные — пыль затуманивает, а не светится
	var dust := MageFx.burst(self, int(10 + 18 * brightness), expand_time + 0.6, MageFx.soft(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3(0, 0, 1)
		pm.emission_ring_radius = radius * 0.35
		pm.emission_ring_inner_radius = radius * 0.25
		pm.emission_ring_height = 0.0
		pm.direction = Vector3(1, 0, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = radius / expand_time * 0.45
		pm.initial_velocity_max = radius / expand_time * 0.7
		pm.damping_min = radius / expand_time * 0.5
		pm.damping_max = radius / expand_time * 0.9
		pm.scale_min = 0.35
		pm.scale_max = 0.6
		pm.scale_curve = MageFx.size_curve(0.3)
		pm.angle_max = 360.0
		pm.color_ramp = MageFx.ramp([Color(MageFx.SMOKE, 0.0), Color(MageFx.SMOKE, 0.2), Color(MageFx.SMOKE, 0.0)], [0.0, 0.25, 1.0]), false)
	dust.scale = Vector2(1.0, 0.8)

	# Искры-штрихи наружу — летят вместе с фронтом
	MageFx.sparks(self, int(10 + 22 * brightness), radius / expand_time * 1.3, expand_time + 0.2)

	# Рунический круг на земле (только у первого импульса — он открывает
	# заклинание и висит, пока не пройдёт большая волна)
	if rune_circle:
		_spawn_circle()

	_light = PointLight2D.new()
	_light.color = color
	_light.energy = 1.0 + 0.5 * brightness
	_light.texture = _radial_texture()
	_light.texture_scale = minf(radius, 90.0) * 2.8 / 128.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)

	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, expand_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_light, "energy", 0.0, expand_time + fade_time)
	t.tween_method(_set_fade, 1.0, 0.0, fade_time)
	# Ждём, пока доиграют пыль и искры — они дети этого узла
	t.tween_interval(0.75)
	t.tween_callback(queue_free)


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
	_dist_mat.set_shader_parameter("progress", v)
	# Вторая волна отстаёт и не доходит до самого края
	_echo_mat.set_shader_parameter("progress", clampf((v - 0.14) / 0.86, 0.0, 1.0) * 0.9)
	_front = v * radius
	_hit_front()


func _set_fade(v: float) -> void:
	_mat.set_shader_parameter("fade", v)
	_echo_mat.set_shader_parameter("fade", v)
	_dist_mat.set_shader_parameter("fade", v)


## Рунический круг на земле под магом: прорисовывается по окружности,
## медленно вращается, светится и гаснет. Живёт в мире, а не на маге —
## круг остаётся на месте заклинания, даже если маг сдвинется. Все времена —
## в кадрах клипа (* _frame): висит, пока не пройдёт большая волна
func _spawn_circle() -> void:
	var at := global_position - _center + _feet
	var h := MageFx.holder(get_tree(), at, 19.5 * _frame, 0)
	# Под персонажами (y-sort уровня), но над землёй
	h.z_as_relative = false
	h.z_index = -16
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	var size := 74.0
	s.scale = Vector2(size, size * 0.62) / 4.0
	var m := ShaderMaterial.new()
	m.shader = CIRCLE_SHADER
	m.set_shader_parameter("seed", randf() * 10.0)
	m.set_shader_parameter("draw", 0.0)
	m.set_shader_parameter("fade", 1.0)
	m.set_shader_parameter("intensity", 1.2)
	s.material = m
	h.add_child(s)
	MageFx.light_pulse(h, 70.0, 1.0, 16.5 * _frame)
	# Руны-искорки поднимаются с круга
	MageFx.embers(h, 14, 26.0, 1.0)
	var t := h.create_tween()
	t.tween_method(func(v: float): m.set_shader_parameter("draw", v), 0.0, 1.0, 2.7 * _frame)
	t.parallel().tween_property(s, "scale", s.scale * 1.08, 15.0 * _frame)
	t.tween_interval(6.75 * _frame)
	t.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, 7.5 * _frame)


## Бьём всех, до кого уже дошёл фронт волны (каждого один раз)
func _hit_front() -> void:
	if not is_instance_valid(_caster):
		return
	# От центра самой волны — там, где её видно, а не от точки опоры мага
	var origin := global_position
	# Разбиваемые предметы (Levels/props/breakable_prop.gd) отвечают тем же,
	# что враги: is_dead, take_damage, global_position
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("breakable"):
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
		MageFx.hit_burst(get_tree(), e.global_position, to.normalized() if to.length() > 0.001 else Vector2.DOWN)
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
