extends SceneTree
## Новые деревья на reference_map из присланного листа
## (reference_map_level/textures/src/forest_sheet.webp, 17 спрайтов на прозрачном фоне).
##
## Два шага (между ними Godot должен импортировать атлас):
##   1) атлас:   godot --headless --path . -s res://tools/replace_trees.gd -- atlas
##      вырезает спрайты по альфе, масштабирует, раскладывает в
##      textures/forest_trees.png (+ .import со сжатием BPTC, как у остальных
##      атласов карты) и textures/forest_trees.json (где какой спрайт).
##      Затем: godot --headless --path . --import
##   2) замена:  godot --headless --path . -s res://tools/replace_trees.gd -- apply
##      во всех y-sort слоях объектов reference_map.tscn и ruined_camp.tscn
##      меняет старые деревья (оранжевые autumn_trees, сухие из ruin_art), кусты,
##      пни и поваленные стволы на новые. Клетки те же — коллизия, навмеш,
##      y-sort и окно прозрачности (OcclusionFade) не меняются. Порода зависит
##      от места: см. ZONES и _zone(). Плюс немного подлеска у деревьев.
##      Повторный запуск безопасен: уже новые тайлы не трогаются.

const SHEET := "res://reference_map_level/textures/src/forest_sheet.webp"
const ATLAS := "res://reference_map_level/textures/forest_trees.png"
const META := "res://reference_map_level/textures/forest_trees.json"
const SCENES := ["res://reference_map_level/reference_map.tscn", "res://reference_map_level/ruined_camp.tscn"]

## Спрайты листа по порядку: ряды сверху вниз, в ряду слева направо
const NAMES := [
	"oak_big", "maple_red", "birch_weeping", "fir_tall", "dead_big",
	"oak", "birch_autumn", "fir", "dead_broken", "bush_berry",
	"bush_green", "bush_red", "bush_dead", "fern", "rocks", "stump", "log",
]
## Во сколько раз увеличить спрайт (старые деревья на карте ~1.3 раза крупнее листа)
const SCALE := {
	"oak_big": [1.35, 1.15], "maple_red": [1.3, 1.1], "birch_weeping": [1.3, 1.1],
	"fir_tall": [1.4, 1.15], "dead_big": [1.3, 1.1], "oak": [1.3, 1.1],
	"birch_autumn": [1.3, 1.1], "fir": [1.35, 1.1], "dead_broken": [1.3, 1.1],
	"bush_berry": [1.0], "bush_green": [1.1], "bush_red": [1.1], "bush_dead": [1.1],
	"fern": [1.0], "rocks": [1.1], "stump": [1.0], "log": [1.2],
}


func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	if mode == "atlas":
		quit(_build_atlas())
	elif mode == "apply":
		quit(_apply())
	else:
		push_error("Режим: atlas или apply")
		quit(1)


# ---------------------------------------------------------------- атлас

