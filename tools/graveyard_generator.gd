extends SceneTree
## Генератор Levels/level_graveyard.tscn по референсу (ночное кладбище-поместье).
## Запуск: godot --headless --path . -s res://tools/graveyard_generator.gd
## ВНИМАНИЕ: ПЕРЕЗАПИСЫВАЕТ level_graveyard.tscn, Levels/props/torch.tscn и
## campfire.tscn — ручные правки этих сцен в редакторе пропадут. Магазин,
## музыку, спавнеры и цветокоррекцию берёт из level_01.tscn.
## Координаты объектов заданы в пикселях РЕФЕРЕНСА (1768x889) и пересчитываются
## в клетки карты через R() — так раскладка повторяет картинку.

const W := 192
const H := 96
const T := 16
const OUT := "res://Levels/level_graveyard.tscn"
const SX := 192.0 / 1768.0
const SY := 96.0 / 889.0

const ATLASES := {
	"grass": "res://TileMap/TX Tileset Grass.png",
	"stone": "res://TileMap/TX Tileset Stone Ground.png",
	"wall": "res://TileMap/TX Tileset Wall.png",
	"props": "res://TileMap/TX Props.png",
	"plant": "res://TileMap/TX Plant.png",
	"ef": "res://TileMap/EFOutside_B.png",
	"forest": "res://TileMap/Forest Tileset.png",
	"houses": "res://TileMap/houses.png",
	"dd": "res://TileMap/DampDungeons/DungeonDecorations.png",
	"tree_dark": "res://TileMap/Trees/tree2.png",
	"tree_autumn": "res://TileMap/Trees/tree1.png",
}

# Штампы: src, x, y, w, h (клетки атласа), solid: none|base|trunk|all
const ST := {
	"pine": {"src": "forest", "x": 9, "y": 18, "w": 3, "h": 4, "solid": "trunk"},
	"round_tree": {"src": "forest", "x": 20, "y": 18, "w": 3, "h": 4, "solid": "trunk"},
	"big_pine": {"src": "ef", "x": 13, "y": 14, "w": 4, "h": 7, "solid": "trunk"},
	"dead_tree": {"src": "ef", "x": 6, "y": 14, "w": 6, "h": 7, "solid": "trunk"},
	"birch": {"src": "ef", "x": 0, "y": 5, "w": 2, "h": 7, "solid": "trunk"},
	"twisted_tree": {"src": "ef", "x": 0, "y": 12, "w": 6, "h": 9, "solid": "trunk"},
	"oak1": {"src": "plant", "x": 1, "y": 0, "w": 8, "h": 10, "solid": "trunk"},
	"oak2": {"src": "plant", "x": 10, "y": 0, "w": 6, "h": 10, "solid": "trunk"},
	"oak3": {"src": "plant", "x": 18, "y": 1, "w": 6, "h": 9, "solid": "trunk"},
	"bush1": {"src": "plant", "x": 2, "y": 12, "w": 2, "h": 2, "solid": "none"},
	"bush2": {"src": "plant", "x": 6, "y": 12, "w": 2, "h": 2, "solid": "none"},
	"bush3": {"src": "plant", "x": 9, "y": 11, "w": 3, "h": 3, "solid": "base"},
	"bush4": {"src": "plant", "x": 13, "y": 11, "w": 3, "h": 3, "solid": "base"},
	"bush5": {"src": "plant", "x": 21, "y": 11, "w": 3, "h": 3, "solid": "base"},
	"stump": {"src": "ef", "x": 27, "y": 18, "w": 3, "h": 3, "solid": "base"},
	"stump2": {"src": "ef", "x": 27, "y": 15, "w": 3, "h": 3, "solid": "base"},
	"slab": {"src": "props", "x": 14, "y": 1, "w": 2, "h": 3, "solid": "base"},
	"slab_tall": {"src": "props", "x": 14, "y": 5, "w": 2, "h": 5, "solid": "base"},
	"grave_round": {"src": "props", "x": 14, "y": 11, "w": 2, "h": 3, "solid": "base"},
	"grave_rip": {"src": "props", "x": 14, "y": 14, "w": 2, "h": 4, "solid": "base"},
	"grave_cross": {"src": "props", "x": 14, "y": 18, "w": 2, "h": 4, "solid": "base"},
	"grave_small": {"src": "props", "x": 18, "y": 15, "w": 2, "h": 3, "solid": "base"},
	"grave_block": {"src": "props", "x": 18, "y": 19, "w": 2, "h": 3, "solid": "base"},
	"coffin_up": {"src": "props", "x": 18, "y": 9, "w": 2, "h": 5, "solid": "base"},
	"sarcophagus": {"src": "props", "x": 18, "y": 5, "w": 4, "h": 3, "solid": "all"},
	"broken_slab": {"src": "props", "x": 24, "y": 0, "w": 2, "h": 4, "solid": "base"},
	"broken_slab2": {"src": "props", "x": 24, "y": 6, "w": 2, "h": 4, "solid": "base"},
	"statue": {"src": "props", "x": 27, "y": 1, "w": 4, "h": 5, "solid": "base"},
	"pillar": {"src": "props", "x": 22, "y": 10, "w": 2, "h": 6, "solid": "base"},
	"pillar_broken": {"src": "props", "x": 26, "y": 12, "w": 2, "h": 4, "solid": "base"},
	"stone_ring": {"src": "props", "x": 26, "y": 22, "w": 4, "h": 4, "solid": "none"},
	"rock_big": {"src": "props", "x": 0, "y": 26, "w": 4, "h": 4, "solid": "base"},
	"barrel": {"src": "props", "x": 10, "y": 9, "w": 2, "h": 3, "solid": "base"},
	"vase": {"src": "props", "x": 10, "y": 13, "w": 2, "h": 3, "solid": "base"},
	"crate": {"src": "props", "x": 10, "y": 1, "w": 2, "h": 3, "solid": "base"},
	"door": {"src": "props", "x": 2, "y": 6, "w": 2, "h": 4, "solid": "all"},
	"roof_long": {"src": "houses", "x": 4, "y": 1, "w": 12, "h": 7, "solid": "all"},
	"chapel": {"src": "houses", "x": 22, "y": 9, "w": 16, "h": 17, "solid": "all"},
	"runestone": {"src": "ef", "x": 45, "y": 15, "w": 2, "h": 3, "solid": "base"},
	"runestone2": {"src": "ef", "x": 45, "y": 19, "w": 2, "h": 3, "solid": "base"},
	"bones_rock": {"src": "dd", "x": 25, "y": 9, "w": 2, "h": 2, "solid": "none"},
}

# Декали (слой Detail — без коллизии, под всеми объектами)
const DECALS := {
	"tuft": [["plant", 0, 24], ["plant", 2, 24], ["plant", 4, 24], ["plant", 6, 24], ["plant", 0, 26], ["plant", 2, 26], ["plant", 4, 26], ["plant", 6, 26], ["plant", 0, 28], ["plant", 2, 28], ["plant", 4, 28], ["plant", 6, 28], ["plant", 0, 30], ["plant", 2, 30], ["plant", 4, 30]],
	"pebble": [["props", 0, 30], ["props", 2, 30], ["props", 4, 30], ["props", 6, 30], ["props", 8, 30], ["props", 14, 30], ["props", 16, 30], ["props", 18, 30]],
	"skull": [["dd", 16, 9], ["dd", 18, 9]],
	"mushroom": [["dd", 16, 4], ["dd", 18, 4]],
}

const CAMPFIRES := [Vector2(150, 238), Vector2(180, 105), Vector2(355, 188), Vector2(1500, 745), Vector2(1585, 810), Vector2(330, 780)]

var rng := RandomNumberGenerator.new()
# ST + деревья, найденные на листах TileMap/Trees (см. detect_trees)
var STAMPS := {}
var DARK_TREES: Array[String] = []
var PALE_TREES: Array[String] = []
var AUTUMN_TREES: Array[String] = []
var ts: TileSet
var SRC := {}
var IMG := {}
var _pix_cache := {}
var lvl: Node2D
var ground: TileMapLayer
var detail: TileMapLayer
var objs: Array[TileMapLayer] = []
var reserved := {}   # клетки, куда нельзя ставить случайный декор/лес
# То же, но проверяется только в stamp(), ПОСЛЕ трат генератора случайных
# чисел — новые запреты не сдвигают раскладку остальной карты
var blocked := {}
# Окно прозрачности (Shaders/occlusion_fade.gdshaderinc) для отдельных спрайтов:
# срабатывает, только если спрайт перед игроком — основание = позиция узла
var occl_sprite: ShaderMaterial
var walls := {}      # клетки стен (для проверки проходов)
var torch_scene: PackedScene
var campfire_scene: PackedScene
var play_rect := Rect2i(13, 6, W - 26, H - 11)


func R(x: float, y: float) -> Vector2i:
	return Vector2i(roundi(x * SX), roundi(y * SY))


func RX(x: float) -> int:
	return roundi(x * SX)


func RY(y: float) -> int:
	return roundi(y * SY)


func world(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5)


# ============================================================ TILESET

func build_tileset() -> void:
	ts = TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var id := 0
	for name in ATLASES:
		var s := TileSetAtlasSource.new()
		s.texture = load(ATLASES[name])
		s.texture_region_size = Vector2i(T, T)
		ts.add_source(s, id)
		SRC[name] = id
		IMG[name] = Image.load_from_file(ProjectSettings.globalize_path(ATLASES[name]))
		id += 1


## Находит отдельные деревья на листе (они стоят не по ровной сетке):
## связные области непрозрачных пикселей -> рамка в клетках 16px.
## Ствол — колонка нижнего ряда с наибольшим числом пикселей.
func detect_trees(src: String, prefix: String) -> Array[String]:
	var img: Image = IMG[src]
	var B := 4
	var bw := img.get_width() / B
	var bh := img.get_height() / B
	var occ := {}
	for by in bh:
		for bx in bw:
			var hit := false
			for py in B:
				for px in B:
					if img.get_pixel(bx * B + px, by * B + py).a > 0.25:
						hit = true
						break
				if hit:
					break
			if hit:
				occ[Vector2i(bx, by)] = true
	var seen := {}
	var boxes := []
	for start in occ:
		if seen.has(start):
			continue
		var stack := [start]
		seen[start] = true
		var mn: Vector2i = start
		var mx: Vector2i = start
		var count := 0
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			count += 1
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := p + Vector2i(dx, dy)
					if occ.has(q) and not seen.has(q):
						seen[q] = true
						stack.append(q)
		if count >= 40:
			boxes.append(Rect2i(mn * B, (mx - mn + Vector2i.ONE) * B))
	# Порядок как на листе: по рядам (по низу дерева), слева направо
	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var ra := a.end.y / 128
		var rb := b.end.y / 128
		return a.position.x < b.position.x if ra == rb else ra < rb)
	var names: Array[String] = []
	for i in boxes.size():
		var r: Rect2i = boxes[i]
		var x0 := r.position.x / T
		var y0 := r.position.y / T
		var x1 := (r.end.x - 1) / T
		var y1 := (r.end.y - 1) / T
		var best := (x0 + x1) / 2
		var best_n := -1
		for cx in range(x0, x1 + 1):
			var n := 0
			for py in T:
				for px in T:
					if img.get_pixel(cx * T + px, y1 * T + py).a > 0.5:
						n += 1
			if n > best_n:
				best_n = n
				best = cx
		var name := "%s_%d" % [prefix, i]
		STAMPS[name] = {"src": src, "x": x0, "y": y0, "w": x1 - x0 + 1, "h": y1 - y0 + 1, "solid": "trunk", "trunk_col": best - x0}
		names.append(name)
	print("GEN trees ", prefix, ": ", names.size())
	return names


func rand_tree(autumn_chance := 0.15) -> String:
	if rng.randf() < autumn_chance:
		return AUTUMN_TREES[rng.randi() % AUTUMN_TREES.size()]
	return DARK_TREES[rng.randi() % DARK_TREES.size()]


func has_pixels(src: String, c: Vector2i) -> bool:
	var key := "%s:%d:%d" % [src, c.x, c.y]
	if _pix_cache.has(key):
		return _pix_cache[key]
	var img: Image = IMG[src]
	var n := 0
	var ok := false
	if (c.x + 1) * T <= img.get_width() and (c.y + 1) * T <= img.get_height():
		for py in T:
			for px in T:
				if img.get_pixel(c.x * T + px, c.y * T + py).a > 0.2:
					n += 1
					if n >= 6:
						ok = true
						break
			if ok:
				break
	_pix_cache[key] = ok
	return ok


func ensure_tile(src: String, c: Vector2i, solid: Rect2, ysort: int) -> void:
	var s: TileSetAtlasSource = ts.get_source(SRC[src])
	if s.has_tile(c):
		return
	s.create_tile(c)
	var td := s.get_tile_data(c, 0)
	td.y_sort_origin = ysort
	if solid.size != Vector2.ZERO:
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			solid.position, Vector2(solid.end.x, solid.position.y), solid.end, Vector2(solid.position.x, solid.end.y)]))


const RECT_ALL := Rect2(-8, -8, 16, 16)
const RECT_BASE := Rect2(-7, -5, 14, 12)
const RECT_TRUNK := Rect2(-5, -2, 10, 9)


# ============================================================ LAYERS

