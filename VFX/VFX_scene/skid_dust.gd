extends RefCounted
## skid_dust.gd — пыль из-под ног героя на резкой остановке, развороте и
## рывке с места. Только статические функции:
##   const SkidDust := preload("res://VFX/VFX_scene/skid_dust.gd")
##   SkidDust.skid(get_tree(), feet, dir, SkidDust.Kind.STOP, power)
##
## Всё процедурное, без спрайт-листов: как у остальных эффектов игры
## (MageFx, KnightFx) — частицы, а не заранее нарисованный дым. Из четырёх слоёв:
##   1. вал — плотные клубы с рваным краем катятся по земле в сторону dir,
##      сплющены по вертикали (земля, а не облако в воздухе), растут и тают;
##   2. дымка — пара крупных медленных пятен, дают объём позади вала;
##   3. крошка — мелкие комки земли, бьют низко и быстро осаживаются;
##   4. царапина — два тонких тёмных следа подошв, лежат на земле и тают.
## Пыль не светится и не зависит от света сцены: цвет подобран тёмным,
## землистым, под палитру уровней — ночью не вспыхивает.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const DebrisScript := preload("res://VFX/VFX_scene/debris_spray.gd")

## STOP — резкая остановка с бега: пыль уходит вперёд по инерции.
## TURN — разворот: тот же вал, плюс короткий выброс назад (носок упёрся).
## START — рывок с места: лёгкая пыль назад из-под ног, без царапины.
enum Kind { STOP, TURN, START }

## Землистый серо-коричневый, теплее к центру и темнее к краю клуба
const DUST := Color(0.46, 0.4, 0.33)
const DUST_DARK := Color(0.18, 0.15, 0.13)
const GRIT := Color(0.42, 0.36, 0.30)
## Сплющивание по вертикали — вид на землю сверху под углом
const GROUND_SQUASH := 0.58

static var _puff: ImageTexture
static var _growth: CurveTexture

## Сколько вариантов клуба в атласе puff() (кадры в ряд)
const PUFF_VARIANTS := 4
const PUFF_SIZE := 64
## Откуда свет на клубах (сверху-слева, как свет мира на героях)
const LIGHT_DIR := Vector2(-0.55, -0.83)


## Клубы пыли — атлас из PUFF_VARIANTS разных клубов в ряд. Каждый клуб
## собран из нескольких «долей» (как цветная капуста): у каждой доли своя
## светлая сторона к свету и тень с другой — клуб объёмный, а не плоская
## клякса. Край рвёт шум, внутри мелкое зерно. Цвет в текстуре — только
## светотень (белый…серый): сам цвет пыли задаёт color_ramp частиц.
## Частица берёт случайный вариант (_atlas) — клубы не повторяются
static func puff() -> ImageTexture:
	if _puff == null:
		var edge_n := FastNoiseLite.new()
		edge_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		edge_n.fractal_type = FastNoiseLite.FRACTAL_FBM
		edge_n.fractal_octaves = 3
		edge_n.frequency = 0.09
		var grain := FastNoiseLite.new()
		grain.noise_type = FastNoiseLite.TYPE_VALUE
		grain.frequency = 0.45
		var s := PUFF_SIZE
		var img := Image.create(s * PUFF_VARIANTS, s, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9137
		for v in PUFF_VARIANTS:
			edge_n.seed = 4242 + v * 31
			grain.seed = 77 + v
			# Доли: центр (в долях стороны) и радиус. Первая — основная
			var lobes := [[Vector2(0.5, 0.54), 0.27]]
			var count := rng.randi_range(4, 6)
			for i in count:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.1, 0.2)
				lobes.append([Vector2(0.5, 0.52) + Vector2(cos(a), sin(a) * 0.85) * r, rng.randf_range(0.13, 0.21)])
			for y in s:
				for x in s:
					var uv := Vector2((x + 0.5) / s, (y + 0.5) / s)
					# Плотность — самая «глубокая» доля; её же нормаль даёт свет
					var best := 0.0
					var best_n := Vector2.ZERO
					for lb in lobes:
						var c: Vector2 = lb[0]
						var rr: float = lb[1]
						var d := (uv - c) / rr
						var k := 1.0 - d.length()
						if k > best:
							best = k
							best_n = d
					var nv := edge_n.get_noise_2d(x + v * 97, y) * 0.5 + 0.5
					# Рваный край: порог плотности гуляет по шуму
					var a := smoothstep(0.0, 0.45, best - (nv - 0.5) * 0.5)
					# Мелкое зерно внутри — пыль, а не вата
					a *= 0.78 + 0.22 * (grain.get_noise_2d(x + v * 53, y) * 0.5 + 0.5)
					# Светотень доли: сторона к свету светлее, обратная — в тень,
					# в середине доли — мягкий объём
					var nrm := best_n.normalized() if best_n.length() > 0.001 else Vector2.ZERO
					var lit := clampf(-nrm.dot(LIGHT_DIR) * (1.0 - best), -1.0, 1.0)
					var shade := clampf(0.74 + 0.26 * lit + 0.1 * best, 0.45, 1.0)
					img.set_pixel(v * s + x, y, Color(shade, shade, shade * 0.97, clampf(a, 0.0, 1.0)))
		_puff = ImageTexture.create_from_image(img)
	return _puff


