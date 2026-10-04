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
			if check_reserved and reserved.has(mc):
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
	# Травинки и камешки старого атласа больше не ставим — их заменили декали
	# из TileMap/ground (см. build_ground). rng выше всё равно тратится, чтобы
	# не сдвинулась остальная случайная раскладка карты
	if kind == "tuft" or kind == "pebble":
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
	rng2.seed = 4242
	ts32 = TileSet.new()
	ts32.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	src.texture = load(GT)
	src.texture_region_size = Vector2i(32, 32)
	ts32.add_source(src, 0)

	var base := TileMapLayer.new()
	base.name = "Ground"
	base.tile_set = ts32
	base.z_index = -22
	var grass := TileMapLayer.new()
	grass.name = "GroundGrass"
	grass.tile_set = ts32
	grass.z_index = -21
	var decals := TileMapLayer.new()
	decals.name = "GroundDecals"
	decals.tile_set = ts32
	decals.z_index = -20
	for l in [base, grass, decals]:
		l.modulate = Color(0.8, 0.84, 0.8)
		add_node(l)

	var tw := W / 2
	var th := H / 2
	var kinds := {}
	for vy in th + 1:
		for vx in tw + 1:
			kinds[Vector2i(vx, vy)] = _vkind(vx, vy)

	for ty in th:
		for tx in tw:
			var c := Vector2i(tx, ty)
			var tl: int = kinds[Vector2i(tx, ty)]
			var tr: int = kinds[Vector2i(tx + 1, ty)]
			var bl: int = kinds[Vector2i(tx, ty + 1)]
			var br: int = kinds[Vector2i(tx + 1, ty + 1)]
			# Низ: булыжник, если площадка касается клетки, иначе земля
			var under := GT_COBBLE if 2 in [tl, tr, bl, br] else GT_DIRT
			_gtile(base, c, under + Vector2i(tx % 2, ty % 2))
			var bits := (8 if tl > 0 else 0) + (4 if tr > 0 else 0) + (2 if bl > 0 else 0) + (1 if br > 0 else 0)
			if bits == 0:
				# Сплошная трава: в основном ровная, изредка с камнями/проплешинами
				var roll := rng2.randf()
				var ac := Vector2i(rng2.randi_range(21, 26), rng2.randi_range(4, 6))
				if roll < 0.06:
					ac = Vector2i(rng2.randi_range(27, 29), rng2.randi_range(4, 6))
				elif roll < 0.11:
					ac = Vector2i(rng2.randi_range(30, 32), rng2.randi_range(4, 6))
				_gtile(grass, c, ac)
				# Декали поверх травы
				var d := rng2.randf()
				if d < 0.16:
					_gtile(decals, c, Vector2i(rng2.randi_range(21, 26), rng2.randi_range(16, 18)))
				elif d < 0.26:
					_gtile(decals, c, Vector2i(rng2.randi_range(21, 23), rng2.randi_range(20, 22)))
				elif d < 0.29:
					_gtile(decals, c, Vector2i(rng2.randi_range(27, 29), rng2.randi_range(16, 18)))
				elif d < 0.32:
					_gtile(decals, c, Vector2i(rng2.randi_range(30, 32), rng2.randi_range(16, 18)))
			elif GT_EDGE.has(bits):
				_gtile(grass, c, GT_EDGE[bits])
			# bits == 15 или диагональ (6, 9) — травы нет, видна земля/булыжник
			if bits != 0 and under == GT_DIRT and rng2.randf() < 0.3:
				_gtile(decals, c, Vector2i(rng2.randi_range(21, 26), rng2.randi_range(24, 26)))

	# Старая трава 16px больше не нужна
	ground.get_parent().remove_child(ground)
	ground.free()


# ============================================================ WALLS

# Горизонтальная стена: крышка (ряд 6) + кладка (ряд 9) атласа стен.
# gaps — массив [x0, x1] проёмов (ворот)
func h_wall(x0: int, x1: int, y: int, gaps := []) -> void:
	for x in range(x0, x1 + 1):
		var in_gap := false
		for g in gaps:
			if x >= g[0] and x <= g[1]:
				in_gap = true
		reserved[Vector2i(x, y)] = true
		reserved[Vector2i(x, y + 1)] = true
		reserved[Vector2i(x, y + 2)] = true
		if in_gap:
			continue
		var left := x == x0
		var right := x == x1
		for g in gaps:
			if x == g[0] - 1:
				right = true
			if x == g[1] + 1:
				left = true
		var col := 2 if left else (7 if right else 3 + (x % 4))
		_wall_tile(Vector2i(x, y), Vector2i(col, 6), T + 6)
		_wall_tile(Vector2i(x, y + 1), Vector2i(col, 9), 6)