func _build_atlas() -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	img.convert(Image.FORMAT_RGBA8)
	var boxes := _components(img)
	if boxes.size() != NAMES.size():
		push_error("Нашёл %d спрайтов, ожидал %d" % [boxes.size(), NAMES.size()])
		for b in boxes:
			print("  box ", b)
		return 1
	# Ряды: по центру Y, затем по X
	boxes.sort_custom(func(a: Rect2i, b: Rect2i): return a.get_center().y < b.get_center().y)
	var rows: Array = [[]]
	for b in boxes:
		var row: Array = rows[-1]
		if not row.is_empty() and b.get_center().y - row[0].get_center().y > 120:
			rows.append([])
			row = rows[-1]
		row.append(b)
	var ordered: Array = []
	for row in rows:
		row.sort_custom(func(a: Rect2i, b: Rect2i): return a.position.x < b.position.x)
		ordered.append_array(row)

	# Варианты: каждый спрайт в 1-2 размерах
	var pieces: Array = []
	for i in ordered.size():
		var name: String = NAMES[i]
		var src := img.get_region(ordered[i])
		for si in SCALE[name].size():
			var s: float = SCALE[name][si]
			var p := src.duplicate() as Image
			p.resize(roundi(src.get_width() * s), roundi(src.get_height() * s), Image.INTERPOLATE_LANCZOS)
			_fix_alpha(p)
			pieces.append({"name": "%s_%d" % [name, si], "kind": name, "img": p})
	# Укладка полками, ширина 2048, высоты кратны 4 (BPTC)
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
		meta[p["name"]] = {"kind": p["kind"], "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "base": _base_offset(p["img"])}
	atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	_write_import()
	print("[replace_trees] атлас %dx%d, %d спрайтов -> %s" % [W, H, pieces.size(), ATLAS])
	for n in meta:
		print("   %-18s %s base=%d" % [n, meta[n]["rect"], meta[n]["base"]])
	return 0


## Связные области непрозрачных пикселей; мелкие отдельные листики
## приклеиваются к ближайшему крупному спрайту
func _components(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var comps: Array = []
	for y0 in h:
		for x0 in w:
			var i0 := y0 * w + x0
			if seen[i0] or img.get_pixel(x0, y0).a < 0.08:
				continue
			var r := Rect2i(x0, y0, 1, 1)
			var n := 0
			var stack := [Vector2i(x0, y0)]
			seen[i0] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				n += 1
				r = r.expand(p).expand(p + Vector2i.ONE)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
							continue
						var qi := q.y * w + q.x
						if seen[qi] or img.get_pixel(q.x, q.y).a < 0.08:
							continue
						seen[qi] = 1
						stack.append(q)
			comps.append({"r": r, "n": n})
	var big: Array = []
	var small: Array = []
	for c in comps:
		(big if c["n"] >= 1500 else small).append(c)
	for c in small:
		var best := -1
		var bd := INF
		for bi in big.size():
			var d: float = big[bi]["r"].grow(2).get_center().distance_to(c["r"].get_center())
			if big[bi]["r"].grow(24).intersects(c["r"]) and d < bd:
				bd = d
				best = bi
		if best >= 0:
			big[best]["r"] = big[best]["r"].merge(c["r"])
	var out: Array = []
	for c in big:
		out.append(c["r"].grow(1).intersection(Rect2i(0, 0, w, h)))
	return out


## После Lanczos по краю остаются полупрозрачные «ореолы» и выбросы цвета
func _fix_alpha(p: Image) -> void:
	for y in p.get_height():
		for x in p.get_width():
			var c := p.get_pixel(x, y)
			if c.a < 0.12:
				p.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				p.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), clampf(c.a, 0, 1)))


## Где у спрайта «земля» (основание ствола): нижний ряд с заметной заливкой,
## поднятый на 8% высоты — у листа под деревом трава и корни
func _base_offset(p: Image) -> int:
	return roundi(p.get_height() * 0.08)


func _write_import() -> void:
	var path := ATLAS + ".import"
	if FileAccess.file_exists(path):
		return
	var tmpl := FileAccess.get_file_as_string("res://reference_map_level/textures/autumn_trees.png.import")
	var lines := []
	for l in tmpl.split("\n"):
		if l.begins_with("uid=") or l.begins_with("path") or l.begins_with("source_file") or l.begins_with("dest_files") \
				or l.begins_with("metadata") or l.begins_with("\"") or l.begins_with("}"):
			continue
		if l.begins_with("compress/mode="):
			l = "compress/mode=2"
		elif l.begins_with("compress/high_quality="):
			l = "compress/high_quality=true"
		lines.append(l)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()


# ---------------------------------------------------------------- замена

