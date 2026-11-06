extends RefCounted
## proc_skin.gd — детали инвентаря героя (hero_inventory_skin.gd): тёмные
## полупрозрачные плашки без картинок. Каждая деталь — одна StyleBoxFlat
## или пара линий, перерисовка только при смене размера/состояния — дёшево.
##
## Палитра приходит словарём pal (theme["pal"]): fill — заливка панели,
## border — едва заметная кайма, accent — золотистая черта под заголовком.


## Плашка: заливка fill, кайма border в 1 px, скругление r, мягкая тень
class CleanU:
	static func box(fill: Color, border: Color, r: int, shadow := 0) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(r)
		sb.anti_aliasing = true
		if shadow > 0:
			sb.shadow_color = Color(0, 0, 0, 0.3)
			sb.shadow_size = shadow
		return sb

	## Ромб с обводкой (метка на значке талисманов)
	static func diamond(c: CanvasItem, at: Vector2, r: float, fill: Color, line: Color, width := 1.2) -> void:
		var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
		c.draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		c.draw_polyline(pts, line, width, true)


## Панель — тёмная полупрозрачная плашка со скруглёнными углами
class ProcFrame extends Control:
	var pal: Dictionary
	var _box: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if _box == null:
			_box = CleanU.box(pal["fill"], pal["border"], 6, 10)
		draw_style_box(_box, Rect2(Vector2.ZERO, size))


## Клетка сетки — тёмный полупрозрачный квадрат
class ProcCell extends Control:
	static var _box: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if _box == null:
			_box = CleanU.box(Color(0, 0, 0, 0.32), Color(1, 1, 1, 0.07), 4)
		draw_style_box(_box, Rect2(Vector2.ZERO, size))


## Разделитель — тонкая черта, гаснущая к концам
class ProcDivider extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cy := size.y * 0.5
		var lc := Color(1, 1, 1, 0.08)
		draw_polyline_colors(PackedVector2Array([Vector2(0, cy), Vector2(size.x * 0.2, cy), Vector2(size.x * 0.8, cy), Vector2(size.x, cy)]),
				PackedColorArray([Color(lc, 0.0), lc, lc, Color(lc, 0.0)]), 1.0)


## Под заголовком колонки — только тонкая золотистая черта
class ProcPlaque extends Control:
	var pal: Dictionary

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_line(Vector2(size.x * 0.3, size.y - 4), Vector2(size.x * 0.7, size.y - 4), Color(pal["accent"], 0.35), 1.0)


## Полоса вкладок — плашка, между вкладками тонкие черты. seg_rects():
## [край, вкладка, промежуток, вкладка, ..., край] — вкладки на нечётных местах
class ProcTabBar extends Control:
	var pal: Dictionary
	var count := 4
	const CAP := 46.0
	const STUD := 34.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func seg_rects() -> Array:
		var tab_w := (size.x - CAP * 2.0 - STUD * (count - 1)) / count
		var out := [Rect2(0, 0, CAP, size.y)]
		var x := CAP
		for i in count:
			if i > 0:
				out.append(Rect2(x, 0, STUD, size.y))
				x += STUD
			out.append(Rect2(roundf(x), 0, roundf(tab_w), size.y))
			x += tab_w
		out.append(Rect2(x, 0, CAP, size.y))
		return out

	func _draw() -> void:
		draw_style_box(CleanU.box(pal["fill"], pal["border"], 6, 8), Rect2(Vector2.ZERO, size))
		var rr := seg_rects()
		for j in range(2, rr.size() - 1, 2):
			var sx: float = rr[j].get_center().x
			draw_line(Vector2(sx, size.y * 0.3), Vector2(sx, size.y * 0.7), Color(1, 1, 1, 0.08), 1.0)


