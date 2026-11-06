extends SceneTree
## slice_hero_ui.gd — режет листы UI героев на отдельные чистые PNG и пишет
## манифест (имя → прямоугольник детали на её листе; скин инвентаря
## Inventory/ui/hero_inventory_skin.gd считает от него всё нарисованное
## внутри: края рамок, углы, ромбы, плашки):
##   Сигрид   — UI/UI_HUD/UI_HUD_Sigrid_2.png → UI/UI_HUD/sigrid2/
##   Хальвард — UI/UI_HUD/halvard/inventory_UI_Halvard.png и
##              panel_description_Halvard.png → UI/UI_HUD/halvard/pieces/
##
##   godot --headless --path . -s res://tools/slice_hero_ui.gd
##
## Листы (кроме помеченных alpha) нарисованы на БЕЛОМ фоне (без прозрачности): почти белые пиксели —
## фон, на кромке детали белый вычитается из цвета (как "цвет в альфу"),
## чтобы на тёмном экране не было светлого ореола.
##
## Как отделяется деталь от соседей: в прямоугольнике детали (+ запас PAD)
## ищутся связные куски не-фона. Кусок, который в основном лежит внутри
## прямоугольника, берётся целиком (даже если торчит наружу — цепи, лоскуты);
## кусок соседа, лишь заходящий краем, отбрасывается. Детали, слипшиеся на
## листе с соседями (стопка плашек), режутся строго по прямоугольнику (clip).
##
## key_field — у рамки Хальварда синие ремни в углах лежат поверх поля.
## Тёмный гладкий фон поля (кроме прямоугольника клеток) делается прозрачным:
## в игре под рамкой свой фон, и ремень должен лечь на него, а не на кусок
## старого поля

const PAD := 24
## Пиксель светлее этого по всем каналам — белый фон листа
const WHITE := 0.86
const KEEP_FRACTION := 0.6

const SHEETS := [
	{
		"out": "res://UI/UI_HUD/sigrid2/",
		"manifest": "sigrid_ui_pieces.gd",
		"parts": [{
			"src": "res://UI/UI_HUD/UI_HUD_Sigrid_2.png",
			"clip": ["plaque_dark"],
			"pieces": {
				"tabs_bar": Rect2(20, 0, 1262, 146),
				"grid_panel": Rect2(131, 116, 470, 581),
				"detail_panel": Rect2(603, 112, 437, 581),
				"standard": Rect2(1417, 491, 109, 352),
				"plaque_dark": Rect2(1270, 13, 254, 59),
			},
		}],
	},
	{
		"out": "res://UI/UI_HUD/halvard/pieces/",
		"manifest": "halvard_ui_pieces.gd",
		"parts": [
			{
				# Минималистичный набор (2026-10-29): тёмная сталь, бронзовые узлы
				# в углах, гладкие кромки (тянутся без шва). Фон прозрачный (alpha)
				"src": "res://UI/UI_HUD/halvard/inventory_UI_Halvard.png",
				"alpha": true,
				"pieces": {
					# большая рамка — из неё собираются все панели, поле — их фон
					"grid_panel": Rect2(22, 54, 570, 568),
					"cell": Rect2(1099, 69, 130, 130),
					"cell_sel": Rect2(1099, 207, 130, 130),
					"plaque_dark": Rect2(598, 636, 306, 70),
					"divider": Rect2(48, 640, 516, 46),
					# малый разделитель — метка под активной вкладкой
					"stud": Rect2(246, 689, 128, 30),
					# кольцо — знак под амулетницей (вместо старого штандарта)
					"standard": Rect2(532, 846, 182, 186),
				},
			},
			{
				# Готовая раскладка инвентаря (2026-10-29, лист «(2)»): три панели
				# с мехом и цепями. Ставится 1:1, поверх — живые элементы
				# (hero_inventory_skin.gd, тема HALVARD sheet_layout).
				# raw — куски ДО обработки: светящаяся клетка (её запечённое
				# свечение — подсветка выбранной клетки в игре);
				# copy — первая клетка на листе светится, на её место — копия
				# соседней (обычной); desat — первый значок категорий светится,
				# гасится в тон остальным; tame — блики и яркие цвета приглушены
				"src": "res://UI/UI_HUD/halvard/inventory_UI_Halvard (2).png",
				"alpha": true,
				"raw": {"cell_glow": Rect2(72, 256, 108, 114)},
				"copy": [[Rect2(72, 256, 108, 114), Vector2i(103, 0)]],
				"desat": [Rect2(83, 168, 86, 74)],
				"tame": {"knee": 0.3, "keep": 0.5, "sat": 0.7},
				"pieces": {
					"inv_left": Rect2(0, 60, 805, 845),
					"inv_mid": Rect2(805, 60, 491, 845),
					"inv_right": Rect2(1296, 60, 376, 845),
				},
			},
			{
				# Верхняя полоса под вкладки: плашка с узлами, мех, ткань и
				# медальоны на цепях — уменьшается под экран (Ланцош)
				"src": "res://UI/UI_HUD/halvard/high_panel_inventory.png",
				"alpha": true,
				"tame": {"knee": 0.3, "keep": 0.5, "sat": 0.7},
				"resize": {"tabs_bar": [Rect2(0, 0, 2172, 724), Vector2i(1347, 449)]},
				"pieces": {},
			},
		],
	},
]


