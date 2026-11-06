extends Control
## trophy_wall.gd — «Стена трофеев» Хальварда: встаёт на место содержимого
## инвентаря (как экран талисманов), вкладки остаются. Открывается кнопкой в
## правой колонке или клавишей T.
##   слева   — одна широкая панель: восемь табличек-трофеев 4x2 (эмблема,
##             название, задача, полоска прогресса, бонус);
##   справа  — «Подвиги»: сколько добыто и какие бонусы уже действуют.
## Данные и счёт — Player_scene/knight_trophies.gd, счётчики — на рыцаре
## (player.gd::trophy_counts). Здесь только показ.

const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const Trophies := preload("res://Player_scene/knight_trophies.gd")
const Side := preload("res://Inventory/ui/hero_side_panels.gd")

const BONUS_COLOR := Color(0.56, 0.86, 0.52)

var _ui
var _plates: Array = []
var _summary: Label
var _bonus_list: Label


func init(ui) -> void:
	_ui = ui
	_build()


## inventory_ui._show_content_panel зовёт при каждом открытии
func refresh() -> void:
	var counts := _counts()
	for p in _plates:
		p.counts = counts
		p.queue_redraw()
	var done := Trophies.done_count(counts)
	_summary.text = tr("Добыто  %d  из  %d") % [done, Trophies.LIST.size()]
	var lines := []
	for t in Trophies.LIST:
		if Trophies.is_done(t, counts):
			lines.append("◆  " + tr(t["bonus_text"]))
	_bonus_list.text = "\n".join(lines) if not lines.is_empty() \
			else "Пока ни одного.\nПодвиги копятся сами — в бою:\nубийства, казни, парирования\nи молитвы богам."


func _counts() -> Dictionary:
	var p = _ui._player if _ui else null
	return p.trophy_counts if p != null and p.get("trophy_counts") != null else {}


## HeroSkin.plaque/build_grid берут _make_label у того, кого им передали
func _make_label(text: String, font_size: int) -> Label:
	return _ui._make_label(text, font_size)


func _build() -> void:
	var lay: Dictionary = HeroSkin.T["layout"]
	var wide := Rect2(HeroSkin.grid_x(), HeroSkin.TOP, lay["grid_w"] + 14 + lay["detail_w"], HeroSkin.FRAME_H)
	var f := HeroSkin.build_frame(self, wide, null)
	var ty: float = f.position.y + lay["title_dy"]
	var hdr := _make_label("СТЕНА ТРОФЕЕВ", 26)
	hdr.add_theme_color_override("font_color", HeroSkin.GOLD)
	hdr.position = Vector2(f.position.x, ty)
	hdr.size = Vector2(f.size.x, 34)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hdr)
	HeroSkin.divider(self, f.position.x + 60, f.size.x - 120, ty + 38)

	var area := Rect2(f.position.x + 40, ty + 84, f.size.x - 80, f.end.y - 40 - (ty + 84))
	var gap := 22.0
	var cw := floorf((area.size.x - gap * 3.0) / 4.0)
	var ch := floorf((area.size.y - gap) / 2.0)
	_plates.clear()
	for i in Trophies.LIST.size():
		var r := Rect2(area.position + Vector2((i % 4) * (cw + gap), (i / 4) * (ch + gap)), Vector2(cw, ch))
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = r.position.round()
		holder.size = r.size
		add_child(holder)
		HeroSkin.cell_plate(holder, r.size)
		var plate := TrophyPlate.new()
		plate.trophy = Trophies.LIST[i]
		plate.size = r.size
		plate.gold = HeroSkin.GOLD
		plate.gold_hi = HeroSkin.GOLD_HI
		plate.text = HeroSkin.TEXT
		plate.text_dim = HeroSkin.TEXT_DIM
		holder.add_child(plate)
		_plates.append(plate)

	# Правая колонка: итог и действующие бонусы
	var rf := HeroSkin.build_frame(self, HeroSkin.right_rect(), null)
	HeroSkin.plaque(self, self, "ПОДВИГИ", rf.position.x, rf.size.x, rf.position.y + lay["title_dy"])
	var y: float = rf.position.y + HeroSkin.column_top()
	_summary = _make_label("", 22)
	_summary.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
	_summary.position = Vector2(rf.position.x, y)
	_summary.size = Vector2(rf.size.x, 30)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_summary)
	HeroSkin.divider(self, rf.position.x + 20, rf.size.x - 40, y + 44)
	var cap := _make_label("Действуют навсегда:", 17)
	cap.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	cap.position = Vector2(rf.position.x + 22, y + 76)
	add_child(cap)
	_bonus_list = _make_label("", 16)
	_bonus_list.add_theme_color_override("font_color", BONUS_COLOR)
	_bonus_list.position = Vector2(rf.position.x + 22, y + 108)
	_bonus_list.size = Vector2(rf.size.x - 44, 330)
	_bonus_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_bonus_list)
	var back := Button.new()
	back.text = "[ T ]   НАЗАД"
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(rf.position.x + 30, rf.end.y - 150)
	back.size = Vector2(rf.size.x - 60, 44)
	back.add_theme_font_size_override("font_size", 17)
	back.add_theme_color_override("font_color", HeroSkin.TEXT)
	back.add_theme_color_override("font_hover_color", HeroSkin.GOLD_HI)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45) if st == "normal" else Color(HeroSkin.GOLD_HI, 0.08)
		sb.border_color = Color(HeroSkin.GOLD, 0.45 if st == "normal" else 0.85)
		sb.set_border_width_all(1)
		b_style(back, st, sb)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(func(): _ui._close_content_panel(self))
	add_child(back)
	refresh()


