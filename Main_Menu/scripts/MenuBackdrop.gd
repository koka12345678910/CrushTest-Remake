extends Control
## MenuBackdrop.gd — живой фон главного меню: утёс с мечом в костре.
##
## Слои (Main_Menu/art, все одного размера IMG — сгенерированы по одной
## картинке и совпадают попиксельно), сзади вперёд:
##   bg_sky.png   — небо: медленно покачивается, облачные массы ползут,
##                  молния светит внутри облаков (menu_sky.gdshader);
##   bg_mid.png   — горы и море тумана: НЕПОДВИЖНЫ;
##   туман        — дымка и облака плывут между горами и скалой
##                  (menu_fog.gdshader, без картинки — из шумовой текстуры);
##   bg_front.png — скала с костром: свет огня мерцает (menu_front.gdshader);
##   огонь        — маленькое пламя у основания клинка (menu_flame.gdshader),
##                  тёплое пятно у углей, искры и отлетающие щепки.
##
## Всё лежит на «сцене» размером IMG, которая растягивается на экран с
## обрезкой краёв (как cover у фона сайта) — огонь и искры всегда точно над
## нарисованным костром на любом формате экрана. Огонь, искры и щепки — в
## отдельном слое fx (поверх цветокоррекции меню, чтобы не тускнели: это
## источники света), с тем же масштабом и сдвигом.

const SKY := preload("res://Main_Menu/art/bg_sky.png")
const MID := preload("res://Main_Menu/art/bg_mid.png")
const FRONT := preload("res://Main_Menu/art/bg_front.png")
const SKY_SHADER := preload("res://Main_Menu/assets/shaders/menu_sky.gdshader")
const FOG_SHADER := preload("res://Main_Menu/assets/shaders/menu_fog.gdshader")
const FRONT_SHADER := preload("res://Main_Menu/assets/shaders/menu_front.gdshader")
const FLAME_SHADER := preload("res://Main_Menu/assets/shaders/menu_flame.gdshader")

## Размер «сцены» и точка у основания меча, где горят угли (в пикселях слоёв
## 1671×941). Слои растягиваются на этот размер, поэтому их можно заменить
## увеличенными (Upscayl ×2 и т. п.) — координаты огня менять не нужно
const IMG := Vector2(1671, 941)
## Меч наклонён вправо — угли там, где клинок входит в пепел
const FIRE := Vector2(1311, 612)
## Прореха в облаках с луной на bg_sky.png (слева вверху)
const MOON := Vector2(230, 120)

var _stage: Control
var _fx: Control
var _sky_mat: ShaderMaterial
var _fog_mat: ShaderMaterial
var _front_mat: ShaderMaterial
var _flames: Array[ShaderMaterial] = []
## Яркость каждого языка: крайние маленькие у поленьев — тусклее
var _flame_k: Array[float] = []
var _glow: TextureRect
var _moon: TextureRect
var _sparks: Control
var _soft: GradientTexture2D

# ── мерцание огня ──
var _t := 0.0
var _flicker_noise := FastNoiseLite.new()
## Вспышка света, когда из костра вылетает щепка; гаснет сама
var _flare := 0.0
var _light := 1.0

# ── искры и щепки ──
var _parts: Array[Dictionary] = []
var _spark_acc := 0.0
var _next_pop := 3.0
var _spark_rate := 5.0
const MAX_PARTS := 180
## Ветер на утёсе: искры сносит влево, туда же плывёт туман. gust (0..1) —
## порыв, его задаёт MainMenu.gd вместе с громкостью ветра и травы
var gust := 0.5
var _wind := -12.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flicker_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_flicker_noise.frequency = 1.0
	_flicker_noise.seed = randi()
	var low: bool = GraphicsQuality.level() <= GraphicsQuality.LOW
	_spark_rate = 2.5 if low else 5.0
	_build_stage(low)


## Слой для огня и искр — поверх цветокоррекции (MainMenu передаёт EffectsLayer)
func setup_fx(layer: CanvasLayer) -> void:
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.size = IMG
	layer.add_child(_fx)
	_build_fire()
	_fit()


## Молния где-то в облаках: 0..1 (MainMenu твинит её вспышками)
func set_flash(v: float) -> void:
	if _sky_mat:
		_sky_mat.set_shader_parameter("flash", v)


