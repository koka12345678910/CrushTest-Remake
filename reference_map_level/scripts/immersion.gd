extends Node2D
## immersion.gd — «погружение» reference_map: мир дышит и отзывается.
##
## Один узел в корне карты (последним ребёнком — к его _ready карта уже готова,
## OcclusionFade уже раздал свой материал). Всё строится при запуске из данных
## самой карты, в сцене ничего не хранится:
##   ветер     — кроны, кусты, трава, камыш качаются; шатры, знамёна, пугало
##               колышутся; петля виселицы раскачивается (shaders/wind_fade);
##   передний  — размытые тёмные ветки и листва с параллаксом между камерой и
##   план        героем: много в лесу, верёвки с флажками в деревне, в поле нет
##               (scripts/foreground_layer.gd);
##   облака    — мягкие тени ползут по всей карте (shaders/cloud_shadows);
##   дым       — столбы над сгоревшими домами и кострами;
##   туман     — клубится в пропасти, над рекой и болотом (shaders/mist);
##               старый туман карты (Atmosphere/Fog) — без пиксельной лесенки;
##   звук      — река, листва, ветер из пропасти, болото, ткань, скрипы
##               (scripts/ambient_sound.gd).
## Ресурсы — tools/immersion_bake.gd (textures/immersion, Sound/ambience).
## Любую часть можно выключить флагом ниже.

const WIND_SHADER := preload("res://reference_map_level/shaders/wind_fade.gdshader")
const CLOUD_SHADER := preload("res://reference_map_level/shaders/cloud_shadows.gdshader")
const MIST_SHADER := preload("res://reference_map_level/shaders/mist.gdshader")
const FG_SHADER := preload("res://reference_map_level/shaders/foreground.gdshader")
const FG_SCRIPT := preload("res://reference_map_level/scripts/foreground_layer.gd")
const SOUND_SCRIPT := preload("res://reference_map_level/scripts/ambient_sound.gd")
const FG_TEX := "res://reference_map_level/textures/immersion/foreground.png"
const FG_JSON := "res://reference_map_level/textures/immersion/foreground.json"
const SMOKE_TEX := "res://reference_map_level/textures/immersion/smoke.png"
const RAVINE_MASK := "res://reference_map_level/textures/immersion/ravine_mask.res"
const ABYSS_SHADER := preload("res://reference_map_level/shaders/abyss.gdshader")
const SHEEN_SHADER := preload("res://reference_map_level/shaders/water_sheen.gdshader")
const CANOPY_SHADER := preload("res://reference_map_level/shaders/canopy_shade.gdshader")
const RESPONSE_SCRIPT := preload("res://reference_map_level/scripts/hero_response.gd")
const CRITTERS_SCRIPT := preload("res://reference_map_level/scripts/critters.gd")
const CAMERA_SCRIPT := preload("res://reference_map_level/scripts/camera_zones.gd")
const SHADOWS_SCRIPT := preload("res://reference_map_level/scripts/light_shadows.gd")
const NORMALS_SCRIPT := preload("res://reference_map_level/scripts/normal_maps.gd")
const GROUND_MATERIAL := "res://reference_map_level/textures/terrain/ground_material.tres"

@export var wind_enabled := true
@export var foreground_enabled := true
@export var clouds_enabled := true
@export var smoke_enabled := true
@export var mist_enabled := true
@export var sound_enabled := true
## Глубина: дно пропасти и оврага, нижний туман с параллаксом, небо в реке
@export var depth_enabled := true
## Отклик на шаги: следы, круги на воде, пыль, звук шага по поверхности
@export var response_enabled := true
## Тень и пятна лунного света под кронами
@export var canopy_enabled := true
## Вороны и крысы, которые боятся героя
@export var critters_enabled := true
## Камера по зонам: ближе в лесу, дальше у обрыва, в поле и в лагере
@export var camera_enabled := true
## Факелы не светят сквозь стены: тени от домов, стен, частокола, стволов на земле
@export var shadows_enabled := true
## Свет огня ложится по рельефу HD-арта (карты нормалей textures/normals)
@export var normals_enabled := true
## Общая сила ветра (кроны, ткань, передний план)
@export_range(0.0, 3.0) var wind_strength := 1.0
@export var seed_value := 7

## Слои с деревьями и пропсами (тайлы)
const TILE_LAYERS := ["Objects/Decor", "Objects/PurpleForest", "Objects/Wilds", "Objects/Ruins",
	"Objects/RuinedCamp/Objects/Trees"]
## Вид дерева -> [наклон верха (мировые px), скорость, дрожь листвы (тексели)]
const TREE_WIND := {
	"oak": [3.0, 0.7, 0.7], "oak_big": [2.6, 0.6, 0.7], "maple_red": [3.2, 0.75, 0.8],
	"birch_autumn": [4.2, 0.9, 0.9], "birch_weeping": [4.6, 0.8, 1.1],
	"fir": [2.0, 0.6, 0.35], "fir_tall": [2.6, 0.55, 0.35],
	"dead_big": [1.4, 0.5, 0.0], "dead_broken": [1.0, 0.5, 0.0],
	"bush_green": [1.6, 1.1, 0.6], "bush_berry": [1.6, 1.1, 0.6], "bush_red": [1.6, 1.1, 0.6],
	"bush_dead": [1.2, 1.2, 0.3], "fern": [2.2, 1.4, 0.5], "tuft": [2.0, 1.8, 0.4],
}
## Что герой раздвигает: вид -> [сила (px), высота растения, радиус]
const PUSH := {
	"tuft": [6.0, 22.0, 26.0], "fern": [7.0, 30.0, 30.0], "bush_green": [5.0, 40.0, 34.0],
	"bush_berry": [5.0, 40.0, 34.0], "bush_red": [5.0, 40.0, 34.0], "bush_dead": [4.0, 34.0, 30.0],
}
## Деревья для плотности леса (передний план, шелест)
const DENSE_KINDS := ["oak", "oak_big", "maple_red", "birch_autumn", "birch_weeping", "fir", "fir_tall",
	"dead_big", "dead_broken"]
