extends SceneTree
## Раздвигает reference_map: вставляет полосу земли шириной W между восточным
## краем деревни и причалом. Всё, что восточнее разреза — река, мост, причал,
## форт, пропасть, лагерь, — уезжает на W вправо, карта становится шире на W.
##
## Разрез — ступенькой: выше CUT_Y он идёт по x = X0 (между деревней и
## причалом), ниже — по x = X1 (лес между болотом и лагерем), чтобы не резать
## болото. Ступенька проходит по лесу под концом реки: выше неё лес уезжает,
## ниже остаётся.
##
## Что делает apply:
##   - тайлы: клетки восточнее разреза сдвигаются; слои земли (FrameGround,
##     Ground) в новой полосе заполняются копией последнего столбца (в пустой
##     земле — тайлом и износом травы с луга GRASS_SAMPLE)
##     перед разрезом, Stone — только в полосе дороги (дорога продлевается до
##     моста);
##   - узлы (дома, пропсы, враги, костры, свет, маркеры, частицы, мосты,
##     обрывы, рельеф, лагерь) — по своей точке;
##   - коллизия (static_shapes; граница карты растягивается) и полигоны воды;
##     контактные тени;
##   - маски земли (paths, wear, zones, cobble_map): вставлены столбцы — копия
##     столбца перед разрезом (брусчатка — только на дороге); прямоугольники
##     масок в материалах и шейдере, WORLD в camera_zones/hero_response/
##     immersion, границы камеры, туман, invisible_collision.json — шире на W;
##   - лес: в новой полосе выше EMPTY_Y.x и ниже EMPTY_Y.y — копия
##     растительности (деревья/кусты, со стволами в коллизии и контактными
##     тенями) из такой же полосы западнее разреза, кроме троп и болота. Между
##     ними — пустая земля с дорогой.
## Повторно не применяется (мета widen_x0 на корне сцены).
##
## Запуск (сцену держит открытый редактор Godot — при "Can't open" повтори;
## не сохраняй старую сцену из редактора после этого):
##   godot --headless --path . -s res://tools/widen_map.gd -- plan
##   godot --headless --path . -s res://tools/widen_map.gd -- apply
##   godot --headless --path . -s res://tools/cull_hidden_ground.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/hidden_ground_cells.res FrameGround:Ground Ground:Stone Ground:PurpleGround Ground:Chasm Ground:Canyon Ground:Water Ground:South
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res
##
## После этого координаты в константах инструментов (build_terrain.gd MIRE и
## пр., paths.json, village_layout.json) восточнее разреза устарели на W —
## перезапуск шагов, которые берут их из констант, а не из сцены, проверять.

const SCENE := "res://reference_map_level/reference_map.tscn"
const LVL := "res://reference_map_level/"
const TERRAIN := LVL + "textures/terrain/"

const X0 := 608.0
const X1 := 1504.0
const CUT_Y := 2160.0
const W := 768.0
const OLD_W := 8640.0
const WORLD_POS := Vector2(-3520, -704)
const WORLD_H := 5120.0
## Полоса новой земли без леса (между деревней и мостом): y от-до
const EMPTY_Y := Vector2(250, 1850)
## Луг у причала (исходные координаты): образец травы для пустой земли
const GRASS_SAMPLE := Rect2(650, 400, 300, 550)
## Ширина перехода к чистой траве: от края деревни, от кромок леса и
## восточного края полосы (px)
const EDGE_FADE := Vector2(192, 96)
## Дорога: строки Stone и брусчатки, которые продлеваются через полосу
const ROAD_Y := Vector2(1020, 1150)
## Прямоугольники коллизии шире этого, лежащие поперёк разреза (граница
## карты), растягиваются, а не сдвигаются
const LONG_RECT := 400.0
## Слои земли, которые заполняются копией столбца перед разрезом
const FILL_LAYERS := ["FrameGround", "Ground"]
const MASKS := ["paths.res", "wear.res", "zones.res", "cobble_map.res"]
const MATERIALS := ["ground_material.tres", "ground_material_chasm.tres"]
const WORLD_SCRIPTS := ["scripts/camera_zones.gd", "scripts/hero_response.gd", "scripts/immersion.gd"]
const SHADER := LVL + "shaders/terrain_ground.gdshader"
const INVISIBLE := LVL + "invisible_collision.json"
## Контейнеры, чьи дети сдвигаются по своей точке
const CONTAINERS := ["Objects", "Markers", "SouthFX", "SouthZones", "Atmosphere", "Night", "PortDecks", "BridgeDecks", "SouthBridges"]
## Одиночные узлы корня (спрайты-картинки), сдвигаются по позиции
const ROOT_SPRITES := ["CanyonFace", "CliffFace", "ReliefShade", "CliffStairs0", "CliffStairs1", "FarmGround", "FortFloor"]

