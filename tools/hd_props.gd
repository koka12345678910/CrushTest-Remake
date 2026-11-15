extends SceneTree
## Чёткие мосты, суда и пропсы (src/hd/bridges|boats|props) вместо старых
## спрайтов на reference_map и в лагере (ruined_camp.tscn).
##
## Каждый старый спрайт (Sprite2D или тайл слоя) узнаётся по куску своего
## атласа ("файл|x,y,w,h") и по таблице MAP получает новую картинку. Новая
## вписывается в видимый контур старой (по альфе) — по ширине (или высоте, или
## растяжкой) и садится на ту же точку: низ (стоит на земле), верх (настил
## моста — по нему ходят), центр (лодка, кувшинки). Поэтому коллизия, навмеш,
## y-sort и свет не меняются. Новая картинка запекается ровно в плотности
## старой (1 тексель старого = 1 тексель нового), так что масштаб узлов и
## тайлов не трогается.
##
## Шаги:
##   atlas — листы режутся на предметы по прозрачности (порядок: ряды сверху
##           вниз, в ряду слева направо — см. PIECES), для каждой пары
##           «старый кусок → новая картинка» запекается свой размер →
##           textures/hd_props.png (+ .json, + .import с BPTC). Затем импорт.
##   apply — подмена в сценах (сцены сохраняются на месте).
##
## Запуск:
##   godot --headless --path . -s res://tools/hd_props.gd -- atlas
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/hd_props.gd -- apply

const BT := preload("res://tools/build_terrain.gd")
const SCENES := ["res://reference_map_level/reference_map.tscn", "res://reference_map_level/ruined_camp.tscn"]
const HD := "res://reference_map_level/textures/src/hd/"
const OLD := "res://reference_map_level/textures/"
const ATLAS := "res://reference_map_level/textures/hd_props.png"
const META := "res://reference_map_level/textures/hd_props.json"
const ATLAS_W := 4096
const PAD := 2

## Новые картинки: [файл, номер предмета в листе (-1 — вся картинка), половина]
const PIECES := {
	"bridge_wood": ["bridges/wooden_bridge_mossy.png", -1],
	"pier_long": ["bridges/wooden_bridge_ropes.png", -1],
	"viaduct": ["bridges/stone_viaduct.png", -1],
	"rope_bridge": ["bridges/rope_bridge.png", -1],
	"bridge_broken_w": ["bridges/stone_bridge_broken.png", 0],
	"bridge_broken_e": ["bridges/stone_bridge_broken.png", 1],
	"bridge_pier": ["bridges/stone_bridge_broken.png", 2],
	"rubble_a": ["bridges/stone_bridge_broken.png", 3],
	"rubble_b": ["bridges/stone_bridge_broken.png", 4],
	"rubble_c": ["bridges/stone_bridge_broken.png", 5],
	"jetty_short": ["bridges/jetties.png", 0],
	"jetty_long": ["bridges/jetties.png", 4],
	"railing_long": ["bridges/jetties.png", 5],
	"railing_mid": ["bridges/jetties.png", 6],
	"longship": ["boats/longship.png", -1],
	"boat_sail": ["boats/boats.png", 0],
	"boat_row": ["boats/boats.png", 1],
	"boat_leaky": ["boats/boats.png", 2],
	"port_net": ["props/port.png", 0],
	"port_rope": ["props/port.png", 1],
	"port_crane": ["props/port.png", 2],
	"port_lantern": ["props/port.png", 5],
	"port_crates_tarp": ["props/port.png", 6],
	"port_bollard": ["props/port.png", 8],
	"tower": ["props/towers.png", 0],
	"tower_damaged": ["props/towers.png", 1],
	"tower_beacon": ["props/towers.png", 2],
	"barrel": ["props/village.png", 0],
	"barrels2": ["props/village.png", 1],
	"crate": ["props/village.png", 3],
	"crates_stack": ["props/village.png", 4],
	"sacks": ["props/village.png", 5],
	"chest": ["props/village.png", 6],
	"bucket": ["props/village.png", 7],
	"gallows": ["props/village.png", 9],
	"scarecrow": ["props/village.png", 10],
	"shrine": ["props/village.png", 12],
	"reeds_big": ["props/water_plants.png", 0],
	"reeds_m": ["props/water_plants.png", 1],
	"reeds_s": ["props/water_plants.png", 2],
	"lily_a": ["props/water_plants.png", 3],
	"lily_b": ["props/water_plants.png", 4],
	"lily_small": ["props/water_plants.png", 5],
	"lily_tiny": ["props/water_plants.png", 6],
	"fountain": ["props/fountain.png", -1],
	"tent_cone": ["props/camp.png", 0],
	"tent_cone_red": ["props/camp.png", 1],
	"tent_ridge": ["props/camp.png", 2],
	"tent_ridge_red": ["props/camp.png", 3],
	"palisade_broken": ["props/camp.png", 4],
	"stake_a": ["props/camp.png", 5, "left"],
	"stake_b": ["props/camp.png", 5, "right"],
	"palisade": ["props/camp.png", 6],
	"palisade_gap": ["props/camp.png", 7],
	"banner": ["props/camp.png", 8],
	"wagon": ["props/camp.png", 9],
	"cart_broken": ["props/camp.png", 10],
	"weapon_rack": ["props/camp.png", 11],
	"armor_stand": ["props/camp.png", 12],
	"pile_a": ["props/camp.png", 13],
	"pile_b": ["props/camp.png", 14],
}