const GALLOWS_FALLBACK := Vector2(-88, 1250)

var _rng := RandomNumberGenerator.new()
var _mats := {}
var _occl := {}
var _noise_tex: NoiseTexture2D
## Плотность деревьев: Vector2i(клетка 256 px) -> число
var _density := {}
## Точки деревьев по видам (для выбора частей переднего плана)
var _purple := {}
var _houses: Array[Sprite2D] = []
var _sound: Node2D
var _swing_half := 0
var _gallows := GALLOWS_FALLBACK
var _fg: Node2D
var stats := {}
## Маски тумана: имя -> [ImageTexture, Rect2] (пропасть, вода, овраг)
var _masks := {}
## Материалы, которым каждый кадр нужен центр камеры (параллакс)
var _cam_mats: Array[ShaderMaterial] = []
var _gallows_rect := Rect2()
## Основания живых деревьев (тень под кронами)
var _trees := PackedVector2Array()


func _ready() -> void:
	# Корень карты в _ready ещё раздаёт детей: туман встаёт между его слоями,
	# поэтому строим кадром позже
	_build.call_deferred()


func _build() -> void:
	_rng.seed = seed_value
	var map := get_parent()
	_read_occlusion(map)
	_scan(map)
	if wind_enabled:
		_apply_wind(map)
	if mist_enabled:
		_build_mist(map)
	if smoke_enabled:
		_build_smoke(map)
	if clouds_enabled:
		_build_clouds()
	if foreground_enabled:
		_build_foreground()
	if depth_enabled:
		_build_depth(map)
	if canopy_enabled:
		_build_canopy(map)
	if response_enabled:
		_build_response(map)
	if critters_enabled:
		_build_critters(map)
	if camera_enabled:
		_build_camera(map)
	if shadows_enabled:
		var ls := SHADOWS_SCRIPT.new()
		ls.name = "LightShadows"
		add_child(ls)
		ls.call("setup", map)
		stats["shadows"] = ls.get("stats")
	if sound_enabled:
		_build_sound(map)
	# Последним: подменяет текстуры на CanvasTexture, а шаги выше смотрят
	# resource_path текстур
	if normals_enabled:
		var nm := NORMALS_SCRIPT.new()
		nm.name = "NormalMaps"
		add_child(nm)
		nm.call("setup", map, _mats.values())
		stats["normals"] = nm.get("stats")
	print("Immersion: ", stats)


func _process(delta: float) -> void:
	if not _cam_mats.is_empty():
		var vp := get_viewport()
		var cam: Vector2 = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)
		for m in _cam_mats:
			m.set_shader_parameter("cam_pos", cam)
	# Скрип виселицы — на каждом развороте петли (период как в шейдере)
	if _sound == null:
		return
	# Развороты: sin(TIME·2π/3.4) замирает в 0.85 + n·1.7 с
	var half := int(floor((Time.get_ticks_msec() / 1000.0 - 0.85) / 1.7))
	if half != _swing_half:
		_swing_half = half
		if _rng.randf() < 0.55:
			_sound.call("play_at", _gallows, "ambience/rope_creak_%d.wav" % _rng.randi_range(1, 2), -9.0, 560.0, _rng.randf_range(0.9, 1.08))


# ---------------------------------------------------------------- данные карты

func _read_occlusion(map: Node) -> void:
	var o := map.get_node_or_null("OcclusionFade")
	if o == null:
		_occl = {}
		return
	_occl = {"occlusion_min_alpha": o.min_alpha, "occlusion_radius": o.radius,
		"occlusion_stretch_y": o.stretch_y, "occlusion_softness": o.softness,
		"occlusion_offset": o.window_offset, "occlusion_depth_mode": 1, "occlusion_sort_offset": 0.0}


func _variant_kind(v: String) -> String:
	var i := v.rfind("_")
	if i > 0 and v.substr(i + 1).is_valid_int():
		return v.substr(0, i)
	return v


