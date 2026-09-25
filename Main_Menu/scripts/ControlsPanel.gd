extends Control
## ControlsPanel.gd — памятка по управлению перед стартом игры.
##
## Полноценного экрана настроек управления пока нет, а билд уходит людям,
## которые игру не видели, — поэтому перед загрузкой уровня (после выбора
## героя или "Continue") показывается это окно: какие кнопки что делают.
## "BEGIN JOURNEY" (Enter/Пробел/E) — сигнал confirmed, игра стартует;
## "BACK" (Esc) — cancelled, возвращаемся в меню.
##
## Стиль — как у InDevelopmentPanel.gd и окон навыков/магазина. Клавиши
## нарисованы "клавишами", кнопки мыши — мышкой с подсвеченной кнопкой.
## Раскладку брать из project.godot -> [input]; поменял клавишу там —
## поправь строку здесь.

signal confirmed
signal cancelled

const OrnateButtonScript := preload("res://Inventory/ui/ornate_button.gd")

const PANEL_SIZE := Vector2(1060, 820)
const GOLD := Color(0.8, 0.62, 0.34)
const GOLD_BRIGHT := Color(1.0, 0.8, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.3, 0.75)
const GOLD_FAINT := Color(0.55, 0.45, 0.3, 0.25)
const TEXT := Color(0.9, 0.84, 0.72)
const TEXT_DIM := Color(0.62, 0.57, 0.48)

const SOUND_OPEN := preload("res://Sound/UI_button/choice.wav")
const SOUND_BEGIN := preload("res://Sound/UI_button/accept.wav")

## [заголовок, [[клавиши], описание, пояснение]]. Клавиши: обычный текст —
## клавиша; "LMB"/"RMB"/"MMB"/"WHEEL" — мышь; "+" и "/" — разделители
const SECTIONS := {
	"left": [
		["MOVEMENT", [
			[["W", "A", "S", "D"], "Move", "or the arrow keys"],
			[["Shift"], "Run", "hold while moving"],
			[["Space"], "Roll", "passes through enemies"],
		]],
		["ITEMS & WORLD", [
			[["R"], "Use item", "from the quick slot"],
			[["WHEEL"], "Switch quick slot", ""],
			[["E"], "Interact", "talk, open the shop"],
			[["Esc"], "Inventory", "items, skills, settings"],
		]],
	],
	"right": [
		["COMBAT", [
			[["LMB"], "Attack", "a combo of 4 — the last strike spins"],
			[["Shift", "+", "LMB"], "Running attack", ""],
			[["RMB"], "Block", "hold"],
			[["RMB"], "Parry", "press just before a hit lands"],
			[["V"], "Kick", ""],
			[["MMB"], "Lock on", "focus the nearest enemy"],
		]],
	],
}

var _font: Font
var _font_italic: Font
var _panel: Control
var _t := 0.0
var _closing := false
var _audio: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	_font = serif
	var ital := SystemFont.new()
	ital.font_names = serif.font_names
	ital.font_italic = true
	_font_italic = ital

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	var back := _make_button("BACK", Vector2(PANEL_SIZE.x * 0.5 - 330, PANEL_SIZE.y - 84), Vector2(220, 46))
	back.pressed.connect(_finish.bind(false))
	var begin := _make_button("BEGIN JOURNEY", Vector2(PANEL_SIZE.x * 0.5 + 40, PANEL_SIZE.y - 84), Vector2(290, 46))
	begin.pressed.connect(_finish.bind(true))

	resized.connect(_center)
	_center()

	modulate.a = 0.0
	_panel.scale = Vector2(0.95, 0.95)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_play(SOUND_OPEN)


func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.set_script(OrnateButtonScript)
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 18)
	_panel.add_child(b)
	return b


func _center() -> void:
	if is_instance_valid(_panel):
		_panel.position = (size - PANEL_SIZE) * 0.5


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()


func _finish(begin: bool) -> void:
	if _closing:
		return
	_closing = true
	if begin:
		_play(SOUND_BEGIN)
		# Сигнал сразу: дальше SceneLoader сам гасит экран в чёрное, окно
		# уходит вместе с меню
		confirmed.emit()
	else:
		_play(SOUND_OPEN)
		cancelled.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2(0.96, 0.96), 0.18)
	await tw.finished
	queue_free()


