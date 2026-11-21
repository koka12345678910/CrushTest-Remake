extends Node2D
## fire_fx.gd — живой огонь карты без единого ассета огня (Immersion/FireFX).
##
## Раньше огонь был пиксельной анимацией 32×32 (Levels/props/campfire.tscn,
## Glow) и размытым пятном света. Теперь каждый огонь собирается из:
##   пламя  — несколько языков, шейдер shaders/fire_flame.gdshader: течёт и
##            закручивается, цвет по температуре (кромка → тело → белое ядро),
##            верх рвётся на отлетающие языки, над ним копоть;
##   угли   — ложе раскалённых головешек (shaders/fire_embers.gdshader);
##   искры  — вылетают вверх, их крутит потоком горячего воздуха;
##   "щелчки" — время от времени полено стреляет снопом искр, и в этот миг
##            вспыхивает и пламя, и свет;
##   пепел, дым — тёмные хлопья и клубы над огнём, освещённые им снизу;
##   марево — воздух над огнём дрожит (shaders/fire_haze.gdshader);
##   свет   — тот же PointLight2D, но дрожит в такт пламени, чуть гуляет
##            (тени пляшут) и желтеет на вспышках.
##
## Огни: экземпляры campfire.tscn (TownFire* — горящие дома) и факелы/костры
## из узла Night (Torch*, Fire*, Brazier*, Beacon*). Лампы и свечи — нет.
## Кладбище не трогается: всё строится здесь, во время игры.

const FLAME_SHADER := preload("res://reference_map_level/shaders/fire_flame.gdshader")
const EMBER_SHADER := preload("res://reference_map_level/shaders/fire_embers.gdshader")
const HAZE_SHADER := preload("res://reference_map_level/shaders/fire_haze.gdshader")
const CAMPFIRE_SCENE := "res://Levels/props/campfire.tscn"
const SMOKE_TEX := "res://reference_map_level/textures/immersion/smoke.png"

## Факел из Night рисуется в Objects (y-sort): точка сортировки — на столько
## ниже пламени (у основания столба/стены), чтобы герой за столбом был за огнём
const TORCH_SORT_DY := 60.0
## z марева: над Objects, облачными тенями с цветокором (45) и лучами (46)
const HAZE_Z := 47

## Вид огня. flames: [смещение основания, размер квада пламени (огонь — ~0.6
## ширины и ~0.75 высоты), сила ядра];
## bed — эллипс углей; sparks/pops/ash/smoke — сколько частиц;
## haze — размер марева; jitter — насколько гуляет свет, px
const KINDS := {
	"torch": {
		"mat": "torch",
		"flames": [[Vector2(0, 2), Vector2(30, 48), 1.0]],
		"bed": Vector2.ZERO, "sparks": 6, "spark_v": Vector2(18, 55), "pops": 4,
		"ash": 0, "smoke": 4, "haze": Vector2(30, 70), "haze_k": 0.55, "jitter": 1.2, "air": 150.0,
	},
	"camp": {
		"mat": "camp",
		"flames": [[Vector2(0, 0), Vector2(64, 78), 0.9]],
		"bed": Vector2(46, 16), "sparks": 18, "spark_v": Vector2(35, 95), "pops": 8,
		"ash": 6, "smoke": 8, "haze": Vector2(60, 120), "haze_k": 0.85, "jitter": 2.5, "air": 300.0,
	},
	"house": {
		"mat": "house",
		"flames": [[Vector2(0, 0), Vector2(130, 150), 0.55]],
		"bed": Vector2.ZERO, "sparks": 36, "spark_v": Vector2(45, 130), "pops": 12,
		"ash": 14, "smoke": 14, "haze": Vector2(110, 190), "haze_k": 1.0, "jitter": 3.5, "air": 460.0,
	},
}