## Старый кусок → [новые картинки (вариант по хэшу места), посадка, множитель]
## Посадка: b — низ по низу, ширина; h — низ по низу, высота; t — верх по
## верху, ширина; c — центр, ширина; s — растянуть в контур старого.
const MAP := {
	# мосты
	"fort_port_art.png|0,1464,450,216": [["bridge_wood"], "t", 1.0],
	"fort_port_art.png|716,1132,844,264": [["viaduct"], "t", 1.0],
	"ruin_art.png|194,462,318,264": [["bridge_broken_w"], "t", 1.0],
	"ruin_art.png|516,462,304,264": [["bridge_broken_e"], "t", 1.0],
	"ruin_art.png|716,748,80,162": [["bridge_pier"], "b", 1.0],
	"ruin_art.png|1496,934,290,122": [["rubble_a"], "b", 1.0],
	"ruin_art.png|1508,1068,100,108": [["rubble_c"], "b", 1.0],
	"ruin_art.png|1952,1188,76,92": [["rubble_b"], "b", 1.0],
	"ruin_art.png|0,934,636,130": [["rope_bridge"], "c", 1.0],
	# причалы и перила
	"fort_port_art.png|0,0,248,1128": [["pier_long"], "s", 1.0],
	"fort_port_art.png|0,1842,316,130": [["jetty_short"], "s", 1.0],
	"fort_port_art.png|1450,1684,524,130": [["jetty_long"], "s", 1.0],
	"bridges.png|584,882,206,30": [["railing_long"], "b", 1.0],
	"bridges.png|584,882,130,30": [["railing_mid"], "b", 1.0],
	"bridges.png|584,882,110,30": [["railing_mid"], "b", 1.0],
	# суда
	"fort_port_art.png|0,1132,430,328": [["longship"], "b", 1.0],
	"fort_port_art.png|498,1464,222,186": [["boat_sail"], "b", 1.0],
	"fort_port_art.png|764,1842,244,72": [["boat_row", "boat_leaky"], "c", 1.0],
	# порт
	"fort_port_art.png|1516,0,284,366": [["port_crane"], "b", 1.0],
	"fort_port_art.png|1220,1684,226,152": [["port_net"], "b", 1.0],
	"fort_port_art.png|544,1842,108,80": [["port_rope"], "c", 1.0],
	"fort_port_art.png|1012,1842,28,32": [["port_bollard"], "b", 1.2],
	"fort_port_art.png|320,1842,24,80": [["port_lantern"], "h", 1.0],
	"fort_port_art.png|656,1842,60,76": [["crate"], "b", 1.0],
	"ruin_art.png|692,1188,152,98": [["port_crates_tarp"], "b", 1.0],
	# башни форта
	"fort_port_art.png|434,1132,140,286": [["tower"], "b", 1.0],
	"fort_port_art.png|578,1132,134,286": [["tower_damaged"], "b", 1.0],
	"fort_port_art.png|1564,1132,136,264": [["tower_beacon"], "b", 1.0],
	# вода
	"fort_port_art.png|416,1976,32,20": [["lily_small", "lily_tiny"], "c", 1.6],
	"watertiles.png|0,704,56,52": [["reeds_m", "reeds_big"], "b", 1.5],
	"watertiles.png|128,704,56,52": [["reeds_s", "reeds_m"], "b", 1.5],
	"watertiles.png|0,704,56,64": [["reeds_m"], "b", 1.5],
	"watertiles.png|128,704,56,64": [["reeds_s"], "b", 1.5],
	"watertiles.png|0,908,48,36": [["lily_a", "lily_b"], "c", 1.5],
	"watertiles.png|128,908,48,36": [["lily_b", "lily_small"], "c", 1.5],
	# деревня
	"ruin_art.png|1002,1476,60,76": [["crate"], "b", 1.0],
	"ruin_art.png|1086,1188,84,96": [["crate"], "b", 1.0],
	"ruin_art.png|1080,748,102,146": [["crates_stack"], "b", 1.0],
	"ruin_art.png|1438,462,130,190": [["crates_stack"], "b", 1.0],
	"ruin_art.png|1572,462,148,188": [["barrels2"], "b", 1.0],
	"ruin_art.png|1724,462,148,188": [["barrels2"], "b", 1.0],
	"ruin_art.png|190,748,112,178": [["barrels2"], "b", 1.0],
	"ruin_art.png|1720,1294,118,84": [["chest"], "b", 1.0],
	"ruin_art.png|672,1388,62,82": [["bucket"], "b", 1.0],
	"ruin_art.png|862,1476,136,76": [["sacks"], "b", 1.0],
	"ruin_art.png|808,0,194,318": [["gallows"], "b", 1.0],
	"farm_fields.png|1080,0,72,120": [["scarecrow"], "b", 1.0],
	"shrine_fountain.png|0,0,320,256": [["fountain"], "b", 1.0],
	"port_town.png|352,444,32,68": [["shrine"], "h", 1.3],
	# лагерь
	"camp_sprites.png|0,0,832,602": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|820,1224,276,204": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|1768,606,392,304": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|2164,606,398,302": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|1382,1224,272,202": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|532,1224,284,206": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|0,918,404,302": [["tent_cone"], "b", 1.0],
	"camp_sprites.png|2280,0,376,310": [["tent_cone_red"], "b", 1.0],
	"camp_sprites.png|1100,1224,278,204": [["tent_cone_red"], "b", 1.0],
	"camp_sprites.png|442,606,392,308": [["tent_cone_red"], "b", 1.0],
	"camp_sprites.png|238,1224,290,208": [["tent_cone_red"], "b", 1.0],
	"camp_sprites.png|0,606,438,308": [["tent_ridge"], "b", 1.0],
	"camp_sprites.png|546,918,498,300": [["tent_ridge"], "b", 1.0],
	"camp_sprites.png|1606,0,670,418": [["tent_ridge"], "b", 1.0],
	"camp_sprites.png|2566,606,484,302": [["tent_ridge"], "b", 1.0],
	"camp_sprites.png|1302,606,462,304": [["tent_ridge_red"], "b", 1.0],
	"camp_sprites.png|838,606,460,304": [["tent_ridge_red"], "b", 1.0],
	"camp_sprites.png|1478,1438,252,124": [["palisade", "palisade", "palisade_broken"], "b", 1.0],
	"camp_sprites.png|684,1438,194,130": [["palisade", "palisade_broken"], "b", 1.0],
	"camp_sprites.png|882,1438,152,128": [["palisade_gap"], "b", 1.0],
	"camp_sprites.png|1440,1438,34,124": [["stake_a", "stake_b"], "b", 1.0],
	"camp_sprites.png|1400,1438,36,124": [["stake_a", "stake_b"], "b", 1.0],
	"camp_sprites.png|2704,1438,32,102": [["stake_b", "stake_a"], "b", 1.0],
	"camp_sprites.png|408,918,134,300": [["banner"], "b", 1.0],
	"camp_sprites.png|2646,1224,46,144": [["port_lantern"], "h", 1.0],
	"camp_sprites.png|922,1576,98,56": [["chest"], "b", 1.0],
	"camp_sprites.png|424,1576,188,78": [["sacks"], "b", 0.8],
	"camp_sprites.png|2346,1438,188,112": [["cart_broken"], "b", 1.0],
	"camp_sprites.png|2090,1438,252,116": [["cart_broken"], "b", 1.0],
	"camp_sprites.png|2624,918,426,210": [["pile_a", "pile_b"], "b", 1.0],
	"camp_sprites.png|2182,918,438,210": [["pile_b", "pile_a"], "b", 1.0],
	"camp_sprites.png|1658,1224,420,188": [["pile_a", "pile_b"], "b", 1.0],
	"camp_sprites.png|1488,918,378,228": [["pile_b", "pile_a"], "b", 1.0],
	"camp_sprites.png|1870,918,308,224": [["pile_a", "pile_b"], "b", 1.0],
	"medieval_atlas.png|1056,1588,250,236": [["wagon"], "b", 1.0],
	"medieval_atlas.png|2184,848,108,170": [["armor_stand"], "h", 1.0],
	"medieval_atlas.png|2320,844,60,176": [["weapon_rack"], "h", 0.9],
	"medieval_atlas.png|2218,658,90,172": [["weapon_rack"], "h", 0.9],
	"medieval_atlas.png|2408,888,154,122": [["chest"], "b", 1.0],
	"medieval_atlas.png|1328,1794,88,92": [["crate"], "b", 1.0],
	"medieval_atlas.png|1202,1886,86,102": [["crate"], "b", 1.0],
	"medieval_atlas.png|400,1584,90,132": [["barrel"], "b", 1.0],
	"medieval_atlas.png|174,1762,108,118": [["barrel"], "b", 1.0],
	"medieval_atlas.png|268,1584,52,84": [["barrel"], "b", 1.0],
	"medieval_atlas.png|332,1634,48,80": [["barrel"], "b", 1.0],
	"medieval_atlas.png|576,1874,74,120": [["sacks"], "b", 1.3],
}