func _scan(map: Node) -> void:
	for path in TILE_LAYERS:
		var l := map.get_node_or_null(path) as TileMapLayer
		if l == null:
			continue
		var purple: bool = str(path).ends_with("PurpleForest")
		for cell in l.get_used_cells():
			var src := l.tile_set.get_source(l.get_cell_source_id(cell)) as TileSetAtlasSource
			if src and str(src.get_meta("hd_prop", "")).begins_with("gallows"):
				_gallows = l.to_global(l.map_to_local(cell)) + Vector2(0, -40)
				var ac := l.get_cell_atlas_coords(cell)
				var td := src.get_tile_data(ac, 0)
				var sz := Vector2(src.get_tile_texture_region(ac).size) * l.global_scale
				var c := l.to_global(l.map_to_local(cell)) - Vector2(td.texture_origin) * l.global_scale
				_gallows_rect = Rect2(c - sz * 0.5, sz)
			if src == null or not src.has_meta("forest_variant"):
				continue
			var kind := _variant_kind(str(src.get_meta("forest_variant")))
			if not kind in DENSE_KINDS:
				continue
			var wp := l.to_global(l.map_to_local(cell))
			if not kind.begins_with("dead"):
				_trees.append(wp)
			var key := Vector2i(floori(wp.x / 256.0), floori(wp.y / 256.0))
			_density[key] = _density.get(key, 0) + 1
			if purple:
				_purple[key] = true
	for c in map.get_node("Objects").get_children():
		if c is Sprite2D and c.has_meta("house"):
			_houses.append(c)
	stats["density_cells"] = _density.size()


func _noise() -> NoiseTexture2D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.seed = 99
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.noise = n
		_noise_tex.width = 256
		_noise_tex.height = 256
		_noise_tex.seamless = true
		_noise_tex.generate_mipmaps = true
	return _noise_tex


# ---------------------------------------------------------------- ветер

func _wind_mat(key: String, params: Dictionary) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	for p in _occl:
		m.set_shader_parameter(p, _occl[p])
	for p in params:
		m.set_shader_parameter(p, params[p])
	m.set_shader_parameter("wind_strength", wind_strength)
	_mats[key] = m
	return m


## Ткань и прочее из hd_props по имени: параметры шейдера или пусто
func _prop_wind(name: String) -> Dictionary:
	if name.begins_with("reeds"):
		return {"sway_amp": 2.6, "sway_speed": 1.3, "shimmer_amp": 0.3, "push_amp": 7.0, "plant_h": 40.0, "push_radius": 30.0}
	if name.begins_with("tent_cone"):
		return {"flutter_amp": 0.9, "flutter_mode": 2, "flutter_speed": 1.6}
	if name.begins_with("banner"):
		return {"flutter_amp": 2.4, "flutter_mode": 1, "flutter_speed": 3.2}
	if name.begins_with("scarecrow"):
		return {"flutter_amp": 1.4, "flutter_mode": 1, "flutter_speed": 2.6, "sway_amp": 0.8, "sway_speed": 0.9}
	if name.begins_with("port_net"):
		return {"flutter_amp": 0.7, "flutter_mode": 1, "flutter_speed": 1.4}
	if name.begins_with("gallows"):
		# Петля: x 0.45..0.66, от бруса (0.1) до низа (0.7) картинки
		return {"rope_rect": Vector4(0.44, 0.1, 0.67, 0.7), "rope_amp": 7.0, "rope_period": 3.4}
	return {}


func _apply_wind(map: Node) -> void:
	var tiles := 0
	var seen := {}
	for path in TILE_LAYERS:
		var l := map.get_node_or_null(path) as TileMapLayer
		if l == null or seen.has(l.tile_set):
			continue
		seen[l.tile_set] = true
		var ts := l.tile_set
		for si in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(si)) as TileSetAtlasSource
			if src == null:
				continue
			var key := ""
			var params := {}
			if src.has_meta("forest_variant"):
				var kind := _variant_kind(str(src.get_meta("forest_variant")))
				if TREE_WIND.has(kind):
					var w: Array = TREE_WIND[kind]
					key = "tree_" + kind
					params = {"sway_amp": w[0], "sway_speed": w[1], "shimmer_amp": w[2]}
					if PUSH.has(kind):
						var pp: Array = PUSH[kind]
						params["push_amp"] = pp[0]
						params["plant_h"] = pp[1]
						params["push_radius"] = pp[2]
			elif src.has_meta("hd_prop"):
				var nm := str(src.get_meta("hd_prop")).get_slice("@", 0)
				params = _prop_wind(nm)
				key = "prop_" + nm
			if params.is_empty():
				continue
			var mat := _wind_mat(key, params)
			for ti in src.get_tiles_count():
				var coords := src.get_tile_id(ti)
				for ai in src.get_alternative_tiles_count(coords):
					var td := src.get_tile_data(coords, src.get_alternative_tile_id(coords, ai))
					if td and td.material == null:
						td.material = mat
						tiles += 1
	# Спрайты карты и лагеря
	var sprites := 0
	for root_path in ["Objects", "Objects/RuinedCamp/Objects"]:
		var r := map.get_node_or_null(root_path)
		if r == null:
			continue
		for c in r.get_children():
			if not c is Sprite2D:
				continue
			var nm := ""
			if c.has_meta("hd_prop"):
				nm = str(c.get_meta("hd_prop")).get_slice("@", 0)
			elif str(c.name).begins_with("HD_standard"):
				nm = "banner"
			var params := _prop_wind(nm) if nm != "" else {}
			if params.is_empty():
				continue
			(c as Sprite2D).material = _wind_mat("prop_" + nm, params)
			sprites += 1
	stats["wind_tiles"] = tiles
	stats["wind_sprites"] = sprites


# ---------------------------------------------------------------- туман

