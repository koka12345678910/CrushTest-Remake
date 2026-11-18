extends SceneTree
## Блокаут Хольмвика (reference_map) по согласованному плану карты:
## вход в деревню внизу слева → путь через деревню (завалы заставляют петлять,
## по дороге учебные враги) → храм Света Бальдра у реки, обязательный босс.
## Это черновая разметка маршрута: арт (дома, храм, ворота, баррикады, трупы)
## заменится потом, логика и коллизия останутся.
##
## Шаги:
##   bake  — textures/blockout/palisade_side.png: кусок частокола сбоку (стена
##           вдоль взгляда — два ряда брёвен из camp_hd), потом нужен --import;
##   clean — убрать лагерь, болото (враги, костёр, зоны, огоньки, маркеры),
##           верёвочный мост и каменный мост через пропасть. Повторять можно;
##   apply — всё своё (узлы с метой "blockout") удаляется и строится заново:
##           частокол с севера и юга от западной границы до реки (с востока —
##           река), южные ворота (закрыты, по сюжету), старт и костёр у них;
##           две линии баррикад поперёк деревни (у BARRIERS проход только с
##           одной стороны) — маршрут змейкой; завал на мосту через реку;
##           храм-заглушка (часовня крупнее) и двор-арена с боссом, костёр у
##           входа; учебные враги по пути; фонари; границы камеры. Деревья и
##           стволы на линиях стен вырубаются.
##
## Запуск (сцену держит открытый редактор Godot — при "Can't open" повтори,
## и не сохраняй потом старую сцену из редактора):
##   godot --headless --path . -s res://tools/holmvik_blockout.gd -- bake
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/holmvik_blockout.gd -- clean apply
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res

const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const HD := TEX + "hd_props.png"
const HD_META := TEX + "hd_props.json"
const CAMP := TEX + "camp_hd.png"
const CAMP_META := TEX + "camp_hd.json"
## Арт партии 2 (tools/holmvik_art2.gd): частокол, ворота, завалы, вход в храм
const TOWN := TEX + "town_props_hd.png"
const TOWN_META := TEX + "town_props_hd.json"
const SIDE := TEX + "blockout/palisade_side.png"
const ZONES := TEX + "terrain/zones.res"
const META := "blockout"
## camp_hd.png и hd_props.png запечены вдвое плотнее мира
const TPX := 2.0

## Частокол верхнего города: западная граница карты, север и юг (юг —
## внутренняя стена между верхним и нижним городом)
const WALL_W := -2960.0
const WALL_N := -600.0
## Восточный край северной стены и верх реки: от реки до северной стены —
## своя восточная стена (река начинается ниже)
const NORTH_E := 1990.0
const RIVER_TOP := -110.0
## Верх города: лес вырубается, кроме этой доли
const NORTH_KEEP_TREES := 0.08
const WALL_S := 1880.0
const WALL_THICK := 14.0
## Внутренние ворота (открыты): центр и ширина проёма; внутренняя стена
## доходит до EAST_END (через причал — иначе по нему обход)
const GATE_X := -1910.0
const GATE_W := 120.0
const INNER_EAST_END := 2070.0
const BONFIRE_INNER := Vector2(-1700, 1770)
## Нижний город: внешний частокол по OUTER_S, восточная стена по OUTER_E
## (от конца реки), внешние ворота (вход, закрыты — по сюжету)
const OUTER_S := 2600.0
const OUTER_E := 1960.0
const OUTER_E_TOP := 1866.0
const OUTER_GATE_X := 1150.0
const SPAWN := Vector2(1150, 2530)
const BONFIRE_GATE := Vector2(960, 2470)
## Лес в нижнем городе вырубается, кроме этой доли деревьев
const LOWER_KEEP_TREES := 0.12
## Болото: полигоны воды, которые остаются (река, овраг)
const KEEP_WATER := ["Water13", "Water14", "Water15"]

