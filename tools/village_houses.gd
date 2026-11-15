extends SceneTree
## Новая деревня на reference_map: присланные HD-дома вместо старых пиксельных.
##
## Шаги (по порядку, можно по одному):
##   atlas  — дома из reference_map_level/textures/src/hd/houses/*.png (обрезка
##            по альфе, масштаб под мир x2) в один атлас village_houses_hd.png +
##            village_houses_hd.json (не путать с village_houses.png — старые
##            тайлы деревни). После шага: godot --headless --path . --import
##   layout — раскладка: каждый дом ищет место около своей «точки замысла»
##            (важные здания у площади, кузницы у главной улицы, амбары и
##            конюшни на окраинах у полей), с разбросом, без рядов. Проверки:
##            не на дорогах, не друг на друге, перед дверью свободно, не на
##            спавне/костре/врагах/воде/крупной коллизии. От дверей — тропинки
##            (поиск пути по сетке вокруг домов к ближайшей дороге или тропе).
##            Пишет reference_map_level/village_layout.json и план village_plan.png
##            (в TERRAIN_PREVIEW, если задан).
##   apply  — правит сцену: убирает старые дома (спрайты, коллизию, тени), лишние
##            мощёные улицы сетки (главная улица, площадь, выезды и причал
##            остаются), всё, что стоит под новыми домами (деревья, пропсы,
##            декали, факелы и их коллизию); ставит новые дома, их коллизию и
##            контактные тени.
##
## Тропинки и дворы рисует маска троп: после apply —
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res
##   godot --headless --path . -s res://tools/forest_paths.gd -- paths clear
##   (навмеш ещё раз), build_terrain.gd -- wear, cull_hidden_ground.gd (см. его шапку)

const MAP := "res://reference_map_level/reference_map.tscn"
const SRC := "res://reference_map_level/textures/src/hd/houses/"
const ATLAS := "res://reference_map_level/textures/village_houses_hd.png"
const META := "res://reference_map_level/textures/village_houses_hd.json"
const LAYOUT := "res://reference_map_level/village_layout.json"

## Текстура в 2 раза плотнее мира (камера в игре x2.2)
const TEX_SCALE := 2.0
const ATLAS_W := 4096

## Вид дома: ширина в мире, доля ширины под коллизией, глубина коллизии
## (доля высоты картинки), мусор под стеной (доля высоты), дверь (доля ширины)
const KINDS := {
	"tavern":        {"w": 340, "foot": 0.84, "depth": 0.36, "debris": 0.07, "door": 0.47},
	"chapel":        {"w": 290, "foot": 0.80, "depth": 0.36, "debris": 0.08, "door": 0.50},
	"hall":          {"w": 360, "foot": 0.84, "depth": 0.36, "debris": 0.08, "door": 0.50},
	"merchant":      {"w": 300, "foot": 0.86, "depth": 0.36, "debris": 0.08, "door": 0.47},
	"forge_a":       {"w": 300, "foot": 0.84, "depth": 0.34, "debris": 0.08, "door": 0.42},
	"forge_b":       {"w": 300, "foot": 0.84, "depth": 0.34, "debris": 0.08, "door": 0.42},
	"forge_c":       {"w": 300, "foot": 0.84, "depth": 0.34, "debris": 0.08, "door": 0.38},
	"forge_d":       {"w": 300, "foot": 0.84, "depth": 0.34, "debris": 0.08, "door": 0.47},
	"workshop":      {"w": 290, "foot": 0.84, "depth": 0.34, "debris": 0.08, "door": 0.30},
	"stabbur":       {"w": 175, "foot": 0.62, "depth": 0.28, "debris": 0.12, "door": 0.50},
	"hut_stone":     {"w": 270, "foot": 0.86, "depth": 0.36, "debris": 0.07, "door": 0.50},
	"stable":        {"w": 300, "foot": 0.86, "depth": 0.36, "debris": 0.08, "door": 0.50},
	"longhouse":     {"w": 380, "foot": 0.88, "depth": 0.40, "debris": 0.06, "door": 0.50},
	"hut_burnt":     {"w": 250, "foot": 0.76, "depth": 0.32, "debris": 0.07, "door": 0.50},
	"tower":         {"w": 215, "foot": 0.80, "depth": 0.28, "debris": 0.10, "door": 0.50},
	"barn":          {"w": 300, "foot": 0.86, "depth": 0.36, "debris": 0.08, "door": 0.50},
	"house_balcony": {"w": 240, "foot": 0.84, "depth": 0.30, "debris": 0.07, "door": 0.43},
	"house_tall":    {"w": 205, "foot": 0.84, "depth": 0.28, "debris": 0.06, "door": 0.38},
}

