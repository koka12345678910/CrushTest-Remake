extends RefCounted
## druid_fx.gd — общие кусочки эффектов заклинаний Сольвейг: та же техника,
## что у Эйрика (mage_fx.gd — его текстуры частиц и шейдеры берутся отсюда же),
## но своя палитра — светло-зелёная живая сила: белёсо-салатовое ядро →
## светло-зелёный → сочная зелень к краю. Плюс то, чего у мага нет: листья,
## пыльца и комья земли.
## Только статические функции:
##   const DruidFx := preload("res://Player_scene/druid_fx.gd")

const MageFx := preload("res://Player_scene/mage_fx.gd")
const CIRCLE_SHADER := preload("res://Shaders/magic_circle.gdshader")

const CORE := Color(0.93, 1.0, 0.84)
const MID := Color(0.62, 1.0, 0.42)
const EDGE := Color(0.3, 0.84, 0.24)
const DEEP := Color(0.1, 0.4, 0.1)
## Свет на карте — чуть теплее чистого зелёного, чтобы трава вокруг светилась
const LIGHT := Color(0.58, 1.0, 0.45)
const MIST := Color(0.16, 0.3, 0.12)
const DIRT := Color(0.24, 0.17, 0.1)
const BARK := Color(0.42, 0.3, 0.17)
const LEAF := Color(0.5, 0.86, 0.3)

static var _leaf: ImageTexture
static var _white: ImageTexture


## Квадрат 4x4 — холст для шейдеров (как у мага)
static func white() -> ImageTexture:
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


## Лист: заострённый овал с прожилкой, белый (цвет — из color_ramp частиц)
static func leaf() -> ImageTexture:
	if _leaf == null:
		var w := 10
		var h := 6
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in w:
			var u := (x + 0.5) / w
			# Ширина листа вдоль оси: ноль на концах, максимум ближе к черенку
			var half := sin(PI * pow(u, 0.8)) * h * 0.5
			for y in h:
				var dy := absf(y + 0.5 - h * 0.5)
				if dy <= half:
					var vein := 0.82 if dy < 0.6 else 1.0
					img.set_pixel(x, y, Color(vein, vein, vein, 1.0 if dy < half - 0.5 else 0.6))
		_leaf = ImageTexture.create_from_image(img)
	return _leaf


static func holder(tree: SceneTree, at: Vector2, life: float, z := 11) -> Node2D:
	return MageFx.holder(tree, at, life, z)


## Вспышка — светло-зелёная
static func flash(parent: Node, size: float, time: float, col := CORE) -> void:
	MageFx.flash(parent, size, time, col)


## Зелёный свет на карте: вспыхивает и гаснет
static func light_pulse(parent: Node, radius: float, energy: float, time: float, col := LIGHT) -> void:
	MageFx.light_pulse(parent, radius, energy, time, col)


## Постоянный свет (держит тот, кто его создал; гасить — fade_light)
static func light(parent: Node, radius: float, energy: float, col := LIGHT) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = MageFx.radial()
	l.texture_scale = radius * 2.0 / 128.0
	l.color = col
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	parent.add_child(l)
	return l


static func ramp_glow(alpha_mid := 0.9) -> GradientTexture1D:
	return MageFx.ramp([Color(CORE, 1.0), Color(MID, alpha_mid), Color(EDGE, 0.0)])


## Искры-штрихи (как у мага), зелёные
static func sparks(parent: Node, amount: int, speed: float, life: float, dir := Vector2.ZERO, spread := 180.0) -> void:
	MageFx.burst(parent, amount, life, MageFx.streak(), func(pm: ParticleProcessMaterial):
		pm.particle_flag_align_y = true
		pm.direction = Vector3(dir.x, dir.y, 0) if dir != Vector2.ZERO else Vector3(1, 0, 0)
		pm.spread = spread
		pm.initial_velocity_min = speed * 0.45
		pm.initial_velocity_max = speed
		pm.damping_min = speed * 1.2
		pm.damping_max = speed * 2.2
		pm.gravity = Vector3(0, 60, 0)
		pm.scale_min = 0.2
		pm.scale_max = 0.42
		pm.color_ramp = ramp_glow())


## Пыльца: светящиеся точки медленно поднимаются, кружат и гаснут
static func pollen(parent: Node, amount: int, area: float, life := 1.4, rise := 30.0) -> GPUParticles2D:
	return MageFx.burst(parent, amount, life, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = area
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 40.0
		pm.initial_velocity_min = rise * 0.3
		pm.initial_velocity_max = rise
		pm.gravity = Vector3(0, -12, 0)
		pm.damping_min = 6.0
		pm.damping_max = 14.0
		pm.scale_min = 0.6
		pm.scale_max = 1.5
		pm.scale_curve = MageFx.size_curve(0.25)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.4
		pm.turbulence_noise_scale = 3.0
		pm.color_ramp = MageFx.ramp([Color(CORE, 1.0), Color(MID, 0.9), Color(EDGE, 0.0)], [0.0, 0.35, 1.0]))