func make_layer(name: String, z: int, ysort: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = ts
	l.z_index = z
	l.y_sort_enabled = ysort
	lvl.add_child(l)
	l.owner = lvl
	return l


func cell_free(c: Vector2i, li: int) -> bool:
	return objs[li].get_cell_source_id(c) == -1


func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


## Ставит штамп так, что его нижний ряд, центр — в клетке base.
## Возвращает false, если ни в одном слое объектов нет места.
func stamp(name: String, base: Vector2i, check_reserved := false, extra_ysort := 0) -> bool:
	var st: Dictionary = STAMPS[name]
	var w: int = st.w
	var h: int = st.h
	var origin := Vector2i(base.x - w / 2, base.y - (h - 1))
	var cells := []
	for r in h:
		for c in w:
			var ac := Vector2i(st.x + c, st.y + r)
			if not has_pixels(st.src, ac):
				continue
			var mc := origin + Vector2i(c, r)
			if not in_map(mc):
				continue
			if check_reserved and (reserved.has(mc) or blocked.has(mc)):
				return false
			var solid := Rect2()
			match st.solid:
				"all":
					solid = RECT_ALL
				"base":
					if r == h - 1:
						solid = RECT_BASE
				"trunk":
					if r == h - 1 and c == int(st.get("trunk_col", w / 2)):
						solid = RECT_TRUNK
			cells.append([mc, ac, solid, (h - 1 - r) * T + 6 + extra_ysort])
	if cells.is_empty():
		return false
	for li in objs.size():
		var ok := true
		for e in cells:
			if not cell_free(e[0], li):
				ok = false
				break
		if ok:
			for e in cells:
				ensure_tile(st.src, e[1], e[2], e[3])
				objs[li].set_cell(e[0], SRC[st.src], e[1])
			return true
	return false


func decal(kind: String, c: Vector2i) -> void:
	var opts: Array = DECALS[kind]
	var d: Array = opts[rng.randi() % opts.size()]
	# Травинки и камешки — из листа ground_&_props, плоскими спрайтами и не на
	# каждой клетке (трава в текстуре земли и так живая). rng выше всё равно
	# тратится, чтобы не сдвинулась остальная случайная раскладка карты
	if kind == "tuft" or kind == "pebble":
		var tuft := kind == "tuft"
		if not blocked.has(c) and gp_rng.randf() < (0.3 if tuft else 0.5):
			var nm := ("sprout_%d" % gp_rng.randi_range(1, 8)) if tuft else ("pebble_%d" % gp_rng.randi_range(1, 2))
			var pos := Vector2(c.x * T + gp_rng.randf_range(2.0, 14.0), c.y * T + gp_rng.randf_range(2.0, 14.0))
			gp_flat(nm, pos, GP_S * gp_rng.randf_range(0.8, 1.1))
		return
	for r in 2:
		for q in 2:
			var ac := Vector2i(d[1] + q, d[2] + r)
			var mc := c + Vector2i(q, r)
			if in_map(mc) and has_pixels(d[0], ac) and detail.get_cell_source_id(mc) == -1:
				ensure_tile(d[0], ac, Rect2(), 0)
				detail.set_cell(mc, SRC[d[0]], ac)


func reserve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			reserved[Vector2i(x, y)] = true


func reserve_circle(c: Vector2i, rad: float) -> void:
	for y in range(c.y - int(rad) - 1, c.y + int(rad) + 2):
		for x in range(c.x - int(rad) - 1, c.x + int(rad) + 2):
			if Vector2(x - c.x, (y - c.y) * 1.3).length() <= rad:
				reserved[Vector2i(x, y)] = true


# ============================================================ GROUND

func set_ground(c: Vector2i, src: String, ac: Vector2i) -> void:
	if not in_map(c):
		return
	ensure_tile(src, ac, Rect2(), 0)
	ground.set_cell(c, SRC[src], ac)


const COBBLES := [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9), Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(6, 8), Vector2i(7, 8), Vector2i(6, 9), Vector2i(8, 9), Vector2i(9, 9), Vector2i(8, 10), Vector2i(9, 10), Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11)]
const COBBLES_BROKEN := [Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(7, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(10, 10), Vector2i(12, 10), Vector2i(13, 10), Vector2i(14, 10), Vector2i(15, 10), Vector2i(0, 12), Vector2i(1, 12), Vector2i(3, 12), Vector2i(0, 13), Vector2i(2, 13), Vector2i(3, 13), Vector2i(6, 13), Vector2i(7, 13), Vector2i(8, 12), Vector2i(11, 12)]
const SLABS := [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(5, 10), Vector2i(0, 11), Vector2i(1, 11), Vector2i(4, 11), Vector2i(5, 11), Vector2i(0, 14), Vector2i(1, 14), Vector2i(4, 14), Vector2i(5, 14), Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15)]


func paint_grass() -> void:
	for y in H:
		for x in W:
			var ac := Vector2i(rng.randi_range(0, 15), rng.randi_range(0, 7))
			# Камешки/листва на траве — пореже, чтобы не рябило
			if rng.randf() < 0.75:
				ac = Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 7))
			set_ground(Vector2i(x, y), "grass", ac)


func paint_path(points: Array, width: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = Vector2(points[i])
		var b: Vector2 = Vector2(points[i + 1])
		var steps := int(a.distance_to(b) * 2.0) + 1
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			for dy in range(-int(width) - 1, int(width) + 2):
				for dx in range(-int(width) - 1, int(width) + 2):
					var c := Vector2i(roundi(p.x) + dx, roundi(p.y) + dy)
					var d := Vector2(dx, dy).length()
					if d > width + 0.5:
						continue
					reserved[c] = true
					gmask[c] = maxi(int(gmask.get(c, 0)), 1)   # тропа — земля
					# Край тропы — битая плитка вперемешку с травой, центр — целая
					var edge: float = d / maxf(width, 0.01)
					if edge > 0.7 and rng.randf() < 0.45:
						continue
					var pool: Array = COBBLES if edge < 0.6 and rng.randf() < 0.8 else COBBLES_BROKEN
					set_ground(c, "grass", pool[rng.randi() % pool.size()])


func paint_plaza(r: Rect2i, ragged := true) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			gmask[Vector2i(x, y)] = 2   # площадка — булыжник
			var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			if ragged and edge and rng.randf() < 0.5:
				continue
			var pool: Array = COBBLES if rng.randf() < 0.85 else COBBLES_BROKEN
			set_ground(Vector2i(x, y), "grass", pool[rng.randi() % pool.size()])
			reserved[Vector2i(x, y)] = true


# ============================================================ GROUND 32px (TileMap/ground)
#
# Земля из TileMap/ground/groundtiles.png (сетка 32px). Три слоя:
#   Ground       — земля под тропами / булыжник под площадками (сплошная заливка)
#   GroundGrass  — трава поверх; по краям троп — автотайлы с прозрачной дыркой,
#                  клетка выбирается по 4 углам (трава / не трава)
#   GroundDecals — сухая трава, камешки, пятна земли, трещины
# Маска троп/площадок (gmask, клетки 16px) копится в paint_path/paint_plaza.

const GT := "res://TileMap/ground/groundtiles.png"
const GT_DIRT := Vector2i(25, 0)      # 2x2 бесшовная земля
const GT_COBBLE := Vector2i(23, 0)    # 2x2 бесшовный булыжник
# Биты "не трава" в углах клетки: TL*8 + TR*4 + BL*2 + BR -> клетка накладки
# (накладка травы с прозрачной дыркой лежит в атласе с 17-го ряда)
const GT_EDGE := {
	1: Vector2i(0, 17), 3: Vector2i(1, 17), 2: Vector2i(2, 17),
	5: Vector2i(0, 18), 10: Vector2i(2, 18),
	4: Vector2i(0, 19), 12: Vector2i(1, 19), 8: Vector2i(2, 19),
	7: Vector2i(3, 17), 11: Vector2i(4, 17), 13: Vector2i(3, 18), 14: Vector2i(4, 18),
}

var gmask := {}
var rng2 := RandomNumberGenerator.new()
var ts32: TileSet


func _gtile(layer: TileMapLayer, c: Vector2i, ac: Vector2i) -> void:
	var s: TileSetAtlasSource = ts32.get_source(0)
	if not s.has_tile(ac):
		s.create_tile(ac)
	layer.set_cell(c, 0, ac)


## Тип земли в узле сетки 32px: 0 трава, 1 земля, 2 булыжник —
## по большинству из 4 клеток 16px вокруг узла
func _vkind(vx: int, vy: int) -> int:
	var dirt := 0
	var cob := 0
	for c in [Vector2i(2 * vx - 1, 2 * vy - 1), Vector2i(2 * vx, 2 * vy - 1), Vector2i(2 * vx - 1, 2 * vy), Vector2i(2 * vx, 2 * vy)]:
		var k: int = gmask.get(c, 0)
		if k == 1:
			dirt += 1
		elif k == 2:
			cob += 1
	if dirt + cob >= 2:
		return 2 if cob >= dirt else 1
	return 0


func build_ground() -> void:
	ts32 = TileSet.new()
	ts32.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	src.texture = load(GT)
	src.texture_region_size = Vector2i(32, 32)
	ts32.add_source(src, 0)

	# Сплошной слой клеток — невидимый: по нему навмеш (nav_mesh_baker.gd)
	# узнаёт границы карты. Видимую землю рисует GroundSurface ниже
	var base := TileMapLayer.new()
	base.name = "Ground"
	base.tile_set = ts32
	base.z_index = -22
	base.visible = false
	add_node(base)
	for ty in H / 2:
		for tx in W / 2:
			_gtile(base, Vector2i(tx, ty), GT_DIRT + Vector2i(tx % 2, ty % 2))

	# Земля из листа ground_&_props: три бесшовные текстуры + маска троп
	var grass := gp_save(gp_bomb(GP_GRASS, GP_FLOWERS, 0.08, 46, 1400, 11), "grass.res")
	var dirt := gp_save(gp_bomb(GP_DIRT, [], 0.0, 40, 1600, 22), "dirt.res")
	var stone := gp_save(gp_bomb(GP_STONE, GP_DIRT, 0.25, 44, 1500, 33), "stone.res")
	var mask := gp_save(gp_ground_mask(), "ground_mask.res")
	var surf := Polygon2D.new()
	surf.name = "GroundSurface"
	var m := 64.0
	surf.polygon = PackedVector2Array([Vector2(-m, -m), Vector2(W * T + m, -m), Vector2(W * T + m, H * T + m), Vector2(-m, H * T + m)])
	surf.z_index = -22
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Shaders/ground_blend.gdshader")
	sm.set_shader_parameter("grass_tex", grass)
	sm.set_shader_parameter("dirt_tex", dirt)
	sm.set_shader_parameter("stone_tex", stone)
	sm.set_shader_parameter("mask_tex", mask)
	sm.set_shader_parameter("map_px", Vector2(W * T, H * T))
	# Квадрат листа (~74 px) ложится на ~31 px мира — как прежние тайлы 32 px
	sm.set_shader_parameter("tex_world", GP_TEX * GP_S)
	surf.material = sm
	# Трава в листе ярко-салатовая — ночью темнее и холоднее
	surf.color = Color(0.72, 0.76, 0.72)
	add_node(surf)

	# Старая трава 16px больше не нужна
	ground.get_parent().remove_child(ground)
	ground.free()


# ============================================================ WALLS

# Горизонтальная ограда в рядах y, y+1 из клеток x0..x1 — секциями из листа
# ground_&_props (каменная кладка или частокол, style = "palisade").
# gaps — массив [x0, x1] проёмов (ворот)
func h_wall(x0: int, x1: int, y: int, gaps := [], style := "stone") -> void:
	var run_start := -1
	for x in range(x0, x1 + 2):
		var in_gap := x > x1
		for g in gaps:
			if x >= g[0] and x <= g[1]:
				in_gap = true
		if x <= x1:
			reserved[Vector2i(x, y)] = true
			reserved[Vector2i(x, y + 1)] = true
			reserved[Vector2i(x, y + 2)] = true
		if in_gap:
			if run_start >= 0:
				wall_run_h(run_start, x - 1, y, style)
				run_start = -1
			continue
		walls[Vector2i(x, y)] = true
		walls[Vector2i(x, y + 1)] = true
		if run_start < 0:
			run_start = x


# Вертикальная ограда (каменная кладка) в столбце x из клеток y0..y1
func v_wall(x: int, y0: int, y1: int, gaps := []) -> void:
	var run_start := -1
	for y in range(y0, y1 + 2):
		var in_gap := y > y1
		for g in gaps:
			if y >= g[0] and y <= g[1]:
				in_gap = true
		if y <= y1:
			reserved[Vector2i(x, y)] = true
			reserved[Vector2i(x + 1, y)] = true
		if in_gap:
			if run_start >= 0:
				wall_run_v(x, run_start, y - 1)
				run_start = -1
			continue
		walls[Vector2i(x, y)] = true
		if run_start < 0:
			run_start = y


func _wall_tile(c: Vector2i, ac: Vector2i, ysort: int, solid := RECT_ALL) -> void:
	if not in_map(c):
		return
	ensure_tile("wall", ac, solid, ysort)
	objs[0].set_cell(c, SRC["wall"], ac)
	walls[c] = true


# Массивный блок здания из кладки: верх (ряд 12) + 3 ряда стены, с окнами.
# cap=false — только стена (фасад под крышей)
func wall_block(x0: int, x1: int, y: int, windows := true, cap := true) -> void:
	var rows := [12, 13, 14, 15] if cap else [13, 14, 15]
	for x in range(x0, x1 + 1):
		for ri in rows.size():
			var r: int = rows[ri] - 12
			var c := Vector2i(x, y + ri)
			reserved[c] = true
			var col := 2 + (x % 8)
			if x == x0:
				col = 2
			elif x == x1:
				col = 9
			var ac := Vector2i(col, 12 + r)
			if windows and r > 0 and (x - x0) % 6 == 3 and x != x1:
				ac = Vector2i(12, 12 + r)
			elif windows and r > 0 and (x - x0) % 6 == 4 and x != x1:
				ac = Vector2i(13, 12 + r)
			ensure_tile("wall", ac, RECT_ALL, (rows.size() - 1 - ri) * T + 6)
			objs[0].set_cell(c, SRC["wall"], ac)
			walls[c] = true
	for x in range(x0 - 1, x1 + 2):
		reserved[Vector2i(x, y + rows.size())] = true


# ============================================================ OBJECTS

func add_node(n: Node, parent: Node = null) -> Node:
	(parent if parent else lvl).add_child(n, true)
	n.owner = lvl
	return n


func set_owner_rec(n: Node) -> void:
	for ch in n.get_children():
		ch.owner = lvl
		if ch.scene_file_path == "":
			set_owner_rec(ch)


func torch(px: Vector2, kind := "torch") -> void:
	var t: Node2D = (campfire_scene if kind == "campfire" else torch_scene).instantiate()
	t.position = px
	add_node(t)
	if kind == "campfire":
		# Каменное кольцо с поленьями — из листа ground_&_props, плоско под огнём
		gp_flat("campfire_ring", px + Vector2(0, 4), GP_S, -17)


func light(px: Vector2, color: Color, energy: float, scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.position = px
	l.color = color
	l.energy = energy
	l.texture = radial_tex(256)
	l.texture_scale = scale
	l.blend_mode = Light2D.BLEND_MODE_ADD
	add_node(l)
	return l


var _radial: GradientTexture2D
func radial_tex(size: int) -> GradientTexture2D:
	if _radial:
		return _radial
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	_radial = GradientTexture2D.new()
	_radial.gradient = g
	_radial.fill = GradientTexture2D.FILL_RADIAL
	_radial.fill_from = Vector2(0.5, 0.5)
	_radial.fill_to = Vector2(0.5, 0.0)
	_radial.width = size
	_radial.height = size
	return _radial


func frames_from_strip(path: String, fw: int, fh: int, count: int, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", true)
	var tex: Texture2D = load(path)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame("default", at)
	return sf


var _ray_seed := 0.0
## Косые лучи лунного света (Shaders/moon_rays.gdshader) поверх тумана.
## Только визуал (аддитивное свечение), без PointLight — не "пятно" на земле.
## Луч задаётся точкой касания земли (foot): его верх уходит ЗА верхний край
## карты (источник света вне кадра), а таять он начинает только у земли
func moon_rays(foot: Vector2, width: float, intensity: float) -> void:
	var ang := deg_to_rad(-22.0)
	var up := Vector2(sin(ang), -cos(ang))        # куда смотрит верх луча
	var length := (foot.y + 300.0) / -up.y        # верх выше y = -300 (за картой)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var s := Sprite2D.new()
	s.name = "MoonRays"
	s.texture = ImageTexture.create_from_image(img)
	s.scale = Vector2(width, length) / 4.0
	s.position = foot + up * (length * 0.5)
	s.rotation = ang
	s.z_index = 101
	var m := ShaderMaterial.new()
	m.shader = load("res://Shaders/moon_rays.gdshader")
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("seed", _ray_seed)
	m.set_shader_parameter("fade_start", clampf(1.0 - 520.0 / length, 0.0, 0.9))
	m.set_shader_parameter("len_scale", length / 450.0)
	_ray_seed += 7.3
	s.material = m
	# Дома гасят лучи, пока игрок внутри (Levels/house_interior.gd)
	s.add_to_group("moon_rays", true)
	add_node(s)


## Возвращает корпус дома в мировых координатах. solid = false — коллизию
## корпуса не ставим (её дадут стены интерьера, см. house_interior())
## old_pose = [base, sc] — где и какого размера дом стоял раньше (см. ниже)
func house_sprite(name: String, path: String, base: Vector2, sc: float, body: Rect2, base_y: float, solid := true, old_pose := []) -> Rect2:
	var tex: Texture2D = load(path)
	var size := tex.get_size()
	var s := Sprite2D.new()
	s.name = name
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-size.x * 0.5, -size.y * base_y)
	s.scale = Vector2(sc, sc)
	s.position = base
	# Картинка уменьшается в ~5 раз — линейная фильтрация вместо рябящей nearest
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = occl_sprite
	add_node(s)
	var body_px := Rect2((body.position.x - 0.5) * size.x * sc, (body.position.y - base_y) * size.y * sc,
			body.size.x * size.x * sc, body.size.y * size.y * sc)
	if solid:
		static_rect(base, body_px)
	var tl := base + Vector2(-size.x * 0.5, -size.y * base_y) * sc
	var rect := Rect2i(Vector2i(tl / T) - Vector2i.ONE, Vector2i(size * sc / T) + Vector2i(3, 3))
	if old_pose.is_empty():
		reserve_rect(rect)
	else:
		# Дом увеличен/сдвинут: резерв — по СТАРОМУ месту (от него зависит поток
		# случайных чисел и вся остальная карта), а новое место только
		# запрещаем для деревьев и декора — это проверяется уже после броска
		var old_base: Vector2 = old_pose[0]
		var old_sc: float = old_pose[1]
		var old_tl := old_base + Vector2(-size.x * 0.5, -size.y * base_y) * old_sc
		reserve_rect(Rect2i(Vector2i(old_tl / T) - Vector2i.ONE, Vector2i(size * old_sc / T) + Vector2i(3, 3)))
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				blocked[Vector2i(x, y)] = true
	return Rect2(base + body_px.position, body_px.size)


## Тень персонажа от огня: оклюдер у его ног (player_spawner.gd, player_shadow)
## на слое 16 — только он, тайлы и дома теней не дают. extra — ещё слои
## оклюдеров (32 — стены комнат, для огня внутри дома)
func fire_shadow(l: Light2D, extra := 0) -> void:
	l.shadow_enabled = true
	l.shadow_item_cull_mask = 16 | extra
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	l.shadow_filter_smooth = 3.0
	# Тень не чёрная дыра: в ней остаётся немного света огня
	l.shadow_color = Color(0, 0, 0, 0.25)


func static_rect(px: Vector2, rect: Rect2, layer := 1) -> void:
	var b := StaticBody2D.new()
	b.position = px
	b.collision_layer = layer
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = rect.size
	cs.shape = sh
	cs.position = rect.get_center()
	b.add_child(cs)
	add_node(b)
	cs.owner = lvl


# ============================================================ ИНТЕРЬЕРЫ ДОМОВ
#
# Интерьеры собираются из листа TileMap/interior/rooms/tiles_interior_2.png в
# top-down стиле: дощатый пол, задняя стена — фасад с деревянным каркасом и
# окнами (бывает разрушенный), боковые, нижняя и внутренние стены — тёмные
# балки "сверху". Дома заброшены: огня нет нигде, свет только лунный — из окон
# и дыр в крыше; на полу мусор, листья и обломки.
#
# Все координаты ниже — пиксели "картинки дома" (= пиксели листа), в мир она
# ложится с масштабом INT_S. Точка door (низ проёма входной двери) ставится
# на дверь спрайта дома снаружи.

const INT_SHEET := "res://TileMap/interior/rooms/tiles_interior_2.png"
## Кровать ~ 55 px мира (два роста героя), доска пола ~ 30 px
const INT_S := 0.4
## Собранные картинки этажей сохраняются сюда — сцена ссылается на них
const ROOMS_DIR := "res://TileMap/interior/rooms/"
## Толщина стены "сверху" и высота фасада задней стены
const WALL_T := 24
const FACE_H := 105

const IS := {
	# пол: доски (по большей части), гнилые доски, мусор/листья с рваным краем
	"planks": [Rect2(18, 18, 78, 82), Rect2(18, 112, 78, 82), Rect2(18, 206, 78, 81), Rect2(200, 18, 81, 82)],
	"rotten": [Rect2(109, 206, 79, 81), Rect2(200, 206, 80, 81), Rect2(200, 112, 80, 82)],
	"debris": [Rect2(584, 113, 81, 82), Rect2(679, 206, 85, 88), Rect2(584, 206, 81, 90), Rect2(480, 300, 103, 88), Rect2(601, 301, 163, 94)],
	# каркас стены: верхняя балка (повторяемая середина) и столб
	"beam": Rect2(1015, 20, 110, 18), "post": Rect2(992, 40, 21, 65),
	# лестница: перила по бокам, середина (5 ступеней) повторяется
	"stairs": Rect2(1406, 16, 107, 127), "stairs_mid": Vector2(46, 104),
}

## Фасады задней стены: прямоугольник, доля ширины, где центр окна (-1 — без окна)
const FACES := {
	"broken": [Rect2(790, 18, 182, 105), -1.0], "hole": [Rect2(784, 132, 107, 102), -1.0],
	"win_a": [Rect2(988, 18, 159, 105), 0.53], "win_b": [Rect2(1162, 17, 134, 106), 0.49],
	"win_c": [Rect2(906, 132, 131, 102), 0.5], "win_d": [Rect2(1052, 131, 131, 104), 0.5],
	"win_e": [Rect2(1200, 132, 101, 103), 0.43],
}

## Мебель и утварь: прямоугольник в листе
const IT := {
	"hearth": Rect2(1417, 286, 96, 110),        # холодный камин с золой
	"chimney_ruin": Rect2(1421, 150, 85, 124),  # развалившийся дымоход
	"bed_torn": Rect2(522, 399, 64, 130), "bed_red": Rect2(115, 387, 82, 138),
	"chair": Rect2(706, 404, 39, 53), "chair_small": Rect2(635, 471, 29, 50), "plank": Rect2(600, 471, 21, 60),
	"shelf_potions": Rect2(889, 429, 90, 76), "shelf_jars": Rect2(997, 428, 78, 78), "shelf_low": Rect2(1010, 592, 98, 65),
	"shelf_small": Rect2(953, 593, 36, 53), "armor": Rect2(1092, 424, 54, 85), "wardrobe": Rect2(1300, 419, 60, 91),
	"chest_big": Rect2(1204, 444, 77, 61), "chest": Rect2(1310, 520, 56, 39), "trunk": Rect2(797, 705, 69, 44),
	"desk_map": Rect2(898, 520, 68, 58), "table_cloth": Rect2(793, 512, 90, 61), "table_plates": Rect2(866, 756, 103, 52),
	"table_tools": Rect2(674, 825, 99, 54), "bench": Rect2(797, 650, 88, 43), "nightstand": Rect2(890, 588, 45, 45),
	"rug_red": Rect2(987, 520, 143, 64), "fur": Rect2(1123, 727, 83, 79), "bear": Rect2(1240, 684, 69, 117),
	"barrel": Rect2(200, 792, 45, 66), "tub": Rect2(87, 881, 54, 59), "crate": Rect2(1336, 713, 60, 67),
	"crate_s": Rect2(664, 897, 44, 46), "crate_tall": Rect2(729, 920, 39, 76), "sack": Rect2(337, 951, 40, 47),
	"basket": Rect2(284, 878, 33, 43), "bucket": Rect2(889, 706, 30, 34), "skull": Rect2(857, 960, 29, 37),
	"rubble": Rect2(1162, 250, 52, 63), "rubble2": Rect2(1238, 246, 59, 61), "stones": Rect2(620, 697, 50, 28),
	"wagon": Rect2(528, 794, 125, 118), "logs": Rect2(402, 851, 104, 31), "logs2": Rect2(407, 819, 97, 30),
	"wheel": Rect2(562, 730, 49, 52), "anvil": Rect2(1026, 765, 59, 38),
}

var _isheet: Image


func _int_sheet() -> Image:
	if _isheet == null:
		_isheet = Image.load_from_file(ProjectSettings.globalize_path(INT_SHEET))
		_isheet.convert(Image.FORMAT_RGBA8)
	return _isheet


func _blend_piece(img: Image, src: Image, at: Vector2i) -> void:
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)


## Кусок листа, при необходимости растянутый до size
func _piece(r: Rect2, size := Vector2i.ZERO) -> Image:
	var p := _int_sheet().get_region(Rect2i(r))
	if size != Vector2i.ZERO and size != p.get_size():
		p.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	return p


func _fill_rect(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())), c)