## Модальное: ввод под окно не проходит
func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		_finish(false)
	elif event.is_action_pressed("ui_accept") \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		_finish(true)
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_panel.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))


# ── Плита ────────────────────────────────────────────────────────────────────

func _draw_panel() -> void:
	var p := _panel
	var r := Rect2(Vector2.ZERO, PANEL_SIZE)
	var pulse := 0.8 + 0.2 * sin(_t * 2.2)
	var cx := r.size.x * 0.5

	for g in 5:
		p.draw_rect(r.grow(3.0 + g * 5.0), Color(1.0, 0.6, 0.2, 0.045 * pulse * (5 - g) / 5.0), false, 5.0)
	p.draw_rect(r, Color(0.04, 0.036, 0.032, 0.98))
	for i in 6:
		p.draw_circle(Vector2(cx, 360), 520.0 - i * 70.0, Color(0.09, 0.08, 0.07, 0.045))
	for i in 10:
		p.draw_rect(r.grow(-i * 3.0), Color(0, 0, 0, 0.04), false, 3.0)
	p.draw_rect(r, GOLD_DIM, false, 1.5)
	p.draw_rect(r.grow(-8.0), GOLD_FAINT, false, 1.0)
	for cc in [[r.position, 1.0, 1.0], [Vector2(r.end.x, 0), -1.0, 1.0],
			[Vector2(0, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		_corner(cc[0], cc[1], cc[2])
	for y in [0.0, r.end.y]:
		p.draw_circle(Vector2(cx, y), 14.0, Color(1.0, 0.6, 0.2, 0.12 * pulse))
		_diamond(Vector2(cx, y), 9.0, GOLD_BRIGHT, true)

	# Шапка
	p.draw_string(_font, Vector2(0, 74), "CONTROLS", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(1.0, 0.88, 0.62))
	p.draw_string(_font_italic, Vector2(0, 108), "Learn the ways of the blade before you take the oath.",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, TEXT_DIM)
	_ornament_line(Vector2(140, 132), Vector2(r.size.x - 140, 132))

	# Колонки
	_draw_column(SECTIONS["left"], 64.0, 178.0, 440.0)
	_draw_column(SECTIONS["right"], 560.0, 178.0, 440.0)
	p.draw_line(Vector2(cx - 10, 170), Vector2(cx - 10, 650), GOLD_FAINT, 1.0)
	_diamond(Vector2(cx - 10, 410), 4.0, GOLD_DIM)

	_ornament_line(Vector2(140, 690), Vector2(r.size.x - 140, 690))


func _draw_column(sections: Array, x: float, y: float, w: float) -> void:
	var p := _panel
	for sec in sections:
		var title: String = sec[0]
		_diamond(Vector2(x + 5, y - 6), 4.5, GOLD, true)
		p.draw_string(_font, Vector2(x + 18, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
		var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		p.draw_line(Vector2(x + 30 + tw, y - 6), Vector2(x + w, y - 6), GOLD_FAINT, 1.0)
		y += 26.0
		for row in sec[1]:
			_draw_row(row, x, y, w)
			y += 62.0
		y += 22.0


## Строка: клавиши слева (колонка 170px), справа действие и серое пояснение
func _draw_row(row: Array, x: float, y: float, w: float) -> void:
	var p := _panel
	var keys: Array = row[0]
	var kx := x
	var cy := y + 24.0
	for k in keys:
		kx += _draw_key(String(k), Vector2(kx, cy)) + 6.0
	var tx := x + 176.0
	var hint: String = row[2]
	var ty := cy + (0.0 if hint == "" else -5.0)
	p.draw_string(_font, Vector2(tx, ty + 7), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 176.0, 20, TEXT)
	if hint != "":
		p.draw_string(_font_italic, Vector2(tx, ty + 27), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 176.0, 15, TEXT_DIM)


## Рисует одну "клавишу" с левым краем в x и центром по вертикали cy.
## Возвращает её ширину
func _draw_key(k: String, left_mid: Vector2) -> float:
	var p := _panel
	if k == "+" or k == "/":
		p.draw_string(_font, left_mid + Vector2(0, 7), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT_DIM)
		return 12.0
	if k in ["LMB", "RMB", "MMB", "WHEEL"]:
		return _draw_mouse(k, left_mid)
	var fs := 17
	var tw := _font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var kw := maxf(36.0, tw + 20.0)
	var r := Rect2(left_mid + Vector2(0, -18), Vector2(kw, 36))
	# Клавиша: тёмная, с "фаской" снизу и светлой кромкой сверху
	p.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.6))
	p.draw_rect(r, Color(0.09, 0.08, 0.065))
	p.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y - 9)), Color(0.13, 0.115, 0.09))
	p.draw_rect(r, GOLD_DIM, false, 1.3)
	p.draw_line(r.position + Vector2(4, 2), Vector2(r.end.x - 4, r.position.y + 2), Color(GOLD, 0.35), 1.0)
	p.draw_string(_font, Vector2(r.position.x, r.get_center().y + 4), k, HORIZONTAL_ALIGNMENT_CENTER, kw, fs, Color(1.0, 0.9, 0.7))
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
	p.draw_colored_polygon(body, Color(0.09, 0.08, 0.065))
	var hi := Color(GOLD_BRIGHT, 0.9)
	var split_y := r.position.y + 15
	if k == "LMB" or k == "RMB":
		p.draw_colored_polygon(_button_shape(r, split_y, k == "LMB"), hi)
	var loop := body.duplicate()
	loop.append(body[0])
	p.draw_polyline(loop, GOLD_DIM, 1.3, true)
	p.draw_line(Vector2(r.position.x + 1, split_y), Vector2(r.end.x - 1, split_y), GOLD_DIM, 1.0)
	p.draw_line(Vector2(c.x, r.position.y + 1), Vector2(c.x, split_y), GOLD_DIM, 1.0)
	# Колесо
	var wheel := Rect2(c.x - 3, r.position.y + 5, 6, 9)
	p.draw_rect(wheel, hi if (k == "MMB" or k == "WHEEL") else Color(0.2, 0.18, 0.15))
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


