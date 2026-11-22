extends SceneTree
## Маршрут Хольмвика: завалы, заглушки щелей между домами, след стражи
## (арт партии 4, reference_map_level/ART_PROMPTS_HOLMVIK_4.md).
##
## Правило карты: закрыто — видно, открыто — видно. Невидимых стен нет:
## коллизия стоит только там, где стоит арт, и арт закрывает проход целиком.
##
## Шаги:
##   atlas — textures/town_route_hd.png (+ .json): листы из
##           textures/src/hd/props_v4/ режутся на предметы, каждый печётся в
##           свой размер в мире (TS текселей на px). Для каждого по альфе
##           считается подножие: где у основания арта плотно (туда коллизия),
##           а где пролом (у прорванных завалов — проход посередине).
##           Прорванные завалы режутся на левую и правую половины.
##           Потом: godot --headless --path . --import
##   apply — правит сцену (узлы с метой route_v1 удаляются и строятся заново):
##           1) линии баррикад (BARRIERS из holmvik_blockout.gd): старые кучки
##              хлама BO_Junk* и полосы Barrier* убираются; каждый закрытый
##              отрезок линии — колонна высоких завалов во всю ширину, коллизия
##              по ширине колонны; в проходе — прорыв: половины разбитого завала
##              по краям улицы, на земле щиты и обломки;
##           2) щели между домами, стоящими рядом в одном ряду (уже COVER_GAP),
##              закрываются заглушками (забор с калиткой, поленница, навес...)
##              в ширину щели, с коллизией от стены до стены. Щели, через
##              которые идёт маршрут, не трогаются;
##           3) след стражи Бальдра вдоль маршрута (TRAIL): горящие святилища
##              Бальдра с лампадой и тёплым светом ведут к храму, указатели с
##              солнцем на поворотах, щиты и знамёна стражи там, где она
##              держалась, трофеи Ордена над её щитами.
## Порядок: holmvik_blockout.gd apply → … → holmvik_route.gd apply →
## bake_navmesh.gd (+ place_order.gd -- dry: точки врагов ещё свободны).
## Сцена сохраняется через PackedScene с GEN_EDIT_STATE_MAIN (инстансы врагов
## и костров остаются инстансами).

const AU := preload("res://tools/art_util.gd")
const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const SRC := TEX + "src/hd/props_v4/"
const ATLAS := TEX + "town_route_hd.png"
const META := TEX + "town_route_hd.json"
const TONE_REF := TEX + "town_art3_hd.png"
const TS := 2.5
const ATLAS_W := 4096
const SHARPEN := 0.25
const TONE_MIX := 0.15
const META_TAG := "route_v1"

## Лист: [[имя, "w"|"h", размер в px мира], ...] в порядке предметов на листе
## (ряды сверху вниз, в ряду слева направо). "split" — прорыв: режется на
## половины _l и _r по самому низкому месту посередине
const SHEETS := {
	"barricades_v2": [["bar2_wagon", "w", 140.0], ["bar2_wall", "w", 140.0], ["bar2_burning", "w", 140.0],
		["bar2_house", "w", 145.0], ["bar2_stakes", "w", 135.0], ["bar2_rubble", "w", 140.0]],
	"alley_closers": [["ac_gate", "h", 96.0], ["ac_wattle", "h", 88.0], ["ac_woodshed", "h", 96.0],
		["ac_leanto", "h", 100.0], ["ac_crates", "h", 90.0], ["ac_burnt", "h", 90.0], ["ac_stone", "h", 100.0]],
	"breaches": [["br_wagon", "split", 250.0], ["br_wall", "split", 250.0], ["br_stakes", "split", 250.0],
		["br_burnt", "split", 250.0], ["br_shields", "split", 250.0]],
	"trail": [["tr_shield", "w", 40.0], ["tr_spear", "w", 54.0], ["tr_banner", "w", 78.0],
		["tr_shrine", "h", 70.0], ["tr_shrine_broken", "w", 66.0], ["tr_sign", "h", 62.0],
		["tr_trophy", "h", 92.0], ["tr_blood", "w", 130.0]],
}