## Замысел: [вид, отражение, точка (низ стены), радиус поиска]
## Площадь и главная улица — таверна, часовня, зал, торговцы, кузницы.
## Задние дворы к северу — жилые дома вперемешку. Запад и юг — хозяйство у
## полей (амбары, конюшни, амбары на сваях, длинные дома), горелые хижины по краям.
## Башня — у западного въезда.
const PLAN := [
	# Площадь и главная улица (двери к улице, отступ от неё разный)
	["tavern", false, Vector2(-110, 880), 60],
	["chapel", false, Vector2(-660, 875), 70],
	["merchant", false, Vector2(300, 865), 70],
	["hall", false, Vector2(-860, 1335), 90],
	["tower", false, Vector2(-2160, 965), 70],
	["hut_stone", false, Vector2(-1880, 950), 80],
	["forge_a", false, Vector2(-1560, 975), 70],
	["house_tall", false, Vector2(-1300, 915), 80],
	["workshop", true, Vector2(-1020, 975), 80],
	# Задворки к северу: жилые дома вразнобой, между ними огороды и пустыри
	["hut_burnt", true, Vector2(-2000, 470), 110],
	["stabbur", false, Vector2(-1680, 330), 110],
	["hut_stone", true, Vector2(-1760, 720), 110],
	["house_balcony", true, Vector2(-1420, 600), 110],
	["longhouse", false, Vector2(-1150, 330), 110],
	["forge_c", false, Vector2(-1000, 690), 110],
	["hut_burnt", false, Vector2(-760, 520), 110],
	["house_tall", true, Vector2(-560, 700), 90],
	["barn", false, Vector2(-650, 280), 110],
	["forge_d", false, Vector2(-60, 620), 110],
	["stable", true, Vector2(120, 300), 110],
	["house_tall", false, Vector2(330, 640), 100],
	["stabbur", true, Vector2(430, 380), 100],
	# К югу от улицы и у полей
	["hut_stone", false, Vector2(-2060, 1320), 100],
	["forge_b", true, Vector2(-1460, 1290), 100],
	["house_balcony", false, Vector2(-1160, 1430), 110],
	["merchant", true, Vector2(130, 1420), 110],
	["barn", true, Vector2(-2000, 1700), 120],
	["stable", false, Vector2(-1650, 1660), 120],
	["longhouse", true, Vector2(-1250, 1700), 120],
	["hut_burnt", false, Vector2(-700, 1690), 120],
	["house_balcony", false, Vector2(-20, 1660), 120],
	["hut_stone", true, Vector2(360, 1640), 110],
]

## Где можно ставить дома (подножие целиком внутри)
const VILLAGE := Rect2(-2260, 160, 2830, 1640)
## Мощёные улицы, которые остаются (остальная мостовая в деревне стирается):
## главная улица, площадь, выезды на север и юг, причал
const KEEP_STONE := [
	Rect2(-2460, 1000, 3040, 132),
	Rect2(-600, 900, 1020, 400),
	Rect2(-400, 60, 180, 860),
	Rect2(-360, 1280, 160, 760),
	Rect2(560, 870, 700, 860),
]
## Где мостовая стирается (вне этого — не трогаем: форт, юг и т.п.)
const STONE_CLEAR := Rect2(-2460, 40, 3020, 1960)
## Не ставить ближе (спавн, костёр, маркеры, враги)
const KEEP_FREE := [
	[Vector2(-256, 1248), 130.0], [Vector2(-169, 1298), 130.0], [Vector2(-288, 1224), 120.0],
	[Vector2(800, 1088), 120.0],
]
const ENEMY_FREE := 80.0