func _init() -> void:
	for sheet in SHEETS:
		var out_dir: String = sheet["out"]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var manifest := "extends RefCounted\n## Сгенерировано tools/slice_hero_ui.gd — не править руками.\n## Имя детали → её прямоугольник на СВОЁМ листе (файл <имя>.png рядом —\n## ровно этот кусок, фон прозрачный)\n\nconst PIECES := {\n"
		for part in sheet["parts"]:
			var img := Image.load_from_file(ProjectSettings.globalize_path(part["src"]))
			if img == null:
				push_error("нет листа " + part["src"])
				quit(1)
				return
			img.convert(Image.FORMAT_RGBA8)
			var raw: Dictionary = part.get("raw", {})
			for piece_name in raw:
				var rw: Rect2i = Rect2i(raw[piece_name])
				img.get_region(rw).save_png(ProjectSettings.globalize_path(out_dir + piece_name + ".png"))
				manifest += "\t\"%s\": Rect2(%d, %d, %d, %d),\n" % [piece_name, rw.position.x, rw.position.y, rw.size.x, rw.size.y]
				print("piece %s -> raw %s" % [piece_name, rw])
			for cp in part.get("copy", []):
				var dst: Rect2i = Rect2i(cp[0])
				var src := img.get_region(Rect2i(dst.position + Vector2i(cp[1]), dst.size))
				img.blit_rect(src, Rect2i(Vector2i.ZERO, dst.size), dst.position)
			for dr in part.get("desat", []):
				_desaturate(img, Rect2i(dr))
			if part.has("tame"):
				_tame(img, part["tame"])
			var resize: Dictionary = part.get("resize", {})
			for piece_name in resize:
				var rr: Rect2i = Rect2i(resize[piece_name][0])
				var to: Vector2i = resize[piece_name][1]
				var small := img.get_region(rr)
				small.resize(to.x, to.y, Image.INTERPOLATE_LANCZOS)
				small.save_png(ProjectSettings.globalize_path(out_dir + piece_name + ".png"))
				manifest += "\t\"%s\": Rect2(0, 0, %d, %d),\n" % [piece_name, to.x, to.y]
				print("piece %s -> resized %dx%d" % [piece_name, to.x, to.y])
			var clip: Array = part.get("clip", [])
			var keys: Dictionary = part.get("key_field", {})
			for piece_name in part["pieces"]:
				var r: Rect2i = Rect2i(part["pieces"][piece_name])
				# Лист с прозрачным фоном — кусок как есть
				var res := [img.get_region(r), r.position] if part.get("alpha", false) \
						else _extract(img, r, piece_name in clip)
				var out: Image = res[0]
				var origin: Vector2i = res[1]
				if keys.has(piece_name):
					_key_field(out, origin, keys[piece_name][0], keys[piece_name][1])
				out.save_png(ProjectSettings.globalize_path(out_dir + piece_name + ".png"))
				manifest += "\t\"%s\": Rect2(%d, %d, %d, %d),\n" % [piece_name, origin.x, origin.y, out.get_width(), out.get_height()]
				print("piece %s -> %s %dx%d" % [piece_name, origin, out.get_width(), out.get_height()])
		manifest += "}\n"
		var f := FileAccess.open(out_dir + sheet["manifest"], FileAccess.WRITE)
		f.store_string(manifest)
		f.close()
	quit()