## Параметры шейдера пламени по видам: факел — тонкий и быстрый, пожар —
## широкий, рваный, с густой копотью
const MATS := {
	"torch": {"rise": 2.6, "tongues": 1.2, "grain": 2.4, "base_width": 0.19, "reach": 0.78, "warp": 0.85,
		"ragged": 0.9, "brightness": 1.3, "halo": 0.3, "soot": 0.3, "flicker_speed": 1.2},
	"camp": {"rise": 2.1, "tongues": 2.2, "grain": 3.0, "base_width": 0.27, "reach": 0.72, "warp": 1.0,
		"ragged": 1.0, "brightness": 1.2, "halo": 0.24, "soot": 0.5, "flicker_speed": 1.0},
	"house": {"rise": 1.8, "tongues": 3.0, "grain": 3.6, "base_width": 0.29, "reach": 0.7, "warp": 1.1,
		"ragged": 1.15, "brightness": 1.1, "halo": 0.2, "soot": 0.7, "flicker_speed": 0.9, "base_rag": 0.2,
		"heat_gain": 1.05},
}

@export var wind_strength := 1.0
## Огонь дальше этого от края экрана не обновляется (свет тоже не дрожит)
@export var cull_margin := 500.0

var stats := {}

var _fires: Array = []          # FireData
var _mats := {}
var _ember_mat: ShaderMaterial
var _haze_mat: ShaderMaterial
var _haze_holder: Node2D
var _haze_copy: BackBufferCopy
## Свечение воздуха вокруг огня (дым и сырость рассеивают свет): мягкое
## аддитивное пятно над всем, дышит вместе с огнём
var _air_holder: Node2D
var _air_tex: Texture2D
@export var air_glow := 0.085
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _white: Texture2D
var _spark_tex: Texture2D
var _ash_tex: Texture2D
var _smoke_tex: Texture2D


class FireData:
	var root: Node2D
	var kind: String
	var quads: Array = []        # Quad
	var light: PointLight2D
	var body_light: PointLight2D
	var base_energy := 1.0
	var base_scale := 1.0
	var base_color := Color.WHITE
	var base_pos := Vector2.ZERO
	var phase := 0.0
	var flare := 0.0
	var pop_t := 2.0
	var pops: GPUParticles2D
	var jitter := 2.0
	var seed := 0.0
	var haze: Quad
	var air: Sprite2D
	var air_y := 0.0


## Квад с параметрами огня в цвете вершин (их читает шейдер)
class Quad:
	extends Node2D
	var rect := Rect2()
	var tex: Texture2D
	var data := Color(0, 1, 0.5, 0.5)

	func _draw() -> void:
		draw_texture_rect(tex, rect, false, data)


func _ready() -> void:
	process_priority = 1000   # после night_flicker / fire_flicker: свет — наш
	_noise.frequency = 1.0
	_rng.seed = 4242


