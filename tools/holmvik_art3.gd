extends SceneTree
## Арт партии 3 Хольмвика (ART_PROMPTS_HOLMVIK_3.md): каменные стены, дома v3,
## следы осады. Листы GPT:
##   textures/src/hd/props_v3/stone_walls.webp — 7 предметов стены;
##   textures/src/hd/props_v3/siege.webp       — 10 предметов осады;
##   textures/src/hd/houses_v3/houses_v3_sheet.webp — 5 домов;
##   textures/src/hd/houses_v3/townhouse_v3_a|b.webp — трёхэтажные дома.
##
## Шаги:
##   atlas  — нарезка (связные области плотной альфы, предмет узнаётся по
##            положению центра на листе — SHEETS), чистка каймы, нарисованный
##            GPT дым стирается (он неподвижен и выглядит наклейкой; живой дым
##            даёт Immersion), тон — немного к тону домов города; атлас
##            textures/town_art3_hd.png (+ .json), 2 текселя на px мира.
##            Потом: godot --headless --path . --import
##   walls  — частокол (спрайты blockout: секции, повреждённые секции, боковые
##            куски, башни, ворота-башни; деревянные сторожевые башни на
##            северной стене) заменяется камнем. Коллизия стен та же; у ворот
##            проём сужается под арку; у проломов — завалы камня.
##   houses — часть домов v2 на главной и северной улицах (виды спереди)
##            заменяется домами v3 той же ширины или уже: место, коллизия
##            подножия и тень остаются.
##   siege  — следы осады (таран у внешних ворот, баллиста, камни катапульт,
##            сгоревшие телеги, дымящиеся балки, частокол-знамя Ордена на
##            площади, поваленная статуя, кучи щитов, колодец, помост) — каждый
##            ищет свободное место у своей точки, с коллизией и тенью.
## Порядок: atlas → --import → walls houses siege → normal_bake.gd --
## town_art3_hd → --import → bake_navmesh.gd.

const AU := preload("res://tools/art_util.gd")
const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const SRC := TEX + "src/hd/"
const ATLAS := TEX + "town_art3_hd.png"
const META := TEX + "town_art3_hd.json"
const TONE_REF := TEX + "town_houses_hd.png"
const TOWN_META := TEX + "town_props_hd.json"
const TEX_SCALE := 2.0
const ATLAS_W := 4096
## Насколько тон сдвигается к тону домов города (арт партии 3 — темнее и
## холоднее, так и задумано; немного — чтобы не выпадал из города)
const TONE_MIX := 0.25
const META_TAG := "art3"

