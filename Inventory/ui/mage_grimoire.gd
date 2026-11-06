extends Control
## mage_grimoire.gd — вкладка «ГРИМУАР» мага (клавиша G): встаёт на место
## содержимого инвентаря, как экран талисманов.
##   слева  — четыре страницы заклинаний (ЛКМ/ПКМ/V/B): руна, что делает,
##            цена в Сейде (с рангом и Гандром вёльвы), сила, три ранга и
##            кнопка «Усилить» за души;
##   справа — Сосуд душ: сколько душ, уровень сосуда и его расширение
##            (+20 к шкале Сейда за уровень).
## Вся экономика — в Player_scene/mage.gd (upgrade_spell/upgrade_vessel,
## rank_price, spell_power), здесь только показ и кнопки.

const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const Side := preload("res://Inventory/ui/hero_side_panels.gd")

## Руны заклинаний — те же черты, что на рунной панели HUD (mage.gd::_ready)
const SPELLS := [
	{"key": "ЛКМ", "name": "Огненный шар", "rune": "Кеназ",
		"desc": "Сгусток голубого пламени летит в цель и опаляет всех рядом с ней.",
		"glyph": [[Vector2(0.72, 0.08), Vector2(0.28, 0.5), Vector2(0.72, 0.92)]],
		"rank3": "+1 урона шару"},
	{"key": "ПКМ", "name": "Выжигание", "rune": "Соулу",
		"desc": "Голубой огонь катится вперёд конусом, жжёт и отбрасывает.",
		"glyph": [[Vector2(0.68, 0.06), Vector2(0.3, 0.38), Vector2(0.7, 0.62), Vector2(0.32, 0.94)]],
		"rank3": "+1 урона огню"},
	{"key": "V", "name": "Двойной импульс", "rune": "Хагалаз",
		"desc": "Две волны силы расходятся от мага — малая и большая — и раскидывают врагов.",
		"glyph": [[Vector2(0.25, 0.06), Vector2(0.25, 0.94)], [Vector2(0.75, 0.06), Vector2(0.75, 0.94)],
				[Vector2(0.25, 0.36), Vector2(0.75, 0.64)]],
		"rank3": "+1 урона волнам"},
	{"key": "B", "name": "Столпы Сейда", "rune": "Альгиз",
		"desc": "Под ближайшими врагами проступают руны — и из земли вырываются столпы огня.",
		"glyph": [[Vector2(0.5, 0.94), Vector2(0.5, 0.06)], [Vector2(0.5, 0.46), Vector2(0.16, 0.1)],
				[Vector2(0.5, 0.46), Vector2(0.84, 0.1)]],
		"rank3": "+2 цели столпам"},
]

var _ui
var _mage: Node
var _pages: Array = []
var _buttons: Array[Button] = []
var _vessel: VesselView
var _souls_label: Label
var _seid_label: Label
var _vessel_btn: Button
var _status: Label


func init(ui) -> void:
	_ui = ui
	_mage = ui._player
	_build()


func _make_label(text: String, font_size: int) -> Label:
	return _ui._make_label(text, font_size)


func refresh() -> void:
	if _mage == null:
		return
	var souls: int = _mage.souls
	for i in _pages.size():
		var pg: SpellPage = _pages[i]
		pg.rank = _mage.spell_ranks[i]
		pg.cost_base = _mage.base_spell_cost(i)
		pg.cost_now = _mage.spell_cost(i)
		pg.power = _mage.spell_power(i)
		pg.queue_redraw()
		var price: int = _mage.rank_price(i)
		var b := _buttons[i]
		if price <= 0:
			b.text = "ВЫСШИЙ РАНГ"
			b.disabled = true
		else:
			b.text = tr("УСИЛИТЬ  ·  %d душ") % price
			b.disabled = souls < price
	_vessel.level = _mage.vessel_level
	_vessel.max_level = _mage.VESSEL_PRICES.size()
	_vessel.queue_redraw()
	_souls_label.text = tr("%d душ") % souls
	_seid_label.text = tr("Шкала Сейда: %d\n+%d за каждый уровень сосуда") % [int(_mage.max_seid), int(_mage.VESSEL_SEID)]
	var vp: int = _mage.vessel_price()
	if vp <= 0:
		_vessel_btn.text = "СОСУД ПОЛОН"
		_vessel_btn.disabled = true
	else:
		_vessel_btn.text = tr("РАСШИРИТЬ  ·  %d душ") % vp
		_vessel_btn.disabled = souls < vp