## Собрать огонь на карте map
func setup(map: Node) -> void:
	_make_resources()
	_haze_holder = Node2D.new()
	_haze_holder.name = "Haze"
	_haze_holder.z_index = HAZE_Z
	add_child(_haze_holder)
	_air_holder = Node2D.new()
	_air_holder.name = "AirGlow"
	_air_holder.z_index = HAZE_Z - 1
	add_child(_air_holder)
	# Марево рисуется после облачных теней с цветокором (они заменяют кадр),
	# поэтому перед ним — свежая копия экрана; только когда огонь в кадре
	_haze_copy = BackBufferCopy.new()
	_haze_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_haze_holder.add_child(_haze_copy)
	var n_house := 0
	var n_camp := 0
	var n_torch := 0
	# 1. Экземпляры campfire.tscn — горящие дома, костры
	for f in map.find_children("*", "Node2D", true, false):
		if f.scene_file_path != CAMPFIRE_SCENE:
			continue
		var nm := String(f.name)
		var kind := "house" if nm.begins_with("TownFire") else "camp"
		var parent_nm := String(f.get_parent().name).to_lower()
		if parent_nm.contains("torch"):
			kind = "torch"
		var s: float = absf((f as Node2D).global_scale.x)
		var size_k := 1.0
		if kind == "house":
			size_k = clampf(s / 1.4, 0.8, 1.2)
		for c in ["Glow", "Embers"]:
			var g := f.get_node_or_null(c) as CanvasItem
			if g:
				g.visible = false
		# Свет дальше ведём мы (fire_flicker.gd остаётся ради треска огня)
		if "energy_jitter" in f:
			f.set("energy_jitter", 0.0)
			f.set("scale_jitter", 0.0)
		var holder := Node2D.new()
		holder.name = "FireFX"
		holder.scale = Vector2.ONE / maxf(s, 0.01) * size_k
		# Огонь стоит у фасада дома (выше основания дома по y) — по y-sort он
		# ушёл бы за дом; как старый Glow, рисуется на слой выше
		holder.z_index = 1
		f.add_child(holder)
		var d := _build(holder, kind)
		d.light = f.get_node_or_null("Light") as PointLight2D
		d.body_light = f.get_node_or_null("BodyLight") as PointLight2D
		if d.light:
			d.base_energy = float(f.get("base_energy")) if f.get("base_energy") != null else d.light.energy
			var bs = f.get("_base_scale")
			d.base_scale = float(bs) if bs != null else d.light.texture_scale
		_finish(d)
		if kind == "house":
			n_house += 1
		else:
			n_camp += 1
	# 2. Факелы и костры, у которых на карте есть только свет (узел Night)
	var night := map.get_node_or_null("Night")
	var objects := map.get_node_or_null("Objects")
	if night and objects:
		var base := {}
		var nf = night.get("_fires")
		if nf is Array:
			for e in nf:
				base[e[0]] = [e[1], e[2]]
		for l in night.get_children():
			if not l is PointLight2D:
				continue
			var nm := String(l.name)
			var kind := ""
			if nm.begins_with("Torch"):
				kind = "torch"
			elif nm.begins_with("Fire") or nm.begins_with("Brazier") or nm.begins_with("Beacon") or nm.begins_with("Camp"):
				kind = "camp"
			if kind == "":
				continue
			var anchor := Node2D.new()
			anchor.name = "FireFX_" + nm
			anchor.position = (l as Node2D).global_position + Vector2(0, TORCH_SORT_DY)
			objects.add_child(anchor)
			var holder := Node2D.new()
			holder.position = Vector2(0, -TORCH_SORT_DY + (10.0 if kind == "torch" else 14.0))
			anchor.add_child(holder)
			var d := _build(holder, kind)
			d.light = l
			if base.has(l):
				d.base_energy = base[l][0]
				d.base_scale = base[l][1]
			else:
				d.base_energy = l.energy
				d.base_scale = l.texture_scale
			_finish(d)
			if kind == "torch":
				n_torch += 1
			else:
				n_camp += 1
	stats = {"house": n_house, "camp": n_camp, "torch": n_torch}


func _finish(d: FireData) -> void:
	if d.light:
		d.base_color = d.light.color
		d.base_pos = d.light.position
	_fires.append(d)


# ------------------------------------------------------------------ сборка

func _build(holder: Node2D, kind: String) -> FireData:
	var k: Dictionary = KINDS[kind]
	var d := FireData.new()
	d.root = holder
	d.kind = kind
	d.phase = _rng.randf() * 1000.0
	d.seed = _rng.randf()
	d.jitter = k["jitter"]
	d.pop_t = _rng.randf_range(1.0, 6.0)
	var flame_h := 0.0
	var flame_w := 0.0
	# Угли — под всем
	var bed: Vector2 = k["bed"]
	if bed != Vector2.ZERO:
		var q := _quad(holder, Rect2(-bed * 0.5, bed), _ember_mat)
		q.data = Color(_rng.randf(), 1, 0.5, 0.5)
		d.quads.append(q)
	for fspec in k["flames"]:
		var off: Vector2 = fspec[0]
		var sz: Vector2 = fspec[1]
		# Сам огонь — около 0.6 ширины и 0.75 высоты квада (base_width, reach):
		# по краям место под наклон, ореол и отлетающие языки
		flame_h = maxf(flame_h, sz.y * 0.7)
		flame_w = maxf(flame_w, sz.x * 0.6)
		var r := Rect2(off.x - sz.x * 0.5, off.y - sz.y, sz.x, sz.y)
		var q := _quad(holder, r, _mats[k["mat"]])
		q.data = Color(_rng.randf(), fspec[2], 0.5, 0.5)
		d.quads.append(q)
	# Дым и пепел — за искрами, перед пламенем (освещены им)
	if int(k["smoke"]) > 0 and _smoke_tex:
		holder.add_child(_smoke(int(k["smoke"]), flame_w, flame_h, kind == "torch"))
	if int(k["ash"]) > 0:
		holder.add_child(_ash(int(k["ash"]), flame_w, flame_h))
	holder.add_child(_sparks(int(k["sparks"]), flame_w, flame_h, k["spark_v"]))
	d.pops = _pops(int(k["pops"]), flame_w, flame_h, k["spark_v"])
	holder.add_child(d.pops)
	# Марево — общий узел над Objects (после общей копии экрана _haze_copy)
	var hz: Vector2 = k["haze"]
	var h := Quad.new()
	h.tex = _white
	h.material = _haze_mat
	h.rect = Rect2(-hz.x * 0.5, -hz.y, hz.x, hz.y)
	h.data = Color(_rng.randf(), 0, 0, 0.5 * float(k["haze_k"]))
	_haze_holder.add_child(h)
	d.haze = h
	var air := Sprite2D.new()
	air.texture = _air_tex
	air.material = _air_mat()
	air.scale = Vector2.ONE * float(k["air"]) / 128.0 * Vector2(1.0, 0.8)
	air.modulate = Color(1.0, 0.5, 0.2, 0.0)
	_air_holder.add_child(air)
	d.air = air
	d.air_y = -flame_h * 0.45
	return d


