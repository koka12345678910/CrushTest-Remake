extends RefCounted
## clean_hud.gd — общий вид игрового HUD в ключе инвентаря (тема CLEAN в
## Inventory/ui/hero_inventory_skin.gd, плашки — Inventory/ui/proc_skin.gd):
## тёмные полупрозрачные плашки с едва заметной каймой, приглушённые
## заливки, без картинок и потёртостей. Золото — только акцент (выделенное/
## активное), остальное — оттенки серого.
##
## Пользуются: UI/health_stamina_bar.gd (портрет и полоски), UI/skill_points_bar.gd,
## Inventory/ui/quick_slot_ui.gd (быстрые слоты), Inventory/ui/hud.gd (золото),
## Player_scene/mage_hud.gd (души и руны).

## Палитра — та же, что у инвентаря (CLEAN["pal"] и цвета текста)
const FILL := Color(0.035, 0.035, 0.04, 0.78)
const BORDER := Color(1, 1, 1, 0.07)
const GOLD := Color(0.86, 0.68, 0.38)
const GOLD_HI := Color(1.0, 0.83, 0.5)
const TEXT := Color(0.88, 0.86, 0.82)
const TEXT_DIM := Color(0.56, 0.55, 0.53)
## Разделитель
const LINE := Color(1, 1, 1, 0.08)
## Канал полоски — темнее плашки, чтобы пустая часть читалась
const TRACK := Color(0.0, 0.0, 0.0, 0.55)
## След урона (отстающее значение) — светлый серый
const TRAIL := Color(0.8, 0.78, 0.74, 0.35)

const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const ProcSkin := preload("res://Inventory/ui/proc_skin.gd")

## Обрезка по кругу (портрет-медальон)
const CIRCLE_MASK_CODE := """
shader_type canvas_item;
uniform float radius = 0.47;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(radius - 0.01, radius + 0.01, length(UV - vec2(0.5)));
}
"""

static var _font: SystemFont
static var _masks := {}


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


## Плашка как у панелей инвентаря (ProcFrame): заливка, кайма 1 px, скругление r
static func box(r := 4, fill := FILL, border := BORDER) -> StyleBoxFlat:
	return ProcSkin.CleanU.box(fill, border, r)


## Шрифт инвентаря — системная антиква с кириллицей и нормальными цифрами
static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	return _font


static func label(text: String, font_size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	# Тонкая тень вместо толстой обводки — читается на любом фоне, но строже
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Иконка предмета — тот же шейдер, что в клетках инвентаря
static func icon_material(gain := 1.15) -> ShaderMaterial:
	return HeroSkin.icon_material(gain)


## Плашка-нода: StyleBoxFlat на весь размер; accent — тонкая золотая черта
## по низу (как под заголовками колонок инвентаря)
class Plate extends Control:
	var radius := 4
	var accent := false
	var fill := FILL
	var border := BORDER
	var _box: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if _box == null:
			_box = ProcSkin.CleanU.box(fill, border, radius)
		draw_style_box(_box, Rect2(Vector2.ZERO, size))
		if accent:
			draw_line(Vector2(size.x * 0.3, size.y + 4.0), Vector2(size.x * 0.7, size.y + 4.0), Color(GOLD, 0.35), 1.0)


## Круглая плашка-медальон под портрет: тёмный круг с мягкой тёмной кромкой,
## без светлых колец. Портрет (с круглой маской) отдаётся в set_portrait —
## он ложится между тёмным кругом и кромкой
class Medallion extends Control:
	var inner_radius := 0.0
	var _rings: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_portrait(portrait: Control) -> void:
		add_child(portrait)
		if _rings == null:
			_rings = Control.new()
			_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_rings.draw.connect(_draw_rings)
		else:
			remove_child(_rings)
		_rings.size = size
		add_child(_rings)

	func _draw() -> void:
		# Непрозрачный: под медальоном начинаются полоски HUD, они не должны просвечивать
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Color(FILL, 1.0))

	## Светлых колец нет (ни золотого, ни тонкой каймы лица) — только мягкая
	## тёмная кромка: лицо растворяется в тёмном круге, край не светится
	func _draw_rings() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		for i in 4:
			_rings.draw_arc(c, r - 1.0 - i * 1.5, 0, TAU, 96, Color(0, 0, 0, 0.5 - i * 0.11), 2.0, true)


