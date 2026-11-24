extends SceneTree
## holmvik_yards.gd — обустройство дворов Хольмвика (reference_map).
##
## После расстановки домов и улиц между домами и рядами остались пустые газоны:
## ровная трава без единой вещи — город выглядит недоделанным. Здесь они
## находятся сами и обставляются как жилые дворы, разорённые несколько дней
## назад: плетни вдоль улиц с калиткой, поленницы и колоды, грядки, бельё,
## загоны со стогом и корытом, бочки и мешки, брошенные телеги; утоптанная
## земля у хозяйства (шейдер земли по маске троп).
##
## Двор — клетка сетки CELL, которая: в черте города (TOWN, без площади,
## двора храма, гавани), не улица (cobble_map R), не тропа (paths R), не под
## картинкой дома/стены/башни, не в коллизии (Collision, стены блокаута и
## маршрута, тела предметов), не под деревом и не у воды. Связные клетки —
## области; длинные полосы режутся на участки по LOT_W. Участок получает
## хозяйство по своему хешу (одинаково при каждом запуске).
##
## Шаги:
##   scan  — только найти: список участков и картинка user://yards.png;
##   apply — обставить (мета yard_v1; прежнее с этой метой убирается),
##           сохранить сцену; потом — ground и bake_navmesh.gd;
##   ground — утоптанная земля во дворах: маска троп (paths.res, R) у вещей
##           и от калитки к дому. Повторять можно (рисует поверх).
## Порядок: holmvik_town.gd props → holmvik_route.gd apply → temple_court →
## holmvik_yards_art.gd (атлас партии 5) → --import → holmvik_yards apply
## ground → bake_navmesh → place_order.
## Партия 5 (town_yards_hd): постройки (курятник, нужник, сарай, коптильня,
## будка, ульи, погреб, навес), заборы (штакетник с калиткой, каменная
## кладка, жерди — у каждого двора свой), быт, следы погрома и земля —
## плоские декали в узле YardGround (под Objects, z -17).

const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const COBBLE := TEX + "terrain/cobble_map.res"
const PATHS := TEX + "terrain/paths.res"
const WORLD := Rect2(-3520, -704, 9408, 5120)
const MASK_PX := 4.0
const META := "yard_v1"

const CELL := 16.0
## Черта города (верхний и нижний город внутри стен) и исключения
const TOWN := Rect2(-2290, 60, 3740, 2520)
const EXCLUDE := [
	Rect2(-580, 905, 580, 390),    # площадь ярлов
	Rect2(740, 840, 720, 560),     # двор храма
	Rect2(1380, 1300, 300, 600),   # гавань
]
## Участок: ширина нарезки полос и минимальная площадь (клеток)
const LOT_W := 240.0
const MIN_CELLS := 26
## Картинка, крупнее которой предмет считается «закрывающим землю»
const COVER_MIN := Vector2(60, 60)

