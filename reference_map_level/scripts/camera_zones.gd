extends Node
## camera_zones.gd — камера по зонам reference_map: в лесу чуть ближе (тесно,
## кроны над головой), у обрыва, пропасти, в поле и в лагере — дальше (видно
## простор и глубину). Упреждение по бегу (look_ahead_distance героя) тоже
## зависит от зоны: на просторе камера сильнее уходит вперёд.
##
## Карта зон считается один раз при запуске (setup из immersion.gd): сетка
## клеток CELL px, в каждой — множитель зума; между клетками — плавно
## (билинейно), во времени — плавно (zoom_speed). Зум ставится через
## Juice.zone_zoom: наезды камеры в бою умножаются поверх, а не спорят.

const WORLD := Rect2(-3520, -704, 9408, 5120)
const CELL := 128.0

## Крайние множители: ближе в лесу, дальше на просторе
@export var forest_zoom := 1.1
@export var edge_zoom := 0.86
@export var open_zoom := 0.93
@export var camp_zoom := 0.92
## Скорость смены зума (доля разницы в секунду)
@export var zoom_speed := 0.7
## Упреждение по бегу при множителе 1 (как у героев) и сколько добавлять на просторе
@export var look_ahead_base := 22.0
@export var look_ahead_open := 14.0

var _grid := PackedFloat32Array()
var _w := 0
var _h := 0
var _zoom := 1.0
var _hero: Node = null
var ready_ok := false


## trees — основания деревьев; edges — клетки обрывов/пропасти (мировые точки);
## houses — дома; camp — земля лагеря
func setup(trees: PackedVector2Array, edges: PackedVector2Array, houses: PackedVector2Array, camp: Rect2) -> void:
	_w = int(ceil(WORLD.size.x / CELL))
	_h = int(ceil(WORLD.size.y / CELL))
	var tree_n := _count(trees)
	var edge_n := _count(edges)
	var house_n := _count(houses)
	tree_n = _blur(tree_n, 2)
	edge_n = _dilate(edge_n, 3)
	house_n = _dilate(house_n, 3)
	_grid.resize(_w * _h)
	for y in _h:
		for x in _w:
			var i := y * _w + x
			var c := WORLD.position + Vector2(x + 0.5, y + 0.5) * CELL
			var forest := smoothstep(0.35, 1.3, tree_n[i])
			var z := lerpf(1.0, forest_zoom, forest)
			if house_n[i] <= 0.0 and tree_n[i] < 0.5:
				z = minf(z, open_zoom)
			if camp.has_point(c):
				z = minf(z, camp_zoom)
			z = lerpf(z, minf(z, edge_zoom), clampf(edge_n[i], 0.0, 1.0))
			_grid[i] = z
	_grid = _blur(_grid, 2)
	ready_ok = true


func _count(pts: PackedVector2Array) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(_w * _h)
	for p in pts:
		var x := int((p.x - WORLD.position.x) / CELL)
		var y := int((p.y - WORLD.position.y) / CELL)
		if x >= 0 and y >= 0 and x < _w and y < _h:
			g[y * _w + x] += 1.0
	return g


## Среднее по квадрату (2r+1)² — дважды, почти гаусс
func _blur(g: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var out := g
	for pass_i in 2:
		var tmp := PackedFloat32Array()
		tmp.resize(_w * _h)
		for y in _h:
			for x in _w:
				var s := 0.0
				var n := 0
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var xx := x + dx
						var yy := y + dy
						if xx >= 0 and yy >= 0 and xx < _w and yy < _h:
							s += out[yy * _w + xx]
							n += 1
				tmp[y * _w + x] = s / n
		out = tmp
	return out


## 1 — в пределах r клеток есть хоть одна точка, к краю мягко
func _dilate(g: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_w * _h)
	for y in _h:
		for x in _w:
			var best := 0.0
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < _w and yy < _h and g[yy * _w + xx] > 0.0:
						best = maxf(best, 1.0 - Vector2(dx, dy).length() / (r + 1.0))
			out[y * _w + x] = best
	return out


func zoom_at(p: Vector2) -> float:
	if not ready_ok:
		return 1.0
	var f := (p - WORLD.position) / CELL - Vector2(0.5, 0.5)
	var x0 := clampi(int(floor(f.x)), 0, _w - 1)
	var y0 := clampi(int(floor(f.y)), 0, _h - 1)
	var x1 := mini(x0 + 1, _w - 1)
	var y1 := mini(y0 + 1, _h - 1)
	var tx := clampf(f.x - floor(f.x), 0.0, 1.0)
	var ty := clampf(f.y - floor(f.y), 0.0, 1.0)
	var a := lerpf(_grid[y0 * _w + x0], _grid[y0 * _w + x1], tx)
	var b := lerpf(_grid[y1 * _w + x0], _grid[y1 * _w + x1], tx)
	return lerpf(a, b, ty)


func _process(delta: float) -> void:
	if not ready_ok:
		return
	var cam := get_viewport().get_camera_2d()
	var juice := get_node_or_null("/root/Juice")
	if cam == null or juice == null:
		return
	var hero := cam.get_parent()
	if hero != _hero:
		_hero = hero
		_zoom = zoom_at((hero as Node2D).global_position) if hero is Node2D else 1.0
	if not hero is Node2D:
		return
	var target := zoom_at((hero as Node2D).global_position)
	_zoom = lerpf(_zoom, target, 1.0 - exp(-zoom_speed * delta))
	juice.set("zone_zoom", _zoom)
	if "look_ahead_distance" in hero:
		hero.set("look_ahead_distance", look_ahead_base + look_ahead_open * clampf((1.0 - _zoom) / (1.0 - edge_zoom), 0.0, 1.0))


func _exit_tree() -> void:
	var juice := get_node_or_null("/root/Juice")
	if juice:
		juice.set("zone_zoom", 1.0)
	if is_instance_valid(_hero) and "look_ahead_distance" in _hero:
		_hero.set("look_ahead_distance", look_ahead_base)