func _corner(pt: Vector2, sx: float, sy: float) -> void:
	var p := _panel
	var o := Vector2(sx, sy)
	p.draw_line(pt + Vector2(-sx * 5, -sy * 5), pt + Vector2(sx * 48, -sy * 5), GOLD, 1.5)
	p.draw_line(pt + Vector2(-sx * 5, -sy * 5), pt + Vector2(-sx * 5, sy * 48), GOLD, 1.5)
	p.draw_line(pt + o * 10, pt + Vector2(sx * 32, sy * 10), Color(GOLD, 0.5), 1.0)
	p.draw_line(pt + o * 10, pt + Vector2(sx * 10, sy * 32), Color(GOLD, 0.5), 1.0)
	p.draw_line(pt + o * 12, pt + o * 24, GOLD_DIM, 1.0)
	p.draw_arc(pt + o * 28, 4.5, 0.0, TAU, 16, GOLD_DIM, 1.0, true)
	_diamond(pt + Vector2(-sx * 5, -sy * 5), 4.5, GOLD, true)


func _diamond(c: Vector2, s: float, col: Color, filled := false) -> void:
	var p := _panel
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	if filled:
		p.draw_colored_polygon(pts, Color(0.06, 0.05, 0.04))
	pts.append(pts[0])
	p.draw_polyline(pts, col, 1.3, true)
	if filled:
		p.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.4, 0),
				c + Vector2(0, s * 0.4), c + Vector2(-s * 0.4, 0)]), col)


func _ornament_line(a: Vector2, b: Vector2) -> void:
	var p := _panel
	var mid := (a + b) * 0.5
	p.draw_line(a, mid - Vector2(14, 0), GOLD_DIM, 1.0)
	p.draw_line(mid + Vector2(14, 0), b, GOLD_DIM, 1.0)
	_diamond(mid, 6.0, GOLD, true)
	_diamond(mid - Vector2(22, 0), 3.0, GOLD_DIM)
	_diamond(mid + Vector2(22, 0), 3.0, GOLD_DIM)
	p.draw_circle(a, 1.5, GOLD_DIM)
	p.draw_circle(b, 1.5, GOLD_DIM)