## Породы по зонам: вес каждой породы. Внутри зоны породы растут куртинами
## (вес умножается на низкочастотный шум своей породы)
const ZONES := {
	"taiga": {"fir_tall": 4.0, "fir": 4.0, "oak_big": 0.8, "birch_weeping": 1.0, "dead_big": 0.5},
	"oakwood": {"oak_big": 3.0, "oak": 3.0, "maple_red": 1.5, "birch_autumn": 1.5, "birch_weeping": 1.0, "fir": 0.5},
	"mixed": {"fir_tall": 2.0, "fir": 2.0, "maple_red": 2.0, "birch_autumn": 2.0, "oak": 2.0, "oak_big": 1.0},
	"darkwood": {"fir_tall": 3.0, "fir": 3.0, "dead_big": 1.5, "dead_broken": 1.5, "oak": 1.0},
	"town": {"oak": 3.0, "oak_big": 2.0, "birch_weeping": 2.0, "birch_autumn": 2.0, "maple_red": 1.0},
	"grove": {"birch_autumn": 3.0, "maple_red": 2.0, "oak": 2.0, "birch_weeping": 2.0, "fir": 1.0},
	"camp": {"birch_autumn": 3.0, "maple_red": 3.0, "oak": 2.0, "birch_weeping": 1.0, "dead_broken": 1.0},
	"cursed": {"maple_red": 4.0, "dead_big": 2.0, "dead_broken": 2.0, "fir_tall": 1.5, "birch_autumn": 1.0},
	"mire": {"dead_big": 3.0, "dead_broken": 3.0, "birch_weeping": 3.0, "fir": 1.0, "oak": 0.5},
}
## Кусты по зонам (заменяют старые кусты и идут в подлесок)
const BUSHES := {
	"taiga": ["bush_green", "fern", "fern"], "oakwood": ["bush_green", "bush_berry", "fern"],
	"mixed": ["bush_green", "bush_red", "bush_berry"], "darkwood": ["fern", "bush_dead", "bush_green"],
	"town": ["bush_green", "bush_berry"], "grove": ["bush_red", "bush_berry", "bush_green"],
	"camp": ["bush_red", "bush_berry"], "cursed": ["bush_red", "bush_dead"], "mire": ["bush_dead", "fern"],
}
## Где на reference_map что (мировые px): игровая зона и болото на юге
const PLAY := Rect2(-2960, -160, 6960, 2360)
const MIRE := Rect2(-1800, 2200, 3900, 1750)
## Доля деревьев, у которых появится подлесок (только лесные зоны)
const UNDERGROWTH := 0.12

## Что считать чем среди старых тайлов: текстура -> [регион, тип]
const OLD := {
	"ruin_art.png": [
		[Rect2i(1006, 0, 264, 312), "dead"], [Rect2i(544, 0, 260, 368), "dead"], [Rect2i(1638, 0, 236, 296), "dead"],
		[Rect2i(926, 462, 240, 244), "log"], [Rect2i(1274, 0, 360, 310), "log"], [Rect2i(1580, 1188, 368, 94), "log"],
		[Rect2i(1266, 1068, 62, 112), "stump"], [Rect2i(138, 1068, 60, 114), "stump"],
	],
	"autumn_decorations.png": [
		[Rect2i(200, 468, 184, 100), "bush"], [Rect2i(64, 472, 128, 96), "bush"], [Rect2i(400, 460, 168, 112), "bush"],
		[Rect2i(1604, 512, 120, 92), "stump"],
	],
}

var _meta := {}
var _atlas: Texture2D
var _noise := {}
var _warp := FastNoiseLite.new()
## TileSet -> {вариант: source id}
var _sources := {}
var _stats := {}


func _apply() -> int:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_atlas = load(ATLAS)
	if _meta == null or _atlas == null:
		push_error("Нет атласа — сначала шаг atlas и импорт")
		return 1
	var seed_i := 11
	for kind in NAMES:
		var n := FastNoiseLite.new()
		n.seed = seed_i
		n.frequency = 1.0 / 650.0
		_noise[kind] = n
		seed_i += 7
	_warp.seed = 3
	_warp.frequency = 1.0 / 900.0
	# Сначала карта (без узлов вставленного лагеря), потом сам лагерь
	for path in SCENES:
		var ps := load(path) as PackedScene
		var root := ps.instantiate()
		_stats = {}
		var hazards := _hazard_layers(root)
		for layer in root.find_children("*", "TileMapLayer", true, false):
			if not layer.y_sort_enabled or (layer != root and layer.owner != root):
				continue
			_process_layer(root, layer as TileMapLayer, hazards)
		_drop_unused(root)
		var out := PackedScene.new()
		var err := out.pack(root)
		if err == OK:
			err = ResourceSaver.save(out, path)
		print("[replace_trees] %s: %s (%s)" % [path, _stats, error_string(err)])
		root.free()
		if err != OK:
			return 1
	return 0