## Линии баррикад поперёк города: [x, проход (y от-до)]. Вдоль линии от
## частокола до частокола всё, что не закрыто коллизией домов, заваливается
## хламом — кроме прохода. Первая — проход по северной улице, вторая — по южной
const BARRIERS := [
	[-950.0, Vector2(560, 690)],
	[150.0, Vector2(1470, 1610)],
]
## Коллизия толще этого считается стеной дома (а не стволом и т.п.)
const COVER_MIN := 40.0
## Учебные враги и босс: узел -> точка (≥450 px от костров)
const ENEMIES := {
	"Enemy_Town5": Vector2(-1550, 1150),
	"Enemy_Town1": Vector2(-1150, 1060),
	"Enemy_Town2": Vector2(-880, 420),
	"Enemy_Town4": Vector2(-280, 620),
	"Enemy_Town6": Vector2(200, 1700),
	"Enemy_Town3": Vector2(310, 1170),
	"Enemy_FortElite": Vector2(1180, 1060),
	# Нижний город
	"Enemy_SouthRoad1": Vector2(300, 2240),
	"Enemy_SouthRoad2": Vector2(-1350, 2230),
	"Enemy_Hermit": Vector2(-2450, 2250),
}
## Храм: настоящий (tools/holmvik_town.gd, мета town_v2 = temple_baldr) или
## заглушка — часовня (House1) крупнее. Основание, полуширина подножия;
## двор-арена перед ним
const TEMPLE_SRC := "House1"
const TEMPLE_BASE := Vector2(1090, 880)
const TEMPLE_SCALE := 0.85
const TEMPLE_HALF := 270.0
const ARENA := Rect2(770, 880, 650, 380)
## Вход во двор храма — каменные врата посередине южной стенки (x центра,
## ширина прохода). С главной улицы двор закрыт стеной: путь — переулком
## к храму на юг, мимо костра, и вдоль южной стенки к вратам
const ARENA_GATE_X := 1090.0
const ARENA_GATE_W := 110.0
const BONFIRE_TEMPLE := Vector2(700, 1320)
## Фонари вдоль маршрута (основание столба); в городе их ставит holmvik_town.gd
const LANTERNS := []
## Завалы поперёк улиц (арт партии 2): [ключ, масштаб]
const JUNK := [
	["bar_cart", 0.55], ["bar_planks", 0.55], ["bar_furniture", 0.65], ["bar_beam", 0.55], ["bar_stakes", 0.6],
]
## Шаг кусков завала вдоль линии (px)
const JUNK_STEP := 30.0
## Доля повреждённых секций частокола; шаг угловых башен
const DAMAGED_SHARE := 0.18
const TOWER_EVERY := 1300.0
## Удаляются шагом clean (пути от корня карты)
const CLEAN := [
	"Objects/RuinedCamp", "Objects/BonfireCamp", "Objects/BonfireMire",
	"Objects/Enemy_Camp1", "Objects/Enemy_Camp2", "Objects/Enemy_Camp3", "Objects/Enemy_Camp4",
	"Objects/Enemy_Camp5", "Objects/Enemy_Camp6", "Objects/Enemy_Camp7",
	"Objects/Enemy_Mire1", "Objects/Enemy_Mire2", "Objects/Enemy_Mire3",
	"SouthZones/Zone_Mire", "SouthZones/Zone_DrownedShrine", "SouthZones/Zone_RopeBridge",
	"Markers/BogLurker1", "Markers/BogLurker2", "Markers/BogLurker3", "Markers/MireEntry",
	"Markers/MireExit", "Markers/DrownedShrine", "Markers/RopeBridge",
	"SouthBridges/RopeBridge", "BridgeDecks/Fort1",
]
## Мостки причала, доходящие до восточного берега (высота настила)
const JETTY_Y := [1300.0, 1485.0]
## Где стояли убранные мосты — там теперь пропасть (коллизия)
const BRIDGE_BLOCKS := [Rect2(3243, 1274, 422, 152)]

var report: Array[String] = []
var _hd_meta: Dictionary
var _camp_meta: Dictionary
var _hd: Texture2D
var _camp: Texture2D
var _town: Texture2D
var _town_meta: Dictionary
var _side: Texture2D
var _water: Array = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["apply"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[holmvik_blockout] ", r)
	quit()


# ───────────────────────── bake ─────────────────────────

## Кусок боковой стены: брёвна log_a/log_b двумя рядами вразбежку на
## SIDE_LEN px мира; основание куска — низ картинки
const SIDE_LEN := 96.0
const LOG_STEP := 4.5
const LOG_SIDE := 5.0

func _step_bake() -> void:
	var camp_img := (load(CAMP) as Texture2D).get_image()
	camp_img.decompress()
	camp_img.convert(Image.FORMAT_RGBA8)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAMP_META))
	var la: Array = meta["log_a"]
	var lb: Array = meta["log_b"]
	var log_h := int(la[3])
	var w := int((LOG_SIDE * 2 + 6) * TPX) + int(la[2])
	var h := int(SIDE_LEN * TPX) + log_h
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := int(SIDE_LEN / LOG_STEP)
	for k in n:
		var r: Array = la if (k / 2) % 3 != 0 else lb
		var piece := camp_img.get_region(Rect2i(r[0], r[1], r[2], r[3]))
		var dk := 0.72 + 0.12 * _hash(k, 77)
		for y in piece.get_height():
			for x in piece.get_width():
				var c := piece.get_pixel(x, y)
				piece.set_pixel(x, y, Color(c.r * dk, c.g * dk * 0.95, c.b * dk * 0.9, c.a))
		var side := -LOG_SIDE if k % 2 == 0 else LOG_SIDE
		var cx := w * 0.5 + (side + (_hash(k, 31) - 0.5) * 3.0) * TPX
		var base_y := (k + 1) * LOG_STEP * TPX + log_h
		out.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(int(cx - piece.get_width() * 0.5), int(base_y - piece.get_height())))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SIDE.get_base_dir()))
	var err := out.save_png(ProjectSettings.globalize_path(SIDE))
	report.append("bake: %s %dx%d (%s); дальше --import" % [SIDE, w, h, error_string(err)])


# ───────────────────────── south (овраг и болото) ─────────────────────────
## Овраг (чёрная пустота в слое South, вход в нижний город) и болото за
## внешней стеной (тёмная вода в South) — неуместны: тёмные клетки South
## заменяются землёй, скопированной блоками из соседнего леса (один столбец
## на всю ширину дал бы полосы); вода оврага, сломанный мост, туман оврага,
## болотные декали и тростник — долой. Повторять можно.
const SOUTH_AREA := Rect2(-2960, 1880, 4900, 2100)
const DARK_LUM := 0.11
const RAVINE_MASK := "res://reference_map_level/textures/immersion/ravine_mask.res"
## Овраг и болото целиком; образцы травы (мировые точки на чистом лугу)
const WET_ZONES: Array[Rect2] = [Rect2(-1130, 1880, 540, 920), Rect2(-960, 2700, 720, 620), Rect2(-520, 2520, 1880, 840)]
const GRASS_GROUND_AT := Vector2(1000, 1500)


