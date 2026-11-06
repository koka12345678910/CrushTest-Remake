extends RefCounted
## hero_side_panels.gd — живые панели правой колонки инвентаря героя
## (hero_inventory_skin.gd::_build_quick) и мелкие украшения ячеек:
##   SagaPanel  — «Сага героя»: строки статов (Inventory/ui/hero_stats.gd);
##   QuiverView — колчан Сигрид: какие стрелы заряжены, что действует, сколько;
##   AltarView  — алтарь Одра Хальварда на вкладке «Магия»: шкала с отметками
##                цен молитв и чем боги платят Одр;
##   FlaskLevel — число зарядов в углу быстрого слота;
##   NewBadge   — пульсирующий ромб «НОВОЕ» на только что полученном предмете.
## Цвета темы приходят полями (gold, text...) — скрипт не тянет скин обратно.

const HeroStats := preload("res://Inventory/ui/hero_stats.gd")


class U:
	static func font_of(c: Control) -> Font:
		var f := c.get_theme_default_font()
		return f if f != null else ThemeDB.fallback_font

	## Строка, урезанная до ширины max_w (с многоточием)
	static func fit(f: Font, s: String, max_w: float, fs: int) -> String:
		if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			return s
		var t := s
		while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			t = t.left(t.length() - 1)
		return t.strip_edges() + "…"

	## Ромб с обводкой — общий знак всех панелей
	static func diamond(c: CanvasItem, at: Vector2, r: float, fill: Color, line: Color, width := 1.2) -> void:
		var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
		c.draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		c.draw_polyline(pts, line, width, true)


# ═════════════════════ Сага героя ═════════════════════

class SagaPanel extends Control:
	var gold := Color(0.86, 0.68, 0.38)
	var text := Color(0.86, 0.8, 0.7)
	var text_dim := Color(0.58, 0.52, 0.44)
	var line := Color(0.72, 0.56, 0.34, 0.5)
	var bonus_color := Color(0.56, 0.86, 0.52)
	var row_h := 26.0
	var font_size := 16
	var title := "САГА ГЕРОЯ"
	var _rows: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func refresh(player: Node) -> void:
		_rows = HeroStats.rows(player)
		queue_redraw()

	## Высота под n строк (без заголовка — он над первой строкой)
	func needed_height() -> float:
		return 34.0 + row_h * maxf(_rows.size(), 1)

	func _draw() -> void:
		var f := U.font_of(self)
		var w := size.x
		# Заголовок: ромбы по краям и черта, гаснущая к концам
		var ty := 18.0
		var title_s := tr(title)
		var tw := f.get_string_size(title_s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 1).x
		draw_string(f, Vector2((w - tw) * 0.5, ty), title_s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 1, gold)
		for s: float in [-1.0, 1.0]:
			var x0 := w * 0.5 + s * (tw * 0.5 + 12.0)
			var x1 := w * 0.5 + s * (w * 0.5 - 6.0)
			draw_line(Vector2(x0, ty - 5), Vector2(x1, ty - 5), Color(line, line.a * 0.8), 1.0)
			U.diamond(self, Vector2(x0 + s * 4.0, ty - 5), 3.5, Color(0, 0, 0, 0.6), gold, 1.0)
		var y := 34.0
		for r in _rows:
			var base_y := y + row_h * 0.7
			draw_string(f, Vector2(4, base_y), tr(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_dim)
			var val: String = tr(r[1])
			var vx := w - 4.0 - f.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 1).x
			draw_string(f, Vector2(vx, base_y), val, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 1, text)
			if r[2] != "":
				var b: String = tr(r[2])
				var bs := font_size - 3
				var bx := vx - 8.0 - f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
				draw_string(f, Vector2(bx, base_y - 1), b, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, bonus_color)
			# Пунктир между подписью и значением — строка читается как запись в книге
			y += row_h
			var dot := Color(line, line.a * 0.35)
			var x := 8.0
			while x < w - 8.0:
				draw_line(Vector2(x, y - 2), Vector2(x + 2, y - 2), dot, 1.0)
				x += 7.0