func _build_stage(low: bool) -> void:
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = IMG
	add_child(_stage)

	# Одна шумовая текстура на небо, туман и пламя: бесшовная, мягкие облака
	var cloud_noise := _noise_texture(512, 0.0055, 5, 1337)

	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("noise_tex", cloud_noise)
	_sky_mat.set_shader_parameter("aspect", IMG.x / IMG.y)
	_layer(SKY, _sky_mat)

	# Лунный свет из прорехи в облаках: мягкое холодное сияние поверх неба,
	# за горами. «Дышит» — будто по луне проходят облака
	_moon = TextureRect.new()
	var mg := Gradient.new()
	mg.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	mg.colors = PackedColorArray([Color(0.75, 0.8, 0.9, 0.5), Color(0.6, 0.67, 0.8, 0.2), Color(0.5, 0.58, 0.72, 0.0)])
	var mgt := GradientTexture2D.new()
	mgt.gradient = mg
	mgt.fill = GradientTexture2D.FILL_RADIAL
	mgt.fill_from = Vector2(0.5, 0.5)
	mgt.fill_to = Vector2(1.0, 0.5)
	mgt.width = 256
	mgt.height = 256
	_moon.texture = mgt
	_moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_moon.stretch_mode = TextureRect.STRETCH_SCALE
	_moon.size = Vector2(1100, 760)
	_moon.position = MOON - _moon.size * 0.5
	_moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var madd := CanvasItemMaterial.new()
	madd.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_moon.material = madd
	_stage.add_child(_moon)

	_layer(MID, null)

	var fog := ColorRect.new()
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.size = IMG
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FOG_SHADER
	_fog_mat.set_shader_parameter("noise_tex", cloud_noise)
	# Мелкий шум — рваные края облаков и детали внутри
	_fog_mat.set_shader_parameter("detail_tex", _noise_texture(512, 0.022, 4, 777))
	_fog_mat.set_shader_parameter("aspect", IMG.x / IMG.y)
	_fog_mat.set_shader_parameter("fire_uv", FIRE / IMG)
	_fog_mat.set_shader_parameter("quality", 0 if low else 2)
	fog.material = _fog_mat
	_stage.add_child(fog)

	_front_mat = ShaderMaterial.new()
	_front_mat.shader = FRONT_SHADER
	_front_mat.set_shader_parameter("light_pos", FIRE / IMG)
	_front_mat.set_shader_parameter("aspect", IMG.x / IMG.y)
	_layer(FRONT, _front_mat)


func _layer(tex: Texture2D, mat: Material) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = IMG
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.material = mat
	_stage.add_child(r)
	return r