func _step_south() -> void:
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var south := lvl.get_node("South") as TileMapLayer
	# Слой South разреженный: в нём только сам овраг, болото и их кромки
	# (обычная трава юга — FrameGround ниже). Клетки South в зонах оврага и
	# болота стираются — открывается трава; тёмные клетки вне зон тоже
	var lum_cache := {}
	var img_cache := {}
	var cleared := 0
	for cell in south.get_used_cells():
		var p := south.transform * south.map_to_local(cell)
		if not SOUTH_AREA.has_point(p):
			continue
		if _in_bands(p, WET_ZONES) or _tile_lum(south, cell, lum_cache, img_cache) < DARK_LUM:
			south.erase_cell(cell)
			cleared += 1
	# Верх оврага в слое Ground (внутри нижнего города) — травой луга (Ground
	# тоже перерисовывает шейдер: одна клетка не даёт повторов)
	var ground := lvl.get_node("Ground") as TileMapLayer
	var gg := ground.local_to_map(ground.transform.affine_inverse() * GRASS_GROUND_AT)
	var g2 := [ground.get_cell_source_id(gg), ground.get_cell_atlas_coords(gg), ground.get_cell_alternative_tile(gg)]
	if g2[0] == -1:
		report.append("ОТКАЗ south: в GRASS_GROUND_AT нет клетки Ground")
		lvl.free()
		return
	var flat := 0
	for cell in ground.get_used_cells():
		if _in_bands(ground.transform * ground.map_to_local(cell), WET_ZONES) and _tile_lum(ground, cell, lum_cache, img_cache) < 0.2:
			ground.set_cell(cell, g2[0], g2[1], g2[2])
			flat += 1
	report.append("south: клеток South стёрто %d, тёмных Ground заменено травой %d" % [cleared, flat])
	# Болотные декали (SouthMarks) и тростник/кувшинки в зоне болота и оврага
	var wet: Array[Rect2] = WET_ZONES
	var marks := lvl.get_node("SouthMarks") as TileMapLayer
	var erased := 0
	for cell in marks.get_used_cells():
		if _in_bands(marks.transform * marks.map_to_local(cell), wet):
			marks.erase_cell(cell)
			erased += 1
	for l in lvl.get_node("Objects").get_children():
		if not (l is TileMapLayer):
			continue
		var layer := l as TileMapLayer
		for cell in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if src == null or not src.has_meta("hd_prop"):
				continue
			var k := str(src.get_meta("hd_prop")).get_slice("@", 0)
			if (k.begins_with("reeds") or k.begins_with("lily")) and _in_bands(layer.transform * layer.map_to_local(cell), wet):
				layer.erase_cell(cell)
				erased += 1
	# Вода оврага, сломанный мост и его маркеры/зона
	var gone := 0
	for c in lvl.get_node("Collision").get_children():
		if c is CollisionPolygon2D and String(c.name) in ["Water16", "Water31"]:
			c.get_parent().remove_child(c)
			c.free()
			gone += 1
	# Огоньки болота (свет) и свеча у сломанного моста
	for c in lvl.get_node("Night").get_children():
		var cn := String(c.name)
		if cn.begins_with("Wisp") or cn == "Candle31":
			c.get_parent().remove_child(c)
			c.free()
			gone += 1
	for path in ["SouthBridges", "SouthZones/Zone_BrokenBridge", "Markers/BrokenBridge", "Markers/BridgeCache"]:
		var n := lvl.get_node_or_null(path)
		if n == null:
			continue
		if path == "SouthBridges":
			for c in n.get_children():
				n.remove_child(c)
				c.free()
				gone += 1
		else:
			n.get_parent().remove_child(n)
			n.free()
			gone += 1
	report.append("south: декалей и тростника убрано %d; воды, моста и маркеров %d" % [erased, gone])
	_save(lvl)
	# Туман и «дно» оврага (immersion) строятся по этой маске — без неё их нет
	if FileAccess.file_exists(ProjectSettings.globalize_path(RAVINE_MASK)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RAVINE_MASK))
		report.append("south: маска оврага удалена (%s)" % RAVINE_MASK)


func _tile_lum(l: TileMapLayer, cell: Vector2i, cache: Dictionary, imgs: Dictionary) -> float:
	var sid := l.get_cell_source_id(cell)
	var ac := l.get_cell_atlas_coords(cell)
	var key := Vector3i(sid, ac.x, ac.y)
	if cache.has(key):
		return cache[key]
	var src := l.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null:
		return 1.0
	if not imgs.has(sid):
		var im := src.texture.get_image()
		if im.is_compressed():
			im.decompress()
		imgs[sid] = im
	var im2: Image = imgs[sid]
	var reg := src.get_tile_texture_region(ac)
	var s := 0.0
	var n := 0
	for y in range(reg.position.y, reg.end.y, 3):
		for x in range(reg.position.x, reg.end.x, 3):
			var c := im2.get_pixel(x, y)
			if c.a > 0.5:
				s += c.get_luminance()
				n += 1
	var v := s / maxf(n, 1) if n > 0 else 1.0
	cache[key] = v
	return v


# ───────────────────────── clean ─────────────────────────

func _step_clean() -> void:
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var n := 0
	for p in CLEAN:
		var c := lvl.get_node_or_null(p)
		if c:
			c.get_parent().remove_child(c)
			c.free()
			n += 1
	# Огоньки болота
	var fx := lvl.get_node_or_null("SouthFX")
	if fx:
		for c in fx.get_children():
			fx.remove_child(c)
			c.free()
			n += 1
	# Вода болота (коллизия) — кроме реки и оврага
	var water := 0
	for c in lvl.get_node("Collision").get_children():
		if c is CollisionPolygon2D and not KEEP_WATER.has(String(c.name)):
			var bb := Rect2((c as CollisionPolygon2D).polygon[0], Vector2.ZERO)
			for v in (c as CollisionPolygon2D).polygon:
				bb = bb.expand(v)
			if bb.position.y > 2500.0 and bb.position.x > -400.0 and bb.end.x < 1300.0:
				c.get_parent().remove_child(c)
				c.free()
				water += 1
	report.append("clean: убрано узлов %d (лагерь, болото, мосты), воды болота %d" % [n, water])
	_save(lvl)
	# Земля болота: маска зон (R — болото) обнуляется
	var zones := (load(ZONES) as Texture2D).get_image()
	zones.convert(Image.FORMAT_RGBA8)
	var cleared := 0
	for y in zones.get_height():
		for x in zones.get_width():
			var c := zones.get_pixel(x, y)
			if c.r > 0.0:
				c.r = 0.0
				zones.set_pixel(x, y, c)
				cleared += 1
	var err := ResourceSaver.save(ImageTexture.create_from_image(zones), ZONES)
	report.append("clean: болото в zones.res снято с %d текселей (%s)" % [cleared, error_string(err)])