var report: Array[String] = []
var _masks := {}
var _grass_tile: Array = []
var _grass_wear := Color(0, 0, 0, 0)


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["plan"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[widen_map] ", r)
	quit()


## Линия разреза на высоте y
func _cut_x(y: float) -> float:
	return X0 if y < CUT_Y else X1


func _east(p: Vector2) -> bool:
	return p.x >= _cut_x(p.y)


func _cell_size(l: TileMapLayer) -> float:
	return l.tile_set.tile_size.x * absf(l.scale.x)


func _center(l: TileMapLayer, c: Vector2i) -> Vector2:
	return l.transform * l.map_to_local(c)


## Первый столбец слоя, чей центр не западнее x
func _col_for_x(l: TileMapLayer, x: float) -> int:
	var c := l.local_to_map(Vector2((x - l.position.x) / absf(l.scale.x), 0)).x
	while _center(l, Vector2i(c, 0)).x < x:
		c += 1
	while _center(l, Vector2i(c - 1, 0)).x >= x:
		c -= 1
	return c


func _cut_col(l: TileMapLayer, row: int) -> int:
	return _col_for_x(l, _cut_x(_center(l, Vector2i(0, row)).y))


## Значение маски (исходной) в мировой точке
func _mask(name: String, p: Vector2) -> Color:
	var img: Image = _masks[name]
	var k := img.get_width() / OLD_W
	var x := clampi(int((p.x - WORLD_POS.x) * k), 0, img.get_width() - 1)
	var y := clampi(int((p.y - WORLD_POS.y) * k), 0, img.get_height() - 1)
	return img.get_pixel(x, y)


func _load_masks() -> void:
	for m in MASKS:
		_masks[m] = (load(TERRAIN + m) as Texture2D).get_image()


func _layers(lvl: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for c in lvl.get_children():
		if c is TileMapLayer:
			out.append(c)
	for c in lvl.get_node("Objects").get_children():
		if c is TileMapLayer:
			out.append(c)
	return out


# ───────────────────────── plan ─────────────────────────

func _step_plan() -> void:
	var lvl := (load(SCENE) as PackedScene).instantiate()
	_load_masks()
	report.append("уже раздвинута: %s" % lvl.has_meta("widen_x0"))
	# Узлы у линии разреза (±40 px) — и у ступеньки
	for path in CONTAINERS:
		for c in lvl.get_node(path).get_children():
			if not (c is Node2D) or c is TileMapLayer:
				continue
			var p := (c as Node2D).position
			var near_v := absf(p.x - _cut_x(p.y)) < 40.0
			var near_h := absf(p.y - CUT_Y) < 60.0 and p.x > X0 - 40 and p.x < X1 + 40
			if near_v or near_h:
				report.append("  у разреза: %s/%s %s" % [path, c.name, p])
	# Столбцы слоёв перед разрезом
	for l in _layers(lvl):
		var rows := []
		for cell in l.get_used_cells():
			if cell.x == _cut_col(l, cell.y) - 1:
				rows.append(int(_center(l, cell).y))
		rows.sort()
		if not rows.is_empty():
			report.append("  %s: клеток перед разрезом %d, y %s" % [l.name, rows.size(), _ranges(rows, _cell_size(l))])
	# Коллизия поперёк разреза
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		var t: Transform2D = xfs[i]
		if s == null:
			continue
		var cx := _cut_x(t.origin.y)
		if t.origin.x - s.size.x * 0.5 < cx and t.origin.x + s.size.x * 0.5 > cx and s.size.x > 60:
			report.append("  коллизия поперёк разреза: %s %s" % [t.origin, s.size])
	for c in col.get_children():
		if c is CollisionPolygon2D:
			var a := 0
			var b := 0
			for v in (c as CollisionPolygon2D).polygon:
				if _east(v + (c as Node2D).position):
					a += 1
				else:
					b += 1
			if a > 0 and b > 0:
				report.append("  полигон поперёк разреза: %s (%d восточнее, %d западнее)" % [c.name, a, b])
	# Маски на разрезе: тропы, болото, брусчатка
	for m in ["paths.res", "zones.res", "cobble_map.res"]:
		var rows := []
		var y := WORLD_POS.y + 2.0
		while y < WORLD_POS.y + WORLD_H:
			if _mask(m, Vector2(_cut_x(y) - 2.0, y)).r > 0.3:
				rows.append(int(y))
			y += 4.0
		report.append("  %s на разрезе: y %s" % [m, _ranges(rows, 4.0)])
	lvl.free()


func _ranges(rows: Array, step: float) -> String:
	if rows.is_empty():
		return "-"
	var out := []
	var a: int = rows[0]
	var b: int = rows[0]
	for r in rows.slice(1):
		if r - b > step * 1.5:
			out.append("%d..%d" % [a, b])
			a = r
		b = r
	out.append("%d..%d" % [a, b])
	return ", ".join(out)


# ───────────────────────── apply ─────────────────────────

func _step_apply() -> void:
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if lvl.has_meta("widen_x0"):
		report.append("ОТКАЗ: карта уже раздвинута (мета widen_x0 = %s)" % lvl.get_meta("widen_x0"))
		lvl.free()
		return
	_load_masks()
	_sample_grass(lvl)

	# 1. Тайлы
	var donor_bases: Array[Vector2] = []  # основания скопированной растительности (уже в полосе)
	for l in _layers(lvl):
		var n := _shift_layer(l)
		var filled := 0
		if FILL_LAYERS.has(String(l.name)):
			filled = _fill_layer(l, Vector2(-INF, INF))
		elif l.name == "Stone":
			filled = _fill_layer(l, ROAD_Y)
		var forest := 0
		if l.get_parent().name == "Objects":
			forest = _copy_forest(l, donor_bases)
		report.append("тайлы %s: сдвинуто %d, заполнено %d, лес %d" % [l.name, n, filled, forest])

	# 2. Узлы
	var moved := 0
	for path in CONTAINERS:
		for c in lvl.get_node(path).get_children():
			if c is TileMapLayer:
				continue
			if c is Node2D and _east((c as Node2D).position):
				(c as Node2D).position.x += W
				moved += 1
			elif c is Control:
				var ctl := c as Control
				if ctl.offset_left >= X1:
					ctl.offset_left += W
					ctl.offset_right += W
				elif ctl.offset_right > X0:
					ctl.offset_right += W
				moved += 1
	for n in ROOT_SPRITES:
		var s := lvl.get_node_or_null(n) as Node2D
		if s and _east(s.position):
			s.position.x += W
			moved += 1
	report.append("узлов сдвинуто: %d" % moved)

	# 3. Коллизия и вода
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	var ns: Array[Shape2D] = []
	var nx: Array[Transform2D] = []
	var cs := 0
	var copied := 0
	var stretched := 0
	for i in shapes.size():
		var o: Transform2D = xfs[i]
		var t := o
		var rs := shapes[i] as RectangleShape2D
		var shape: Shape2D = shapes[i]
		var cx := _cut_x(o.origin.y)
		if rs and rs.size.x >= LONG_RECT and o.origin.x - rs.size.x * 0.5 < cx and o.origin.x + rs.size.x * 0.5 > cx:
			# Граница карты и прочие длинные стены поперёк разреза — растянуть
			var r2 := rs.duplicate() as RectangleShape2D
			r2.size.x += W
			shape = r2
			t.origin.x += W * 0.5
			stretched += 1
		elif o.origin.x >= cx:
			t.origin.x += W
			cs += 1
		ns.append(shape)
		nx.append(t)
		# Стволы скопированного леса
		if rs and maxf(rs.size.x, rs.size.y) <= 64.0 and o.origin.x >= cx - W and o.origin.x < cx \
				and _near(o.origin + Vector2(W, 0), donor_bases, 24.0):
			ns.append(shapes[i])
			nx.append(Transform2D(0, o.origin + Vector2(W, 0)))
			copied += 1
	col.set("shapes", ns)
	col.set("shape_transforms", nx)
	var polys := 0
	for c in col.get_children():
		if c is CollisionPolygon2D:
			var cp := c as CollisionPolygon2D
			var pts := cp.polygon
			var east := 0
			for v in pts:
				if _east(v + cp.position):
					east += 1
			if east == 0:
				continue
			# Почти весь по одну сторону — целиком туда (иначе через полосу
			# протянется тонкий язык воды); по-настоящему поперёк — растянуть
			var frac := float(east) / pts.size()
			if frac < 0.1:
				continue
			for k in pts.size():
				if frac > 0.9 or _east(pts[k] + cp.position):
					pts[k].x += W
			cp.polygon = pts
			polys += 1
	report.append("коллизия: сдвинуто %d, растянуто %d, стволов скопировано %d, полигонов воды %d" % [cs, stretched, copied, polys])

	# 4. Контактные тени
	var cshadow := lvl.get_node("ContactShadows")
	var data: PackedFloat32Array = cshadow.get("data")
	var nd := PackedFloat32Array()
	var sh := 0
	var shc := 0
	for k in range(0, data.size(), 5):
		var e := data.slice(k, k + 5)
		var p := Vector2(e[0], e[1])
		if _east(p):
			e[0] += W
			sh += 1
		nd.append_array(e)
		var cx := _cut_x(p.y)
		if p.x >= cx - W and p.x < cx and _near(p + Vector2(W, 0), donor_bases, 20.0):
			var e2 := data.slice(k, k + 5)
			e2[0] += W
			nd.append_array(e2)
			shc += 1
	cshadow.set("data", nd)
	report.append("контактные тени: сдвинуто %d, скопировано %d" % [sh, shc])

	# 5. Камера
	var spawn := lvl.get_node("Objects/PlayerSpawn")
	var cl: Rect2i = spawn.get("camera_limits")
	cl.size.x += int(W)
	spawn.set("camera_limits", cl)
	lvl.set_meta("widen_x0", Vector4(X0, X1, CUT_Y, W))

	# Сцена — первой: если её держит редактор, остальные файлы не трогаем
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	report.append("сцена сохранена (%s)" % error_string(err))
	lvl.free()
	if err != OK:
		report.append("ОСТАНОВЛЕНО: сцена не сохранилась, остальное не тронуто")
		return

	# 6. Маски земли: строки выше ступеньки режутся по X0, ниже — по X1
	for m in MASKS:
		var img: Image = _masks[m]
		var k := float(img.get_width()) / OLD_W
		var dw := int(round(W * k))
		var h := img.get_height()
		var ty_cut := clampi(int(round((CUT_Y - WORLD_POS.y) * k)), 0, h)
		var out := Image.create(img.get_width() + dw, h, false, img.get_format())
		for part in [[0, ty_cut, X0], [ty_cut, h, X1]]:
			var y0: int = part[0]
			var y1: int = part[1]
			if y1 <= y0:
				continue
			var c := int(round((float(part[2]) - WORLD_POS.x) * k))
			out.blit_rect(img, Rect2i(0, y0, c, y1 - y0), Vector2i(0, y0))
			out.blit_rect(img, Rect2i(c, y0, img.get_width() - c, y1 - y0), Vector2i(c + dw, y0))
			var col_img := img.get_region(Rect2i(c - 1, y0, 1, y1 - y0))
			if m == "cobble_map.res":
				# Брусчатка в полосе — только дорога (на разрезе ещё и
				# боковая улочка: её копия дала бы мощёное поле)
				for ty in col_img.get_height():
					var wy := WORLD_POS.y + (y0 + ty + 0.5) / k
					if wy < ROAD_Y.x or wy > ROAD_Y.y:
						col_img.set_pixel(0, ty, Color(0, 0, 0, 0))
			for x in dw:
				out.blit_rect(col_img, Rect2i(0, 0, 1, y1 - y0), Vector2i(c + x, y0))
			if m == "wear.res":
				# Пустая земля — как луг у причала (у края деревни на разрезе
				# вытоптанный двор: его копия дала бы полосу грязи); переход
				# плавный (_grassiness)
				var cx: float = part[2]
				for x in dw:
					var wx := cx + (x + 0.5) / k
					for ty in col_img.get_height():
						var wy := WORLD_POS.y + (y0 + ty + 0.5) / k
						var g := _grassiness(wx, wy)
						var e := _east_blend(wx, wy)
						if g > 0.0 or e > 0.0:
							var v := col_img.get_pixel(0, ty).lerp(_grass_wear, g)
							out.set_pixel(c + x, y0 + ty, v.lerp(img.get_pixel(c, y0 + ty), e))
		var tex := ImageTexture.create_from_image(out)
		var e2 := ResourceSaver.save(tex, TERRAIN + m)
		report.append("маска %s: %dx%d -> %dx%d (%s)" % [m, img.get_width(), h, out.get_width(), h, error_string(e2)])

	# 7. Прямоугольники мира в материалах, шейдере и скриптах
	var new_w := int(OLD_W + W)
	for m in MATERIALS:
		_replace_in(TERRAIN + m, "8640, 5120", "%d, 5120" % new_w)
	_replace_in(SHADER, "8640.0, 5120.0", "%d.0, 5120.0" % new_w)
	for s in WORLD_SCRIPTS:
		_replace_in(LVL + s, "Rect2(-3520, -704, 8640, 5120)", "Rect2(-3520, -704, %d, 5120)" % new_w)

	# 8. Невидимые упоры
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(INVISIBLE))
	if list is Array:
		var ni := 0
		for e in list:
			# (x, y) в списке — центр прямоугольника
			var c := Vector2(float(e[0]), float(e[1]))
			if str(e[4]) == "Collision" and _east(c):
				e[0] = float(e[0]) + W
				ni += 1
		var f := FileAccess.open(INVISIBLE, FileAccess.WRITE)
		f.store_string(JSON.stringify(list, "\t"))
		f.close()
		report.append("invisible_collision.json: сдвинуто %d" % ni)
	report.append("дальше: cull_hidden_ground.gd, bake_navmesh.gd (команды в шапке)")


func _replace_in(path: String, a: String, b: String) -> void:
	var s := FileAccess.get_file_as_string(path)
	var n := s.count(a)
	if n == 0:
		report.append("  %s: '%s' не найдено" % [path.get_file(), a])
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(s.replace(a, b))
	f.close()
	report.append("  %s: заменено %d" % [path.get_file(), n])


## Клетки восточнее разреза — на W вправо
func _shift_layer(l: TileMapLayer) -> int:
	var dc := int(round(W / _cell_size(l)))
	var cells: Array = []
	for c in l.get_used_cells():
		if c.x >= _cut_col(l, c.y):
			cells.append([c, l.get_cell_source_id(c), l.get_cell_atlas_coords(c), l.get_cell_alternative_tile(c)])
	for e in cells:
		l.erase_cell(e[0])
	for e in cells:
		l.set_cell(e[0] + Vector2i(dc, 0), e[1], e[2], e[3])
	return cells.size()


## Новая полоса: копия столбца перед разрезом (в пределах строк y_range)
func _fill_layer(l: TileMapLayer, y_range: Vector2) -> int:
	var dc := int(round(W / _cell_size(l)))
	var n := 0
	for c in l.get_used_cells():
		var cut := _cut_col(l, c.y)
		if c.x != cut - 1:
			continue
		var y := _center(l, c).y
		if y < y_range.x or y > y_range.y:
			continue
		var t: Array = [l.get_cell_source_id(c), l.get_cell_atlas_coords(c), l.get_cell_alternative_tile(c)]
		# Восточный сосед полосы — первый столбец сдвинутой части
		var ec := Vector2i(cut + dc, c.y)
		var te: Array = [l.get_cell_source_id(ec), l.get_cell_atlas_coords(ec), l.get_cell_alternative_tile(ec)]
		for k in dc:
			var tk := t
			if l.name == "Ground" and not _grass_tile.is_empty():
				# Трава и восточный сосед вразброс по силе перехода — рваный
				# край, не линейка
				var x := _center(l, Vector2i(cut + k, c.y)).x
				var g := _grassiness(x, y)
				var e := _east_blend(x, y)
				var r := _hash(cut + k, c.y)
				if te[0] != -1 and e > 0.0 and e >= r:
					tk = te
				elif g > 0.0 and g >= r:
					tk = _grass_tile
			l.set_cell(Vector2i(cut + k, c.y), tk[0], tk[1], tk[2])
			n += 1
	return n


## Сила восточного соседа у восточного края полосы (0..1)
func _east_blend(x: float, y: float) -> float:
	if y >= ROAD_Y.x and y <= ROAD_Y.y:
		return 0.0
	var cx := _cut_x(y)
	return smoothstep(cx + W - EDGE_FADE.x, cx + W, x)


## Сила «чистой травы» в новой полосе (0 — копия столбца перед разрезом,
## 1 — луг): только в пустой земле (EMPTY_Y, не дорога), плавно от края
## деревни (EDGE_FADE.x) и от кромок леса (EDGE_FADE.y). У восточного края
## полосы поверх неё — восточный сосед (_east_blend)
func _grassiness(x: float, y: float) -> float:
	if y >= ROAD_Y.x and y <= ROAD_Y.y:
		return 0.0
	var cx := _cut_x(y)
	var v := smoothstep(EMPTY_Y.x, EMPTY_Y.x + EDGE_FADE.y, y) * (1.0 - smoothstep(EMPTY_Y.y - EDGE_FADE.y, EMPTY_Y.y, y))
	var h := smoothstep(cx, cx + EDGE_FADE.x, x)
	return v * h


static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0


## Самый частый тайл Ground и средний износ на лугу GRASS_SAMPLE (исходные
## координаты, до сдвига)
func _sample_grass(lvl: Node) -> void:
	var g := lvl.get_node("Ground") as TileMapLayer
	var count := {}
	for c in g.get_used_cells():
		if GRASS_SAMPLE.has_point(_center(g, c)):
			var key := [g.get_cell_source_id(c), g.get_cell_atlas_coords(c), g.get_cell_alternative_tile(c)]
			count[key] = count.get(key, 0) + 1
	var best := 0
	for key in count:
		if count[key] > best:
			best = count[key]
			_grass_tile = key
	var wear: Image = _masks["wear.res"]
	var k := wear.get_width() / OLD_W
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for ty in range(int((GRASS_SAMPLE.position.y - WORLD_POS.y) * k), int((GRASS_SAMPLE.end.y - WORLD_POS.y) * k)):
		for tx in range(int((GRASS_SAMPLE.position.x - WORLD_POS.x) * k), int((GRASS_SAMPLE.end.x - WORLD_POS.x) * k)):
			sum += wear.get_pixel(tx, ty)
			n += 1
	_grass_wear = sum / maxf(n, 1)
	report.append("трава для пустой земли: тайл %s (%d из %d клеток луга), износ %s" % [_grass_tile, best, count.values().reduce(func(a, b): return a + b, 0), _grass_wear])


## Лес в новой полосе: копия растительности из полосы шириной W западнее
## разреза — только выше/ниже EMPTY_Y, не на тропах и не из болота
func _copy_forest(l: TileMapLayer, bases: Array[Vector2]) -> int:
	var dc := int(round(W / _cell_size(l)))
	var ts := l.tile_set
	var add: Array = []
	for c in l.get_used_cells():
		var cut := _cut_col(l, c.y)
		if c.x < cut - dc or c.x >= cut:
			continue
		var src := ts.get_source(l.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null or not _foliage(src):
			continue
		var base := _center(l, c)
		var td := src.get_tile_data(l.get_cell_atlas_coords(c), l.get_cell_alternative_tile(c) & 0xFFF)
		if td:
			base.y += td.y_sort_origin * absf(l.scale.y)
		if base.y > EMPTY_Y.x and base.y < EMPTY_Y.y:
			continue
		var cx := _cut_x(base.y)
		# Тропа в полосе — это продолжение тропы с разреза
		if _mask("paths.res", Vector2(cx - 2.0, base.y)).r > 0.25:
			continue
		if _mask("zones.res", base).r > 0.5:
			continue
		add.append([c + Vector2i(dc, 0), l.get_cell_source_id(c), l.get_cell_atlas_coords(c), l.get_cell_alternative_tile(c)])
		bases.append(base + Vector2(W, 0))
	var n := 0
	for e in add:
		if l.get_cell_source_id(e[0]) == -1:
			l.set_cell(e[0], e[1], e[2], e[3])
			n += 1
	return n


func _foliage(src: TileSetAtlasSource) -> bool:
	if src.has_meta("forest_variant"):
		return true
	if src.has_meta("hd_prop"):
		var k := str(src.get_meta("hd_prop")).get_slice("@", 0)
		for p in ["bush", "tuft", "fern", "stump"]:
			if k.begins_with(p):
				return true
	return false


func _near(p: Vector2, pts: Array[Vector2], r: float) -> bool:
	for q in pts:
		if absf(q.x - p.x) < r and absf(q.y - p.y) < r:
			return true
	return false