## Тёмный гладкий фон поля → прозрачность (мягко по яркости). Светлое (линии,
## заклёпки, пластины) и синее (ремни) остаётся. Прямоугольник клеток —
## без изменений. field/cells — в координатах листа
func _key_field(img: Image, origin: Vector2i, field: Rect2, cells: Rect2) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(origin.x + x, origin.y + y)
			if not field.has_point(p) or cells.has_point(p):
				continue
			var c := img.get_pixel(x, y)
			var lum := maxf(c.r, maxf(c.g, c.b))
			if c.b - maxf(c.r, c.g) > 0.04:
				continue
			c.a *= smoothstep(0.13, 0.24, lum)
			img.set_pixel(x, y, c)


## Приглушить блики и яркие цвета: яркость выше knee сжимается (остаётся
## доля keep от превышения), насыщенность — доля sat. Тёмное не меняется
static func _tame(img: Image, t: Dictionary) -> void:
	var knee: float = t["knee"]
	var keep: float = t["keep"]
	var sat: float = t["sat"]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var v := c.v
			if v > knee:
				v = knee + (v - knee) * keep
			img.set_pixel(x, y, Color.from_hsv(c.h, c.s * sat, v, c.a))


## Погасить запечённое свечение: тёплое → в нейтральный тон соседних
## значков, яркость вдвое ниже (только в прямоугольнике)
static func _desaturate(img: Image, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color.from_hsv(c.h, c.s * 0.25, c.v * 0.55, c.a))


static func _is_bg(c: Color) -> bool:
	return minf(c.r, minf(c.g, c.b)) > WHITE


## Вырезает деталь: [Image, левый верхний угол на листе]. clip — строго по
## прямоугольнику, без поиска связных кусков
func _extract(img: Image, r: Rect2i, clip: bool) -> Array:
	var reg := r if clip else Rect2i(r.position - Vector2i(PAD, PAD), r.size + Vector2i(PAD * 2, PAD * 2))
	reg = reg.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var w := reg.size.x
	var h := reg.size.y
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 0 if _is_bg(img.get_pixel(reg.position.x + x, reg.position.y + y)) else 1

	var keep := PackedByteArray()
	keep.resize(w * h)
	if clip:
		keep = solid.duplicate()
	else:
		# Связные куски не-фона (8 соседей)
		var label := PackedInt32Array()
		label.resize(w * h)
		label.fill(-1)
		var comp_total: Array[int] = []
		var comp_inside: Array[int] = []
		var stack := PackedInt32Array()
		var inner := Rect2i(r.position - reg.position, r.size)
		for start in w * h:
			if solid[start] == 0 or label[start] != -1:
				continue
			var id := comp_total.size()
			comp_total.append(0)
			comp_inside.append(0)
			label[start] = id
			stack.append(start)
			while stack.size() > 0:
				var k := stack[stack.size() - 1]
				stack.remove_at(stack.size() - 1)
				var x := k % w
				var y := k / w
				comp_total[id] += 1
				if inner.has_point(Vector2i(x, y)):
					comp_inside[id] += 1
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var j := ny * w + nx
						if solid[j] == 1 and label[j] == -1:
							label[j] = id
							stack.append(j)
		for k in w * h:
			var id := label[k]
			if id >= 0 and float(comp_inside[id]) / float(comp_total[id]) >= KEEP_FRACTION:
				keep[k] = 1

	# Обрез по краю оставленного
	var minp := Vector2i(w, h)
	var maxp := Vector2i(-1, -1)
	for k in w * h:
		if keep[k] == 1:
			var x := k % w
			var y := k / w
			minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
			maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
	var out := Image.create(maxp.x - minp.x + 1, maxp.y - minp.y + 1, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in range(minp.y, maxp.y + 1):
		for x in range(minp.x, maxp.x + 1):
			if keep[y * w + x] == 0:
				continue
			var c := img.get_pixel(reg.position.x + x, reg.position.y + y)
			# Кромка (рядом фон): белый подмешан к цвету — вычитаем его в альфу
			var edge := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h or keep[ny * w + nx] == 0:
						edge = true
			if edge:
				var a := clampf(1.0 - minf(c.r, minf(c.g, c.b)), 0.0, 1.0)
				if a < 0.02:
					continue
				c = Color((c.r - (1.0 - a)) / a, (c.g - (1.0 - a)) / a, (c.b - (1.0 - a)) / a, a)
			out.set_pixel(x - minp.x, y - minp.y, c)
	return [out, reg.position + minp]