func _process_layer(root: Node, layer: TileMapLayer, hazards: Array) -> void:
	var lname := String(layer.name)
	var in_camp := String(root.name) == "RuinedCamp" or root.scene_file_path.ends_with("ruined_camp.tscn")
	var ts := layer.tile_set
	var cells := layer.get_used_cells()
	var occupied := {}
	for c in cells:
		occupied[c] = true
	var adds: Array = []
	for c in cells:
		var src := ts.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null or src.texture == null or src.texture == _atlas:
			continue
		var kind := _old_kind(src, layer.get_cell_atlas_coords(c))
		if kind == "":
			continue
		var wp: Vector2 = layer.to_global(layer.map_to_local(c))
		var zone := "camp" if in_camp else _zone(wp, lname)
		var h := _hash(c, lname)
		var pick := ""
		match kind:
			"tree":
				pick = _pick_tree(zone, wp, h)
			"dead":
				pick = "dead_big" if h % 2 == 0 else "dead_broken"
			"bush":
				var b: Array = BUSHES[zone]
				pick = b[h % b.size()]
			"stump":
				pick = "stump"
			"log":
				pick = "log"
		_place(layer, c, pick, h)
		_stats[pick] = _stats.get(pick, 0) + 1
		# Подлесок у деревьев в лесах (не в городе, не в лагере)
		if kind == "tree" and zone in ["taiga", "oakwood", "mixed", "darkwood", "cursed", "mire"] \
				and float((h >> 8) % 1000) / 1000.0 < UNDERGROWTH:
			adds.append([c, zone, h])
	for a in adds:
		var c: Vector2i = a[0]
		var h: int = a[2]
		var off := Vector2i(((h >> 4) % 13) - 6, 3 + ((h >> 12) % 4))
		var nc := c + off
		if occupied.has(nc):
			continue
		var wp: Vector2 = layer.to_global(layer.map_to_local(nc))
		if _is_hazard(wp, hazards):
			continue
		var opts: Array = BUSHES[a[1]] + ["rocks", "stump", "log"]
		var pick: String = opts[(h >> 16) % opts.size()]
		occupied[nc] = true
		_place(layer, nc, pick, h >> 3)
		_stats["+" + pick] = _stats.get("+" + pick, 0) + 1


func _old_kind(src: TileSetAtlasSource, ac: Vector2i) -> String:
	var file := src.texture.resource_path.get_file()
	var reg := src.get_tile_texture_region(ac)
	if file == "autumn_trees.png" and reg.size.y >= 190:
		return "tree"
	for e in OLD.get(file, []):
		if e[0] == reg:
			return e[1]
	return ""


func _zone(wp: Vector2, lname: String) -> String:
	if lname == "PurpleForest":
		return "cursed"
	if lname == "Wilds":
		return "mire"
	# Размытые границы: точку немного «водит» шум
	var p := wp + Vector2(_warp.get_noise_2d(wp.x, wp.y), _warp.get_noise_2d(wp.y + 777.0, wp.x - 333.0)) * 260.0
	if MIRE.has_point(p):
		return "mire"
	if PLAY.has_point(p):
		return "town" if p.x < 900.0 else "grove"
	if p.y < PLAY.position.y:
		return "taiga"
	if p.y > MIRE.end.y:
		return "darkwood"
	if p.x < PLAY.position.x:
		return "oakwood"
	if p.x > PLAY.end.x:
		return "mixed"
	# По бокам от болота
	return "oakwood" if p.x < MIRE.position.x else "mixed"


func _pick_tree(zone: String, wp: Vector2, h: int) -> String:
	var weights: Dictionary = ZONES[zone]
	var total := 0.0
	var ws := {}
	for k in weights:
		var w: float = weights[k] * exp(1.6 * (_noise[k] as FastNoiseLite).get_noise_2d(wp.x, wp.y))
		ws[k] = w
		total += w
	var r := float(h % 100000) / 100000.0 * total
	for k in ws:
		r -= ws[k]
		if r <= 0.0:
			return k
	return weights.keys()[0]


