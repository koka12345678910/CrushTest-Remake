extends SceneTree
## holmvik_yards_art.gd — атлас дворов Хольмвика из листов партии 5
## (reference_map_level/ART_PROMPTS_HOLMVIK_5.md, картинки в
## textures/src/hd/props_v5/): постройки, заборы, быт, следы погрома, земля.
##
## Каждый лист режется на связные области альфы (порядок — ряды сверху вниз,
## в ряду слева направо), предмет печётся сразу в свой размер в мире при TS
## текселях на px мира, резкость, тон чуть к тону городских атласов. Для
## каждого предмета пишется «подножие» — доля ширины, где он стоит на земле
## (по ней коллизия построек).
##
##   godot --headless --path . -s res://tools/holmvik_yards_art.gd
##   godot --headless --path . --import
## Дальше — tools/holmvik_yards.gd -- apply ground.

const AU := preload("res://tools/art_util.gd")
const TEX := "res://reference_map_level/textures/"
const SRC := TEX + "src/hd/props_v5/"
const ATLAS := TEX + "town_yards_hd.png"
const META := TEX + "town_yards_hd.json"
const TONE_REF := TEX + "town_art3_hd.png"
const TS := 2.5
const ATLAS_W := 4096
const SHARPEN := 0.25
const TONE_MIX := 0.12
## Подножие: доля высоты самой высокой колонки, с которой столбец — предмет
const FOOT_SOLID := 0.45

## Лист: [[имя, "w"|"h", размер в px мира], ...] по порядку на листе.
## Рост героя ≈ 45 px мира
const SHEETS := {
	"yard_buildings": [["b_coop", "w", 64.0], ["b_outhouse", "h", 74.0], ["b_toolshed", "w", 104.0],
		["b_smokehouse", "w", 78.0], ["b_kennel", "w", 44.0], ["b_beehives", "w", 82.0],
		["b_cellar", "w", 64.0], ["b_leanto", "w", 118.0]],
	"yard_fences": [["f_picket", "w", 104.0], ["f_picket_broken", "w", 104.0], ["f_picket_side", "h", 104.0],
		["f_gate_picket", "h", 50.0], ["f_gate_post", "h", 46.0], ["f_gate_wattle", "w", 50.0],
		["f_stone", "w", 104.0], ["f_stone_broken", "w", 104.0], ["f_stone_side", "h", 104.0],
		["f_stone_corner", "w", 66.0], ["f_rail", "w", 104.0]],
	"yard_life": [["l_bench", "w", 52.0], ["l_table", "w", 58.0], ["l_washtub", "w", 34.0],
		["l_spinning", "h", 40.0], ["l_grindstone", "h", 36.0],
		["l_anvil", "h", 32.0], ["l_baskets", "w", 42.0], ["l_pots", "w", 30.0], ["l_handcart", "w", 58.0],
		["l_churn", "h", 34.0],
		["l_sheaves", "h", 42.0], ["l_herbrack", "w", 66.0], ["l_woodstack", "h", 44.0], ["l_cauldron", "h", 44.0]],
	"yard_raid": [["r_bench_spill", "w", 70.0], ["r_sacks", "w", 60.0], ["r_woodpile", "w", 64.0],
		["r_chest", "w", 60.0], ["r_wheel", "w", 56.0], ["r_coop", "w", 56.0], ["r_fence_flat", "w", 92.0],
		["r_fence_burnt", "w", 66.0], ["r_laundry", "w", 74.0], ["r_cart_hay", "w", 86.0]],
	"yard_ground": [["g_garden", "w", 128.0], ["g_plot", "w", 96.0], ["g_herbs", "w", 86.0],
		["g_straw", "w", 96.0], ["g_chips", "w", 84.0], ["g_puddle", "w", 88.0],
		["g_mud", "w", 88.0], ["g_ash", "w", 76.0], ["g_dung", "w", 76.0]],
}

## Листы, где предметы касаются друг друга: нарезка по прямоугольникам
## вручную (пиксели листа в px). Пиксель принадлежит первому прямоугольнику,
## в который попал, — порядок списка решает спорные места
const BOXES := {
	"yard_raid": [Rect2i(0, 0, 385, 262), Rect2i(385, 0, 335, 252), Rect2i(720, 0, 370, 265),
		Rect2i(1090, 0, 410, 270), Rect2i(0, 262, 405, 234), Rect2i(405, 252, 415, 272),
		Rect2i(820, 270, 680, 215), Rect2i(0, 496, 385, 254), Rect2i(385, 470, 495, 280),
		Rect2i(880, 476, 620, 274)],
	"yard_ground": [Rect2i(0, 0, 515, 325), Rect2i(515, 0, 485, 325), Rect2i(1000, 0, 500, 325),
		Rect2i(0, 325, 515, 260), Rect2i(515, 325, 485, 260), Rect2i(1000, 325, 500, 260),
		Rect2i(0, 585, 515, 260), Rect2i(515, 585, 485, 260), Rect2i(1000, 585, 500, 260)],
}
## Земля: край клетки растворяется эллипсом (декаль ляжет на любую траву,
## обрывки соседей у края уходят)
const FADE := ["yard_ground"]