func v_wall(x: int, y0: int, y1: int, gaps := []) -> void:
	for y in range(y0, y1 + 1):
		var in_gap := false
		for g in gaps:
			if y >= g[0] and y <= g[1]:
				in_gap = true
		reserved[Vector2i(x, y)] = true
		reserved[Vector2i(x + 1, y)] = true
		if in_gap:
			continue
		var top := y == y0
		var bottom := y == y1
		for g in gaps:
			if y == g[0] - 1:
				bottom = true
			if y == g[1] + 1:
				top = true
		var row := 2 if top else (7 if bottom else 3 + (y % 4))
		_wall_tile(Vector2i(x, y), Vector2i(18, row), 6, Rect2(-8, -8, 9, 16))


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
		stamp("stone_ring", Vector2i(int(px.x / T), int(px.y / T) + 1))


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
	add_node(s)


func house_sprite(name: String, path: String, base: Vector2, sc: float, body: Rect2, base_y: float) -> void:
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
	s.material = objs[0].material
	add_node(s)
	static_rect(base, Rect2((body.position.x - 0.5) * size.x * sc, (body.position.y - base_y) * size.y * sc,
			body.size.x * size.x * sc, body.size.y * size.y * sc))
	var tl := base + Vector2(-size.x * 0.5, -size.y * base_y) * sc
	reserve_rect(Rect2i(Vector2i(tl / T) - Vector2i.ONE, Vector2i(size * sc / T) + Vector2i(3, 3)))


