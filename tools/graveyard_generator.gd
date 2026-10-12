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

const INTERIOR_TEX := "res://TileMap/interior/tile_interior.png"
## Лист интерьеров нарисован крупнее карты: при 0.5 кровать выходит ~в два
## роста персонажа, а дверной проём (~30 px) пропускает и игрока, и врагов
## (у навмеша отступ 14 — проём уже 28 px враг бы не прошёл)
const INT_S := 0.5
## Собранные интерьеры домов сохраняются сюда — сцена ссылается на них
const ROOMS_DIR := "res://TileMap/interior/rooms/"
## Чистые доски из листа — ими заделываются проёмы и застилается пол комнат,
## из которых убрана родная мебель
const FLOOR_SRC := Rect2(28, 332, 96, 220)
## Лестница из листа: перила по бокам, 6 ступеней; её середина (2 ступени)
## повторяется, чтобы пролёт стал длиннее
const STAIRS_SRC := Rect2(892, 207, 74, 108)
const STAIRS_MID := Vector2(226, 260)


## Интерьер дома — одна картинка из нескольких готовых комнат листа
## TileMap/interior/tile_interior.png (пол, стены, мебель нарисованы вместе).
##
## Комната (словарь), координаты — пиксели листа:
##   room    — комната (стены включительно), src — что вырезать (бывает чуть
##             больше комнаты: свисающие столбы)
##   at      — где левый верхний угол комнаты в "картинке дома" (пиксели листа;
##             у главной комнаты — 0, 0). Комнаты рисуются по порядку списка:
##             следующая перекрывает общую стену предыдущей
##   cols    — [x0, x1, n]: вертикальная полоса листа, которая повторяется ещё
##             n раз — так комната становится шире; rows [y0, y1, n] — то же
##             по высоте. Полосы выбраны там, где поперёк комнаты только стены
##             и пол (или то, что не страшно удлинить: скамья, ковёр) — мебель
##             не растягивается, в комнате просто больше места
##   col_alt — [[y0, y1, x]]: в копиях колонки строки y0..y1 брать с x (если
##             в самой колонке на этой высоте камин или столб); row_alt —
##             [[x0, x1, y]] — то же для копий ряда (тень под камином)
##   patches — [откуда, куда] кусок пола поверх стены: так прорезается входная
##             дверь (в листе стены комнат глухие)
##   floor   — прямоугольник, который застилается чистыми досками (FLOOR_SRC):
##             родная мебель комнаты убирается, ставится своя из items
##   items   — [откуда, куда] предметы листа поверх пола (с прозрачностью)
##   solids  — стены и мебель (коллизия), lights — [где, цвет, энергия, радиус
##             в мире, мерцает], fill — общий свет комнаты [цвет, энергия, мерцает]
##
## Дом (словарь): floors — этажи (первый — с входной дверью), main — номер
## комнаты с входной дверью в первом этаже, door_x/wall_y — середина проёма и
## низ нижней стены этой комнаты (пиксели листа): эта точка ставится на дверь
## спрайта снаружи (world_door).
##
## Этаж (словарь): rooms + в координатах "картинки дома" (у главной комнаты
## первого этажа угол 0, 0): doors — внутренние проёмы (застилаются досками),
## stairs — {at, repeat, down} лестница (down — пролёт сверху: темнеет низ, а не
## верх), items — [откуда, куда] утварь поверх всего, lights — свет вне
## комнат [где, цвет, энергия, радиус, мерцает], solids — коллизия вне комнат
## (перила, мебель из items), occluders — ломаные стен для огня (иначе —
## контур главной комнаты с щелью двери). Комнаты всех этажей должны
## совпадать по контуру — это один и тот же дом
func build_interiors(ruin_base: Vector2, ruin_sc: float, ruin_body: Rect2, barn_base: Vector2, barn_sc: float, barn_body: Rect2) -> void:
	# Разрушенный дом. Под правым щипцом (там арочная дверь, центр арки —
	# 0.5895 ширины картинки) — зал с камином и лестницей на второй этаж;
	# влево под низким крылом уходят кладовая и спальня. Стены соседних комнат
	# перекрываются, проёмы между ними застелены досками
	var ruin_w: float = load("res://TileMap/Houses/ruin_house.png").get_width()
	var hall := {
		"room": Rect2(26, 583, 272, 283), "src": Rect2(26, 583, 272, 283), "at": Vector2.ZERO,
		"cols": [216, 230, 12],                                 # между камином и правой полкой — только стена и пол
		"rows": [661, 674, 9], "row_alt": [[127, 215, 778]],     # между камином и столом; под камином — пол из-под стола (без тени)
		"patches": [[Rect2(150, 771, 76, 48), Vector2(68, 818)]],    # входная дверь в нижней стене
		# стены (верх с камином, левая — с проёмом в кладовую, правая, низ по
		# обе стороны двери) и мебель
		"solids": [Rect2(26, 583, 272, 45), Rect2(138, 583, 64, 68), Rect2(26, 583, 32, 153), Rect2(26, 816, 32, 50),
				Rect2(266, 583, 32, 283), Rect2(26, 818, 42, 48), Rect2(144, 818, 154, 48),
				Rect2(132, 690, 66, 75), Rect2(63, 696, 29, 40)],
		"lights": [[Vector2(170, 640), Color(1.0, 0.55, 0.25), 1.25, 170.0, true]],   # камин — главный свет, от него тень
		"fill": [Color(1.0, 0.7, 0.45), 0.5, true],              # от камина, поэтому дышит
	}
	# Кладовая: стены от каморки с бочками, пол застелен заново, своя утварь
	# вдоль верхней стены — шкаф с кувшином, стол с тазом и свечой, бочка,
	# мешок. Вдоль нижней стены свободный коридор между проёмами в зал и в
	# спальню (31 px — шире отступа навмеша, враги тоже пройдут)
	var pantry_walls := [Rect2(596, 586, 213, 26), Rect2(596, 586, 26, 149),
			Rect2(783, 586, 26, 130), Rect2(783, 796, 26, 22), Rect2(596, 798, 213, 20)]
	var pantry := {
		"room": Rect2(596, 586, 213, 232), "src": Rect2(596, 586, 213, 243), "at": Vector2(-181, 140),
		"floor": Rect2(622, 612, 161, 186),
		"items": [[Rect2(1042, 328, 73, 86), Vector2(624, 604)],     # шкаф с кувшином
				[Rect2(952, 526, 82, 59), Vector2(700, 612)],        # стол с тазом
				[Rect2(1047, 742, 23, 58), Vector2(745, 596)],       # свеча на столе
				[Rect2(1272, 666, 39, 58), Vector2(742, 674)],       # бочка
				[Rect2(1297, 812, 38, 50), Vector2(702, 680)]],      # мешок
		"solids": pantry_walls + [Rect2(624, 606, 73, 80), Rect2(700, 612, 82, 59), Rect2(742, 676, 39, 56), Rect2(702, 690, 38, 40)],
		"lights": [[Vector2(756, 606), Color(1.0, 0.68, 0.4), 0.9, 110.0, true]],     # свеча
		"fill": [Color(1.0, 0.72, 0.5), 0.4, true],
	}
	# Спальня в дальнем конце — как есть (проём к кладовой вместо полки и стула)
	var bedroom_walls := [Rect2(344, 586, 231, 34), Rect2(344, 586, 28, 232), Rect2(344, 798, 231, 20)]
	var bedroom := {
		"room": Rect2(344, 586, 231, 232), "src": Rect2(344, 586, 231, 243), "at": Vector2(-386, 140),
		"solids": bedroom_walls + [Rect2(378, 620, 56, 138), Rect2(470, 600, 35, 58), Rect2(511, 620, 42, 115)],
		"lights": [[Vector2(487, 628), Color(1.0, 0.68, 0.4), 0.8, 110.0, true]],     # свеча на столике
		"fill": [Color(1.0, 0.72, 0.5), 0.4, true],
	}
	# Внешний контур (без щели входной двери — она только внизу) и внутренние
	# стены с проёмами: свет одной комнаты не идёт в соседние
	var outline := [Vector2(440, 400), Vector2(440, 0), Vector2(0, 0), Vector2(0, 140),
			Vector2(-386, 140), Vector2(-386, 372), Vector2(0, 372), Vector2(0, 400)]
	var inner := [[Vector2(16, 140), Vector2(16, 270)], [Vector2(16, 350), Vector2(16, 372)],
			[Vector2(-168, 140), Vector2(-168, 289)], [Vector2(-168, 351), Vector2(-168, 372)]]
	var doors := [Rect2(-1, 270, 47, 80),         # зал <-> кладовая (вместо табурета и ведра у левой стены зала; 40 px — пройдут и враги)
			Rect2(-219, 289, 69, 62)]           # кладовая <-> спальня (по низу — на одной линии с проёмом в зал)
	var ground := {
		"rooms": [bedroom, pantry, hall],
		"doors": doors,
		# Лестница у правой стены зала поднимается к потолку: верх уходит в
		# тёмный пролёт второго этажа
		"stairs": {"at": Vector2(333, 30), "repeat": 3},
		"solids": [Rect2(333, 30, 14, 210)],      # левые перила
		# внешний контур с щелью входной двери (x 42..118 по низу зала)
		"occluders": [[Vector2(118, 400)] + outline + [Vector2(42, 400)]] + inner,
	}

	# ---- Второй этаж: те же стены и проёмы, своя обстановка. Над залом —
	# кабинет-библиотека (камин тот же — труба идёт насквозь), над кладовой —
	# комната с чертёжным столом, над спальней — хозяйская спальня. Крыша
	# дырявая — на пол падают пятна лунного света
	var up_hall := {
		"room": hall.room, "src": hall.src, "at": hall.at, "cols": hall.cols, "rows": hall.rows, "row_alt": hall.row_alt,
		"floor": [Rect2(58, 652, 208, 166), Rect2(58, 628, 80, 24), Rect2(202, 628, 64, 24)],
		"solids": [Rect2(26, 583, 272, 45), Rect2(138, 583, 64, 68), Rect2(26, 583, 32, 153), Rect2(26, 816, 32, 50),
				Rect2(266, 583, 32, 283), Rect2(26, 818, 272, 48)],    # нижняя стена — сплошная, двери наверху нет
		"lights": hall.lights,
		"fill": [Color(1.0, 0.7, 0.45), 0.35, true],
	}
	var up_study := {
		"room": pantry.room, "src": pantry.src, "at": pantry.at, "floor": pantry.floor,
		"solids": pantry_walls, "fill": [Color(1.0, 0.72, 0.5), 0.35, true],
	}
	var up_bedroom := {
		"room": bedroom.room, "src": bedroom.src, "at": bedroom.at, "floor": Rect2(372, 612, 181, 186),
		"solids": bedroom_walls, "fill": [Color(1.0, 0.72, 0.5), 0.35, true],
	}
	var moon := Color(0.62, 0.72, 0.95)
	var upper := {
		"rooms": [up_bedroom, up_study, up_hall],
		"doors": doors,
		"stairs": {"at": Vector2(333, 30), "repeat": 3, "down": true},
		"items": [
			# кабинет над залом
			[Rect2(939, 329, 76, 111), Vector2(190, 30)],      # книжный шкаф со склянками
			[Rect2(1148, 329, 83, 71), Vector2(40, 110)],      # стол с картой
			[Rect2(1230, 421, 33, 62), Vector2(124, 128)],     # стул
			[Rect2(832, 465, 90, 45), Vector2(170, 215)],      # шкура на полу
			[Rect2(1310, 735, 51, 55), Vector2(275, 292)],     # бочка
			[Rect2(1090, 689, 42, 41), Vector2(345, 300)],     # ящик
			[Rect2(1070, 947, 50, 48), Vector2(352, 252)],     # ящик под пролётом
			# комната над кладовой
			[Rect2(1259, 325, 97, 75), Vector2(-150, 166)],    # чертёжный стол
			[Rect2(1474, 440, 39, 100), Vector2(-45, 160)],    # высокий шкаф
			[Rect2(1230, 421, 33, 62), Vector2(-110, 222)],    # стул
			[Rect2(1462, 340, 43, 55), Vector2(-122, 148)],    # подсвечник на стене
			# спальня над спальней
			[Rect2(828, 535, 84, 125), Vector2(-352, 168)],    # большая кровать с ковриком
			[Rect2(1152, 419, 58, 66), Vector2(-250, 168)],    # столик с бумагами
			[Rect2(960, 452, 65, 64), Vector2(-250, 250)],     # круглый коврик
			[Rect2(837, 750, 45, 46), Vector2(-300, 300)],     # сундук
		],
		"lights": [
			[Vector2(-100, 175), Color(1.0, 0.68, 0.4), 0.8, 100.0, true],    # подсвечник
			[Vector2(-221, 185), Color(1.0, 0.68, 0.4), 0.7, 100.0, true],    # свеча на столике
			[Vector2(230, 280), moon, 0.6, 45.0, false],                      # луна сквозь дыры в крыше
			[Vector2(95, 240), moon, 0.5, 40.0, false],
			[Vector2(-280, 240), moon, 0.45, 40.0, false],
		],
		"solids": [
			Rect2(333, 130, 14, 110), Rect2(333, 236, 74, 8),  # перила пролёта: слева (кроме верха — там проход к спуску, шире героя) и снизу
			Rect2(190, 40, 76, 95), Rect2(40, 115, 83, 60), Rect2(275, 300, 51, 45), Rect2(345, 305, 42, 36), Rect2(352, 255, 50, 45),
			Rect2(-150, 175, 97, 60), Rect2(-45, 175, 39, 80),
			Rect2(-352, 175, 84, 60), Rect2(-250, 180, 58, 50), Rect2(-300, 305, 45, 38),
		],
		"occluders": [outline + [Vector2(440, 400)]] + inner,
	}
	house_interior("RuinHouseInterior", "RuinHouse", ruin_body, {
		"floors": [ground, upper], "main": 2,
		"door_x": 106.0, "wall_y": 838.0,
		"world_door": Vector2(ruin_base.x + 0.0895 * ruin_w * ruin_sc, ruin_base.y + 4.0),
		# Второй этаж проступает по ходу подъёма по лестнице, без переноса:
		# наверху сходят влево — в проход над укороченными перилами второго этажа
	})
	# Амбар: каморка с кроватью и бочками в жилой половине (справа — открытый
	# навес с сеном, туда не заходим). Дверь на спрайте — 0.365 ширины
	var barn_w: float = load("res://TileMap/Houses/barn.png").get_width()
	house_interior("BarnInterior", "Barn", barn_body, {
		"floors": [{"rooms": [{
			"room": Rect2(596, 586, 213, 232), "src": Rect2(596, 586, 213, 243), "at": Vector2.ZERO,
			# пол перед бочками; в копиях низ берём с гладкого бревна без столба
			"cols": [733, 751, 7], "col_alt": [[798, 829, 700]],
			"rows": [740, 760, 5],                                  # через ковёр — он станет дорожкой
			"patches": [[Rect2(680, 775, 64, 20), Vector2(671, 798)]],
			"solids": [Rect2(596, 586, 213, 34), Rect2(596, 586, 26, 232), Rect2(752, 586, 57, 232),
					Rect2(596, 798, 75, 20), Rect2(735, 798, 74, 20),
					Rect2(628, 618, 55, 109), Rect2(700, 605, 30, 57), Rect2(628, 766, 32, 26)],
			"lights": [[Vector2(690, 690), Color(1.0, 0.68, 0.4), 1.0, 140.0, true]],    # свеча/лампа
			"fill": [Color(1.0, 0.72, 0.5), 0.45, true],
		}]}], "main": 0,
		"door_x": 703.0, "wall_y": 818.0,
		"world_door": Vector2(barn_base.x - 0.135 * barn_w * barn_sc, barn_base.y + 2.0),
	})


