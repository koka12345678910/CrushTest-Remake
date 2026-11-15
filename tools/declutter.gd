extends SceneTree
## Меньше мелочи на reference_map: убрать то, что читается мусором и ямами,
## остальное проредить «по смыслу».
##
## Каждый спрайт пропа узнаётся по своему куску атласа (файл + регион) и
## попадает в категорию из CATS:
##   remove — убирается везде: старые тёмные декали кустов (сверху выглядят
##            ямами), земляные кочки с камнями, корни-трещины, бледные
##            пиксельные камушки/столбики, кучка красной листвы, пятно грязи;
##   [r, near_k] — прореживание: остаётся проп, если ближе r нет оставленного
##            той же категории. У домов, руин и лагерей (ближе NEAR) расстояние
##            r * near_k — там мусор к месту, и такие пропы отбираются первыми;
##            вдали от построек обломки и доски без «источника» реже (r * FAR_K).
## Деревья, кусты, вода, домашняя утварь (бочки, ящики, палатки...) не трогаются.
## Маленькие прямоугольники коллизии у убранных твёрдых пропов уходят из
## Collision (static_shapes), как в forest_paths.gd.
##
## Запуск:
##   godot --headless --path . -s res://tools/declutter.gd
## После — перепечь навмеш (коллизия поменялась):
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res

const MAP := "res://reference_map_level/reference_map.tscn"
const LAYERS := ["Grime", "SouthMarks", "Objects/Decor", "Objects/Wilds", "Objects/Ruins", "Objects/PurpleForest"]
## Ближе — «у постройки»
const NEAR := 280.0
## Обломки и доски вдали от построек — во столько раз реже
const FAR_K := 1.8

## Категории: ключ "файл|x,y,w,h" региона → категория
const CATS := {
	# тёмные декали кустов (Grime/SouthMarks) — сверху как ямы
	"ruin_art.png|1112,1294,246,86": "remove",
	"ruin_art.png|862,1294,246,86": "remove",
	"ruin_art.png|1174,1188,142,96": "remove",
	"ruin_art.png|1320,1188,142,96": "remove",
	"ruin_art.png|686,934,186,128": "remove",
	"ruin_art.png|876,934,186,128": "remove",
	# земляная кочка с камнями (тёмная яма)
	"ruin_art.png|0,1068,134,116": "remove",
	# корни-трещины
	"ruin_art.png|0,1388,222,84": "remove",
	"ruin_art.png|138,1294,232,90": "remove",
	"ruin_art.png|1422,1294,294,86": "remove",
	"ruin_art.png|278,1476,306,78": "remove",
	# кучка красной листвы, пятно грязи, бледный пиксельный камень
	"ruin_art.png|628,1476,116,78": "remove",
	"ruin_art.png|964,1560,68,44": "remove",
	"grassland_props.png|1354,968,46,46": "remove",
	# пучки травы и мох (декали)
	"ruin_art.png|1108,1560,60,36": "tuft",
	"ruin_art.png|1172,1560,44,36": "tuft",
	"ruin_art.png|1220,1560,28,36": "tuft",
	"ruin_art.png|1252,1560,36,36": "tuft",
	"ruin_art.png|672,1560,80,52": "tuft",
	# скелеты
	"ruin_art.png|1206,1388,102,80": "skeleton",
	"ruin_art.png|226,1388,102,84": "skeleton",
	# каменные обломки, кучи, плиты
	"ruin_art.png|140,1188,188,100": "rubble",
	"ruin_art.png|1414,1476,162,72": "rubble",
	"ruin_art.png|1580,1476,112,66": "rubble",
	"ruin_art.png|1696,1476,152,66": "rubble",
	"ruin_art.png|210,1560,74,58": "rubble",
	"ruin_art.png|332,1188,118,100": "rubble",
	"ruin_art.png|332,1388,182,84": "rubble",
	"ruin_art.png|518,1388,150,82": "rubble",
	"ruin_art.png|748,1476,110,76": "rubble",
	"ruin_art.png|850,1388,150,82": "rubble",
	# доски, брёвна, кучи досок
	"ruin_art.png|0,1476,198,80": "planks",
	"ruin_art.png|1004,1388,198,80": "planks",
	"ruin_art.png|1612,1068,192,108": "planks",
	"ruin_art.png|1790,934,164,118": "planks",
	"ruin_art.png|288,1560,208,56": "planks",
	"ruin_art.png|454,1188,234,98": "planks",
	"ruin_art.png|500,1560,168,54": "planks",
	"ruin_art.png|848,1188,234,98": "planks",
	# подлесок из forest_trees
	"forest_trees.png|407,1222,133,130": "stump",
	"forest_trees.png|1789,878,150,150": "log",
	"forest_trees.png|0,1222,137,140": "rocks",
	"forest_trees.png|274,1222,129,130": "rocks",
	"forest_trees.png|1460,878,160,160": "dry_bush",
	"forest_trees.png|1624,878,161,160": "dry_bush",
	"forest_trees.png|141,1222,129,130": "fern",
	"forest_trees.png|735,1222,60,60": "fern",
	"forest_trees.png|544,1222,119,120": "grass",
	"forest_trees.png|667,1222,64,64": "grass",
}
## [r, near_k]
const THIN := {
	"tuft": [260.0, 1.0],
	"skeleton": [700.0, 0.6],
	"rubble": [460.0, 0.45],
	"planks": [420.0, 0.45],
	"stump": [320.0, 1.0],
	"log": [360.0, 1.0],
	"rocks": [380.0, 1.0],
	"dry_bush": [260.0, 1.0],
	"fern": [180.0, 1.0],
	"grass": [170.0, 1.0],
}
## Твёрдые: у них может быть прямоугольник коллизии
const SOLID := ["rubble", "stump", "log", "rocks", "remove"]
## Регионы руин (стены, арки, колонны) — тоже «постройки» для NEAR
const RUIN_MIN_AREA := 140 * 140

