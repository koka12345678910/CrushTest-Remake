extends SceneTree
## Доводка присланной карты reference_map под демо. Правит сцену на месте.
## Запуск:
##   godot --headless --path . -s res://tools/polish_reference_map.gd
## После него нужно перепечь навмеш (tools/bake_navmesh.gd): коллизия меняется.
##
## Шаги (каждый помечает сцену метой, повторный запуск его пропускает):
##   houses  — дома в городе были вдвое меньше нужного (дверь ниже героя,
##             бочка размером с дом). В атласе medieval_houses.png лежат те же
##             дома крупнее; тайл заменяется спрайтом из крупной копии, коллизия
##             дома растёт вместе с ним, пропсы под новым домом убираются;
##   roads   — пропсы, разбросанные по мощёным дорогам, убираются вместе с
##             их коллизией (площади и двор форта не трогаются);
##   shadows — мягкие контактные тени под домами, деревьями и пропсами: без
##             них всё выглядит наклеенным на землю;
##   lights  — факелы: мягче спад, без пересвета там, где их несколько рядом,
##             дрожание огня (reference_map_level/scripts/night_flicker.gd).

const SCENE := "res://reference_map_level/reference_map.tscn"
const HOUSES_TEX := "res://reference_map_level/textures/medieval_houses.png"
const FLICKER := "res://reference_map_level/scripts/night_flicker.gd"
const SHADOWS := "res://reference_map_level/scripts/contact_shadows.gd"

## Масштаб спрайта дома (текстуры карты двойной плотности, обычный масштаб 0.5)
const HOUSE_SCALE := 0.65
## Источник тайла в слое Decor -> где в атласе лежит крупная копия того же дома
## (диапазон по x и y; точные границы обрезаются по альфе)
const HOUSE_LARGE := {
	173: Rect2i(836, 976, 284, 370), 183: Rect2i(1120, 976, 392, 370),
	156: Rect2i(1512, 976, 364, 370), 154: Rect2i(2300, 976, 384, 370),
	159: Rect2i(2684, 976, 368, 370), 168: Rect2i(3052, 976, 298, 370),
	153: Rect2i(3350, 976, 430, 370), 157: Rect2i(366, 1544, 324, 304),
	167: Rect2i(690, 1544, 376, 304), 166: Rect2i(1066, 1544, 404, 304),
	158: Rect2i(0, 1544, 366, 304),
	# Эти два уже крупные — меняется только масштаб
	169: Rect2i(690, 1544, 376, 304), 175: Rect2i(1876, 976, 424, 370),
}
## Двор форта: мощёный, но пропсы там на месте
const FORT_RECT := Rect2(1060, 640, 720, 360)
## Мощение шире этого (в клетках по 16 px) считается площадью, а не дорогой
const PLAZA_CELLS := 5

var lvl: Node2D
var img: Image
var report := []


func _initialize() -> void:
	lvl = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	img = Image.load_from_file(HOUSES_TEX)
	for step in ["houses", "roads", "shadows_v2", "lights", "lights_v2", "relief_v4", "stair_torches"]:
		if lvl.has_meta("polish_" + step):
			report.append("%s: уже сделано, пропуск" % step)
			continue
		call("_step_" + step.trim_suffix("_v2").trim_suffix("_v3").trim_suffix("_v4") if step != "lights_v2" else "_step_lights_v2")
		lvl.set_meta("polish_" + step, true)
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	for r in report:
		print("[polish] ", r)
	print("[polish] сохранено: ", error_string(err))
	quit(0 if err == OK else 1)


# ───────────────────────── общее ─────────────────────────