## Точка листа -> точка растянутой комнаты (в пикселях листа от её угла).
## Всё, что правее/ниже вставленной полосы, сдвигается на ширину копий
func room_ex(d: Dictionary, p: Vector2) -> Vector2:
	var room: Rect2 = d.room
	var c: Array = d.get("cols", [0, 0, 0])
	var r: Array = d.get("rows", [0, 0, 0])
	var x := p.x - room.position.x
	var y := p.y - room.position.y
	if p.x >= c[1]:
		x += (c[1] - c[0]) * c[2]
	if p.y >= r[1]:
		y += (r[1] - r[0]) * r[2]
	return Vector2(x, y)


## Заливает прямоугольник картинки плиткой из куска листа
func fill_tiled(img: Image, sheet: Image, dst: Rect2i, src: Rect2i) -> void:
	var y := dst.position.y
	while y < dst.end.y:
		var x := dst.position.x
		var h := mini(src.size.y, dst.end.y - y)
		while x < dst.end.x:
			var w := mini(src.size.x, dst.end.x - x)
			img.blit_rect(sheet, Rect2i(src.position, Vector2i(w, h)), Vector2i(x, y))
			x += w
		y += h


## Собирает комнату в картинку: растяжка копиями колонки и ряда, новый пол,
## прорезанные проёмы, своя утварь
func compose_room(sheet: Image, d: Dictionary) -> Image:
	var src := Rect2i(d.src)
	var cols: Array = d.get("cols", [0, 0, 0])
	var rows: Array = d.get("rows", [0, 0, 0])
	var c0: int = cols[0]
	var c1: int = cols[1]
	var nx: int = cols[2]
	var cw := c1 - c0
	var wide := sheet.get_region(src)
	if nx > 0:
		wide = Image.create(src.size.x + cw * nx, src.size.y, false, Image.FORMAT_RGBA8)
		wide.blit_rect(sheet, Rect2i(src.position.x, src.position.y, c1 - src.position.x, src.size.y), Vector2i.ZERO)
		for i in nx:
			var dx := c1 - src.position.x + i * cw
			wide.blit_rect(sheet, Rect2i(c0, src.position.y, cw, src.size.y), Vector2i(dx, 0))
			for a in d.get("col_alt", []):
				wide.blit_rect(sheet, Rect2i(a[2], a[0], cw, a[1] - a[0]), Vector2i(dx, a[0] - src.position.y))
		wide.blit_rect(sheet, Rect2i(c1, src.position.y, src.end.x - c1, src.size.y), Vector2i(c1 - src.position.x + nx * cw, 0))

	var img := wide
	var ny: int = rows[2]
	if ny > 0:
		var r0: int = rows[0] - src.position.y
		var r1: int = rows[1] - src.position.y
		var rh := r1 - r0
		var ww := wide.get_width()
		img = Image.create(ww, src.size.y + rh * ny, false, Image.FORMAT_RGBA8)
		img.blit_rect(wide, Rect2i(0, 0, ww, r1), Vector2i.ZERO)
		for i in ny:
			img.blit_rect(wide, Rect2i(0, r0, ww, rh), Vector2i(0, r1 + i * rh))
			for a in d.get("row_alt", []):
				img.blit_rect(sheet, Rect2i(a[0], a[2], a[1] - a[0], rh), Vector2i(a[0] - src.position.x, r1 + i * rh))
		img.blit_rect(wide, Rect2i(0, r1, ww, src.size.y - r1), Vector2i(0, r1 + ny * rh))

	# Новый пол: один прямоугольник или список (концы — через растяжку,
	# прямоугольник может пересекать вставленные полосы)
	var floors: Array = d.floor if d.get("floor") is Array else ([d.floor] if d.has("floor") else [])
	for f: Rect2 in floors:
		var fa := room_ex(d, f.position)
		fill_tiled(img, sheet, Rect2i(Rect2(fa, room_ex(d, f.end) - fa)), Rect2i(FLOOR_SRC))
	for p in d.get("patches", []):
		img.blit_rect(sheet, Rect2i(p[0]), Vector2i(room_ex(d, p[1])))
	for it in d.get("items", []):
		img.blend_rect(sheet, Rect2i(it[0]), Vector2i(room_ex(d, it[1])))
	return img