## Подножие: доля высоты самой высокой колонки, с которой столбец — завал
const FOOT_SOLID := 0.45

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["atlas"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[holmvik_route] ", r)
	quit()


# ───────────────────────── atlas ─────────────────────────

func _step_atlas() -> void:
	var ref := (load(TONE_REF) as Texture2D).get_image()
	ref.decompress()
	ref.convert(Image.FORMAT_RGBA8)
	var target := AU.mean_color(ref)
	var items := []
	for sheet in SHEETS:
		var img := AU.load_hd(SRC, sheet)
		if img == null:
			report.append("нет листа %s" % sheet)
			continue
		img = AU.clean_edges(img)
		var boxes := _components(img)
		var names: Array = SHEETS[sheet]
		if boxes.size() != names.size():
			report.append("ОТКАЗ %s: найдено %d предметов, ждали %d: %s" % [sheet, boxes.size(), names.size(), boxes])
			continue
		for i in names.size():
			var spec: Array = names[i]
			var part := AU.keep_main(img.get_region(boxes[i]), 0.02)
			if spec[1] == "split":
				var cut := _split_column(part)
				var halves := {"_l": part.get_region(Rect2i(0, 0, cut, part.get_height())),
					"_r": part.get_region(Rect2i(cut, 0, part.get_width() - cut, part.get_height()))}
				var k := float(spec[2]) * TS / part.get_width()
				for suf in halves:
					var hp: Image = halves[suf]
					var used := hp.get_used_rect()
					hp = hp.get_region(used)
					items.append({"name": spec[0] + suf, "img": _bake(hp, k, target)})
			else:
				var k := float(spec[2]) * TS / (part.get_width() if spec[1] == "w" else part.get_height())
				items.append({"name": spec[0], "img": _bake(part, k, target)})
		report.append("%s: %s" % [sheet, ", ".join(names.map(func(n): return n[0]))])
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
	var meta := {"_ts": TS}
	for it in items:
		var r: Rect2i = placed[it.name]
		atlas.blit_rect(it.img, Rect2i(Vector2i.ZERO, r.size), r.position)
		var foot := _foot(it.img)
		meta[it.name] = [r.position.x, r.position.y, r.size.x, r.size.y, foot.x, foot.y]
		report.append("  %s: %.0fx%.0f px мира, подножие %.2f..%.2f" % [it.name, r.size.x / TS, r.size.y / TS, foot.x, foot.y])
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	AU.write_import(ATLAS, false)
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	report.append("atlas: %d предметов, %dx%d (%s); дальше --import" % [placed.size(), ATLAS_W, ah, error_string(err)])


func _bake(img: Image, k: float, target: Color) -> Image:
	var w := maxi(int(round(img.get_width() * k)), 4)
	var h := maxi(int(round(img.get_height() * k)), 4)
	var out := AU.resize_clean(img, w, h)
	out = AU.unsharp(out, SHARPEN)
	var m := AU.mean_color(out)
	return AU.match_tone(out, m.lerp(target, TONE_MIX))


## Столбец разреза прорыва: в средней трети — где куча ниже всего
func _split_column(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var best := w / 2
	var best_h := h + 1
	for x in range(w / 3, w * 2 / 3, 2):
		var top := h
		for y in range(0, h, 2):
			if img.get_pixel(x, y).a > 0.5:
				top = y
				break
		var height := h - top
		if height < best_h:
			best_h = height
			best = x
	return best


## Подножие предмета: доли ширины [от, до], где куча высокая — высота
## плотной альфы в столбце не меньше FOOT_SOLID от самой высокой (низкий
## хвост обломков у прорыва проходим — туда коллизия не идёт)
func _foot(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var cnt := PackedInt32Array()
	cnt.resize(w)
	var best := 1
	for x in w:
		var c := 0
		for y in range(0, h, 2):
			if img.get_pixel(x, y).a > 0.5:
				c = h - y
				break
		cnt[x] = c
		best = maxi(best, c)
	var a := 0
	while a < w - 1 and cnt[a] < best * FOOT_SOLID:
		a += 1
	var b := w - 1
	while b > a and cnt[b] < best * FOOT_SOLID:
		b -= 1
	return Vector2(snappedf(float(a) / w, 0.001), snappedf(float(b + 1) / w, 0.001))


## Прямоугольники предметов: связные области альфы на сетке 4 px с
## расширением на 3 клетки; мелкие (< 4% крупнейшей) — к ближайшей крупной.
## Порядок — ряды сверху вниз, в ряду слева направо (как holmvik_art2.gd)
func _components(img: Image) -> Array:
	return _components_p(img, 0, 0.3)


func _components_p(img: Image, r: int, thr: float) -> Array:
	var cell := 4
	var gw := img.get_width() / cell
	var gh := img.get_height() / cell
	var occ := PackedByteArray()
	occ.resize(gw * gh)
	for gy in gh:
		for gx in gw:
			var on := 0
			for dy in range(0, cell, 2):
				for dx in range(0, cell, 2):
					if img.get_pixel(gx * cell + dx, gy * cell + dy).a > thr:
						on = 1
			occ[gy * gw + gx] = on
	var dil := PackedByteArray()
	dil.resize(gw * gh)
	for gy in gh:
		for gx in gw:
			if occ[gy * gw + gx] == 0:
				continue
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var x := gx + dx
					var y := gy + dy
					if x >= 0 and y >= 0 and x < gw and y < gh:
						dil[y * gw + x] = 1
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
		if area > 0:
			comps.append([Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), area])
	var big := 0
	for c in comps:
		big = maxi(big, c[1])
	var mains := []
	var smalls := []
	for c in comps:
		(mains if c[1] >= big * 0.04 else smalls).append(c)
	for s in smalls:
		var best := 0
		var bd := INF
		for i in mains.size():
			var d := Vector2(s[0].get_center()).distance_to(Vector2(mains[i][0].get_center()))
			if d < bd:
				bd = d
				best = i
		if not mains.is_empty():
			mains[best][0] = (mains[best][0] as Rect2i).merge(s[0])
	mains.sort_custom(func(a, b): return a[0].get_center().y < b[0].get_center().y)
	var rows := []
	for m in mains:
		if rows.is_empty():
			rows.append([m])
			continue
		var row: Array = rows[rows.size() - 1]
		var top := INF
		var hmax := 0
		for q in row:
			top = minf(top, q[0].position.y)
			hmax = maxi(hmax, q[0].size.y)
		if m[0].position.y > top + hmax * 0.55:
			rows.append([m])
		else:
			row.append(m)
	var out := []
	for row in rows:
		row.sort_custom(func(a, b): return a[0].position.x < b[0].position.x)
		for m in row:
			var b: Rect2i = m[0]
			out.append(Rect2i(b.position * cell, b.size * cell).grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	return out


# ───────────────────────── apply ─────────────────────────

## Маршрут героя (навмеш спавн → врата арены), для щелей и следа стражи
const ROUTE := [
	Vector2(1150, 2530), Vector2(1046, 2466), Vector2(785, 2306), Vector2(723, 2268),
	Vector2(119, 2200), Vector2(-95, 2175), Vector2(-264, 2134), Vector2(-638, 2042),
	Vector2(-1134, 1998), Vector2(-1630, 1950), Vector2(-1869, 1896), Vector2(-1871, 1810),
	Vector2(-1875, 1644), Vector2(-1861, 1469), Vector2(-1855, 1329), Vector2(-1865, 1292),
	Vector2(-1910, 1142), Vector2(-1944, 1025), Vector2(-1951, 899), Vector2(-1938, 718),
	Vector2(-1933, 662), Vector2(-1795, 662), Vector2(-916, 668), Vector2(-631, 888),
	Vector2(-631, 1004), Vector2(-648, 1118), Vector2(-648, 1164), Vector2(-576, 1229),
	Vector2(-467, 1283), Vector2(-294, 1370), Vector2(-69, 1484), Vector2(116, 1492),
	Vector2(184, 1492), Vector2(351, 1450), Vector2(428, 1434), Vector2(705, 1378),
	Vector2(912, 1335), Vector2(1090, 1300),
]
## Линии баррикад — как в holmvik_blockout.gd: [x, проход по y]
const BARRIERS := [
	[-950.0, Vector2(560, 690)],
	[150.0, Vector2(1470, 1610)],
]
const WALL_N := -600.0
const WALL_S := 1880.0
const COVER_MIN := 40.0
## Колонна завалов: шаг рядов по y, ширина спрайта, полуширина коллизии
const BAR_KEYS := ["bar2_wagon", "bar2_wall", "bar2_burning", "bar2_house", "bar2_stakes", "bar2_rubble"]
const BAR_STEP := 34.0
const BAR_W := 118.0
const BAR_HALF := 46.0
## Щели между домами: уже GAP_ART — только коллизия (дома и так сомкнуты
## на картинке, но капсула героя радиусом 5 px туда пролезала); до GAP_MAX —
## заглушка-арт; шире — это улица
const GAP_ART := 34.0
const GAP_MAX := 150.0
const CLOSERS := ["ac_gate", "ac_wattle", "ac_woodshed", "ac_leanto", "ac_crates", "ac_burnt", "ac_stone"]
## След стражи: [расстояние по маршруту, что, сторона (+1/-1/0 — любая)].
## Святилища с лампадой — каждые ~700 px: огоньки Бальдра ведут к храму.
## Указатели — где путь поворачивает на восток/запад. Щиты, копья, знамёна и
## кровь — там, где стража держалась (у отрядов Ордена), трофеи Ордена над
## её щитами — у ворот, на площади, у храма
const TRAIL := [
	[260.0, "tr_shrine", 1], [420.0, "tr_sign", 1],
	[820.0, "tr_shield", 0], [880.0, "tr_blood", 0], [960.0, "tr_spear", 0], [1040.0, "tr_shrine", -1],
	[1750.0, "tr_shrine", 1], [2350.0, "tr_banner", 0], [2450.0, "tr_shield", 0],
	[2620.0, "tr_shrine", -1], [3060.0, "tr_trophy", 1], [3200.0, "tr_blood", 0],
	[3330.0, "tr_shrine", 1], [3620.0, "tr_shield", 0], [3700.0, "tr_spear", 0],
	[4100.0, "tr_shrine", -1], [4560.0, "tr_sign", 1], [4800.0, "tr_shrine", 1],
	[5300.0, "tr_banner", 0], [5380.0, "tr_blood", 0], [5470.0, "tr_shield", 0],
	[5560.0, "tr_shrine", -1], [5930.0, "tr_trophy", -1], [6060.0, "tr_spear", 0],
	[6280.0, "tr_shrine", 1], [6760.0, "tr_sign", -1], [6900.0, "tr_shield", 0],
	[6980.0, "tr_blood", 0], [7060.0, "tr_shrine", 1], [7420.0, "tr_banner", 0],
	[7560.0, "tr_trophy", 1], [7640.0, "tr_shield", 0],
]
## Плоское (лежит на земле) — в RouteDecals перед Objects, под героем
const FLAT := ["tr_shield", "tr_spear", "tr_banner", "tr_blood", "tr_shrine_broken"]

var _meta: Dictionary
var _tex: Texture2D
var _houses: Array[Rect2] = []
var _blocked: Array[Rect2] = []


func _step_apply() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_tex = load(ATLAS) as Texture2D
	if _tex == null or _meta.is_empty():
		report.append("ОШИБКА: нет атласа — atlas, потом --import")
		return
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	if lvl.get_node("Ground").get("material") == null:
		report.append("ОШИБКА: материал земли не загрузился — сначала --import")
		lvl.free()
		return
	var objects := lvl.get_node("Objects")
	var night := lvl.get_node("Night")
	# 0. Убрать прежнее своё и старые кучки хлама/полосы блокаута
	var removed := 0
	for parent in [objects, night, lvl]:
		for n in parent.get_children():
			if n.has_meta(META_TAG) or (parent == objects and String(n.name).begins_with("BO_Junk")):
				parent.remove_child(n)
				n.free()
				removed += 1
	var walls := lvl.get_node_or_null("Blockout/Walls")
	if walls:
		for n in walls.get_children():
			if String(n.name).begins_with("Barrier"):
				walls.remove_child(n)
				n.free()
				removed += 1
	report.append("убрано старого: %d" % removed)
	_collect_houses(lvl)
	var body := StaticBody2D.new()
	body.name = "RouteWalls"
	body.set_meta(META_TAG, true)
	lvl.add_child(body)
	body.owner = lvl
	var decals := Node2D.new()
	decals.name = "RouteDecals"
	decals.set_meta(META_TAG, true)
	lvl.add_child(decals)
	lvl.move_child(decals, objects.get_index())
	decals.owner = lvl
	# 1. Линии баррикад
	var rows := 0
	for b in BARRIERS:
		var x: float = b[0]
		var pass_y: Vector2 = b[1]
		for seg in _segments(lvl, x, pass_y):
			var y0: float = seg[0]
			var y1: float = seg[1]
			if y1 - y0 < 8.0:
				continue
			var r := Rect2(x - BAR_HALF, y0 - 6.0, BAR_HALF * 2.0, y1 - y0 + 12.0)
			_shape(body, lvl, "Bar%d_%d" % [int(x), int(y0)], r)
			_blocked.append(r)
			var y := y0 + 22.0
			var k := 0
			while y <= y1 + 12.0:
				# Внутри картинки дома (его коллизия у́же арта) хлам не рисуем —
				# иначе завал ложится поверх крыши; коллизия остаётся
				if _in_house_art(Vector2(x, y)):
					k += 1
					y += BAR_STEP
					continue
				var key: String = BAR_KEYS[int(_hash(int(x) + k * 7, int(y)) * BAR_KEYS.size()) % BAR_KEYS.size()]
				var w := BAR_W * lerpf(0.92, 1.08, _hash(k, int(y)))
				var s := _sprite(objects, lvl, key, Vector2(x + (_hash(int(y), k) - 0.5) * 14.0, y), w / _w(key), "RBar")
				s.flip_h = _hash(int(y) + 3, k) > 0.5
				rows += 1
				k += 1
				y += BAR_STEP
		# Проход: разбитый завал по краям улицы, на земле — щиты, обломки
		# Северный проход — прорубленная стена из дверей; у храма — павшая
		# стена щитов стражи (здесь она держалась до последнего)
		var br: String = "br_wall" if x < 0.0 else "br_shields"
		var sl := _sprite(objects, lvl, br + "_l", Vector2(x - 6.0, pass_y.x + 16.0), 0.85, "RBreach")
		_foot_body(sl, lvl, 12.0)
		var sr := _sprite(objects, lvl, br + "_r", Vector2(x + 6.0, pass_y.y + 4.0), 0.85, "RBreach")
		_foot_body(sr, lvl, 12.0)
		var mid := (pass_y.x + pass_y.y) * 0.5
		_sprite(decals, lvl, "tr_shield", Vector2(x - 24.0, mid - 10.0), 1.0, "RDecal")
		_sprite(decals, lvl, "tr_spear", Vector2(x + 20.0, mid + 16.0), 1.0, "RDecal").flip_h = true
		report.append("баррикада x%.0f: проход %s, завал %s" % [x, pass_y, br])
	report.append("завалы: %d рядов" % rows)
	# 2. Щели между домами
	var n_art := 0
	var n_seal := 0
	for g in _gaps():
		var gap: Rect2 = g
		if _route_hits(gap.grow(8.0)) or _near_barrier(gap):
			continue
		_shape(body, lvl, "Gap%d_%d" % [int(gap.position.x), int(gap.position.y)], gap.grow_individual(3, 0, 3, 0))
		if gap.size.x < GAP_ART:
			n_seal += 1
			continue
		var key := _closer_for(gap.size.x)
		var fw: float = _w(key) * _foot_frac(key)
		var sc := clampf((gap.size.x + 12.0) / fw, 0.6, 1.6)
		var f: Array = _meta[key]
		var foot_c: float = (float(f[4]) + float(f[5])) * 0.5 - 0.5
		var base := Vector2(gap.get_center().x - foot_c * _w(key) * sc, gap.end.y - 2.0)
		var s := _sprite(objects, lvl, key, base, sc, "RGap")
		s.flip_h = _hash(int(base.x), int(base.y)) > 0.5
		if s.flip_h:
			s.position.x = gap.get_center().x + foot_c * _w(key) * sc
		n_art += 1
	report.append("щели между домами: заглушек %d, сомкнуто коллизией %d" % [n_art, n_seal])
	# 3. След стражи
	var lantern := night.get_node_or_null("LanternTown0") as PointLight2D
	var placed := 0
	var shrines := 0
	for t in TRAIL:
		var p := _trail_point(float(t[0]), int(t[2]))
		if not p.is_finite():
			report.append("  след: нет места у d=%.0f (%s)" % [t[0], t[1]])
			continue
		var key: String = t[1]
		var parent: Node = decals if key in FLAT else objects
		var s := _sprite(parent, lvl, key, p, 1.0, "RTrail")
		var tan := _route_tangent(float(t[0]))
		if key == "tr_sign":
			# Стрелка на картинке смотрит вправо — по ходу к храму
			s.flip_h = tan.x < 0.0
		elif key in FLAT:
			s.flip_h = _hash(int(p.x), int(p.y)) > 0.5
			s.rotation = (_hash(int(p.y), int(p.x)) - 0.5) * 0.5
		if key == "tr_shrine" or key == "tr_trophy" or key == "tr_sign":
			_foot_body(s, lvl, 8.0)
		if key == "tr_shrine" and lantern:
			var l := lantern.duplicate() as PointLight2D
			l.name = "LanternShrine%d" % shrines
			l.position = p + Vector2(_w(key) * 0.32 * (-1.0 if s.flip_h else 1.0), -_h(key) * 0.5)
			l.energy = 0.65
			l.texture_scale = lantern.texture_scale * 0.8
			l.set_meta(META_TAG, true)
			l.remove_meta("town_v2")
			night.add_child(l)
			l.owner = lvl
			shrines += 1
		placed += 1
	report.append("след стражи: %d предметов, святилищ с огнём %d" % [placed, shrines])
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	report.append("сцена сохранена (%s); дальше bake_navmesh.gd" % error_string(err))
	lvl.free()


var _house_art: Array[Rect2] = []


func _in_house_art(p: Vector2) -> bool:
	for r in _house_art:
		if r.has_point(p):
			return true
	return false


## Подножия домов (и прочих крупных стен) из коллизии карты; картинки домов
## (без самой верхушки — там небо над коньком)
func _collect_houses(lvl: Node) -> void:
	_houses.clear()
	_house_art.clear()
	for n in lvl.get_node("Objects").get_children():
		if n is Sprite2D and (n.has_meta("town_v2") or n.has_meta("village_v2") or n.has_meta("house")):
			var s := n as Sprite2D
			var r := s.get_rect()
			var bb := Rect2(s.transform * r.position, Vector2.ZERO).expand(s.transform * r.end).abs()
			_house_art.append(Rect2(bb.position.x + bb.size.x * 0.06, bb.position.y + bb.size.y * 0.08,
				bb.size.x * 0.88, bb.size.y * 0.92))
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		if s == null or s.size.x < 70.0 or s.size.y < 24.0:
			continue
		var o: Vector2 = (xfs[i] as Transform2D).origin
		_houses.append(Rect2(o - s.size * 0.5, s.size))


## Отрезки линии баррикады, не закрытые домами (как в holmvik_blockout.gd)
func _segments(lvl: Node, x: float, passage: Vector2) -> Array:
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	var cover: Array = []
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		if s == null or minf(s.size.x, s.size.y) < COVER_MIN * 0.5 or maxf(s.size.x, s.size.y) < COVER_MIN:
			continue
		var o: Vector2 = (xfs[i] as Transform2D).origin
		if absf(o.x - x) <= s.size.x * 0.5:
			cover.append(Vector2(o.y - s.size.y * 0.5, o.y + s.size.y * 0.5))
	cover.append(passage)
	cover.sort_custom(func(a, b): return a.x < b.x)
	var segs: Array = []
	var y := WALL_N
	for c in cover:
		if c.x > y + 6.0:
			segs.append([y, minf(c.x, WALL_S)])
		y = maxf(y, c.y)
		if y >= WALL_S:
			break
	if y < WALL_S - 6.0:
		segs.append([y, WALL_S])
	return segs


## Щели между соседними домами одного ряда: прямоугольник от стены до стены
## по высоте, где подножия обоих домов перекрываются
func _gaps() -> Array:
	var out: Array = []
	for a in _houses:
		var best := INF
		var bb := Rect2()
		for b in _houses:
			if b == a or b.position.x <= a.end.x - 1.0:
				continue
			var oy := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
			if oy < minf(a.size.y, b.size.y) * 0.6:
				continue
			var gap := b.position.x - a.end.x
			if gap < best:
				best = gap
				bb = b
		if best < 2.0 or best > GAP_MAX:
			continue
		var y0 := maxf(a.position.y, bb.position.y)
		var y1 := minf(a.end.y, bb.end.y)
		var r := Rect2(a.end.x, y0, best, y1 - y0)
		# Уже закрыто чем-то ещё (другой дом посередине)?
		var covered := false
		for c in _houses:
			if c != a and c != bb and c.intersects(r.grow(-2.0)):
				covered = true
				break
		if not covered:
			out.append(r)
	return out


func _near_barrier(r: Rect2) -> bool:
	for b in BARRIERS:
		if absf(r.get_center().x - float(b[0])) < BAR_HALF + r.size.x * 0.5 + 10.0:
			return true
	return false


func _route_hits(r: Rect2) -> bool:
	for i in range(1, ROUTE.size()):
		var a: Vector2 = ROUTE[i - 1]
		var b: Vector2 = ROUTE[i]
		var n := int(ceil(a.distance_to(b) / 6.0))
		for j in n + 1:
			if r.has_point(a.lerp(b, float(j) / maxf(n, 1))):
				return true
	return false


## Заглушка под ширину щели: та, чьё подножие ближе всего по ширине
func _closer_for(width: float) -> String:
	var best := ""
	var bd := INF
	for k in CLOSERS:
		var d := absf(_w(k) * _foot_frac(k) - (width + 12.0)) * lerpf(0.9, 1.1, _hash(int(width), k.length()))
		if d < bd:
			bd = d
			best = k
	return best


func _route_point(d: float) -> Vector2:
	var acc := 0.0
	for i in range(1, ROUTE.size()):
		var a: Vector2 = ROUTE[i - 1]
		var b: Vector2 = ROUTE[i]
		var l := a.distance_to(b)
		if acc + l >= d:
			return a.lerp(b, (d - acc) / maxf(l, 0.001))
		acc += l
	return ROUTE[ROUTE.size() - 1]


func _route_tangent(d: float) -> Vector2:
	return (_route_point(d + 30.0) - _route_point(maxf(d - 30.0, 0.0))).normalized()


## Точка сбоку от маршрута (у края улицы), не в доме и не в завале
func _trail_point(d: float, side: int) -> Vector2:
	var p := _route_point(d)
	var n := _route_tangent(d).orthogonal()
	var sides := [side] if side != 0 else [1, -1]
	if side != 0:
		sides.append(-side)
	var offs := [0.0, 22.0, 40.0, 56.0] if side == 0 else [50.0, 40.0, 62.0, 30.0]
	for off in offs:
		for sd in sides:
			var q: Vector2 = p + n * float(off) * float(sd)
			var ok := true
			for r in _houses + _blocked:
				if (r as Rect2).grow(14.0).has_point(q):
					ok = false
					break
			if ok:
				return q
	return Vector2.INF


func _w(key: String) -> float:
	return float(_meta[key][2]) / TS


func _h(key: String) -> float:
	return float(_meta[key][3]) / TS


func _foot_frac(key: String) -> float:
	var f: Array = _meta[key]
	return maxf(float(f[5]) - float(f[4]), 0.05)


func _sprite(parent: Node, lvl: Node, key: String, base: Vector2, sc: float, prefix: String) -> Sprite2D:
	var r: Array = _meta[key]
	var s := Sprite2D.new()
	s.name = "%s_%s_%d_%d" % [prefix, key, int(base.x), int(base.y)]
	s.texture = _tex
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.centered = false
	s.scale = Vector2.ONE * sc / TS
	s.offset = Vector2(-float(r[2]) * 0.5, -float(r[3]) + 4.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = base
	s.set_meta(META_TAG, key)
	parent.add_child(s)
	s.owner = lvl
	return s


## Коллизия по подножию предмета: плотная часть ширины, depth px в глубину
func _foot_body(s: Sprite2D, lvl: Node, depth: float) -> void:
	var key := String(s.get_meta(META_TAG))
	var f: Array = _meta[key]
	var w: float = _w(key) * s.scale.x * TS
	var a: float = float(f[4]) - 0.5
	var b: float = float(f[5]) - 0.5
	if s.flip_h:
		var t := -b
		b = -a
		a = t
	var body := StaticBody2D.new()
	body.name = "Body"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2((b - a) * w, depth) / s.scale
	cs.shape = shape
	cs.position = Vector2((a + b) * 0.5 * w, -depth * 0.5) / s.scale
	s.add_child(body)
	body.owner = lvl
	body.add_child(cs)
	cs.owner = lvl
	_blocked.append(Rect2(s.position + Vector2(a * w, -depth), Vector2((b - a) * w, depth)))


func _shape(body: StaticBody2D, lvl: Node, nm: String, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	cs.name = nm
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	body.add_child(cs)
	cs.owner = lvl


static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 10000) / 10000.0