# ═════════════════════ Колчан Сигрид ═════════════════════

## Слева — колчан со стрелами: обычные — тусклые, заряженные навыками —
## с цветным оперением и свечением (сколько зарядов — столько стрел).
## Справа — список: заряды стрел и действующие навыки с полоской времени
## (игра на паузе, время стоит — видно, сколько осталось)
class QuiverView extends Control:
	var gold := Color(0.86, 0.68, 0.38)
	var text := Color(0.86, 0.8, 0.7)
	var text_dim := Color(0.58, 0.52, 0.44)
	var line := Color(0.72, 0.56, 0.34, 0.5)
	var font_size := 15
	## [цвет оперения, свечение]
	var _arrows: Array = []
	## [подпись, цвет, доля оставшегося времени или -1, приписка справа]
	var _entries: Array = []
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if not _arrows.is_empty():
			queue_redraw()

	func refresh(a: Node) -> void:
		_arrows.clear()
		_entries.clear()
		if a == null or a.get("character_id") != "archer":
			queue_redraw()
			return
		if a.get("_valkyrie_shot_ready"):
			_arrows.append(a.COLOR_VALKYRIE)
			_entries.append(["Выстрел Валькирии", a.COLOR_VALKYRIE, -1.0, "заряжен"])
		if a.get("_dance_charged"):
			_arrows.append(a.COLOR_DANCE)
			_entries.append(["Танец: следующий — крит", a.COLOR_DANCE, -1.0, ""])
		var pierce: int = a.get("_pierce_shots")
		for i in pierce:
			_arrows.append(a.COLOR_FENRIR)
		if pierce > 0:
			_entries.append(["Коготь Фенрира", a.COLOR_FENRIR, -1.0, "×%d" % pierce])
		var whisper: int = a.get("_whisper_shots")
		for i in whisper:
			_arrows.append(a.COLOR_WHISPER)
		if whisper > 0:
			_entries.append(["Шёпот Одина", a.COLOR_WHISPER, -1.0, "×%d" % whisper])
		var durations: Dictionary = a.get("_durations")
		for e in [["Последний взор", "last_look", "_last_look_time", a.COLOR_LAST_LOOK],
				["Путь охотницы", "huntress_path", "_hunt_time", a.COLOR_HUNT],
				["Танец Валькирии", "valkyrie_dance", "_dance_time", a.COLOR_DANCE],
				["Кровавое Перо", "bloody_feather", "_bleed_time", a.COLOR_BLEED]]:
			var left: float = a.get(e[2])
			if left > 0.0:
				var full: float = durations.get(e[1], left)
				var note := tr("%.1f с") % left
				if e[1] == "huntress_path" and int(a.get("_hunt_stacks")) > 0:
					note = "+%d · %s" % [mini(int(a.get("_hunt_stacks")), int(a.HUNT_MAX_BONUS)), note]
				_entries.append([e[0], e[3], left / maxf(full, 0.01), note])
		for tal in [[a.TALISMAN_HUGINN, a.COLOR_HUGINN], [a.TALISMAN_NORN, Color(0.85, 0.8, 0.65)]]:
			if a._has_talisman(tal[0]):
				_entries.append([tal[0], tal[1], -1.0, "оберег"])
		queue_redraw()

	func _draw() -> void:
		var f := U.font_of(self)
		var h := size.y
		var w := size.x
		# Колчан: наклонная кожаная туба, ремешки, стрелы торчат сверху
		var qw := 38.0
		var qx := 8.0
		var top := 54.0
		var bottom := h - 10.0
		var body := PackedVector2Array([Vector2(qx, top), Vector2(qx + qw, top), Vector2(qx + qw - 6, bottom), Vector2(qx + 6, bottom)])
		# Стрелы — до тубы, туба их прикрывает снизу
		var n := maxi(_arrows.size(), 0)
		var plain := 4
		var total := plain + n
		for i in total:
			var k := (i + 0.5) / total
			var ax := qx + 8.0 + k * (qw - 16.0)
			var tip := Vector2(ax + (k - 0.5) * 22.0, 8.0 + absf(k - 0.5) * 18.0)
			var special := i >= plain
			var col: Color = _arrows[i - plain] if special else Color(text_dim, 0.7)
			draw_line(Vector2(ax, top + 20), tip, Color(0.55, 0.42, 0.28) if not special else col.darkened(0.25), 2.0)
			# Оперение: два пера у верхушки
			var d := (tip - Vector2(ax, top + 20)).normalized()
			var nrm := Vector2(-d.y, d.x)
			var fb := tip - d * 4.0
			var fe := tip - d * 18.0
			for s in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([fb, fe, fe + nrm * 6.0 * s - d * 2.0]), col)
			if special:
				var pulse := 0.5 + 0.5 * sin(_t * 4.0 + i)
				draw_circle(tip - d * 10.0, 9.0 + 2.0 * pulse, Color(col, 0.12 + 0.08 * pulse))
		draw_colored_polygon(body, Color(0.2, 0.13, 0.08, 0.95))
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, Color(gold, 0.55), 1.2, true)
		for yy in [top + 16.0, bottom - 22.0]:
			draw_line(Vector2(qx + 2, yy), Vector2(qx + qw - 2, yy), Color(gold, 0.7), 2.0)
		# Стёжка вдоль тубы
		var sy := top + 26.0
		while sy < bottom - 28.0:
			draw_line(Vector2(qx + qw * 0.5, sy), Vector2(qx + qw * 0.5, sy + 4), Color(gold, 0.35), 1.0)
			sy += 9.0

		# Список справа
		var lx := qx + qw + 16.0
		var lw := w - lx - 4.0
		var y := 14.0
		if _entries.is_empty():
			var msg := ["Колчан пуст.", "Навыки из быстрого слота", "заряжают стрелы — они", "появятся здесь."]
			for m in msg:
				draw_string(f, Vector2(lx, y + 12), tr(m), HORIZONTAL_ALIGNMENT_LEFT, lw, font_size - 1, text_dim)
				y += 20.0
			return
		for e in _entries:
			if y > h - 18.0:
				break
			var col: Color = e[1]
			U.diamond(self, Vector2(lx + 4, y + 7), 4.0, Color(col, 0.35), col, 1.0)
			var note: String = tr(e[3]) if e[3] != "" else ""
			var nw := 0.0
			if note != "":
				nw = f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1).x
				draw_string(f, Vector2(lx + lw - nw, y + 12), note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, col.lightened(0.15))
			# Название не заходит на приписку — обрезается многоточием
			draw_string(f, Vector2(lx + 14, y + 12), U.fit(f, tr(e[0]), lw - 22.0 - nw, font_size), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text)
			y += 18.0
			if e[2] >= 0.0:
				draw_rect(Rect2(lx + 14, y, lw - 14, 3), Color(0, 0, 0, 0.5))
				draw_rect(Rect2(lx + 14, y, (lw - 14) * clampf(e[2], 0.0, 1.0), 3), Color(col, 0.85))
				y += 8.0
			y += 6.0