static func b_style(b: Button, st: String, sb: StyleBox) -> void:
	b.add_theme_stylebox_override(st, sb)


## Табличка трофея: эмблема в круге, название, задача, прогресс, бонус.
## Не добытый — тусклый, эмблема контуром; добытый — светится, «ДОБЫТ»
class TrophyPlate extends Control:
	var trophy: Dictionary
	var counts: Dictionary = {}
	var gold := Color(0.8, 0.74, 0.6)
	var gold_hi := Color(0.96, 0.9, 0.74)
	var text := Color(0.84, 0.84, 0.82)
	var text_dim := Color(0.56, 0.58, 0.6)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := Side.U.font_of(self)
		var w := size.x
		var h := size.y
		var done := Trophies.is_done(trophy, counts)
		var prog := Trophies.progress(trophy, counts)
		var goal: int = trophy["goal"]
		var c := Vector2(w * 0.5, h * 0.3)
		var r := minf(w, h) * 0.2
		# Медальон: свечение у добытого, двойное кольцо
		if done:
			for k in 6:
				draw_circle(c, r * (1.5 - k * 0.1), Color(gold_hi, 0.03))
		draw_circle(c, r, Color(0, 0, 0, 0.55))
		draw_arc(c, r, 0, TAU, 64, Color(gold if done else text_dim, 0.9 if done else 0.5), 2.0, true)
		draw_arc(c, r * 0.86, 0, TAU, 64, Color(gold if done else text_dim, 0.35), 1.0, true)
		Emblem.draw(self, trophy["emblem"], c, r * 0.62, gold_hi if done else Color(text_dim, 0.6))

		var y := c.y + r + 34.0
		_center(f, trophy["name"], y, 20, gold_hi if done else text)
		y += 26.0
		_center(f, trophy["task"], y, 14, text_dim)
		y += 26.0
		# Прогресс
		var bw := w * 0.7
		var bx := (w - bw) * 0.5
		draw_rect(Rect2(bx, y, bw, 8), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bx, y, bw * float(prog) / maxf(goal, 1), 8), Color(gold_hi if done else gold, 0.85))
		draw_rect(Rect2(bx - 1, y - 1, bw + 2, 10), Color(gold, 0.4), false, 1.0)
		y += 28.0
		_center(f, "ДОБЫТ" if done else "%d / %d" % [prog, goal], y, 15, gold_hi if done else text)
		y += 26.0
		_center(f, trophy["bonus_text"], y, 15, BONUS_COLOR if done else Color(text_dim, 0.8))

	func _center(f: Font, s: String, y: float, fs: int, col: Color) -> void:
		s = tr(s)
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - sw) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