## Маска из занятых клеток слоя: 1 тексель = 1 клетка, размыта
func _cell_mask(l: TileMapLayer, blur: int) -> Array:
	var r := l.get_used_rect()
	var img := Image.create(r.size.x, r.size.y, false, Image.FORMAT_L8)
	for cell in l.get_used_cells():
		img.set_pixel(cell.x - r.position.x, cell.y - r.position.y, Color.WHITE)
	var p0: Vector2 = l.to_global(l.map_to_local(r.position)) - Vector2(l.tile_set.tile_size) * l.global_scale * 0.5
	var size := Vector2(r.size) * Vector2(l.tile_set.tile_size) * l.global_scale
	return [_blur_mask(img, blur), Rect2(p0, size)]


## Только размытая маска, поджатая порогом: край мягкий и внутри области,
## без ступенек клеток
func _blur_mask(src: Image, blur: int) -> ImageTexture:
	var img := src.duplicate() as Image
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	var w := img.get_width()
	var h := img.get_height()
	var small := img.duplicate() as Image
	small.resize(maxi(w / blur, 2), maxi(h / blur, 2), Image.INTERPOLATE_BILINEAR)
	small.resize(w, h, Image.INTERPOLATE_CUBIC)
	for y in h:
		for x in w:
			var b := smoothstep(0.3, 0.8, small.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(b, 0, 0))
	return ImageTexture.create_from_image(img)


func _soft_rect_mask(edge: float) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var u := minf(x, n - 1 - x) / (n * edge)
			var v := minf(y, n - 1 - y) / (n * edge)
			var a := clampf(minf(u, v), 0.0, 1.0)
			img.set_pixel(x, y, Color(a * a * (3.0 - 2.0 * a), 0, 0))
	return ImageTexture.create_from_image(img)


