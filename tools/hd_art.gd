extends SceneTree
## Лес reference_map из чётких картинок (reference_map_level/textures/src/hd/,
## по одному объекту на картинку, 1024x1536 и 1254x1254, прозрачный фон).
##
## Шаги:
##   atlas — каждая картинка: убрать белый фон (если есть), обрезать по альфе,
##           уменьшить до размера на карте (premultiplied alpha, без ореолов),
##           лёгкая резкость; всё в textures/forest_trees.png + forest_trees.json
##           (те же имена вариантов, что и раньше: oak_0, fir_tall_1 ...).
##           Затем: godot --headless --path . --import
##   remap — в reference_map.tscn и ruined_camp.tscn источники тайлов леса
##           (metadata forest_variant) получают новые места в атласе и точку
##           основания. Деревья стоят на тех же клетках: коллизия, навмеш,
##           y-sort, тени не меняются. Если у вида стало больше вариантов
##           (bush_green, rocks), клетки этого вида делятся между ними по хешу.
##           Слоям объектов ставится сглаживание (Linear) — детальная картинка
##           при зуме 2.2 без лесенки Nearest.
##
## Запуск:
##   godot --headless --path . -s res://tools/hd_art.gd -- atlas
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/hd_art.gd -- remap

const HD := "res://reference_map_level/textures/src/hd/"
const ATLAS := "res://reference_map_level/textures/forest_trees.png"
const META := "res://reference_map_level/textures/forest_trees.json"
const SCENES := ["res://reference_map_level/reference_map.tscn", "res://reference_map_level/ruined_camp.tscn"]

## Вариант: [файл, высота в атласе (px), доля высоты от низа до основания,
##           часть картинки (0 — вся, 1/2 — левая/правая группа)]
## Слой деревьев масштабирован 0.5: 400 px атласа = 200 px мира.
const SPECS := {
	"oak_big_0": ["tree_oak_ancient", 430, 0.07, 0],
	"oak_big_1": ["tree_oak_ancient", 370, 0.07, 0],
	"oak_0": ["tree_oak", 420, 0.06, 0],
	"oak_1": ["tree_oak", 360, 0.06, 0],
	"maple_red_0": ["tree_crimson", 400, 0.07, 0],
	"maple_red_1": ["tree_crimson", 340, 0.07, 0],
	"birch_weeping_0": ["tree_birch_weeping_dark", 410, 0.05, 0],
	"birch_weeping_1": ["tree_birch_weeping_autumn", 370, 0.05, 0],
	"birch_autumn_0": ["tree_birch_gold", 400, 0.04, 0],
	"birch_autumn_1": ["tree_birch_gold", 340, 0.04, 0],
	"fir_tall_0": ["tree_spruce", 470, 0.05, 0],
	"fir_tall_1": ["tree_spruce", 400, 0.05, 0],
	"fir_0": ["tree_spruce", 380, 0.05, 0],
	"fir_1": ["tree_spruce", 320, 0.05, 0],
	"dead_big_0": ["tree_dead", 400, 0.07, 0],
	"dead_big_1": ["tree_dead", 340, 0.07, 0],
	"dead_broken_0": ["tree_dead_broken", 340, 0.07, 0],
	"dead_broken_1": ["tree_dead_broken", 290, 0.07, 0],
	"bush_berry_0": ["bush_berry", 190, 0.12, 0],
	"bush_green_0": ["bush_green", 160, 0.12, 0],
	"bush_green_1": ["grass_tuft", 120, 0.12, 0],
	"bush_red_0": ["bush_dry_leaves", 160, 0.12, 0],
	"bush_dead_0": ["bush_dry_twigs", 160, 0.1, 0],
	"fern_0": ["fern", 130, 0.12, 0],
	"rocks_0": ["rocks_mossy", 130, 0.18, 0],
	"rocks_1": ["rock_cliff_single", 140, 0.18, 0],
	"stump_0": ["stump", 130, 0.16, 0],
	"log_0": ["log_mossy", 150, 0.3, 0],
	# Мелкая трава и папоротник вместо старых пиксельных цветочков
	"tuft_0": ["grass_tuft", 64, 0.15, 0],
	"tuft_1": ["fern", 60, 0.15, 0],
}


func _initialize() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	match mode:
		"atlas":
			quit(_build_atlas())
		"remap":
			quit(_remap())
		"props":
			quit(_props())
		_:
			push_error("Режим: atlas, remap или props")
			quit(1)