## Хозяйства: items — что ставится по порядку (первое — главное, обычно
## постройка у задней кромки двора), ground — плоская земля под ним
## (декали партии 5: грядки, солома, щепа, лужи...)
const KITS := {
	"woodyard": {"items": [["y5", "b_leanto"], ["town", "yard_woodpile"], ["town", "yard_chopblock"], ["y5", "l_woodstack"], ["camp", "log_a"], ["farm", "wheelbarrow"]],
		"ground": ["g_chips"]},
	"garden": {"items": [["town", "yard_garden"], ["town", "yard_rainbarrel"], ["hd", "scarecrow@60x90"], ["y5", "l_baskets"], ["farm", "tools"], ["hd", "bucket@62x85"]],
		"ground": ["g_garden", "g_plot"]},
	"laundry": {"items": [["town", "yard_laundry"], ["y5", "l_washtub"], ["y5", "l_bench"], ["hd", "bucket@62x85"], ["town", "yard_rainbarrel"], ["hd", "barrel@52x77"]],
		"ground": ["g_puddle"]},
	"livestock": {"items": [["town", "yard_pen"], ["farm", "trough"], ["farm", "haystack"], ["farm", "bale_a"], ["y5", "l_sheaves"], ["farm", "tools"]],
		"ground": ["g_dung", "g_straw"]},
	"storage": {"items": [["y5", "b_cellar"], ["hd", "barrels2@112x113"], ["hd", "crates_stack@102x138"], ["y5", "l_pots"], ["hd", "sacks@136x107"], ["y5", "l_churn"]],
		"ground": ["g_mud"]},
	"farmyard": {"items": [["farm", "haystack"], ["farm", "plough"], ["y5", "l_sheaves"], ["farm", "bale_b"], ["y5", "l_handcart"], ["farm", "trough"]],
		"ground": ["g_straw"]},
	"coop": {"items": [["y5", "b_coop"], ["y5", "l_baskets"], ["farm", "bale_b"], ["y5", "l_pots"], ["hd", "bucket@62x85"]],
		"ground": ["g_straw", "g_dung"]},
	"workshop": {"items": [["y5", "b_toolshed"], ["y5", "l_grindstone"], ["y5", "l_anvil"], ["y5", "l_woodstack"], ["y5", "l_handcart"], ["town", "yard_chopblock"]],
		"ground": ["g_chips"]},
	"apiary": {"items": [["y5", "b_beehives"], ["y5", "l_herbrack"], ["y5", "l_bench"], ["y5", "l_pots"], ["town", "yard_rainbarrel"]],
		"ground": ["g_herbs", "g_plot"]},
	"smokehouse": {"items": [["y5", "b_smokehouse"], ["y5", "l_cauldron"], ["y5", "l_woodstack"], ["y5", "l_table"], ["hd", "barrel@52x77"]],
		"ground": ["g_ash", "g_chips"]},
	"household": {"items": [["y5", "b_outhouse"], ["y5", "l_table"], ["y5", "l_spinning"], ["y5", "l_washtub"], ["y5", "l_churn"], ["y5", "l_bench"]],
		"ground": ["g_mud"]},
	"kennel": {"items": [["y5", "b_kennel"], ["y5", "b_outhouse"], ["y5", "l_handcart"], ["y5", "l_woodstack"], ["y5", "l_baskets"]],
		"ground": ["g_mud", "g_straw"]},
	# Амбар на сваях (партия 6, атлас домов town_houses6_hd): зерно, мешки, сено
	"granary": {"items": [["h6", "storehouse"], ["y5", "l_sheaves"], ["farm", "bale_a"], ["y5", "l_baskets"], ["y5", "l_handcart"]],
		"ground": ["g_straw"]},
	"granary_b": {"items": [["h6", "storehouse_side"], ["farm", "haystack"], ["y5", "l_sheaves"], ["hd", "sacks@136x107"], ["y5", "l_handcart"]],
		"ground": ["g_straw", "g_mud"]},
	"granary_c": {"items": [["h6", "storehouse_back"], ["y5", "l_baskets"], ["farm", "bale_b"], ["town", "yard_rainbarrel"], ["y5", "l_pots"]],
		"ground": ["g_straw"]},
	# Двор обыскали и бросили: всё перевёрнуто и раскидано
	"raided": {"items": [["y5", "r_coop"], ["y5", "r_chest"], ["y5", "r_bench_spill"], ["y5", "r_sacks"], ["y5", "r_laundry"], ["y5", "r_woodpile"], ["y5", "r_wheel"]],
		"ground": ["g_straw", "g_mud"]},
	"raided_cart": {"items": [["y5", "r_cart_hay"], ["y5", "r_sacks"], ["y5", "r_chest"], ["y5", "r_bench_spill"], ["hd", "crate@84x106"]],
		"ground": ["g_straw", "g_mud"]},
}
## Мелочь, которая есть в любом дворе: после вещей хозяйства — отсюда
const CLUTTER := [["hd", "barrel@48x71"], ["hd", "bucket@62x85"], ["y5", "l_pots"], ["camp", "log_a"],
	["farm", "tools"], ["y5", "l_baskets"], ["town", "yard_rainbarrel"], ["y5", "l_bench"], ["y5", "l_churn"]]
const KIT_ORDER := ["woodyard", "garden", "laundry", "livestock", "storage", "raided", "coop", "workshop",
	"apiary", "smokehouse", "household", "kennel", "garden", "raided_cart", "farmyard", "coop", "raided",
	"granary", "granary_b", "granary_c"]