## Частицы с puff() — каждая берёт случайный клуб из атласа (кадр анимации
## частицы, сама анимация стоит)
static func _atlas(p: GPUParticles2D) -> void:
	var m := p.material as CanvasItemMaterial
	if m == null:
		m = CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		p.material = m
	m.particles_animation = true
	m.particles_anim_h_frames = PUFF_VARIANTS
	m.particles_anim_v_frames = 1
	m.particles_anim_loop = false
	var pm := p.process_material as ParticleProcessMaterial
	if pm:
		pm.anim_offset_min = 0.0
		pm.anim_offset_max = 1.0
		pm.anim_speed_min = 0.0
		pm.anim_speed_max = 0.0


## Клуб раздаётся вширь по мере жизни: 0.45 → 1.25 (а не сужается, как
## size_curve мага — пыль оседает, растекаясь)
static func growth() -> CurveTexture:
	if _growth == null:
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.45), 0.0, 2.6)
		c.add_point(Vector2(0.35, 0.95))
		c.add_point(Vector2(1.0, 1.25))
		_growth = CurveTexture.new()
		_growth.curve = c
	return _growth


## feet — точка у ног в мировых координатах. dir — КУДА летит пыль (вперёд по
## инерции на остановке/развороте, назад на старте). power ~0.6..1.3 — от
## скорости, с которой гасили ход
static func skid(tree: SceneTree, feet: Vector2, dir: Vector2, kind: int = Kind.STOP, power := 1.0) -> void:
	if tree == null or dir.length() < 0.01:
		return
	dir = dir.normalized()
	power = clampf(power, 0.5, 1.4)
	var holder := MageFx.holder(tree, feet, 1.8, 11)

	var strength := 0.62 if kind == Kind.START else 1.0
	var s := power * strength

	# Вал: основной клубящийся край пыли
	_billow(holder, dir, int(8 + 8 * s), 40.0, 110.0 + 120.0 * s, 0.5 + 0.2 * s, 0.95, 0.68)
	# Разворот: носок упёрся — маленький встречный выброс назад
	if kind == Kind.TURN:
		_billow(holder, -dir, int(4 + 3 * s), 55.0, 60.0 + 40.0 * s, 0.38, 0.75, 0.55)
	# Дымка: пара крупных медленных пятен для объёма, чтобы вал не выглядел
	# пригоршней одинаковых кружков
	_haze(holder, dir, 3 + int(s * 2.0), 0.95 + 0.35 * s)
	# Крошка: мелкие комки, низко и быстро
	_grit(holder, dir, int(6 + 6 * s), 110.0 + 90.0 * s)

	if kind != Kind.START:
		_scuff(tree, feet, dir, 15.0 + 12.0 * s)