func _mist_node(name: String, mask: Texture2D, area: Rect2, params: Dictionary) -> Node2D:
	var n := _RectDraw.new()
	n.name = name
	n.rect = area
	var m := ShaderMaterial.new()
	m.shader = MIST_SHADER
	m.set_shader_parameter("noise", _noise())
	m.set_shader_parameter("mask", mask)
	m.set_shader_parameter("area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
	for p in params:
		m.set_shader_parameter(p, params[p])
	if params.has("parallax") or params.has("cam_pos"):
		_cam_mats.append(m)
	n.material = m
	return n


func _insert_after(map: Node, after: String, n: Node) -> void:
	var ref := map.get_node_or_null(after)
	map.add_child(n)
	if ref:
		map.move_child(n, ref.get_index() + 1)


func _insert_before(map: Node, before: String, n: Node) -> void:
	var ref := map.get_node_or_null(before)
	map.add_child(n)
	if ref:
		map.move_child(n, ref.get_index())


func _build_mist(map: Node) -> void:
	var count := 0
	# Пропасть: под гранями обрыва (CanyonFace рисуется поверх) — туман внизу
	var chasm := map.get_node_or_null("Chasm") as TileMapLayer
	if chasm:
		var mk := _cell_mask(chasm, 6)
		_masks["chasm"] = mk
		_insert_after(map, "Chasm", _mist_node("ChasmMist", mk[0], mk[1], {
			"mist_color": Color(0.62, 0.64, 0.68), "density": 0.24, "scale": 520.0, "base": 0.0, "parallax": 0.9, "stretch": Vector2(0.85, 1.15),
			"drift": Vector2(12.0, -6.0), "threshold": 0.5, "softness": 0.6}))
		count += 1
	# Река: тонкая дымка над водой
	var water := map.get_node_or_null("Water") as TileMapLayer
	if water:
		var mk := _cell_mask(water, 5)
		_masks["water"] = mk
		_insert_after(map, "Water", _mist_node("RiverMist", mk[0], mk[1], {
			"mist_color": Color(0.66, 0.72, 0.8), "density": 0.3, "scale": 360.0,
			"drift": Vector2(4.0, 10.0), "threshold": 0.48, "softness": 0.6}))
		count += 1
	# Западный овраг (чёрные тайлы в слое South) — маска из tools/immersion_bake.gd
	if ResourceLoader.exists(RAVINE_MASK):
		var rt: Texture2D = load(RAVINE_MASK)
		if rt and rt.has_meta("area"):
			_masks["ravine"] = [_blur_mask(rt.get_image(), 3), rt.get_meta("area")]
			_insert_after(map, "South", _mist_node("RavineMist", _masks["ravine"][0], _masks["ravine"][1], {
				"mist_color": Color(0.62, 0.64, 0.68), "density": 0.22, "scale": 440.0, "base": 0.0, "parallax": 0.9, "stretch": Vector2(0.85, 1.15),
				"drift": Vector2(-10.0, -4.0), "threshold": 0.5, "softness": 0.6}))
			count += 1
	# Болото: стелется по земле под деревьями и пропсами — кроны торчат из него
	var mire := map.get_node_or_null("SouthZones/Zone_Mire/Shape") as CollisionShape2D
	if mire and mire.shape is RectangleShape2D:
		var sz: Vector2 = (mire.shape as RectangleShape2D).size + Vector2(500, 360)
		var area := Rect2(mire.global_position - sz * 0.5, sz)
		_insert_before(map, "Objects", _mist_node("MireMist", _soft_rect_mask(0.28), area, {
			"mist_color": Color(0.6, 0.68, 0.66), "density": 0.32, "scale": 380.0, "base": 0.15,
			"drift": Vector2(8.0, 2.0), "threshold": 0.45, "softness": 0.6}))
		count += 1
	# Старый туман карты: плавный вместо пиксельных ступенек
	var fog := map.get_node_or_null("Atmosphere/Fog") as CanvasItem
	if fog and fog.material is ShaderMaterial:
		(fog.material as ShaderMaterial).set_shader_parameter("pixel", 0.0)
	stats["mist"] = count


# ---------------------------------------------------------------- дым

func _smoke_emitter(at: Vector2, size: float, amount: int, life: float, tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.particles_animation = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	p.material = mat
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.randomness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0 * size
	p.direction = Vector2(0.1, -1)
	p.spread = 22.0
	p.initial_velocity_min = 7.0 * size
	p.initial_velocity_max = 12.0 * size
	# Тёплый дым всплывает, ветер сносит вбок
	p.gravity = Vector2(3.5 * wind_strength, -5.0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -10.0
	p.angular_velocity_max = 10.0
	p.anim_offset_max = 1.0
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 0.75 * size
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 3.4))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	# Цвет больше 1: ночной CanvasModulate (×0.27…0.38) гасит его до
	# серо-синего дыма в лунном свете, у огня он рыжеет от факелов
	g.colors = PackedColorArray([Color(1.1, 1.06, 1.0, 0.0), Color(1.15, 1.12, 1.08, 0.4),
		Color(1.25, 1.25, 1.3, 0.26), Color(1.3, 1.3, 1.35, 0.0)])
	p.color_ramp = g
	return p


func _build_smoke(map: Node) -> void:
	var tex: Texture2D = load(SMOKE_TEX) if ResourceLoader.exists(SMOKE_TEX) else null
	if tex == null:
		return
	var holder := Node2D.new()
	holder.name = "Smoke"
	holder.z_index = 40
	add_child(holder)
	var n := 0
	# Сгоревшие дома и пара тлеющих: столб над крышей
	var picks: Array[Sprite2D] = []
	for h in _houses:
		if str(h.get_meta("village_v2", "")) == "hut_burnt":
			picks.append(h)
	var others := _houses.filter(func(h): return str(h.get_meta("village_v2", "")) != "hut_burnt")
	for i in 3:
		if others.is_empty():
			break
		picks.append(others.pop_at(_rng.randi() % others.size()))
	for h in picks:
		var top := h.global_position + Vector2(_rng.randf_range(-30, 30), -h.region_rect.size.y * absf(h.global_scale.y) * 0.55)
		var big := str(h.get_meta("village_v2", "")) == "hut_burnt"
		holder.add_child(_smoke_emitter(top, 1.2 if big else 0.85, 36 if big else 24, 13.0 if big else 10.0, tex))
		n += 1
	# Костры лагеря и карты: тонкий дымок
	var camp := map.get_node_or_null("Objects/RuinedCamp/Objects")
	if camp:
		for c in camp.get_children():
			var f := c.get_node_or_null("Fire") as Node2D
			if f and not str(c.name).begins_with("HD_torch"):
				holder.add_child(_smoke_emitter(f.global_position + Vector2(0, -24), 0.6, 20, 7.0, tex))
				n += 1
	for nm in ["Night/Fire41", "Night/Fire42"]:
		var f := map.get_node_or_null(nm) as Node2D
		if f:
			holder.add_child(_smoke_emitter(f.global_position + Vector2(0, -20), 0.6, 20, 7.0, tex))
			n += 1
	stats["smoke"] = n


# ---------------------------------------------------------------- облака

func _build_clouds() -> void:
	var n := _ViewDraw.new()
	n.name = "CloudShadows"
	n.z_index = 45
	var m := ShaderMaterial.new()
	m.shader = CLOUD_SHADER
	m.set_shader_parameter("noise", _noise())
	n.material = m
	add_child(n)


# ---------------------------------------------------------------- передний план

func _build_foreground() -> void:
	if not ResourceLoader.exists(FG_TEX):
		return
	var fg := FG_SCRIPT.new() as Node2D
	fg.name = "Foreground"
	fg.z_index = 100
	# Факелы на земле не подсвечивают то, что у самой камеры
	fg.light_mask = 0
	fg.set("atlas", load(FG_TEX))
	fg.set("wind_strength", wind_strength)
	var parts := {}
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FG_JSON))
	for k in meta:
		var r: Array = meta[k]["rect"]
		parts[k] = Rect2(r[0], r[1], r[2], r[3])
	fg.set("parts", parts)
	var m := ShaderMaterial.new()
	m.shader = FG_SHADER
	fg.material = m
	add_child(fg)
	_fg = fg
	var crowns := ["crown_oak", "crown_ancient", "crown_spruce", "crown_weeping", "crown_oak", "crown_spruce"]
	var crowns_purple := ["crown_crimson", "branch_dead", "branch_broken", "crown_crimson"]
	var lows := ["fern", "grass", "twigs", "bush", "fern"]
	# Лес: по клетке 256 px, чем гуще — тем вероятнее ветка у края кадра
	for key in _density:
		var cnt: int = _density[key]
		var p := clampf((cnt - 2) / 7.0, 0.0, 1.0) * 0.6
		if _rng.randf() >= p:
			continue
		var at := Vector2(key) * 256.0 + Vector2(_rng.randf(), _rng.randf()) * 256.0
		var high := _rng.randf() < 0.72
		var pool: Array = (crowns_purple if _purple.has(key) else crowns) if high else lows
		var part: String = pool[_rng.randi() % pool.size()]
		var sc := _rng.randf_range(0.6, 0.95) if high else _rng.randf_range(0.55, 0.85)
		var k := _rng.randf_range(1.35, 1.6) if high else _rng.randf_range(1.25, 1.4)
		fg.call("add_part", at, part, sc, _rng.randf_range(-PI, PI) if high else _rng.randf_range(-0.6, 0.6), _rng.randf() < 0.5, k)
	# Деревня: редкие верёвки с флажками между домами
	var palette := PackedColorArray([Color(0.32, 0.1, 0.08), Color(0.36, 0.3, 0.16), Color(0.3, 0.29, 0.26),
		Color(0.16, 0.2, 0.26), Color(0.26, 0.12, 0.1)])
	var ropes := 0
	for i in _houses.size():
		if i % 3 != 0:
			continue
		var h := _houses[i]
		var a := h.global_position + Vector2(_rng.randf_range(-160, -60), _rng.randf_range(-260, -160))
		var b := a + Vector2(_rng.randf_range(260, 420), _rng.randf_range(-60, 60))
		var cols := PackedColorArray()
		for j in 3:
			cols.append(palette[_rng.randi() % palette.size()])
		fg.call("add_rope", a, b, _rng.randf_range(1.2, 1.32), cols)
		ropes += 1
	stats["foreground"] = fg.call("item_count")
	stats["ropes"] = ropes