## Пол: доски плиткой, кое-где гнилые; без рамки плитки (обрезка по 4 px)
func _int_floor(img: Image, r: Rect2i, rnd: RandomNumberGenerator, rotten := 0.15) -> void:
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		var h := 72
		while x < r.end.x:
			var pool: Array = IS.rotten if rnd.randf() < rotten else IS.planks
			var t: Rect2 = pool[rnd.randi() % pool.size()]
			var tile := _piece(t.grow(-4))
			var w := mini(tile.get_width(), r.end.x - x)
			var hh := mini(mini(h, tile.get_height()), r.end.y - y)
			img.blit_rect(tile, Rect2i(0, 0, w, hh), Vector2i(x, y))
			x += w
		y += h


## Мусор и листья поверх пола — пятнами с рваным краем
func _int_debris(img: Image, r: Rect2i, count: int, rnd: RandomNumberGenerator) -> void:
	for i in count:
		var d: Rect2 = IS.debris[rnd.randi() % IS.debris.size()]
		var p := _piece(d)
		if rnd.randf() < 0.5:
			p.flip_x()
		if rnd.randf() < 0.5:
			p.flip_y()
		var k := rnd.randf_range(0.55, 0.85)
		for yy in p.get_height():
			for xx in p.get_width():
				var c := p.get_pixel(xx, yy)
				c.a *= k
				p.set_pixel(xx, yy, c)
		var at := Vector2i(rnd.randi_range(r.position.x - 20, r.end.x - p.get_width() + 20), rnd.randi_range(r.position.y - 10, r.end.y - p.get_height() + 10))
		_blend_piece(img, p, at)


## Задняя стена-фасад: куски по порядку, растянутые ровно под ширину.
## Возвращает x центров окон
func _int_face(img: Image, x0: int, x1: int, y: int, names: Array) -> Array:
	var total := 0.0
	for n in names:
		total += (FACES[n][0] as Rect2).size.x
	var sx := float(x1 - x0) / total
	var x := float(x0)
	var windows := []
	for n in names:
		var r: Rect2 = FACES[n][0]
		var w := r.size.x * sx
		_blend_piece(img, _piece(r, Vector2i(roundi(w), FACE_H)), Vector2i(roundi(x), y))
		if FACES[n][1] >= 0.0:
			windows.append(x + w * FACES[n][1])
		x += w
	return windows


## Стена "сверху": тёмная полоса с балкой каркаса посередине
func _int_hstrip(img: Image, x0: int, x1: int, y: int) -> void:
	_fill_rect(img, Rect2i(x0, y, x1 - x0, WALL_T), Color(0.07, 0.055, 0.045))
	var b := _piece(IS.beam)
	var x := x0 + 2
	while x < x1 - 2:
		var w := mini(b.get_width(), x1 - 2 - x)
		img.blit_rect(b, Rect2i(0, 0, w, b.get_height()), Vector2i(x, y + 3))
		x += w


func _int_vstrip(img: Image, x: int, y0: int, y1: int) -> void:
	_fill_rect(img, Rect2i(x, y0, WALL_T, y1 - y0), Color(0.07, 0.055, 0.045))
	var p := _piece(IS.post)
	var y := y0 + 2
	while y < y1 - 2:
		var h := mini(p.get_height(), y1 - 2 - y)
		img.blit_rect(p, Rect2i(0, 0, p.get_width(), h), Vector2i(x + 1, y))
		y += h