# ---------------------------------------------------------------- атлас

func _build_atlas() -> int:
	var cache := {}
	var pieces: Array = []
	for v in SPECS:
		var s: Array = SPECS[v]
		var key := "%s/%d" % [s[0], s[3]]
		if not cache.has(key):
			var img := Image.load_from_file(ProjectSettings.globalize_path(HD + s[0] + ".png"))
			if img == null:
				push_error("Нет картинки " + s[0])
				return 1
			img.convert(Image.FORMAT_RGBA8)
			if _has_white_bg(img):
				_remove_white_bg(img)
			if s[3] > 0:
				img = _half(img, s[3])
			cache[key] = img.get_region(img.get_used_rect())
		var src: Image = cache[key]
		var h: int = s[1]
		var w := roundi(src.get_width() * float(h) / src.get_height())
		var p := _downscale(src, w, h)
		p = _unsharp(p, 0.35)
		pieces.append({"name": v, "kind": v.substr(0, v.rfind("_")), "img": p, "base": roundi(h * float(s[2]))})
	# Полки шириной 2048, высоты кратны 4 (BPTC)
	pieces.sort_custom(func(a, b): return a["img"].get_height() > b["img"].get_height())
	var W := 2048
	var x := 0
	var y := 0
	var shelf := 0
	for p in pieces:
		var w: int = p["img"].get_width()
		var h: int = p["img"].get_height()
		if x + w > W:
			x = 0
			y += shelf + 4
			shelf = 0
		p["rect"] = Rect2i(x, y, w, h)
		x += w + 4
		shelf = maxi(shelf, h)
	var H := ((y + shelf + 3) / 4) * 4
	var atlas := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var meta := {}
	for p in pieces:
		var r: Rect2i = p["rect"]
		atlas.blit_rect(p["img"], Rect2i(Vector2i.ZERO, r.size), r.position)
		meta[p["name"]] = {"kind": p["kind"], "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "base": p["base"]}
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	var prev := OS.get_environment("TERRAIN_PREVIEW")
	if prev != "":
		atlas.save_png(prev + "/forest_atlas.png")
	print("[hd_art] атлас %dx%d, %d вариантов (%s)" % [W, H, pieces.size(), error_string(err)])
	return 0 if err == OK else 1


## Белый фон (картинка без альфы): углы почти белые
func _has_white_bg(img: Image) -> bool:
	var n := 0
	for c in [Vector2i(2, 2), Vector2i(img.get_width() - 3, 2), Vector2i(2, img.get_height() - 3),
			Vector2i(img.get_width() - 3, img.get_height() - 3)]:
		var p := img.get_pixelv(c)
		if p.a > 0.9 and minf(p.r, minf(p.g, p.b)) > 0.88:
			n += 1
	return n >= 3


## Заливка белого от краёв; у края объекта альфа по «белизне» и цвет без
## примеси белого — без светлого ореола
func _remove_white_bg(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if bg[i]:
			continue
		var mn := mini(d[i * 4], mini(d[i * 4 + 1], d[i * 4 + 2]))
		var mx := maxi(d[i * 4], maxi(d[i * 4 + 1], d[i * 4 + 2]))
		if mn < 200 or mx - mn > 40:
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	# Белые просветы внутри объекта (между листьями), до которых заливка от
	# края не дошла: почти чистый белый тоже фон
	for i in w * h:
		var mn := mini(d[i * 4], mini(d[i * 4 + 1], d[i * 4 + 2]))
		var mx := maxi(d[i * 4], maxi(d[i * 4 + 1], d[i * 4 + 2]))
		if mn >= 222 and mx - mn <= 22:
			bg[i] = 1
	# Край: пиксели объекта рядом с фоном
	for y in h:
		for x in w:
			var i := y * w + x
			if bg[i]:
				d[i * 4 + 3] = 0
				continue
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and bg[yy * w + xx]:
						near = true
			if not near:
				continue
			var mn := mini(d[i * 4], mini(d[i * 4 + 1], d[i * 4 + 2]))
			var a := clampf((255.0 - mn) / 110.0, 0.0, 1.0)
			if a <= 0.02:
				d[i * 4 + 3] = 0
				continue
			for ch in 3:
				d[i * 4 + ch] = clampi(int((d[i * 4 + ch] - 255.0 * (1.0 - a)) / a), 0, 255)
			d[i * 4 + 3] = int(a * 255.0)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, d)


## Левая (1) или правая (2) группа — по самой широкой пустой полосе столбцов
## в середине картинки
func _half(img: Image, which: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cols := PackedInt32Array()
	cols.resize(w)
	for x in w:
		for y in range(0, h, 2):
			if img.get_pixel(x, y).a > 0.1:
				cols[x] += 1
	var best_x := w / 2
	var best_len := 0
	var run := 0
	for x in range(w / 4, w * 3 / 4):
		run = run + 1 if cols[x] <= 1 else 0
		if run > best_len:
			best_len = run
			best_x = x - run / 2
	if best_len == 0:
		# Пустой полосы нет — самый тонкий столбец
		var mn := 1 << 30
		for x in range(w / 4, w * 3 / 4):
			if cols[x] < mn:
				mn = cols[x]
				best_x = x
	var r := Rect2i(0, 0, best_x, h) if which == 1 else Rect2i(best_x, 0, w - best_x, h)
	var out := img.get_region(r)
	return out.get_region(out.get_used_rect())


## Уменьшение без тёмных/светлых ореолов: в premultiplied alpha
static func _downscale(src: Image, w: int, h: int) -> Image:
	var p := src.duplicate() as Image
	p.premultiply_alpha()
	p.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var d := p.get_data()
	for i in range(0, d.size(), 4):
		var a := d[i + 3]
		if a < 10:
			d[i] = 0
			d[i + 1] = 0
			d[i + 2] = 0
			d[i + 3] = 0
			continue
		for ch in 3:
			d[i + ch] = clampi(int(d[i + ch] * 255.0 / a + 0.5), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


## Нерезкая маска радиуса ~1 px; полупрозрачный край не трогается
static func _unsharp(img: Image, amount: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var blur := img.duplicate() as Image
	blur.resize(maxi(w / 2, 1), maxi(h / 2, 1), Image.INTERPOLATE_BILINEAR)
	blur.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var a := img.get_data()
	var b := blur.get_data()
	for i in range(0, a.size(), 4):
		if a[i + 3] < 250 or b[i + 3] < 250:
			continue
		for ch in 3:
			a[i + ch] = clampi(int(a[i + ch] + (a[i + ch] - b[i + ch]) * amount), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, a)


# ---------------------------------------------------------------- сцены

var _meta := {}
var _atlas: Texture2D


func _remap() -> int:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_atlas = load(ATLAS)
	if _meta == null or _atlas == null:
		push_error("Нет атласа — сначала шаг atlas и импорт")
		return 1
	if Vector2i(_atlas.get_size()) != _atlas_png_size():
		push_error("Атлас не переимпортирован — godot --headless --path . --import")
		return 1
	for path in SCENES:
		var root := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var stats := {}
		var tilesets := {}
		var layers: Array = []
		for layer in root.find_children("*", "TileMapLayer", true, false):
			if not layer.y_sort_enabled or (layer != root and layer.owner != root):
				continue
			layers.append(layer)
			if layer.tile_set:
				tilesets[layer.tile_set] = true
		# 1) Источники: новые места в атласе
		var by_ts := {}   # TileSet -> {вариант: source id}
		for ts: TileSet in tilesets:
			by_ts[ts] = {}
			for i in ts.get_source_count():
				var sid := ts.get_source_id(i)
				var s := ts.get_source(sid) as TileSetAtlasSource
				if s == null or not s.has_meta("forest_variant"):
					continue
				var v: String = s.get_meta("forest_variant")
				if not _meta.has(v):
					v = v.substr(0, v.rfind("_")) + "_0"
					s.set_meta("forest_variant", v)
				s.texture = _atlas
				_fit_source(s, v)
				by_ts[ts][v] = sid
				stats["src"] = stats.get("src", 0) + 1
		# 2) Виды, у которых вариантов больше, чем источников: делим клетки
		var kinds := {}
		for v in _meta:
			var k: String = _meta[v]["kind"]
			if not kinds.has(k):
				kinds[k] = []
			kinds[k].append(v)
		for k in kinds:
			kinds[k].sort()
		# Какие виды в каком TileSet делить (до прохода: новые источники
		# появляются по ходу)
		var split := {}
		for ts: TileSet in by_ts:
			split[ts] = {}
			for k in kinds:
				for v in kinds[k]:
					if not by_ts[ts].has(v):
						split[ts][k] = true
		for layer: TileMapLayer in layers:
			var ts := layer.tile_set
			if ts == null or not by_ts.has(ts):
				continue
			var sid_kind := {}
			for v in by_ts[ts]:
				sid_kind[by_ts[ts][v]] = _meta[v]["kind"]
			for c in layer.get_used_cells():
				var sid := layer.get_cell_source_id(c)
				if not sid_kind.has(sid):
					continue
				var k: String = sid_kind[sid]
				var vs: Array = kinds[k]
				if not split[ts].has(k):
					continue
				# Вид получил новый вариант: выбор заново по хешу клетки
				var hsh := absi(hash(Vector3i(c.x, c.y, hash(String(layer.name)) % 100000)))
				var v: String = vs[(hsh >> 7) % vs.size()]
				var nsid := _source_for(ts, v, by_ts[ts])
				layer.set_cell(c, nsid, Vector2i.ZERO, layer.get_cell_alternative_tile(c))
				stats[v] = stats.get(v, 0) + 1
		# 3) Сглаживание слоёв объектов
		var objects := root.get_node_or_null("Objects") as CanvasItem
		if objects:
			objects.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		for layer: TileMapLayer in layers:
			if layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and _has_forest(layer, by_ts):
				layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				stats["linear"] = stats.get("linear", 0) + 1
		var g := root.get_node_or_null("Ground") as CanvasItem
		if path == SCENES[0] and g != null and g.material == null:
			print("[hd_art] %s НЕ сохранена: материал земли не загрузился — сначала импорт" % path.get_file())
			root.free()
			return 1
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		print("[hd_art] %s: %s (%s)" % [path.get_file(), stats, error_string(err)])
		root.free()
		if err != OK:
			return 1
	return 0


func _atlas_png_size() -> Vector2i:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	return img.get_size()


func _fit_source(s: TileSetAtlasSource, v: String) -> void:
	var m: Dictionary = _meta[v]
	var rect := Rect2i(m["rect"][0], m["rect"][1], m["rect"][2], m["rect"][3])
	s.margins = rect.position
	s.texture_region_size = rect.size
	s.separation = Vector2i.ZERO
	s.use_texture_padding = false
	if not s.has_tile(Vector2i.ZERO):
		s.create_tile(Vector2i.ZERO)
	# Основание ствола — в центре клетки
	var origin := Vector2i(0, rect.size.y / 2 - int(m["base"]))
	for alt in s.get_alternative_tiles_count(Vector2i.ZERO):
		var aid := s.get_alternative_tile_id(Vector2i.ZERO, alt)
		s.get_tile_data(Vector2i.ZERO, aid).texture_origin = origin
	if s.get_alternative_tiles_count(Vector2i.ZERO) < 2:
		var a := s.create_alternative_tile(Vector2i.ZERO, 1)
		var td := s.get_tile_data(Vector2i.ZERO, a)
		td.flip_h = true
		td.texture_origin = origin


func _source_for(ts: TileSet, v: String, known: Dictionary) -> int:
	if known.has(v):
		return known[v]
	var s := TileSetAtlasSource.new()
	s.texture = _atlas
	s.set_meta("forest_variant", v)
	var m: Dictionary = _meta[v]
	s.margins = Vector2i(m["rect"][0], m["rect"][1])
	s.texture_region_size = Vector2i(m["rect"][2], m["rect"][3])
	var sid := ts.add_source(s)
	_fit_source(s, v)
	known[v] = sid
	return sid


func _has_forest(layer: TileMapLayer, by_ts: Dictionary) -> bool:
	if not by_ts.has(layer.tile_set):
		return false
	var ids := {}
	for v in by_ts[layer.tile_set]:
		ids[by_ts[layer.tile_set][v]] = true
	for c in layer.get_used_cells():
		if ids.has(layer.get_cell_source_id(c)):
			return true
	return false


# ---------------------------------------------------------------- старые мелочи

## Старые пиксельные мелочи (autumn_decorations.png) на новые картинки:
## куст с «ножкой» — новые кусты; мелкие цветочки и травинки (их ~1100) —
## часть становится пучками травы и папоротником, остальные убираются;
## пиксельные пни — новый пень. Плюс перед лестницами в стене убираются
## деревья и кусты (закрывали проход).
const DEC := "autumn_decorations.png"
const DEC_BUSH := Rect2i(592, 508, 164, 68)
const DEC_STUMPS := [Rect2i(1792, 548, 64, 56), Rect2i(1868, 532, 104, 68)]
## Мелкие растения — полоса атласа под кустами
const DEC_PLANTS := Rect2i(40, 570, 740, 90)
## Доля мелких растений, которые остаются (пучком травы или папоротником)
const KEEP_PLANTS := 0.4
const MIRE := Rect2(-1800, 2200, 3900, 1750)


func _props() -> int:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_atlas = load(ATLAS)
	if _meta == null or _atlas == null or not _meta.has("tuft_0"):
		push_error("Нет атласа с tuft_* — сначала atlas, импорт, remap")
		return 1
	var path: String = SCENES[0]
	var root := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var stats := {}
	var stairs: Array = root.get_meta("relief_stairs", [])
	var trunks: Array[Vector2] = []
	var known := {}
	for layer in root.find_children("*", "TileMapLayer", true, false):
		if not layer.y_sort_enabled or layer.owner != root or layer.tile_set == null:
			continue
		var ts: TileSet = layer.tile_set
		if not known.has(ts):
			known[ts] = {}
			for i in ts.get_source_count():
				var s := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
				if s and s.has_meta("forest_variant"):
					known[ts][s.get_meta("forest_variant")] = ts.get_source_id(i)
		for c in layer.get_used_cells():
			var s := ts.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			if s == null or s.texture == null:
				continue
			var wp: Vector2 = layer.to_global(layer.map_to_local(c))
			var hsh := absi(hash(Vector3i(c.x, c.y, 7177)))
			# Перед лестницей — ничего из леса
			if s.has_meta("forest_variant"):
				for r: Rect2 in stairs:
					var clear := Rect2(r.position.x - 40.0, r.position.y - 10.0, r.size.x + 80.0, r.size.y + 150.0)
					if clear.has_point(wp):
						layer.erase_cell(c)
						trunks.append(wp)
						stats["stairs_clear"] = stats.get("stairs_clear", 0) + 1
						break
				continue
			if s.texture.resource_path.get_file() != DEC:
				continue
			var reg := s.get_tile_texture_region(layer.get_cell_atlas_coords(c))
			var alt: int = layer.get_cell_alternative_tile(c) & 1
			var pick := ""
			if reg == DEC_BUSH:
				var opts := ["bush_dead", "fern", "bush_dead"] if MIRE.has_point(wp) else ["bush_green", "bush_berry", "bush_green", "bush_red"]
				pick = opts[(hsh >> 3) % opts.size()]
			elif reg in DEC_STUMPS:
				pick = "stump"
			elif DEC_PLANTS.encloses(reg):
				if float((hsh >> 5) % 1000) / 1000.0 >= KEEP_PLANTS:
					layer.erase_cell(c)
					stats["plants_removed"] = stats.get("plants_removed", 0) + 1
					continue
				pick = "tuft"
			else:
				continue
			var vs: Array = []
			for v in _meta:
				if _meta[v]["kind"] == pick:
					vs.append(v)
			vs.sort()
			var v: String = vs[(hsh >> 9) % vs.size()]
			layer.set_cell(c, _source_for(ts, v, known[ts]), Vector2i.ZERO, alt)
			stats[v] = stats.get(v, 0) + 1
	# Ствол убранного дерева — и из коллизии (как в forest_paths.gd thin)
	var body := root.get_node_or_null("Collision")
	if not trunks.is_empty() and body and body.get_script() and body.get_script().resource_path.ends_with("static_shapes.gd"):
		var shapes: Array = body.get("shapes")
		var xf: Array = body.get("shape_transforms")
		var ns: Array[Shape2D] = []
		var nx: Array[Transform2D] = []
		var bt: Transform2D = (body as Node2D).transform
		for i in shapes.size():
			var s: Shape2D = shapes[i]
			var o: Vector2 = bt * (xf[i] as Transform2D).origin
			var drop := false
			if s is RectangleShape2D and s.size.x <= 48.0 and s.size.y <= 48.0:
				for t in trunks:
					if o.distance_to(t) < 14.0:
						drop = true
			if drop:
				stats["trunk_shapes"] = stats.get("trunk_shapes", 0) + 1
			else:
				ns.append(s)
				nx.append(xf[i])
		body.set("shapes", ns)
		body.set("shape_transforms", nx)
	var g := root.get_node_or_null("Ground") as CanvasItem
	if g != null and g.material == null:
		print("[hd_art] сцена НЕ сохранена: материал земли не загрузился — сначала импорт")
		root.free()
		return 1
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("[hd_art] props %s: %s (%s)" % [path.get_file(), stats, error_string(err)])
	root.free()
	return 0 if err == OK else 1