# ═════════════════════ Алтарь Одра ═════════════════════

## Камень алтаря с символом стихии текущего слота магии, свечение — по
## наполненности Одра; под ним шкала с засечками цен молитв из слотов и
## строки «чем боги платят»
class AltarView extends Control:
	var gold := Color(0.8, 0.74, 0.6)
	var text := Color(0.84, 0.84, 0.82)
	var text_dim := Color(0.56, 0.58, 0.6)
	var line := Color(0.62, 0.66, 0.72, 0.45)
	var odr_color := Color(0.58, 0.68, 0.98)
	var font_size := 15
	var _odr := 0.0
	var _max := 100.0
	## [имя, цена, цвет]
	var _spells: Array = []
	var _gains: Array = []
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if visible:
			queue_redraw()

	func refresh(knight: Node) -> void:
		_spells.clear()
		_gains.clear()
		var magic = knight.get("magic") if knight else null
		if magic == null:
			return
		_odr = magic.odr
		_max = magic.max_odr
		for s in magic.magic_slots.abilities:
			_spells.append([s.ability_name.replace("Благословение ", ""), magic.spell_cost(s), s.color])
		_gains = [
			["Казнь", magic.odr_on_execution + knight.trophy_bonus("odr_exec")],
			["Идеальное парирование", magic.odr_on_parry + knight.trophy_bonus("odr_parry")],
			["Убийство", magic.odr_on_kill],
		]
		queue_redraw()

	func _draw() -> void:
		var f := U.font_of(self)
		var w := size.x
		var k := clampf(_odr / maxf(_max, 1.0), 0.0, 1.0)
		var c := Vector2(w * 0.5, 62.0)
		# Свечение над камнем
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		for i in 6:
			draw_circle(c + Vector2(0, -6), 54.0 - i * 8.0, Color(odr_color, (0.025 + 0.02 * pulse) * k * (i + 1) * 0.5))
		# Камень: трапеция с плитой сверху
		var stone := PackedVector2Array([c + Vector2(-46, 10), c + Vector2(46, 10), c + Vector2(38, 52), c + Vector2(-38, 52)])
		draw_colored_polygon(stone, Color(0.12, 0.13, 0.15, 0.95))
		draw_rect(Rect2(c + Vector2(-56, 0), Vector2(112, 12)), Color(0.17, 0.18, 0.2, 0.95))
		var so := stone.duplicate()
		so.append(stone[0])
		draw_polyline(so, Color(gold, 0.5), 1.2, true)
		draw_rect(Rect2(c + Vector2(-56, 0), Vector2(112, 12)), Color(gold, 0.6), false, 1.0)
		# Символ: молния / пламя первого заклинания в слоте
		var sym_col: Color = _spells[0][2] if not _spells.is_empty() else odr_color
		var g := Color(sym_col, 0.35 + 0.65 * k)
		var sc := c + Vector2(0, -26)
		if not _spells.is_empty() and _spells[0][0].contains("Сурт"):
			for s in [-1.0, 0.0, 1.0]:
				var hh := 30.0 - absf(s) * 10.0
				var base := sc + Vector2(s * 11.0, 18)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-7, 0), base + Vector2(0, -hh - 4.0 * sin(_t * 6.0 + s)), base + Vector2(7, 0)]), g)
		else:
			draw_polyline(PackedVector2Array([sc + Vector2(6, -20), sc + Vector2(-6, 0), sc + Vector2(4, 0), sc + Vector2(-6, 22)]), g, 3.0, true)
		# Руны по камню
		for i in 3:
			var rx := c.x - 20.0 + i * 20.0
			draw_line(Vector2(rx, c.y + 20), Vector2(rx, c.y + 42), Color(odr_color, 0.18 + 0.5 * k), 1.5)
			draw_line(Vector2(rx, c.y + 26), Vector2(rx + 6, c.y + 21), Color(odr_color, 0.18 + 0.5 * k), 1.5)

		# Шкала Одра
		var by := 132.0
		var bx := 10.0
		var bw := w - 20.0
		draw_rect(Rect2(bx - 1, by - 1, bw + 2, 14), Color(gold, 0.5), false, 1.0)
		draw_rect(Rect2(bx, by, bw, 12), Color(0.02, 0.025, 0.04, 0.9))
		draw_rect(Rect2(bx, by, bw * k, 12), Color(odr_color, 0.85))
		draw_rect(Rect2(bx, by, bw * k, 4), Color(1, 1, 1, 0.18))
		var lbl := tr("Одр  %d / %d") % [int(roundf(_odr)), int(roundf(_max))]
		draw_string(f, Vector2(bx, by - 8), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text)
		# Засечки цен молитв: где кончается Одр на одну, две... молитвы
		for s in _spells:
			var cost: float = s[1]
			if cost <= 0.0:
				continue
			var m := cost
			while m <= _max + 0.01:
				var x := bx + bw * (m / _max)
				draw_line(Vector2(x, by - 3), Vector2(x, by + 15), Color(s[2], 0.9), 2.0)
				m += cost
		var y := by + 36.0
		for s in _spells:
			var n := int(floorf(_odr / maxf(s[1], 1.0)))
			U.diamond(self, Vector2(bx + 5, y - 5), 4.0, Color(s[2], 0.4), s[2], 1.0)
			draw_string(f, Vector2(bx + 16, y), tr("%s — %d Одра") % [tr(s[0]), int(s[1])], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text)
			var note := tr("хватит ×%d") % n if n > 0 else tr("мало Одра")
			var nw := f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1).x
			draw_string(f, Vector2(bx + bw - nw, y), note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, s[2] if n > 0 else Color(0.85, 0.4, 0.3))
			y += 24.0
		y += 10.0
		draw_string(f, Vector2(bx, y), tr("Боги платят Одром за:"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, gold)
		y += 24.0
		for gl in _gains:
			draw_string(f, Vector2(bx + 8, y), tr(gl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, text_dim)
			var v := "+%d" % int(gl[1])
			var vw := f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(f, Vector2(bx + bw - vw, y), v, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, odr_color.lightened(0.2))
			y += 22.0


# ═════════════════════ Пояс и фляги ═════════════════════

## Фляга поверх быстрого слота: стеклянный силуэт, уровень жидкости — по
## зарядам (count/max_count), цвет — цвет предмета из каталога магазина
class FlaskLevel extends Control:
	var level := 0.0:
		set(v):
			level = v
			queue_redraw()
	var liquid := Color(0.6, 0.3, 0.2)
	var glass := Color(0.8, 0.8, 0.85, 0.35)
	## Рисовать горлышко с пробкой (фляга Хальварда); false — только число
	var bottle := true
	var text := ""
	var text_color := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Жидкость — снизу ячейки до уровня, мягкий мениск
		if level > 0.0:
			var top := h - 6.0 - (h - 16.0) * clampf(level, 0.0, 1.0)
			draw_rect(Rect2(6, top, w - 12, h - 6.0 - top), Color(liquid, 0.24))
			draw_line(Vector2(8, top), Vector2(w - 8, top), Color(liquid.lightened(0.3), 0.7), 1.5)
			# Блик на стекле
			draw_line(Vector2(12, top + 4), Vector2(12, h - 12), Color(1, 1, 1, 0.08), 3.0)
		# Горлышко и пробка сверху по центру — только у фляги
		if bottle:
			draw_rect(Rect2(w * 0.5 - 8, -6, 16, 8), Color(0.32, 0.21, 0.12, 0.95))
			draw_rect(Rect2(w * 0.5 - 8, -6, 16, 8), Color(glass, 0.6), false, 1.0)
		if text != "":
			var f := U.font_of(self)
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, Vector2(w - tw - 8, h - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)


# ═════════════════════ «НОВОЕ» ═════════════════════

## Ромб в углу ячейки: дышит, пока игрок не наведёт на предмет
## (inventory_ui._on_slot_hover снимает отметку)
class NewBadge extends Control:
	var color := Color(1.0, 0.82, 0.48)
	var label := "НОВОЕ"
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var p := 0.5 + 0.5 * sin(_t * 4.5)
		var c := Vector2(10, 10)
		draw_circle(c, 9.0 + 3.0 * p, Color(color, 0.12 + 0.12 * p))
		U.diamond(self, c, 6.0, Color(color, 0.55 + 0.35 * p), color.lightened(0.3), 1.2)
		if label != "":
			var f := U.font_of(self)
			draw_string(f, Vector2(22, 15), tr(label), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.75 + 0.25 * p))
