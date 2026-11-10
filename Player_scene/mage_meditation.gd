extends Node2D
## mage_meditation.gd — вид «Медитации» (руна Лагуз, Z — держать): маг
## опускается на колено, под ним медленно прорисовывается рунный круг, из
## земли вокруг поднимаются искры Сейда и стекаются к нему. Чем дольше сидит,
## тем ярче (power тянет маг: 0 — только сел, 1 — полный приток).
## Висит на маге; погасить — fade_out(). Механика (сколько Сейда, что
## прерывает) — в mage.gd::_update_meditation.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const CIRCLE_SHADER := preload("res://Shaders/magic_circle.gdshader")

## Сейд — цвет шкалы (mage.gd::SEID_LACK_COLOR), а не лёд и не огонь
const SEID_CORE := Color(0.8, 0.9, 1.0)
const SEID_EDGE := Color(0.32, 0.5, 0.95)

var feet := Vector2(0, 24)
var power := 0.0
var _circle_mat: ShaderMaterial
var _circle: Node2D
var _motes: GPUParticles2D
var _light: PointLight2D
var _done := false


func _ready() -> void:
	# Круг — на земле под всеми (как рунический круг импульса)
	_circle = Node2D.new()
	_circle.z_as_relative = false
	_circle.z_index = -16
	_circle.position = feet
	add_child(_circle)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.scale = Vector2(84.0, 84.0 * 0.62) / 4.0
	_circle_mat = ShaderMaterial.new()
	_circle_mat.shader = CIRCLE_SHADER
	_circle_mat.set_shader_parameter("seed", randf() * 10.0)
	_circle_mat.set_shader_parameter("draw", 0.0)
	_circle_mat.set_shader_parameter("fade", 1.0)
	_circle_mat.set_shader_parameter("intensity", 0.6)
	_circle_mat.set_shader_parameter("spin", 0.25)
	_circle_mat.set_shader_parameter("color_core", SEID_CORE)
	_circle_mat.set_shader_parameter("color_edge", SEID_EDGE)
	s.material = _circle_mat
	_circle.add_child(s)

	# Искры Сейда: рождаются кольцом на земле и стягиваются к магу, поднимаясь
	_motes = GPUParticles2D.new()
	_motes.amount = 26
	_motes.lifetime = 1.3
	_motes.local_coords = true
	_motes.texture = MageFx.dot()
	_motes.material = MageFx.add_material()
	_motes.visibility_rect = MageFx.VIS_RECT
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = 48.0
	pm.emission_ring_inner_radius = 34.0
	pm.emission_ring_height = 0.0
	pm.radial_velocity_min = -30.0
	pm.radial_velocity_max = -22.0
	pm.orbit_velocity_min = 0.12
	pm.orbit_velocity_max = 0.25
	pm.gravity = Vector3(0, -14, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.color_ramp = MageFx.ramp([Color(SEID_CORE, 0.0), Color(SEID_CORE, 0.9), Color(SEID_EDGE, 0.0)], [0.0, 0.3, 1.0])
	_motes.process_material = pm
	_motes.position = feet
	_motes.scale = Vector2(1.0, 0.62)
	_motes.z_index = 1
	add_child(_motes)
	_motes.emitting = true

	_light = PointLight2D.new()
	_light.texture = MageFx.radial()
	_light.texture_scale = 120.0 / 128.0
	_light.color = SEID_EDGE
	_light.energy = 0.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	_light.position = feet * 0.5
	add_child(_light)

	create_tween().tween_method(func(v: float): _circle_mat.set_shader_parameter("draw", v), 0.0, 1.0, 0.5)


func _process(_delta: float) -> void:
	if _done:
		return
	_circle_mat.set_shader_parameter("intensity", 0.5 + 0.8 * power)
	_light.energy = 0.25 + 0.75 * power
	_motes.speed_scale = 0.7 + 0.8 * power


## Встал: круг тает, искры доигрывают
func fade_out() -> void:
	if _done:
		return
	_done = true
	_motes.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): _circle_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	tw.tween_property(_light, "energy", 0.0, 0.3)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_callback(queue_free)