var report: Array[String] = []


func _initialize() -> void:
	var lvl := (load(MAP) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var structures := _structures(lvl)
	var items: Array = []        # [layer, cell, pos, cat]
	var counts := {}
	for lp in LAYERS:
		var t := lvl.get_node(lp) as TileMapLayer
		var xf := _xf(t, lvl)
		for c in t.get_used_cells():
			var src := t.tile_set.get_source(t.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			var file := src.texture.resource_path.get_file()
			var reg := src.get_tile_texture_region(t.get_cell_atlas_coords(c))
			var key := "%s|%d,%d,%d,%d" % [file, reg.position.x, reg.position.y, reg.size.x, reg.size.y]
			var cat: String = CATS.get(key, "")
			# Бледные пиксельные камни, столбики, брёвнышки — весь лист
			if file == "autumn_decorations.png":
				cat = "remove"
			if cat == "":
				continue
			items.append([t, c, xf * t.map_to_local(c), cat])
			counts[cat] = counts.get(cat, 0) + 1
	var removed: Array = []
	var kept := {}
	for cat in counts:
		var group: Array = items.filter(func(e): return e[3] == cat)
		if cat == "remove":
			removed.append_array(group)
			continue
		var r: float = THIN[cat][0]
		var near_k: float = THIN[cat][1]
		# Сначала те, что у построек, дальше — в случайном, но постоянном порядке
		for e in group:
			e.append(_near(e[2], structures, NEAR))
		group.sort_custom(func(a, b):
			if a[4] != b[4]:
				return a[4]
			return hash(a[2]) < hash(b[2]))
		var far_k := FAR_K if cat in ["rubble", "planks"] else 1.0
		var keep := _poisson(group, func(e): return r * (near_k if e[4] else far_k))
		var ks := {}
		for e in keep:
			ks[e] = true
		for e in group:
			if not ks.has(e):
				removed.append(e)
		kept[cat] = keep.size()
	var solid_pos: Array[Vector2] = []
	for e in removed:
		(e[0] as TileMapLayer).erase_cell(e[1])
		if e[3] in SOLID and not (e[0] as TileMapLayer).name in ["Grime", "SouthMarks"]:
			solid_pos.append(e[2])
	var cut := _cut_collision(lvl, solid_pos)
	for cat in counts:
		report.append("  %s: было %d, осталось %d" % [cat, counts[cat], kept.get(cat, 0)])
	report.append("убрано пропов %d, прямоугольников коллизии %d" % [removed.size(), cut])
	var g := lvl.get_node_or_null("Ground") as CanvasItem
	if g != null and g.material == null:
		report.append("НЕ сохранено: материал земли не загрузился — сначала godot --headless --path . --import")
	else:
		var ps := PackedScene.new()
		var err := ps.pack(lvl)
		if err == OK:
			err = ResourceSaver.save(ps, MAP)
		report.append("%s сохранена: %s" % [MAP.get_file(), error_string(err)])
	lvl.free()
	for line in report:
		print(line)
	quit()


## Преобразование из координат узла в координаты сцены (без дерева сцены)
func _xf(n: Node, root_node: Node) -> Transform2D:
	var t := Transform2D.IDENTITY
	var cur := n
	while cur != null and cur != root_node:
		if cur is Node2D:
			t = (cur as Node2D).transform * t
		cur = cur.get_parent()
	return t


## Точки построек: дома и прочие спрайты в Objects, лагерь, костры,
## крупные куски руин, клетки города
func _structures(lvl: Node) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var objs := lvl.get_node("Objects")
	for c in objs.get_children():
		if c is Sprite2D or (c is Node2D and String(c.name).begins_with("Bonfire")) or c.name == "RuinedCamp":
			pts.append((c as Node2D).position)
	var town := lvl.get_node_or_null("Town") as TileMapLayer
	if town:
		var xf := _xf(town, lvl)
		var i := 0
		for c in town.get_used_cells():
			if i % 3 == 0:
				pts.append(xf * town.map_to_local(c))
			i += 1
	var ruins := lvl.get_node("Objects/Ruins") as TileMapLayer
	var rxf := _xf(ruins, lvl)
	for c in ruins.get_used_cells():
		var src := ruins.tile_set.get_source(ruins.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null:
			continue
		var reg := src.get_tile_texture_region(ruins.get_cell_atlas_coords(c))
		var file := src.texture.resource_path.get_file()
		if file != "forest_trees.png" and reg.size.x * reg.size.y >= RUIN_MIN_AREA:
			pts.append(rxf * ruins.map_to_local(c))
	return pts


func _near(p: Vector2, pts: Array[Vector2], d: float) -> bool:
	for q in pts:
		if absf(q.x - p.x) < d and absf(q.y - p.y) < d and q.distance_to(p) < d:
			return true
	return false


## Жадный отбор: проп остаётся, если ближе r(e) нет оставленного
func _poisson(order: Array, r_of: Callable) -> Array:
	var grid := {}
	var cs := 200.0
	var out: Array = []
	for e in order:
		var p: Vector2 = e[2]
		var r: float = r_of.call(e)
		var gc := Vector2i(floor(p.x / cs), floor(p.y / cs))
		var span := int(ceil(r / cs))
		var ok := true
		for dy in range(-span, span + 1):
			for dx in range(-span, span + 1):
				for q in grid.get(gc + Vector2i(dx, dy), []):
					if (q as Vector2).distance_to(p) < r:
						ok = false
						break
				if not ok:
					break
			if not ok:
				break
		if ok:
			out.append(e)
			if not grid.has(gc):
				grid[gc] = []
			grid[gc].append(p)
	return out


func _cut_collision(lvl: Node, pos: Array[Vector2]) -> int:
	var body := lvl.get_node_or_null("Collision")
	if body == null or body.get_script() == null or not body.get_script().resource_path.ends_with("static_shapes.gd"):
		return 0
	var shapes: Array = body.get("shapes")
	var xf: Array = body.get("shape_transforms")
	var ns: Array[Shape2D] = []
	var nx: Array[Transform2D] = []
	var bt := _xf(body, lvl)
	var cut := 0
	for i in shapes.size():
		var s: Shape2D = shapes[i]
		var o: Vector2 = bt * (xf[i] as Transform2D).origin
		var drop := false
		if s is RectangleShape2D and s.size.x <= 72.0 and s.size.y <= 72.0:
			for p in pos:
				if o.distance_to(p) < 14.0:
					drop = true
					break
		if drop:
			cut += 1
		else:
			ns.append(s)
			nx.append(xf[i])
	body.set("shapes", ns)
	body.set("shape_transforms", nx)
	return cut