## Коллизия предметов у основания (px мира); бочки и ящики hd — без неё
## (их делает разбиваемыми breakables.gd во время игры). Постройки партии 5
## (b_*) — по подножию картинки
const BODY := {
	"yard_woodpile": Vector2(100, 18), "yard_garden": Vector2(96, 24), "yard_well": Vector2(54, 22),
	"yard_pen": Vector2(84, 34), "yard_rainbarrel": Vector2(24, 10), "yard_chopblock": Vector2(20, 8),
	"haystack": Vector2(64, 22), "trough": Vector2(60, 12), "bale_a": Vector2(46, 14), "bale_b": Vector2(46, 14),
	"cart_broken@188x133": Vector2(80, 22), "scarecrow@60x90": Vector2(10, 6), "wheelbarrow": Vector2(40, 10),
	"l_table": Vector2(50, 12), "l_handcart": Vector2(40, 10), "l_woodstack": Vector2(32, 12),
	"l_cauldron": Vector2(30, 10), "l_grindstone": Vector2(26, 8), "l_anvil": Vector2(20, 8),
	"l_spinning": Vector2(26, 8), "l_herbrack": Vector2(56, 6), "l_bench": Vector2(46, 8),
	"r_cart_hay": Vector2(70, 16), "r_coop": Vector2(44, 14), "r_chest": Vector2(40, 12),
	"r_woodpile": Vector2(52, 14), "r_bench_spill": Vector2(44, 10),
	"storehouse": Vector2(84, 22), "storehouse_back": Vector2(84, 22), "storehouse_side": Vector2(90, 22),
}
## Масштаб картинки в дворе (амбар из атласа домов — меньше, чем на улице)
const ITEM_K := {"storehouse": 0.7, "storehouse_back": 0.7, "storehouse_side": 0.7}
## Глубина коллизии построек b_* (ширина — подножие картинки)
const BUILDING_DEPTH := 20.0
## Листы: [png, json, текселей на px мира]
const SHEETS := {
	"town": ["town_props_hd.png", "town_props_hd.json", 2.0],
	"hd": ["hd_props.png", "hd_props.json", 2.0],
	"farm": ["farm_props.png", "farm_props.json", 2.0],
	"camp": ["camp_hd.png", "camp_hd.json", 2.0],
	"y5": ["town_yards_hd.png", "town_yards_hd.json", 2.5],
	"h6": ["town_houses6_hd.png", "town_houses6_hd.json", 2.0],
}
## Заборы: лист, целый кусок, сломанный, короткий (или "" — целый в масштабе),
## масштаб, калитка (две картинки по краям прохода; "" — просто проход)
const FENCES := {
	"wattle": {"sheet": "farm", "long": "fence", "broken": "fence_broken", "short": "fence_short", "k": 1.0, "gate": ""},
	"picket": {"sheet": "y5", "long": "f_picket", "broken": "f_picket_broken", "short": "", "k": 0.78, "gate": "picket"},
	"stone": {"sheet": "y5", "long": "f_stone", "broken": "f_stone_broken", "short": "", "k": 0.85, "gate": ""},
	"rail": {"sheet": "y5", "long": "f_rail", "broken": "f_rail", "short": "", "k": 0.85, "gate": ""},
}
const FENCE_ORDER := ["wattle", "picket", "stone", "picket", "rail", "wattle", "stone"]
## Разорённым дворам — сломанные куски чаще, местами поваленный/сгоревший забор
const RAIDED_FENCE := ["r_fence_flat", "r_fence_burnt"]
## Земля двора: сколько декалей на участок (1 + клеток / GROUND_PER)
const GROUND_PER := 60
const GROUND_MAX := 2
## Сколько вещей на участок: 1 + клеток / ITEM_PER
const ITEM_PER := 26
const ITEM_MAX := 7
## Плетень вдоль улицы: участок шире FENCE_MIN_W, улица под ним по доле
## FENCE_ROAD ширины; калитка посередине шириной GATE_W
const FENCE_MIN_W := 130.0
const FENCE_ROAD := 0.55
const GATE_W := 46.0
const FENCE_BROKEN := 0.22
## Маска троп до дворов (сюда копируется оригинал при первом ground)
const PATHS_PRE := TEX + "terrain/paths_pre_yards.res"

var report: Array[String] = []
var _sheets := {}
var _cobble: Image
var _paths: Image
var _gw := 0
var _gh := 0
## 0 — двор, 1 — улица/тропа, 2 — закрыто картинкой, 3 — коллизия, 4 — вне города
var _grid: PackedByteArray


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["scan"]
	var lvl: Node = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	_load_masks()
	for k in SHEETS:
		_sheets[k] = [load(TEX + SHEETS[k][0]), JSON.parse_string(FileAccess.get_file_as_string(TEX + SHEETS[k][1]))]
	if "apply" in steps:
		_remove_old(lvl)
	_build_grid(lvl)
	var lots := _lots()
	report.append("участков: %d" % lots.size())
	if "apply" in steps:
		_dress(lvl, lots)
	elif "ground" in steps:
		report.append("ground — только вместе с apply (-- apply ground): земля ложится по вещам этого запуска")
		steps.erase("ground")
	_debug_image(lots)
	if "apply" in steps:
		var ps := PackedScene.new()
		var err := ps.pack(lvl)
		if err == OK:
			err = ResourceSaver.save(ps, SCENE)
		report.append("сцена сохранена: %s" % error_string(err))
	if "ground" in steps:
		_ground()
	for r in report:
		print("[yards] ", r)
	lvl.free()
	quit()


func _load_masks() -> void:
	_cobble = (load(COBBLE) as Texture2D).get_image()
	if _cobble.is_compressed():
		_cobble.decompress()
	# Дворы ищутся по маске троп ДО утоптанной земли дворов (иначе повторный
	# запуск принял бы свою же землю за тропы)
	var src := PATHS_PRE if ResourceLoader.exists(PATHS_PRE) else PATHS
	_paths = (load(src) as Texture2D).get_image()
	if _paths.is_compressed():
		_paths.decompress()
	_paths.convert(Image.FORMAT_RGBA8)