func static_rect(px: Vector2, rect: Rect2) -> void:
	var b := StaticBody2D.new()
	b.position = px
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = rect.size
	cs.shape = sh
	cs.position = rect.get_center()
	b.add_child(cs)
	add_node(b)
	cs.owner = lvl


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
	n.add_child(l)
	l.owner = n
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
	for i in 6:
		var l := make_layer("Objects%d" % (i + 1), 0, true)
		l.material = occl
		objs.append(l)

	paint_grass()
	layout()
	finish_scene()
	build_ground()

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
	house_sprite("RuinHouse", "res://TileMap/Houses/ruin_house.png", Vector2(RX(675) * T, 232), 0.21, Rect2(0.06, 0.25, 0.89, 0.51), 0.76)
	house_sprite("Barn", "res://TileMap/Houses/barn.png", Vector2(2680, 464), 0.2, Rect2(0.12, 0.3, 0.68, 0.5), 0.8)

	# Часовня убрана по просьбе. Место оставлено зарезервированным — иначе
	# поменялся бы поток случайных чисел и сдвинулась бы вся остальная карта
	var chapel_base := R(1155, 212)
	reserve_rect(Rect2i(chapel_base.x - 9, chapel_base.y - 18, 18, 20))

	wall_block(RX(720), RX(885), RY(458))                         # дом в средней стене
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
	# южная граница
	h_wall(RX(100), RX(1700), RY(622), [[RX(505), RX(620)], [RX(825), RX(860)], [RX(912), RX(945)], [RX(1115), RX(1150)]])
	# руины на юго-западе
	v_wall(RX(290), RY(680), RY(790), [[RY(720), RY(740)]])
	h_wall(RX(290), RX(335), RY(680))

	# ---------- фонтан, алтарь
	# Пруд убран (не подошёл для игры). На его месте — поляна, а вызовы rng,
	# которые раньше тратил пруд (камешки по берегу), сохранены вхолостую:
	# иначе сдвинулся бы весь случайный поток и поменялась бы вся остальная карта
	reserve_circle(R(765, 400), 9.0)
	for i in 14:
		rng.randf()
		rng.randi()
	var fountain := AnimatedSprite2D.new()
	fountain.name = "Fountain"
	fountain.sprite_frames = frames_from_strip("res://TileMap/Props/shrine or fountain 160x128-on grass.png", 160, 128, 8, 6.0)
	fountain.autoplay = "default"
	fountain.centered = false
	fountain.offset = Vector2(-80, -122)
	fountain.position = world(R(565, 612))
	add_node(fountain)
	static_rect(fountain.position, Rect2(-62, -100, 124, 92))
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
	# Лунный свет — лучами, а не пятном. [центр, ширина, длина, яркость]
	moon_rays(world(R(1485, 470)) + Vector2(97, 241), 300.0, 0.42)   # лунный сад
	moon_rays(world(R(900, 230)) + Vector2(86, 213), 260.0, 0.3)     # кладбище у часовни
	moon_rays(world(R(420, 230)) + Vector2(79, 195), 220.0, 0.28)    # роща с кострами
	moon_rays(world(R(760, 410)) + Vector2(82, 204), 240.0, 0.3)     # поляна (бывший пруд)
	moon_rays(world(R(1250, 700)) + Vector2(82, 204), 240.0, 0.26)   # у южной дороги

	# ---------- отдельные деревья внутри участков
	for p in [R(420, 370), R(565, 385), R(600, 430), R(745, 345), R(905, 480), R(870, 575), R(1080, 560), R(1040, 385), R(1240, 575), R(1330, 445), R(1420, 650), R(340, 560), R(180, 470), R(660, 560)]:
		stamp(rand_tree(0.3), p)
	for i in 26:
		var p := Vector2i(rng.randi_range(play_rect.position.x, play_rect.end.x), rng.randi_range(RY(640), play_rect.end.y))
		var kind: String = ["stump", "stump2", "rock_big"][rng.randi() % 3] if rng.randf() < 0.4 else rand_tree(0.1)
		stamp(kind, p, true)

	# ---------- лес по краям и в северо-западной роще (поляны под костры — заранее)
	for p in CAMPFIRES:
		reserve_circle(R(p.x, p.y), 3.5)
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
		stamp(["bush1", "bush2", "bush3", "bush4", "bush5"][rng.randi() % 5], c, true)

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
	# Ночь: тёмная общая подсветка + слабый холодный "лунный" свет; всё яркое
	# на карте даёт огонь (факелы/костры) и холодное свечение лунного сада
	var cm: CanvasModulate = lvl.get_node("NightModulate")
	cm.visible = true
	cm.color = Color(0.24, 0.27, 0.29)
	var moon: DirectionalLight2D = lvl.get_node("DirectionalLight2D")
	moon.color = Color(0.55, 0.65, 0.8)
	moon.energy = 0.16
	moon.blend_mode = Light2D.BLEND_MODE_ADD
	moon.shadow_enabled = false
	moon.set("night_energy", 0.16)
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
	spawn.set("camera_limits", Rect2i(Vector2i(4, 2) * T, Vector2i(W - 8, H - 4) * T))
	var shop: Node2D = lvl.get_node("Shop")
	var shop_sprite: Sprite2D = shop.get_node("Shop")
	shop_sprite.z_index = 0
	shop.get_node("CollisionShop").z_index = 0
	shop.position = world(R(1060, 735)) - shop_sprite.position
	reserve_rect(Rect2i(R(1010, 700), Vector2i(12, 6)))

	var enemy_scene: PackedScene = load("res://enemy/Assets/enemy.tscn")
	var i := 0
	for p in [Vector2(950, 250), Vector2(1250, 300), Vector2(500, 420), Vector2(285, 530), Vector2(1000, 560), Vector2(1480, 480), Vector2(690, 730), Vector2(400, 260)]:
		var e: Node2D = enemy_scene.instantiate()
		e.name = "Enemy%d" % (i + 1)
		e.position = world(R(p.x, p.y))
		add_node(e)
		i += 1
	var sp := lvl.get_node("EnemySpawner")
	var pts := [Vector2(880, 220), Vector2(1200, 300), Vector2(470, 420), Vector2(270, 500), Vector2(1000, 540), Vector2(1470, 500), Vector2(1550, 720), Vector2(300, 720)]
	var k := 0
	for ch in sp.get_children():
		if k < pts.size():
			ch.position = world(R(pts[k].x, pts[k].y))
		k += 1