## Лестница: верх и низ куска листа, середина повторяется repeat раз.
## down — вид сверху в пролёт: низ уходит в темноту первого этажа,
## иначе (снизу) — верх уходит под перекрытие
func _int_stairs(img: Image, at: Vector2i, repeat: int, down: bool) -> Rect2i:
	var s: Rect2 = IS.stairs
	var m: Vector2 = IS.stairs_mid
	var top := _piece(Rect2(s.position.x, s.position.y, s.size.x, m.x))
	var mid := _piece(Rect2(s.position.x, s.position.y + m.x, s.size.x, m.y - m.x))
	var bot := _piece(Rect2(s.position.x, s.position.y + m.y, s.size.x, s.size.y - m.y))
	var h := top.get_height() + mid.get_height() * repeat + bot.get_height()
	if down:
		_fill_rect(img, Rect2i(at.x + 18, at.y, int(s.size.x) - 36, h), Color(0.02, 0.015, 0.01))
	_blend_piece(img, top, at)
	for i in repeat:
		_blend_piece(img, mid, at + Vector2i(0, top.get_height() + i * mid.get_height()))
	_blend_piece(img, bot, at + Vector2i(0, top.get_height() + repeat * mid.get_height()))
	var dh := 130
	var dark := Image.create(int(s.size.x) + 8, dh, false, Image.FORMAT_RGBA8)
	for y in dh:
		var k := float(y) / dh
		var a := 0.95 * pow(k if down else 1.0 - k, 1.5)
		for x in dark.get_width():
			var e := clampf(minf(x, dark.get_width() - 1 - x) / 6.0, 0.0, 1.0)
			dark.set_pixel(x, y, Color(0.02, 0.015, 0.01, a * e))
	_blend_piece(img, dark, Vector2i(at.x - 4, at.y + h - dh if down else at.y))
	return Rect2i(at, Vector2i(int(s.size.x), h))


## Предмет: картинка листа в точке at (левый верх). solid — нижняя доля высоты
## под коллизию (0 — без коллизии, ковры). Возвращает коллизию или пустой
func _int_item(img: Image, name: String, at: Vector2, solid := 0.45, flip := false) -> Rect2:
	var r: Rect2 = IT[name]
	var p := _piece(r)
	if flip:
		p.flip_x()
	_blend_piece(img, p, Vector2i(at))
	if solid <= 0.0:
		return Rect2()
	return Rect2(at.x + 3, at.y + r.size.y * (1.0 - solid), r.size.x - 6, r.size.y * solid - 2)


## Дома. Разрушенный дом: справа зал под щипцом (дверь — арка на спрайте,
## 0.5895 ширины картинки), слева под низким крылом кладовая и спальня, по
## лестнице у правой стены зала — второй этаж. Амбар — одна большая комната
func build_interiors(ruin_base: Vector2, ruin_sc: float, ruin_body: Rect2, barn_base: Vector2, barn_sc: float, barn_body: Rect2) -> void:
	var moon := Color(0.62, 0.72, 0.95)
	var ruin_w: float = load("res://TileMap/Houses/ruin_house.png").get_width()
	# Комнаты занимают всё место под крышей дома: зал x 586..1156 y 0..660,
	# крыло (спальня x 0..320, кладовая x 296..610) y 180..660. Справа от
	# зала — ограда кладбища, дальше не расширить. Проёмы между комнатами у
	# нижней стены — 90 px (36 px мира: проходят и враги)
	var walls_common := {
		"h": [[586, 1156, 0], [0, 586, 180]],
		"v": [[0, 180, 660], [1132, 0, 660], [586, 0, 530], [586, 620, 636], [296, 180, 530], [296, 620, 636]],
	}
	var floor_rects := [Rect2i(610, 129, 522, 507), Rect2i(320, 309, 266, 327), Rect2i(24, 309, 272, 327),
			Rect2i(574, 530, 50, 90), Rect2i(284, 530, 50, 90), Rect2i(641, 630, 90, 30)]     # + проёмы и порог
	var debris_g := [[Rect2i(610, 140, 400, 490), 12], [Rect2i(320, 320, 260, 300), 5], [Rect2i(24, 320, 265, 300), 5]]
	var ground := {
		"floor": floor_rects,
		"rotten": 0.18,
		"debris": debris_g,
		"faces": [[610, 1132, WALL_T, ["broken", "win_a", "hole", "win_d"]],
				[320, 586, 204, ["win_b", "win_c"]],
				[24, 296, 204, ["hole", "win_e"]]],
		"h": walls_common.h + [[0, 641, 636], [731, 1156, 636]],     # входная дверь x 641..731
		"v": walls_common.v,
		"stairs": [Vector2i(1021, WALL_T), 5, false],
		"items": [
			# зал
			["hearth", Vector2(760, 39)], ["shelf_jars", Vector2(900, 62)],
			["rubble", Vector2(616, 132), 0.5], ["stones", Vector2(680, 172), 0.0], ["skull", Vector2(960, 250), 0.0],
			["table_plates", Vector2(720, 360)], ["chair", Vector2(835, 356), 0.4, true], ["plank", Vector2(700, 450), 0.0],
			["bench", Vector2(765, 425), 0.35], ["crate", Vector2(630, 290)], ["rubble2", Vector2(900, 520), 0.5],
			["barrel", Vector2(1050, 470)], ["crate_s", Vector2(1060, 540)],
			# кладовая
			["shelf_potions", Vector2(335, 240)], ["shelf_low", Vector2(440, 250)], ["barrel", Vector2(340, 330)],
			["sack", Vector2(395, 345)], ["crate", Vector2(480, 330)], ["basket", Vector2(440, 410), 0.4], ["crate_s", Vector2(530, 420)],
			# спальня
			["bed_torn", Vector2(44, 245)], ["nightstand", Vector2(120, 265)], ["wardrobe", Vector2(210, 220)],
			["chest", Vector2(130, 345)], ["bear", Vector2(130, 395), 0.0], ["chair_small", Vector2(240, 330), 0.4],
		],
		"solids": [Rect2(1021, 129, 20, 312), Rect2(1108, 129, 24, 312)],     # перила лестницы
		"lights": [[Vector2(820, 300), moon, 0.38, 46.0]],                    # дыра в крыше над залом
		"fill": 0.34,
	}
	var upper := {
		"floor": floor_rects,
		"rotten": 0.3,
		"debris": [[Rect2i(610, 140, 400, 490), 16], [Rect2i(320, 320, 260, 300), 7], [Rect2i(24, 320, 265, 300), 7]],
		"faces": [[610, 1132, WALL_T, ["win_b", "broken", "win_c"]],
				[320, 586, 204, ["broken", "win_e"]],
				[24, 296, 204, ["win_d", "hole"]]],
		"h": walls_common.h + [[0, 1156, 636]],      # двери наверху нет
		"v": walls_common.v,
		"stairs": [Vector2i(1021, WALL_T), 5, true],
		"items": [
			# кабинет над залом: дымоход насквозь, книжные полки, стол с картой
			["chimney_ruin", Vector2(765, 24)], ["shelf_potions", Vector2(630, 60)], ["shelf_low", Vector2(870, 72)],
			["armor", Vector2(960, 52), 0.35], ["rug_red", Vector2(700, 420), 0.0],
			["desk_map", Vector2(660, 260)], ["chair_small", Vector2(690, 318), 0.4],
			["rubble", Vector2(820, 520), 0.5], ["stones", Vector2(880, 300), 0.0], ["crate_tall", Vector2(1070, 500)],
			# комната над кладовой: верстак, сундук
			["table_tools", Vector2(340, 380)], ["chest_big", Vector2(470, 250)], ["shelf_small", Vector2(330, 256)],
			# хозяйская спальня
			["bed_red", Vector2(40, 250)], ["nightstand", Vector2(130, 255)], ["trunk", Vector2(180, 380)],
			["fur", Vector2(60, 420), 0.0],
		],
		# Перила пролёта: слева (кроме верха — там сходят на этаж), снизу и справа
		# (как внизу — иначе, спускаясь вдоль правого края, герой оказался бы
		# внутри нижних перил)
		"solids": [Rect2(1021, 235, 20, 208), Rect2(1021, 441, 111, 8), Rect2(1108, 129, 24, 312)],
		# луна сквозь дыры в крыше
		"lights": [[Vector2(700, 520), moon, 0.42, 46.0], [Vector2(880, 360), moon, 0.36, 40.0],
				[Vector2(420, 470), moon, 0.34, 36.0], [Vector2(150, 500), moon, 0.3, 36.0]],
		"fill": 0.3,
	}
	house2("RuinHouseInterior", "RuinHouse", ruin_body, {
		"size": Vector2i(1156, 660), "door": Vector2(686, 660),
		"world_door": Vector2(ruin_base.x + 0.0895 * ruin_w * ruin_sc, ruin_base.y + 4.0),
		"rooms": [Rect2(586, 0, 570, 660), Rect2(296, 180, 314, 480), Rect2(0, 180, 320, 480)],
		"floors": [ground, upper],
		# ступени между перилами; верх — докуда реально доходит герой у стены
		"stairs_rect": Rect2(1041, 140, 67, 301),
		"seed": 77,
	})
	# Амбар: телега, дрова, бочки — хозяйство брошено. Комната — почти вся
	# стеновая часть сарая
	var barn_w: float = load("res://TileMap/Houses/barn.png").get_width()
	house2("BarnInterior", "Barn", barn_body, {
		"size": Vector2i(700, 535), "door": Vector2(274, 535),
		"world_door": Vector2(barn_base.x - 0.135 * barn_w * barn_sc, barn_base.y + 2.0),
		"rooms": [Rect2(0, 0, 700, 535)],
		"floors": [{
			"floor": [Rect2i(24, 129, 652, 382), Rect2i(229, 505, 90, 30)],
			"rotten": 0.35,
			"debris": [[Rect2i(24, 140, 652, 370), 11]],
			"faces": [[24, 676, WALL_T, ["win_a", "hole", "win_e", "win_b"]]],
			"h": [[0, 700, 0], [0, 229, 511], [319, 700, 511]],
			"v": [[0, 0, 535], [676, 0, 535]],
			"items": [
				["wagon", Vector2(50, 120), 0.5], ["wheel", Vector2(200, 140), 0.0], ["logs", Vector2(330, 125), 0.6],
				["logs2", Vector2(334, 150), 0.6], ["sack", Vector2(500, 170)], ["tub", Vector2(560, 170)],
				["crate", Vector2(580, 280)], ["crate_tall", Vector2(620, 380)], ["crate_s", Vector2(60, 380)],
				["barrel", Vector2(110, 370)], ["anvil", Vector2(450, 400)], ["bucket", Vector2(300, 330), 0.4],
				["stones", Vector2(380, 450), 0.0],
			],
			"lights": [],
			"fill": 0.34,
		}],
		"seed": 91,
	})


func house2(node_name: String, exterior: String, body: Rect2, h: Dictionary) -> void:
	var size: Vector2i = h.size
	var origin: Vector2 = (h.world_door as Vector2) - (h.door as Vector2) * INT_S
	var wp := func(p: Vector2) -> Vector2: return origin + p * INT_S
	var wrect := func(r: Rect2) -> Rect2: return Rect2(origin + r.position * INT_S, r.size * INT_S)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = h.seed

	var root := Node2D.new()
	root.name = node_name
	root.z_index = -15          # над землёй (-19), под персонажами и объектами (0)
	root.set_script(load("res://Levels/house_interior.gd"))
	add_node(root)

	var floors: Array = h.floors
	for fi in floors.size():
		var f: Dictionary = floors[fi]
		var solid_layer := 1 if fi == 0 else 512   # верхний этаж — только для игрока наверху
		var occ_bit := 32 << fi
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		for r: Rect2i in f.floor:
			_int_floor(img, r, rnd, f.get("rotten", 0.15))
		for d in f.get("debris", []):
			_int_debris(img, d[0], d[1], rnd)
		var windows := []
		var solids: Array[Rect2] = []
		for fc in f.faces:
			# Под фасадом — тёмная кладка: в рваных краях разрушенных кусков иначе
			# просвечивала бы трава с улицы
			_fill_rect(img, Rect2i(fc[0], fc[2], fc[1] - fc[0], FACE_H), Color(0.1, 0.085, 0.075))
			for wx in _int_face(img, fc[0], fc[1], fc[2], fc[3]):
				windows.append(Vector2(wx, fc[2] + FACE_H))
			# фасад непроходим, кроме нижних пикселей — герой встаёт к стене вплотную
			solids.append(Rect2(fc[0], fc[2], fc[1] - fc[0], FACE_H - 8))
		# Стены "сверху" — поверх пола и мусора
		var wall_rects: Array[Rect2] = []
		for s in f.h:
			_int_hstrip(img, s[0], s[1], s[2])
			wall_rects.append(Rect2(s[0], s[2], s[1] - s[0], WALL_T))
		for s in f.v:
			_int_vstrip(img, s[0], s[1], s[2])
			wall_rects.append(Rect2(s[0], s[1], WALL_T, s[2] - s[1]))
		if f.has("stairs"):
			_int_stairs(img, f.stairs[0], f.stairs[1], f.stairs[2])
		for it in f.get("items", []):
			var sr := _int_item(img, it[0], it[1], it[2] if it.size() > 2 else 0.45, it[3] if it.size() > 3 else false)
			if sr.size != Vector2.ZERO:
				solids.append(sr)
		for s: Rect2 in f.get("solids", []):
			solids.append(s)

		var path := ROOMS_DIR + node_name + ("" if fi == 0 else "_floor%d" % (fi + 1)) + ".res"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOMS_DIR))
		ResourceSaver.save(ImageTexture.create_from_image(img), path)
		var tex: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

		var fnode := Node2D.new()
		fnode.name = "Floor%d" % fi
		add_node(fnode, root)
		var vis := Node2D.new()
		vis.name = "Visuals"
		add_node(vis, fnode)
		var spr := Sprite2D.new()
		spr.name = "Rooms"
		spr.texture = tex
		spr.centered = false
		spr.position = origin
		spr.scale = Vector2(INT_S, INT_S)
		# Лист уменьшается в 2.5 раза — линейная фильтрация, как у домов
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Свой бит света: лунный свет и облака (бит 1) под крышу не попадают
		spr.light_mask = 2
		add_node(spr, vis)

		# ---- свет: только луна — пятна под окнами и дырами в крыше
		var lights := Node2D.new()
		lights.name = "Lights"
		add_node(lights, fnode)
		var moon := Color(0.62, 0.72, 0.95)
		var spots: Array = f.get("lights", []).duplicate()
		for w: Vector2 in windows:
			spots.append([w + Vector2(0, 48), moon, 0.36, 40.0])
		for l in spots:
			var pl := PointLight2D.new()
			pl.texture = radial_tex(256)
			pl.texture_scale = float(l[3]) * 2.0 / 256.0
			pl.position = wp.call(l[0])
			pl.color = l[1]
			pl.energy = l[2]
			pl.blend_mode = Light2D.BLEND_MODE_ADD
			# Светит и на интерьер, и на героя/врагов (бит 1); стены — оклюдеры,
			# свет не выходит наружу. От него и тень героя на полу
			pl.range_item_cull_mask = 3
			fire_shadow(pl, occ_bit)
			add_node(pl, lights)
			# Копия без тени — только тело героя (слой 8): лунный свет ложится и
			# на него, но собственной тени он не ловит
			var bl := pl.duplicate() as PointLight2D
			bl.name = "BodyLight"
			bl.shadow_enabled = false
			bl.range_item_cull_mask = 8
			bl.texture_scale = pl.texture_scale * 1.3
			bl.energy = pl.energy * 0.8
			add_node(bl, lights)
		# Общий рассеянный свет — "коробка" по каждой комнате, холодный и тусклый
		for rr: Rect2 in h.rooms:
			var wr: Rect2 = wrect.call(rr)
			var bw := 64
			var bh := maxi(8, roundi(bw * wr.size.y / wr.size.x))
			var box := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
			for y in bh:
				for x in bw:
					var e := minf(minf(x, bw - 1 - x) / 6.0, minf(y, bh - 1 - y) / 6.0)
					var v := smoothstep(0.0, 1.0, clampf(e, 0.0, 1.0))
					box.set_pixel(x, y, Color(v, v, v, v))
			var fl := PointLight2D.new()
			fl.texture = ImageTexture.create_from_image(box)
			fl.texture_scale = wr.size.x / bw
			fl.position = wr.get_center()
			fl.color = Color(0.58, 0.64, 0.78)
			fl.energy = f.fill
			fl.blend_mode = Light2D.BLEND_MODE_ADD
			fl.range_item_cull_mask = 11     # интерьер, всё обычное и тело героя
			add_node(fl, lights)

		# ---- стены не пропускают свет наружу и в соседние комнаты
		for i in wall_rects.size():
			var wr: Rect2 = wrect.call(wall_rects[i])
			var occ := LightOccluder2D.new()
			occ.name = "WallOccluder%d" % (i + 1)
			var poly := OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([wr.position, Vector2(wr.end.x, wr.position.y), wr.end, Vector2(wr.position.x, wr.end.y)])
			occ.occluder = poly
			occ.occluder_light_mask = occ_bit
			add_node(occ, fnode)

		# ---- коллизия: стены и мебель
		for s: Rect2 in wall_rects + solids:
			static_rect(Vector2.ZERO, wrect.call(s), solid_layer)

	# Затемнение улицы — полигон на всю карту с запасом, поверх всего мира
	var shade := Polygon2D.new()
	shade.name = "Shade"
	var m := 1200.0
	shade.polygon = PackedVector2Array([Vector2(-m, -m), Vector2(W * T + m, -m), Vector2(W * T + m, H * T + m), Vector2(-m, H * T + m)])
	shade.z_as_relative = false
	shade.z_index = 110
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Shaders/indoor_shade.gdshader")
	shade.material = sm
	add_node(shade, root)

	var room_rects: Array[Rect2] = []
	for rr: Rect2 in h.rooms:
		room_rects.append(wrect.call(rr))
	root.set("exterior_path", root.get_path_to(lvl.get_node(exterior)))
	root.set("rooms", room_rects)
	if h.has("stairs_rect"):
		root.set("stairs_rect", wrect.call(h.stairs_rect))

	# Корпус дома, не занятый комнатами, — сплошной: по бокам от комнат и над
	# теми, что ниже крыши (низкое крыло)
	var minx := INF
	var maxx := -INF
	for rr: Rect2 in room_rects:
		minx = minf(minx, rr.position.x)
		maxx = maxf(maxx, rr.end.x)
		if rr.position.y > body.position.y:
			static_rect(Vector2.ZERO, Rect2(rr.position.x, body.position.y, rr.size.x, rr.position.y - body.position.y))
	if minx > body.position.x:
		static_rect(Vector2.ZERO, Rect2(body.position.x, body.position.y, minx - body.position.x, body.size.y))
	if maxx < body.end.x:
		static_rect(Vector2.ZERO, Rect2(maxx, body.position.y, body.end.x - maxx, body.size.y))