func _mask(img: Image, p: Vector2) -> Color:
	var x := int((p.x - WORLD.position.x) / MASK_PX)
	var y := int((p.y - WORLD.position.y) / MASK_PX)
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)


func _remove_old(lvl: Node) -> void:
	var n := 0
	for c in lvl.get_node("Objects").get_children():
		if c.has_meta(META):
			c.get_parent().remove_child(c)
			c.free()
			n += 1
	var g := lvl.get_node_or_null("YardGround")
	if g:
		n += g.get_child_count()
		lvl.remove_child(g)
		g.free()
	report.append("убрано прежнего: %d" % n)


# ───────────────────────── сетка ─────────────────────────

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x - TOWN.position.x) / CELL), int((p.y - TOWN.position.y) / CELL))


func _center(c: Vector2i) -> Vector2:
	return TOWN.position + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _mark_rect(r: Rect2, v: int) -> void:
	var a := _cell_of(r.position)
	var b := _cell_of(r.end)
	for y in range(maxi(a.y, 0), mini(b.y, _gh - 1) + 1):
		for x in range(maxi(a.x, 0), mini(b.x, _gw - 1) + 1):
			var i := y * _gw + x
			if _grid[i] == 0 or v == 3:
				_grid[i] = v


func _build_grid(lvl: Node) -> void:
	_gw = int(TOWN.size.x / CELL)
	_gh = int(TOWN.size.y / CELL)
	_grid = PackedByteArray()
	_grid.resize(_gw * _gh)
	for y in _gh:
		for x in _gw:
			var p := _center(Vector2i(x, y))
			var v := 0
			var ex := false
			for e in EXCLUDE:
				if (e as Rect2).has_point(p):
					ex = true
			if ex:
				v = 4
			elif _mask(_cobble, p).r > 0.12 or _mask(_paths, p).r > 0.25:
				v = 1
			_grid[y * _gw + x] = v
	# Картинки на Objects: дома, стены, башни, большие предметы закрывают землю
	var objects := lvl.get_node("Objects")
	for c in objects.get_children():
		if c is Sprite2D:
			var s := c as Sprite2D
			var r := s.get_rect()
			var gr := s.get_global_transform() * r
			if gr.size.x >= COVER_MIN.x and gr.size.y >= COVER_MIN.y:
				# Нижние 85% картинки — тело дома; верх (крыша, шпиль) уже над
				# землёй за домом, она тоже не видна
				_mark_rect(gr, 2)
			for b in s.get_children():
				if b is StaticBody2D:
					for cs in b.get_children():
						if cs is CollisionShape2D and (cs as CollisionShape2D).shape is RectangleShape2D:
							var sz := ((cs as CollisionShape2D).shape as RectangleShape2D).size
							var t := (cs as CollisionShape2D).get_global_transform()
							var rr := t * Rect2(-sz * 0.5, sz)
							_mark_rect(rr.grow(6.0), 3)
	# Тайлы: деревья и крупный декор (источники с forest_variant) — клетка закрыта
	for layer in objects.get_children():
		if layer is TileMapLayer:
			var tl := layer as TileMapLayer
			for cell in tl.get_used_cells():
				var src := tl.tile_set.get_source(tl.get_cell_source_id(cell)) as TileSetAtlasSource
				if src == null:
					continue
				var p := tl.to_global(tl.map_to_local(cell))
				var big := src.has_meta("forest_variant")
				_mark_rect(Rect2(p - Vector2(24, 24), Vector2(48, 40)) if big else Rect2(p - Vector2(10, 10), Vector2(20, 20)), 2)
	# Коллизия мира
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	for i in shapes.size():
		var rs := shapes[i] as RectangleShape2D
		if rs:
			var o: Vector2 = (xf[i] as Transform2D).origin
			_mark_rect(Rect2(o - rs.size * 0.5, rs.size).grow(6.0), 3)
	for path in ["Blockout/Walls", "RouteWalls"]:
		var body := lvl.get_node_or_null(path)
		if body == null:
			continue
		for cs in body.get_children():
			if cs is CollisionShape2D and (cs as CollisionShape2D).shape is RectangleShape2D:
				var sz := ((cs as CollisionShape2D).shape as RectangleShape2D).size
				_mark_rect(Rect2((cs as Node2D).position - sz * 0.5, sz).grow(6.0), 3)
	# Вода
	var water := lvl.get_node_or_null("Water") as TileMapLayer
	if water:
		for cell in water.get_used_cells():
			var p := water.to_global(water.map_to_local(cell))
			_mark_rect(Rect2(p - Vector2(40, 40), Vector2(80, 80)), 3)