# ───────────────────────── apply ─────────────────────────

func _step_apply() -> void:
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	_hd_meta = JSON.parse_string(FileAccess.get_file_as_string(HD_META))
	_camp_meta = JSON.parse_string(FileAccess.get_file_as_string(CAMP_META))
	_hd = load(HD)
	_camp = load(CAMP)
	_side = load(SIDE) if ResourceLoader.exists(SIDE) else null
	if _side == null:
		report.append("ОШИБКА: нет %s — сначала bake и --import" % SIDE)
		lvl.free()
		return
	_town = load(TOWN) if ResourceLoader.exists(TOWN) else null
	if _town == null:
		report.append("ОШИБКА: нет %s — сначала holmvik_art2.gd -- atlas и --import" % TOWN)
		lvl.free()
		return
	_town_meta = JSON.parse_string(FileAccess.get_file_as_string(TOWN_META))
	_load_water(lvl)
	var removed := _remove_nodes(lvl)
	var objects := lvl.get_node("Objects")
	var bank_n := NORTH_E
	var bank_s := _bank_x(WALL_S)

	var root := Node2D.new()
	root.name = "Blockout"
	root.set_meta(META, true)
	lvl.add_child(root)
	lvl.move_child(root, objects.get_index() + 1)
	root.owner = lvl
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	_add(root, walls, lvl)

	# Полосы, где вырубаются деревья (стены, баррикады, двор храма)
	var bands: Array[Rect2] = [
		Rect2(WALL_W, WALL_N - 26, bank_n - WALL_W + 20, 40),
		Rect2(WALL_W, WALL_S - 26, bank_s - WALL_W + 20, 40),
		Rect2(WALL_W, OUTER_S - 26, OUTER_E - WALL_W + 20, 40),
		Rect2(OUTER_E - 26, OUTER_E_TOP, 52, OUTER_S - OUTER_E_TOP),
		ARENA.grow(30), Rect2(TEMPLE_BASE.x - 260, TEMPLE_BASE.y - 120, 520, 140),
		# Ворота-башни и подходы к ним с обеих сторон
		Rect2(GATE_X - 170, WALL_S - 140, 340, 280), Rect2(OUTER_GATE_X - 170, OUTER_S - 140, 340, 280),
	]
	for b in BARRIERS:
		bands.append(Rect2(b[0] - 26, WALL_N, 52, WALL_S - WALL_N))
	var trees := _erase_foliage(lvl, bands)
	var trunks := _erase_trunks(lvl, bands)
	# Нижний город: лес вырубить, оставить редкие деревья (их стволы — тоже)
	var lower := Rect2(WALL_W, WALL_S + 20, OUTER_E - WALL_W, OUTER_S - WALL_S - 30)
	var kept: Array[Vector2] = []
	trees += _thin_foliage(lvl, lower, LOWER_KEEP_TREES, kept)
	trunks += _erase_trunks(lvl, [lower], kept)
	# Верх города (бывший лес за старой северной стеной) — так же
	var upper := Rect2(WALL_W, WALL_N + 10, NORTH_E - WALL_W, 80 - WALL_N)
	var kept_n: Array[Vector2] = []
	trees += _thin_foliage(lvl, upper, NORTH_KEEP_TREES, kept_n)
	trunks += _erase_trunks(lvl, [upper], kept_n)
	# Граница карты: старая верхняя (y -176) теперь внутри города — долой;
	# новые — сверху и на западе выше старой
	var col := lvl.get_node("Collision")
	var shp: Array = col.get("shapes")
	var sxf: Array = col.get("shape_transforms")
	var ns2: Array[Shape2D] = []
	var nx2: Array[Transform2D] = []
	for i in shp.size():
		var rs := shp[i] as RectangleShape2D
		if rs and rs.size.x > 4000.0 and (sxf[i] as Transform2D).origin.y < 0.0:
			continue
		ns2.append(shp[i])
		nx2.append(sxf[i])
	col.set("shapes", ns2)
	col.set("shape_transforms", nx2)
	_rect(walls, lvl, "MapTop", Rect2(-3100, WALL_N - 140, 9600, 30))
	_rect(walls, lvl, "MapWestTop", Rect2(WALL_W - 48, WALL_N - 140, 48, 140 - WALL_N))

	# 1. Частокол: север, внутренняя стена (ворота открыты), нижний город
	var sec := 0
	var g0 := GATE_X - GATE_W * 0.5
	var g1 := GATE_X + GATE_W * 0.5
	var ghw: float = _town_meta["pal_gatehouse"][2] / TPX * 0.5
	sec += _pal_row(objects, lvl, WALL_W, bank_n + 10, WALL_N, Vector2.ZERO)
	sec += _pal_row(objects, lvl, WALL_W, bank_s + 10, WALL_S, Vector2(GATE_X - ghw, GATE_X + ghw))
	_rect(walls, lvl, "WallN", Rect2(WALL_W, WALL_N - WALL_THICK, bank_n + 20 - WALL_W, WALL_THICK))
	# Восточная стена верха: от северной стены до начала реки
	_rect(walls, lvl, "WallNE", Rect2(NORTH_E - WALL_THICK * 0.5, WALL_N - 10, WALL_THICK, RIVER_TOP - WALL_N + 40))
	var ne_sides := _side_wall(objects, lvl, NORTH_E, WALL_N + 20.0, RIVER_TOP + 30.0)
	_rect(walls, lvl, "WallS_W", Rect2(WALL_W, WALL_S - WALL_THICK, g0 - WALL_W, WALL_THICK))
	_rect(walls, lvl, "WallS_E", Rect2(g1, WALL_S - WALL_THICK, INNER_EAST_END - g1, WALL_THICK))
	# Внутренние ворота — открыты
	_gatehouse(objects, lvl, walls, GATE_X, WALL_S, "BO_InnerGate")
	# Внешний частокол нижнего города и восточная стена
	sec += _pal_row(objects, lvl, WALL_W, OUTER_E + 10, OUTER_S, Vector2(OUTER_GATE_X - ghw, OUTER_GATE_X + ghw), "BO_OuterPal")
	_rect(walls, lvl, "OuterS", Rect2(WALL_W, OUTER_S - WALL_THICK, OUTER_E + 20 - WALL_W, WALL_THICK))
	_rect(walls, lvl, "OuterE", Rect2(OUTER_E - WALL_THICK * 0.5, OUTER_E_TOP, WALL_THICK, OUTER_S - OUTER_E_TOP))
	var east_sides := _side_wall(objects, lvl, OUTER_E, OUTER_E_TOP + 20.0, OUTER_S - 20.0)
	# Внешние ворота: Хальвард вошёл, за ним рухнула балка — проход завален
	_gatehouse(objects, lvl, walls, OUTER_GATE_X, OUTER_S, "BO_OuterGate")
	var gb := _sprite(objects, lvl, "town", "bar_beam", Vector2(OUTER_GATE_X, OUTER_S + 24), "BO_GateRubble")
	gb.scale *= 0.62

	# 2. Старт и костры: у внешних ворот, у внутренних, у храма
	var spawn := objects.get_node("PlayerSpawn") as Node2D
	spawn.position = SPAWN
	var ps := lvl.get_node_or_null("Markers/PlayerStart") as Node2D
	if ps:
		ps.position = SPAWN
	var market := objects.get_node("BonfireMarket")
	_bonfire(objects, lvl, market, "BonfireGate", "Нижние ворота", BONFIRE_GATE)
	_bonfire(objects, lvl, market, "BonfireInner", "Южные ворота", BONFIRE_INNER)
	_bonfire(objects, lvl, market, "BonfireTemple", "Храм Света Бальдра", BONFIRE_TEMPLE)
	var sr := objects.get_node_or_null("BonfireSouthRoad")
	if sr:
		sr.set("bonfire_name", "Нижний город")
	# Камера — город с окрестностями (за стенами — потом)
	var bank_max := maxf(bank_n, maxf(bank_s, OUTER_E))
	var cam_top := int(WALL_N - 90)
	spawn.set("camera_limits", Rect2i(int(WALL_W - 48), cam_top, int(bank_max + 520 - WALL_W + 48), int(OUTER_S + 270) - cam_top))

	# 3. Баррикады поперёк города: промежутки между домами на линии
	var junk := 0
	for b in BARRIERS:
		var x: float = b[0]
		var segs := _barrier_segments(lvl, x, b[1])
		report.append("баррикада x%.0f: завалы %s" % [x, segs])
		for seg in segs:
			var y0: float = seg[0]
			var y1: float = seg[1]
			_rect(walls, lvl, "Barrier%d_%d" % [int(x), int(y0)], Rect2(x - 20, y0 - 8, 40, y1 - y0 + 16))
			var y := y0 + 18.0
			var k := 0
			# Куски завала вразбежку — читается сплошной стеной хлама
			while y <= y1 + 4.0:
				var j: Array = JUNK[int(_hash(int(x) + k, int(y)) * JUNK.size()) % JUNK.size()]
				var side := -8.0 if k % 2 == 0 else 8.0
				var s := _sprite(objects, lvl, "town", j[0], Vector2(x + side + (_hash(k, int(y)) - 0.5) * 8.0, y), "BO_Junk%d" % junk)
				s.scale *= float(j[1])
				s.flip_h = _hash(int(y), k) > 0.5
				junk += 1
				k += 1
				y += JUNK_STEP
	# Завал на мосту через реку (дальше — после демо)
	var bx := _bridge_x()
	var span := _span(bx)
	_rect(walls, lvl, "BridgeBlock", Rect2(bx - 16, span.x - 10, 32, span.y - span.x + 20))
	var bb := _sprite(objects, lvl, "town", "bar_furniture", Vector2(bx, span.y + 4), "BO_BridgeJunk0")
	bb.scale *= 0.55
	# Мостки причала доходят до восточного берега — тоже завал (иначе реку
	# переходят по ним)
	var ji := 0
	for jy in JETTY_Y:
		var jx := _bridge_x(jy)
		var js := _span(jx, jy)
		_rect(walls, lvl, "JettyBlock%d" % ji, Rect2(jx - 16, js.x - 10, 32, js.y - js.x + 20))
		var jj := _sprite(objects, lvl, "town", "bar_stakes", Vector2(jx, js.y + 4), "BO_JettyJunk%d" % ji)
		jj.scale *= 0.45
		report.append("мостки y%.0f: завал x%.0f, суша y%s" % [jy, jx, js])
		ji += 1
	# Пропасть на месте убранных мостов
	var bi := 0
	for r in BRIDGE_BLOCKS:
		_rect(walls, lvl, "GoneBridge%d" % bi, r)
		bi += 1

	# 4. Храм (настоящий из городка или заглушка) и двор-арена
	var real_temple := false
	for c in objects.get_children():
		if str(c.get_meta("town_v2", "")) == "temple_baldr":
			real_temple = true
	var tw := TEMPLE_HALF * 2.0
	if not real_temple:
		var src := objects.get_node(TEMPLE_SRC) as Sprite2D
		var temple := src.duplicate() as Sprite2D
		temple.name = "BO_Temple"
		temple.position = TEMPLE_BASE
		temple.scale = Vector2.ONE * TEMPLE_SCALE
		temple.set_meta(META, true)
		for m in ["house", "village_v2"]:
			if temple.has_meta(m):
				temple.remove_meta(m)
		objects.add_child(temple)
		temple.owner = lvl
		_rect(walls, lvl, "Temple", Rect2(TEMPLE_BASE.x - tw * 0.5, TEMPLE_BASE.y - 70, tw, 70))
	var a := ARENA
	var gwk: float = _town_meta["tmp_gateway"][2] / TPX * 0.5
	var ag0 := ARENA_GATE_X - ARENA_GATE_W * 0.5
	var ag1 := ARENA_GATE_X + ARENA_GATE_W * 0.5
	_rect(walls, lvl, "ArenaS_W", Rect2(a.position.x, a.end.y - WALL_THICK, ag0 - a.position.x, WALL_THICK))
	_rect(walls, lvl, "ArenaS_E", Rect2(ag1, a.end.y - WALL_THICK, a.end.x - ag1, WALL_THICK))
	_rect(walls, lvl, "ArenaW", Rect2(a.position.x - WALL_THICK * 0.5, a.position.y - 30, WALL_THICK, a.size.y + 30))
	_rect(walls, lvl, "ArenaE", Rect2(a.end.x - WALL_THICK * 0.5, a.position.y - 30, WALL_THICK, a.size.y + 30))
	_rect(walls, lvl, "ArenaNW", Rect2(a.position.x, a.position.y - 30, TEMPLE_BASE.x - tw * 0.5 - a.position.x, 30))
	_rect(walls, lvl, "ArenaNE", Rect2(TEMPLE_BASE.x + tw * 0.5, a.position.y - 30, a.end.x - TEMPLE_BASE.x - tw * 0.5, 30))
	# Каменные врата и стенка двора; столбы врат — упоры
	_sprite(objects, lvl, "town", "tmp_gateway", Vector2(ARENA_GATE_X, a.end.y + 6), "BO_TempleGate")
	_rect(walls, lvl, "TempleGate_L", Rect2(ARENA_GATE_X - gwk, a.end.y - 40, gwk - ARENA_GATE_W * 0.5, 46))
	_rect(walls, lvl, "TempleGate_R", Rect2(ag1, a.end.y - 40, gwk - ARENA_GATE_W * 0.5, 46))
	sec += _pal_row(objects, lvl, a.position.x, ARENA_GATE_X - gwk, a.end.y, Vector2.ZERO, "BO_ArenaWallW", "tmp_wall", false)
	sec += _pal_row(objects, lvl, ARENA_GATE_X + gwk, a.end.x, a.end.y, Vector2.ZERO, "BO_ArenaWallE", "tmp_wall", false)
	var sides := east_sides + ne_sides
	for sx in [a.position.x, a.end.x]:
		sides += _side_wall(objects, lvl, sx, a.position.y, a.end.y)
	# Осквернение: поваленная статуя Бальдра, алтарь Ордена, жаровни у врат
	var st := _sprite(objects, lvl, "town", "tmp_statue", Vector2(900, 1040), "BO_BaldrStatue")
	_body(st, lvl, Vector2(56, 18))
	var alt := _sprite(objects, lvl, "town", "ds_altar", Vector2(1290, 990), "BO_DarkAltar")
	_body(alt, lvl, Vector2(30, 12))
	for dx in [-gwk - 26.0, gwk + 26.0]:
		var br := _sprite(objects, lvl, "town", "ds_brazier", Vector2(ARENA_GATE_X + dx, a.end.y + 30), "BO_GateBrazier%d" % int(dx))
		_body(br, lvl, Vector2(18, 8))

	# 5. Враги и босс
	var moved := 0
	for n in ENEMIES:
		var e := objects.get_node_or_null(n) as Node2D
		if e:
			e.position = ENEMIES[n]
			moved += 1

	# 6. Фонари (свет — копия Lantern28 в Night)
	var lantern_src := lvl.get_node_or_null("Night/Lantern28") as PointLight2D
	var li := 0
	for p in LANTERNS:
		var s := _sprite(objects, lvl, "hd", "port_lantern@81x144", p, "BO_Lantern%d" % li)
		_body(s, lvl, Vector2(10, 6))
		if lantern_src:
			var light := lantern_src.duplicate() as PointLight2D
			light.name = "LanternBO%d" % li
			light.position = p + Vector2(11, -54)
			light.set_meta(META, true)
			lvl.get_node("Night").add_child(light)
			light.owner = lvl
		li += 1

	report.append("apply: убрано старых %d; вырублено тайлов %d, стволов %d; частокол %d секций, боковых кусков %d, хлама %d; берег север x%.0f юг x%.0f; мост x%.0f y%s; врагов %d, фонарей %d" % [
		removed, trees, trunks, sec, sides, junk, bank_n, bank_s, bx, span, moved, li])
	_save(lvl)
	report.append("дальше — перепечь навмеш (tools/bake_navmesh.gd)")