# ============================================================ ЛИСТ ground_&_props
#
# TileMap/ground/ground_&_props.png — земля, ограды и пропсы (деревья из него не
# берём). Лист нарисован без сетки, поэтому всё берётся прямоугольниками
# (найдены по непрозрачным пикселям) и ставится отдельными спрайтами, а земля
# собирается в бесшовные текстуры (см. build_ground).

const GP := "res://TileMap/ground/ground_&_props.png"
const GP_DIR := "res://TileMap/ground/generated/"
## Масштаб пропсов: бочка ~ 23 px, куст ~ 27 px — по росту героя
const GP_S := 0.42

const GP_SPR := {
	# каменная кладка: горизонтальные секции и вертикальная
	"stone_a": Rect2(20, 576, 141, 49), "stone_b": Rect2(184, 577, 72, 48),
	"stone_c": Rect2(278, 577, 116, 46), "stone_d": Rect2(20, 643, 236, 45),
	"stone_v": Rect2(566, 573, 33, 133),
	# частокол
	"pal_a": Rect2(20, 487, 97, 71), "pal_b": Rect2(137, 487, 121, 68),
	"pal_c": Rect2(280, 486, 114, 69), "pal_d": Rect2(415, 487, 121, 69), "pal_e": Rect2(556, 487, 58, 70),
	# кусты
	"bush_1": Rect2(764, 29, 54, 53), "bush_2": Rect2(839, 23, 64, 71), "bush_3": Rect2(758, 100, 65, 57),
	"bush_4": Rect2(847, 103, 56, 56), "bush_5": Rect2(963, 182, 53, 59), "bush_6": Rect2(1120, 178, 48, 51),
	"bush_7": Rect2(809, 260, 44, 60), "bush_8": Rect2(1439, 219, 53, 53), "bush_9": Rect2(1420, 293, 47, 46),
	"bush_10": Rect2(1475, 300, 38, 39),
	# камни
	"rock_1": Rect2(975, 101, 58, 53), "rock_2": Rect2(1043, 133, 69, 65), "rock_3": Rect2(879, 256, 67, 68),
	"rock_4": Rect2(1024, 238, 74, 66), "rock_5": Rect2(968, 254, 39, 46), "rock_6": Rect2(1058, 325, 60, 67),
	# мелочь на земле
	"sprout_1": Rect2(924, 39, 29, 43), "sprout_2": Rect2(924, 99, 24, 17), "sprout_3": Rect2(930, 132, 21, 20),
	"sprout_4": Rect2(761, 254, 30, 25), "sprout_5": Rect2(762, 290, 31, 29), "sprout_6": Rect2(832, 335, 25, 27),
	"sprout_7": Rect2(1494, 264, 24, 22), "sprout_8": Rect2(1478, 351, 26, 25),
	"pebble_1": Rect2(805, 70, 11, 11), "pebble_2": Rect2(1102, 241, 11, 14),
	# стоянки, двор, ворота
	"campfire_ring": Rect2(471, 767, 68, 65),
	"tent_white": Rect2(804, 555, 103, 93), "tent_red": Rect2(946, 414, 90, 117),
	"bedroll_white": Rect2(1108, 746, 58, 52), "bedroll_red": Rect2(1082, 808, 86, 38),
	"log_bench": Rect2(402, 896, 110, 32), "log_bench2": Rect2(413, 867, 92, 27),
	"pot_stand": Rect2(618, 700, 88, 59), "well": Rect2(727, 703, 49, 46),
	"woodpile": Rect2(688, 873, 104, 56), "firewood": Rect2(696, 953, 40, 47),
	"barrel": Rect2(192, 848, 42, 56), "barrel_small": Rect2(133, 857, 40, 48),
	"crate": Rect2(319, 862, 55, 53), "crate_stack": Rect2(1297, 567, 61, 61), "crate_tall": Rect2(758, 943, 37, 59),
	"sack_cart": Rect2(712, 769, 66, 61), "jug": Rect2(246, 869, 27, 46), "bucket": Rect2(388, 951, 26, 40),
	"banner_red": Rect2(146, 711, 51, 110), "banner_red2": Rect2(348, 712, 53, 115),
	"scythe": Rect2(27, 718, 36, 111), "handcart": Rect2(1424, 725, 88, 62),
}

var gp_rng := RandomNumberGenerator.new()   # свой поток: основной rng не трогаем
var _gp_atlas := {}
var _gp_sheet: Image


func gp_tex(name: String) -> AtlasTexture:
	if not _gp_atlas.has(name):
		var at := AtlasTexture.new()
		at.atlas = load(GP)
		at.region = GP_SPR[name]
		_gp_atlas[name] = at
	return _gp_atlas[name]


## Спрайт из листа, стоящий основанием (низ картинки по центру) в base —
## по основанию он и сортируется по глубине. solid — доли ширины/высоты
## картинки у основания под коллизию (ноль — без коллизии)
## Что можно разбить (Levels/props/breakable_prop.gd): [прочность, шанс монет].
## Хрупкое деревянное и глиняное; камни, кусты, палатки, колодец — нет
const BREAKABLE := {
	"barrel": [2, 0.35], "barrel_small": [1, 0.25], "crate": [2, 0.4], "crate_stack": [3, 0.5],
	"crate_tall": [2, 0.35], "bucket": [1, 0.0], "jug": [1, 0.15], "firewood": [1, 0.0],
	"woodpile": [3, 0.0], "sack_cart": [3, 0.4], "handcart": [3, 0.0], "pot_stand": [2, 0.0],
	"log_bench": [2, 0.0], "log_bench2": [2, 0.0], "banner_red": [2, 0.0], "banner_red2": [2, 0.0],
	"scythe": [1, 0.0],
}


## Разбиваемый предмет: StaticBody2D со скриптом, стоит основанием в base
func gp_breakable(name: String, base: Vector2, sc: float, solid: Vector2, flip: bool) -> Sprite2D:
	var r: Rect2 = GP_SPR[name]
	var b := StaticBody2D.new()
	b.name = name.to_pascal_case()
	b.position = base
	b.collision_layer = 1
	b.set_script(load("res://Levels/props/breakable_prop.gd"))
	b.set("hits", BREAKABLE[name][0])
	b.set("loot_chance", BREAKABLE[name][1])
	b.set("pieces", Vector2i(clampi(roundi(r.size.x / 28.0), 2, 4), clampi(roundi(r.size.y / 28.0), 2, 3)))
	# Цвет щепок — средний цвет самого предмета
	var img := _gp_sheet_img()
	var avg := Color(0, 0, 0, 0)
	for y in range(int(r.position.y), int(r.end.y), 3):
		for x in range(int(r.position.x), int(r.end.x), 3):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				avg += Color(c.r, c.g, c.b, 1.0)
	if avg.a > 0.0:
		b.set("chip_color", Color(avg.r / avg.a, avg.g / avg.a, avg.b / avg.a))
	add_node(b)
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = gp_tex(name)
	s.centered = false
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y)
	s.scale = Vector2(sc, sc)
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = occl_sprite
	add_node(s, b)
	var w := r.size.x * sc
	var h := r.size.y * sc
	if solid.x > 0.0 and solid.y > 0.0:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w * solid.x, h * solid.y)
		cs.shape = sh
		cs.position = Vector2(0, -h * solid.y * 0.5)
		add_node(cs, b)
	# Область попаданий — весь предмет: удар мечом приходится по корпусу
	var hb := Area2D.new()
	hb.name = "Hurtbox"
	hb.collision_layer = 0
	hb.collision_mask = 1
	add_node(hb, b)
	var hcs := CollisionShape2D.new()
	var hsh := RectangleShape2D.new()
	hsh.size = Vector2(w * 0.9, h * 0.9)
	hcs.shape = hsh
	hcs.position = Vector2(0, -h * 0.5)
	add_node(hcs, hb)
	return s


func gp_prop(name: String, base: Vector2, sc := GP_S, solid := Vector2(0.7, 0.3), flip := false, sx := 1.0) -> Sprite2D:
	if BREAKABLE.has(name) and sx == 1.0:
		return gp_breakable(name, base, sc, solid, flip)
	var r: Rect2 = GP_SPR[name]
	var s := Sprite2D.new()
	s.name = name.to_pascal_case()
	s.texture = gp_tex(name)
	s.centered = false
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y)
	s.scale = Vector2(sc * sx, sc)
	s.flip_h = flip
	s.position = base
	# Лист уменьшается в ~2.5 раза — линейная фильтрация, как у домов
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Окно прозрачности вокруг героя, если он зашёл за предмет
	s.material = occl_sprite
	add_node(s)
	if solid.x > 0.0 and solid.y > 0.0:
		var w := r.size.x * sc * sx * solid.x
		var h := r.size.y * sc * solid.y
		static_rect(base, Rect2(-w * 0.5, -h, w, h))
	return s


## Плоская мелочь на земле (под всеми объектами, без коллизии)
func gp_flat(name: String, pos: Vector2, sc := GP_S, z := -18) -> void:
	var s := Sprite2D.new()
	s.name = name.to_pascal_case()
	s.texture = gp_tex(name)
	s.position = pos
	s.scale = Vector2(sc, sc)
	s.flip_h = gp_rng.randf() < 0.5
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.z_index = z
	add_node(s)


## Свободно ли место под предмет: клетки не заняты дорожками, стенами,
## деревьями и уже поставленными предметами
func gp_area_free(c: Vector2i, half_w: int, h: int) -> bool:
	for y in range(c.y - h + 1, c.y + 1):
		for x in range(c.x - half_w, c.x + half_w + 1):
			var q := Vector2i(x, y)
			if not in_map(q) or reserved.has(q) or blocked.has(q):
				return false
			for l in objs:
				if l.get_cell_source_id(q) != -1:
					return false
	return true


func gp_block(c: Vector2i, half_w: int, h: int) -> void:
	for y in range(c.y - h + 1, c.y + 1):
		for x in range(c.x - half_w, c.x + half_w + 1):
			blocked[Vector2i(x, y)] = true


## Случайный предмет (куст, камень) в клетке c, если там свободно
func gp_scatter(name: String, c: Vector2i, solid := Vector2.ZERO) -> void:
	var r: Rect2 = GP_SPR[name]
	var half_w := maxi(0, int(r.size.x * GP_S / T / 2.0))
	var h := maxi(1, int(ceil(r.size.y * GP_S * 0.5 / T)))
	if not gp_area_free(c, half_w, h):
		return
	gp_block(c, half_w, h)
	gp_prop(name, Vector2(c.x * T + T * 0.5, (c.y + 1) * T - 2), GP_S, solid, gp_rng.randf() < 0.5)