# ───────────────────────── обустройство ─────────────────────────

var _used := {}
## Для земли: [центр, полуоси] пятен и [калитка, глубь двора] тропинок
var _patches := []
var _trails := []


func _g(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _gw or c.y >= _gh:
		return 4
	return _grid[c.y * _gw + c.x]


func _art(sheet: String, key: String) -> Rect2:
	var r: Variant = _sheets[sheet][1].get(key)
	if r is Dictionary:
		r = (r as Dictionary).get("rect", [])
	var a: Array = r
	return Rect2(a[0], a[1], a[2], a[3])


## Все клетки прямоугольника — свободный двор (не занятые), вокруг на margin
## нет улицы
func _free(fp: Rect2, margin: float) -> bool:
	var a := _cell_of(fp.position)
	var b := _cell_of(fp.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var c := Vector2i(x, y)
			if _g(c) != 0 or _used.has(c):
				return false
	var m := fp.grow(margin)
	a = _cell_of(m.position)
	b = _cell_of(m.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var v := _g(Vector2i(x, y))
			if v == 1 or v == 4:
				return false
	return true


func _use(fp: Rect2) -> void:
	var a := _cell_of(fp.position)
	var b := _cell_of(fp.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			_used[Vector2i(x, y)] = true


## Насколько клетка у края участка (у дома, у стены): соседи не-двор в радиусе 2
func _hug(c: Vector2i) -> int:
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var v := _g(c + Vector2i(dx, dy))
			if v == 2 or v == 3:
				n += 1
	return n


## Ширина/высота картинки предмета в px мира
func _ts(sheet: String) -> float:
	return float(SHEETS[sheet][2])


func _wsize(sheet: String, key: String) -> Vector2:
	return _art(sheet, key).size / _ts(sheet) * float(ITEM_K.get(key, 1.0))


## Коллизия предмета (px мира): из BODY, у построек b_* — по подножию картинки
func _body_of(sheet: String, key: String) -> Vector2:
	if BODY.has(key):
		return BODY[key]
	if key.begins_with("b_"):
		var a: Array = _sheets[sheet][1][key]
		var w := _wsize(sheet, key).x
		var foot := (float(a[5]) - float(a[4])) if a.size() >= 6 else 0.8
		return Vector2(w * foot * 0.92, BUILDING_DEPTH)
	return Vector2.ZERO


func _dress(lvl: Node, lots: Array) -> void:
	var objects := lvl.get_node("Objects")
	var ground := Node2D.new()
	ground.name = "YardGround"
	ground.z_as_relative = false
	ground.z_index = -17
	lvl.add_child(ground)
	lvl.move_child(ground, objects.get_index())
	ground.owner = lvl
	var counts := {}
	var fences := {}
	var decals := 0
	for lot in lots:
		var rect: Rect2 = lot["rect"]
		var cells: Array = lot["cells"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(rect.get_center()))
		var kit_name: String = KIT_ORDER[rng.randi() % KIT_ORDER.size()]
		# Узкая полоска — без стога, загона и больших построек
		if rect.size.y < 70.0 and kit_name in ["livestock", "farmyard", "workshop", "smokehouse", "granary", "granary_b", "granary_c"]:
			kit_name = "storage"
		var kit: Dictionary = KITS[kit_name]
		counts[kit_name] = counts.get(kit_name, 0) + 1
		var raided := kit_name.begins_with("raided")
		# Забор вдоль улицы (сначала — чтобы вещи не встали на его линию)
		var ftype: String = FENCE_ORDER[rng.randi() % FENCE_ORDER.size()]
		var gate := _fence(objects, lvl, lot, rng, ftype, raided)
		if gate != Vector2.ZERO:
			fences[ftype] = fences.get(ftype, 0) + 1
		# Земля: грядки и огород занимают место, остальное лежит под вещами
		var nground := mini(1 + cells.size() / GROUND_PER, GROUND_MAX)
		var gi := 0
		var gtries := 0
		var keys: Array = kit["ground"]
		while gi < nground and gtries < 6:
			var key: String = keys[gtries % keys.size()]
			gtries += 1
			if _place_decal(ground, lvl, cells, key, rng, key in ["g_garden", "g_plot", "g_herbs"]):
				gi += 1
				decals += 1
		var want := mini(1 + cells.size() / ITEM_PER, ITEM_MAX)
		var placed := 0
		for item in kit["items"]:
			if placed >= want:
				break
			if _place_in(objects, lvl, cells, item[0], item[1], rng):
				placed += 1
		var tries := 0
		while placed < want and tries < 10:
			tries += 1
			var item: Array = CLUTTER[rng.randi() % CLUTTER.size()]
			if _place_in(objects, lvl, cells, item[0], item[1], rng):
				placed += 1
		if gate != Vector2.ZERO:
			# Тропинка от калитки вглубь двора, к противоположной кромке
			var far := rect.position.y + CELL + 10.0 if _fence_dir > 0 else rect.end.y - CELL - 10.0
			_trails.append([gate, Vector2(gate.x + rng.randf_range(-30, 30), far)])
	report.append("хозяйства: %s" % counts)
	report.append("заборы: %s; вещей %d; земли %d" % [fences, _patches.size(), decals])


## Плоская декаль земли на участке: целиком на дворе, не на занятом
func _place_decal(parent: Node2D, lvl: Node, cells: Array, key: String, rng: RandomNumberGenerator, occupy: bool) -> bool:
	if not _sheets["y5"][1].has(key):
		return false
	var k := rng.randf_range(0.8, 1.0)
	var sz := _wsize("y5", key) * k
	for t in 30:
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var at := _center(c) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		var r := Rect2(at - sz * 0.5, sz).grow(-sz.y * 0.12)
		if not _all_yard(r):
			continue
		var s := Sprite2D.new()
		s.name = "YardGround_%s_%d_%d" % [key, int(at.x), int(at.y)]
		s.texture = _sheets["y5"][0]
		s.region_enabled = true
		s.region_rect = _art("y5", key)
		s.scale = Vector2.ONE * k / _ts("y5")
		s.flip_h = rng.randf() < 0.5
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Грядки — в полную силу, грязь/солома/зола — полупрозрачно: земля
		# под ними должна проступать, иначе пятно читается как плоский диск
		s.modulate.a = 1.0 if occupy else 0.72
		s.position = at
		s.set_meta(META, key)
		parent.add_child(s)
		s.owner = lvl
		if occupy:
			_use(r)
		return true
	return false


## Все клетки прямоугольника — двор, не занятые
func _all_yard(r: Rect2) -> bool:
	var a := _cell_of(r.position)
	var b := _cell_of(r.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if _g(Vector2i(x, y)) != 0 or _used.has(Vector2i(x, y)):
				return false
	return true


## Поставить предмет в лучшую из случайных клеток участка (ближе к краю)
func _place_in(objects: Node, lvl: Node, cells: Array, sheet: String, key: String, rng: RandomNumberGenerator) -> bool:
	if not _sheets[sheet][1].has(key):
		return false
	var ws := _wsize(sheet, key)
	var body := _body_of(sheet, key)
	var fw := maxf(body.x, ws.x * 0.7)
	var fh := maxf(body.y, 12.0)
	var best := Vector2.INF
	var best_s := -1.0
	for t in 24:
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var base := _center(c) + Vector2(rng.randf_range(-4, 4), CELL * 0.5 - 2.0)
		var fp := Rect2(base.x - fw * 0.5, base.y - fh, fw, fh)
		if not _free(fp, 10.0):
			continue
		# Постройки — к задней кромке двора (у стены дома, у забора)
		var s := float(_hug(c)) * (2.0 if key.begins_with("b_") or ITEM_K.has(key) else 1.0) + rng.randf() * 3.0
		if s > best_s:
			best_s = s
			best = base
	if best == Vector2.INF:
		return false
	var flip := rng.randf() < 0.5
	_sprite(objects, lvl, sheet, key, best, flip, body, float(ITEM_K.get(key, 1.0)))
	_use(Rect2(best.x - fw * 0.5, best.y - fh, fw, fh).grow(8.0))
	_patches.append([best + Vector2(0, -fh * 0.4), Vector2(fw * 0.75 + 10.0, fh + 12.0)])
	return true


## Забор по кромке участка, за которой улица — нижней, а если там нет,
## то задней (верхней): две половины от краёв к калитке посередине.
## Возвращает точку калитки (или ZERO); _fence_dir — какая кромка (+1 низ)
var _fence_dir := 1


func _fence(objects: Node, lvl: Node, lot: Dictionary, rng: RandomNumberGenerator, ftype: String, raided: bool) -> Vector2:
	var rect: Rect2 = lot["rect"]
	if rect.size.x < FENCE_MIN_W:
		return Vector2.ZERO
	for dir in [1, -1]:
		var gate := _fence_edge(objects, lvl, lot, rng, dir, ftype, raided)
		if gate != Vector2.ZERO:
			_fence_dir = dir
			return gate
	return Vector2.ZERO


func _fence_edge(objects: Node, lvl: Node, lot: Dictionary, rng: RandomNumberGenerator, dir: int, ftype: String, raided: bool) -> Vector2:
	var rect: Rect2 = lot["rect"]
	var spec: Dictionary = FENCES[ftype]
	var sheet: String = spec["sheet"]
	var fk: float = spec["k"]
	# Крайняя клетка каждого столбца со стороны dir и улица за ней
	var bottom := {}
	for c in lot["cells"]:
		var cc: Vector2i = c
		if not bottom.has(cc.x) or (cc.y - bottom[cc.x]) * dir > 0:
			bottom[cc.x] = cc.y
	var road := 0
	for x in bottom:
		var y: int = bottom[x]
		if _g(Vector2i(x, y + dir)) == 1 or _g(Vector2i(x, y + dir * 2)) == 1:
			road += 1
	if float(road) / bottom.size() < FENCE_ROAD:
		return Vector2.ZERO
	var cx := rect.get_center().x + rng.randf_range(-20, 20)
	var full := _wsize(sheet, spec["long"]).x * fk
	var n := 0
	var line_y := -INF
	for seg in [[rect.position.x + 6.0, cx - GATE_W * 0.5], [cx + GATE_W * 0.5, rect.end.x - 6.0]]:
		var x: float = seg[0]
		var x1: float = seg[1]
		while x1 - x >= full * 0.45:
			var psheet := sheet
			var key: String = spec["long"]
			var k := fk
			if x1 - x < full:
				# Хвост: короткий кусок или целый в меньшем масштабе
				if spec["short"] != "":
					key = spec["short"]
				else:
					k = fk * (x1 - x) / full
			elif raided and rng.randf() < 0.35:
				psheet = "y5"
				key = RAIDED_FENCE[rng.randi() % RAIDED_FENCE.size()]
				k = full / _wsize("y5", key).x
			elif rng.randf() < (FENCE_BROKEN * 2.0 if raided else FENCE_BROKEN):
				key = spec["broken"]
			var w := _wsize(psheet, key).x * k
			var mid := x + w * 0.5
			# Основание — у крайней клетки двора под этим куском
			var by := -INF
			for kk in range(_cell_of(Vector2(x, 0)).x, _cell_of(Vector2(x + w, 0)).x + 1):
				if bottom.has(kk):
					var cy := _center(Vector2i(kk, bottom[kk])).y
					by = maxf(by, cy) if dir > 0 or by == -INF else minf(by, cy)
			if by == -INF:
				x += w
				continue
			var base := Vector2(mid, by + CELL * 0.5 - 3.0)
			var fp := Rect2(x + 2.0, base.y - 8.0, w - 4.0, 8.0)
			if _fence_ok(fp):
				var flat := key.begins_with("r_")
				_sprite(objects, lvl, psheet, key, base, rng.randf() < 0.5,
						Vector2.ZERO if flat else Vector2(w * 0.92, 6.0), k)
				_use(fp.grow(10.0))
				line_y = base.y
				n += 1
			x += w - 2.0
	if n == 0:
		return Vector2.ZERO
	# Калитка штакетника: открытая створка у левого столба, столб справа
	if spec["gate"] == "picket" and line_y != -INF:
		_sprite(objects, lvl, "y5", "f_gate_picket", Vector2(cx - GATE_W * 0.5 + 12.0, line_y + 1.0), false, Vector2(10, 6), fk)
		_sprite(objects, lvl, "y5", "f_gate_post", Vector2(cx + GATE_W * 0.5 - 4.0, line_y + 1.0), false, Vector2(8, 6), fk)
	return Vector2(cx, rect.end.y if dir > 0 else rect.position.y + CELL)


## Под забором — двор (не улица, не дом, не коллизия)
func _fence_ok(fp: Rect2) -> bool:
	var a := _cell_of(fp.position)
	var b := _cell_of(fp.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var v := _g(Vector2i(x, y))
			if v != 0 and v != 1:
				return false
			if _used.has(Vector2i(x, y)):
				return false
	# Не на самой улице: центр основания — на дворе
	return _g(_cell_of(Vector2(fp.get_center().x, fp.position.y))) == 0


## Спрайт основанием в base; body — коллизия у основания (px мира, полный
## размер), k — масштаб к размеру листа
func _sprite(objects: Node, lvl: Node, sheet: String, key: String, base: Vector2, flip: bool, body: Vector2, k := 1.0) -> Sprite2D:
	var r := _art(sheet, key)
	var s := Sprite2D.new()
	s.name = "Yard_%s_%d_%d" % [key.get_slice("@", 0), int(base.x), int(base.y)]
	s.texture = _sheets[sheet][0]
	s.region_enabled = true
	s.region_rect = r
	s.centered = false
	s.scale = Vector2.ONE * k / _ts(sheet)
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y + 4.0)
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = base
	s.set_meta(META, key)
	if sheet == "hd":
		s.set_meta("hd_prop", key)
	objects.add_child(s)
	s.owner = lvl
	if body != Vector2.ZERO:
		var b := StaticBody2D.new()
		b.name = "Body"
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = body / s.scale
		cs.shape = sh
		cs.position = Vector2(0, -body.y * 0.5) / s.scale
		s.add_child(b)
		b.owner = lvl
		b.add_child(cs)
		cs.owner = lvl
	return s


# ───────────────────────── земля ─────────────────────────

## Утоптанная земля: пятна у вещей и тропинка от калитки вглубь двора, край
## рваный по шуму; рисуется по оригинальной маске троп (PATHS_PRE)
func _ground() -> void:
	if not ResourceLoader.exists(PATHS_PRE):
		var orig := (load(PATHS) as Texture2D).get_image()
		ResourceSaver.save(ImageTexture.create_from_image(orig), PATHS_PRE, ResourceSaver.FLAG_COMPRESS)
	var img := _paths.duplicate() as Image
	var noise := FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = 1.0 / 26.0
	var painted := 0
	for p in _patches:
		painted += _paint_ellipse(img, p[0], p[1], 0.55, noise)
	for t in _trails:
		var a: Vector2 = t[0]
		var b: Vector2 = t[1]
		var steps := int(a.distance_to(b) / 8.0) + 1
		for i in steps + 1:
			var q := a.lerp(b, float(i) / steps)
			painted += _paint_ellipse(img, q, Vector2(15, 11), 0.7, noise)
	var err := ResourceSaver.save(ImageTexture.create_from_image(img), PATHS, ResourceSaver.FLAG_COMPRESS)
	report.append("земля: текселей %d, пятен %d, тропинок %d (%s)" % [painted, _patches.size(), _trails.size(), error_string(err)])


func _paint_ellipse(img: Image, c: Vector2, r: Vector2, strength: float, noise: FastNoiseLite) -> int:
	var n := 0
	var x0 := int((c.x - r.x - 8.0 - WORLD.position.x) / MASK_PX)
	var x1 := int((c.x + r.x + 8.0 - WORLD.position.x) / MASK_PX)
	var y0 := int((c.y - r.y - 8.0 - WORLD.position.y) / MASK_PX)
	var y1 := int((c.y + r.y + 8.0 - WORLD.position.y) / MASK_PX)
	for ty in range(maxi(y0, 0), mini(y1, img.get_height() - 1) + 1):
		for tx in range(maxi(x0, 0), mini(x1, img.get_width() - 1) + 1):
			var p := WORLD.position + Vector2(tx + 0.5, ty + 0.5) * MASK_PX
			var q := (p - c) / r
			var d := q.length() + noise.get_noise_2d(p.x, p.y) * 0.45
			var v := (1.0 - smoothstep(0.55, 1.0, d)) * strength
			if v <= 0.0:
				continue
			var col := img.get_pixel(tx, ty)
			if v > col.r:
				col.r = v
				img.set_pixel(tx, ty, col)
				n += 1
	return n


## Связные области дворов, порезанные на участки по LOT_W
func _lots() -> Array:
	var seen := PackedByteArray()
	seen.resize(_gw * _gh)
	var lots := []
	for y in _gh:
		for x in _gw:
			var i := y * _gw + x
			if _grid[i] != 0 or seen[i] != 0:
				continue
			var cells: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[i] = 1
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				cells.append(c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < 0 or n.y < 0 or n.x >= _gw or n.y >= _gh:
						continue
					var j := n.y * _gw + n.x
					if _grid[j] == 0 and seen[j] == 0:
						seen[j] = 1
						stack.append(n)
			# Нарезка по x
			var parts := {}
			for c in cells:
				var k := int(floor(_center(c).x / LOT_W))
				if not parts.has(k):
					parts[k] = []
				parts[k].append(c)
			for k in parts:
				var pc: Array = parts[k]
				if pc.size() < MIN_CELLS:
					continue
				var bb := Rect2(_center(pc[0]), Vector2.ZERO)
				for c in pc:
					bb = bb.expand(_center(c))
				lots.append({"cells": pc, "rect": bb.grow(CELL * 0.5)})
	return lots


func _debug_image(lots: Array) -> void:
	var img := Image.create(_gw, _gh, false, Image.FORMAT_RGB8)
	var cols := [Color(0.15, 0.3, 0.12), Color(0.5, 0.5, 0.5), Color(0.1, 0.1, 0.12), Color(0.55, 0.1, 0.1), Color(0, 0, 0)]
	for y in _gh:
		for x in _gw:
			img.set_pixel(x, y, cols[_grid[y * _gw + x]])
	var li := 0
	for lot in lots:
		var hue := fmod(li * 0.137, 1.0)
		for c in lot["cells"]:
			img.set_pixelv(c, Color.from_hsv(hue, 0.6, 0.95))
		li += 1
	img.resize(_gw * 3, _gh * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(OS.get_user_data_dir() + "/yards.png")
	report.append("картинка: " + OS.get_user_data_dir() + "/yards.png")