## Участки линии x (от частокола до частокола), не закрытые коллизией домов и
## не входящие в проход: [[y0, y1], ...]
func _barrier_segments(lvl: Node, x: float, passage: Vector2) -> Array:
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	var cover: Array = []
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		if s == null or minf(s.size.x, s.size.y) < COVER_MIN * 0.5 or maxf(s.size.x, s.size.y) < COVER_MIN:
			continue
		var o: Vector2 = (xfs[i] as Transform2D).origin
		if absf(o.x - x) <= s.size.x * 0.5:
			cover.append(Vector2(o.y - s.size.y * 0.5, o.y + s.size.y * 0.5))
	cover.append(passage)
	cover.sort_custom(func(a, b): return a.x < b.x)
	var segs: Array = []
	var y := WALL_N
	for c in cover:
		if c.x > y + 6.0:
			segs.append([y, minf(c.x, WALL_S)])
		y = maxf(y, c.y)
		if y >= WALL_S:
			break
	if y < WALL_S - 6.0:
		segs.append([y, WALL_S])
	return segs


func _remove_nodes(lvl: Node) -> int:
	var n := 0
	for path in ["Objects", "Night"]:
		for c in lvl.get_node(path).get_children():
			if c.has_meta(META):
				c.get_parent().remove_child(c)
				c.free()
				n += 1
	var r := lvl.get_node_or_null("Blockout")
	if r:
		lvl.remove_child(r)
		r.free()
		n += 1
	return n


