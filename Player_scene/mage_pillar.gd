extends Node2D
## mage_pillar.gd — один столп голубого огня особой атаки мага (SpecialAttack_,
## см. mage.gd::_cast_pillars). Живёт в мире, а не на маге.
##
## Порядок: под целью проступает рунический круг и идёт за ней, пока маг
## собирает силу -> через delay из круга вырывается столп (убивает цель) ->
## держится, сужается, отрывается от земли и гаснет. Собран целиком кодом;
## сам огонь — один квадрат с шейдером, остальное — немного частиц и свет.

const SHADER := preload("res://Shaders/magic_pillar.gdshader")
const CIRCLE_SHADER := preload("res://Shaders/magic_circle.gdshader")
const MageFx := preload("res://Player_scene/mage_fx.gd")

## Размер столпа в пикселях мира
@export var width := 50.0
@export var height := 130.0
## Сколько длятся подъём, горение и угасание — в кадрах клипа SpecialAttack_
## (длительность кадра приходит из mage.gd), чтобы столп шёл в темпе анимации
@export var rise_frames := 2.0
@export var burn_frames := 7.5
@export var out_frames := 5.0

var _caster: Node2D
var _target: Node2D
var _offset := Vector2.ZERO
var _delay := 0.3
var _frame := 0.1
var _rise_time := 0.2
var _burn_time := 0.75
var _out_time := 0.5
var _erupted := false
var _mat: ShaderMaterial
var _flame: Sprite2D
var _circle_mat: ShaderMaterial


## target — враг (столп идёт за ним до извержения), offset — точка под его
## ногами относительно узла; без цели столп встаёт в at (координаты мира)
## frame — длительность одного кадра клипа в секундах
func setup(caster: Node2D, target: Node2D, offset: Vector2, at: Vector2, delay: float, frame := 0.1) -> void:
	_caster = caster
	_target = target
	_offset = offset
	_delay = delay
	_frame = frame
	position = at


func _ready() -> void:
	z_index = 11
	_rise_time = rise_frames * _frame
	_burn_time = burn_frames * _frame
	_out_time = out_frames * _frame
	_follow()
	_spawn_circle()
	get_tree().create_timer(_delay).timeout.connect(_erupt)


func _process(_delta: float) -> void:
	if not _erupted:
		_follow()


func _follow() -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position + _offset


## Руны на земле — та же отрисовка, что у круга под импульсом, только меньше.
## Под персонажами (y-sort уровня), но над землёй
func _spawn_circle() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.z_as_relative = false
	s.z_index = -16
	s.scale = Vector2(width * 1.15, width * 1.15 * 0.62) / 4.0
	_circle_mat = ShaderMaterial.new()
	_circle_mat.shader = CIRCLE_SHADER
	_circle_mat.set_shader_parameter("seed", randf() * 10.0)
	_circle_mat.set_shader_parameter("draw", 0.0)
	_circle_mat.set_shader_parameter("fade", 1.0)
	_circle_mat.set_shader_parameter("intensity", 1.0)
	_circle_mat.set_shader_parameter("spin", 1.4)
	s.material = _circle_mat
	add_child(s)
	var t := create_tween()
	t.tween_method(func(v: float): _circle_mat.set_shader_parameter("draw", v), 0.0, 1.0, minf(_delay, 2.5 * _frame))


func _erupt() -> void:
	_erupted = true

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_flame = Sprite2D.new()
	_flame.texture = ImageTexture.create_from_image(img)
	_flame.scale = Vector2(width, height) / 4.0
	# Низ квадрата — на земле под врагом
	_flame.position = Vector2(0, -height * 0.5 + 8.0)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise_tex", MageFx.noise_tex())
	_mat.set_shader_parameter("seed", randf() * 10.0)
	_mat.set_shader_parameter("aspect", height / width)
	_mat.set_shader_parameter("speed", randf_range(0.9, 1.15))
	_mat.set_shader_parameter("rise", 0.0)
	_mat.set_shader_parameter("intensity", 0.95)
	_flame.material = _mat
	add_child(_flame)

	# Вспышка у земли, искры вверх и в стороны, угли по всему столпу, свет
	MageFx.flash(self, width * 1.3, 0.18)
	MageFx.sparks(self, 12, 260.0, 0.45, Vector2.UP, 28.0)
	MageFx.sparks(self, 8, 120.0, 0.3)
	_column_embers()
	MageFx.smoke(self, 5, width * 0.3, 34.0, 0.9)
	var light_at := Node2D.new()
	light_at.position = Vector2(0, -height * 0.35)
	add_child(light_at)
	MageFx.light_pulse(light_at, 80.0, 1.8, _rise_time + _burn_time + _out_time)

	_hit()

	var t := create_tween()
	t.tween_method(_set_param.bind("rise"), 0.0, 1.0, _rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_interval(_burn_time)
	t.tween_method(_set_param.bind("thin"), 0.0, 1.0, _out_time).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(_set_param.bind("lift"), 0.0, 0.7, _out_time).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(_set_param.bind("fade"), 1.0, 0.0, _out_time).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(func(v: float): _circle_mat.set_shader_parameter("fade", v), 1.0, 0.0, _out_time)
	# Дожидаемся углей и дыма — они дети этого узла
	t.tween_interval(0.6)
	t.tween_callback(queue_free)


func _set_param(v: float, param: String) -> void:
	_mat.set_shader_parameter(param, v)


## Угли поднимаются по всей ширине столпа и улетают выше его макушки
func _column_embers() -> void:
	var p := MageFx.burst(self, 18, 0.9, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(width * 0.28, height * 0.25, 0)
		pm.emission_shape_offset = Vector3(0, -height * 0.25, 0)
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 70.0
		pm.initial_velocity_max = 150.0
		pm.damping_min = 30.0
		pm.damping_max = 60.0
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
		pm.turbulence_noise_scale = 2.5
		pm.color_ramp = MageFx.ramp([Color(MageFx.CORE, 1.0), Color(MageFx.MID, 0.9), Color(MageFx.EDGE, 0.0)], [0.0, 0.35, 1.0]))
	p.explosiveness = 0.6


func _hit() -> void:
	if not is_instance_valid(_target) or _target.is_dead:
		return
	# Смертельно: урон на всё оставшееся здоровье, мимо блока и парирования
	_target.take_damage(maxi(ceili(_target.health), 1), _caster, true)
	MageFx.hit_burst(get_tree(), _target.global_position, Vector2.UP)
