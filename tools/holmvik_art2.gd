extends SceneTree
## Арт партии 2 Хольмвика (ART_PROMPTS_HOLMVIK_2.md): листы GPT из
## textures/src/hd/props_v2/*.webp режутся на предметы (связные области альфы,
## мелкие обрывки — к ближайшему крупному), предметы — в атлас
## textures/town_props_hd.png (+ .json: rect в атласе), 2 текселя на px мира,
## тон — к тону атласа домов города.
##
## Порядок предметов в листе — по рядам сверху вниз, в ряду слева направо;
## имена — в SHEETS. Если GPT разложил лист иначе (другое число предметов),
## шаг отказывается и печатает, что нашёл.
##
## Запуск:
##   godot --headless --path . -s res://tools/holmvik_art2.gd -- atlas
##   godot --headless --path . --import

const AU := preload("res://tools/art_util.gd")
const SRC := "res://reference_map_level/textures/src/hd/props_v2/"
const TEX := "res://reference_map_level/textures/"
const ATLAS := TEX + "town_props_hd.png"
const META := TEX + "town_props_hd.json"
const TONE_REF := TEX + "town_houses_hd.png"
const TONE_MIX := 0.5
const TEX_SCALE := 2.0
const ATLAS_W := 4096

## лист: [[имя, "w"|"h", размер в px мира], ...] — в порядке предметов
const SHEETS := {
	"dark_sun": [["ds_standard", "h", 135.0], ["ds_banner", "h", 90.0], ["ds_spear", "h", 100.0],
		["ds_shield_post", "h", 62.0], ["ds_brazier", "h", 46.0], ["ds_altar", "w", 72.0]],
	"barricades": [["bar_cart", "w", 180.0], ["bar_planks", "w", 180.0], ["bar_furniture", "w", 135.0],
		["bar_beam", "w", 180.0], ["bar_stakes", "w", 135.0]],
	"yard": [["yard_well", "h", 90.0], ["yard_woodpile", "w", 135.0], ["yard_laundry", "w", 135.0],
		["yard_garden", "w", 130.0], ["yard_fishrack", "w", 90.0], ["yard_chopblock", "w", 46.0],
		["yard_rainbarrel", "h", 52.0], ["yard_pen", "w", 100.0]],
	"palisade": [["pal_front", "w", 180.0], ["pal_damaged", "w", 180.0], ["pal_side", "h", 270.0],
		["pal_tower", "w", 135.0], ["pal_gatehouse", "w", 270.0]],
	"temple_steps": [["tmp_gateway", "w", 220.0], ["tmp_wall", "w", 180.0], ["tmp_statue", "w", 140.0]],
}

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["atlas"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[holmvik_art2] ", r)
	quit()


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
			var r: Rect2i = boxes[i]
			var part := img.get_region(r)
			# Только свой предмет (соседи в прямоугольник не попадают — их
			# альфа вне маски компоненты не нужна, но маску не храним: GPT
			# раскладывает с запасом, прямоугольники не пересекаются)
			var k: float = float(spec[2]) * TEX_SCALE / (part.get_width() if spec[1] == "w" else part.get_height())
			var tw := maxi(int(round(part.get_width() * k)), 4)
			var th := maxi(int(round(part.get_height() * k)), 4)
			part = AU.resize_clean(part, tw, th)
			var m := AU.mean_color(part)
			part = AU.match_tone(part, m.lerp(target, TONE_MIX))
			items.append({"name": spec[0], "img": part})
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


## Прямоугольники предметов: связные области альфы на сетке 4 px с
## расширением на 3 клетки; мелкие (< 4% крупнейшей) — к ближайшей крупной.
## Порядок — ряды сверху вниз, в ряду слева направо
func _components(img: Image) -> Array:
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
					if img.get_pixel(gx * cell + dx, gy * cell + dy).a > 0.3:
						on = 1
			occ[gy * gw + gx] = on
	# Расширение
	var dil := PackedByteArray()
	dil.resize(gw * gh)
	var r := 3
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
	var comps := []  # [bbox Rect2i в клетках, площадь]
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
	# Ряды: по центру y; новый ряд, если центр ниже текущего больше чем на
	# половину высоты самого высокого в ряду
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