func _build() -> void:
	var lay: Dictionary = HeroSkin.T["layout"]
	var wide := Rect2(HeroSkin.grid_x(), HeroSkin.TOP, lay["grid_w"] + 14 + lay["detail_w"], HeroSkin.FRAME_H)
	var f := HeroSkin.build_frame(self, wide, null, false)
	var ty: float = f.position.y + lay["title_dy"]
	var hdr := _make_label("ГРИМУАР", 26)
	hdr.add_theme_color_override("font_color", HeroSkin.GOLD)
	hdr.position = Vector2(f.position.x, ty)
	hdr.size = Vector2(f.size.x, 34)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hdr)
	HeroSkin.divider(self, f.position.x + 60, f.size.x - 120, ty + 38)
	var sub := _make_label("Души, собранные с павших, вплетаются в руны: ранг II — дешевле, ранг III — сильнее", 16)
	sub.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	sub.position = Vector2(f.position.x, ty + 62)
	sub.size = Vector2(f.size.x, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var area := Rect2(f.position.x + 30, ty + 104, f.size.x - 60, f.end.y - 30 - (ty + 104))
	var gap := 20.0
	var cw := floorf((area.size.x - gap * 3.0) / 4.0)
	_pages.clear()
	_buttons.clear()
	for i in SPELLS.size():
		var r := Rect2(area.position + Vector2(i * (cw + gap), 0), Vector2(cw, area.size.y))
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = r.position.round()
		holder.size = r.size
		add_child(holder)
		HeroSkin.cell_plate(holder, r.size)
		var pg := SpellPage.new()
		pg.spell = SPELLS[i]
		pg.size = r.size
		pg.gold = HeroSkin.GOLD
		pg.gold_hi = HeroSkin.GOLD_HI
		pg.text = HeroSkin.TEXT
		pg.text_dim = HeroSkin.TEXT_DIM
		holder.add_child(pg)
		_pages.append(pg)
		var b := _button(Rect2(r.position.x + 20, r.end.y - 70, r.size.x - 40, 48))
		var rune := i
		b.pressed.connect(func(): _upgrade_spell(rune))
		_buttons.append(b)

	# Сосуд душ — правая колонка
	var rf := HeroSkin.build_frame(self, HeroSkin.right_rect(), null)
	HeroSkin.plaque(self, self, "СОСУД ДУШ", rf.position.x, rf.size.x, rf.position.y + lay["title_dy"])
	var y: float = rf.position.y + HeroSkin.column_top()
	_vessel = VesselView.new()
	_vessel.size = Vector2(rf.size.x - 40, 300)
	_vessel.position = Vector2(rf.position.x + 20, y)
	_vessel.pal = HeroSkin.T.get("pal", {})
	add_child(_vessel)
	y += 310.0
	_souls_label = _make_label("", 26)
	_souls_label.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
	_souls_label.position = Vector2(rf.position.x, y)
	_souls_label.size = Vector2(rf.size.x, 34)
	_souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_souls_label)
	HeroSkin.divider(self, rf.position.x + 20, rf.size.x - 40, y + 44)
	_seid_label = _make_label("", 16)
	_seid_label.add_theme_color_override("font_color", HeroSkin.TEXT)
	_seid_label.position = Vector2(rf.position.x + 10, y + 72)
	_seid_label.size = Vector2(rf.size.x - 20, 48)
	_seid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_seid_label)
	_vessel_btn = _button(Rect2(rf.position.x + 24, y + 138, rf.size.x - 48, 48))
	_vessel_btn.pressed.connect(_upgrade_vessel)
	_status = _make_label("", 16)
	_status.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	_status.position = Vector2(f.position.x, HeroSkin.TOP + HeroSkin.FRAME_H + 8)
	_status.size = Vector2(f.size.x, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	refresh()


func _button(r: Rect2) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", HeroSkin.TEXT)
	b.add_theme_color_override("font_hover_color", HeroSkin.GOLD_HI)
	b.add_theme_color_override("font_pressed_color", HeroSkin.GOLD_HI)
	b.add_theme_color_override("font_disabled_color", Color(HeroSkin.TEXT_DIM, 0.7))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(HeroSkin.GOLD_HI, 0.09) if st == "hover" or st == "pressed" else Color(0, 0, 0, 0.5)
		sb.border_color = Color(HeroSkin.GOLD, 0.25 if st == "disabled" else (0.9 if st == "hover" else 0.55))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(b)
	return b


func _upgrade_spell(rune: int) -> void:
	var name_s: String = SPELLS[rune]["name"]
	if _mage.upgrade_spell(rune):
		_ui._play_ui_sound(_ui.SOUND_ACCEPT)
		_status.text = tr("%s — ранг %s") % [tr(name_s), ["", "I", "II", "III"][_mage.spell_ranks[rune]]]
		_status.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
		(_pages[rune] as SpellPage).flash()
	else:
		_ui._play_ui_sound(_ui.SOUND_DENIED)
		_status.text = "Не хватает душ"
		_status.add_theme_color_override("font_color", Color(0.85, 0.4, 0.3))
	refresh()


func _upgrade_vessel() -> void:
	if _mage.upgrade_vessel():
		_ui._play_ui_sound(_ui.SOUND_ACCEPT)
		_status.text = tr("Сосуд душ расширен — Сейд %d") % int(_mage.max_seid)
		_status.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
	else:
		_ui._play_ui_sound(_ui.SOUND_DENIED)
		_status.text = "Не хватает душ"
		_status.add_theme_color_override("font_color", Color(0.85, 0.4, 0.3))
	refresh()


## Страница заклинания: рунный камень с чертой руны, клавиша, название,
## описание, цена (старая зачёркнута, если стала ниже), сила, три ранга
class SpellPage extends Control:
	var spell: Dictionary
	var rank := 1
	var cost_base := 0.0
	var cost_now := 0.0
	var power: Array = [0, 0]
	var gold := Color(0.7, 0.82, 1.0)
	var gold_hi := Color(0.86, 0.94, 1.0)
	var text := Color(0.85, 0.88, 0.95)
	var text_dim := Color(0.52, 0.58, 0.72)
	var _flash := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(_flash - delta * 1.5, 0.0)
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var f := Side.U.font_of(self)
		var w := size.x
		var c := Vector2(w * 0.5, 120.0)
		var r := 74.0
		var glow := 0.25 + 0.25 * (rank - 1) + 0.6 * _flash
		# Ореол по рангу, пульс
		var p := 0.5 + 0.5 * sin(_t * 2.0)
		for k in 7:
			draw_circle(c, r * (1.45 - k * 0.1), Color(gold_hi, 0.012 * glow * (1.0 + p)))
		# Рунный камень: восьмиугольник
		var oct := PackedVector2Array()
		for i in 8:
			oct.append(c + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * r)
		draw_colored_polygon(oct, Color(0.06, 0.07, 0.11, 0.95))
		var o := oct.duplicate()
		o.append(oct[0])
		draw_polyline(o, Color(gold, 0.75), 2.0, true)
		var inner := PackedVector2Array()
		for i in 9:
			inner.append(c + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * r * 0.86)
		draw_polyline(inner, Color(gold, 0.25), 1.0, true)
		# Руна
		var box := Rect2(c - Vector2(r, r) * 0.55, Vector2(r, r) * 1.1)
		for stroke in spell["glyph"]:
			var pts := PackedVector2Array()
			for v in stroke:
				pts.append(box.position + (v as Vector2) * box.size)
			draw_polyline(pts, Color(gold_hi, 0.35 + 0.65 * minf(glow, 1.0)), 5.0, true)
			draw_polyline(pts, Color(1, 1, 1, 0.25 * minf(glow, 1.0)), 2.0, true)
		# Клавиша
		var key: String = tr(spell["key"])
		var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0
		draw_rect(Rect2(14, 14, kw, 26), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(14, 14, kw, 26), Color(gold, 0.7), false, 1.0)
		draw_string(f, Vector2(23, 33), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text)

		var y := 232.0
		_center(f, spell["name"], y, 23, gold_hi)
		y += 24.0
		_center(f, tr("руна %s") % tr(spell["rune"]), y, 14, text_dim)
		y += 30.0
		# Описание — по словам в ширину страницы
		for line in _wrap(f, tr(spell["desc"]), w - 40.0, 15):
			_center(f, line, y, 15, text)
			y += 20.0
		y = maxf(y + 10.0, 352.0)
		draw_line(Vector2(30, y), Vector2(w - 30, y), Color(gold, 0.3), 1.0)
		y += 30.0
		# Цена
		draw_string(f, Vector2(24, y), tr("Цена"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_dim)
		var now_s := tr("%d Сейда") % int(cost_now)
		var nw := f.get_string_size(now_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(f, Vector2(w - 24 - nw, y), now_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, text)
		if cost_now < cost_base - 0.5:
			var old_s := "%d" % int(cost_base)
			var ow := f.get_string_size(old_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var ox := w - 24 - nw - 12 - ow
			draw_string(f, Vector2(ox, y), old_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, text_dim)
			draw_line(Vector2(ox - 2, y - 5), Vector2(ox + ow + 2, y - 5), text_dim, 1.0)
		y += 30.0
		var is_pillars: bool = spell["key"] == "B"
		draw_string(f, Vector2(24, y), tr("Целей") if is_pillars else tr("Урон"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_dim)
		var pw_s := tr("до %d") % int(power[1]) if is_pillars else "%d" % int(power[0])
		var pww := f.get_string_size(pw_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(f, Vector2(w - 24 - pww, y), pw_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, text)
		y += 46.0
		# Ранги I II III
		var labels := ["I", "II", "III"]
		for i in 3:
			var cx := w * 0.5 + (i - 1) * 64.0
			var on := i < rank
			Side.U.diamond(self, Vector2(cx, y), 13.0, Color(gold_hi, 0.35) if on else Color(0, 0, 0, 0.5), Color(gold_hi if on else text_dim, 0.9), 1.5)
			var lw := f.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(f, Vector2(cx - lw * 0.5, y + 32), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold_hi if on else text_dim)
		y += 66.0
		var nxt := ""
		if rank == 1:
			nxt = "Ранг II: цена −20%"
		elif rank == 2:
			nxt = tr("Ранг III: %s") % tr(spell["rank3"])
		else:
			nxt = "Руна раскрыта полностью"
		_center(f, nxt, y, 15, gold if rank < 3 else gold_hi)

	func _center(f: Font, s: String, y: float, fs: int, col: Color) -> void:
		s = tr(s)
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - sw) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _wrap(f: Font, s: String, max_w: float, fs: int) -> Array:
		var out := []
		var line := ""
		for word: String in s.split(" "):
			var t: String = word if line == "" else line + " " + word
			if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and line != "":
				out.append(line)
				line = word
			else:
				line = t
		if line != "":
			out.append(line)
		return out


## Сосуд душ: урна с тремя поясами, светится по уровню; внутри медленно
## кружат искры-души
class VesselView extends Control:
	var level := 0
	var max_level := 3
	var pal: Dictionary = {}
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var glow: Color = pal.get("glow", Color(0.55, 0.78, 1.0))
		var accent: Color = pal.get("accent", Color(0.64, 0.76, 0.97))
		var c := Vector2(size.x * 0.5, size.y * 0.55)
		var k := float(level) / maxf(max_level, 1)
		for i in 8:
			draw_circle(c, 120.0 - i * 12.0, Color(glow, 0.012 + 0.02 * k))
		# Урна: горло, плечи, тулово, ножка
		var body := PackedVector2Array([
			c + Vector2(-26, -118), c + Vector2(26, -118), c + Vector2(22, -96), c + Vector2(70, -60),
			c + Vector2(84, 0), c + Vector2(64, 70), c + Vector2(30, 96), c + Vector2(40, 118),
			c + Vector2(-40, 118), c + Vector2(-30, 96), c + Vector2(-64, 70), c + Vector2(-84, 0),
			c + Vector2(-70, -60), c + Vector2(-22, -96)])
		draw_colored_polygon(body, Color(0.05, 0.06, 0.1, 0.95))
		# Свет внутри — снизу вверх по уровню
		if level > 0:
			var top := lerpf(90.0, -80.0, k)
			for i in 12:
				var yy := lerpf(top, 92.0, float(i) / 11.0)
				var half := 80.0 - absf(yy) * 0.35
				draw_line(c + Vector2(-half, yy), c + Vector2(half, yy), Color(glow, 0.06 + 0.04 * k), 14.0)
			for i in 9:
				var a := _t * (0.6 + i * 0.07) + i
				var p := c + Vector2(cos(a) * 40.0, lerpf(top + 10.0, 80.0, fposmod(_t * 0.1 + i * 0.13, 1.0)))
				draw_circle(p, 2.5, Color(glow.lightened(0.3), 0.8))
		var o := body.duplicate()
		o.append(body[0])
		draw_polyline(o, Color(accent, 0.85), 2.0, true)
		# Пояса сосуда: горят, если уровень куплен
		for i in max_level:
			var yy := 50.0 - i * 50.0
			var on := i < level
			var half := 84.0 - absf(yy) * 0.3
			draw_line(c + Vector2(-half + 6, yy), c + Vector2(half - 6, yy), Color(glow if on else accent, 0.9 if on else 0.3), 3.0 if on else 1.5)
			Side.U.diamond(self, c + Vector2(0, yy), 7.0, Color(glow, 0.5) if on else Color(0, 0, 0, 0.7), Color(glow if on else accent, 0.9), 1.4)