# ---------------------------------------------------------------- звук

func _build_sound(map: Node) -> void:
	var s := SOUND_SCRIPT.new() as Node2D
	s.name = "AmbientSound"
	add_child(s)
	_sound = s
	# Река: точка на каждые ~320 px воды
	var water := map.get_node_or_null("Water") as TileMapLayer
	if water:
		for p in _cluster(water, 320.0, 12):
			s.call("add_loop", p, "ambience/river_loop.wav", -7.0, 560.0, _rng.randf_range(0.92, 1.06))
	# Пропасть: глухой ветер снизу
	var chasm := map.get_node_or_null("Chasm") as TileMapLayer
	if chasm:
		for p in _cluster(chasm, 520.0, 40):
			s.call("add_loop", p, "ambience/wind_loop.wav", -10.0, 640.0, _rng.randf_range(0.62, 0.72))
	# Лес: шелест в кронах
	var leaves := 0
	var done := {}
	for key in _density:
		var big := Vector2i(floori(key.x / 2.0), floori(key.y / 2.0))
		if done.has(big):
			continue
		var cnt := 0
		for dy in 2:
			for dx in 2:
				cnt += int(_density.get(Vector2i(big.x * 2 + dx, big.y * 2 + dy), 0))
		if cnt < 14:
			continue
		done[big] = true
		s.call("add_loop", Vector2(big) * 512.0 + Vector2(256, 256), "ambience/leaves_loop.wav", -13.0, 560.0, _rng.randf_range(0.9, 1.1))
		leaves += 1
	# Болото
	var mire := map.get_node_or_null("SouthZones/Zone_Mire/Shape") as CollisionShape2D
	if mire and mire.shape is RectangleShape2D:
		var sz: Vector2 = (mire.shape as RectangleShape2D).size
		var x := -sz.x * 0.5 + 220.0
		while x < sz.x * 0.5:
			var y := -sz.y * 0.5 + 200.0
			while y < sz.y * 0.5:
				s.call("add_loop", mire.global_position + Vector2(x, y), "ambience/swamp_loop.wav", -9.0, 620.0, _rng.randf_range(0.94, 1.06))
				y += 440.0
			x += 460.0
	# Шатры лагеря: хлопает ткань (самые большие, не теснее 300 px)
	var tents := PackedVector2Array()
	for root_path in ["Objects", "Objects/RuinedCamp/Objects"]:
		var r := map.get_node_or_null(root_path)
		if r == null:
			continue
		for c in r.get_children():
			if c is Sprite2D and c.has_meta("hd_prop") and str(c.get_meta("hd_prop")).begins_with("tent_cone"):
				var w := int(str(c.get_meta("hd_prop")).get_slice("@", 1).get_slice("x", 0))
				if w < 380:
					continue
				var pos: Vector2 = (c as Node2D).global_position + Vector2(0, -60)
				var ok := true
				for t in tents:
					if t.distance_to(pos) < 300.0:
						ok = false
				if ok:
					tents.append(pos)
	for t in tents:
		s.call("add_loop", t, "ambience/cloth_loop.wav", -12.0, 420.0, _rng.randf_range(0.9, 1.1))
	# Деревня: скрип ставней у домов, раз в несколько секунд у одного из ближних
	var houses := PackedVector2Array()
	for h in _houses:
		houses.append(h.global_position + Vector2(_rng.randf_range(-40, 40), -40))
	s.call("add_oneshots", houses, ["ambience/creak_1.wav", "ambience/creak_2.wav", "ambience/creak_3.wav"],
		-13.0, 620.0, Vector2(5.0, 13.0), Vector2(0.85, 1.15))
	stats["sound_loops"] = s.call("loop_count")
	stats["leaves"] = leaves