var report: Array[String] = []
var _imgs := {}
var _pieces := {}
var _bboxes := {}


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if "atlas" in steps:
		_step_atlas()
	if "apply" in steps:
		_step_apply()
	for r in report:
		print(r)
	quit()


# ───────────────────────── нарезка и атлас ─────────────────────────

func _img(path: String) -> Image:
	if not _imgs.has(path):
		var im := Image.load_from_file(ProjectSettings.globalize_path(path))
		im.convert(Image.FORMAT_RGBA8)
		_imgs[path] = im
	return _imgs[path]


## Предметы листа: группы связных непрозрачных областей (мелочь — к ближайшему
## крупному), порядок — ряды по 150 px сверху вниз, в ряду слева направо.
## Возвращает [{rect, mask(Image L8 в размер rect)}]
func _sheet_items(file: String) -> Array:
	var key := "items:" + file
	if _imgs.has(key):
		return _imgs[key]
	var full := _img(HD + file)
	var small := full.duplicate() as Image
	var w := full.get_width() / 2
	var h := full.get_height() / 2
	small.resize(w, h)
	var lab := PackedInt32Array()
	lab.resize(w * h)
	var comps: Array = []    # {r, n}
	for y0 in h:
		for x0 in w:
			if lab[y0 * w + x0] != 0 or small.get_pixel(x0, y0).a < 0.08:
				continue
			var id := comps.size() + 1
			var r := Rect2i(x0, y0, 1, 1)
			var n := 0
			var stack := [Vector2i(x0, y0)]
			lab[y0 * w + x0] = id
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				n += 1
				r = r.expand(p).expand(p + Vector2i.ONE)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
							continue
						var qi := q.y * w + q.x
						if lab[qi] != 0 or small.get_pixel(q.x, q.y).a < 0.08:
							continue
						lab[qi] = id
						stack.append(q)
			comps.append({"r": r, "n": n, "g": -1})
	# Крупные — свои группы, мелкие — к ближайшему крупному рядом
	var groups: Array = []    # {r, ids}
	for i in comps.size():
		if comps[i]["n"] >= 1500:
			comps[i]["g"] = groups.size()
			groups.append({"r": comps[i]["r"], "ids": {i + 1: true}})
	for i in comps.size():
		if comps[i]["g"] >= 0:
			continue
		var best := -1
		var bd := INF
		for gi in groups.size():
			var gr: Rect2i = groups[gi]["r"]
			var d: float = Vector2(gr.get_center()).distance_to(Vector2(comps[i]["r"].get_center()))
			if gr.grow(24).intersects(comps[i]["r"]) and d < bd:
				bd = d
				best = gi
		if best >= 0:
			groups[best]["r"] = (groups[best]["r"] as Rect2i).merge(comps[i]["r"])
			groups[best]["ids"][i + 1] = true
	groups.sort_custom(func(a, b):
		var ay: int = (a["r"] as Rect2i).get_center().y * 2 / 150
		var by: int = (b["r"] as Rect2i).get_center().y * 2 / 150
		if ay != by:
			return ay < by
		return (a["r"] as Rect2i).position.x < (b["r"] as Rect2i).position.x)
	var out: Array = []
	for g in groups:
		var rs: Rect2i = g["r"]
		var rect := Rect2i(rs.position * 2 - Vector2i(2, 2), rs.size * 2 + Vector2i(4, 4)).intersection(Rect2i(Vector2i.ZERO, full.get_size()))
		var mask := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_L8)
		var ids: Dictionary = g["ids"]
		for y in rect.size.y:
			for x in rect.size.x:
				var fx := rect.position.x + x
				var fy := rect.position.y + y
				var hx := fx / 2
				var hy := fy / 2
				var mine := false
				for dy in [0, -1, 1]:
					for dx in [0, -1, 1]:
						var qx: int = hx + dx
						var qy: int = hy + dy
						if qx >= 0 and qy >= 0 and qx < w and qy < h and ids.has(lab[qy * w + qx]):
							mine = true
							break
					if mine:
						break
				if mine:
					mask.set_pixel(x, y, Color(1, 1, 1))
		out.append({"rect": rect, "mask": mask})
	_imgs[key] = out
	return out


