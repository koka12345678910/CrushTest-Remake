extends Control
## ControlsPanel.gd — памятка по управлению перед стартом игры.
##
## Полноценного экрана настроек управления пока нет, а билд уходит людям,
## которые игру не видели, — поэтому перед загрузкой уровня (после выбора
## героя или «Продолжить») показывается это окно: какие кнопки что делают.
## «Начать путь» (Enter/Пробел/E/A) — сигнал confirmed, игра стартует;
## «Назад» (Esc/B) — cancelled, возвращаемся в меню.
##
## Вид — как панели инвентаря (MenuStyle.gd): тёмная плашка с каймой,
## золотые заголовки разделов, клавиши — тёмные плашки, кнопки мыши —
## мышкой с подсвеченной кнопкой. Раскладку брать из project.godot ->
## [input]; поменял клавишу там — поправь строку здесь.

signal confirmed
signal cancelled

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")

const PANEL_SIZE := Vector2(1080, 780)
const GOLD := Style.GOLD
const GOLD_HI := Style.GOLD_HI
const TEXT := Style.TEXT
const TEXT_DIM := Style.TEXT_DIM
## Кайма клавиш и мыши
const KEY_EDGE := Color(1, 1, 1, 0.24)
const KEY_FILL := Color(0.0, 0.0, 0.0, 0.6)

## [заголовок, [[клавиши], действие, пояснение]]. Клавиши: обычный текст —
## клавиша; "LMB"/"RMB"/"MMB"/"WHEEL" — мышь; "+" и "/" — разделители
const SECTIONS := {
	"left": [
		["ДВИЖЕНИЕ", [
			[["W", "A", "S", "D"], "Идти", "или стрелки"],
			[["Shift"], "Бег", "держать при движении"],
			[["Пробел"], "Перекат", "сквозь врагов"],
		]],
		["ПРЕДМЕТЫ И МИР", [
			[["R"], "Использовать", "предмет из быстрого слота"],
			[["WHEEL"], "Сменить слот", ""],
			[["E"], "Взаимодействие", "поднять, говорить, торговать"],
			[["Esc"], "Инвентарь", "предметы, навыки, настройки"],
		]],
	],
	"right": [
		["БОЙ", [
			[["LMB"], "Удар", "серия из 4 — последний с разворота"],
			[["Shift", "+", "LMB"], "Удар с разбега", ""],
			[["RMB"], "Блок", "держать"],
			[["RMB"], "Парирование", "нажать перед самым ударом"],
			[["V"], "Пинок", ""],
			[["MMB"], "Захват цели", "ближайший враг"],
		]],
	],
}

var _font: Font
var _font_caps: Font
var _font_italic: Font
var _panel: Control
var _closing := false
var _audio: AudioStreamPlayer
var _begin: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.make_theme()
	_font = Style.font()
	_font_caps = Style.caps_font()
	_font_italic = Style.italic_font()
	_audio = Style.ui_player(self)
	Style.make_dim(self, 0.72)

	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	var back := _make_button("НАЗАД", Vector2(PANEL_SIZE.x * 0.5 - 320, PANEL_SIZE.y - 86), Vector2(260, 50))
	back.pressed.connect(_finish.bind(false))
	_begin = _make_button("НАЧАТЬ ПУТЬ", Vector2(PANEL_SIZE.x * 0.5 + 60, PANEL_SIZE.y - 86), Vector2(260, 50))
	_begin.pressed.connect(_finish.bind(true))
	for pair in [[back, _begin], [_begin, back]]:
		var a: Button = pair[0]
		a.focus_neighbor_left = a.get_path_to(pair[1])
		a.focus_neighbor_right = a.get_path_to(pair[1])
		a.focus_entered.connect(func(): Style.play_move(_audio))
	_begin.call_deferred("grab_focus")

	resized.connect(_center)
	_center()

	modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Style.play_open(_audio)


func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Style.chip_button(text, 18)
	b.position = pos
	b.size = sz
	_panel.add_child(b)
	return b


func _center() -> void:
	if is_instance_valid(_panel):
		_panel.position = ((size - PANEL_SIZE) * 0.5).round()


func _finish(begin: bool) -> void:
	if _closing:
		return
	_closing = true
	if begin:
		Style.play(_audio, Style.SOUND_ACCEPT)
		# Сигнал сразу: дальше SceneLoader сам гасит экран в чёрное, окно
		# уходит вместе с меню
		confirmed.emit()
	else:
		Style.play_back(_audio)
		cancelled.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2(0.97, 0.97), 0.18)
	await tw.finished
	queue_free()


## Модальное: ввод под окно не проходит. Enter/A нажимает кнопку в фокусе
## (это делает сама кнопка), E — всегда «Начать путь»
func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		_finish(false)
	elif event.is_action_pressed("ui_accept") \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		_finish(true)
	if not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


# ── Плашка ───────────────────────────────────────────────────────────────────