func _bonfire(objects: Node, lvl: Node, src: Node, node_name: String, title: String, pos: Vector2) -> void:
	var b := src.duplicate() as Node2D
	b.name = node_name
	b.position = pos
	b.set("bonfire_name", title)
	b.set_meta(META, true)
	objects.add_child(b)
	objects.move_child(b, src.get_index() + 1)
	_own(b, lvl)


## Ряд секций частокола (поперёк взгляда) от x0 до x1 по основанию y; gap —
## проём (x от-до) без секций
## Ряд частокола (поперёк взгляда) от x0 до x1 по основанию y: секции
## pal_front, изредка повреждённые; угловые башни на концах и через
## TOWER_EVERY; gap — проём (x от-до) без секций. piece — другая секция
## (стенка двора храма)
func _pal_row(objects: Node, lvl: Node, x0: float, x1: float, y: float, gap: Vector2, prefix := "BO_Pal", piece := "pal_front", towers := true) -> int:
	var w: float = _town_meta[piece][2] / TPX
	var n := 0
	var parts: Array = [[x0, x1]]
	if gap != Vector2.ZERO:
		parts = [[x0, gap.x], [gap.y, x1]]
	for p in parts:
		var a: float = p[0]
		var b: float = p[1]
		if b - a < w * 0.4:
			continue
		var cnt := maxi(1, roundi((b - a) / w))
		var k := (b - a) / (cnt * w)
		for i in cnt:
			var key := piece
			if piece == "pal_front" and _hash(int(a) + i, int(y) + 7) < DAMAGED_SHARE:
				key = "pal_damaged"
			var s := _sprite(objects, lvl, "town", key, Vector2(a + (i + 0.5) * w * k, y), "%s%d_%d" % [prefix, int(y), int(a) + i])
			s.scale.x *= k
			s.flip_h = piece == "pal_front" and _hash(int(a) + i, int(y)) > 0.5
			n += 1
	if towers:
		var tx := x0 + 40.0
		while tx < x1 - 40.0:
			if gap == Vector2.ZERO or tx < gap.x - 140.0 or tx > gap.y + 140.0:
				var t := _sprite(objects, lvl, "town", "pal_tower", Vector2(tx, y + 14), "%sTower%d_%d" % [prefix, int(y), int(tx)])
				_body(t, lvl, Vector2(60, 22))
			tx += TOWER_EVERY
	return n