## Картинка предмета, обрезанная по альфе
func _piece(name: String) -> Image:
	if _pieces.has(name):
		return _pieces[name]
	var spec: Array = PIECES[name]
	var full := _img(HD + spec[0])
	var im: Image
	if spec[1] < 0:
		im = full.duplicate() as Image
	else:
		var it: Dictionary = _sheet_items(spec[0])[spec[1]]
		var rect: Rect2i = it["rect"]
		var mask: Image = it["mask"]
		im = full.get_region(rect)
		for y in rect.size.y:
			for x in rect.size.x:
				if mask.get_pixel(x, y).r < 0.5:
					im.set_pixel(x, y, Color(0, 0, 0, 0))
		if spec.size() > 2:
			# Половина пары (два кола слиплись): по разрыву альфы посередине
			var cut := _gap_column(im)
			for y in im.get_height():
				for x in im.get_width():
					if (spec[2] == "left" and x >= cut) or (spec[2] == "right" and x < cut):
						im.set_pixel(x, y, Color(0, 0, 0, 0))
	var bb := _alpha_bbox(im, Rect2i(Vector2i.ZERO, im.get_size()))
	im = im.get_region(bb)
	_pieces[name] = im
	return im


## Столбец с наименьшей заливкой в средней трети — разрез между двумя предметами
func _gap_column(im: Image) -> int:
	var w := im.get_width()
	var best := w / 2
	var bn := 1 << 30
	for x in range(w / 3, w * 2 / 3):
		var n := 0
		for y in im.get_height():
			if im.get_pixel(x, y).a > 0.1:
				n += 1
		if n < bn:
			bn = n
			best = x
	return best