var report: Array[String] = []


func _initialize() -> void:
	var ref := (load(TONE_REF) as Texture2D).get_image()
	ref.decompress()
	ref.convert(Image.FORMAT_RGBA8)
	var target := AU.mean_color(ref)
	var items := []
	var ok := true
	for sheet in SHEETS:
		var img := AU.load_hd(SRC, sheet)
		if img == null:
			report.append("ОТКАЗ: нет листа %s" % sheet)
			ok = false
			continue
		img = AU.clean_edges(img)
		var names: Array = SHEETS[sheet]
		if BOXES.has(sheet):
			var parts := _owned(img, BOXES[sheet], sheet in FADE)
			for i in names.size():
				var spec: Array = names[i]
				var part := AU.keep_main(parts[i], 0.02)
				var k := float(spec[2]) * TS / (part.get_width() if spec[1] == "w" else part.get_height())
				items.append({"name": spec[0], "img": _bake(part, k, target)})
			report.append("%s: %d (по разметке)" % [sheet, names.size()])
			continue
		var boxes := _components(img)
		if boxes.size() != names.size():
			report.append("ОТКАЗ %s: найдено %d предметов, ждали %d:" % [sheet, boxes.size(), names.size()])
			for b in boxes:
				report.append("    %s" % b)
			ok = false
			continue
		for i in names.size():
			var spec: Array = names[i]
			var part := AU.keep_main(img.get_region(boxes[i]), 0.02)
			var used := part.get_used_rect()
			part = part.get_region(used)
			var k := float(spec[2]) * TS / (part.get_width() if spec[1] == "w" else part.get_height())
			items.append({"name": spec[0], "img": _bake(part, k, target)})
		report.append("%s: %d" % [sheet, names.size()])
	if not ok:
		report.append("атлас не записан")
		_print()
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
		report.append("  %s: %.0fx%.0f px мира" % [it.name, r.size.x / TS, r.size.y / TS])
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	AU.write_import(ATLAS, false)
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	report.append("атлас: %d предметов, %dx%d (%s); дальше --import" % [placed.size(), ATLAS_W, ah, error_string(err)])
	_print()


## Вырезки по прямоугольникам: пиксель — первому прямоугольнику, где он есть
func _owned(img: Image, boxes: Array, fade: bool) -> Array:
	var out := []
	for i in boxes.size():
		var b: Rect2i = boxes[i]
		var part := Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGBA8)
		var c := Vector2(b.size) * 0.5
		for y in b.size.y:
			for x in b.size.x:
				var p := b.position + Vector2i(x, y)
				var owner := -1
				for j in i:
					if (boxes[j] as Rect2i).has_point(p):
						owner = j
						break
				if owner != -1:
					continue
				var col := img.get_pixelv(p)
				if fade:
					var d := ((Vector2(x, y) + Vector2(0.5, 0.5) - c) / c).length()
					col.a *= 1.0 - smoothstep(0.45, 0.95, d)
				part.set_pixel(x, y, col)
		out.append(part)
	return out


func _print() -> void:
	for r in report:
		print("[yards_art] ", r)
	quit()


func _bake(img: Image, k: float, target: Color) -> Image:
	var w := maxi(int(round(img.get_width() * k)), 4)
	var h := maxi(int(round(img.get_height() * k)), 4)
	var out := AU.resize_clean(img, w, h)
	out = AU.unsharp(out, SHARPEN)
	var m := AU.mean_color(out)
	return AU.match_tone(out, m.lerp(target, TONE_MIX))


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


## Прямоугольники предметов: связные области альфы на сетке 4 px; мелкие
## (< 4% крупнейшей) — к ближайшей крупной. Порядок — ряды сверху вниз, в ряду
## слева направо
func _components(img: Image) -> Array:
	var cell := 4
	var thr := 0.3
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
	var label := PackedInt32Array()
	label.resize(gw * gh)
	label.fill(-1)
	var comps := []
	for i in gw * gh:
		if occ[i] == 0 or label[i] != -1:
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
			area += 1
			x0 = mini(x0, jx)
			y0 = mini(y0, jy)
			x1 = maxi(x1, jx)
			y1 = maxi(y1, jy)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nx: int = jx + d.x
				var ny: int = jy + d.y
				if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
					continue
				var k := ny * gw + nx
				if occ[k] == 1 and label[k] == -1:
					label[k] = id
					stack.append(k)
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