## Боковая стена (вдоль взгляда) из кусков pal_side (низ куска — основание)
func _side_wall(objects: Node, lvl: Node, x: float, y0: float, y1: float) -> int:
	var h: float = _town_meta["pal_side"][3] / TPX
	var step := h * 0.62
	var n := 0
	var y := y0 + step
	while y <= y1 + step * 0.5:
		var s := _sprite(objects, lvl, "town", "pal_side", Vector2(x, minf(y, y1) + 8.0), "BO_Side%d_%d" % [int(x), int(y)])
		s.flip_h = _hash(int(x), int(y)) > 0.5
		n += 1
		y += step
	return n


## Ворота-башня: картинка pal_gatehouse по центру проёма, упоры по бокам от
## прохода (стена частокола у проёма — отдельной коллизией)
func _gatehouse(objects: Node, lvl: Node, walls: StaticBody2D, x: float, y: float, node_name: String) -> void:
	var gw: float = _town_meta["pal_gatehouse"][2] / TPX
	_sprite(objects, lvl, "town", "pal_gatehouse", Vector2(x, y + 10), node_name)
	var side := (gw - GATE_W) * 0.5
	_rect(walls, lvl, node_name + "_L", Rect2(x - gw * 0.5, y - 46, side, 52))
	_rect(walls, lvl, node_name + "_R", Rect2(x + GATE_W * 0.5, y - 46, side, 52))