## Полоска: плашка-канал, внутри с отступом inset px — след урона и плоская
## заливка. Те же поля, что у старых HudBar/SheetBar (ratio, delayed_ratio,
## fill_color, centered, fill_mod) — health_stamina_bar пишет в них как раньше.
## centered — заливка растёт от середины (концентрация), по центру черта
class Bar extends Control:
	var fill_color := Color.WHITE:
		set(v):
			if v != fill_color:
				fill_color = v
				queue_redraw()
	var fill_mod := Color.WHITE:
		set(v):
			fill_mod = v
			queue_redraw()
	var ratio := 1.0:
		set(v):
			v = clampf(v, 0.0, 1.0)
			if not is_equal_approx(v, ratio):
				ratio = v
				queue_redraw()
	var delayed_ratio := 0.0:
		set(v):
			v = clampf(v, 0.0, 1.0)
			if not is_equal_approx(v, delayed_ratio):
				delayed_ratio = v
				queue_redraw()
	var centered := false
	## Отступ заливки от края плашки (1 — для стопки полосок вплотную)
	var inset := 2.0
	var _box: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Сила блика сверху (доля белого у верхнего края заливки) и тени снизу
	const GLOSS := 0.2
	const SHADE := 0.28
	var _track: StyleBoxFlat
	var _fill_box: StyleBoxFlat

	## Концы скруглены на половину высоты (капсула): канал, след урона и
	## заливка. Цвет заливки тот же тусклый, поверх — лёгкий глянец: сверху
	## светлее, к середине сходит на нет, низ чуть темнее
	func _draw() -> void:
		if _box == null:
			_box = ProcSkin.CleanU.box(FILL, BORDER, 0)
			_track = ProcSkin.CleanU.box(TRACK, Color(0, 0, 0, 0), 0)
			_track.set_border_width_all(0)
			_fill_box = ProcSkin.CleanU.box(Color.WHITE, Color(0, 0, 0, 0), 0)
			_fill_box.set_border_width_all(0)
		_box.set_corner_radius_all(ceili(size.y * 0.5))
		draw_style_box(_box, Rect2(Vector2.ZERO, size))
		var ch := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		_track.set_corner_radius_all(ceili(ch.size.y * 0.5))
		draw_style_box(_track, ch)
		if centered:
			var half := ch.size.x * 0.5 * ratio
			_fill(ch.get_center().x - half, ch.get_center().x + half, ch, fill_color * fill_mod)
			var cx := roundf(size.x * 0.5)
			draw_line(Vector2(cx, -3), Vector2(cx, size.y + 3), Color(TEXT, 0.45), 1.0)
			return
		if delayed_ratio > ratio:
			_fill(ch.position.x, ch.position.x + ch.size.x * delayed_ratio, ch, TRAIL, false)
		_fill(ch.position.x, ch.position.x + ch.size.x * ratio, ch, fill_color * fill_mod)

	func _fill(a: float, b: float, ch: Rect2, col: Color, gloss := true) -> void:
		if b - a < 0.5:
			return
		var r := Rect2(a, ch.position.y, b - a, ch.size.y)
		# StyleBoxFlat сам ужимает скругление, если заливка короче высоты
		_fill_box.bg_color = col
		_fill_box.set_corner_radius_all(ceili(ch.size.y * 0.5))
		draw_style_box(_fill_box, r)
		if not gloss:
			return
		# Блик и тень — половинки той же капсулы на 1 px внутри заливки
		# (края полигонов без сглаживания, на светлой кромке не видны)
		var g := r.grow(-1.0)
		if g.size.x < 2.0 or g.size.y < 2.0:
			return
		_half(g, true, Color(1, 1, 1, GLOSS), Color(1, 1, 1, 0.0))
		_half(g, false, Color(0, 0, 0, 0.0), Color(0, 0, 0, SHADE))

	## Верхняя (top) или нижняя половина капсулы r; цвет меняется по высоте
	## линейно от c0 (верх половины) до c1 (низ половины)
	func _half(r: Rect2, top: bool, c0: Color, c1: Color) -> void:
		var ry := r.size.y * 0.5
		var rx := minf(ry, r.size.x * 0.5)
		var cy := r.position.y + ry
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var steps := 8
		# Левая дуга, затем правая; верх — углы от PI до 2PI, низ — от 0 до PI
		# Короткая заливка: центры дуг совпали — вторая дуга без первой точки,
		# иначе полигон с двумя одинаковыми вершинами не триангулируется
		var joined := r.size.x - rx * 2.0 < 0.01
		for side in 2:
			var cx := r.position.x + rx if side == 0 else r.end.x - rx
			for i in range(1 if side == 1 and joined else 0, steps + 1):
				var t := float(i) / steps
				var ang: float
				if top:
					ang = PI + (t * 0.5 if side == 0 else 0.5 + t * 0.5) * PI
				else:
					ang = (t * 0.5 if side == 0 else 0.5 + t * 0.5) * PI
					ang = PI - ang
				var p := Vector2(cx + cos(ang) * rx, cy + sin(ang) * ry)
				pts.append(p)
				var k := (p.y - r.position.y) / ry if top else (p.y - cy) / ry
				cols.append(c0.lerp(c1, clampf(k, 0.0, 1.0)))
		draw_polygon(pts, cols)