func _quad(parent: Node, r: Rect2, mat: Material) -> Quad:
	var q := Quad.new()
	q.tex = _white
	q.rect = r
	q.material = mat
	parent.add_child(q)
	return q


func _make_resources() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	for key in MATS:
		var m := ShaderMaterial.new()
		m.shader = FLAME_SHADER
		var p: Dictionary = MATS[key]
		for pk in p:
			m.set_shader_parameter(pk, p[pk])
		_mats[key] = m
	_ember_mat = ShaderMaterial.new()
	_ember_mat.shader = EMBER_SHADER
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = HAZE_SHADER
	# Искра — вытянутая капля с горячей серединой (вдоль скорости)
	var sp := Image.create(8, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 8:
			var dx := (x - 3.5) / 3.5
			var dy := (y - 11.5) / 11.5
			var r := dx * dx + dy * dy
			var a := clampf(exp(-r * 3.2), 0.0, 1.0)
			sp.set_pixel(x, y, Color(1, 1, 1, a))
	_spark_tex = ImageTexture.create_from_image(sp)
	# Хлопья пепла — неровные пятнышки
	var ash := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var pr := RandomNumberGenerator.new()
	pr.seed = 11
	for y in 6:
		for x in 6:
			var r2 := Vector2(x - 2.5, y - 2.5).length()
			var a2 := clampf(1.0 - r2 / 3.0 + pr.randf_range(-0.35, 0.2), 0.0, 1.0)
			ash.set_pixel(x, y, Color(1, 1, 1, a2))
	_ash_tex = ImageTexture.create_from_image(ash)
	_smoke_tex = load(SMOKE_TEX) if ResourceLoader.exists(SMOKE_TEX) else null
	var ag := GradientTexture2D.new()
	ag.width = 128
	ag.height = 128
	ag.fill = GradientTexture2D.FILL_RADIAL
	ag.fill_from = Vector2(0.5, 0.5)
	ag.fill_to = Vector2(0.5, 0.0)
	var agg := Gradient.new()
	agg.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	agg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)])
	ag.gradient = agg
	_air_tex = ag


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


func _ramp(offsets: Array, colors: Array) -> GradientTexture1D:
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


func _turbulence(pm: ParticleProcessMaterial, strength: float, influence: Vector2) -> void:
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = strength
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_noise_speed_random = 0.6
	pm.turbulence_influence_min = influence.x
	pm.turbulence_influence_max = influence.y


func _spark_ramp() -> GradientTexture1D:
	return _ramp([0.0, 0.35, 0.75, 1.0], [Color(1, 0.96, 0.72, 1), Color(1, 0.76, 0.3, 1),
		Color(1, 0.42, 0.1, 0.9), Color(0.7, 0.15, 0.03, 0.0)])


