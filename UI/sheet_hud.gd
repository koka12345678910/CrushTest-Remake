extends RefCounted
## sheet_hud.gd — нарисованный HUD Хальварда (рыцаря) из листа
## UI/UI_HUD/halvard/HUD_Halvard.png (прозрачный фон, детали слоями):
## полоса = пустая рамка с ромбами + заливка + тёмный "след" урона, у каждой
## полосы свой цвет (красная — здоровье, синяя — Одр, зелёная — выносливость);
## длинная полоса с ромбом посередине — концентрация; кольцо с квадратиком —
## быстрый слот (иконка в кольце, заряды в квадратике); круглая рамка —
## медальон.
##
## Всё нарисованное на листе крупнее, чем нужно на HUD. Картинки не
## масштабируются на лету (без мип-карт мелкие линии рвутся, крупные мылятся):
## каждая деталь заранее вырезается и уменьшается Ланцошем ровно до своего
## экранного размера (piece, bar_frame), кэш по размеру. Рамка полосы
## собирается под нужную длину: концы с ромбами 1:1, середина тянется.
##
## Все прямоугольники ниже — в пикселях листа.

const SHEET := "res://UI/UI_HUD/halvard/HUD_Halvard.png"

## Полосы: рамка (строки и столбцы рамки целиком), канал внутри неё (куда
## ложится заливка), заливка и след (обрезаны до самой полосы, без тени)
const BARS := {
	"hp": {"frame": Rect2(11, 3, 752, 67), "ch": Rect2(76, 26, 626, 25),
		"fill": Rect2(94, 72, 550, 30), "trail": Rect2(96, 112, 548, 24)},
	"stamina": {"frame": Rect2(11, 155, 752, 64), "ch": Rect2(76, 178, 626, 25),
		"fill": Rect2(95, 222, 550, 30), "trail": Rect2(96, 261, 548, 22)},
	"odr": {"frame": Rect2(11, 303, 752, 65), "ch": Rect2(76, 326, 626, 25),
		"fill": Rect2(95, 370, 549, 30), "trail": Rect2(96, 412, 548, 23)},
	# Концентрация: заливка — нейтральный след, окрашенный цветом концентрации;
	# ромб посередине рисуется ещё раз поверх заливки
	# (erase — кончик ромба соседней детали листа, попавший в прямоугольник)
	"posture": {"frame": Rect2(872, 679, 594, 85), "ch": Rect2(922, 714, 498, 17),
		"fill": Rect2(96, 112, 548, 24), "trail": null, "overlay": Rect2(1130, 679, 80, 85),
		"erase": [Rect2(872, 679, 250, 12)]},
	# Очки навыков: пустая полоса (без ромба, с крюками слева), заливка —
	# нейтральный след, окрашенный бронзой
	"skill": {"frame": Rect2(921, 92, 545, 40), "ch": Rect2(947, 101, 479, 23),
		"fill": Rect2(96, 112, 548, 24), "trail": null},
}

## Ромб с числом (очки навыков): на листе в нём нарисована "1" — она
## закрашивается тёмным ромбиком внутри внутренней каймы (digit_r), сам ромб
## вырезается по форме (вокруг на листе — кусок соседней полосы)
const SKILL_DIAMOND := {"rect": Rect2(825, 7, 104, 103), "center": Vector2(876.5, 58), "digit_r": 27.0}

## Кольцо быстрого слота: деталь, центр отверстия и его радиус, квадратик
## для зарядов (его тёмное поле)
const RING_ITEMS := {"rect": Rect2(272, 615, 268, 263), "center": Vector2(405.5, 752), "r": 81.0,
	"box": Rect2(447, 791, 62, 60)}
const RING_MAGIC := {"rect": Rect2(542, 614, 266, 264), "center": Vector2(675.5, 751), "r": 81.0,
	"box": Rect2(717, 790, 62, 60)}