## Значки, нарисованные линиями, как значки категорий инвентаря (CleanIcon):
## монета (золото) и огонёк (души)
class Glyph extends Control:
	var kind := "coin"
	var color := TEXT_DIM

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		# Нарисован под 24 px — при другом размере всё пропорционально
		var k := size.x / 24.0
		match kind:
			"coin":
				draw_arc(c, 8.0 * k, 0, TAU, 28, color, 1.6 * k, true)
				draw_arc(c, 4.5 * k, 0, TAU, 20, Color(color, 0.6), 1.0 * k, true)
			"soul":
				# Капля пламени: круглый низ, острый верх
				var out := PackedVector2Array([c + Vector2(0, -11) * k])
				for i in range(17):
					var a := -PI * 0.15 + (PI * 1.3) * float(i) / 16.0
					out.append(c + (Vector2(cos(a), sin(a)) * 7.0 + Vector2(0, 3)) * k)
				out.append(c + Vector2(0, -11) * k)
				draw_polyline(out, color, 1.6 * k, true)
				draw_circle(c + Vector2(0, 4) * k, 2.2 * k, Color(color, 0.8))


## Часы суток — как настенные, но на 24 часа: стрелка делает один оборот за
## игровые сутки. Вверху солнце (полдень), внизу луна (полночь), слева —
## рассвет, справа — закат; верхняя половина циферблата чуть теплее (день),
## нижняя — чуть холоднее (ночь). Эмблема того, что сейчас на небе, светится,
## другая тускнеет. Тонкая минутная стрелка делает оборот за игровой час
## (от верха по часовой, как на обычных часах) — движение видно всё время.
## Время берётся у Weather (Levels/weather.gd)
class DayClock extends Control:
	const SUN := Color(0.95, 0.76, 0.42)
	const MOON := Color(0.8, 0.85, 0.95)
	var _last_hour := -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		visible = Weather.is_active()
		# Стрелки идут плавно — перерисовка каждый кадр, пока время идёт
		if visible and Weather.hour != _last_hour:
			_last_hour = Weather.hour
			queue_redraw()

	## Направление на час h: полночь внизу, по часовой — 6 слева, 12 вверху
	func _dir(h: float) -> Vector2:
		var a := h / 24.0 * TAU
		return Vector2(-sin(a), cos(a))

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		# Нарисованы под радиус 46 px — при другом размере всё пропорционально
		var k := r / 46.0
		var day := 1.0 - Weather.night

		# Циферблат: плашка, тёплая (день) и холодная (ночь) половины
		draw_circle(c, r, FILL)
		draw_polygon(_half(c, r - 4.0 * k, true), [Color(SUN, 0.07)])
		draw_polygon(_half(c, r - 4.0 * k, false), [Color(MOON, 0.06)])
		draw_line(c + Vector2(-r + 7.0 * k, 0), c + Vector2(r - 7.0 * k, 0), LINE, 1.0)
		draw_arc(c, r - 0.5, 0, TAU, 72, Color(1, 1, 1, 0.1), 1.0, true)

		# Деления: каждый час, крупнее — каждые 6 часов
		for i in 24:
			var major := i % 6 == 0
			var d := _dir(float(i))
			var outer := r - 6.0 * k
			var inner := outer - (5.0 if major else 2.5) * k
			draw_line(c + d * inner, c + d * outer, Color(TEXT_DIM, 0.85 if major else 0.45), 1.5 if major else 1.0, true)

		# Минутная стрелка: длинная, тонкая, тусклая — под часовой
		var m := fposmod(Weather.hour, 1.0) * TAU
		var minute := Vector2(sin(m), -cos(m))
		draw_line(c - minute * 4.0 * k, c + minute * (r - 7.0 * k), Color(TEXT_DIM, 0.9), 1.2 * k, true)

		# Стрелка с противовесом, ось — золотая, как акценты HUD
		var hand := _dir(Weather.hour)
		draw_line(c - hand * 7.0 * k, c + hand * (r - 11.0 * k), TEXT, 2.0 * k, true)
		draw_circle(c + hand * (r - 11.0 * k), 2.2 * k, TEXT)
		draw_circle(c, 3.6 * k, GOLD)
		draw_arc(c, 3.6 * k, 0, TAU, 16, GOLD, 1.0, true)
		draw_circle(c, 1.4 * k, FILL)
		# Эмблемы — поверх стрелки: в полдень она "указывает" на солнце, в
		# полночь — на луну, а кончик всё равно виден за эмблемой
		_draw_sun(c + Vector2(0, -r * 0.5), 7.0 * k, Color(SUN, lerpf(0.3, 1.0, day)))
		_draw_moon(c + Vector2(0, r * 0.5), 8.5 * k, Color(MOON, lerpf(0.3, 1.0, 1.0 - day)))

	## Полукруг: верхний (top) или нижний
	func _half(c: Vector2, r: float, top: bool) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 33:
			var a := PI * float(i) / 32.0
			pts.append(c + Vector2(cos(a), -sin(a) if top else sin(a)) * r)
		return pts

	func _draw_sun(at: Vector2, r: float, col: Color) -> void:
		draw_circle(at, r, col)
		draw_arc(at, r, 0, TAU, 24, col, 1.0, true)
		for i in 8:
			var d := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
			draw_line(at + d * (r + 2.0), at + d * (r + 4.5 * r / 6.0), col, maxf(1.0, r / 5.0), true)

	## Серп: внешняя дуга — полкруга слева, внутренняя — узкий эллипс обратно
	func _draw_moon(at: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 17:
			var s := -PI * 0.5 + PI * float(i) / 16.0
			pts.append(at + Vector2(-cos(s) * r, sin(s) * r))
		for i in 17:
			var s := PI * 0.5 - PI * float(i) / 16.0
			pts.append(at + Vector2(-cos(s) * r * 0.3, sin(s) * r))
		draw_colored_polygon(pts, col)
		draw_polyline(pts, col, 1.0, true)