func _draw_panel() -> void:
	var p := _panel
	var r := Rect2(Vector2.ZERO, PANEL_SIZE)
	var sb := Style.panel_box(6)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 26
	p.draw_style_box(sb, r)

	# Шапка
	p.draw_string(_font_caps, Vector2(0, 72), tr("УПРАВЛЕНИЕ"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, GOLD)
	p.draw_string(_font_italic, Vector2(0, 106), tr("Запомни, как держать клинок, прежде чем дать клятву."),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, TEXT_DIM)
	_fade_line(Vector2(160, 130), r.size.x - 320, Color(GOLD, 0.35))

	# Колонки
	_draw_column(SECTIONS["left"], 70.0, 180.0, 440.0)
	_draw_column(SECTIONS["right"], 580.0, 180.0, 440.0)
	p.draw_rect(Rect2(r.size.x * 0.5 + 5, 170, 1, 470), Style.LINE)

	_fade_line(Vector2(160, 668), r.size.x - 320, Style.LINE)


func _draw_column(sections: Array, x: float, y: float, w: float) -> void:
	var p := _panel
	for sec in sections:
		var title: String = tr(sec[0])
		p.draw_string(_font_caps, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)
		var tw := _font_caps.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		p.draw_rect(Rect2(x + tw + 14, y - 6, w - tw - 14, 1), Style.LINE)
		y += 22.0
		for row in sec[1]:
			_draw_row(row, x, y, w)
			y += 60.0
		y += 22.0


## Строка: клавиши слева (колонка 176px), справа действие и серое пояснение
func _draw_row(row: Array, x: float, y: float, w: float) -> void:
	var p := _panel
	var keys: Array = row[0]
	var kx := x
	var cy := y + 24.0
	for k in keys:
		kx += _draw_key(String(k), Vector2(kx, cy)) + 6.0
	var tx := x + 176.0
	var hint: String = tr(row[2]) if row[2] != "" else ""
	var ty := cy + (0.0 if hint == "" else -6.0)
	p.draw_string(_font, Vector2(tx, ty + 7), tr(String(row[1])), HORIZONTAL_ALIGNMENT_LEFT, w - 176.0, 20, TEXT)
	if hint != "":
		p.draw_string(_font_italic, Vector2(tx, ty + 27), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 176.0, 15, TEXT_DIM)


## Рисует одну «клавишу» с левым краем в x и центром по вертикали cy.
## Возвращает её ширину
func _draw_key(k: String, left_mid: Vector2) -> float:
	var p := _panel
	if k == "+" or k == "/":
		p.draw_string(_font, left_mid + Vector2(0, 7), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT_DIM)
		return 12.0
	if k in ["LMB", "RMB", "MMB", "WHEEL"]:
		return _draw_mouse(k, left_mid)
	k = tr(k)
	var fs := 16
	var tw := _font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var kw := maxf(36.0, tw + 20.0)
	var r := Rect2(left_mid + Vector2(0, -17), Vector2(kw, 34))
	var sb := StyleBoxFlat.new()
	sb.bg_color = KEY_FILL
	sb.border_color = KEY_EDGE
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(3)
	p.draw_style_box(sb, r)
	p.draw_string(_font, Vector2(r.position.x, r.get_center().y + 5), k, HORIZONTAL_ALIGNMENT_CENTER, kw, fs, TEXT)
	return kw


## Мышь: корпус, линия между кнопками, нужная кнопка/колесо — золотом
func _draw_mouse(k: String, left_mid: Vector2) -> float:
	var p := _panel
	var w := 28.0
	var h := 40.0
	var r := Rect2(left_mid + Vector2(0, -h * 0.5), Vector2(w, h))
	var c := r.get_center()
	var body := PackedVector2Array()
	for i in 25:
		var a := PI + i * PI / 24.0
		body.append(Vector2(c.x + cos(a) * w * 0.5, r.position.y + 13 + sin(a) * 13))
	body.append(Vector2(r.end.x, r.end.y - 11))
	for i in 25:
		var a := i * PI / 24.0
		body.append(Vector2(c.x + cos(a) * w * 0.5, r.end.y - 11 + sin(a) * 11))
	p.draw_colored_polygon(body, KEY_FILL)
	var split_y := r.position.y + 15
	if k == "LMB" or k == "RMB":
		p.draw_colored_polygon(_button_shape(r, split_y, k == "LMB"), Color(GOLD_HI, 0.9))
	var loop := body.duplicate()
	loop.append(body[0])
	p.draw_polyline(loop, KEY_EDGE, 1.3, true)
	p.draw_line(Vector2(r.position.x + 1, split_y), Vector2(r.end.x - 1, split_y), KEY_EDGE, 1.0)
	p.draw_line(Vector2(c.x, r.position.y + 1), Vector2(c.x, split_y), KEY_EDGE, 1.0)
	# Колесо
	var wheel := Rect2(c.x - 3, r.position.y + 5, 6, 9)
	p.draw_rect(wheel, Color(GOLD_HI, 0.9) if (k == "MMB" or k == "WHEEL") else Color(1, 1, 1, 0.15))
	if k == "WHEEL":
		for s: float in [-1.0, 1.0]:
			var tip := Vector2(r.end.x + 8, c.y + s * 9)
			p.draw_polyline(PackedVector2Array([tip + Vector2(-4, -s * 4), tip, tip + Vector2(4, -s * 4)]), GOLD, 1.5, true)
		return w + 14.0
	return w


## Левая/правая кнопка мыши: четверть скруглённого верха корпуса
func _button_shape(r: Rect2, split_y: float, left: bool) -> PackedVector2Array:
	var cx := r.get_center().x
	var arc_c := Vector2(cx, r.position.y + 13)
	var out := PackedVector2Array()
	var a0 := PI if left else PI * 1.5
	for i in 13:
		var a := a0 + i * (PI * 0.5) / 12.0
		out.append(arc_c + Vector2(cos(a) * r.size.x * 0.5, sin(a) * 13.0))
	if left:
		out.append(Vector2(cx, split_y))
		out.append(Vector2(r.position.x, split_y))
	else:
		out.append(Vector2(r.end.x, split_y))
		out.append(Vector2(cx, split_y))
	return out


## Черта, гаснущая к концам
func _fade_line(at: Vector2, width: float, color: Color) -> void:
	var n := 24
	var step := width / n
	for i in n:
		var t := (i + 0.5) / n
		var a := 1.0 - absf(t - 0.5) * 2.0
		_panel.draw_rect(Rect2(at.x + i * step, at.y, step + 0.5, 1), Color(color, color.a * smoothstep(0.0, 0.6, a)))