## Клубы, катящиеся вдоль земли: быстро стартуют, сильно тормозятся
## (damping) — отсюда «подушка» пыли, а не взрыв
static func _billow(parent: Node, dir: Vector2, amount: int, spread: float, speed: float,
		size: float, life: float, alpha: float) -> void:
	var p := MageFx.burst(parent, amount, life, puff(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 5.0
		pm.direction = Vector3(dir.x, dir.y, 0)
		pm.spread = spread
		pm.initial_velocity_min = speed * 0.4
		pm.initial_velocity_max = speed
		pm.damping_min = speed * 1.25
		pm.damping_max = speed * 2.0
		# Лёгкий подъём: клубы чуть всплывают, пока тают
		pm.gravity = Vector3(0, -16, 0)
		pm.scale_min = size * 0.65
		pm.scale_max = size
		pm.scale_curve = growth()
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -45.0
		pm.angular_velocity_max = 45.0
		pm.color_ramp = MageFx.ramp([Color(DUST, 0.0), Color(DUST, alpha), Color(DUST_DARK, 0.0)], [0.0, 0.16, 1.0]),
		false)
	_atlas(p)
	p.explosiveness = 0.7
	p.scale = Vector2(1.0, GROUND_SQUASH)


## Крупные редкие пятна: медленно расходятся и держатся дольше вала
static func _haze(parent: Node, dir: Vector2, amount: int, size: float) -> void:
	var p := MageFx.burst(parent, amount, 1.25, puff(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 6.0
		pm.direction = Vector3(dir.x, dir.y, 0)
		pm.spread = 70.0
		pm.initial_velocity_min = 18.0
		pm.initial_velocity_max = 48.0
		pm.damping_min = 14.0
		pm.damping_max = 24.0
		pm.gravity = Vector3(0, -9, 0)
		pm.scale_min = size * 0.8
		pm.scale_max = size * 1.15
		pm.scale_curve = growth()
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -18.0
		pm.angular_velocity_max = 18.0
		pm.color_ramp = MageFx.ramp([Color(DUST, 0.0), Color(DUST, 0.3), Color(DUST_DARK, 0.0)], [0.0, 0.25, 1.0]),
		false)
	_atlas(p)
	p.explosiveness = 0.6
	p.scale = Vector2(1.0, GROUND_SQUASH)


## Комья земли: короткие, остаются тёмными до конца и падают вниз
static func _grit(parent: Node, dir: Vector2, amount: int, speed: float) -> void:
	MageFx.burst(parent, amount, 0.42, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(dir.x, dir.y - 0.55, 0)
		pm.spread = 42.0
		pm.initial_velocity_min = speed * 0.35
		pm.initial_velocity_max = speed
		pm.damping_min = speed * 0.7
		pm.damping_max = speed * 1.3
		pm.gravity = Vector3(0, 330, 0)
		pm.scale_min = 0.4
		pm.scale_max = 0.85
		pm.color_ramp = MageFx.ramp([Color(GRIT, 0.9), Color(DUST_DARK, 0.7), Color(DUST_DARK, 0.0)], [0.0, 0.6, 1.0]),
		false)


## Тяжёлый удар о землю (вихрь рыцаря): пыль встаёт стеной. Три слоя:
##   1. кольцо — плотные клубы разбегаются от центра во все стороны по земле,
##      сплюснутые, тяжёлые, с сильным торможением;
##   2. столп — крупные клубы вверх из центра: поднимаются, раздаются вширь и
##      висят дольше всего — «грибок» от удара;
##   3. крошка — комья земли и камешки летят вверх веером и падают.
## feet — точка у ног, radius — до куда дойдёт кольцо, power ~1 — как у вихря
static func slam(tree: SceneTree, feet: Vector2, radius: float, power := 1.0) -> void:
	if tree == null:
		return
	var holder := MageFx.holder(tree, feet, 2.0, 11)
	# 1. Кольцо: клубы наружу в 360°
	var ring := MageFx.burst(holder, int(26 * power), 1.1, puff(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3(0, 0, 1)
		pm.emission_ring_radius = radius * 0.22
		pm.emission_ring_inner_radius = radius * 0.1
		pm.emission_ring_height = 0.0
		pm.direction = Vector3(1, 0, 0)
		pm.spread = 180.0
		# Радиальная скорость от центра — кольцо расходится ровно, а не веером
		pm.radial_velocity_min = radius * 1.4
		pm.radial_velocity_max = radius * 2.1
		pm.damping_min = radius * 1.4
		pm.damping_max = radius * 2.2
		pm.gravity = Vector3(0, -10, 0)
		pm.scale_min = 0.4 * power
		pm.scale_max = 0.7 * power
		pm.scale_curve = growth()
		pm.angle_max = 360.0
		pm.angular_velocity_min = -30.0
		pm.angular_velocity_max = 30.0
		pm.color_ramp = MageFx.ramp([Color(DUST, 0.0), Color(DUST, 0.78), Color(DUST_DARK, 0.0)], [0.0, 0.14, 1.0]),
		false)
	_atlas(ring)
	ring.explosiveness = 0.85
	ring.scale = Vector2(1.0, GROUND_SQUASH)
	# 2. Столп: клубы вверх из центра. Не сплюснутые — это объём в воздухе
	var col := MageFx.burst(holder, int(12 * power), 1.45, puff(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.16
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 38.0
		pm.initial_velocity_min = 55.0 * power
		pm.initial_velocity_max = 120.0 * power
		pm.damping_min = 40.0
		pm.damping_max = 75.0
		pm.gravity = Vector3(0, -8, 0)
		pm.scale_min = 0.6 * power
		pm.scale_max = 1.0 * power
		pm.scale_curve = growth()
		pm.angle_max = 360.0
		pm.angular_velocity_min = -20.0
		pm.angular_velocity_max = 20.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.2
		pm.turbulence_noise_scale = 2.0
		pm.color_ramp = MageFx.ramp([Color(DUST, 0.0), Color(DUST, 0.62), Color(DUST_DARK, 0.0)], [0.0, 0.2, 1.0]),
		false)
	_atlas(col)
	col.explosiveness = 0.6
	# 3. Крошка: мелкие тёмные комья веером вверх, падают
	MageFx.burst(holder, int(16 * power), 0.7, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.2
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 75.0
		pm.initial_velocity_min = 110.0
		pm.initial_velocity_max = 260.0
		pm.damping_min = 30.0
		pm.damping_max = 70.0
		pm.gravity = Vector3(0, 520, 0)
		pm.scale_min = 0.45
		pm.scale_max = 1.0
		pm.color_ramp = MageFx.ramp([Color(GRIT, 1.0), Color(DUST_DARK, 0.85), Color(DUST_DARK, 0.0)], [0.0, 0.6, 1.0]),
		false)
	# 4. Камни: настоящие обломки с тенью, отскоком и вращением
	var root := tree.current_scene
	if root:
		var deb: Node2D = DebrisScript.new()
		deb.setup(int(20 * power), radius * 0.25, 40.0, 150.0 * power, 120.0, 300.0 * power)
		root.add_child(deb)
		deb.global_position = feet
	# 5. Вал: стена пыли бежит от центра чётким фронтом
	_dust_wall(tree, feet, radius, power)
	# 6. Пыль на земле: осевшее пятно под ударом, медленно тает
	_ground_patch(tree, feet, radius * 0.95)
	# 7. Пылинки: мелкая взвесь висит в воздухе и оседает, когда всё кончилось
	_motes(holder, radius, power)


## Стена пыли: кольцо клубов-спрайтов разом уходит от центра к краю удара,
## растёт и тает. Два ряда — передний быстрее, задний отстаёт — у вала есть
## толщина. Спрайты, а не частицы: у волны должен быть чёткий фронт
static func _dust_wall(tree: SceneTree, feet: Vector2, radius: float, power: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var n := Node2D.new()
	n.z_index = 11
	root.add_child(n)
	n.global_position = feet
	var tex := puff()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var count := int(22 * power)
	for row in 2:
		var speed_k := 1.0 if row == 0 else 0.72
		for i in count:
			var a := TAU * (i + randf_range(-0.3, 0.3)) / count
			var dir := Vector2(cos(a), sin(a) * GROUND_SQUASH)
			var s := Sprite2D.new()
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((randi() % PUFF_VARIANTS) * PUFF_SIZE, 0, PUFF_SIZE, PUFF_SIZE)
			s.texture = at
			s.material = mat
			s.rotation = randf() * TAU
			var base_scale := randf_range(0.28, 0.42) * power * (1.0 if row == 0 else 1.25)
			s.scale = Vector2(base_scale, base_scale * 0.8) * 0.5
			s.position = dir * radius * 0.12
			var col := DUST.lerp(DUST_DARK, randf_range(0.0, 0.35))
			s.modulate = Color(col, 0.0)
			n.add_child(s)
			var life := randf_range(0.55, 0.8) / speed_k
			var t := s.create_tween().set_parallel(true)
			t.tween_property(s, "position", dir * radius * randf_range(0.95, 1.12) * speed_k, life) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			t.tween_property(s, "scale", Vector2(base_scale, base_scale * 0.85) * 1.6, life * 1.4).set_ease(Tween.EASE_OUT)
			t.tween_property(s, "rotation", s.rotation + randf_range(-0.6, 0.6), life * 1.4)
			t.tween_property(s, "modulate:a", 0.85 if row == 0 else 0.6, 0.06)
			t.tween_property(s, "modulate:a", 0.0, life * 0.9).set_delay(life * 0.45).set_ease(Tween.EASE_IN)
	n.get_tree().create_timer(2.2).timeout.connect(n.queue_free)


## Осевшая пыль: светлое пятно на земле под ударом (под героями), проступает
## сразу и тает несколько секунд
static func _ground_patch(tree: SceneTree, feet: Vector2, radius: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = -15
	root.add_child(n)
	n.global_position = feet
	n.scale = Vector2(1.0, GROUND_SQUASH)
	var s := Sprite2D.new()
	s.texture = MageFx.soft()
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	s.scale = Vector2.ONE * radius * 2.0 / 64.0 * 0.6
	s.modulate = Color(DUST.lightened(0.15), 0.0)
	n.add_child(s)
	var t := n.create_tween()
	t.set_parallel(true)
	t.tween_property(s, "modulate:a", 0.32, 0.2)
	t.tween_property(s, "scale", Vector2.ONE * radius * 2.0 / 64.0, 0.5).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_interval(1.4)
	t.tween_property(s, "modulate:a", 0.0, 2.2)
	t.tween_callback(n.queue_free)


## Взвесь: мелкие пылинки медленно кружат и оседают ещё пару секунд после удара
static func _motes(parent: Node, radius: float, power: float) -> void:
	var p := MageFx.burst(parent, int(36 * power), 2.2, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.7
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 90.0
		pm.initial_velocity_min = 6.0
		pm.initial_velocity_max = 28.0
		pm.damping_min = 6.0
		pm.damping_max = 14.0
		pm.gravity = Vector3(0, 9, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.5
		pm.turbulence_noise_scale = 3.0
		pm.scale_min = 0.25
		pm.scale_max = 0.55
		pm.color_ramp = MageFx.ramp([Color(0.75, 0.66, 0.52, 0.0), Color(0.75, 0.66, 0.52, 0.55), Color(0.6, 0.52, 0.42, 0.0)], [0.0, 0.2, 1.0]),
		false)
	p.explosiveness = 0.5


## Две тонкие тёмные царапины подошв вдоль движения — лежат на земле под
## ногами и тают. Слой как у трещины (juice.gd::ground_crack): под героями
static func _scuff(tree: SceneTree, feet: Vector2, dir: Vector2, length: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = -15
	root.add_child(n)
	n.global_position = feet
	# Поперёк движения — сдвиг между левой и правой ногой (на земле сплюснут)
	var side := Vector2(-dir.y, dir.x)
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.2))
	taper.add_point(Vector2(0.25, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	for k in 2:
		var off := side * (-2.0 if k == 0 else 2.5) * GROUND_SQUASH
		var l := Line2D.new()
		var len := length * randf_range(0.8, 1.15)
		var pts := PackedVector2Array()
		# Слегка волнистая линия: подошва не скользит по линейке
		for i in 5:
			var t := i / 4.0
			pts.append(off + dir * (t * len - 3.0) + side * sin(t * 5.0 + k * 2.0) * 0.6)
		l.points = pts
		l.width = 2.2 if k == 0 else 1.6
		l.width_curve = taper
		l.default_color = Color(0.04, 0.03, 0.025, 0.4)
		l.antialiased = false
		n.add_child(l)
	var tw := n.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(n, "modulate:a", 0.0, 1.4)
	tw.tween_callback(n.queue_free)