## Ступенчатая лестница: верх и низ куска листа, между ними — повтор середины
func compose_stairs(sheet: Image, repeat: int) -> Image:
	var s := Rect2i(STAIRS_SRC)
	var m0 := int(STAIRS_MID.x)
	var m1 := int(STAIRS_MID.y)
	var mh := m1 - m0
	var img := Image.create(s.size.x, s.size.y + mh * repeat, false, Image.FORMAT_RGBA8)
	img.blit_rect(sheet, Rect2i(s.position.x, s.position.y, s.size.x, m1 - s.position.y), Vector2i.ZERO)
	for i in repeat:
		img.blit_rect(sheet, Rect2i(s.position.x, m0, s.size.x, mh), Vector2i(0, m1 - s.position.y + i * mh))
	img.blit_rect(sheet, Rect2i(s.position.x, m1, s.size.x, s.end.y - m1), Vector2i(0, m1 - s.position.y + repeat * mh))
	return img


func house_interior(node_name: String, exterior: String, body: Rect2, h: Dictionary) -> void:
	# Картинки этажей — лист читаем как Image напрямую (без импорта), результат
	# сохраняем ресурсами, чтобы сцена ссылалась на файлы, а не тащила
	# картинки внутри .tscn
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(INTERIOR_TEX))
	sheet.convert(Image.FORMAT_RGBA8)
	# Отдельные доски в листе светлее пола в готовых комнатах — притемняем,
	# чтобы заделанные проёмы и новый пол не выделялись пятнами
	var fr := Rect2i(FLOOR_SRC)
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			var c := sheet.get_pixel(x, y)
			sheet.set_pixel(x, y, Color(c.r * 0.86, c.g * 0.86, c.b * 0.86, c.a))

	var floors: Array = h.floors
	var room_imgs := []          # [этаж][комната]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for f in floors:
		var imgs := []
		for r in f.rooms:
			var im := compose_room(sheet, r)
			imgs.append(im)
			lo = Vector2(minf(lo.x, r.at.x), minf(lo.y, r.at.y))
			hi = Vector2(maxf(hi.x, r.at.x + im.get_width()), maxf(hi.y, r.at.y + im.get_height()))
		room_imgs.append(imgs)
	# Всё ниже — в "картинке дома" с началом в левом верхнем углу всех комнат
	var shift := -lo
	var size := Vector2i(hi - lo)

	# Мир: точка (door_x, wall_y) главной комнаты ложится на дверь спрайта снаружи
	var main: Dictionary = floors[0].rooms[h.main]
	var hp := func(r: Dictionary, p: Vector2) -> Vector2: return r.at + shift + room_ex(r, p)
	var world_door: Vector2 = h.world_door
	var origin: Vector2 = world_door - hp.call(main, Vector2(h.door_x, h.wall_y)) * INT_S
	var wp := func(p: Vector2) -> Vector2: return origin + p * INT_S
	var wrect := func(r: Rect2) -> Rect2: return Rect2(origin + r.position * INT_S, r.size * INT_S)

	var root := Node2D.new()
	root.name = node_name
	root.z_index = -15          # над землёй (-19), под персонажами и объектами (0)
	root.set_script(load("res://Levels/house_interior.gd"))
	add_node(root)

	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var lt := GradientTexture2D.new()
	lt.gradient = g
	lt.width = 128
	lt.height = 128
	lt.fill = GradientTexture2D.FILL_RADIAL
	lt.fill_from = Vector2(0.5, 0.5)
	lt.fill_to = Vector2(1.0, 0.5)

	var room_rects: Array[Rect2] = []
	var stairs_world := Rect2()
	for fi in floors.size():
		var f: Dictionary = floors[fi]
		var rooms: Array = f.rooms
		# Свои слои: стены верхних этажей — только для игрока наверху (слой 10),
		# оклюдеры — свои для огня каждого этажа
		var solid_layer := 1 if fi == 0 else 512
		var occ_bit := 32 << fi

		# ---- картинка этажа
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		for i in rooms.size():
			var im: Image = room_imgs[fi][i]
			img.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(rooms[i].at + shift))
		for door: Rect2 in f.get("doors", []):
			fill_tiled(img, sheet, Rect2i(Rect2(door.position + shift, door.size)), Rect2i(FLOOR_SRC))
		var stairs: Dictionary = f.get("stairs", {})
		var stairs_img: Image = null if stairs.is_empty() else compose_stairs(sheet, stairs.repeat)
		if stairs_img:
			var sa := Vector2i(stairs.at + shift)
			var down: bool = stairs.get("down", false)
			if down:
				# Пролёт сверху: под лестницей — провал вниз
				var hole := Image.create(stairs_img.get_width(), stairs_img.get_height(), false, Image.FORMAT_RGBA8)
				hole.fill(Color(0.03, 0.02, 0.015, 1.0))
				img.blit_rect(hole, Rect2i(Vector2i.ZERO, hole.get_size()), sa)
			img.blend_rect(stairs_img, Rect2i(Vector2i.ZERO, stairs_img.get_size()), sa)
			# Темнота пролёта: внизу — верх лестницы уходит под перекрытие (тёмный
			# верх); наверху — низ лестницы уходит на первый этаж (тёмный низ)
			var dw := stairs_img.get_width() + 8
			var dh := 120
			var dark := Image.create(dw, dh, false, Image.FORMAT_RGBA8)
			for y in dh:
				var k := float(y) / dh
				var a := 0.96 * pow(k if down else 1.0 - k, 1.4)
				for x in dw:
					var edge := clampf(minf(x, dw - 1 - x) / 6.0, 0.0, 1.0)
					dark.set_pixel(x, y, Color(0.02, 0.015, 0.01, a * edge))
			var dy := sa.y + stairs_img.get_height() - dh if down else int(shift.y)
			img.blend_rect(dark, Rect2i(0, 0, dw, dh), Vector2i(sa.x - 4, dy))
		for it in f.get("items", []):
			img.blend_rect(sheet, Rect2i(it[0]), Vector2i(it[1] + shift))
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
		var s := Sprite2D.new()
		s.name = "Rooms"
		s.texture = tex
		s.centered = false
		s.position = origin
		s.scale = Vector2(INT_S, INT_S)
		# Лист уменьшается в 2 раза — линейная фильтрация, как у домов
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Свой бит света: лунный свет и облака (бит 1) под крышу не попадают
		s.light_mask = 2
		add_node(s, vis)

		var lights := Node2D.new()
		lights.name = "Lights"
		add_node(lights, fnode)
		var radial := func(pos: Vector2, l: Array) -> void:
			var pl := PointLight2D.new()
			pl.texture = lt
			pl.texture_scale = float(l[3]) * 2.0 / 128.0
			pl.position = pos
			pl.color = l[1]
			pl.energy = l[2]
			pl.blend_mode = Light2D.BLEND_MODE_ADD
			# Круглый свет (огонь, свеча, луна в дыре крыши) светит и на интерьер,
			# и на обычный слой. С одной маской 2 он ложился тускло и плоско, а
			# тень почти пропадала. Наружу и в соседние комнаты не проливается:
			# стены — оклюдеры этого этажа. Тень персонажа на пол тоже от него
			# (тело персонажа освещает общий свет комнаты — он без тени)
			pl.range_item_cull_mask = 3
			fire_shadow(pl, occ_bit)
			if l[4]:
				pl.set_meta("flicker", true)
			add_node(pl, lights)
			# Копия без тени — только для тела персонажа (слой 8, см.
			# player_spawner.gd): огонь окрашивает героя своим тёплым цветом,
			# сильнее всего вблизи. Сам теневой свет тело не освещает — иначе
			# персонаж ловил бы собственную тень. Чуть шире оригинала, цвет
			# насыщеннее, а яркость ниже: спрайты героев светлые, и полный огонь
			# пересвечивал их почти в белый вместо тёплого оранжевого
			var bl := pl.duplicate() as PointLight2D
			bl.name = "BodyLight"
			bl.shadow_enabled = false
			bl.range_item_cull_mask = 8
			bl.texture_scale = pl.texture_scale * 1.3
			var lc: Color = l[1]
			bl.color = Color(lc.r, lc.g * 0.8, lc.b * 0.45)
			bl.energy = pl.energy * 0.75
			add_node(bl, lights)

		for r in rooms:
			var room: Rect2 = r.room
			var rr: Rect2 = wrect.call(Rect2(hp.call(r, room.position), room_ex(r, room.end)))
			if fi == 0:
				room_rects.append(rr)
			for l in r.get("lights", []):
				radial.call(wp.call(hp.call(r, l[0])), l)
			# Общий тёплый свет комнаты — "коробка" ровно по комнате с мягкими
			# краями в толще стен. Светит и на интерьер, и на всё обычное (бит 1):
			# на игрока и врагов внутри, — но наружу не выходит по форме текстуры
			var fill: Array = r.fill
			var bw := 64
			var bh := maxi(8, roundi(bw * rr.size.y / rr.size.x))
			var box := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
			for y in bh:
				for x in bw:
					var e := minf(minf(x, bw - 1 - x) / 6.0, minf(y, bh - 1 - y) / 6.0)
					var v := smoothstep(0.0, 1.0, clampf(e, 0.0, 1.0))
					box.set_pixel(x, y, Color(v, v, v, v))
			var fl := PointLight2D.new()
			fl.texture = ImageTexture.create_from_image(box)
			fl.texture_scale = rr.size.x / bw
			fl.position = rr.get_center()
			fl.color = fill[0]
			fl.energy = fill[1]
			fl.blend_mode = Light2D.BLEND_MODE_ADD
			fl.range_item_cull_mask = 3
			if fill[2]:
				fl.set_meta("flicker", true)
			add_node(fl, lights)
			# Стены и мебель
			for sr: Rect2 in r.get("solids", []):
				var a: Vector2 = hp.call(r, sr.position)
				static_rect(Vector2.ZERO, wrect.call(Rect2(a, hp.call(r, sr.end) - a)), solid_layer)
		for l in f.get("lights", []):
			radial.call(wp.call(l[0] + shift), l)
		for sr: Rect2 in f.get("solids", []):
			static_rect(Vector2.ZERO, wrect.call(Rect2(sr.position + shift, sr.size)), solid_layer)

		# Стены не пропускают огонь наружу (и в соседние комнаты): незамкнутые
		# ломаные по стенам — сами стены изнутри остаются освещёнными; в дверях
		# щели, сквозь которые свет чуть выливается
		var lines: Array = []
		if f.has("occluders"):
			for line in f.occluders:
				var pts := PackedVector2Array()
				for p: Vector2 in line:
					pts.append(wp.call(p + shift))
				lines.append(pts)
		else:
			var door_patch: Array = main.patches[0]
			var R: Rect2 = room_rects[h.main]
			var gx0: float = wp.call(hp.call(main, door_patch[1])).x
			var gx1: float = gx0 + (door_patch[0] as Rect2).size.x * INT_S
			lines.append(PackedVector2Array([Vector2(gx1, R.end.y), R.end, Vector2(R.end.x, R.position.y),
					R.position, Vector2(R.position.x, R.end.y), Vector2(gx0, R.end.y)]))
		for i in lines.size():
			var occ := LightOccluder2D.new()
			occ.name = "WallOccluder%d" % (i + 1)
			var poly := OccluderPolygon2D.new()
			poly.closed = false
			poly.polygon = lines[i]
			occ.occluder = poly
			occ.occluder_light_mask = occ_bit
			add_node(occ, fnode)

		# Лестница общая для этажей: по ней первый этаж плавно сменяется вторым
		# (Levels/house_interior.gd). Ступени — между левыми перилами и правой
		# стеной зала
		if stairs_img and fi == 0:
			stairs_world = wrect.call(Rect2(stairs.at + shift + Vector2(14, 0), Vector2(stairs_img.get_width() - 14, stairs_img.get_height())))

	# Затемнение улицы — полигон на всю карту с запасом, поверх всего мира
	# (лунные лучи — z 101)
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

	root.set("exterior_path", root.get_path_to(lvl.get_node(exterior)))
	root.set("rooms", room_rects)
	if stairs_world.size != Vector2.ZERO:
		root.set("stairs_rect", stairs_world)

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
func gp_prop(name: String, base: Vector2, sc := GP_S, solid := Vector2(0.7, 0.3), flip := false, sx := 1.0) -> Sprite2D:
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
	# южная граница — частокол (остальные ограды — каменная кладка)
	h_wall(RX(100), RX(1700), RY(622), [[RX(505), RX(620)], [RX(825), RX(860)], [RX(912), RX(945)], [RX(1115), RX(1150)]], "palisade")
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
	# Ночь: тёмная общая подсветка + слабый холодный "лунный" свет; всё яркое
	# на карте даёт огонь (факелы/костры) и холодное свечение лунного сада
	var cm: CanvasModulate = lvl.get_node("NightModulate")
	cm.visible = true
	cm.color = Color(0.24, 0.27, 0.29)
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
