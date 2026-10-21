extends Node2D
## rain_system.gd — дождь уровня. Сам находит камеру текущего героя (рыцарь,
## лучница, маг — у кого какая) и держит дождь вокруг её вида. Раньше капли
## висели только на камере рыцаря (player.tscn), у остальных дождя не было.
##
## Слои:
##   - пелена ливня (Shaders/rain_sheet.gdshader): три слоя тонких косых
##     струй разной дальности с параллаксом — толща дождя;
##   - капли (GPUParticles2D): штрихи, вытянутые по полёту и наклонённые
##     ветром; рождаются по всему виду и пролетают короткий отрезок — в 3/4
##     виде сверху так и выглядит падение на землю;
##   - касание земли: расходящиеся колечки и брызги-короны по всему виду, их
##     частота идёт за силой дождя (суб-эмиттеры капель в 4.3 тут не
##     срабатывали — отдельные излучатели надёжнее, а на глаз то же самое);
##   - порывы: плавный шум раз в несколько секунд усиливает дождь и сильнее
##     кладёт его по ветру.
## Всё освещается светом уровня (луна сквозь облака, костры): в пятнах света
## дождь блестит, в темноте почти тонет.
##
## Под крышей дом гасит дождь через modulate (house_interior.gd, группа
## rain_fx).

## Базовая сила дождя (0..1) — плотность пелены и капель без порывов
@export_range(0.0, 1.0) var intensity := 0.6
## Насколько порывы добавляют к силе и как часто (с)
@export_range(0.0, 1.0) var gust_strength := 0.2
@export var gust_period := 9.0
## Наклон дождя: сдвиг по x на единицу падения (минус — влево)
@export var slant := -0.22
@export var gust_slant := 0.08
@export var rain_color := Color(0.62, 0.7, 0.84)
## Яркость пелены и капель. Дождь — фон: он должен читаться, но не забирать
## внимание у боя (2026-10-21 приглушён по просьбе игрока)
@export var sheet_strength := 0.75
@export var drop_brightness := 1.15
## Капли: сколько одновременно (при силе 1) и скорость
@export var drop_amount := 150
@export var big_drop_amount := 10
@export var drop_speed := 820.0

const RIPPLE_W := 24
const RIPPLE_H := 12

var _camera: Camera2D
var _sheet: Sprite2D
var _sheet_mat: ShaderMaterial
var _drops: GPUParticles2D
var _drops_pm: ParticleProcessMaterial
var _big: GPUParticles2D
var _big_pm: ParticleProcessMaterial
var _ripples: GPUParticles2D
var _crowns: GPUParticles2D
var _noise := FastNoiseLite.new()
var _t := 0.0
var _view := Vector2(640, 360)
var _boost := 0.0
var _boost_decay := 0.0


func _ready() -> void:
	add_to_group("rain_fx")
	_noise.seed = randi()
	_noise.frequency = 1.0 / gust_period

	var white := _white_tex()
	_sheet = Sprite2D.new()
	_sheet.texture = white
	_sheet.z_as_relative = false
	_sheet.z_index = 85
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = preload("res://Shaders/rain_sheet.gdshader")
	_sheet.material = _sheet_mat
	add_child(_sheet)

	# Касания земли — лежат на земле (над кровью и выжиганием, под героями)
	_ripples = _make_particles(150, 0.5, _ripple_tex(), -14)
	var rp := _ripples.process_material as ParticleProcessMaterial
	rp.gravity = Vector3.ZERO
	rp.scale_min = 0.5
	rp.scale_max = 1.0
	rp.scale_curve = _curve([Vector2(0.0, 0.25), Vector2(1.0, 1.0)])
	var rc := rain_color * drop_brightness * 1.2
	rp.color_ramp = _ramp([Color(rc, 0.62), Color(rc, 0.28), Color(rc, 0.0)], [0.0, 0.4, 1.0])

	_crowns = _make_particles(90, 0.32, _dot_tex(), -13)
	var cp := _crowns.process_material as ParticleProcessMaterial
	cp.direction = Vector3(0, -1, 0)
	cp.spread = 70.0
	cp.initial_velocity_min = 30.0
	cp.initial_velocity_max = 70.0
	cp.gravity = Vector3(0, 320, 0)
	cp.scale_min = 0.6
	cp.scale_max = 1.0
	cp.color_ramp = _ramp([Color(rc, 0.5), Color(rc, 0.0)], [0.0, 1.0])

	# Капли — над героями, как и пелена
	_drops = _make_particles(drop_amount, 0.22, _streak_tex(), 84)
	_drops_pm = _drops.process_material
	_drops.randomness = 0.6
	_drops_pm.lifetime_randomness = 0.6
	_drops_pm.particle_flag_align_y = true
	_drops_pm.initial_velocity_min = drop_speed * 0.85
	_drops_pm.initial_velocity_max = drop_speed * 1.15
	_drops_pm.gravity = Vector3.ZERO
	_drops_pm.scale_min = 0.6
	_drops_pm.scale_max = 1.1
	_drops_pm.color = Color(rain_color.r * drop_brightness, rain_color.g * drop_brightness, rain_color.b * drop_brightness, 0.36)

	_big = _make_particles(big_drop_amount, 0.26, _streak_tex(), 84)
	_big_pm = _big.process_material
	_big_pm.particle_flag_align_y = true
	_big_pm.lifetime_randomness = 0.5
	_big_pm.initial_velocity_min = drop_speed * 1.1
	_big_pm.initial_velocity_max = drop_speed * 1.35
	_big_pm.gravity = Vector3.ZERO
	_big_pm.scale_min = 1.1
	_big_pm.scale_max = 1.4
	_big_pm.color = Color(rain_color.r * drop_brightness, rain_color.g * drop_brightness, rain_color.b * drop_brightness, 0.4)