const GRID := 16.0

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["atlas"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print(r)
	quit()


# ───────────────────────── атлас ─────────────────────────

func _step_atlas() -> void:
	var items := []
	for kind in KINDS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + kind + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		var bb := _alpha_bbox(img, 0.04)
		img = img.get_region(bb)
		var tw := int(round(KINDS[kind].w * TEX_SCALE))
		var th := int(round(float(img.get_height()) * tw / img.get_width()))
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		items.append({"kind": kind, "img": img})
	# Полки по высоте
	items.sort_custom(func(a, b): return a.img.get_height() > b.img.get_height())
	var x := 0
	var y := 0
	var shelf := 0
	var pad := 4
	var placed := {}
	for it in items:
		var im: Image = it.img
		if x + im.get_width() > ATLAS_W:
			x = 0
			y += shelf + pad
			shelf = 0
		placed[it.kind] = Rect2i(x, y, im.get_width(), im.get_height())
		x += im.get_width() + pad
		shelf = maxi(shelf, im.get_height())
	var h := y + shelf
	var ah := 1
	while ah < h:
		ah *= 2
	var atlas := Image.create(ATLAS_W, ah, false, Image.FORMAT_RGBA8)
	for it in items:
		var r: Rect2i = placed[it.kind]
		atlas.blit_rect(it.img, Rect2i(Vector2i.ZERO, r.size), r.position)
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	var meta := {}
	for kind in placed:
		var r: Rect2i = placed[kind]
		meta[kind] = {"rect": [r.position.x, r.position.y, r.size.x, r.size.y]}
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	# Импорт как у атласа леса: BPTC, без мипмапов
	var imp := FileAccess.open(ProjectSettings.globalize_path(ATLAS) + ".import", FileAccess.WRITE)
	imp.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\n"
		+ "compress/mode=2\ncompress/high_quality=true\ncompress/lossy_quality=0.7\n"
		+ "compress/uastc_level=0\ncompress/rdo_quality_loss=0.0\ncompress/hdr_compression=1\n"
		+ "compress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=false\nmipmaps/limit=-1\n"
		+ "roughness/mode=0\nroughness/src_normal=\"\"\nprocess/channel_remap/red=0\n"
		+ "process/channel_remap/green=1\nprocess/channel_remap/blue=2\nprocess/channel_remap/alpha=3\n"
		+ "process/fix_alpha_border=true\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\n"
		+ "process/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\n"
		+ "detect_3d/compress_to=1\n")
	imp.close()
	report.append("atlas: %d домов, %dx%d (%s)" % [placed.size(), ATLAS_W, ah, error_string(err)])


func _alpha_bbox(img: Image, thr: float) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > thr:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	x0 = maxi(x0 - 2, 0)
	y0 = maxi(y0 - 2, 0)
	x1 = mini(x1 + 2, w - 1)
	y1 = mini(y1 + 2, h - 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


# ───────────────────────── геометрия дома ─────────────────────────

func _meta() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(META))


## Размер дома в мире по атласу
func _world_size(meta: Dictionary, kind: String) -> Vector2:
	var r: Array = meta[kind].rect
	return Vector2(r[2], r[3]) / TEX_SCALE


## base — низ стены (точка сортировки). Подножие (коллизия) — над ним.
func _footprint(meta: Dictionary, kind: String, base: Vector2) -> Rect2:
	var sz := _world_size(meta, kind)
	var k: Dictionary = KINDS[kind]
	var fw: float = sz.x * k.foot
	var fd: float = sz.y * k.depth
	return Rect2(base.x - fw * 0.5, base.y - fd, fw, fd)


## Весь спрайт в мире
func _sprite_rect(meta: Dictionary, kind: String, base: Vector2) -> Rect2:
	var sz := _world_size(meta, kind)
	var debris: float = sz.y * KINDS[kind].debris
	return Rect2(base.x - sz.x * 0.5, base.y + debris - sz.y, sz.x, sz.y)


func _door(meta: Dictionary, kind: String, base: Vector2, flip: bool) -> Vector2:
	var sz := _world_size(meta, kind)
	var d: float = KINDS[kind].door
	if flip:
		d = 1.0 - d
	return Vector2(base.x - sz.x * 0.5 + sz.x * d, base.y + 6)


# ───────────────────────── раскладка ─────────────────────────