class Emblem:
	## Эмблемы трофеев — контурные знаки линиями (своих картинок пока нет)
	static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
		var w := 2.0
		match kind:
			"skull":
				ci.draw_arc(c + Vector2(0, -r * 0.15), r * 0.7, PI * 0.85, PI * 2.15, 32, col, w, true)
				ci.draw_line(c + Vector2(-r * 0.6, r * 0.15), c + Vector2(-r * 0.4, r * 0.75), col, w)
				ci.draw_line(c + Vector2(r * 0.6, r * 0.15), c + Vector2(r * 0.4, r * 0.75), col, w)
				ci.draw_line(c + Vector2(-r * 0.4, r * 0.75), c + Vector2(r * 0.4, r * 0.75), col, w)
				for s: float in [-1.0, 1.0]:
					ci.draw_circle(c + Vector2(s * r * 0.3, -r * 0.05), r * 0.17, col)
				for i in 3:
					var x := -r * 0.2 + i * r * 0.2
					ci.draw_line(c + Vector2(x, r * 0.5), c + Vector2(x, r * 0.75), col, 1.5)
			"shield":
				ci.draw_arc(c, r * 0.85, 0, TAU, 40, col, w, true)
				ci.draw_circle(c, r * 0.2, col)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.15, -r * 0.85), c + Vector2(r * 0.1, -r * 0.4),
						c + Vector2(-r * 0.12, -r * 0.1), c + Vector2(r * 0.18, r * 0.35), c + Vector2(0, r * 0.85)]), col, w, true)
			"axe":
				ci.draw_line(c + Vector2(-r * 0.6, r * 0.9), c + Vector2(r * 0.45, -r * 0.8), col, w + 1.0)
				ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.15, -r * 0.55), c + Vector2(r * 0.85, -r * 0.75),
						c + Vector2(r * 0.95, -r * 0.1), c + Vector2(r * 0.35, -r * 0.0)]), col, w, true)
			"sword":
				ci.draw_line(c + Vector2(0, r * 0.95), c + Vector2(0, r * 0.45), col, w + 1.0)
				ci.draw_line(c + Vector2(-r * 0.45, r * 0.45), c + Vector2(r * 0.45, r * 0.45), col, w)
				ci.draw_line(c + Vector2(0, r * 0.35), c + Vector2(0, -r * 0.1), col, w + 1.0)
				ci.draw_line(c + Vector2(r * 0.08, -r * 0.3), c + Vector2(r * 0.12, -r * 0.9), col, w + 1.0)
			"rune":
				ci.draw_line(c + Vector2(-r * 0.4, -r * 0.85), c + Vector2(-r * 0.4, r * 0.85), col, w + 0.5)
				ci.draw_line(c + Vector2(r * 0.4, -r * 0.85), c + Vector2(r * 0.4, r * 0.85), col, w + 0.5)
				ci.draw_line(c + Vector2(-r * 0.4, -r * 0.25), c + Vector2(r * 0.4, r * 0.25), col, w + 0.5)
			"hand":
				ci.draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.1), Vector2(r * 0.8, r * 0.7)), col, false, w)
				for i in 4:
					var x := -r * 0.3 + i * r * 0.2
					ci.draw_line(c + Vector2(x, -r * 0.1), c + Vector2(x, -r * (0.6 + 0.1 * (1 - absf(i - 1.5) / 1.5))), col, w)
				ci.draw_line(c + Vector2(-r * 0.4, r * 0.2), c + Vector2(-r * 0.75, -r * 0.15), col, w)
				ci.draw_line(c + Vector2(-r * 0.2, r * 0.6), c + Vector2(-r * 0.2, r * 0.9), col, w)
				ci.draw_line(c + Vector2(r * 0.2, r * 0.6), c + Vector2(r * 0.2, r * 0.9), col, w)
			"bolt":
				ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.25, -r * 0.9), c + Vector2(-r * 0.25, -r * 0.05),
						c + Vector2(r * 0.15, -r * 0.05), c + Vector2(-r * 0.3, r * 0.9)]), col, w + 1.0, true)
			_:
				# Валькнут: три сцепленных треугольника
				for i in 3:
					var o := Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * r * 0.28
					var pts := PackedVector2Array()
					for k in 4:
						pts.append(c + o + Vector2.from_angle(-PI * 0.5 + TAU * k / 3.0) * r * 0.62)
					ci.draw_polyline(pts, col, w, true)