func _noise_texture(px: int, freq: float, octaves: int, seed_v: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.seed = seed_v
	var t := NoiseTexture2D.new()
	t.width = px
	t.height = px
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	return t


# ── Огонь ─────────────────────────────────────────────────────────────────────
func _build_fire() -> void:
	# Тёплое пятно у углей: свет на земле и камнях кольца, дышит вместе с огнём
	_glow = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.5, 0.16, 0.5), Color(1.0, 0.38, 0.1, 0.18), Color(1.0, 0.3, 0.05, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow.texture = gt
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = Vector2(150, 62)
	_glow.position = FIRE - _glow.size * 0.5 + Vector2(0, 2)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_fx.add_child(_glow)

	# Языки пламени: мельче и чаще, чем в картинке. Крайние — маленькие, у
	# концов поленьев; два боковых — по сторонам клинка; средний — самый
	# высокий, за клинком
	var flame_noise := _noise_texture(256, 0.03, 3, 4242)
	for f in [
		{"x": FIRE.x - 30.0, "w": 22.0, "h": 15.0, "seed": 5.3, "rise": 1.2, "bw": 0.42, "k": 0.6},
		{"x": FIRE.x + 31.0, "w": 22.0, "h": 16.0, "seed": 6.9, "rise": 1.15, "bw": 0.42, "k": 0.6},
		{"x": FIRE.x - 16.0, "w": 30.0, "h": 36.0, "seed": 1.7, "rise": 1.05, "bw": 0.34, "k": 1.0},
		{"x": FIRE.x + 17.0, "w": 32.0, "h": 40.0, "seed": 3.1, "rise": 0.95, "bw": 0.34, "k": 1.0},
		{"x": FIRE.x, "w": 50.0, "h": 60.0, "seed": 0.0, "rise": 0.85, "bw": 0.36, "k": 1.0},
	]:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(f["w"], f["h"])
		r.position = Vector2(f["x"] - f["w"] * 0.5, FIRE.y + 4.0 - f["h"])
		var m := ShaderMaterial.new()
		m.shader = FLAME_SHADER
		m.set_shader_parameter("noise_tex", flame_noise)
		m.set_shader_parameter("seed", f["seed"])
		m.set_shader_parameter("rise", f["rise"])
		m.set_shader_parameter("base_width", f["bw"])
		r.material = m
		_fx.add_child(r)
		_flames.append(m)
		_flame_k.append(float(f["k"]))

	_sparks = Control.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.size = IMG
	var add2 := CanvasItemMaterial.new()
	add2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = add2
	_sparks.draw.connect(_draw_parts)
	_fx.add_child(_sparks)


func _process(delta: float) -> void:
	_fit()
	_t += delta
	# Мерцание: две частоты шума — медленное «дыхание» и быстрая дрожь
	var n := _flicker_noise.get_noise_1d(_t * 2.1) * 0.65 + _flicker_noise.get_noise_1d(_t * 7.3 + 40.0) * 0.35
	_flare = move_toward(_flare, 0.0, delta * 0.8)
	_light = 1.0 + n * 0.28 + _flare
	if _front_mat:
		_front_mat.set_shader_parameter("light", _light)
		# Свет пляшет вместе с пламенем: центр чуть гуляет (больше по
		# горизонтали и вверх), радиус дышит — блики ползут по граням камней
		var jx := _flicker_noise.get_noise_1d(_t * 3.1 + 17.0) * 3.5
		var jy := -absf(_flicker_noise.get_noise_1d(_t * 2.6 + 61.0)) * 4.0
		_front_mat.set_shader_parameter("light_pos", (FIRE + Vector2(jx, jy - 6.0)) / IMG)
		_front_mat.set_shader_parameter("radius", 0.2 + n * 0.018 + _flare * 0.05)
	if _fog_mat:
		_fog_mat.set_shader_parameter("fire_light", _light)
	for i in _flames.size():
		_flames[i].set_shader_parameter("intensity", (0.9 + n * 0.25 + _flare * 0.9) * _flame_k[i])
	if _glow:
		_glow.modulate.a = clampf(0.75 + n * 0.3 + _flare * 0.8, 0.0, 1.6)
	if _moon:
		_moon.modulate.a = 0.75 + 0.25 * sin(_t * 0.17) * sin(_t * 0.071 + 1.3)
	if _sparks:
		_update_parts(delta)
		_sparks.queue_redraw()


## Сцена накрывает экран целиком (обрезая края), центр — по центру экрана
func _fit() -> void:
	var vp := get_viewport_rect().size
	var s := maxf(vp.x / IMG.x, vp.y / IMG.y)
	var pos := ((vp - IMG * s) * 0.5).round()
	for st: Control in [_stage, _fx]:
		if st:
			st.scale = Vector2(s, s)
			st.global_position = pos


# ── Искры и щепки ─────────────────────────────────────────────────────────────
# Искры поднимаются от углей постоянно: тёплый подъём, их сносит ветром,
# они виляют и гаснут, остывая от жёлтого к красному.
# Раз в несколько секунд полено «стреляет»: вспышка света, веер быстрых искр
# и 1–3 тлеющие щепки — летят по дуге, падают на землю, разок
# подпрыгивают и дотлевают, медленно темнея.
func _update_parts(delta: float) -> void:
	_wind = lerpf(-5.0, -34.0, gust)
	_spark_acc += delta * _spark_rate * (0.7 + 0.6 * _light)
	while _spark_acc >= 1.0:
		_spark_acc -= 1.0
		_spawn_spark(false)
	_next_pop -= delta
	if _next_pop <= 0.0:
		_next_pop = randf_range(2.5, 7.5)
		_pop()

	var i := 0
	while i < _parts.size():
		var p: Dictionary = _parts[i]
		p.age += delta
		if p.age >= p.life:
			_parts.remove_at(i)
			continue
		match p.kind:
			"spark":
				p.v.x += (sin(p.age * 3.2 + p.phase) * 18.0 + _wind * 0.6) * delta
				p.v.y += -12.0 * delta + p.grav * delta
				p.v *= 1.0 - 0.45 * delta
				p.p += p.v * delta
			"chunk":
				if p.state == 0:
					p.v.y += 260.0 * delta
					p.v.x += _wind * 0.25 * delta
					p.rot += p.rotv * delta
					p.p += p.v * delta
					# Летящая щепка роняет крошечные искры
					if randf() < 9.0 * delta and _parts.size() < MAX_PARTS:
						_parts.append({"kind": "spark", "p": p.p, "v": p.v * 0.15 + Vector2(0, -12),
							"age": 0.0, "life": randf_range(0.2, 0.45), "sz": 0.6, "phase": randf() * TAU, "grav": 0.0})
					if p.v.y > 0.0 and p.p.y >= p.land_y:
						p.p.y = p.land_y
						if p.bounces < 1 and absf(p.v.y) > 40.0:
							p.v = Vector2(p.v.x * 0.45, -p.v.y * 0.25)
							p.bounces += 1
						else:
							# Легла и тлеет: остаток жизни — на остывание
							p.state = 1
							p.v = Vector2.ZERO
							p.land_age = p.age
							p.life = p.age + randf_range(1.8, 3.6)
		i += 1


func _spawn_spark(fast: bool) -> void:
	if _parts.size() >= MAX_PARTS:
		return
	var a := deg_to_rad(-90.0 + randf_range(-40.0, 40.0)) if fast else deg_to_rad(-90.0 + randf_range(-12.0, 12.0))
	var speed := randf_range(110.0, 190.0) if fast else randf_range(45.0, 95.0)
	_parts.append({
		"kind": "spark",
		"p": FIRE + Vector2(randf_range(-15.0, 15.0), randf_range(-14.0, -2.0)),
		"v": Vector2.from_angle(a) * speed + Vector2(_wind * 0.3, 0),
		"age": 0.0,
		"life": randf_range(0.5, 1.1) if fast else randf_range(1.2, 2.6),
		"sz": randf_range(0.9, 1.6),
		"phase": randf() * TAU,
		"grav": 70.0 if fast else 0.0,
	})


func _pop() -> void:
	_flare = randf_range(0.3, 0.5)
	for k in randi_range(6, 12):
		_spawn_spark(true)
	for k in randi_range(1, 3):
		if _parts.size() >= MAX_PARTS:
			return
		var a := deg_to_rad(-90.0 + randf_range(-60.0, 60.0))
		var v := Vector2.from_angle(a) * randf_range(70.0, 150.0)
		var start := FIRE + Vector2(randf_range(-10.0, 10.0), -8.0)
		# Где упадёт: кольцо камней чуть ниже углей, дальше от центра — ниже
		var land := FIRE.y + 10.0 + randf_range(-4.0, 22.0)
		_parts.append({
			"kind": "chunk", "p": start, "v": v, "age": 0.0, "life": 6.0,
			"sz": randf_range(2.6, 4.0), "phase": randf() * TAU,
			"rot": randf() * TAU, "rotv": randf_range(-9.0, 9.0),
			"state": 0, "bounces": 0, "land_y": land, "land_age": 0.0,
			"shape": [randf_range(0.7, 1.2), randf_range(0.5, 0.9), randf_range(0.7, 1.2), randf_range(0.5, 0.9)],
		})


func _draw_parts() -> void:
	for p in _parts:
		var k: float = p.age / p.life
		if p.kind == "spark":
			# Остывание: жёлто-белая → оранжевая → тёмно-красная
			var hot := Color(1.0, 0.86, 0.55).lerp(Color(1.0, 0.42, 0.08), clampf(k * 1.6, 0.0, 1.0))
			hot = hot.lerp(Color(0.7, 0.1, 0.02), clampf(k * 1.6 - 1.0, 0.0, 1.0))
			var tw := 0.75 + 0.25 * sin(p.age * 23.0 + p.phase)
			var a := pow(1.0 - k, 1.3) * tw
			var tail: Vector2 = p.v * 0.045
			_sparks.draw_line(p.p, p.p - tail, Color(hot, a), p.sz)
			_soft_glow(p.p, p.sz * 3.2, Color(hot, a * 0.35))
		else:
			var glow: float
			if p.state == 0:
				glow = 1.0
			else:
				var cool: float = (p.age - p.land_age) / maxf(p.life - p.land_age, 0.01)
				glow = (1.0 - cool) * (0.65 + 0.35 * sin(p.age * 8.0 + p.phase))
			var col := Color(1.0, 0.5, 0.14).lerp(Color(0.6, 0.1, 0.02), 1.0 - glow)
			var s: float = p.sz
			var sh: Array = p.shape
			var pts := PackedVector2Array()
			for j in 4:
				var ang: float = p.rot + j * TAU / 4.0
				pts.append(p.p + Vector2.from_angle(ang) * s * float(sh[j]))
			_sparks.draw_colored_polygon(pts, Color(col, 0.9 * glow))
			_soft_glow(p.p, s * 4.0, Color(col, 0.4 * glow))


## Ореол — мягкое радиальное пятно, а не плоский круг (тот давал «пузыри»
## с резким краем вокруг каждой щепки)
func _soft_glow(at: Vector2, r: float, col: Color) -> void:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	_sparks.draw_texture_rect(_soft, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