func _sparks(amount: int, w: float, h: float, v: Vector2) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "Sparks"
	p.amount = amount
	p.lifetime = 1.7
	p.preprocess = 1.7
	p.randomness = 0.6
	p.texture = _spark_tex
	p.material = _additive()
	p.position = Vector2(0, -h * 0.35)
	p.visibility_rect = Rect2(-w * 2.0 - 60, -h * 3.0 - 160, w * 4.0 + 120, h * 3.0 + 200)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.particle_flag_align_y = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.28, h * 0.15, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.gravity = Vector3(8.0 * wind_strength, -30.0, 0)
	pm.damping_min = 10.0
	pm.damping_max = 28.0
	pm.scale_min = 0.16
	pm.scale_max = 0.36
	pm.scale_curve = _curve([Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0.15)])
	pm.color_ramp = _spark_ramp()
	_turbulence(pm, 2.0, Vector2(0.03, 0.1))
	p.process_material = pm
	return p


func _pops(amount: int, w: float, h: float, v: Vector2) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "Pops"
	p.amount = amount
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.randomness = 0.5
	p.texture = _spark_tex
	p.material = _additive()
	p.position = Vector2(0, -h * 0.25)
	p.visibility_rect = Rect2(-w * 3.0 - 120, -h * 3.0 - 200, w * 6.0 + 240, h * 3.0 + 300)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.particle_flag_align_y = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = w * 0.15
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = v.y * 0.6
	pm.initial_velocity_max = v.y * 1.2
	pm.gravity = Vector3(0, 90.0, 0)
	pm.damping_min = 30.0
	pm.damping_max = 60.0
	pm.scale_min = 0.12
	pm.scale_max = 0.24
	pm.scale_curve = _curve([Vector2(0, 1), Vector2(1, 0.2)])
	pm.color_ramp = _spark_ramp()
	p.process_material = pm
	return p