## Лист: [файл, порог альфы, расширение (клетки по 4 px), мировых px на px
## листа (общий масштаб листа — пропорции между предметами как у GPT),
## [[имя, центр на листе (доли), дым]]]
const SHEETS := [
	["props_v3/stone_walls.webp", 0.85, 1, 180.0 / 488.0, [
		["wall_front", Vector2(0.20, 0.18), false],
		["wall_breach", Vector2(0.62, 0.18), true],
		["wall_side", Vector2(0.94, 0.44), false],
		["tower_round", Vector2(0.12, 0.63), false],
		["tower_square", Vector2(0.33, 0.57), true],
		["gatehouse", Vector2(0.65, 0.57), false],
		["wall_rubble", Vector2(0.47, 0.90), false],
	]],
	["props_v3/siege.webp", 0.85, 0, 180.0 / 608.0, [
		["siege_ram", Vector2(0.21, 0.19), false],
		["siege_ballista", Vector2(0.57, 0.17), false],
		["siege_stones", Vector2(0.86, 0.18), false],
		["siege_cart", Vector2(0.18, 0.54), true],
		["siege_beams", Vector2(0.49, 0.52), true],
		["siege_stakes", Vector2(0.82, 0.40), false],
		["siege_statue", Vector2(0.15, 0.85), false],
		["siege_shields", Vector2(0.43, 0.84), false],
		["siege_well", Vector2(0.67, 0.81), false],
		["siege_platform", Vector2(0.88, 0.80), false],
	]],
	["houses_v3/houses_v3_sheet.webp", 0.85, 1, 360.0 / 584.0, [
		["v3_stone_wide", Vector2(0.20, 0.29), false],
		["v3_guildhall", Vector2(0.64, 0.27), false],
		["v3_stone_longhouse", Vector2(0.27, 0.79), true],
		["v3_burnt_shell", Vector2(0.67, 0.78), true],
		["v3_tower_house", Vector2(0.91, 0.73), false],
	]],
	["houses_v3/townhouse_v3_a.webp", 0.85, 1, 270.0 / 932.0, [
		["v3_townhouse_a", Vector2(0.5, 0.5), false],
	]],
	["houses_v3/townhouse_v3_b.webp", 0.85, 1, 270.0 / 1048.0, [
		["v3_townhouse_b", Vector2(0.5, 0.5), false],
	]],
]

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["atlas"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[holmvik_art3] ", r)
	quit()


# ───────────────────────── atlas ─────────────────────────

func _step_atlas() -> void:
	var ref := (load(TONE_REF) as Texture2D).get_image()
	ref.decompress()
	ref.convert(Image.FORMAT_RGBA8)
	var target := AU.mean_color(ref)
	var items := []
	var prev := OS.get_environment("TERRAIN_PREVIEW")
	for sheet in SHEETS:
		var img := AU.load_hd(SRC, sheet[0])
		if img == null:
			report.append("нет листа %s" % sheet[0])
			continue
		var lab := {}
		var comps := _components(img, sheet[1], sheet[2], lab)
		var names: Array = sheet[4]
		var used := {}
		for spec in names:
			var want: Vector2 = spec[1] * Vector2(img.get_size())
			var best := -1
			var bd := INF
			for i in comps.size():
				if used.has(i):
					continue
				var d: float = (comps[i].rect as Rect2i).get_center().distance_to(want) if (comps[i].rect as Rect2i).has_point(Vector2i(want)) else 1e6 + Vector2((comps[i].rect as Rect2i).get_center()).distance_to(want)
				if d < bd:
					bd = d
					best = i
			if best < 0:
				report.append("ОТКАЗ %s: не найден %s" % [sheet[0], spec[0]])
				continue
			used[best] = true
			var part := _cut(img, comps[best], lab["grid"], lab["cell"], best)
			if spec[2]:
				part = _remove_smoke(part)
			part = AU.clean_edges(part)
			part = part.get_region(part.get_used_rect())
			var k: float = float(sheet[3]) * TEX_SCALE
			part = AU.resize_clean(part, maxi(int(round(part.get_width() * k)), 4), maxi(int(round(part.get_height() * k)), 4))
			var m := AU.mean_color(part)
			part = AU.match_tone(part, m.lerp(target, TONE_MIX))
			if prev != "":
				part.save_png(prev + "/art3_" + spec[0] + ".png")
			items.append({"name": spec[0], "img": part})
		var left := comps.size() - used.size()
		report.append("%s: %d предметов (лишних кусков %d)" % [sheet[0].get_file(), used.size(), left])
	if items.is_empty():
		return
	items.sort_custom(func(a, b): return a.img.get_height() > b.img.get_height())
	var x := 0
	var y := 0
	var shelf := 0
	var placed := {}
	for it in items:
		var im: Image = it.img
		if x + im.get_width() > ATLAS_W:
			x = 0
			y += shelf + 4
			shelf = 0
		placed[it.name] = Rect2i(x, y, im.get_width(), im.get_height())
		x += im.get_width() + 4
		shelf = maxi(shelf, im.get_height())
	var ah := 1
	while ah < y + shelf:
		ah *= 2
	var atlas := Image.create(ATLAS_W, ah, false, Image.FORMAT_RGBA8)
	for it in items:
		var r: Rect2i = placed[it.name]
		atlas.blit_rect(it.img, Rect2i(Vector2i.ZERO, r.size), r.position)
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	AU.write_import(ATLAS, false)
	var meta := {}
	for nm in placed:
		var r: Rect2i = placed[nm]
		meta[nm] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	report.append("atlas: %d предметов, %dx%d (%s); дальше --import" % [placed.size(), ATLAS_W, ah, error_string(err)])


## Связные области плотной альфы на сетке 4 px (rad — расширение в клетках,
## чтобы части одного предмета с щелью не распадались). Мелкие (< 3%
## крупнейшей) — к ближайшей крупной. lab получает сетку меток.
func _components(img: Image, thr: float, rad: int, lab: Dictionary) -> Array:
	var cell := 4
	var gw := img.get_width() / cell
	var gh := img.get_height() / cell
	var occ := PackedByteArray()
	occ.resize(gw * gh)
	for gy in gh:
		for gx in gw:
			for dy in range(0, cell, 2):
				for dx in range(0, cell, 2):
					if img.get_pixel(gx * cell + dx, gy * cell + dy).a > thr:
						occ[gy * gw + gx] = 1
	var dil := occ.duplicate()
	if rad > 0:
		for gy in gh:
			for gx in gw:
				if occ[gy * gw + gx] == 0:
					continue
				for dy in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						var xx := gx + dx
						var yy := gy + dy
						if xx >= 0 and yy >= 0 and xx < gw and yy < gh:
							dil[yy * gw + xx] = 1
	var label := PackedInt32Array()
	label.resize(gw * gh)
	label.fill(-1)
	var comps := []
	for i in gw * gh:
		if dil[i] == 0 or label[i] != -1:
			continue
		var id := comps.size()
		var stack := [i]
		label[i] = id
		var x0 := gw
		var y0 := gh
		var x1 := 0
		var y1 := 0
		var area := 0
		while not stack.is_empty():
			var j: int = stack.pop_back()
			var jx := j % gw
			var jy := j / gw
			if occ[j] == 1:
				area += 1
				x0 = mini(x0, jx)
				y0 = mini(y0, jy)
				x1 = maxi(x1, jx)
				y1 = maxi(y1, jy)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = jx + d.x
				var ny: int = jy + d.y
				if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
					continue
				var k := ny * gw + nx
				if dil[k] == 1 and label[k] == -1:
					label[k] = id
					stack.append(k)
		comps.append({"rect": Rect2i(x0 * cell, y0 * cell, (x1 - x0 + 1) * cell, (y1 - y0 + 1) * cell), "area": area, "ids": [id]})
	var big := 0
	for c in comps:
		big = maxi(big, c.area)
	var mains := []
	for c in comps:
		if c.area >= big * 0.03:
			mains.append(c)
	for c in comps:
		if c.area >= big * 0.03 or c.area == 0:
			continue
		var best := -1
		var bd := INF
		for i in mains.size():
			var d := Vector2((mains[i].rect as Rect2i).get_center()).distance_to(Vector2((c.rect as Rect2i).get_center()))
			if d < bd:
				bd = d
				best = i
		if best >= 0 and bd < 260.0:
			mains[best].rect = (mains[best].rect as Rect2i).merge(c.rect)
			mains[best].ids.append(c.ids[0])
	lab["grid"] = label
	lab["cell"] = cell
	lab["gw"] = gw
	return mains


## Предмет без соседей: только пиксели его клеток (с запасом в 2 клетки —
## полупрозрачный край), остальное в прямоугольнике — прозрачно
func _cut(img: Image, comp: Dictionary, label: PackedInt32Array, cell: int, _idx: int) -> Image:
	var r: Rect2i = (comp.rect as Rect2i).grow(8).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var gw := img.get_width() / cell
	var gh := img.get_height() / cell
	var ids := {}
	for i in comp.ids:
		ids[i] = true
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for y in r.size.y:
		for x in r.size.x:
			var px := r.position.x + x
			var py := r.position.y + y
			var gx := px / cell
			var gy := py / cell
			var mine := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var qx := gx + dx
					var qy := gy + dy
					if qx < 0 or qy < 0 or qx >= gw or qy >= gh:
						continue
					if ids.has(label[qy * gw + qx]):
						mine = true
						break
				if mine:
					break
			if mine:
				out.set_pixel(x, y, img.get_pixel(px, py))
	return out


## Нарисованный дым: серые полупрозрачные клубы над предметом. Пиксель —
## дым, если он почти без цвета и не плотный, или плотный, но светло-серый
## и рядом с полупрозрачным (тело клуба). Стирается с мягким краем
func _remove_smoke(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var smoke := PackedFloat32Array()
	smoke.resize(w * h)
	for i in w * h:
		var a := d[i * 4 + 3] / 255.0
		if a <= 0.0:
			continue
		var r := d[i * 4] / 255.0
		var g := d[i * 4 + 1] / 255.0
		var b := d[i * 4 + 2] / 255.0
		var sat := maxf(r, maxf(g, b)) - minf(r, minf(g, b))
		var lum := r * 0.3 + g * 0.59 + b * 0.11
		if sat < 0.07 and a < 0.93:
			smoke[i] = 1.0
		elif sat < 0.05 and lum > 0.36:
			smoke[i] = 0.6
	# Размытие маски — край клуба
	var m := Image.create_from_data(w, h, false, Image.FORMAT_RF, smoke.to_byte_array())
	m.resize(maxi(w / 6, 1), maxi(h / 6, 1), Image.INTERPOLATE_BILINEAR)
	m.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var md := m.get_data().to_float32_array()
	for i in w * h:
		var s: float = maxf(smoke[i], md[i] * 1.6)
		if s <= 0.05:
			continue
		var a := d[i * 4 + 3]
		d[i * 4 + 3] = int(a * clampf(1.0 - s, 0.0, 1.0))
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


# ───────────────────────── общее для сцены ─────────────────────────

var _meta: Dictionary
var _tex: Texture2D
var _old_meta: Dictionary


func _open() -> Node:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_old_meta = JSON.parse_string(FileAccess.get_file_as_string(TOWN_META))
	_tex = load(ATLAS) as Texture2D
	if _tex == null:
		report.append("ОШИБКА: нет %s — сначала atlas и --import" % ATLAS)
		return null
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if lvl.get_node("Ground").get("material") == null:
		report.append("ОШИБКА: материал земли не загрузился — сначала godot --headless --path . --import")
		lvl.free()
		return null
	return lvl


func _save(lvl: Node) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	report.append("сцена сохранена (%s)" % error_string(err))
	lvl.free()


func _rect_of(key: String) -> Rect2:
	var r: Array = _meta[key]
	return Rect2(r[0], r[1], r[2], r[3])


func _old_key(s: Sprite2D) -> String:
	if s.texture == null or not s.texture.resource_path.ends_with("town_props_hd.png"):
		return ""
	for k in _old_meta:
		var r: Array = _old_meta[k]
		if s.region_rect == Rect2(r[0], r[1], r[2], r[3]):
			return k
	return ""


## Спрайт как у holmvik_blockout._sprite: не центрован, основание — точка узла
func _set_base_sprite(s: Sprite2D, key: String, sc: float) -> void:
	var r := _rect_of(key)
	s.texture = _tex
	s.region_enabled = true
	s.region_rect = r
	s.centered = false
	s.scale = Vector2(sc, sc) / TEX_SCALE
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y + 4.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.set_meta(META_TAG, key)


func _new_sprite(objects: Node, lvl: Node, key: String, base: Vector2, sc: float, node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	_set_base_sprite(s, key, sc)
	s.position = base
	s.set_meta("blockout", true)
	objects.add_child(s)
	s.owner = lvl
	return s


## Упор у основания спрайта (size — px мира)
func _body(s: Sprite2D, lvl: Node, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size / s.scale
	cs.shape = shape
	cs.position = Vector2(0, -size.y * 0.5 / s.scale.y)
	s.add_child(body)
	body.owner = lvl
	body.add_child(cs)
	cs.owner = lvl


func _hash(a: int, b: int) -> float:
	var h := hash(Vector2i(a, b))
	return float(h % 10007) / 10007.0


# ───────────────────────── walls ─────────────────────────

## Масштаб каменных башен относительно масштаба листа стен
const TOWER_SQUARE_K := 1.25
## Сторожевые башни северной стены (дома v2 «watchtower») — круглые башни
const TOWER_ROUND_W := 165.0
## Ворота: ширина в мире; проход под аркой (коллизия проёма сужается до него)
const GATE_W_WORLD := 360.0
const GATE_PASS := 84.0
## Завал у пролома: масштаб
const RUBBLE_K := 0.62
## Шаг кусков боковой стены — доля высоты куска (как у частокола)
const SIDE_STEP := 0.62


func _step_walls() -> void:
	var lvl := _open()
	if lvl == null:
		return
	var objects := lvl.get_node("Objects")
	var walls := lvl.get_node("Blockout/Walls")
	var front_w: float = _rect_of("wall_front").size.x
	var stats := {"front": 0, "breach": 0, "tower": 0, "round": 0, "gate": 0, "side": 0, "rubble": 0}
	var sides := {}  # x -> [ymin, ymax]
	var old_side_h: float = float(_old_meta["pal_side"][3]) / TEX_SCALE
	for c in objects.get_children():
		if not (c is Sprite2D):
			continue
		var s := c as Sprite2D
		var k := _old_key(s)
		if k == "pal_front" or k == "pal_damaged":
			var old_w: float = float(_old_meta[k][2])
			var kx := s.scale.x * TEX_SCALE * old_w / front_w
			var breach := k == "pal_damaged"
			_set_base_sprite(s, "wall_breach" if breach else "wall_front", 1.0)
			s.scale.x = kx / TEX_SCALE
			stats["breach" if breach else "front"] += 1
			if breach:
				var rb := _new_sprite(objects, lvl, "wall_rubble", s.position + Vector2((_hash(int(s.position.x), 3) - 0.5) * 30.0, 22.0), RUBBLE_K, "A3_Rubble%d_%d" % [int(s.position.x), int(s.position.y)])
				rb.flip_h = _hash(int(s.position.x), 5) > 0.5
				_body(rb, lvl, Vector2(_rect_of("wall_rubble").size.x / TEX_SCALE * RUBBLE_K * 0.7, 16))
				stats.rubble += 1
		elif k == "pal_tower":
			_set_base_sprite(s, "tower_square", TOWER_SQUARE_K)
			s.flip_h = _hash(int(s.position.x), 11) > 0.5
			stats.tower += 1
		elif k == "pal_gatehouse":
			var gr := _rect_of("gatehouse")
			_set_base_sprite(s, "gatehouse", GATE_W_WORLD / (gr.size.x / TEX_SCALE))
			_gate_collision(walls, String(s.name), s.position.x)
			stats.gate += 1
		elif k == "pal_side":
			var x := s.position.x
			if not sides.has(x):
				sides[x] = [INF, -INF]
			sides[x][0] = minf(sides[x][0], s.position.y)
			sides[x][1] = maxf(sides[x][1], s.position.y)
			s.get_parent().remove_child(s)
			s.free()
		elif str(s.get_meta("town_v2", "")) == "watchtower":
			var rr := _rect_of("tower_round")
			var sc := TOWER_ROUND_W / (rr.size.x / TEX_SCALE)
			s.texture = _tex
			s.region_rect = rr
			s.scale = Vector2(sc, sc) / TEX_SCALE
			s.offset = Vector2(0, -rr.size.y * 0.5 + rr.size.y * 0.04)
			s.set_meta(META_TAG, "tower_round")
			stats.round += 1
	# Боковые стены заново: тот же отрезок, куски каменной стены
	var side_h: float = _rect_of("wall_side").size.y / TEX_SCALE
	for x in sides:
		# в holmvik_blockout первая позиция — y0 + шаг частокола (+8)
		var y0: float = sides[x][0] - 8.0 - old_side_h * SIDE_STEP
		var y1: float = sides[x][1] - 8.0
		var step := side_h * SIDE_STEP
		var y := y0 + step
		while y <= y1 + step * 0.5:
			var s := _new_sprite(objects, lvl, "wall_side", Vector2(x, minf(y, y1) + 8.0), 1.0, "BO_Side%d_%d" % [int(x), int(y)])
			s.flip_h = _hash(int(x), int(y)) > 0.5
			stats.side += 1
			y += step
	report.append("walls: секций %d, проломов %d (+завалов %d), башен %d, круглых %d, ворот %d, боковых кусков %d" % [
		stats.front, stats.breach, stats.rubble, stats.tower, stats.round, stats.gate, stats.side])
	_save(lvl)


## Проём ворот — под арку: упоры от краёв башен до прохода
func _gate_collision(walls: Node, gate: String, x: float) -> void:
	for side in ["_L", "_R"]:
		var cs := walls.get_node_or_null(gate + side) as CollisionShape2D
		if cs == null:
			continue
		var rs := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
		var w := GATE_W_WORLD * 0.5 - GATE_PASS * 0.5
		rs.size = Vector2(w, rs.size.y)
		cs.shape = rs
		var cx := x - GATE_PASS * 0.5 - w * 0.5 if side == "_L" else x + GATE_PASS * 0.5 + w * 0.5
		cs.position = Vector2(cx, cs.position.y)


# ───────────────────────── houses ─────────────────────────

## [дом v2 (мета town_v2), x основания, дом v3, отражение]. Главная, северная
## и верхние улицы — каменные трёхэтажные; бедные деревянные остаются на
## окраинах и в нижнем городе
const SWAPS := [
	# главная улица
	["townhouse_a", -1821, "v3_townhouse_a", true],
	["house_burnt_v2", -1309, "v3_burnt_shell", false],
	["merchant_a", -1562, "v3_tower_house", false],
	["house_burnt_v2", -2102, "v3_townhouse_b", false],
	# северная улица
	["townhouse_a", -1260, "v3_townhouse_b", true],
	["longhouse_v2", -837, "v3_guildhall", false],
	["townhouse_a", 112, "v3_townhouse_a", false],
	["townhouse_b", -198, "v3_stone_wide", false],
	["merchant_a", -1804, "v3_tower_house", true],
	["house_burnt_v2", -2075, "v3_burnt_shell", true],
	# верхний город
	["townhouse_b", -950, "v3_townhouse_a", true],
	["longhouse_v2", 50, "v3_stone_longhouse", false],
	["longhouse_v2", -1743, "v3_stone_wide", true],
	["longhouse_v2", 573, "v3_guildhall", true],
	["townhouse_b", 131, "v3_townhouse_b", false],
	["house_burnt_v2", -1142, "v3_burnt_shell", false],
	# южная улица
	["townhouse_b", -1240, "v3_townhouse_a", false],
	["longhouse_v2", -865, "v3_stone_longhouse", true],
]
## Новый дом шире старого не больше чем на столько (px мира) — иначе
## уменьшается: соседи и коллизия на своих местах
const SWAP_SLACK := 16.0
## Тлеющие (живой дым над ними даёт Immersion, как у сгоревших хижин)
const SMOULDER := ["v3_burnt_shell", "v3_stone_longhouse"]


func _step_houses() -> void:
	var lvl := _open()
	if lvl == null:
		return
	var objects := lvl.get_node("Objects")
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	var shadows := lvl.get_node("ContactShadows")
	var sd: PackedFloat32Array = shadows.get("data")
	var done := 0
	for sw in SWAPS:
		var hit: Sprite2D = null
		for c in objects.get_children():
			if c is Sprite2D and str(c.get_meta("town_v2", "")) == sw[0] and absf((c as Sprite2D).position.x - float(sw[1])) < 6.0:
				hit = c
				break
		if hit == null:
			report.append("  нет дома %s у x%d (уже заменён?)" % [sw[0], sw[1]])
			continue
		var old_w := hit.region_rect.size.x * absf(hit.scale.x)
		var r := _rect_of(sw[2])
		var nat_w := r.size.x / TEX_SCALE
		var new_w := minf(nat_w, old_w + SWAP_SLACK)
		var sc := new_w / nat_w
		hit.texture = _tex
		hit.region_rect = r
		hit.scale = Vector2(sc, sc) / TEX_SCALE
		hit.offset = Vector2(0, -r.size.y * 0.5 + r.size.y * 0.05)
		hit.flip_h = sw[3]
		hit.set_meta(META_TAG, sw[2])
		hit.set_meta("town_v2", sw[2])
		hit.set_meta("village_v2", "hut_burnt" if sw[2] in SMOULDER else sw[2])
		# Коллизия подножия: фигура у основания дома; уже — по новой ширине
		var base := hit.position
		for i in shapes.size():
			var rs := shapes[i] as RectangleShape2D
			if rs == null:
				continue
			var o: Vector2 = (xf[i] as Transform2D).origin
			var rect := Rect2(o - rs.size * 0.5, rs.size)
			if rect.grow(4.0).has_point(base + Vector2(0, -6)) and rs.size.x > 80.0:
				var fw := minf(rs.size.x, new_w * 0.86)
				if fw < rs.size.x - 1.0:
					var ns := rs.duplicate() as RectangleShape2D
					ns.size.x = fw
					shapes[i] = ns
				break
		for i in range(0, sd.size(), 5):
			if absf(sd[i] - base.x) < 4.0 and sd[i + 1] < base.y and sd[i + 1] > base.y - 120.0 and sd[i + 2] >= 50.0:
				sd[i + 2] = minf(sd[i + 2], new_w * 0.86 * 0.62)
		done += 1
	col.set("shapes", shapes)
	shadows.set("data", sd)
	report.append("houses: заменено %d из %d" % [done, SWAPS.size()])
	_save(lvl)


# ───────────────────────── siege ─────────────────────────

## [ключ, точка-замысел (основание), радиус поиска, масштаб, отражение,
##  упор: доля ширины и глубина px мира (0 — без коллизии)]
const SIEGE := [
	# у внешних ворот: таран, которым их выбили, помост захватчиков, щиты
	["siege_ram", Vector2(1070, 2715), 40.0, 1.0, false, 0.8, 26.0],
	["siege_platform", Vector2(1390, 2500), 120.0, 0.9, true, 0.6, 22.0],
	["siege_shields", Vector2(900, 2540), 120.0, 0.6, false, 0.6, 14.0],
	# нижний город: баллиста против внутренних ворот, телега, колодец, балки
	["siege_ballista", Vector2(-1500, 2290), 420.0, 0.75, false, 0.6, 18.0],
	["siege_cart", Vector2(-520, 2300), 160.0, 0.8, false, 0.7, 18.0],
	["siege_well", Vector2(-900, 2510), 300.0, 0.85, false, 0.6, 20.0],
	["siege_beams", Vector2(300, 2510), 300.0, 0.75, true, 0.6, 14.0],
	# у внутренних ворот: следы штурма
	["siege_shields", Vector2(-1760, 1720), 140.0, 0.6, true, 0.6, 14.0],
	["siege_stones", Vector2(-2040, 1740), 140.0, 0.7, false, 0.7, 18.0],
	# главная улица и площадь: знамёна Ордена, поваленный воин, камни катапульт
	["siege_stakes", Vector2(-120, 1240), 120.0, 0.8, false, 0.8, 14.0],
	["siege_statue", Vector2(-560, 1200), 120.0, 0.85, true, 0.7, 18.0],
	["siege_stones", Vector2(-1180, 1135), 160.0, 0.75, true, 0.7, 18.0],
	["siege_cart", Vector2(-1650, 1130), 160.0, 0.8, true, 0.7, 18.0],
	["siege_beams", Vector2(-1309, 1050), 160.0, 0.75, false, 0.6, 14.0],
	# северная и верхняя улицы
	["siege_stones", Vector2(-640, 660), 140.0, 0.65, false, 0.7, 16.0],
	["siege_beams", Vector2(-1142, -330), 150.0, 0.7, true, 0.6, 14.0],
	["siege_ballista", Vector2(560, 660), 160.0, 0.7, true, 0.6, 16.0],
	["siege_shields", Vector2(-300, 650), 260.0, 0.55, false, 0.6, 12.0],
]
## Свободно от: спавн, костры, враги (px)
const KEEP_CLEAR := 110.0
## Запас вокруг подножия до чужой коллизии — проход не перекрывается
const PASS_MARGIN := 26.0


func _step_siege() -> void:
	var lvl := _open()
	if lvl == null:
		return
	var objects := lvl.get_node("Objects")
	# Повторный запуск: прежний результат шага убирается
	var removed := 0
	var old_pos := {}
	for c in objects.get_children():
		if String(c.name).begins_with("A3_Siege"):
			old_pos[Vector2((c as Node2D).position.x, (c as Node2D).position.y - 4.0)] = true
			objects.remove_child(c)
			c.free()
			removed += 1
	var blocks := _blockers(lvl)
	# Рисунки домов и стен: что стоит выше их основания, ими закрыто
	var covers := []
	for c in objects.get_children():
		if c is Sprite2D and ((c as Sprite2D).has_meta("house") or str(c.get_meta(META_TAG, "")).begins_with("wall") or str(c.get_meta(META_TAG, "")).begins_with("tower")):
			var sp := c as Sprite2D
			var gr := sp.get_rect()
			var a := sp.transform * gr.position
			var b := sp.transform * gr.end
			covers.append([Rect2(a, b - a).abs(), sp.position.y])
	var pins: Array[Vector2] = []
	for c in objects.get_children():
		var nm := String(c.name)
		if nm.begins_with("Bonfire") or nm.begins_with("Enemy") or nm == "PlayerSpawn":
			pins.append((c as Node2D).position)
	var shadows := lvl.get_node("ContactShadows")
	var sd0: PackedFloat32Array = shadows.get("data")
	# и их тени
	var sd := PackedFloat32Array()
	for k in range(0, sd0.size(), 5):
		if old_pos.has(Vector2(sd0[k], sd0[k + 1])):
			continue
		sd.append_array(sd0.slice(k, k + 5))
	var placed := 0
	var i := 0
	for spec in SIEGE:
		var key: String = spec[0]
		var r := _rect_of(key)
		var sc: float = spec[3]
		var w: float = r.size.x / TEX_SCALE * sc
		var hh: float = r.size.y / TEX_SCALE * sc
		var foot := Vector2(w * float(spec[5]), maxf(float(spec[6]), 10.0))
		var best := Vector2.INF
		var rng := RandomNumberGenerator.new()
		rng.seed = 31 + i
		for t in 900:
			var p: Vector2 = spec[1]
			if t > 0:
				var a := rng.randf() * TAU
				p += Vector2(cos(a), sin(a) * 0.7) * sqrt(rng.randf()) * float(spec[2])
			p = p.round()
			var fr := Rect2(p.x - foot.x * 0.5, p.y - foot.y, foot.x, foot.y)
			# Нижняя треть рисунка не ложится на чужую коллизию (иначе предмет
			# стоит «в стене»); подножие — с запасом на проход
			var pic := Rect2(p.x - w * 0.5, p.y - hh * 0.35, w, hh * 0.35)
			var ok := true
			for b in blocks:
				if (b as Rect2).intersects(fr.grow(PASS_MARGIN)) or (b as Rect2).intersects(pic):
					ok = false
					break
			if ok:
				for q in pins:
					if q.distance_to(p) < KEEP_CLEAR:
						ok = false
						break
			if ok:
				# Не прятаться за рисунком того, что стоит ближе к камере
				var full := Rect2(p.x - w * 0.5, p.y - hh, w, hh)
				for cv in covers:
					if float(cv[1]) > p.y + 2.0 and (cv[0] as Rect2).intersects(full):
						var inter := (cv[0] as Rect2).intersection(full)
						if inter.get_area() > full.get_area() * 0.12:
							ok = false
							break
			if ok:
				best = p
				break
		if best == Vector2.INF:
			report.append("  НЕ встал: %s у %s" % [key, spec[1]])
			i += 1
			continue
		var s := _new_sprite(objects, lvl, key, best, sc, "A3_Siege%d_%s" % [i, key])
		s.flip_h = spec[4]
		if float(spec[6]) > 0.0:
			_body(s, lvl, foot)
		blocks.append(Rect2(best.x - foot.x * 0.5, best.y - foot.y, foot.x, foot.y))
		sd.append_array(PackedFloat32Array([best.x, best.y - 4.0, w * 0.48, maxf(foot.y, 14.0) * 0.9, 0.4]))
		report.append("  %s → (%d, %d)" % [key, best.x, best.y])
		placed += 1
		i += 1
	shadows.set("data", sd)
	report.append("siege: поставлено %d из %d (убрано прежних %d)" % [placed, SIEGE.size(), removed])
	_save(lvl)


## Прямоугольники, на которые нельзя ставить: коллизия карты, стены
## блокаута, тела пропсов, вода
func _blockers(lvl: Node) -> Array:
	var out := []
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	for i in shapes.size():
		var rs := shapes[i] as RectangleShape2D
		if rs:
			var o: Vector2 = (xf[i] as Transform2D).origin
			out.append(Rect2(o - rs.size * 0.5, rs.size))
	for cs in lvl.find_children("*", "CollisionShape2D", true, false):
		var rs := (cs as CollisionShape2D).shape as RectangleShape2D
		if rs == null:
			continue
		var gx := _global_xf(cs as Node2D, lvl)
		var sz := rs.size * gx.get_scale().abs()
		out.append(Rect2(gx.origin - sz * 0.5, sz))
	for cp in col.get_children():
		if cp is CollisionPolygon2D:
			var poly: PackedVector2Array = (cp as CollisionPolygon2D).polygon
			var rr := Rect2(poly[0], Vector2.ZERO)
			for p in poly:
				rr = rr.expand(p)
			out.append(rr)
	return out


func _global_xf(n: Node2D, lvl: Node) -> Transform2D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != lvl:
		if p is Node2D:
			t = (p as Node2D).transform * t
		p = p.get_parent()
	return t