func _alpha_bbox(im: Image, reg: Rect2i) -> Rect2i:
	var x0 := reg.end.x
	var y0 := reg.end.y
	var x1 := reg.position.x - 1
	var y1 := reg.position.y - 1
	for y in range(reg.position.y, reg.end.y):
		for x in range(reg.position.x, reg.end.x):
			if im.get_pixel(x, y).a > 0.1:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < x0:
		return reg
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Видимый контур старого куска — в координатах его региона
func _old_bbox(key: String) -> Rect2i:
	if _bboxes.has(key):
		return _bboxes[key]
	var parts := key.split("|")
	var n := parts[1].split(",")
	var reg := Rect2i(int(n[0]), int(n[1]), int(n[2]), int(n[3]))
	var bb := _alpha_bbox(_img(OLD + parts[0]), reg)
	bb.position -= reg.position
	_bboxes[key] = bb
	return bb


## Размер новой картинки (в текселях старого) и её левый верхний угол в
## координатах старого региона
func _fit(name: String, b: Rect2i, mode: String, k: float) -> Array:
	var p := _piece(name).get_size()
	var w: int
	var h: int
	match mode:
		"h":
			h = maxi(2, roundi(b.size.y * k))
			w = maxi(2, roundi(h * float(p.x) / p.y))
		"s":
			w = maxi(2, roundi(b.size.x * k))
			h = maxi(2, roundi(b.size.y * k))
		_:
			w = maxi(2, roundi(b.size.x * k))
			h = maxi(2, roundi(w * float(p.y) / p.x))
	var cx := b.position.x + b.size.x * 0.5
	var tl := Vector2(cx - w * 0.5, 0)
	match mode:
		"t":
			tl.y = b.position.y
		"c":
			tl.y = b.position.y + b.size.y * 0.5 - h * 0.5
		"s":
			tl = Vector2(cx - w * 0.5, b.position.y + b.size.y * 0.5 - h * 0.5)
		_:
			tl.y = b.end.y - h
	return [Vector2i(w, h), tl]


