extends SceneTree
## Ферма и костры reference_map из картинок GPT (src/hd/farm, src/hd/props).
##
## Шаги:
##   bake  — текстуры (рядом кладутся .import с BPTC, потом нужен импорт):
##           textures/farm_fields_hd.png — старый лист фермы (дорожки, рамки
##             участков) с новыми полями внутри участков: каждое поле —
##             бесшовная по горизонтали картинка, повтор с плавным стыком;
##           textures/farm_props.png (+ .json) — стог, тюки, тачка, плуг,
##             корыто, вилы с граблями, плетень (секция, короткая секция,
##             сломанная, боковой ряд кольев под длину секции);
##           textures/bonfire_unlit.png / bonfire_lit.png — костёр в одном
##             кадре (смещение центра кольца — в farm_props.json).
##   apply — сцена reference_map.tscn:
##           FarmGround -> farm_fields_hd.png без затемнения;
##           старый забор фермы (перила причала, повёрнутые боком) -> плетень
##             той же длины на тех же местах: коллизия забора не меняется;
##           пропсы фермы с коллизией у основания (после — перепечь навмеш);
##           шесть костров карты получают новую картинку (bonfire.gd, art_*).
##
## Запуск:
##   godot --headless --path . -s res://tools/farm_bonfire.gd -- bake
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/farm_bonfire.gd -- apply
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res

const AU := preload("res://tools/art_util.gd")
const SCENE := "res://reference_map_level/reference_map.tscn"
const HD := "res://reference_map_level/textures/src/hd/"
const TEX := "res://reference_map_level/textures/"
const FIELDS_OLD := TEX + "farm_fields.png"
const FIELDS := TEX + "farm_fields_hd.png"
const PROPS := TEX + "farm_props.png"
const META := TEX + "farm_props.json"
const BF_UNLIT := TEX + "bonfire_unlit.png"
const BF_LIT := TEX + "bonfire_lit.png"
## Текселей на px мира у запечённых картинок (спрайт со scale 1/TPX)
const TPX := 2

## Участки старого листа фермы (px листа, лист выводится со scale 0.5):
## [x, y, w, h, картинка поля, px мира на px картинки]. Масштаб — по герою
## (~45 px): колос ~35 px, кочан ~25 px, тыква ~25-30 px
const PLOTS := [
	[24, 24, 1030, 394, "farm/field_wheat", 0.2],
	[24, 562, 1030, 370, "farm/field_cabbage", 0.18],
	[24, 958, 1030, 274, "farm/field_ploughed", 0.2],
	[24, 1258, 1030, 300, "farm/field_pumpkin", 0.17],
	[24, 1588, 1030, 300, "farm/field_wheat", 0.2],
]

## Ширина самой фермы в листе (правее — старое пугало, не выводится)
const FARM_W := 1080
## Участки расширяются на столько px листа: закрывают старый пунктир по краю
const GROW := 8
## Межи и дорожка: HD-грунт, px мира на px картинки
const DIRT_K := 0.22
## Растворение внешнего края фермы, px листа
const EDGE_FADE := 28.0

## Предметы листа props/farm (прямоугольники нарезки, px листа) и размер на
## карте: ["w"|"h", px мира] — по ширине или по высоте
const ITEMS := {
	"haystack": [Rect2i(8, 8, 376, 438), "h", 96.0],
	"bale_a": [Rect2i(412, 44, 264, 172), "w", 54.0],
	"bale_b": [Rect2i(416, 214, 270, 176), "w", 54.0],
	"wheelbarrow": [Rect2i(756, 32, 408, 296), "w", 72.0],
	"plough": [Rect2i(1106, 74, 422, 302), "w", 80.0],
	"tools": [Rect2i(790, 320, 244, 316), "h", 58.0],
	"trough": [Rect2i(200, 448, 422, 194), "w", 76.0],
	# Плетень: секция целиком = одна старая секция забора (103 px мира)
	"fence": [Rect2i(40, 662, 732, 152), "w", 110.0],
	# Короткая — левые две трети секции (обрез по столбу)
	"fence_short": [Rect2i(40, 662, 500, 152), "w", 62.0],
	"fence_broken": [Rect2i(200, 852, 530, 154), "w", 110.0],
}
## Боковой ряд: левый ряд кольев из куска «забор уходит на север» (GPT
## нарисовал два параллельных ряда — берётся один), копии стопкой
const SIDE_SRC := Rect2i(862, 646, 44, 172)
## Шаг стопки — расстояние между основаниями переднего и заднего кола, px листа
const SIDE_STEP := 80
const SIDE_K := 0.3
const SIDE_LENGTHS := [103, 65]