## Круглая рамка медальона: деталь, центр и радиус отверстия
const MEDALLION := {"rect": Rect2(1095, 463, 134, 136), "center": Vector2(1163, 531), "r": 51.0}

## Обрезка по кругу (иконка в кольце, медальон)
const CIRCLE_MASK_CODE := """
shader_type canvas_item;
uniform float radius = 0.47;
uniform float feather = 0.03;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(radius, radius + feather, length(UV - vec2(0.5)));
}
"""

static var _img: Image
static var _cache := {}
static var _masks := {}


static func image() -> Image:
	if _img == null:
		if ResourceLoader.exists(SHEET):
			_img = (load(SHEET) as Texture2D).get_image()
		else:
			_img = Image.load_from_file(ProjectSettings.globalize_path(SHEET))
		if _img.is_compressed():
			_img.decompress()
		_img.convert(Image.FORMAT_RGBA8)
	return _img


## Деталь листа, уменьшенная Ланцошем ровно до size; dark — синие ремни
## перекрашены в тёмную сталь (_darken_blue)
static func piece(rect: Rect2, size: Vector2, dark := false) -> Texture2D:
	var sz := Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	var key := "%s@%s%s" % [rect, sz, " dark" if dark else ""]
	if not _cache.has(key):
		var part := image().get_region(Rect2i(rect))
		if dark:
			_darken_blue(part)
		part.resize(sz.x, sz.y, Image.INTERPOLATE_LANCZOS)
		_cache[key] = ImageTexture.create_from_image(part)
	return _cache[key]