func _baked_key(name: String, size: Vector2i) -> String:
	return "%s@%dx%d" % [name, size.x, size.y]


func _step_atlas() -> void:
	var bake := {}    # baked key → [name, size]
	for key in MAP:
		var e: Array = MAP[key]
		var b := _old_bbox(key)
		for name in e[0]:
			var f := _fit(name, b, e[1], e[2])
			bake[_baked_key(name, f[0])] = [name, f[0]]
	# Упаковка полками
	var keys := bake.keys()
	keys.sort_custom(func(a, c): return bake[a][1].y > bake[c][1].y)
	var rects := {}
	var x := 0
	var y := 0
	var shelf := 0
	for k in keys:
		var s: Vector2i = bake[k][1]
		if x + s.x + PAD > ATLAS_W:
			x = 0
			y += shelf + PAD
			shelf = 0
		rects[k] = Rect2i(x, y, s.x, s.y)
		x += s.x + PAD
		shelf = maxi(shelf, s.y)
	var ah := y + shelf
	ah = (ah + 3) / 4 * 4
	var atlas := Image.create(ATLAS_W, ah, false, Image.FORMAT_RGBA8)
	for k in keys:
		var name: String = bake[k][0]
		var s: Vector2i = bake[k][1]
		var im := _piece(name).duplicate() as Image
		im.resize(s.x, s.y, Image.INTERPOLATE_LANCZOS)
		_fix_alpha(im)
		if s.x * s.y > 400:
			im = BT._unsharp(im, 0.25)
		atlas.blit_rect(im, Rect2i(Vector2i.ZERO, s), rects[k].position)
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	var js := {}
	for k in rects:
		var r: Rect2i = rects[k]
		js[k] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(js, "\t"))
	f.close()
	_write_import()
	report.append("atlas: %d картинок, %dx%d (%s)" % [keys.size(), ATLAS_W, ah, error_string(err)])