func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		# Герой появляется позже уровня (player_spawner) — ищем лениво
		var hero := get_tree().get_first_node_in_group("player")
		if hero:
			_camera = hero.get_node_or_null("Camera2D") as Camera2D
		if not is_instance_valid(_camera):
			return
	_t += delta
	global_position = _camera.get_screen_center_position()
	_view = get_viewport().get_visible_rect().size / _camera.zoom

	# Порыв: плавный шум 0..1, острее к пику
	var g := clampf(_noise.get_noise_1d(_t) * 1.6 + 0.5, 0.0, 1.0)
	g = g * g
	_boost = move_toward(_boost, 0.0, _boost_decay * delta)
	var power := clampf(intensity + gust_strength * g + _boost, 0.0, 1.0)
	var s := slant - gust_slant * g

	# Пелена — с запасом за края вида
	_sheet.scale = _view * 1.25
	_sheet_mat.set_shader_parameter("cam_pos", global_position)
	_sheet_mat.set_shader_parameter("view_half", _view * 0.5)
	_sheet_mat.set_shader_parameter("density", 0.12 + 0.38 * power)
	_sheet_mat.set_shader_parameter("slant", s)
	_sheet_mat.set_shader_parameter("rain_color", rain_color)
	_sheet_mat.set_shader_parameter("strength", sheet_strength)

	# Капли рождаются по всему виду (+ запас против ветра)
	var dir := Vector2(s, 1.0).normalized()
	for pm in [_drops_pm, _big_pm]:
		pm.direction = Vector3(dir.x, dir.y, 0.0)
		pm.emission_box_extents = Vector3(_view.x * 0.6, _view.y * 0.6, 0.0)
	# Касания земли — по всему виду, чуть с запасом
	for p in [_ripples, _crowns]:
		(p.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(_view.x * 0.55, _view.y * 0.55, 0.0)
	_ripples.amount_ratio = clampf(0.3 + 0.7 * power, 0.0, 1.0)
	_crowns.amount_ratio = clampf(power * power, 0.0, 1.0)
	_drops.amount_ratio = clampf(0.35 + 0.65 * power, 0.0, 1.0)
	_big.amount_ratio = clampf(power * power, 0.0, 1.0)


func _make_particles(amount: int, life: float, tex: Texture2D, z: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.texture = tex
	p.z_as_relative = false
	p.z_index = z
	p.visibility_rect = Rect2(-1200, -900, 2400, 1800)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(400, 300, 0)
	pm.spread = 0.0
	p.process_material = pm
	add_child(p)
	return p


## Штрих капли: тонкий, с яркой головой и тающим хвостом (вдоль оси y)
func _streak_tex() -> Texture2D:
	var img := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		var a := pow(float(y + 1) / 14.0, 1.6)
		for x in 2:
			img.set_pixel(x, y, Color(1, 1, 1, a * (1.0 if x == 0 else 0.55)))
	return ImageTexture.create_from_image(img)


## Колечко на земле: эллипс (3/4 вид), тонкий обод
func _ripple_tex() -> Texture2D:
	var img := Image.create(RIPPLE_W, RIPPLE_H, false, Image.FORMAT_RGBA8)
	var c := Vector2(RIPPLE_W, RIPPLE_H) * 0.5
	for y in RIPPLE_H:
		for x in RIPPLE_W:
			var d := Vector2((x + 0.5 - c.x) / c.x, (y + 0.5 - c.y) / c.y).length()
			var a := clampf(1.0 - absf(d - 0.78) / 0.18, 0.0, 1.0)
			# Ближний (нижний) край обода ярче — свет снизу-сверху
			a *= 0.7 + 0.3 * float(y) / RIPPLE_H
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _dot_tex() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.9))
	return ImageTexture.create_from_image(img)


func _white_tex() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


## Внешний порыв (удар молнии рядом, directional_light_2d.gd): дождь на time
## секунд сильнее на amount и плавно возвращается
func boost(amount: float, time: float) -> void:
	_boost = maxf(_boost, amount)
	_boost_decay = _boost / maxf(time, 0.1)