func _step_layout() -> void:
	var meta := _meta()
	var lvl := (load(MAP) as PackedScene).instantiate()
	# Препятствия: вода, крупная не-домовая коллизия, городские тайлы
	var blocked: Array[Rect2] = []
	var old_houses := _old_house_rects(lvl)
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	for i in shapes.size():
		var s: Shape2D = shapes[i]
		if not (s is RectangleShape2D):
			continue
		var o: Vector2 = (xf[i] as Transform2D).origin
		var sz: Vector2 = (s as RectangleShape2D).size
		if maxf(sz.x, sz.y) < 130.0 or _in_any(o, old_houses):
			continue
		blocked.append(Rect2(o - sz * 0.5, sz))
	for ch in col.get_children():
		if ch is CollisionPolygon2D:
			var poly: PackedVector2Array = (ch as CollisionPolygon2D).polygon
			var r := Rect2(poly[0], Vector2.ZERO)
			for p in poly:
				r = r.expand(p)
			blocked.append(r)
	var town := lvl.get_node("Town") as TileMapLayer
	for c in town.get_used_cells():
		blocked.append(Rect2(town.to_global(town.map_to_local(c)) - Vector2(8, 8), Vector2(16, 16)))
	var free_pts := KEEP_FREE.duplicate()
	for e in lvl.find_children("Enemy_Town*", "CharacterBody2D", true, false):
		free_pts.append([(e as Node2D).position, ENEMY_FREE])
	lvl.free()

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := []
	for spec in PLAN:
		var kind: String = spec[0]
		var flip: bool = spec[1]
		var want: Vector2 = spec[2]
		var rad: float = spec[3]
		var gap := rng.randf_range(34.0, 78.0)
		var best := Vector2.INF
		var best_score := INF
		for t in 900:
			var cand := want
			if t > 0:
				var a := rng.randf() * TAU
				var d := sqrt(rng.randf()) * rad * (1.0 + t / 300.0)
				cand = want + Vector2(cos(a), sin(a) * 0.8) * d
			cand = cand.round()
			var fp := _footprint(meta, kind, cand)
			if not _fits(meta, kind, flip, cand, fp, gap, placed, blocked, free_pts):
				continue
			var score := cand.distance_to(want) + rng.randf() * 25.0
			if score < best_score:
				best_score = score
				best = cand
			if t > 80 and best != Vector2.INF:
				break
		if best == Vector2.INF:
			report.append("  НЕ встал: %s у %s" % [kind, want])
			continue
		placed.append({"kind": kind, "flip": flip, "base": best,
			"foot": _footprint(meta, kind, best), "door": _door(meta, kind, best, flip), "gap": gap})

	var lanes := _lanes(meta, placed, blocked)
	var out := {"houses": [], "lanes": [], "yards": []}
	for h in placed:
		out.houses.append({"kind": h.kind, "flip": h.flip, "x": h.base.x, "y": h.base.y})
		var d: Vector2 = h.door
		out.yards.append([d.x, d.y + 14.0, 30.0 + rng.randf() * 14.0])
	for ln in lanes:
		var arr := []
		for p in ln:
			arr.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
		out.lanes.append(arr)
	var f := FileAccess.open(LAYOUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	_plan_png(meta, placed, lanes)
	report.append("layout: %d домов из %d, %d тропинок" % [placed.size(), PLAN.size(), lanes.size()])


func _in_any(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


func _fits(meta: Dictionary, kind: String, flip: bool, base: Vector2, fp: Rect2, gap: float,
		placed: Array, blocked: Array, free_pts: Array) -> bool:
	if not VILLAGE.encloses(fp):
		return false
	var spr := _sprite_rect(meta, kind, base)
	var door := _door(meta, kind, base, flip)
	# Перед дверью свободно (дворик)
	var porch := Rect2(door.x - 30, door.y - 4, 60, 70)
	for r in KEEP_STONE:
		if (r as Rect2).intersects(fp.grow(18)):
			return false
	for r in blocked:
		if (r as Rect2).intersects(fp.grow(12)):
			return false
	for fpt in free_pts:
		var c: Vector2 = fpt[0]
		var rr: float = fpt[1]
		if _rect_dist(fp, c) < rr or _rect_dist(porch, c) < rr * 0.5:
			return false
	for h in placed:
		var g: float = maxf(gap, h.gap)
		var other: Rect2 = h.foot
		if other.grow(g).intersects(fp):
			return false
		# Дверь соседа не загораживать, и свою тоже
		var odoor: Vector2 = h.door
		var oporch := Rect2(odoor.x - 30, odoor.y - 4, 60, 70)
		if oporch.intersects(fp) or porch.intersects(other):
			return false
		# Крыша не должна наезжать на стену соседа спереди слишком сильно
		var ospr := _sprite_rect(meta, h.kind, h.base)
		if spr.intersects(other.grow(6)) and base.y < (h.base as Vector2).y:
			return false
		if ospr.intersects(fp.grow(6)) and (h.base as Vector2).y < base.y:
			return false
	return true


func _rect_dist(r: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


func _old_house_rects(lvl: Node) -> Array:
	var out := []
	for n in lvl.find_children("House*", "Sprite2D", true, false):
		var s := n as Sprite2D
		if s.has_meta("village_v2"):
			continue
		var r := Rect2(s.position + (s.offset - s.region_rect.size * 0.5) * s.scale, s.region_rect.size * s.scale)
		out.append(Rect2(r.position.x - 6, r.position.y + r.size.y * 0.38, r.size.x + 12, r.size.y * 0.62 + 8))
	return out


## Тропинки: от каждой двери к ближайшей дороге или уже проложенной тропе
func _lanes(meta: Dictionary, placed: Array, blocked: Array) -> Array:
	var reg := Rect2i(Vector2i((STONE_CLEAR.position / GRID).floor()), Vector2i((STONE_CLEAR.size / GRID).ceil()))
	var astar := AStarGrid2D.new()
	astar.region = reg
	astar.cell_size = Vector2(GRID, GRID)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 1.0 / 140.0
	var targets := {}
	for x in range(reg.position.x, reg.end.x):
		for y in range(reg.position.y, reg.end.y):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) * GRID
			var c := Vector2i(x, y)
			# Лёгкая неровность — тропы не идут по линейке
			astar.set_point_weight_scale(c, 1.0 + (noise.get_noise_2d(p.x, p.y) + 1.0) * 0.6)
			var solid := false
			for h in placed:
				if (h.foot as Rect2).grow(10).has_point(p):
					solid = true
					break
			if not solid:
				for r in blocked:
					if (r as Rect2).has_point(p):
						solid = true
						break
			if solid:
				astar.set_point_solid(c, true)
			elif _in_any(p, KEEP_STONE):
				targets[c] = true
	# Ближние к дороге — первыми, дальние вливаются в их тропы
	var order := placed.duplicate()
	order.sort_custom(func(a, b): return _nearest_dist(a.door, targets) < _nearest_dist(b.door, targets))
	var lanes := []
	for h in order:
		var start := Vector2i(((h.door as Vector2) + Vector2(0, 12)) / GRID)
		if not astar.is_in_boundsv(start) or astar.is_point_solid(start):
			continue
		var goal := _nearest_cell(Vector2(start) * GRID, targets)
		if goal == Vector2i(-99999, -99999):
			continue
		var path := astar.get_id_path(start, goal)
		if path.size() < 2:
			continue
		var pts := PackedVector2Array()
		pts.append(h.door)
		for c in path:
			pts.append((Vector2(c) + Vector2(0.5, 0.5)) * GRID)
		pts = _chaikin(_simplify(pts, 3), 3)
		lanes.append(pts)
		# Тропа теперь тоже цель и дешевле — следующие вливаются в неё
		for c in path:
			targets[c] = true
			astar.set_point_weight_scale(c, 0.35)
	return lanes


func _nearest_dist(p: Vector2, targets: Dictionary) -> float:
	var c := _nearest_cell(p, targets)
	return (Vector2(c) * GRID).distance_to(p)


func _nearest_cell(p: Vector2, targets: Dictionary) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	var bd := INF
	for c in targets:
		var d := ((Vector2(c) + Vector2(0.5, 0.5)) * GRID).distance_squared_to(p)
		if d < bd:
			bd = d
			best = c
	return best


func _simplify(pts: PackedVector2Array, keep_every: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		if i == 0 or i == pts.size() - 1 or i % keep_every == 0:
			out.append(pts[i])
	return out


func _chaikin(pts: PackedVector2Array, it: int) -> PackedVector2Array:
	for k in it:
		if pts.size() < 3:
			return pts
		var out := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


func _plan_png(meta: Dictionary, placed: Array, lanes: Array) -> void:
	var dir := OS.get_environment("TERRAIN_PREVIEW")
	if dir == "":
		return
	var k := 4.0
	var a := STONE_CLEAR
	var im := Image.create(int(a.size.x / k), int(a.size.y / k), false, Image.FORMAT_RGBA8)
	im.fill(Color(0.18, 0.22, 0.14))
	var lvl := (load(MAP) as PackedScene).instantiate()
	var stone := lvl.get_node("Stone") as TileMapLayer
	for c in stone.get_used_cells():
		var p := stone.to_global(stone.map_to_local(c))
		if _keep_stone(p) or not STONE_CLEAR.has_point(p):
			var q := (p - a.position) / k
			im.fill_rect(Rect2i(int(q.x) - 2, int(q.y) - 2, 4, 4), Color(0.55, 0.55, 0.55))
	for e in lvl.find_children("Enemy_Town*", "CharacterBody2D", true, false):
		var q := ((e as Node2D).position - a.position) / k
		im.fill_rect(Rect2i(int(q.x) - 4, int(q.y) - 4, 8, 8), Color(1, 0, 0))
	lvl.free()
	for ln in lanes:
		for p in ln:
			var q: Vector2 = (p - a.position) / k
			im.fill_rect(Rect2i(int(q.x) - 2, int(q.y) - 2, 4, 4), Color(0.55, 0.4, 0.25))
	for h in placed:
		var sr := _sprite_rect(meta, h.kind, h.base)
		var q := Rect2((sr.position - a.position) / k, sr.size / k)
		im.fill_rect(Rect2i(q), Color(0.35, 0.2, 0.15))
		var fq := Rect2(((h.foot as Rect2).position - a.position) / k, (h.foot as Rect2).size / k)
		im.fill_rect(Rect2i(fq), Color(0.75, 0.25, 0.15))
		var dq := ((h.door as Vector2) - a.position) / k
		im.fill_rect(Rect2i(int(dq.x) - 2, int(dq.y) - 2, 5, 5), Color(1, 1, 0))
	for fpt in KEEP_FREE:
		var q := ((fpt[0] as Vector2) - a.position) / k
		im.fill_rect(Rect2i(int(q.x) - 4, int(q.y) - 4, 8, 8), Color(0, 1, 1))
	im.save_png(dir + "/village_plan.png")


## Остаётся ли мостовая в этой точке: зоны KEEP_STONE с рваным краем
func _keep_stone(p: Vector2) -> bool:
	var jag := (hash(Vector2i(p / 16.0)) % 1000) / 1000.0
	for r in KEEP_STONE:
		if (r as Rect2).grow(-8.0 + jag * 22.0).has_point(p):
			return true
	return false


# ───────────────────────── правка сцены ─────────────────────────

func _step_apply() -> void:
	var meta := _meta()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var lvl := (load(MAP) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	if lvl.get_node("Ground").get("material") == null:
		report.append("apply: материал земли не загрузился — сначала godot --headless --path . --import")
		lvl.free()
		return
	var objects := lvl.get_node("Objects")
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	var shadows := lvl.get_node("ContactShadows")
	var sdata: PackedFloat32Array = shadows.get("data")

	# 1. Старые дома: спрайты, коллизия, тени
	var old := _old_house_rects(lvl)
	var removed_old := 0
	for n in lvl.find_children("House*", "Sprite2D", true, false):
		if not (n as Node).has_meta("village_v2"):
			n.get_parent().remove_child(n)
			n.free()
			removed_old += 1
	var keep_s: Array[Shape2D] = []
	var keep_x: Array[Transform2D] = []
	var old_shapes := 0
	for i in shapes.size():
		var s: Shape2D = shapes[i]
		var o: Vector2 = (xf[i] as Transform2D).origin
		if s is RectangleShape2D and maxf((s as RectangleShape2D).size.x, (s as RectangleShape2D).size.y) >= 50.0 and _in_any(o, old):
			old_shapes += 1
			continue
		keep_s.append(s)
		keep_x.append(xf[i])
	var nd := PackedFloat32Array()
	var old_sh := 0
	for i in range(0, sdata.size(), 5):
		var c := Vector2(sdata[i], sdata[i + 1])
		if sdata[i + 2] >= 50.0 and _in_any(c, old):
			old_sh += 1
			continue
		for j in 5:
			nd.append(sdata[i + j])

	# 2. Новые дома
	var tex := load(ATLAS) as Texture2D
	var feet: Array[Rect2] = []
	var clear_zones: Array[Rect2] = []
	var n := 0
	for h in layout.houses:
		var kind: String = h.kind
		var base := Vector2(h.x, h.y)
		var r: Array = meta[kind].rect
		var size := Vector2(r[2], r[3])
		var wsz := size / TEX_SCALE
		var debris: float = wsz.y * KINDS[kind].debris
		var spr := Sprite2D.new()
		spr.name = "House%d" % n
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = Rect2(r[0], r[1], r[2], r[3])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.scale = Vector2.ONE / TEX_SCALE
		spr.flip_h = h.flip
		spr.position = base
		spr.offset = Vector2(0, -size.y * 0.5 + debris * TEX_SCALE)
		spr.set_meta("house", true)
		spr.set_meta("village_v2", kind)
		objects.add_child(spr)
		spr.owner = lvl
		var fp := _footprint(meta, kind, base)
		feet.append(fp)
		var rs := RectangleShape2D.new()
		rs.size = fp.size
		keep_s.append(rs)
		keep_x.append(Transform2D(0.0, fp.get_center()))
		# Мягкая тень вдоль низа дома
		nd.append_array(PackedFloat32Array([base.x, base.y - fp.size.y * 0.35, fp.size.x * 0.62, fp.size.y * 0.75, 0.45]))
		# Всё, что стоит на стенах: от трети высоты картинки до порога
		var sr := _sprite_rect(meta, kind, base)
		clear_zones.append(Rect2(sr.position.x + 4, sr.position.y + sr.size.y * 0.33, sr.size.x - 8, sr.size.y * 0.67 + 10))
		n += 1

	# 3. Что оказалось под домами: тайлы объектов и декали, мелкая коллизия, факелы
	var erased := 0
	for layer_path in ["Objects/Trees", "Objects/Decor", "Objects/Wilds", "Objects/Ruins", "Objects/PurpleForest", "Grime", "SouthMarks"]:
		var tl := lvl.get_node_or_null(layer_path) as TileMapLayer
		if tl == null:
			continue
		for c in tl.get_used_cells():
			var p := tl.to_global(tl.map_to_local(c))
			if _in_any(p, clear_zones):
				tl.erase_cell(c)
				erased += 1
	var fs: Array[Shape2D] = []
	var fx: Array[Transform2D] = []
	var small := 0
	var new_from := keep_s.size() - feet.size()
	for i in keep_s.size():
		var s := keep_s[i]
		var o := keep_x[i].origin
		if i < new_from and s is RectangleShape2D and maxf((s as RectangleShape2D).size.x, (s as RectangleShape2D).size.y) < 130.0 and _in_any(o, clear_zones):
			small += 1
			continue
		fs.append(s)
		fx.append(keep_x[i])
	col.set("shapes", fs)
	col.set("shape_transforms", fx)
	var lights := 0
	for t in lvl.get_node("Night").get_children():
		if t is Node2D and _in_any((t as Node2D).position, clear_zones):
			t.get_parent().remove_child(t)
			t.free()
			lights += 1
	# Тени деревьев/пропсов, что были под домами
	var nd2 := PackedFloat32Array()
	var house_shadow_from := nd.size() - feet.size() * 5
	for i in range(0, nd.size(), 5):
		if i < house_shadow_from and _in_any(Vector2(nd[i], nd[i + 1]), clear_zones):
			continue
		for j in 5:
			nd2.append(nd[i + j])
	shadows.set("data", nd2)

	# 4. Мостовая: остаются главная улица, площадь, выезды и причал
	var stone := lvl.get_node("Stone") as TileMapLayer
	var stone_cut := 0
	for c in stone.get_used_cells():
		var p := stone.to_global(stone.map_to_local(c))
		if STONE_CLEAR.has_point(p) and not _keep_stone(p):
			stone.erase_cell(c)
			stone_cut += 1

	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, MAP)
	lvl.free()
	report.append("apply: старых домов %d (коллизий %d, теней %d); новых %d; под домами убрано тайлов %d, мелкой коллизии %d, огней %d; мостовой стёрто %d клеток (%s)"
		% [removed_old, old_shapes, old_sh, n, erased, small, lights, stone_cut, error_string(err)])