func _fix_alpha(p: Image) -> void:
	for y in p.get_height():
		for x in p.get_width():
			var c := p.get_pixel(x, y)
			if c.a < 0.12:
				p.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				p.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), clampf(c.a, 0, 1)))


## Импорт как у атласа леса: BPTC (быстро на слабом ноутбуке), без мипмапов
func _write_import() -> void:
	var path := ProjectSettings.globalize_path(ATLAS) + ".import"
	if FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\nmipmaps/generate=false\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=1\n")
	f.close()


# ───────────────────────── подмена в сценах ─────────────────────────

var _atlas: Texture2D
var _meta := {}
var _sources := {}


func _step_apply() -> void:
	_atlas = load(ATLAS)
	if _atlas == null:
		report.append("apply: нет атласа — сначала atlas и --import")
		return
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	for path in SCENES:
		var lvl := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var ns := 0
		var nt := 0
		var miss := {}
		for sp in lvl.find_children("*", "Sprite2D", true, false):
			var s := sp as Sprite2D
			if s.owner != lvl or s.texture == null or s.texture == _atlas:
				continue
			var key := _sprite_key(s)
			if MAP.has(key):
				if _replace_sprite(s, key, str(lvl.get_path_to(s))):
					ns += 1
				else:
					miss[key] = true
		for l in lvl.find_children("*", "TileMapLayer", true, false):
			var t := l as TileMapLayer
			if t.owner != lvl and t != lvl:
				continue
			nt += _replace_tiles(t, miss)
		# У карты земля с материалом: нет материала — импорт не прошёл (у лагеря
		# своего материала нет, это нормально)
		var g := lvl.get_node_or_null("Ground") as CanvasItem
		if path == SCENES[0] and g != null and g.material == null:
			report.append("%s НЕ сохранена: материал земли не загрузился — сначала --import" % path.get_file())
			lvl.free()
			continue
		var ps := PackedScene.new()
		var err := ps.pack(lvl)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		report.append("%s: спрайтов %d, тайлов %d, без картинки %s (%s)" % [path.get_file(), ns, nt, miss.keys(), error_string(err)])
		lvl.free()


func _sprite_key(s: Sprite2D) -> String:
	var reg := Rect2i(s.region_rect) if s.region_enabled else Rect2i(Vector2i.ZERO, s.texture.get_size())
	return "%s|%d,%d,%d,%d" % [s.texture.resource_path.get_file(), reg.position.x, reg.position.y, reg.size.x, reg.size.y]


func _choose(e: Array, salt: String) -> String:
	var names: Array = e[0]
	return names[absi(hash(salt)) % names.size()]