## Костёр: ширина кольца камней на карте, px мира (герой ~45 px)
const BONFIRE_RING_W := 74.0
## Куда встаёт герой на отдыхе (от центра кольца): справа-снизу, кроме
## костров, у которых там коллизия карты
const REST_OVERRIDE := {"BonfireMarket": Vector2(0, 46)}

## Пропсы на ферме: [предмет, позиция основания (px мира), коллизия w x h у
## основания (0 — без коллизии), отразить]
const PLACE := [
	["haystack", Vector2(-2786, 1012), Vector2(64, 20), false],
	["bale_a", Vector2(-2716, 1022), Vector2(46, 14), false],
	["haystack", Vector2(-2370, 1760), Vector2(64, 20), true],
	["bale_b", Vector2(-2436, 1754), Vector2(46, 14), false],
	["bale_a", Vector2(-2604, 1764), Vector2(46, 14), true],
	["plough", Vector2(-2752, 1428), Vector2(60, 12), false],
	["wheelbarrow", Vector2(-2362, 1594), Vector2(54, 14), true],
	["trough", Vector2(-2792, 1284), Vector2(68, 14), false],
	["tools", Vector2(-2322, 1324), Vector2.ZERO, false],
]

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["bake"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[farm_bonfire] ", r)
	quit()


# ───────────────────────── bake ─────────────────────────

func _step_bake() -> void:
	_bake_fields()
	var meta := _bake_props()
	meta["bonfire"] = _bake_bonfire()
	var f := FileAccess.open(ProjectSettings.globalize_path(META), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	for p in [FIELDS, PROPS, BF_UNLIT, BF_LIT]:
		AU.write_import(p, false)
	report.append("bake готов — теперь: godot --headless --path . --import, затем apply")


func _bake_fields() -> void:
	var old := Image.load_from_file(ProjectSettings.globalize_path(FIELDS_OLD))
	old.convert(Image.FORMAT_RGBA8)
	# Всё вне участков (межи, дорожка, рамка) — заново из HD-грунта: в старом
	# листе там пиксельная земля и жёлтый пунктир по краю участков
	var base := Image.create(old.get_width(), old.get_height(), false, Image.FORMAT_RGBA8)
	var dirt := AU.load_hd(HD, "ground_dirt_tracks")
	var c := dirt.get_size() / 2
	dirt = dirt.get_region(Rect2i(c - Vector2i(320, 320), Vector2i(640, 640)))
	dirt = AU.resize_clean(dirt, roundi(640 * DIRT_K * 2.0), roundi(640 * DIRT_K * 2.0))
	_fill_tiled(base, Rect2i(0, 0, FARM_W, old.get_height()), dirt, 0, 0.0)
	# Столбец справа (старое пугало, его использует hd_props) — как был
	base.blit_rect(old, Rect2i(FARM_W, 0, old.get_width() - FARM_W, old.get_height()), Vector2i(FARM_W, 0))
	var cache := {}
	for p in PLOTS:
		var rect := Rect2i(p[0], p[1], p[2], p[3]).grow(GROW)
		var key := "%s@%s" % [p[4], p[5]]
		if not cache.has(key):
			var src := AU.load_hd(HD, p[4])
			# Лист фермы выводится со scale 0.5: 2 px листа на px мира
			var k: float = p[5] * 2.0
			cache[key] = AU.resize_clean(src, roundi(src.get_width() * k), roundi(src.get_height() * k))
		var tile: Image = cache[key]
		# Начало повтора у каждого участка своё — одинаковые поля не совпадают
		var shift := int(_hash(p[1], 7) * tile.get_width())
		_fill_tiled(base, rect, tile, shift, 14.0)
	# Внешний край фермы растворяется в земле карты (иначе виден прямоугольник)
	for y in base.get_height():
		for x in FARM_W:
			var e := minf(minf(x, FARM_W - 1 - x), minf(y, base.get_height() - 1 - y))
			if e < EDGE_FADE:
				var px := base.get_pixel(x, y)
				px.a = e / EDGE_FADE
				base.set_pixel(x, y, px)
	var err := base.save_png(ProjectSettings.globalize_path(FIELDS))
	report.append("поля: %d участков в %s (%s)" % [PLOTS.size(), FIELDS.get_file(), error_string(err)])


## Заливка участка повтором плитки: стыки по горизонтали и вертикали — плавный
## переход на OV пикселей (плитки от GPT бесшовны не идеально), край участка —
## мягкий переход в межу на feather пикселей (0 — без перехода)
func _fill_tiled(dst: Image, rect: Rect2i, tile: Image, shift: int, feather: float) -> void:
	const OV := 48
	var tw := tile.get_width()
	var th := tile.get_height()
	var step_x := tw - OV
	var step_y := th - OV
	for y in rect.size.y:
		var ty := y % step_y
		var y2 := ty + step_y           # тот же пиксель в предыдущей плитке
		var wy := 1.0
		if y >= step_y and ty < OV:
			wy = float(ty) / OV
		for x in rect.size.x:
			var sx := x + shift
			var tx := sx % step_x
			var c := _blend_x(tile, tx, sx, step_x, ty)
			if wy < 1.0 and y2 < th:
				c = _blend_x(tile, tx, sx, step_x, y2).lerp(c, wy)
			var dx := minf(x, rect.size.x - 1 - x)
			var dy := minf(y, rect.size.y - 1 - y)
			var a := 1.0 if feather <= 0.0 else clampf(minf(dx, dy) / feather, 0.0, 1.0)
			var px := rect.position + Vector2i(x, y)
			var old := dst.get_pixelv(px)
			var out := old.lerp(c, a)
			out.a = 1.0
			dst.set_pixelv(px, out)


func _blend_x(tile: Image, tx: int, sx: int, step_x: int, ty: int) -> Color:
	const OV := 48
	var c := tile.get_pixel(tx, ty)
	var tx2 := tx + step_x
	if sx >= step_x and tx < OV and tx2 < tile.get_width():
		c = tile.get_pixel(tx2, ty).lerp(c, float(tx) / OV)
	return c


func _bake_props() -> Dictionary:
	var sheet := AU.load_hd(HD, "props/farm")
	sheet = AU.clean_edges(sheet)
	# Тон — наполовину к HD-пропсам деревни: лист farm рыжее, а полная
	# подгонка делала дерево серым
	var village := AU.load_hd(HD, "props/village")
	sheet = AU.match_tone(sheet, AU.mean_color(sheet).lerp(AU.mean_color(village), 0.5).darkened(0.03), 1.0)
	var pieces := {}
	for name in ITEMS:
		var spec: Array = ITEMS[name]
		var reg: Rect2i = spec[0]
		var im := AU.keep_main(sheet.get_region(reg))
		var k: float = spec[2] / (im.get_width() if spec[1] == "w" else im.get_height())
		pieces[name] = _bake_size(im, k)
	# Боковой ряд плетня: копии стопкой, нижние поверх верхних
	var side := sheet.get_region(SIDE_SRC)
	side = side.get_region(side.get_used_rect())
	for L in SIDE_LENGTHS:
		var h_src := int(L / SIDE_K)
		var strip := Image.create(side.get_width(), h_src + side.get_height(), false, Image.FORMAT_RGBA8)
		var y := 0
		var tops := []
		while y <= h_src:
			tops.append(y)
			y += SIDE_STEP
		for t in tops:
			strip.blend_rect(side, Rect2i(Vector2i.ZERO, side.get_size()), Vector2i(0, t))
		strip = strip.get_region(strip.get_used_rect())
		pieces["fence_side_%d" % L] = _bake_size(strip, SIDE_K)

	# Упаковка в атлас по рядам
	var names := pieces.keys()
	names.sort_custom(func(a, b): return (pieces[a] as Image).get_height() > (pieces[b] as Image).get_height())
	const W := 1024
	const PAD := 4
	var x := PAD
	var y0 := PAD
	var row_h := 0
	var rects := {}
	for n in names:
		var im: Image = pieces[n]
		if x + im.get_width() + PAD > W:
			x = PAD
			y0 += row_h + PAD
			row_h = 0
		rects[n] = Rect2i(x, y0, im.get_width(), im.get_height())
		x += im.get_width() + PAD
		row_h = maxi(row_h, im.get_height())
	var atlas := Image.create(W, y0 + row_h + PAD, false, Image.FORMAT_RGBA8)
	var meta := {}
	for n in names:
		var r: Rect2i = rects[n]
		atlas.blit_rect(pieces[n], Rect2i(Vector2i.ZERO, r.size), r.position)
		meta[n] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var err := atlas.save_png(ProjectSettings.globalize_path(PROPS))
	report.append("пропсы: %d картинок в %s %dx%d (%s)" % [names.size(), PROPS.get_file(), atlas.get_width(), atlas.get_height(), error_string(err)])
	return meta


## Картинка в плотности TPX текселей на px мира, k — px мира на px исходника
func _bake_size(im: Image, k: float) -> Image:
	var w := maxi(roundi(im.get_width() * k * TPX), 1)
	var h := maxi(roundi(im.get_height() * k * TPX), 1)
	var out := AU.resize_clean(im, w, h)
	return AU.unsharp(out, 0.3)


## Обе картинки костра — в одном кадре (общий обрез), центр кольца — точка узла
func _bake_bonfire() -> Dictionary:
	var unlit := AU.load_hd(HD, "props/bonfire_unlit")
	var lit := AU.load_hd(HD, "props/bonfire_lit")
	var u := unlit.get_used_rect().merge(lit.get_used_rect())
	unlit = AU.clean_edges(unlit.get_region(u))
	lit = AU.clean_edges(lit.get_region(u))
	# Одинаковый сдвиг тона у обеих: зажжённая остаётся ярче потухшей
	var village := AU.load_hd(HD, "props/village")
	var m := AU.mean_color(unlit)
	var target := AU.mean_color(village)
	var gain := Color(target.r / m.r, target.g / m.g, target.b / m.b)
	unlit = _gain(unlit, gain)
	lit = _gain(lit, gain)
	# Ширина кольца — ширина обреза потухшей картинки (меч уже кольца)
	var ring_w := float(unlit.get_used_rect().size.x)
	var k := BONFIRE_RING_W / ring_w
	var w := roundi(unlit.get_width() * k * TPX)
	var h := roundi(unlit.get_height() * k * TPX)
	var a := AU.unsharp(AU.resize_clean(unlit, w, h), 0.3)
	var b := AU.unsharp(AU.resize_clean(lit, w, h), 0.3)
	a.save_png(ProjectSettings.globalize_path(BF_UNLIT))
	b.save_png(ProjectSettings.globalize_path(BF_LIT))
	# Центр кольца на земле: по x — середина, по y — от низа на ~0.36 ширины
	# кольца (эллипс камней в виде 3/4 и высота самих камней)
	var used := unlit.get_used_rect()
	var cx := (used.position.x + used.size.x * 0.5) * k * TPX
	var cy := (used.end.y - used.size.x * 0.36) * k * TPX
	report.append("костёр: %dx%d текселей, центр кольца (%d, %d)" % [w, h, cx, cy])
	return {"offset": [-cx, -cy], "size": [w, h]}


func _gain(img: Image, g: Color) -> Image:
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		d[i] = clampi(int(d[i] * g.r), 0, 255)
		d[i + 1] = clampi(int(d[i + 1] * g.g), 0, 255)
		d[i + 2] = clampi(int(d[i + 2] * g.b), 0, 255)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 1000) / 1000.0


# ───────────────────────── apply ─────────────────────────

func _step_apply() -> void:
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(META)))
	var atlas := load(PROPS) as Texture2D
	var fields := load(FIELDS) as Texture2D
	if atlas == null or fields == null or load(BF_UNLIT) == null:
		report.append("ОШИБКА: текстуры не импортированы — сначала bake и --import")
		return
	var objects := lvl.get_node("Objects")

	# Поля
	var fg := lvl.get_node("FarmGround") as Sprite2D
	fg.texture = fields
	fg.modulate = Color.WHITE

	# Забор: старые перила (hd_props railing) по периметру фермы
	var farm := Rect2(-2880, 790, 620, 1020)
	var replaced := 0
	for n in objects.get_children():
		if not (n is Sprite2D):
			continue
		var s := n as Sprite2D
		var pos: Vector2
		var length: float
		var vertical: bool
		if s.has_meta("farm_fence"):
			# Уже заменена — исходные данные старой секции сохранены в мете
			# (атлас мог перепаковаться, координаты куска обновляются)
			pos = s.get_meta("fence_pos")
			length = s.get_meta("fence_len")
			vertical = s.get_meta("fence_vertical")
		else:
			if s.texture == null or not s.texture.resource_path.ends_with("hd_props.png"):
				continue
			if not farm.has_point(s.position) or not s.region_enabled:
				continue
			var sz := s.region_rect.size
			var is_rail := (sz == Vector2(206, 25)) or (sz == Vector2(110, 36)) or (sz == Vector2(130, 43))
			if not is_rail:
				continue
			pos = s.position
			length = sz.x * absf(s.scale.x)
			vertical = absf(absf(s.rotation) - PI / 2.0) < 0.01
			s.set_meta("fence_pos", pos)
			s.set_meta("fence_len", length)
			s.set_meta("fence_vertical", vertical)
		var piece := ""
		if vertical:
			piece = "fence_side_103" if length > 80.0 else "fence_side_65"
		else:
			piece = "fence" if length > 80.0 else "fence_short"
			# Одна секция внизу — сломанная, для разнообразия
			if piece == "fence" and is_equal_approx(pos.y, 1786.0) and is_equal_approx(pos.x, -2556.0):
				piece = "fence_broken"
		var r: Array = meta[piece]
		var tex_w: float = r[2] / float(TPX)
		var tex_h: float = r[3] / float(TPX)
		s.texture = atlas
		s.region_rect = Rect2(r[0], r[1], r[2], r[3])
		s.scale = Vector2(1.0 / TPX, 1.0 / TPX)
		s.rotation = 0.0
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if vertical:
			# Старая секция шла от pos вверх на length: низ ряда — в pos
			s.position = Vector2(pos.x - tex_w * 0.5, pos.y)
			s.offset = Vector2(0, -r[3])
		else:
			# Горизонтальная: от pos вправо, основание — на линии забора
			s.position = Vector2(pos.x - (tex_w - length) * 0.5, pos.y + 2.0)
			s.offset = Vector2(0, -r[3])
		s.set_meta("farm_fence", true)
		replaced += 1

	# Пропсы
	var placed := 0
	for p in PLACE:
		var name: String = p[0]
		var node_name := "Farm_%s_%d" % [name, placed]
		var old := objects.get_node_or_null(node_name)
		if old:
			objects.remove_child(old)
			old.free()
		var r: Array = meta[name]
		var spr := Sprite2D.new()
		spr.name = node_name
		spr.texture = atlas
		spr.region_enabled = true
		spr.region_rect = Rect2(r[0], r[1], r[2], r[3])
		spr.centered = false
		spr.scale = Vector2(1.0 / TPX, 1.0 / TPX)
		spr.flip_h = p[3]
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Узел — в точке основания (по ней y-sort), картинка над ней
		spr.position = p[1]
		spr.offset = Vector2(-r[2] * 0.5, -r[3] + 4.0)
		objects.add_child(spr)
		spr.owner = lvl
		var col: Vector2 = p[2]
		if col != Vector2.ZERO:
			var body := StaticBody2D.new()
			body.name = "Body"
			var cs := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			# Тело — дочернее спрайта со scale 1/TPX: размеры в текселях
			shape.size = col * TPX
			cs.shape = shape
			cs.position = Vector2(0, -col.y * 0.5 * TPX)
			spr.add_child(body)
			body.owner = lvl
			body.add_child(cs)
			cs.owner = lvl
		placed += 1

	# Костры
	var bf: Dictionary = meta["bonfire"]
	var nb := 0
	for n in objects.get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with("bonfire.gd"):
			n.set("art_unlit", load(BF_UNLIT))
			n.set("art_lit", load(BF_LIT))
			n.set("art_offset", Vector2(bf["offset"][0], bf["offset"][1]))
			n.set("art_scale", 1.0 / TPX)
			n.set("rest_offset", REST_OVERRIDE.get(String(n.name), Vector2(48, 20)))
			n.set("interact_radius", 64.0)
			nb += 1

	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	report.append("apply: забор %d секций, пропсов %d, костров %d, сцена (%s)" % [replaced, placed, nb, error_string(err)])
	report.append("дальше — перепечь навмеш (tools/bake_navmesh.gd): у пропсов и костров есть коллизия")