## Центры занятых клеток слоя, сгруппированные по сетке step; min — сколько
## клеток должно быть в группе
func _cluster(l: TileMapLayer, step: float, min_cells: int) -> PackedVector2Array:
	var acc := {}
	for cell in l.get_used_cells():
		var wp := l.to_global(l.map_to_local(cell))
		var key := Vector2i(floori(wp.x / step), floori(wp.y / step))
		if not acc.has(key):
			acc[key] = [Vector2.ZERO, 0]
		acc[key][0] += wp
		acc[key][1] += 1
	var out := PackedVector2Array()
	for key in acc:
		if acc[key][1] >= min_cells:
			out.append(acc[key][0] / float(acc[key][1]))
	return out


# ---------------------------------------------------------------- глубина

func _depth_node(name: String, shader: Shader, mask: Texture2D, area: Rect2, params: Dictionary) -> Node2D:
	var n := _RectDraw.new()
	n.name = name
	n.rect = area
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("noise", _noise())
	m.set_shader_parameter("mask", mask)
	m.set_shader_parameter("area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
	for p in params:
		m.set_shader_parameter(p, params[p])
	_cam_mats.append(m)
	n.material = m
	return n


func _build_depth(map: Node) -> void:
	var n := 0
	var gm := load(GROUND_MATERIAL) as ShaderMaterial if ResourceLoader.exists(GROUND_MATERIAL) else null
	var layers: Variant = gm.get_shader_parameter("ground_layers") if gm else null
	# Пропасть и овраг: далёкое дно, над ним нижний туман — оба отстают при
	# беге; обычный туман (ChasmMist/RavineMist, параллакс 0.9) — выше них
	for key in ["chasm", "ravine"]:
		if not _masks.has(key) or layers == null:
			continue
		var mk: Array = _masks[key]
		var area: Rect2 = mk[1]
		var nm: String = str(key).capitalize()
		var bottom := _depth_node(nm + "Floor", ABYSS_SHADER, mk[0], area, {"ground_layers": layers, "parallax": 0.7, "floor_light": 0.13, "edge_dark": 2.6})
		_insert_after(map, "Chasm" if key == "chasm" else "South", bottom)
		var deep := _mist_node(nm + "DeepMist", mk[0], area, {"mist_color": Color(0.55, 0.58, 0.64), "density": 0.2,
			"scale": 640.0, "base": 0.0, "parallax": 0.8, "drift": Vector2(-7.0, 5.0), "threshold": 0.5, "softness": 0.6})
		map.add_child(deep)
		map.move_child(deep, bottom.get_index() + 1)
		n += 2
	# Река: небо в воде и блики по течению
	if _masks.has("water"):
		var mk: Array = _masks["water"]
		_insert_after(map, "Water", _depth_node("RiverSky", SHEEN_SHADER, mk[0], mk[1], {}))
		n += 1
	stats["depth"] = n


# ---------------------------------------------------------------- тень крон

const WORLD := Rect2(-3520, -704, 8640, 5120)


func _build_canopy(map: Node) -> void:
	if _trees.is_empty():
		return
	var cell := 32.0
	var w := int(WORLD.size.x / cell)
	var h := int(WORLD.size.y / cell)
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	# Луна сверху слева: тень лежит у основания и чуть вправо-вниз
	for p in _trees:
		var c := (p + Vector2(10, 4) - WORLD.position) / cell
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var x := int(c.x) + dx
				var y := int(c.y) + dy
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var d := Vector2(dx, dy * 1.4).length() / 3.2
				var v := clampf(1.0 - d, 0.0, 1.0)
				if v > img.get_pixel(x, y).r:
					img.set_pixel(x, y, Color(v, 0, 0))
	var node := _depth_node("CanopyShade", CANOPY_SHADER, _blur_mask(img, 2), WORLD, {"wind_strength": wind_strength})
	_cam_mats.erase(node.material)
	_insert_before(map, "MireMist" if map.has_node("MireMist") else "Objects", node)
	stats["canopy_trees"] = _trees.size()


# ---------------------------------------------------------------- отклик и живность

func _build_response(map: Node) -> void:
	var r := RESPONSE_SCRIPT.new() as Node2D
	r.name = "HeroTraces"
	r.call("setup", map)
	r.add_to_group("surface_provider")
	_insert_before(map, "MireMist" if map.has_node("MireMist") else "Objects", r)
	# Лагерь: его земля рисуется внутри Objects и закрыла бы следы — там
	# следы рисует второй узел прямо над землёй лагеря
	var area := _camp_ground_area(map)
	if area.has_area():
		r.set("skip", area)
		var v := RESPONSE_SCRIPT.new() as Node2D
		v.name = "CampTraces"
		v.set("core", r)
		v.set("clip", area)
		_add_to_camp_ground(map, v)


## Прямоугольник земли лагеря в мире (маска грязи: 4 мировых px на тексель)
func _camp_ground_area(map: Node) -> Rect2:
	var camp := map.get_node_or_null("Objects/RuinedCamp") as Node2D
	var mg := camp.get_node_or_null("MudGround") as Sprite2D if camp else null
	if mg == null or mg.texture == null:
		return Rect2()
	return Rect2(mg.global_position, mg.texture.get_size() * mg.global_scale)


## Узел в лагерь сразу над его землёй (после FloorDecals): та же точка
## сортировки, что у земли, поэтому пропсы и герой рисуются поверх
func _add_to_camp_ground(map: Node, n: Node2D) -> void:
	var camp := map.get_node("Objects/RuinedCamp")
	# На 2 px ниже земли: при равной точке сортировки порядок не гарантирован
	n.position = Vector2(0, 2)
	camp.add_child(n)
	var ref := camp.get_node_or_null("FloorDecals")
	if ref:
		camp.move_child(n, ref.get_index() + 1)


func _build_critters(map: Node) -> void:
	var crows := CRITTERS_SCRIPT.new() as Node2D
	crows.name = "Crows"
	crows.set("kind", "crows")
	crows.z_index = 30
	add_child(crows)
	# Брус виселицы — по обе стороны от петли
	if _gallows_rect.size != Vector2.ZERO:
		var g := _gallows_rect
		for u in [0.17, 0.3, 0.83]:
			crows.call("add_spot", Vector2(g.position.x + g.size.x * u, g.position.y + g.size.y * 0.075))
	# Коньки сгоревших крыш
	for hs in _houses:
		if str(hs.get_meta("village_v2", "")) != "hut_burnt":
			continue
		var r := Rect2(hs.to_global(hs.get_rect().position), hs.get_rect().size * hs.global_scale)
		crows.call("add_spot", Vector2(r.position.x + r.size.x * 0.42, r.position.y + r.size.y * 0.2))
		crows.call("add_spot", Vector2(r.position.x + r.size.x * 0.58, r.position.y + r.size.y * 0.21))
	# Поле у пугала: клюют землю
	for c in map.get_node("Objects").get_children():
		if c is Sprite2D and str(c.get_meta("hd_prop", "")).begins_with("scarecrow"):
			var base: Vector2 = (c as Node2D).global_position
			for off in [Vector2(-70, 18), Vector2(-48, 34), Vector2(60, 26), Vector2(84, 6), Vector2(30, 48)]:
				crows.call("add_spot", base + off, true)
	# Крысы — у мешков, бочек, ящиков и телег лагеря; рисуются под пропсами
	var rats := CRITTERS_SCRIPT.new() as Node2D
	rats.name = "Rats"
	rats.set("kind", "rats")
	rats.set("flee_radius", 110.0)
	rats.set("respawn_time", 20.0)
	var spots := PackedVector2Array()
	var camp := map.get_node_or_null("Objects/RuinedCamp/Objects")
	if camp:
		for c in camp.get_children():
			var nm := str(c.get_meta("hd_prop", ""))
			if c is Sprite2D and (nm.begins_with("sacks") or nm.begins_with("barrel") or nm.begins_with("crate") or nm.begins_with("cart")):
				var w := float(nm.get_slice("@", 1).get_slice("x", 0)) * absf((c as Node2D).global_scale.x)
				var at: Vector2 = (c as Node2D).global_position + Vector2(_rng.randf_range(-0.45, 0.45) * w, 15.0)
				var ok := true
				for s in spots:
					if s.distance_to(at) < 150.0:
						ok = false
				if ok:
					spots.append(at)
	for s in spots:
		rats.call("add_spot", s)
	if map.has_node("Objects/RuinedCamp"):
		_add_to_camp_ground(map, rats)
	else:
		_insert_before(map, "Objects", rats)
	stats["crows"] = crows.call("spot_count")
	stats["rats"] = rats.call("spot_count")


# ---------------------------------------------------------------- камера

func _build_camera(map: Node) -> void:
	var edges := PackedVector2Array()
	for ln in ["Chasm", "Canyon", "Cliffs"]:
		var l := map.get_node_or_null(ln) as TileMapLayer
		if l:
			for cell in l.get_used_cells():
				edges.append(l.to_global(l.map_to_local(cell)))
	if _masks.has("ravine"):
		var img: Image = (_masks["ravine"][0] as Texture2D).get_image()
		var area: Rect2 = _masks["ravine"][1]
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y).r > 0.5:
					edges.append(area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * area.size / Vector2(img.get_size()))
	var houses := PackedVector2Array()
	for h in _houses:
		houses.append(h.global_position)
	var cz := CAMERA_SCRIPT.new()
	cz.name = "CameraZones"
	add_child(cz)
	cz.call("setup", _trees, edges, houses, _camp_ground_area(map))
	var lo := 9.0
	var hi := 0.0
	for z in cz.get("_grid"):
		lo = minf(lo, z)
		hi = maxf(hi, z)
	stats["camera_zoom"] = "%.2f..%.2f" % [lo, hi]


# ---------------------------------------------------------------- помощники

## Прямоугольник в мире под шейдер (туман)
class _RectDraw extends Node2D:
	var rect := Rect2()

	func _draw() -> void:
		draw_rect(rect, Color.WHITE)


## Прямоугольник на весь кадр, каждый кадр под камерой (тени облаков)
class _ViewDraw extends Node2D:
	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport()
		var inv := vp.get_canvas_transform().affine_inverse()
		var vs := vp.get_visible_rect().size
		var a: Vector2 = inv * Vector2.ZERO
		var b: Vector2 = inv * vs
		draw_rect(Rect2(a, b - a).grow(32.0), Color.WHITE)