## Листья: разлетаются, кружатся и падают. Не аддитивные — это вещество, а не
## свет; без освещения сцены, чтобы ночью их было видно
static func leaves(parent: Node, amount: int, speed: float, life := 1.0, dir := Vector2.ZERO, spread := 180.0) -> GPUParticles2D:
	return MageFx.burst(parent, amount, life, leaf(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(dir.x, dir.y, 0) if dir != Vector2.ZERO else Vector3(0, -1, 0)
		pm.spread = spread
		pm.initial_velocity_min = speed * 0.4
		pm.initial_velocity_max = speed
		pm.damping_min = speed * 0.8
		pm.damping_max = speed * 1.6
		pm.gravity = Vector3(0, 40, 0)
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -360.0
		pm.angular_velocity_max = 360.0
		pm.scale_min = 0.7
		pm.scale_max = 1.2
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
		pm.color_ramp = MageFx.ramp([Color(MID, 1.0), Color(LEAF, 0.95), Color(DEEP, 0.0)], [0.0, 0.6, 1.0])
	, false)


## Комья земли: вылетают из-под корней и падают обратно
static func dirt(parent: Node, amount: int, speed: float, life := 0.6) -> void:
	MageFx.burst(parent, amount, life, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 55.0
		pm.initial_velocity_min = speed * 0.4
		pm.initial_velocity_max = speed
		pm.gravity = Vector3(0, 380, 0)
		pm.scale_min = 0.7
		pm.scale_max = 1.6
		pm.color_ramp = MageFx.ramp([Color(DIRT, 1.0), Color(DIRT, 0.9), Color(DIRT, 0.0)], [0.0, 0.7, 1.0])
	, false)


## Зелёная дымка-сияние: мягкие пятна, светятся и тают
static func haze(parent: Node, amount: int, area: float, size: float, life := 0.9) -> void:
	var p := MageFx.burst(parent, amount, life, MageFx.soft(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = area
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 16.0
		pm.gravity = Vector3(0, -8, 0)
		pm.scale_min = size * 0.6 / 64.0
		pm.scale_max = size / 64.0
		pm.scale_curve = MageFx.size_curve(0.3)
		pm.angle_max = 360.0
		pm.color_ramp = MageFx.ramp([Color(EDGE, 0.0), Color(EDGE, 0.3), Color(DEEP, 0.0)], [0.0, 0.25, 1.0]))
	p.explosiveness = 0.8


## Рунный круг на земле (шейдер мага magic_circle, перекрашенный). Возвращает
## материал — draw/fade/intensity крутит вызывающий
static func circle(parent: Node, diameter: float, spin := 0.8, z := -16) -> ShaderMaterial:
	var s := Sprite2D.new()
	s.texture = white()
	s.z_as_relative = false
	s.z_index = z
	s.scale = Vector2(diameter, diameter * 0.62) / 4.0
	var m := ShaderMaterial.new()
	m.shader = CIRCLE_SHADER
	m.set_shader_parameter("color_core", CORE)
	m.set_shader_parameter("color_edge", EDGE)
	m.set_shader_parameter("seed", randf() * 10.0)
	m.set_shader_parameter("draw", 0.0)
	m.set_shader_parameter("fade", 1.0)
	m.set_shader_parameter("intensity", 1.2)
	m.set_shader_parameter("spin", spin)
	s.material = m
	parent.add_child(s)
	return m


## Облако Целебных спор у ног того, кого лечат: круг, вихрь светящейся пыльцы
## вверх по телу, свет (druid.gd::_start_spores; в коопе — и эхом у других)
static func spores_burst(tree: SceneTree, feet: Vector2) -> void:
	var h := holder(tree, feet, 2.2, 12)
	var c := circle(h, 54.0, 2.0)
	var t := h.create_tween()
	t.tween_method(func(v: float): c.set_shader_parameter("draw", v), 0.0, 1.0, 0.25)
	t.tween_interval(0.6)
	t.tween_method(func(v: float): c.set_shader_parameter("fade", v), 1.0, 0.0, 0.6)
	flash(h, 44.0, 0.25)
	light_pulse(h, 80.0, 2.0, 0.8)
	var up := Node2D.new()
	up.position = Vector2(0, -16)
	h.add_child(up)
	pollen(up, 30, 12.0, 1.3, 55.0)
	leaves(up, 6, 50.0, 1.0)
	haze(up, 6, 10.0, 40.0, 1.0)


## Вспышка попадания: зелёный всплеск, искры, пара листьев и свет
static func hit_burst(tree: SceneTree, at: Vector2, dir: Vector2) -> void:
	var h := holder(tree, at + Vector2(0, -10), 1.0, 12)
	flash(h, 26.0, 0.14)
	sparks(h, 10, 110.0, 0.35, dir, 60.0)
	leaves(h, 4, 70.0, 0.7, dir, 70.0)
	light_pulse(h, 44.0, 1.5, 0.28)