## Предмет стоянки/двора: ставится в мир и не даёт лесу и мелочи вырасти
## поверх (blocked проверяется уже после трат основного rng)
func gp_place(name: String, base: Vector2, sc := GP_S, solid := Vector2(0.7, 0.3), flip := false) -> void:
	var r: Rect2 = GP_SPR[name]
	var c := Vector2i(int(base.x / T), int(base.y / T))
	gp_block(c, int(r.size.x * sc / T / 2.0) + 1, int(ceil(r.size.y * sc / T)) + 1)
	gp_prop(name, base, sc, solid, flip)


# ---------- ограды

const STONE_H := ["stone_a", "stone_b", "stone_c", "stone_d"]
const PAL_H := ["pal_a", "pal_b", "pal_c", "pal_d", "pal_e"]
## Высота кладки ~ 29 px и частокола ~ 32 px — как у прежних стен в две клетки
const STONE_SC := 0.62
const PAL_SC := 0.46


## Участок горизонтальной ограды из клеток xa..xb (ряды y, y+1): секции
## подряд, последняя подбирается по остатку, все вместе чуть растягиваются
## ровно под длину участка
func wall_run_h(xa: int, xb: int, y: int, style: String) -> void:
	var pool: Array = PAL_H if style == "palisade" else STONE_H
	var sc := PAL_SC if style == "palisade" else STONE_SC
	var length := float(xb - xa + 1) * T
	var pieces := []
	var total := 0.0
	var max_w := 0.0
	for p in pool:
		max_w = maxf(max_w, (GP_SPR[p] as Rect2).size.x * sc)
	while length - total > max_w:
		var p: String = pool[gp_rng.randi() % pool.size()]
		pieces.append(p)
		total += (GP_SPR[p] as Rect2).size.x * sc
	var rest := length - total
	var best := ""
	var best_d := rest
	for p in pool:
		var d := absf(rest - (GP_SPR[p] as Rect2).size.x * sc)
		if d < best_d:
			best_d = d
			best = p
	if best != "":
		pieces.append(best)
		total += (GP_SPR[best] as Rect2).size.x * sc
	var sx := length / total
	var x := float(xa * T)
	var base_y := float((y + 2) * T)
	for p in pieces:
		var w := (GP_SPR[p] as Rect2).size.x * sc * sx
		gp_prop(p, Vector2(x + w * 0.5, base_y), sc, Vector2.ZERO, gp_rng.randf() < 0.5, sx)
		x += w
	static_rect(Vector2.ZERO, Rect2(xa * T, y * T + 4, length, 2 * T - 4))


## Участок вертикальной ограды: столб кладки нарезан полосами по клетке —
## каждая сортируется по своему низу, как прежние тайлы стены
func wall_run_v(x: int, ya: int, yb: int) -> void:
	var r: Rect2 = GP_SPR["stone_v"]
	var slice := T / STONE_SC
	var cx := x * T + T * 0.5
	for yy in range(ya, yb + 1):
		var top := r.position.y + slice * (1 + (yy - ya) % 3)
		if yy == ya:
			top = r.position.y
		elif yy == yb:
			top = r.end.y - slice
		var at := AtlasTexture.new()
		at.atlas = load(GP)
		at.region = Rect2(r.position.x, top, r.size.x, slice)
		var s := Sprite2D.new()
		s.name = "StoneV"
		s.texture = at
		s.centered = false
		s.offset = Vector2(-r.size.x * 0.5, -slice)
		s.scale = Vector2(STONE_SC, STONE_SC)
		s.position = Vector2(cx, (yy + 1) * T)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.material = occl_sprite
		add_node(s)
	static_rect(Vector2.ZERO, Rect2(x * T + 2, ya * T, T - 4, (yb - ya + 1) * T))


# ---------- земля: бесшовные текстуры из квадратов листа

## Квадраты листа (без рваной кромки): трава, трава с цветами, земля, камень
const GP_GRASS := [Rect2(27, 28, 58, 60), Rect2(120, 28, 62, 60), Rect2(28, 119, 58, 60)]
const GP_FLOWERS := [Rect2(215, 27, 61, 59), Rect2(307, 27, 56, 59), Rect2(121, 119, 61, 59), Rect2(215, 119, 61, 59)]
const GP_DIRT := [Rect2(309, 212, 51, 62), Rect2(309, 312, 51, 44), Rect2(600, 338, 125, 36), Rect2(492, 318, 66, 50)]
const GP_STONE := [Rect2(215, 311, 60, 150), Rect2(307, 392, 53, 68), Rect2(395, 391, 55, 69)]
const GP_TEX := 1024


func _gp_sheet_img() -> Image:
	if _gp_sheet == null:
		_gp_sheet = Image.load_from_file(ProjectSettings.globalize_path(GP))
		_gp_sheet.convert(Image.FORMAT_RGBA8)
	return _gp_sheet


## Бесшовная текстура "бомбардировкой": сотни случайных кусков квадратов с
## мягкими краями, повёрнутых и отражённых, вперемешку и с переносом через
## край — без сетки и швов, как сплошной газон или тропа
func gp_bomb(pool: Array, extra: Array, extra_chance: float, stamp_px: int, count: int, seed_v: int) -> ImageTexture:
	var sheet := _gp_sheet_img()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed_v
	# Подложка — средний цвет первого квадрата
	var avg := Color(0, 0, 0)
	var r0 := Rect2i(pool[0])
	for y in range(r0.position.y, r0.end.y, 3):
		for x in range(r0.position.x, r0.end.x, 3):
			avg += sheet.get_pixel(x, y)
	avg /= avg.a
	var img := Image.create(GP_TEX, GP_TEX, false, Image.FORMAT_RGBA8)
	img.fill(Color(avg.r, avg.g, avg.b, 1.0))
	# Заготовки кусков: случайный вырез, поворот/отражение, мягкая кромка
	var stamps := []
	for i in 48:
		var use_extra := not extra.is_empty() and i % int(round(1.0 / maxf(extra_chance, 0.01))) == 0
		var src: Rect2i = Rect2i(extra[rnd.randi() % extra.size()] if use_extra else pool[rnd.randi() % pool.size()])
		var sw := mini(stamp_px, src.size.x)
		var sh := mini(stamp_px, src.size.y)
		var ox := src.position.x + rnd.randi_range(0, src.size.x - sw)
		var oy := src.position.y + rnd.randi_range(0, src.size.y - sh)
		var st := sheet.get_region(Rect2i(ox, oy, sw, sh))
		if rnd.randf() < 0.5:
			st.flip_x()
		if rnd.randf() < 0.5:
			st.flip_y()
		if sw == sh and rnd.randf() < 0.5:
			st.rotate_90(CLOCKWISE)
		var f := minf(sw, sh) * 0.3
		for y in st.get_height():
			for x in st.get_width():
				var e := minf(minf(x, st.get_width() - 1 - x), minf(y, st.get_height() - 1 - y))
				var c := st.get_pixel(x, y)
				c.a = smoothstep(0.0, f, e) * (1.0 if c.a > 0.5 else 0.0)
				st.set_pixel(x, y, c)
		stamps.append(st)
	for i in count:
		var st: Image = stamps[rnd.randi() % stamps.size()]
		var px := rnd.randi_range(0, GP_TEX - 1)
		var py := rnd.randi_range(0, GP_TEX - 1)
		var full := Rect2i(Vector2i.ZERO, st.get_size())
		for dy in [0, -GP_TEX]:
			for dx in [0, -GP_TEX]:
				var p := Vector2i(px + dx, py + dy)
				if p.x + st.get_width() > 0 and p.y + st.get_height() > 0 and p.x < GP_TEX and p.y < GP_TEX:
					img.blend_rect(st, full, p)
	return ImageTexture.create_from_image(img)


func gp_save(tex: Texture2D, file: String) -> Texture2D:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GP_DIR))
	ResourceSaver.save(tex, GP_DIR + file)
	return ResourceLoader.load(GP_DIR + file, "", ResourceLoader.CACHE_MODE_REPLACE)


## Маска троп и площадок для шейдера: тексель на 8 px мира (по 2 на клетку),
## слегка размытая, чтобы края шли плавной кривой, а не лесенкой по клеткам
func gp_ground_mask() -> ImageTexture:
	var mw := W * 2
	var mh := H * 2
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	a.resize(mw * mh)
	b.resize(mw * mh)
	for c: Vector2i in gmask:
		var k: int = gmask[c]
		if not in_map(c):
			continue
		for q in 4:
			var i := (c.y * 2 + q / 2) * mw + c.x * 2 + q % 2
			a[i] = 1.0
			if k == 2:
				b[i] = 1.0
	for pass_i in 2:
		a = _box_blur(a, mw, mh)
		b = _box_blur(b, mw, mh)
	var img := Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	for y in mh:
		for x in mw:
			img.set_pixel(x, y, Color(a[y * mw + x], b[y * mw + x], 0.0, 1.0))
	return ImageTexture.create_from_image(img)