class CleanIcon extends Control:
	var kind := "all"
	var gold := Color(1.0, 0.83, 0.5)
	var active := false:
		set(v):
			active = v
			queue_redraw()
	var hover := false:
		set(v):
			hover = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 - 2.0)
		var col := gold if active else (Color(0.86, 0.85, 0.82) if hover else Color(0.5, 0.5, 0.5))
		if active:
			for i in 5:
				draw_circle(c, 22.0 - i * 3.5, Color(gold, 0.05))
			draw_line(Vector2(size.x * 0.25, size.y - 2), Vector2(size.x * 0.75, size.y - 2), Color(gold, 0.8), 1.5)
		var w := 2.0
		match kind:
			"all":
				for p in [Vector2(-8, -8), Vector2(2, -8), Vector2(-8, 2), Vector2(2, 2)]:
					draw_rect(Rect2(c + p, Vector2(7, 7)), col, false, w)
			"potion":
				draw_arc(c + Vector2(0, 4), 9.0, 0, TAU, 24, col, w, true)
				draw_rect(Rect2(c + Vector2(-3, -12), Vector2(6, 8)), col, false, w)
				draw_line(c + Vector2(-5, -13), c + Vector2(5, -13), col, w)
				draw_line(c + Vector2(-6, 6), c + Vector2(6, 6), Color(col, 0.6), 1.5)
			"rune":
				draw_line(c + Vector2(0, -13), c + Vector2(0, 13), col, w)
				draw_line(c + Vector2(0, -1), c + Vector2(-9, -12), col, w)
				draw_line(c + Vector2(0, -1), c + Vector2(9, -12), col, w)
			"amulet":
				draw_arc(c + Vector2(0, 5), 8.0, 0, TAU, 24, col, w, true)
				draw_polyline(PackedVector2Array([c + Vector2(-7, 1), c + Vector2(0, -13), c + Vector2(7, 1)]), col, w, true)
				CleanU.diamond(self, c + Vector2(0, 5), 3.0, col, col, 1.0)
			"key":
				draw_arc(c + Vector2(-8, 0), 6.0, 0, TAU, 20, col, w, true)
				draw_line(c + Vector2(-2, 0), c + Vector2(13, 0), col, w)
				draw_line(c + Vector2(8, 0), c + Vector2(8, 6), col, w)
				draw_line(c + Vector2(12, 0), c + Vector2(12, 5), col, w)