## Ставит вариант: размер (если у вида их два) и отражение — по хешу клетки
func _place(layer: TileMapLayer, c: Vector2i, kind: String, h: int) -> void:
	var variants: Array = []
	for n in _meta:
		if _meta[n]["kind"] == kind:
			variants.append(n)
	variants.sort()
	# Крупный вариант чаще: 60/40
	var v: String = variants[0] if variants.size() == 1 or (h >> 5) % 10 < 6 else variants[1]
	var sid := _source_for(layer.tile_set, v)
	layer.set_cell(c, sid, Vector2i.ZERO, 1 if (h >> 7) % 2 == 1 else 0)


func _source_for(ts: TileSet, variant: String) -> int:
	if not _sources.has(ts):
		_sources[ts] = {}
		# Уже созданные при прошлом запуске источники — переиспользуем
		for i in ts.get_source_count():
			var sid := ts.get_source_id(i)
			var s := ts.get_source(sid) as TileSetAtlasSource
			if s and s.texture == _atlas and s.has_meta("forest_variant"):
				_sources[ts][s.get_meta("forest_variant")] = sid
	if _sources[ts].has(variant):
		return _sources[ts][variant]
	var m: Dictionary = _meta[variant]
	var rect := Rect2i(m["rect"][0], m["rect"][1], m["rect"][2], m["rect"][3])
	var src := TileSetAtlasSource.new()
	src.texture = _atlas
	src.margins = rect.position
	src.texture_region_size = rect.size
	src.use_texture_padding = false
	src.set_meta("forest_variant", variant)
	var sid := ts.add_source(src)
	src.create_tile(Vector2i.ZERO)
	# Основание ствола — в центре клетки (как у старых деревьев: низ спрайта
	# чуть ниже клетки, на высоту травы под деревом)
	var origin := Vector2i(0, rect.size.y / 2 - int(m["base"]))
	src.get_tile_data(Vector2i.ZERO, 0).texture_origin = origin
	var alt := src.create_alternative_tile(Vector2i.ZERO)
	var td := src.get_tile_data(Vector2i.ZERO, alt)
	td.flip_h = true
	td.texture_origin = origin
	_sources[ts][variant] = sid
	return sid


## Слои, где подлесок ставить нельзя (вода, пропасть, каньон, обрывы)
func _hazard_layers(root: Node) -> Array:
	var out: Array = []
	for n in ["Water", "Chasm", "Canyon", "Cliffs", "Stone", "Town"]:
		var l := root.get_node_or_null(n) as TileMapLayer
		if l:
			out.append(l)
	return out


func _is_hazard(wp: Vector2, hazards: Array) -> bool:
	for l in hazards:
		var lp: Vector2 = (l as TileMapLayer).to_local(wp)
		if (l as TileMapLayer).get_cell_source_id((l as TileMapLayer).local_to_map(lp)) >= 0:
			return true
	return false


## Старые источники деревьев, которыми больше ничто не пользуется, убираем —
## иначе их текстура (autumn_trees.png) грузилась бы в память впустую
func _drop_unused(root: Node) -> void:
	var by_ts := {}
	for layer in root.find_children("*", "TileMapLayer", true, false):
		if layer != root and layer.owner != root:
			continue
		var ts: TileSet = layer.tile_set
		if ts == null:
			continue
		if not by_ts.has(ts):
			by_ts[ts] = {}
		for c in layer.get_used_cells():
			by_ts[ts][layer.get_cell_source_id(c)] = true
	for ts in by_ts:
		var ids := []
		for i in ts.get_source_count():
			ids.append(ts.get_source_id(i))
		for sid in ids:
			var s := ts.get_source(sid) as TileSetAtlasSource
			if s == null or s.texture == null or by_ts[ts].has(sid):
				continue
			if s.texture.resource_path.get_file() == "autumn_trees.png":
				ts.remove_source(sid)
				_stats["-old_src"] = _stats.get("-old_src", 0) + 1


func _hash(c: Vector2i, salt: String) -> int:
	return absi(hash(Vector3i(c.x, c.y, hash(salt) % 100000)))
