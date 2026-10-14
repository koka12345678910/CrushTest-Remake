extends RefCounted
## mage_fx.gd — общие кусочки эффектов заклинаний мага (огненный шар,
## пелена, импульс): текстуры частиц, вспышки, искры, дым, ожог на земле.
## Только статические функции — подключается как
## const MageFx := preload("res://Player_scene/mage_fx.gd")
##
## Палитра у всех заклинаний одна — холодная синяя магия: белое ядро →
## голубой → глубокий синий к краю.

const CORE := Color(0.88, 0.96, 1.0)
const MID := Color(0.42, 0.72, 1.0)
const EDGE := Color(0.14, 0.32, 1.0)
const SMOKE := Color(0.14, 0.17, 0.27)
## Прямоугольник видимости частиц (см. burst) — с запасом под большую волну
const VIS_RECT := Rect2(-400, -400, 800, 800)

static var _dot: GradientTexture2D
static var _soft: GradientTexture2D
static var _streak: GradientTexture2D
static var _radial: GradientTexture2D
static var _noise: ImageTexture


## Гладкий бесшовный шум для шейдеров заклинаний (magic_pulse и др.).
## Генерится синхронно один раз: NoiseTexture2D строится в фоновом потоке, и
## первое заклинание успело бы нарисоваться с пустой текстурой
static func noise_tex() -> ImageTexture:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		n.seed = 1337
		var img := n.get_seamless_image(256, 256)
		_noise = ImageTexture.create_from_image(img)
	return _noise


## Аддитивный материал без освещения — свечение не темнеет ночью
static func add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


## Маленькая круглая точка — искры, угли
static func dot() -> GradientTexture2D:
	if _dot == null:
		_dot = _radial_tex(8, [0.0, 0.5, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	return _dot


## Большое мягкое пятно — дым, дымка, ореолы
static func soft() -> GradientTexture2D:
	if _soft == null:
		_soft = _radial_tex(64, [0.0, 0.5, 1.0], [Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	return _soft


## Вытянутая искра-штрих: частица с align_y вытягивается по полёту
static func streak() -> GradientTexture2D:
	if _streak == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
		_streak = GradientTexture2D.new()
		_streak.gradient = g
		_streak.fill = GradientTexture2D.FILL_RADIAL
		_streak.fill_from = Vector2(0.5, 0.5)
		_streak.fill_to = Vector2(0.5, 0.0)
		_streak.width = 12
		_streak.height = 48
	return _streak


## Текстура света PointLight2D
static func radial() -> GradientTexture2D:
	if _radial == null:
		_radial = _radial_tex(128, [0.0, 0.4, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	return _radial


static func _radial_tex(size: int, offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	return t


static func ramp(colors: Array, offsets := [0.0, 0.45, 1.0]) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Кривая размера частицы: вырастает и сходит на нет
static func size_curve(peak_at := 0.2) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(peak_at, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


## Узел-контейнер эффекта в мире (не на заклинании — то может исчезнуть
## раньше, чем доиграет эффект). Сам удаляется через life секунд
static func holder(tree: SceneTree, at: Vector2, life: float, z := 11) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	var root := tree.current_scene if tree.current_scene else tree.root
	root.add_child(n)
	n.global_position = at
	tree.create_timer(life).timeout.connect(n.queue_free)
	return n


## Разовый выброс частиц
static func burst(parent: Node, amount: int, life: float, tex: Texture2D, setup: Callable, additive := true) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.texture = tex
	# Свет сцены на частицы считается только в пределах visibility_rect: пыль,
	# улетевшая за него, резко темнела по прямой границе. Поэтому прямоугольник
	# с запасом, а дым и пыль — без освещения вообще (свой ночной цвет)
	p.visibility_rect = VIS_RECT
	if additive:
		p.material = add_material()
	else:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = m
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.gravity = Vector3.ZERO
	setup.call(pm)
	p.process_material = pm
	parent.add_child(p)
	p.emitting = true
	return p


## Вспышка: яркое пятно, которое мгновенно раздувается и гаснет
static func flash(parent: Node, size: float, time: float, col := CORE) -> void:
	var s := Sprite2D.new()
	s.texture = soft()
	s.material = add_material()
	s.modulate = Color(col.r * 1.6, col.g * 1.6, col.b * 1.8, 1.0)
	s.scale = Vector2.ONE * size * 0.3 / 64.0
	parent.add_child(s)
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * size / 64.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(s, "modulate:a", 0.0, time * 1.4).set_ease(Tween.EASE_IN)


## Свет, который вспыхивает и плавно гаснет
static func light_pulse(parent: Node, radius: float, energy: float, time: float, col := MID) -> void:
	var l := PointLight2D.new()
	l.texture = radial()
	l.texture_scale = radius * 2.0 / 128.0
	l.color = col
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	parent.add_child(l)
	l.create_tween().tween_property(l, "energy", 0.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Искры-штрихи во все стороны (или конусом вокруг dir)
static func sparks(parent: Node, amount: int, speed: float, life: float, dir := Vector2.ZERO, spread := 180.0) -> void:
	burst(parent, amount, life, streak(), func(pm: ParticleProcessMaterial):
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
		pm.color_ramp = ramp([Color(CORE, 1.0), Color(MID, 0.9), Color(EDGE, 0.0)]))


## Угольки: медленно поднимаются, мерцают и гаснут
static func embers(parent: Node, amount: int, area: float, life := 1.1) -> void:
	burst(parent, amount, life, dot(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = area
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 35.0
		pm.initial_velocity_min = 10.0
		pm.initial_velocity_max = 32.0
		pm.gravity = Vector3(0, -18, 0)
		pm.damping_min = 8.0
		pm.damping_max = 18.0
		pm.scale_min = 0.7
		pm.scale_max = 1.6
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.0
		pm.turbulence_noise_scale = 3.0
		pm.color_ramp = ramp([Color(CORE, 1.0), Color(MID, 0.9), Color(EDGE, 0.0)], [0.0, 0.3, 1.0]))


## Дым/дымка: мягкие пятна, расплываются и тают. Не аддитивные — иначе дым
## светился бы, а он должен лишь чуть затуманивать
static func smoke(parent: Node, amount: int, area: float, size: float, life := 0.9) -> void:
	var p := burst(parent, amount, life, soft(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = area
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 8.0
		pm.initial_velocity_max = 26.0
		pm.damping_min = 10.0
		pm.damping_max = 20.0
		pm.gravity = Vector3(0, -10, 0)
		pm.scale_min = size * 0.6 / 64.0
		pm.scale_max = size / 64.0
		pm.scale_curve = size_curve(0.35)
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.color_ramp = ramp([Color(SMOKE, 0.0), Color(SMOKE, 0.32), Color(SMOKE, 0.0)], [0.0, 0.2, 1.0]), false)
	p.explosiveness = 0.8


## Вспышка удара по врагу: короткий всплеск света и искры от точки удара
static func hit_burst(tree: SceneTree, at: Vector2, dir: Vector2) -> void:
	var h := holder(tree, at + Vector2(0, -10), 0.8, 12)
	flash(h, 26.0, 0.14)
	sparks(h, 12, 110.0, 0.35, dir, 60.0)
	light_pulse(h, 40.0, 1.4, 0.25)
