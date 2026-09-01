extends Control
## MenuPanel.gd — общий каркас всплывающих панелей главного меню.
##
## Ровно то же, что делает SettingsPanel.gd (затемнение, рамка, наплыв при
## открытии, Esc на закрытие, обводка текста поверх движущихся обоев) — но без
## содержимого. Панель выбора персонажа и список сохранений наследуются отсюда
## и описывают только свою начинку в _build_content().
##
## Сам SettingsPanel на эту базу не переезжает: он уже работает и вылизан, а
## переписывать рабочее ради красоты — лишний риск на ровном месте.

signal closed

# Палитра общая с MenuButton.gd и SettingsPanel.gd — панели должны выглядеть
# частью меню, а не чужими окнами
const COLOR_TEXT := Color(0.70, 0.62, 0.52)
const COLOR_BRIGHT := Color(0.92, 0.85, 0.72)
const COLOR_ACCENT := Color(0.78, 0.50, 0.19)
const COLOR_DIM := Color(0.45, 0.40, 0.34)

const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")

const PANEL_MARGIN_H := 0.11
const PANEL_MARGIN_V := 0.07

@export_range(0.0, 1.0) var dim_alpha := 0.38
@export_range(0.0, 1.0) var panel_alpha := 0.55

var _dim: ColorRect
var _panel: PanelContainer
var _audio: AudioStreamPlayer
var _tween: Tween
var _is_open := false


func _ready() -> void:
	# ИМЕННО set_anchors_and_offsets_preset, а не set_anchors_preset: второй
	# задаёт только якоря, а отступы оставляет как есть, и у созданного через
	# .new() Control размер так и остаётся нулевым. Панель внутри тогда
	# схлопывалась до размера содержимого и прилипала к левому верхнему углу,
	# а затемнение фона не появлялось вовсе — оно тоже было нулевого размера.
	# У SettingsPanel этой беды нет только потому, что он лежит готовой нодой
	# в MainMenu.tscn с уже прописанными якорями и отступами
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Ловим ввод только когда открыты — иначе перехватывали бы клики по меню
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.03, dim_alpha)
	add_child(_dim)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_rebuild()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	modulate.a = 0.0
	# Ждём кадр, чтобы панель получила реальный размер — иначе pivot окажется в
	# нуле и она наплывала бы из левого верхнего угла, а не из центра
	await get_tree().process_frame
	if not _is_open:
		return
	_panel.pivot_offset = _panel.size / 2.0

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.3)\
		.from(Vector2(0.97, 0.97)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await _tween.finished
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_play(SOUND_CHOICE)
		close()


# ----------------------------------------------------------
# КАРКАС
# ----------------------------------------------------------

func _rebuild() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()

	_panel = PanelContainer.new()
	_panel.anchor_left = PANEL_MARGIN_H
	_panel.anchor_right = 1.0 - PANEL_MARGIN_H
	_panel.anchor_top = PANEL_MARGIN_V
	_panel.anchor_bottom = 1.0 - PANEL_MARGIN_V
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, panel_alpha)
	style.border_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = _get_title()
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COLOR_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(title, 6)
	vbox.add_child(title)
	_add_rule(vbox, 16)

	_build_content(vbox)


## Переопределяют наследники
func _get_title() -> String:
	return ""


func _build_content(_parent: VBoxContainer) -> void:
	pass


# ----------------------------------------------------------
# ХЕЛПЕРЫ
# ----------------------------------------------------------

func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()


## Сквозь полупрозрачную панель просвечивают обои и дождь — без обводки светлый
## текст теряется на светлых участках фона
func _outline(node: Control, thickness := 4) -> void:
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	node.add_theme_constant_override("outline_size", thickness)


func _add_rule(parent: Control, spacing: int) -> void:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(spacing / 2.0))
	wrap.add_theme_constant_override("margin_bottom", int(spacing / 2.0))
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.28)
	wrap.add_child(rule)
	parent.add_child(wrap)


func _make_text_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
	_outline(btn)
	return btn


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	_outline(lbl)
	return lbl