func _cell_world(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	return layer.position + layer.map_to_local(cell) * layer.scale


## Прямоугольник картинки тайла в мире: {rect, base_y, center_x} по непрозрачным пикселям
func _tile_world_rect(layer: TileMapLayer, cell: Vector2i) -> Rect2:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	if src == null:
		return Rect2(_cell_world(layer, cell), Vector2.ZERO)
	var size := Vector2(src.texture_region_size)
	var td := src.get_tile_data(layer.get_cell_atlas_coords(cell), 0)
	var center := layer.map_to_local(cell) - Vector2(td.texture_origin)
	return Rect2(layer.position + (center - size * 0.5) * layer.scale, size * layer.scale)


func _alpha_bbox(region: Rect2i) -> Rect2i:
	var minx := region.end.x; var maxx := region.position.x
	var miny := region.end.y; var maxy := region.position.y
	for y in range(region.position.y, mini(region.end.y, img.get_height())):
		for x in range(region.position.x, mini(region.end.x, img.get_width())):
			if img.get_pixel(x, y).a > 0.1:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


func _shape_rect(cs: CollisionShape2D) -> Rect2:
	var rs := cs.shape as RectangleShape2D
	if rs == null:
		return Rect2(cs.position, Vector2.ZERO)
	var size := rs.size * cs.scale.abs()
	return Rect2(cs.position - size * 0.5, size)


func _object_layers() -> Array:
	var out := []
	for n in lvl.get_node("Objects").get_children():
		if n is TileMapLayer:
			out.append(n)
	return out


func _is_tex(layer: TileMapLayer, cell: Vector2i, names: Array) -> bool:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	return src != null and src.texture != null and src.texture.resource_path.get_file() in names


# ───────────────────────── дома ─────────────────────────

func _step_houses() -> void:
	var decor := lvl.get_node("Objects/Decor") as TileMapLayer
	var objects := lvl.get_node("Objects")
	var collision := lvl.get_node("Collision")
	var tex := load(HOUSES_TEX) as Texture2D
	var houses := []   # {footprint}
	var n := 0
	for cell in decor.get_used_cells():
		var sid := decor.get_cell_source_id(cell)
		if not HOUSE_LARGE.has(sid):
			continue
		var src := decor.tile_set.get_source(sid) as TileSetAtlasSource
		var small_region := Rect2i(src.margins, src.texture_region_size)
		var small_box := _alpha_bbox(small_region)
		var td := src.get_tile_data(decor.get_cell_atlas_coords(cell), 0)
		# Где на карте стояла видимая часть маленького дома
		var tile_center := decor.map_to_local(cell) - Vector2(td.texture_origin)
		var local_tl := tile_center - Vector2(small_region.size) * 0.5 \
				+ Vector2(small_box.position - small_region.position)
		var old_rect := Rect2(decor.position + local_tl * decor.scale, Vector2(small_box.size) * decor.scale)
		var anchor := Vector2(old_rect.get_center().x, old_rect.end.y)

		var big := _alpha_bbox(HOUSE_LARGE[sid])
		var new_size := Vector2(big.size) * HOUSE_SCALE
		var factor := new_size.x / old_rect.size.x
		var new_rect := Rect2(anchor.x - new_size.x * 0.5, anchor.y - new_size.y, new_size.x, new_size.y)

		# Линия сортировки по глубине — чуть выше низа картинки, как было у тайла
		var sort_lift := 8.0
		var spr := Sprite2D.new()
		spr.name = "House%d" % n
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = Rect2(big)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(HOUSE_SCALE, HOUSE_SCALE)
		spr.position = anchor - Vector2(0, sort_lift)
		spr.offset = Vector2(0, -big.size.y * 0.5 + sort_lift / HOUSE_SCALE)
		spr.set_meta("house", true)
		objects.add_child(spr)
		spr.owner = lvl
		decor.erase_cell(cell)

		# Коллизия дома растёт от той же точки опоры
		var grown := []
		for cs in collision.get_children():
			if not (cs is CollisionShape2D) or not (cs.shape is RectangleShape2D):
				continue
			if old_rect.grow(4.0).has_point(cs.position):
				var rs := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
				rs.size *= factor
				cs.shape = rs
				cs.position = anchor + (cs.position - anchor) * factor
				cs.set_meta("house_collision", true)
				grown.append(cs)
		if grown.is_empty():
			# У дома не было своей коллизии — ставим по основанию
			var cs2 := CollisionShape2D.new()
			var rs2 := RectangleShape2D.new()
			rs2.size = Vector2(new_size.x * 0.78, new_size.y * 0.34)
			cs2.shape = rs2
			cs2.position = anchor - Vector2(0, rs2.size.y * 0.5 + 6.0)
			cs2.name = "HouseBody%d" % n
			cs2.set_meta("house_collision", true)
			collision.add_child(cs2)
			cs2.owner = lvl
		houses.append({"rect": new_rect, "anchor": anchor})
		n += 1

	# Всё, что оказалось под выросшим домом (нижняя часть картинки — стены)
	var cleared := 0
	var shapes_removed := 0
	for h in houses:
		var r: Rect2 = h.rect
		var foot := Rect2(r.position.x + r.size.x * 0.06, r.position.y + r.size.y * 0.42,
				r.size.x * 0.88, r.size.y * 0.58).grow(6.0)
		for layer in _object_layers():
			for cell in layer.get_used_cells():
				if foot.has_point(_cell_world(layer, cell)):
					layer.erase_cell(cell)
					cleared += 1
		for cs in collision.get_children():
			if cs is CollisionShape2D and not cs.has_meta("house_collision") \
					and cs.shape is RectangleShape2D and foot.has_point(cs.position) \
					and (cs.shape as RectangleShape2D).size.x < 120.0:
				cs.free()
				shapes_removed += 1
	report.append("houses: %d домов увеличено (спрайты, масштаб %.2f), убрано из-под них %d объектов и %d коллизий" % [n, HOUSE_SCALE, cleared, shapes_removed])


# ───────────────────────── дороги ─────────────────────────

func _step_roads() -> void:
	var stone := lvl.get_node("Stone") as TileMapLayer
	var collision := lvl.get_node("Collision")
	var paved := {}
	for c in stone.get_used_cells():
		paved[c] = true
	var removable := ["ruin_art.png", "camp_sprites.png", "medieval_atlas.png", "autumn_decorations.png",
			"grassland_props.png", "ruins_props.png", "props.png", "decorations.png"]
	var removed := 0
	var shapes := 0
	for layer in _object_layers():
		for cell in layer.get_used_cells():
			if not _is_tex(layer, cell, removable):
				continue
			var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			# Столбы с факелами стоят у дорог нарочно (на них висит свет)
			if src.texture_region_size.x <= 50 and src.texture_region_size.y >= 120:
				continue
			var p := _cell_world(layer, cell)
			if FORT_RECT.has_point(p):
				continue
			var sc := stone.local_to_map((p - stone.position) / stone.scale)
			if not paved.has(sc) or not _is_road(paved, sc):
				continue
			var art := _tile_world_rect(layer, cell)
			layer.erase_cell(cell)
			removed += 1
			for cs in collision.get_children():
				if cs is CollisionShape2D and cs.shape is RectangleShape2D \
						and not cs.has_meta("house_collision") \
						and art.grow(2.0).has_point(cs.position) \
						and (cs.shape as RectangleShape2D).size.x < 120.0 \
						and (cs.shape as RectangleShape2D).size.y < 120.0:
					cs.free()
					shapes += 1
	report.append("roads: с мощёных дорог убрано %d пропсов и %d их коллизий" % [removed, shapes])


## Дорога — мощение, край которого близко хотя бы с двух противоположных сторон
func _is_road(paved: Dictionary, c: Vector2i) -> bool:
	var reach := {}
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var k := 0
		while k <= PLAZA_CELLS and paved.has(c + d * (k + 1)):
			k += 1
		reach[d] = k
	var narrow_x: bool = reach[Vector2i.LEFT] + reach[Vector2i.RIGHT] < PLAZA_CELLS * 2
	var narrow_y: bool = reach[Vector2i.UP] + reach[Vector2i.DOWN] < PLAZA_CELLS * 2
	return narrow_x or narrow_y


# ───────────────────────── тени ─────────────────────────

func _step_shadows() -> void:
	var objects := lvl.get_node("Objects")
	var items := []   # [center, half_w, half_h, alpha]
	for layer in _object_layers():
		for cell in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if src == null:
				continue
			var size: Vector2 = Vector2(src.texture_region_size) * (layer as TileMapLayer).scale
			# Плоская мелочь (листья, трава, камешки) тени не даёт
			if size.y < 24.0 or size.x < 14.0:
				continue
			var art := _tile_world_rect(layer, cell)
			var tree := _is_tex(layer, cell, ["autumn_trees.png"])
			var w: float = size.x * (0.30 if tree else 0.46)
			items.append([Vector2(art.get_center().x, art.end.y - (10.0 if tree else 5.0)),
					w, w * (0.42 if tree else 0.36), 0.5 if tree else 0.42])
	for n in objects.get_children():
		if n is Sprite2D and n.has_meta("house"):
			var s := n as Sprite2D
			var size2: Vector2 = s.region_rect.size * s.scale
			var base := s.position + Vector2(0, 8.0)
			items.append([base + Vector2(4.0, -size2.y * 0.10), size2.x * 0.56, size2.y * 0.26, 0.55])

	var data := PackedFloat32Array()
	for it in items:
		data.append_array([it[0].x, it[0].y, it[1], it[2], it[3]])
	var old := lvl.get_node_or_null("ContactShadows")
	if old:
		lvl.remove_child(old)
		old.free()
	var node := MultiMeshInstance2D.new()
	node.name = "ContactShadows"
	node.set_script(load(SHADOWS))
	node.set("data", data)
	lvl.add_child(node)
	node.owner = lvl
	# Над землёй и настилами, под всем, что сортируется по глубине
	lvl.move_child(node, objects.get_index())
	report.append("shadows: %d контактных теней одним MultiMesh" % items.size())


## Вторая настройка факелов: после смягчения спада они стали тускловаты
func _step_lights_v2() -> void:
	var n := 0
	for l in lvl.get_node("Night").get_children():
		if l is PointLight2D and (String(l.name).begins_with("Torch") or String(l.name).begins_with("Fire")):
			(l as PointLight2D).energy *= 1.3
			n += 1
	report.append("lights_v2: яркость %d огней x1.3" % n)


# ───────────────────────── свет ─────────────────────────

func _step_lights() -> void:
	var night := lvl.get_node("Night") as Node2D
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256

	var torches := []
	for l in night.get_children():
		if l is PointLight2D and (String(l.name).begins_with("Torch") or String(l.name).begins_with("Fire")):
			torches.append(l)
	for l in torches:
		var light := l as PointLight2D
		var near := 0
		for o in torches:
			if o != l and (o as PointLight2D).position.distance_to(light.position) < 170.0:
				near += 1
		var old_radius: float = light.texture.get_width() * light.texture_scale * 0.5
		light.texture = tex
		# Спад мягче — радиус чуть больше; рядом стоящие факелы делят яркость
		light.texture_scale = old_radius * 1.25 / 128.0
		light.energy = 1.05 / sqrt(1.0 + near * 0.9)
		light.color = Color(1.0, 0.56, 0.24)
	night.set_script(load(FLICKER))
	report.append("lights: %d огней — мягкий спад, без пересвета, дрожание" % torches.size())


# ───────────────────────── рельеф ─────────────────────────
# Скальные стены карты (слой Cliffs) — фронтальные грани: сверху плато, снизу
# низина. Сами тайлы плоские и одного тона с землёй, поэтому высота не читалась.
# Здесь запекается один слой затенения поверх них (текстура relief_shade.res):
#   - светлая кромка по верху стены и тёмная щель под ней;
#   - стена темнеет к подножию;
#   - тень от стены на нижней земле и сбоку от торцов;
#   - в проходах сквозь стену — каменные ступени;
#   - земля у края пропасти темнеет.
# Всё считается по реальному контуру нарисованных скал (альфа тайлов), а не по
# клеткам: у тайлов прозрачный верх, и кромка по клеткам висела бы в воздухе.
# Свет условно сверху-слева, север выше юга (так нарисованы тайлы).

const RELIEF_TEX := "res://reference_map_level/textures/relief_shade.res"
## Мировых пикселей на тексель слоя затенения
const RS := 2

var _ri: Image
var _r_origin := Vector2i.ZERO
var _images := {}


func _step_relief() -> void:
	var cliffs := lvl.get_node("Cliffs") as TileMapLayer
	var chasm := lvl.get_node("Chasm") as TileMapLayer
	var cell := 16
	var cl := {}
	for c in cliffs.get_used_cells(): cl[c] = true
	var vd := {}
	for c in chasm.get_used_cells(): vd[c] = true

	var rect := Rect2i()
	var first := true
	for d in [cl, vd]:
		for c in d:
			var r := Rect2i(c * cell, Vector2i(cell, cell))
			rect = r if first else rect.merge(r)
			first = false
	rect = rect.grow(96)
	_r_origin = rect.position
	var w: int = rect.size.x / RS
	var h: int = rect.size.y / RS
	_ri = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_ri.fill(Color(0, 0, 0, 0))

	var shade := Color(0.03, 0.025, 0.045)
	var lip := Color(1.0, 0.9, 0.74)

	# ── контур скал по альфе тайлов ──
	var solid := PackedByteArray()
	solid.resize(w * h)
	var per: int = cell / RS
	for c in cl:
		var src := cliffs.tile_set.get_source(cliffs.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null:
			continue
		var img2 := _source_image(src)
		var region := src.get_tile_texture_region(cliffs.get_cell_atlas_coords(c))
		var alt := cliffs.get_cell_alternative_tile(c)
		var fh := (alt & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
		var fv := (alt & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
		var step: int = region.size.x / per
		var bx: int = (c.x * cell - _r_origin.x) / RS
		var by: int = (c.y * cell - _r_origin.y) / RS
		for ty in per:
			for tx in per:
				var sx: int = (per - 1 - tx) if fh else tx
				var sy: int = (per - 1 - ty) if fv else ty
				if img2.get_pixel(region.position.x + sx * step + step / 2,
						region.position.y + sy * step + step / 2).a > 0.5:
					solid[(by + ty) * w + bx + tx] = 1

	# ── стены: по столбцам текселей ──
	var faces := 0
	var hole := 4          # дырки в рисунке до 8 px считаются той же стеной
	for x in w:
		var y := 0
		while y < h:
			if solid[y * w + x] == 0:
				y += 1
				continue
			var y0 := y
			var y1 := y
			var gap := 0
			var yy := y + 1
			while yy < h and gap <= hole:
				if solid[yy * w + x] == 1:
					y1 = yy
					gap = 0
				else:
					gap += 1
				yy += 1
			y = y1 + 1
			var hp: float = (y1 - y0 + 1) * RS
			if hp < 14.0:
				continue
			faces += 1
			for ty in range(y0, y1 + 1):
				var dpx: int = (ty - y0) * RS
				var t: float = dpx / hp
				var al: float = 0.05 + 0.46 * pow(t, 1.2)
				if dpx >= 4 and dpx < 8:
					al = maxf(al, 0.36)        # щель под кромкой
				_put(x, ty, shade, al)
				if dpx < 4:
					_put(x, ty, lip, 0.34)
			# тень на нижней земле
			var reach: float = clampf(hp * 0.42, 26.0, 62.0)
			var rt: int = int(reach / RS)
			for k in rt:
				var ty2: int = y1 + 1 + k
				if ty2 >= h or solid[ty2 * w + x] == 1:
					break
				_put(x, ty2, shade, 0.56 * pow(1.0 - float(k) / rt, 1.5))
	# тень сбоку от правых торцов
	var side := 11
	for y in h:
		for x in range(0, w - 1):
			if solid[y * w + x] == 1 and solid[y * w + x + 1] == 0:
				for k in side:
					var tx2: int = x + 1 + k
					if tx2 >= w or solid[y * w + tx2] == 1:
						break
					_put(tx2, y, shade, 0.30 * (1.0 - float(k) / side))

	# ── проходы сквозь стену: каменные ступени ──
	var blockers: Array[Rect2] = []
	for cs in lvl.get_node("Collision").get_children():
		if cs is CollisionShape2D and cs.shape is RectangleShape2D:
			blockers.append(_shape_rect(cs))
	var cols := {}
	for c in cl:
		if not cols.has(c.x):
			cols[c.x] = [c.y, c.y]
		cols[c.x][0] = mini(cols[c.x][0], c.y)
		cols[c.x][1] = maxi(cols[c.x][1], c.y)
	var xs := cols.keys()
	xs.sort()
	var stairs := 0
	var stair_rects := []
	for i in range(1, xs.size()):
		var gapc: int = xs[i] - xs[i - 1] - 1
		if gapc < 2 or gapc > 9:
			continue
		var x0: int = (xs[i - 1] + 1) * cell
		var x1: int = xs[i] * cell
		# Высота прохода — по соседним столбцам стены с обеих сторон
		# Ступени начинаются там, где стена есть уже с обеих сторон прохода
		var top: int = maxi(cols[xs[i - 1]][0], cols[xs[i]][0]) * cell
		var bot := -(1 << 30)
		for k in 3:
			for cx in [xs[i - 1] - k, xs[i] + k]:
				if cols.has(cx):
					bot = maxi(bot, (cols[cx][1] + 1) * cell)
		top += 10
		bot = mini(bot, top + 140)
		# Проход настоящий, только если по нему можно пройти
		var mid := Vector2((x0 + x1) * 0.5, (top + bot) * 0.5)
		var blocked := false
		for r in blockers:
			if r.has_point(mid):
				blocked = true
				break
		if blocked:
			continue
		stairs += 1
		stair_rects.append(Rect2(x0, top, x1 - x0, bot - top))
		var step_h := 10
		for py in range(top, bot, RS):
			var row: int = (py - top) / step_h
			var ph: int = (py - top) % step_h
			var depth: float = float(py - top) / (bot - top)
			for px in range(x0, x1, RS):
				var edge: float = minf(px - x0, x1 - RS - px)
				var n: float = 0.86 + 0.28 * _hash(px / 4, row * 7 + 3)
				# стык камней — со сдвигом через ряд
				var joint: bool = (px + (row % 2) * 11) % 22 < RS
				var col := Color(0.47, 0.45, 0.44)
				var v: float = n * (1.0 - 0.34 * depth)
				if ph >= step_h - 4:
					v *= 0.45                    # подступёнок в тени
				elif ph < RS:
					v *= 1.25                    # освещённый край ступени
				if joint and ph < step_h - 4:
					v *= 0.72
				_over(px, py, Color(col.r * v, col.g * v, col.b * v), 0.94)
				if edge < 12.0:
					_over(px, py, shade, 0.5 * (1.0 - edge / 12.0))   # тень от стен по бокам
		# тень под нижней ступенью
		for py in range(bot, bot + 18, RS):
			for px in range(x0, x1, RS):
				_over(px, py, shade, 0.4 * (1.0 - float(py - bot) / 18.0))

	# ── край пропасти: земля темнеет плавно, по расстоянию до провала ──
	var rim := 22.0
	var border := {}
	for c in vd:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var nb := Vector2i(c.x + dx, c.y + dy)
				if not vd.has(nb) and not cl.has(nb):
					border[nb] = true
	for c in border:
		var near: Array[Rect2] = []
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var v2 := Vector2i(c.x + dx, c.y + dy)
				if vd.has(v2):
					near.append(Rect2(v2 * cell, Vector2(cell, cell)))
		for py in range(c.y * cell, (c.y + 1) * cell, RS):
			for px in range(c.x * cell, (c.x + 1) * cell, RS):
				var p := Vector2(px + 1, py + 1)
				var best := rim
				for r in near:
					var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
					best = minf(best, p.distance_to(q))
				if best < rim:
					_over(px, py, shade, 0.4 * pow(1.0 - best / rim, 1.4))

	var tex := ImageTexture.create_from_image(_ri)
	var err := ResourceSaver.save(tex, RELIEF_TEX, ResourceSaver.FLAG_COMPRESS)
	var old := lvl.get_node_or_null("ReliefShade")
	if old:
		lvl.remove_child(old)
		old.free()
	var spr := Sprite2D.new()
	spr.name = "ReliefShade"
	spr.texture = ResourceLoader.load(RELIEF_TEX, "", ResourceLoader.CACHE_MODE_REPLACE)
	spr.centered = false
	spr.position = Vector2(_r_origin)
	spr.scale = Vector2(RS, RS)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lvl.add_child(spr)
	spr.owner = lvl
	lvl.move_child(spr, cliffs.get_index() + 1)
	# Камень холоднее и чуть светлее земли — стена отделяется от листвы
	cliffs.modulate = Color(0.66, 0.66, 0.70)
	lvl.set_meta("relief_stairs", stair_rects)
	report.append("relief: %d граней стены, %d проходов со ступенями, слой %dx%d (%s)" % [
		faces, stairs, w, h, error_string(err)])


func _source_image(src: TileSetAtlasSource) -> Image:
	var path := src.texture.resource_path
	if not _images.has(path):
		_images[path] = Image.load_from_file(path)
	return _images[path]


## Наложить цвет в мировых координатах
func _over(px: int, py: int, col: Color, a: float) -> void:
	_put((px - _r_origin.x) / RS, (py - _r_origin.y) / RS, col, a)


## Наложить цвет в текселях слоя
func _put(x: int, y: int, col: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= _ri.get_width() or y >= _ri.get_height() or a <= 0.0:
		return
	var cur := _ri.get_pixel(x, y)
	var out_a := a + cur.a * (1.0 - a)
	if out_a <= 0.0:
		return
	var k := cur.a * (1.0 - a)
	_ri.set_pixel(x, y, Color((col.r * a + cur.r * k) / out_a, (col.g * a + cur.g * k) / out_a,
			(col.b * a + cur.b * k) / out_a, out_a))


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 1000) / 1000.0


## Факелы у верха каждой лестницы: без них ночью проход и перепад высоты не
## читаются (у стен своего света нет). Столб — тот же тайл, что у остальных
## факелов карты; свет копируется с существующего факела и получает дрожание
## сам (узел Night, имя на "Torch").
func _step_stair_torches() -> void:
	var decor := lvl.get_node("Objects/Decor") as TileMapLayer
	var night := lvl.get_node("Night")
	var sample: PointLight2D = null
	for l in night.get_children():
		if l is PointLight2D and String(l.name).begins_with("Torch"):
			sample = l
			break
	# Какой тайл стоит под существующим факелом и как свет смещён от его клетки
	var best_cell := Vector2i.ZERO
	var best_d := 1e9
	for c in decor.get_used_cells():
		var src := decor.tile_set.get_source(decor.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null or src.texture_region_size.x > 50 or src.texture_region_size.y < 120:
			continue
		var d := _cell_world(decor, c).distance_to(sample.position)
		if d < best_d:
			best_d = d
			best_cell = c
	var post_src := decor.get_cell_source_id(best_cell)
	var post_atlas := decor.get_cell_atlas_coords(best_cell)
	var light_off := sample.position - _cell_world(decor, best_cell)
	var shadows := lvl.get_node_or_null("ContactShadows")
	var n := 0
	for r in lvl.get_meta("relief_stairs", []):
		var rect: Rect2 = r
		for px in [rect.position.x - 20.0, rect.end.x + 20.0]:
			var cell := decor.local_to_map((Vector2(px, rect.position.y - 4.0) - decor.position) / decor.scale)
			decor.set_cell(cell, post_src, post_atlas)
			var light := sample.duplicate() as PointLight2D
			light.name = "TorchStairs%d" % n
			light.position = _cell_world(decor, cell) + light_off
			light.energy = 1.05
			night.add_child(light)
			light.owner = lvl
			if shadows:
				var data: PackedFloat32Array = shadows.get("data")
				var art := _tile_world_rect(decor, cell)
				data.append_array([art.get_center().x, art.end.y - 5.0, 10.0, 4.0, 0.42])
				shadows.set("data", data)
			n += 1
	report.append("stair_torches: %d факелов у лестниц (столб как у факела в %s, найден в %.0f px от света)" % [n, sample.name, best_d])