## Синие ремни/верёвки на кольцах — в тёмную сталь: где синий заметно
## преобладает, цвет плавно уходит в серый той же яркости, притушенный
## (фактура остаётся, оттенок — нет). Сталь, бронза и чёрное не задеты
static func _darken_blue(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var excess := c.b - maxf(c.r, c.g)
			if excess <= 0.02:
				continue
			var t := smoothstep(0.02, 0.12, excess)
			var g := maxf(c.r, maxf(c.g, c.b)) * 0.42
			img.set_pixel(x, y, Color(c.lerp(Color(g, g * 0.98, g * 0.96), t), c.a))


## Кусок листа; прямоугольники erase (координаты листа) в нём стёрты
static func _region(rect: Rect2, erase: Array) -> Image:
	var img := image().get_region(Rect2i(rect))
	for e in erase:
		var r := Rect2i(Rect2(e).intersection(rect))
		if r.has_area():
			img.fill_rect(Rect2i(r.position - Vector2i(rect.position), r.size), Color(0, 0, 0, 0))
	return img


## Круглая рамка с прозрачным окном радиуса r вокруг center (координаты
## листа) — у рамок на листе поле внутри залито, а в окне должен быть
## портрет. Уменьшена Ланцошем до size
static func ring_with_hole(rect: Rect2, center: Vector2, r: float, size: Vector2, dark := false) -> Texture2D:
	var sz := Vector2i(roundi(size.x), roundi(size.y))
	var key := "hole%s@%s%s" % [rect, sz, " dark" if dark else ""]
	if not _cache.has(key):
		var img := image().get_region(Rect2i(rect))
		if dark:
			_darken_blue(img)
		var c := center - rect.position
		for y in img.get_height():
			for x in img.get_width():
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				if d < r:
					var px := img.get_pixel(x, y)
					px.a *= smoothstep(r - 2.0, r, d)
					img.set_pixel(x, y, px)
		img.resize(sz.x, sz.y, Image.INTERPOLATE_LANCZOS)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Ромб SKILL_DIAMOND без нарисованной цифры, вырезанный по форме ромба,
## уменьшенный до size
static func blank_diamond(size: Vector2) -> Texture2D:
	var sz := Vector2i(roundi(size.x), roundi(size.y))
	var key := "diamond@%s" % sz
	if not _cache.has(key):
		var rect: Rect2 = SKILL_DIAMOND["rect"]
		var img := image().get_region(Rect2i(rect))
		var c: Vector2 = SKILL_DIAMOND["center"] - rect.position
		var hw := rect.size.x * 0.5
		var hh := rect.size.y * 0.5
		var dr: float = SKILL_DIAMOND["digit_r"]
		var body := Color(0.035, 0.035, 0.04)
		for y in img.get_height():
			for x in img.get_width():
				var d := Vector2(x + 0.5, y + 0.5) - c
				var px := img.get_pixel(x, y)
				# вне ромба — чужое (кусок полосы), мягко в ноль
				px.a *= 1.0 - smoothstep(0.97, 1.0, absf(d.x) / hw + absf(d.y) / hh)
				# внутри внутренней каймы — гладкое тёмное поле вместо "1"
				var k := absf(d.x) + absf(d.y)
				if k < dr:
					px = Color(body, px.a).lerp(px, smoothstep(dr - 2.0, dr, k))
				img.set_pixel(x, y, px)
		img.resize(sz.x, sz.y, Image.INTERPOLATE_LANCZOS)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Рамка полосы длиной length в масштабе s: левый и правый концы (до и после
## канала) уменьшены как есть, середина — растянута до длины.
## Возвращает [текстура, канал в её координатах]
static func bar_frame(spec: Dictionary, length: float, s: float) -> Array:
	var fr: Rect2 = spec["frame"]
	var ch: Rect2 = spec["ch"]
	var h := roundi(fr.size.y * s)
	var lw := roundi((ch.position.x - fr.position.x) * s)
	var rw := roundi((fr.end.x - ch.end.x) * s)
	var mw := maxi(1, roundi(length) - lw - rw)
	var key := "bar%s@%d,%s" % [fr, roundi(length), s]
	if not _cache.has(key):
		var out := Image.create(lw + mw + rw, h, false, Image.FORMAT_RGBA8)
		var parts := [
			[Rect2(fr.position.x, fr.position.y, ch.position.x - fr.position.x, fr.size.y), lw, 0],
			[Rect2(ch.position.x, fr.position.y, ch.size.x, fr.size.y), mw, lw],
			[Rect2(ch.end.x, fr.position.y, fr.end.x - ch.end.x, fr.size.y), rw, lw + mw],
		]
		for p in parts:
			var img := _region(p[0], spec.get("erase", []))
			img.resize(p[1], h, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(img, Rect2i(0, 0, p[1], h), Vector2i(p[2], 0))
		_cache[key] = ImageTexture.create_from_image(out)
	var chr := Rect2(lw, roundi((ch.position.y - fr.position.y) * s), mw, roundi(ch.size.y * s))
	return [_cache[key], chr]


## Настроить нарисованную полосу (UI/SheetBar.gd) под длину length и масштаб s
static func setup_bar(bar, kind: String, length: float, s: float) -> void:
	var spec: Dictionary = BARS[kind]
	var fr := bar_frame(spec, length, s)
	var tex: Texture2D = fr[0]
	var ch: Rect2 = fr[1]
	bar.frame_tex = tex
	bar.channel = ch
	bar.size = tex.get_size()
	bar.fill_tex = piece(spec["fill"], ch.size)
	if spec["trail"] != null:
		bar.trail_tex = piece(spec["trail"], ch.size)
	if spec.has("overlay"):
		var ov: Rect2 = spec["overlay"]
		bar.overlay_tex = piece(ov, ov.size * s)
		bar.overlay_pos = ((ov.position - spec["frame"].position) * s).round()


## Обрезка по кругу радиуса radius (доля стороны картинки); по одной на радиус
static func mask_material(radius := 0.47) -> ShaderMaterial:
	if not _masks.has(radius):
		var sh := Shader.new()
		sh.code = CIRCLE_MASK_CODE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("radius", radius)
		_masks[radius] = m
	return _masks[radius]