func _ash(amount: int, w: float, h: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "Ash"
	p.amount = amount
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.randomness = 0.5
	p.texture = _ash_tex
	p.position = Vector2(0, -h * 0.6)
	p.visibility_rect = Rect2(-w * 2.0 - 120, -h * 3.0 - 200, w * 4.0 + 240, h * 3.0 + 260)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.3, h * 0.2, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(6.0 * wind_strength, -5.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 5.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	# Часть пепла ещё тлеет (ярче), остальной серый; гаснет к концу
	pm.color_ramp = _ramp([0.0, 0.15, 0.7, 1.0], [Color(1.6, 0.7, 0.3, 0.0), Color(1.1, 0.75, 0.6, 0.9),
		Color(0.55, 0.52, 0.5, 0.7), Color(0.4, 0.38, 0.38, 0.0)])
	_turbulence(pm, 1.5, Vector2(0.1, 0.25))
	p.process_material = pm
	return p


func _smoke(amount: int, w: float, h: float, thin: bool) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "Smoke"
	p.amount = amount
	p.lifetime = 3.2 if thin else 5.0
	p.preprocess = p.lifetime
	p.randomness = 0.4
	p.texture = _smoke_tex
	var cm := CanvasItemMaterial.new()
	cm.particles_animation = true
	cm.particles_anim_h_frames = 4
	cm.particles_anim_v_frames = 1
	# Копоть сама не светится и свет огня на ней читается как пламя —
	# рисуем без освещения, тёмной: на фоне зарева видна, в ночи тает
	cm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = cm
	p.position = Vector2(0, -h * 0.8)
	p.visibility_rect = Rect2(-w * 3.0 - 200, -h * 4.0 - 320, w * 6.0 + 400, h * 4.0 + 360)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = w * 0.2
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 12.0 if thin else 16.0
	pm.initial_velocity_max = 20.0 if thin else 28.0
	pm.gravity = Vector3(5.0 * wind_strength, -5.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -14.0
	pm.angular_velocity_max = 14.0
	pm.anim_offset_max = 1.0
	var s := 0.12 if thin else 0.22
	pm.scale_min = s
	pm.scale_max = s * 1.4
	pm.scale_curve = _curve([Vector2(0, 0.35), Vector2(1, 1.0 if thin else 1.0)])
	# У огня — бурая, выше — серая, расходится и тает
	var a := 0.22 if thin else 0.38
	pm.color_ramp = _ramp([0.0, 0.12, 0.6, 1.0], [Color(0.12, 0.07, 0.04, 0.0), Color(0.1, 0.07, 0.05, a),
		Color(0.07, 0.07, 0.08, a * 0.6), Color(0.08, 0.08, 0.09, 0.0)])
	p.process_material = pm
	return p


# ------------------------------------------------------------------ жизнь огня

func _process(delta: float) -> void:
	_time += delta
	var view := _view_rect()
	var weather := get_node_or_null("/root/Weather")
	var day_k := 1.0
	if weather and weather.call("is_active"):
		day_k = float(weather.get("fire_scale"))
	var wind := 1.0
	if weather and weather.call("is_active"):
		wind = float(weather.get("wind"))
	for d: FireData in _fires:
		if not is_instance_valid(d.root):
			continue
		var gp := d.root.global_position
		if not view.has_point(gp):
			continue
		var t := _time * 6.5 + d.phase
		# Дыхание + дрожь + мелкая рябь: у огня нет ритма
		var n := _noise.get_noise_1d(t) * 0.6 + _noise.get_noise_1d(t * 2.7 + 31.0) * 0.3 \
				+ _noise.get_noise_1d(t * 7.9 + 77.0) * 0.1
		# Щелчок полена: сноп искр и короткая вспышка
		d.pop_t -= delta
		if d.pop_t <= 0.0:
			d.pop_t = _rng.randf_range(1.5, 7.0) if d.kind != "torch" else _rng.randf_range(3.0, 11.0)
			d.flare += _rng.randf_range(0.18, 0.4)
			if d.pops:
				d.pops.restart()
		d.flare = move_toward(d.flare, 0.0, delta * 1.6)
		var inten := clampf(1.0 + n * 0.24 + d.flare, 0.55, 1.7)
		var lean := clampf(0.5 + (wind - 1.0) * 0.08 + 0.06 * wind_strength
				+ _noise.get_noise_1d(t * 0.25 + 400.0) * 0.08, 0.15, 0.85)
		for q: Quad in d.quads:
			var c := q.data
			c.a = clampf(inten * 0.5, 0.0, 1.0)
			c.b = lean
			q.data = c
			q.queue_redraw()
		if d.haze:
			d.haze.global_position = gp
		if d.air:
			d.air.global_position = gp + Vector2(0, d.air_y)
			d.air.modulate.a = air_glow * day_k * inten
		if d.light:
			d.light.energy = d.base_energy * day_k * inten
			d.light.texture_scale = d.base_scale * (1.0 + n * 0.045 + d.flare * 0.06)
			d.light.position = d.base_pos + Vector2(_noise.get_noise_1d(t * 0.9 + 5.0),
					_noise.get_noise_1d(t * 1.1 + 9.0) * 0.6) * d.jitter
			d.light.color = d.base_color.lerp(Color(1.0, 0.66, 0.32), clampf(d.flare * 1.4 + n * 0.15, 0.0, 0.6))
			if d.body_light:
				d.body_light.energy = d.light.energy
				d.body_light.texture_scale = d.light.texture_scale
				d.body_light.color = d.light.color
	# Марево только у огня в кадре; нет такого — нет и копии экрана
	var screen := _view_rect(0.0)
	var any := false
	for d: FireData in _fires:
		if d.haze == null or not is_instance_valid(d.root):
			continue
		var hr := d.haze.rect
		var vis := screen.intersects(Rect2(d.haze.global_position + hr.position, hr.size))
		d.haze.visible = vis
		any = any or vis
	if _haze_copy:
		_haze_copy.visible = any


func _view_rect(margin := -1.0) -> Rect2:
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var r := Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
	return r.grow(cull_margin if margin < 0.0 else margin)


## Насколько точка освещена огнём (0 — только луна, ~1 — у самого огня):
## силуэт героя за домом у костра тёплый, в темноте — лунный
func warmth_at(p: Vector2) -> float:
	var best := 0.0
	for d: FireData in _fires:
		if d.light == null or not is_instance_valid(d.light) or d.light.texture == null:
			continue
		var r := d.light.texture.get_width() * d.light.texture_scale * 0.5 * absf(d.light.global_scale.x) * 0.75
		var dist := d.light.global_position.distance_to(p)
		if dist >= r:
			continue
		best = maxf(best, (1.0 - dist / r) * minf(d.light.energy, 1.2))
	return clampf(best * 1.4, 0.0, 0.85)


var _air_material: CanvasItemMaterial

func _air_mat() -> CanvasItemMaterial:
	if _air_material == null:
		_air_material = _additive()
	return _air_material