func _plan(key: String, name: String, flip: bool) -> Array:
	var e: Array = MAP[key]
	var b := _old_bbox(key)
	var reg_w := int(key.split("|")[1].split(",")[2])
	if flip:
		b.position.x = reg_w - b.position.x - b.size.x
	var f := _fit(name, b, e[1], e[2])
	var bk := _baked_key(name, f[0])
	if not _meta.has(bk):
		return []
	var r: Array = _meta[bk]
	return [Rect2i(r[0], r[1], r[2], r[3]), f[1], bk]


func _replace_sprite(s: Sprite2D, key: String, salt: String) -> bool:
	var name := _choose(MAP[key], salt)
	var p := _plan(key, name, s.flip_h)
	if p.is_empty():
		return false
	var reg := Rect2i(s.region_rect) if s.region_enabled else Rect2i(Vector2i.ZERO, s.texture.get_size())
	var tl_local: Vector2 = (s.offset - Vector2(reg.size) * 0.5) if s.centered else s.offset
	s.texture = _atlas
	s.region_enabled = true
	s.region_rect = Rect2(p[0])
	s.centered = false
	s.offset = (tl_local + (p[1] as Vector2)).round()
	s.set_meta("hd_prop", p[2])
	return true


func _replace_tiles(t: TileMapLayer, miss: Dictionary) -> int:
	var n := 0
	var ts := t.tile_set
	if ts == null:
		return 0
	for c in t.get_used_cells():
		var src := ts.get_source(t.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null or src.texture == null or src.texture == _atlas:
			continue
		var ac := t.get_cell_atlas_coords(c)
		var reg := src.get_tile_texture_region(ac)
		var key := "%s|%d,%d,%d,%d" % [src.texture.resource_path.get_file(), reg.position.x, reg.position.y, reg.size.x, reg.size.y]
		if not MAP.has(key):
			continue
		var td := src.get_tile_data(ac, t.get_cell_alternative_tile(c))
		var flip := td.flip_h
		var name := _choose(MAP[key], "%s%s" % [t.name, c])
		var p := _plan(key, name, flip)
		if p.is_empty():
			miss[key] = true
			continue
		var rect: Rect2i = p[0]
		# Старый рисунок: левый верх = -размер/2 - texture_origin
		var tl_old := -Vector2(reg.size) * 0.5 - Vector2(td.texture_origin)
		var tl_new := tl_old + (p[1] as Vector2)
		var origin := Vector2i((-Vector2(rect.size) * 0.5 - tl_new).round())
		var sid := _source_for(ts, p[2], rect, origin, td)
		t.set_cell(c, sid, Vector2i.ZERO, 1 if flip else 0)
		n += 1
	return n


func _source_for(ts: TileSet, bk: String, rect: Rect2i, origin: Vector2i, old: TileData) -> int:
	var id := "%s|%s|%d|%d" % [bk, origin, old.y_sort_origin, old.z_index]
	if not _sources.has(ts):
		_sources[ts] = {}
		for i in ts.get_source_count():
			var sid := ts.get_source_id(i)
			var s := ts.get_source(sid) as TileSetAtlasSource
			if s and s.texture == _atlas and s.has_meta("hd_prop"):
				_sources[ts][s.get_meta("hd_prop")] = sid
	if _sources[ts].has(id):
		return _sources[ts][id]
	var src := TileSetAtlasSource.new()
	src.texture = _atlas
	src.margins = rect.position
	src.texture_region_size = rect.size
	src.use_texture_padding = false
	src.set_meta("hd_prop", id)
	var sid := ts.add_source(src)
	src.create_tile(Vector2i.ZERO)
	for alt in [0, 1]:
		var a: int = alt if alt == 0 else src.create_alternative_tile(Vector2i.ZERO)
		var td := src.get_tile_data(Vector2i.ZERO, a)
		td.texture_origin = origin
		td.y_sort_origin = old.y_sort_origin
		td.z_index = old.z_index
		td.flip_h = alt == 1
	_sources[ts][id] = sid
	return sid