## Спрайт предмета листа: узел в точке основания (по ней y-sort)
func _sprite(objects: Node, lvl: Node, sheet: String, key: String, base: Vector2, node_name: String) -> Sprite2D:
	var metas := {"hd": _hd_meta, "camp": _camp_meta, "town": _town_meta}
	var texs := {"hd": _hd, "camp": _camp, "town": _town}
	var r: Array = metas[sheet][key]
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = texs[sheet]
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.centered = false
	s.scale = Vector2(1.0 / TPX, 1.0 / TPX)
	s.offset = Vector2(-r[2] * 0.5, -r[3] + 4.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = base
	s.set_meta(META, true)
	objects.add_child(s)
	s.owner = lvl
	return s


func _body(s: Sprite2D, lvl: Node, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size * TPX
	cs.shape = shape
	cs.position = Vector2(0, -size.y * 0.5 * TPX)
	s.add_child(body)
	body.owner = lvl
	body.add_child(cs)
	cs.owner = lvl


func _rect(body: StaticBody2D, lvl: Node, node_name: String, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	cs.name = node_name
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	body.add_child(cs)
	cs.owner = lvl


func _add(parent: Node, n: Node, lvl: Node) -> void:
	parent.add_child(n)
	n.owner = lvl


func _own(n: Node, lvl: Node) -> void:
	n.owner = lvl
	for c in n.get_children():
		_own(c, lvl)


func _save(lvl: Node) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	report.append("сцена сохранена (%s)" % error_string(err))
	lvl.free()


# ───────────────────────── вода, мост, растительность ─────────────────────────

func _load_water(lvl: Node) -> void:
	_water.clear()
	var col := lvl.get_node("Collision") as Node2D
	for c in col.get_children():
		if c is CollisionPolygon2D:
			_water.append((col.transform * (c as Node2D).transform) * (c as CollisionPolygon2D).polygon)


func _in_water(p: Vector2) -> bool:
	for poly in _water:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Западный берег реки на высоте y (восточнее деревни)
func _bank_x(y: float) -> float:
	var x := 1400.0
	while x < 2600.0:
		if _in_water(Vector2(x, y)):
			return x
		x += 2.0
	return 2300.0


## Проход по мосту (мосткам) на x возле высоты yc: [верх, низ] суши между водой
func _span(x: float, yc := 1100.0) -> Vector2:
	var y0 := INF
	var y1 := -INF
	var y := yc - 70.0
	while y < yc + 70.0:
		if not _in_water(Vector2(x, y)):
			y0 = minf(y0, y)
			y1 = maxf(y1, y)
		y += 1.0
	return Vector2(y0, y1)


## x моста через реку, где вода с обеих сторон (середина такого участка)
func _bridge_x(yc := 1100.0) -> float:
	var xs: Array[float] = []
	var x := 1600.0
	while x < 2100.0:
		var s := _span(x, yc)
		if s.y - s.x < 45.0 and _in_water(Vector2(x, s.x - 4)) and _in_water(Vector2(x, s.y + 4)):
			xs.append(x)
		x += 4.0
	if xs.is_empty():
		return 1790.0
	return xs[xs.size() / 2]


func _in_bands(p: Vector2, bands: Array[Rect2]) -> bool:
	for b in bands:
		if b.has_point(p):
			return true
	return false


func _erase_foliage(lvl: Node, bands: Array[Rect2]) -> int:
	var n := 0
	for l in lvl.get_node("Objects").get_children():
		if not (l is TileMapLayer):
			continue
		var layer := l as TileMapLayer
		var ts := layer.tile_set
		for cell in layer.get_used_cells():
			var src := ts.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if src == null or not _foliage(src):
				continue
			var base := layer.transform * layer.map_to_local(cell)
			var td := src.get_tile_data(layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell) & 0xFFF)
			if td:
				base.y += td.y_sort_origin * absf(layer.scale.y)
			if _in_bands(base, bands):
				layer.erase_cell(cell)
				n += 1
	return n


func _foliage(src: TileSetAtlasSource) -> bool:
	if src.has_meta("forest_variant"):
		return true
	if src.has_meta("hd_prop"):
		var k := str(src.get_meta("hd_prop")).get_slice("@", 0)
		for p in ["bush", "tuft", "fern", "stump", "reeds"]:
			if k.begins_with(p):
				return true
	return false


## Растительность в rect: оставить долю keep (по хешу клетки), остальное
## стереть; основания оставленных — в kept
func _thin_foliage(lvl: Node, rect: Rect2, keep: float, kept: Array[Vector2]) -> int:
	var n := 0
	for l in lvl.get_node("Objects").get_children():
		if not (l is TileMapLayer):
			continue
		var layer := l as TileMapLayer
		var ts := layer.tile_set
		for cell in layer.get_used_cells():
			var src := ts.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if src == null or not _foliage(src):
				continue
			var base := layer.transform * layer.map_to_local(cell)
			var td := src.get_tile_data(layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell) & 0xFFF)
			if td:
				base.y += td.y_sort_origin * absf(layer.scale.y)
			if not rect.has_point(base):
				continue
			if _hash(cell.x, cell.y) < keep:
				kept.append(base)
				continue
			layer.erase_cell(cell)
			n += 1
	return n


## Стволы (прямоугольники ≤ 48 px) в коллизии карты на линиях стен (кроме
## стволов оставленных деревьев — ближе 28 px к kept)
func _erase_trunks(lvl: Node, bands: Array[Rect2], kept: Array[Vector2] = []) -> int:
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	var ns: Array[Shape2D] = []
	var nx: Array[Transform2D] = []
	var n := 0
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		var t: Transform2D = xfs[i]
		if s and maxf(s.size.x, s.size.y) <= 48.0 and _in_bands(t.origin, bands):
			var near_kept := false
			for k in kept:
				if k.distance_to(t.origin) < 28.0:
					near_kept = true
					break
			if not near_kept:
				n += 1
				continue
		ns.append(shapes[i])
		nx.append(t)
	col.set("shapes", ns)
	col.set("shape_transforms", nx)
	return n


static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0