## Значок навигации из листа UI/icons_inventory/icons_inventory.png (белые
## силуэты на прозрачном, 12×4). Без наведения — тёмный и полупрозрачный;
## выбранный — ровное золото (gold) без прозрачности; при наведении — яркое
## золото (gold_hi) с ореолом. Переход плавный (glow 0 → ACTIVE → 1)
class SheetIcon extends Control:
	const SHEET := "res://UI/icons_inventory/icons_inventory.png"
	## Рамки силуэтов в листе — по непрозрачным пикселям
	const RECTS := {
		"bag": Rect2i(78, 68, 98, 126),
		"swords": Rect2i(235, 73, 111, 114),
		"ring": Rect2i(736, 71, 85, 113),
		"potion": Rect2i(901, 71, 78, 118),
		"scroll": Rect2i(1048, 85, 103, 100),
		"key": Rect2i(1212, 72, 114, 118),
		"book": Rect2i(1386, 263, 85, 107),
		"star": Rect2i(1561, 259, 109, 109),
		"gear": Rect2i(1057, 434, 105, 103),
		"chest": Rect2i(233, 608, 109, 89),
	}
	## Свечение выбранного — слабее, чем при наведении
	const ACTIVE := 0.6
	## Полный переход 0 → 1 за ~0.18 с (по реальному времени: игра на паузе,
	## а Juice может замедлять Engine.time_scale)
	const SPEED := 5.5
	static var _cache := {}

	var icon := "bag"
	## Сторона квадрата, в который вписан силуэт
	var icon_px := 30
	var gold := Color(0.86, 0.68, 0.38)
	var gold_hi := Color(1.0, 0.83, 0.5)
	## Без наведения: тёмно-серый, прозрачность 40 %
	var dim := Color(0.5, 0.49, 0.47, 0.4)
	## Черта под значком у выбранного (у вкладок черту рисует Indicator)
	var underline := false
	## Кнопка, чей текст красится вместе со значком (вкладки)
	var label_button: Button
	var text_dim := Color(0.56, 0.55, 0.53)
	var active := false:
		set(v):
			active = v
			_retarget()
	var hover := false:
		set(v):
			hover = v
			_retarget()
	var glow := 0.0
	var _target := 0.0
	var _last_ms := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func _ready() -> void:
		_apply_label()

	func _notification(what: int) -> void:
		# Окно закрыли под курсором — mouse_exited не придёт, гасим сами
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and hover:
			hover = false
			glow = _target
			_apply_label()
			queue_redraw()

	func _retarget() -> void:
		_target = 1.0 if hover else (ACTIVE if active else 0.0)
		if is_equal_approx(glow, _target):
			return
		_last_ms = Time.get_ticks_msec()
		set_process(true)

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_msec()
		var dt := minf((now - _last_ms) / 1000.0, 0.1)
		_last_ms = now
		glow = move_toward(glow, _target, SPEED * dt)
		if is_equal_approx(glow, _target):
			glow = _target
			set_process(false)
		_apply_label()
		queue_redraw()

	## Цвет при свечении g: тёмный → золото (к ACTIVE) → яркое золото
	func color_at(g: float, from: Color) -> Color:
		if g <= ACTIVE:
			return from.lerp(gold, g / ACTIVE)
		return gold.lerp(gold_hi, (g - ACTIVE) / (1.0 - ACTIVE))

	func _apply_label() -> void:
		if label_button == null:
			return
		var c := color_at(glow, text_dim)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			label_button.add_theme_color_override(k, c)

	func _draw() -> void:
		var tex := texture_for(icon, icon_px)
		if tex == null:
			return
		var c := size * 0.5
		var r := Rect2(c - Vector2(icon_px, icon_px) * 0.5, Vector2(icon_px, icon_px))
		var col := color_at(glow, dim)
		var halo := glow * glow
		if halo > 0.01:
			# Мягкий ореол и золотая кайма вокруг силуэта
			for i in 5:
				draw_circle(c, icon_px * 0.75 - i * icon_px * 0.11, Color(gold_hi, 0.045 * halo))
			for d in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
				draw_texture_rect(tex, Rect2(r.position + d, r.size), false, Color(gold_hi, 0.22 * halo))
		draw_texture_rect(tex, r, false, col)
		if underline and active:
			draw_line(Vector2(size.x * 0.25, size.y - 2), Vector2(size.x * 0.75, size.y - 2),
					Color(gold, 0.8 * minf(glow / ACTIVE, 1.0)), 1.5)

	## Силуэт, вписанный в квадрат px (хранится вдвое крупнее — чётко и при
	## растянутом окне). Почти прозрачная «грязь» листа срезается
	static func texture_for(id: String, px: int) -> Texture2D:
		var key := "%s:%d" % [id, px]
		if _cache.has(key):
			return _cache[key]
		var sheet: Texture2D = load(SHEET)
		if sheet == null or not RECTS.has(id):
			return null
		var src := sheet.get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var reg: Rect2i = RECTS[id]
		var part := src.get_region(reg.grow(3))
		for y in part.get_height():
			for x in part.get_width():
				var p := part.get_pixel(x, y)
				if p.a < 0.15:
					part.set_pixel(x, y, Color(1, 1, 1, 0))
				else:
					part.set_pixel(x, y, Color(1, 1, 1, p.a))
		var side := maxi(part.get_width(), part.get_height())
		var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
		sq.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()),
				Vector2i((side - part.get_width()) / 2, (side - part.get_height()) / 2))
		sq.resize(px * 2, px * 2, Image.INTERPOLATE_LANCZOS)
		var tex := ImageTexture.create_from_image(sq)
		_cache[key] = tex
		return tex