func _box_blur(src: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			var n := 0
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					s += src[yy * w + xx]
					n += 1
			out[y * w + x] = s / n
	return out


# ---------- новые места: стоянки, двор, ворота, могильщик

## Ставится ДО леса: занятые клетки (blocked) лес обходит, поэтому поляны у
## костров становятся просторнее, а раскладка остальной карты не меняется
func gp_places(ruin_base: Vector2) -> void:
	# Предметы стоянок чуть крупнее мелочи — их должно быть видно издалека
	var CS := 0.52
	var fire := func(i: int) -> Vector2: return world(R(CAMPFIRES[i].x, CAMPFIRES[i].y))
	# Роща на северо-западе — стоянка могильщиков: палатка, спальник и
	# бревно у одного костра, котелок и дрова у второго, скамья у третьего
	var a: Vector2 = fire.call(0)
	_clear_circle(a, 6)
	gp_place("tent_white", a + Vector2(-62, -10), 0.85, Vector2(0.75, 0.55))
	gp_place("bedroll_white", a + Vector2(34, 8), CS, Vector2.ZERO)
	gp_place("log_bench", a + Vector2(2, 34), CS, Vector2(0.9, 0.6))
	var b: Vector2 = fire.call(1)
	_clear_circle(b, 5)
	gp_place("pot_stand", b + Vector2(40, 10), CS, Vector2(0.8, 0.3))
	gp_place("woodpile", b + Vector2(-44, 12), CS, Vector2(0.9, 0.5))
	gp_place("bucket", b + Vector2(22, 30), CS, Vector2.ZERO)
	var c: Vector2 = fire.call(2)
	_clear_circle(c, 4)
	gp_place("log_bench2", c + Vector2(0, 32), CS, Vector2(0.9, 0.6))
	gp_place("barrel_small", c + Vector2(34, -4), CS)
	# Юго-восток — дозорный пост у двух костров: палатка, припасы, спальник
	var d: Vector2 = fire.call(3)
	_clear_circle(d, 6)
	gp_place("tent_red", d + Vector2(-8, -44), 0.75, Vector2(0.75, 0.5))
	gp_place("crate_stack", d + Vector2(-50, 0), CS)
	gp_place("barrel", d + Vector2(-40, 22), CS)
	var e: Vector2 = fire.call(4)
	_clear_circle(e, 4)
	gp_place("bedroll_red", e + Vector2(36, 8), CS, Vector2.ZERO)
	gp_place("log_bench", e + Vector2(0, 32), CS, Vector2(0.9, 0.6))
	# Юго-запад — костёр у руин: просто бревно и охапка дров
	var f: Vector2 = fire.call(5)
	_clear_circle(f, 4)
	gp_place("log_bench2", f + Vector2(0, 30), CS, Vector2(0.9, 0.6))
	gp_place("firewood", f + Vector2(34, 2), CS)
	# Двор разрушенного дома: колодец и поленница у стены
	gp_place("well", ruin_base + Vector2(196, 112), 0.65, Vector2(0.8, 0.55))
	gp_place("woodpile", ruin_base + Vector2(-208, 84), CS, Vector2(0.9, 0.5))
	gp_place("bucket", ruin_base + Vector2(226, 118), CS, Vector2.ZERO)
	# Главные ворота в южном частоколе (к ним выходит тропа от старта) — флаги
	var gx0 := RX(912) * T
	var gx1 := (RX(945) + 1) * T
	var gy := (RY(622) + 2) * T + 2
	gp_place("banner_red", Vector2(gx0 - 10, gy), CS, Vector2(0.4, 0.15))
	gp_place("banner_red2", Vector2(gx1 + 10, gy), CS, Vector2(0.4, 0.15))
	# Могильщик оставил тачку и косу у ограды старого кладбища
	var g := world(R(1003, 345))
	gp_place("handcart", g + Vector2(-26, 0), CS, Vector2(0.8, 0.45))
	gp_place("scythe", g + Vector2(12, -2), CS, Vector2(0.3, 0.15))


func _clear_circle(center: Vector2, rad: int) -> void:
	var c := Vector2i(int(center.x / T), int(center.y / T))
	for y in range(-rad, rad + 1):
		for x in range(-rad, rad + 1):
			if Vector2(x, y * 1.2).length() <= rad:
				blocked[c + Vector2i(x, y)] = true


## Товар торговца рядом с его фургоном (магазин ставится в finish_scene)
func gp_shop_goods(shop_rect: Rect2) -> void:
	var r := shop_rect
	gp_prop("crate_stack", Vector2(r.end.x + 18, r.end.y - 6), 0.52)
	gp_prop("barrel", Vector2(r.end.x + 46, r.end.y - 2), 0.52)
	gp_prop("sack_cart", Vector2(r.position.x - 30, r.end.y - 2), 0.52, Vector2(0.8, 0.35))


# ============================================================ ОКНО ПРОЗРАЧНОСТИ

## Тайловые слои объектов (деревья, могилы, старые стены) сортируются по
## глубине потайлово: у каждой клетки своё основание (y_sort_origin тайла).
## Шейдер окна (Shaders/occlusion_fade.gdshaderinc, режим 2) должен его знать,
## чтобы делать предмет прозрачным только когда тот рисуется поверх игрока.
## Для каждого слоя — карта W x H: R = (y_sort_origin + 32) / 255
func occlusion_base_maps() -> void:
	for i in objs.size():
		var l := objs[i]
		var img := Image.create(W, H, false, Image.FORMAT_R8)
		for c: Vector2i in l.get_used_cells():
			if not in_map(c):
				continue
			var td := l.get_cell_tile_data(c)
			var v := clampi(td.y_sort_origin + 32, 0, 255) if td else 32
			img.set_pixel(c.x, c.y, Color(v / 255.0, 0, 0))
		var tex := gp_save(ImageTexture.create_from_image(img), "occlusion_base_%d.res" % (i + 1))
		var m: ShaderMaterial = l.material.duplicate()
		m.set_shader_parameter("occlusion_depth_mode", 2)
		m.set_shader_parameter("occlusion_base_map", tex)
		m.set_shader_parameter("occlusion_cell", float(T))
		l.material = m


# ============================================================ PREFABS (факел, костёр)

func build_fire_scene(campfire: bool) -> PackedScene:
	var n := Node2D.new()
	n.name = "Campfire" if campfire else "Torch"
	n.set_script(load("res://Levels/props/fire_flicker.gd"))
	var flame_y := -6.0 if campfire else -27.0
	if not campfire:
		var post := Sprite2D.new()
		post.name = "Post"
		var at := AtlasTexture.new()
		at.atlas = load(ATLASES["ef"])
		at.region = Rect2(25 * T, 27 * T, T, 2 * T)
		post.texture = at
		post.offset = Vector2(0, -T)
		n.add_child(post)
		post.owner = n
		var body := StaticBody2D.new()
		body.name = "Body"
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 4.0
		cs.shape = sh
		body.add_child(cs)
		n.add_child(body)
		body.owner = n
		cs.owner = n
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var glow := AnimatedSprite2D.new()
	glow.name = "Glow"
	glow.sprite_frames = frames_from_strip("res://TileMap/Textures Of Light/32x32/animation/1.png", 32, 32, 10, 12.0)
	glow.autoplay = "default"
	glow.material = add_mat
	glow.modulate = Color(1.9, 0.85, 0.3, 0.95)
	glow.position = Vector2(0, flame_y)
	glow.scale = Vector2.ONE * (0.9 if campfire else 0.45)
	glow.z_index = 1
	n.add_child(glow)
	glow.owner = n
	var emb := GPUParticles2D.new()
	emb.name = "Embers"
	emb.position = Vector2(0, flame_y - 2)
	emb.amount = 10 if campfire else 5
	emb.lifetime = 1.6
	emb.material = add_mat
	emb.z_index = 1
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -12, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0 if campfire else 1.5
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.35, 0.1, 0.8), Color(0.6, 0.1, 0.05, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	emb.process_material = pm
	var dot_g := Gradient.new()
	dot_g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var dot := GradientTexture2D.new()
	dot.gradient = dot_g
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 4
	dot.height = 4
	emb.texture = dot
	n.add_child(emb)
	emb.owner = n
	var l := PointLight2D.new()
	l.name = "Light"
	l.position = Vector2(0, flame_y)
	l.color = Color(1.0, 0.5, 0.2)
	l.energy = 1.05 if campfire else 0.9
	l.texture = radial_tex(256)
	l.texture_scale = 1.25 if campfire else 0.9
	l.blend_mode = Light2D.BLEND_MODE_ADD
	fire_shadow(l)
	n.add_child(l)
	l.owner = n
	# Копия света без тени — только для тела персонажа (слой 8, см.
	# player_spawner.gd): иначе огонь ниже персонажа клал бы тень на него самого
	var bl := l.duplicate() as PointLight2D
	bl.name = "BodyLight"
	bl.shadow_enabled = false
	bl.range_item_cull_mask = 8
	n.add_child(bl)
	bl.owner = n
	n.set("base_energy", l.energy)
	var ps := PackedScene.new()
	ps.pack(n)
	var path := "res://Levels/props/campfire.tscn" if campfire else "res://Levels/props/torch.tscn"
	ResourceSaver.save(ps, path)
	n.free()
	return load(path)


# ============================================================ LAYOUT

func _initialize() -> void:
	rng.seed = 1768889
	gp_rng.seed = 5150
	build_tileset()
	STAMPS = ST.duplicate(true)
	DARK_TREES = detect_trees("tree_dark", "dark")
	AUTUMN_TREES = detect_trees("tree_autumn", "autumn")
	# Светлоствольные из тёмного листа — для лунного сада
	for i in [2, 6, 7, 8]:
		if i < DARK_TREES.size():
			PALE_TREES.append(DARK_TREES[i])
	torch_scene = build_fire_scene(false)
	campfire_scene = build_fire_scene(true)

	lvl = load("res://Levels/level_01.tscn").instantiate()
	lvl.name = "LevelGraveyard"
	lvl.y_sort_enabled = true
	# Убираем всё, что завязано на геометрию старой карты
	for n in ["Forest", "TileMapLayer", "TileMap_Walls", "TileMap_Props", "SpawnBoss", "fontan2", "fontan3", "StairsLevel01"]:
		var node := lvl.get_node_or_null(n)
		if node:
			lvl.remove_child(node)
			node.free()
	for ch in lvl.get_children():
		if ch.name.begins_with("Enemy") and ch.name != "EnemySpawner":
			lvl.remove_child(ch)
			ch.free()
	for ch in lvl.get_node("DirectionalLight2D").get_children():
		if ch is PointLight2D:
			ch.get_parent().remove_child(ch)
			ch.free()

	# Старая трава (16px) рисуется по-прежнему — ради неизменного потока rng —
	# но в сцену не попадает: в конце её заменяет build_ground() (32px, TileMap/ground)
	ground = make_layer("OldGround16", -30, false)
	detail = make_layer("GroundDetail", -19, false)
	var occl: ShaderMaterial = load("res://Shaders/occlusion_fade_material.tres").duplicate()
	occl.set_shader_parameter("object_brightness", 1.15)
	occl_sprite = occl.duplicate()
	occl_sprite.set_shader_parameter("occlusion_depth_mode", 1)
	for i in 6:
		var l := make_layer("Objects%d" % (i + 1), 0, true)
		l.material = occl
		objs.append(l)

	paint_grass()
	layout()
	finish_scene()
	build_ground()
	occlusion_base_maps()

	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	print("GEN pack: ", err)
	err = ResourceSaver.save(ps, OUT)
	print("GEN save: ", err, " -> ", OUT)
	quit()


func layout() -> void:
	# Место под магазин (фургон) и точку старта — до деревьев и декора
	reserve_rect(Rect2i(R(985, 690), Vector2i(17, 9)))
	reserve_circle(R(930, 705), 3.0)
	# ---------- дорожки и площадки (сначала: резервируют клетки под лес/декор)
	paint_path([R(1155, 250), R(1155, 300), R(1125, 380), R(1115, 470), R(1130, 560), R(1132, 650)], 1.4)   # от часовни на юг
	paint_path([R(110, 660), R(500, 660), R(700, 660), R(1000, 662), R(1400, 660), R(1700, 660)], 1.3)       # дорога вдоль южной стены
	paint_path([R(930, 640), R(930, 700), R(860, 730)], 1.2)                                                    # к алтарю
	paint_path([R(675, 120), R(675, 200), R(720, 300), R(700, 400), R(630, 520), R(565, 560)], 1.1)           # от длинного дома к фонтану
	paint_path([R(1020, 400), R(1200, 410), R(1330, 470), R(1395, 485)], 1.0)                                    # к лунному саду
	paint_path([R(330, 470), R(470, 500), R(620, 500)], 0.9)
	paint_plaza(Rect2i(R(1085, 205), R(1225, 245) - R(1085, 205)))      # двор часовни
	paint_plaza(Rect2i(R(735, 655), R(885, 780) - R(735, 655)))         # площадь алтаря
	paint_plaza(Rect2i(R(1395, 385), R(1575, 585) - R(1395, 385)))      # лунный сад

	# ---------- здания
	# Дома из TileMap/Houses — цельные картинки. body — корпус дома в долях
	# картинки (коллизия), base_y — низ стен (точка сортировки по глубине)
	# В оба дома можно зайти: коллизию корпуса заменяют стены интерьера
	# Дома увеличены, чтобы внутри было где развернуться: амбар в ~1.45 раза,
	# разрушенный дом в ~1.7 (в нём зал с лестницей и ещё две комнаты под
	# левым крылом). Разрушенный дом опущен (крыша иначе уходила за верх
	# карты) и сдвинут влево от ограды кладбища, амбар поднят (снизу ряд
	# могил). Последний аргумент — прежнее место и масштаб
	var ruin_base := Vector2(RX(675) * T - 60, 330)
	var ruin_sc := 0.36
	var ruin_body := house_sprite("RuinHouse", "res://TileMap/Houses/ruin_house.png", ruin_base, ruin_sc, Rect2(0.06, 0.25, 0.89, 0.51), 0.76, false,
			[Vector2(RX(675) * T, 232), 0.21])
	var barn_base := Vector2(2680, 412)
	var barn_sc := 0.29
	var barn_body := house_sprite("Barn", "res://TileMap/Houses/barn.png", barn_base, barn_sc, Rect2(0.12, 0.3, 0.68, 0.5), 0.8, false,
			[Vector2(2680, 464), 0.2])
	build_interiors(ruin_base, ruin_sc, ruin_body, barn_base, barn_sc, barn_body)

	# Часовня убрана по просьбе. Место оставлено зарезервированным — иначе
	# поменялся бы поток случайных чисел и сдвинулась бы вся остальная карта
	var chapel_base := R(1155, 212)
	reserve_rect(Rect2i(chapel_base.x - 9, chapel_base.y - 18, 18, 20))

	# Дом в средней стене (кладка с тремя окошками) убран по просьбе — место
	# зарезервировано как было, чтобы не сдвинулась остальная карта
	reserve_rect(Rect2i(RX(720), RY(458), RX(885) - RX(720) + 1, 4))
	reserve_rect(Rect2i(RX(720) - 1, RY(458) + 4, RX(885) - RX(720) + 3, 1))
	wall_block(RX(1185), RX(1245), RY(518), false)                # сторожка
	wall_block(RX(1250), RX(1380), RY(636))                       # склеп у южной стены

	# ---------- стены (ограды участков)
	h_wall(RX(835), RX(1000), RY(92), [[RX(905), RX(925)]])
	v_wall(RX(770), RY(185), RY(335))
	v_wall(RX(1000), RY(92), RY(190))
	v_wall(RX(1310), RY(150), RY(350), [[RY(250), RY(270)]])
	h_wall(RX(1310), RX(1600), RY(350), [[RX(1440), RX(1465)]])
	h_wall(RX(380), RX(625), RY(345), [[RX(495), RX(520)]])
	v_wall(RX(625), RY(345), RY(470))
	v_wall(RX(375), RY(345), RY(470), [[RY(395), RY(420)]])
	h_wall(RX(225), RX(330), RY(398))
	v_wall(RX(225), RY(398), RY(612), [[RY(480), RY(515)]])
	h_wall(RX(886), RX(1085), RY(465), [[RX(1095), RX(1140)]])
	v_wall(RX(1215), RY(380), RY(470))
	h_wall(RX(900), RX(1035), RY(395))
	h_wall(RX(1078), RX(1240), RY(240), [[RX(1140), RX(1170)]])
	# лунный сад
	h_wall(RX(1390), RX(1580), RY(378))
	h_wall(RX(1390), RX(1580), RY(592), [[RX(1465), RX(1500)]])
	v_wall(RX(1390), RY(378), RY(592), [[RY(470), RY(505)]])
	v_wall(RX(1580), RY(378), RY(592))
	# южная граница — частокол (остальные ограды — каменная кладка)
	h_wall(RX(100), RX(1700), RY(622), [[RX(505), RX(620)], [RX(825), RX(860)], [RX(912), RX(945)], [RX(1115), RX(1150)]], "palisade")
	# руины на юго-западе
	v_wall(RX(290), RY(680), RY(790), [[RY(720), RY(740)]])
	h_wall(RX(290), RX(335), RY(680))

	# ---------- пруд, фонтан, алтарь (всё убрано)
	# Пруд убран (не подошёл для игры). На его месте — поляна, а вызовы rng,
	# которые раньше тратил пруд (камешки по берегу), сохранены вхолостую:
	# иначе сдвинулся бы весь случайный поток и поменялась бы вся остальная карта
	reserve_circle(R(765, 400), 9.0)
	for i in 14:
		rng.randf()
		rng.randi()
	# Фонтан убран по просьбе. Его место остаётся зарезервированным — иначе
	# сдвинулся бы поток случайных чисел и поменялась бы вся остальная карта;
	# на месте фонтана теперь просто поляна, куда выходит тропа
	reserve_rect(Rect2i(R(565, 612) - Vector2i(6, 8), Vector2i(12, 9)))

	# Алтарь убран по просьбе — на его месте осталась мощёная площадка

	# ---------- кладбищенские ряды
	grave_rows(Rect2i(R(790, 120), R(990, 330) - R(790, 120)), 3, 4, 0.82)
	grave_rows(Rect2i(R(1015, 270), R(1300, 335) - R(1015, 270)), 3, 4, 0.7)
	grave_rows(Rect2i(R(400, 365), R(610, 455) - R(400, 365)), 3, 4, 0.7)
	grave_rows(Rect2i(R(240, 420), R(320, 600) - R(240, 420)), 3, 5, 0.5)
	grave_rows(Rect2i(R(1330, 270), R(1600, 340) - R(1330, 270)), 4, 4, 0.55)
	grave_rows(Rect2i(R(1250, 540), R(1370, 610) - R(1250, 540)), 3, 4, 0.55)
	stamp("statue", R(880, 175))
	stamp("statue", R(1236, 300))
	stamp("sarcophagus", R(950, 260))
	stamp("sarcophagus", R(500, 410))
	stamp("pillar", R(1100, 470))
	stamp("pillar", R(1150, 470))
	stamp("pillar_broken", R(830, 625))
	stamp("pillar", R(870, 625))
	stamp("runestone", R(1040, 410))

	# ---------- лунный сад: белые берёзы, мёртвое дерево, могилы
	for p in [R(1420, 430), R(1555, 560), R(1500, 455), R(1540, 420), R(1430, 585)]:
		stamp(PALE_TREES[rng.randi() % PALE_TREES.size()], p)
	for p in [R(1450, 540), R(1565, 485)]:
		stamp("stump2", p)
	for p in [R(1470, 420), R(1525, 500), R(1420, 500), R(1545, 470)]:
		stamp(["grave_cross", "grave_round", "grave_small"][rng.randi() % 3], p)
	# Лунные лучи — только там, где есть открытое небо; основной лунный свет
	# даёт Moonlight (тени облаков, см. finish_scene). Над рощей с кострами и
	# у южной дороги лучей нет: пять одинаковых столбов читались как прожекторы
	moon_rays(world(R(1485, 470)) + Vector2(97, 241), 420.0, 0.5)    # лунный сад
	moon_rays(world(R(900, 230)) + Vector2(86, 213), 340.0, 0.32)    # кладбище у часовни
	moon_rays(world(R(760, 410)) + Vector2(82, 204), 320.0, 0.3)     # поляна (бывший пруд)

	# ---------- отдельные деревья внутри участков
	for p in [R(420, 370), R(565, 385), R(600, 430), R(745, 345), R(905, 480), R(870, 575), R(1080, 560), R(1040, 385), R(1240, 575), R(1330, 445), R(1420, 650), R(340, 560), R(180, 470), R(660, 560)]:
		stamp(rand_tree(0.3), p)
	for i in 26:
		var p := Vector2i(rng.randi_range(play_rect.position.x, play_rect.end.x), rng.randi_range(RY(640), play_rect.end.y))
		var kind: String = ["stump", "stump2", "rock_big"][rng.randi() % 3] if rng.randf() < 0.4 else rand_tree(0.1)
		# Большой камень — из листа ground_&_props, пни остаются прежние
		if kind == "rock_big":
			gp_scatter("rock_%d" % gp_rng.randi_range(1, 6), p, Vector2(0.7, 0.4))
		else:
			stamp(kind, p, true)

	# ---------- лес по краям и в северо-западной роще (поляны под костры — заранее)
	for p in CAMPFIRES:
		reserve_circle(R(p.x, p.y), 3.5)
	# Стоянки у костров, двор дома, ворота — до леса, чтобы он их обходил
	gp_places(ruin_base)
	forest()

	# ---------- мелочь на земле
	for i in 900:
		var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		if not reserved.has(c):
			decal("tuft", c)
	for i in 140:
		var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		decal("pebble", c)
	for i in 12:
		var c := Vector2i(rng.randi_range(RX(790), RX(1300)), rng.randi_range(RY(120), RY(340)))
		decal("skull", c)
	for i in 25:
		var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		decal("mushroom", c)
	for i in 70:
		var c := Vector2i(rng.randi_range(play_rect.position.x, play_rect.end.x), rng.randi_range(play_rect.position.y, play_rect.end.y))
		# Кусты из листа ground_&_props; rng тратится как раньше (выбор из 5)
		rng.randi()
		var bush := "bush_%d" % gp_rng.randi_range(1, 10)
		gp_scatter(bush, c, Vector2(0.6, 0.3) if bush in ["bush_2", "bush_5", "bush_7"] else Vector2.ZERO)

	# ---------- костры (факелы убраны — свет на карте теперь даёт луна)
	for p in CAMPFIRES:
		torch(world(R(p.x, p.y)), "campfire")


func grave_rows(r: Rect2i, sx: int, sy: int, fill: float) -> void:
	var kinds := ["slab", "slab_tall", "grave_round", "grave_rip", "grave_cross", "grave_small", "grave_block", "broken_slab", "broken_slab2", "coffin_up"]
	var y := r.position.y + sy - 1
	while y < r.end.y:
		var x := r.position.x + 1
		while x < r.end.x:
			if rng.randf() < fill:
				stamp(kinds[rng.randi() % kinds.size()], Vector2i(x + rng.randi_range(0, 1), y), true)
				if rng.randf() < 0.15:
					decal("skull", Vector2i(x, y + 1))
			x += sx
		y += sy


# Густота леса в клетке: кольцо по краю карты + рощи с референса
func forest_density(c: Vector2i) -> float:
	var d := 0.0
	var edge := mini(mini(c.x - play_rect.position.x, play_rect.end.x - c.x), mini(c.y - play_rect.position.y, play_rect.end.y - c.y))
	if edge < 0:
		d = 1.0
	elif edge < 4:
		d = 0.75 - edge * 0.12
	var zones := [
		[Rect2i(R(0, 0), R(540, 335)), 0.85],      # северо-западная роща
		[Rect2i(R(790, 0), R(1080, 75) - R(790, 0)), 0.45],
		[Rect2i(R(1250, 0), R(1768, 215) - R(1250, 0)), 0.75],
		[Rect2i(R(1600, 200), R(1768, 889) - R(1600, 200)), 0.9],
		[Rect2i(R(0, 330), R(150, 889) - R(0, 330)), 0.85],
		[Rect2i(R(0, 640), R(320, 889) - R(0, 640)), 0.6],
		[Rect2i(R(1400, 640), R(1768, 889) - R(1400, 640)), 0.7],
		[Rect2i(R(320, 790), R(1400, 889) - R(320, 790)), 0.35],
	]
	for z in zones:
		if (z[0] as Rect2i).has_point(c):
			d = maxf(d, z[1])
	return d


func forest() -> void:
	# Деревья из TileMap/Trees крупные (5-8 клеток), шаг решётки под них шире;
	# несколько смещённых решёток в разных слоях дают сплошную стену крон
	var offsets := [Vector2i(0, 0), Vector2i(2, 3), Vector2i(4, 1), Vector2i(1, 4), Vector2i(3, 2)]
	for k in offsets.size():
		var y: int = -1 + offsets[k].y
		while y < H + 5:
			var x: int = -2 + offsets[k].x
			while x < W + 3:
				var c := Vector2i(x + rng.randi_range(-1, 1), y + rng.randi_range(0, 1))
				var cc := Vector2i(clampi(c.x, 0, W - 1), clampi(c.y, 0, H - 1))
				var dens := forest_density(cc)
				if dens > 0.0 and rng.randf() < dens and not reserved.has(cc):
					stamp(rand_tree(0.12), c, true)
				x += 5
			y += 5


func finish_scene() -> void:
	# Дождь уровня (Levels/rain_system.gd) — сам находит камеру героя; раньше
	# капли были только на камере рыцаря
	if lvl.get_node_or_null("RainSystem") == null:
		var rain := Node2D.new()
		rain.name = "RainSystem"
		rain.set_script(load("res://Levels/rain_system.gd"))
		lvl.add_child(rain)
		rain.owner = lvl
	# Ночь: тёмная общая подсветка + слабый холодный "лунный" свет; всё яркое
	# на карте даёт огонь (факелы/костры) и холодное свечение лунного сада
	var cm: CanvasModulate = lvl.get_node("NightModulate")
	cm.visible = true
	# 2026-10-21: чуть ярче по просьбе игрока (было 0.24, 0.27, 0.29) — средняя
	# яркость кадра +40%, ночь и холодный тон остались
	cm.color = Color(0.325, 0.365, 0.39)
	var moon: DirectionalLight2D = lvl.get_node("DirectionalLight2D")
	moon.color = Color(0.55, 0.65, 0.8)
	# Ровная подсветка совсем слабая — это свет, рассеянный облаками. Сама луна
	# светит пятнами сквозь разрывы облаков (Moonlight ниже)
	moon.energy = 0.08
	moon.blend_mode = Light2D.BLEND_MODE_ADD
	moon.shadow_enabled = false
	moon.set("night_energy", 0.08)
	moon.add_to_group("outdoor_light", true)
	var moonlight := Node2D.new()
	moonlight.name = "Moonlight"
	moonlight.set_script(load("res://Levels/moonlight.gd"))
	moonlight.set("area", Rect2(0, 0, W * T, H * T))
	add_node(moonlight)
	# Земля темнее и холоднее: трава в атласе ярко-оливковая, а на референсе
	# почва почти чёрная
	ground.modulate = Color(0.52, 0.58, 0.54)
	detail.modulate = Color(0.6, 0.64, 0.6)

	var grade: CanvasLayer = lvl.get_node("AtmosphereGrade")
	grade.get_node("ColorRect").visible = true
	grade.set("desaturation", 0.3)
	grade.set("contrast", 1.1)
	grade.set("shadow_tint", Color(0.82, 0.9, 0.95))
	grade.set("vignette_strength", 0.55)
	grade.set("vignette_radius", 0.95)

	# Туман убран по просьбе (был Polygon2D с Shaders/fog.gdshader поверх мира)

	# Невидимая граница игровой зоны (за ней — лес и туман)
	var pr_px := Rect2(Vector2((play_rect.position - Vector2i(2, 2)) * T), Vector2((play_rect.size + Vector2i(4, 4)) * T))
	static_rect(Vector2.ZERO, Rect2(pr_px.position.x - 64, pr_px.position.y - 64, pr_px.size.x + 128, 64))
	static_rect(Vector2.ZERO, Rect2(pr_px.position.x - 64, pr_px.end.y, pr_px.size.x + 128, 64))
	static_rect(Vector2.ZERO, Rect2(pr_px.position.x - 64, pr_px.position.y, 64, pr_px.size.y))
	static_rect(Vector2.ZERO, Rect2(pr_px.end.x, pr_px.position.y, 64, pr_px.size.y))

	# Навигация (запекается при старте, см. nav_mesh_baker.gd)
	var nav := NavigationRegion2D.new()
	nav.name = "NavigationRegion2D"
	nav.set_script(load("res://Levels/nav_mesh_baker.gd"))
	add_node(nav)
	var gl: Array[NodePath] = [NodePath("../Ground")]
	nav.set("ground_layers", gl)
	nav.set("cell_size", 4.0)
	nav.set("agent_radius", 14.0)

	# Игрок, магазин, враги
	var spawn: Marker2D = lvl.get_node("PlayerSpawn")
	spawn.position = world(R(930, 705))
	spawn.set("character_z_index", 0)
	spawn.set("player_glow_energy", 0.25)
	spawn.set("player_shadow", true)
	spawn.set("camera_limits", Rect2i(Vector2i(4, 2) * T, Vector2i(W - 8, H - 4) * T))
	var shop: Node2D = lvl.get_node("Shop")
	var shop_sprite: Sprite2D = shop.get_node("Shop")
	shop_sprite.z_index = 0
	shop.get_node("CollisionShop").z_index = 0
	shop.position = world(R(1060, 735)) - shop_sprite.position
	reserve_rect(Rect2i(R(1010, 700), Vector2i(12, 6)))
	# Фургон сортируется по глубине по точке узла Shop, а спрайт в нём сдвинут —
	# окну прозрачности сообщаем, где на самом деле его основание
	var shop_occl: ShaderMaterial = occl_sprite.duplicate()
	shop_occl.set_shader_parameter("occlusion_sort_offset", -shop_sprite.position.y)
	shop_sprite.material = shop_occl
	# Товар торговца — ящики, бочка и тележка с мешками у фургона
	var sr := shop_sprite.get_rect()
	gp_shop_goods(Rect2(shop.position + shop_sprite.position + sr.position * shop_sprite.scale, sr.size * shop_sprite.scale))

	# Враги кладбища — скелеты (enemy/location_cemetery): мясо, щитовики,
	# ловкий и танк с топором. Состав расставленных и пачек спавнера
	var sk := "res://enemy/location_cemetery/"
	var sk_grunt: PackedScene = load(sk + "default_skeleton/default_skeleton.tscn")
	var sk_shield: PackedScene = load(sk + "skeleton_shield_bag/skeleton_shield_bag.tscn")
	var sk_duelist: PackedScene = load(sk + "skeleton_dexterous/skeleton_dexterous.tscn")
	var sk_brute: PackedScene = load(sk + "axe_skeleton_2/axe_skeleton_2.tscn")
	var placed_kinds := [sk_shield, sk_grunt, sk_duelist, sk_grunt, sk_brute, sk_shield, sk_grunt, sk_grunt]
	var i := 0
	for p in [Vector2(950, 250), Vector2(1250, 300), Vector2(500, 420), Vector2(285, 530), Vector2(1000, 560), Vector2(1480, 480), Vector2(690, 730), Vector2(400, 260)]:
		var e: Node2D = placed_kinds[i].instantiate()
		e.name = "Enemy%d" % (i + 1)
		e.position = world(R(p.x, p.y))
		add_node(e)
		i += 1
	var sp := lvl.get_node("EnemySpawner")
	sp.enemy_scene = sk_grunt
	sp.enemy_scenes = [sk_grunt, sk_shield, sk_duelist, sk_brute] as Array[PackedScene]
	sp.enemy_weights = [6.0, 3.0, 1.2, 1.0] as Array[float]
	sp.enemy_pack_limits = [0, 2, 1, 1] as Array[int]

	# Лут как в Dark Souls (Levels/loot/loot_item.gd): светящиеся находки под
	# охраной скелетов. Координаты — мировые; находка сама встаёт на навмеш.
	# [имя, позиция, награда (0 — случайно, 1 — золото, 2 — способность, 3 — заклинание),
	#  золото от/до, охрана, [заклинание для награды 3]]
	var loot_scene: PackedScene = load("res://Levels/loot/loot_item.tscn")
	for L in [
		["LootCamp", Vector2(380, 230), 0, 40, 90, [sk_grunt, sk_grunt, sk_shield]],
		["LootGrove", Vector2(230, 500), 1, 40, 80, [sk_grunt, sk_grunt]],
		["LootCenter", Vector2(1460, 660), 2, 40, 90, [sk_duelist, sk_grunt]],
		["LootBarn", Vector2(2540, 500), 3, 40, 90, [sk_brute, sk_grunt], "Благословение Сурта"],
		["LootEast", Vector2(2430, 800), 0, 40, 90, [sk_shield, sk_shield, sk_grunt]],
		["LootSouthWest", Vector2(480, 1150), 1, 60, 120, [sk_grunt, sk_grunt, sk_grunt]],
	]:
		var loot: Node2D = loot_scene.instantiate()
		loot.name = L[0]
		loot.position = L[1]
		loot.reward = L[2]
		loot.gold_min = L[3]
		loot.gold_max = L[4]
		loot.guards.assign(L[5])
		if L.size() > 6:
			loot.spell_name = L[6]
		add_node(loot)
	var pts :=[Vector2(880, 220), Vector2(1200, 300), Vector2(470, 420), Vector2(270, 500), Vector2(1000, 540), Vector2(1470, 500), Vector2(1550, 720), Vector2(300, 720)]
	var k := 0
	for ch in sp.get_children():
		if k < pts.size():
			ch.position = world(R(pts[k].x, pts[k].y))
		k += 1
