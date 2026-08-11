extends Control
## SettingsPanel.gd — панель настроек поверх главного меню.
##
## Не отдельная сцена, а оверлей: фон меню, дождь и музыка продолжают жить,
## пока игрок крутит настройки. Вся вёрстка собирается кодом — как HUD
## (health_stamina_bar.gd) и быстрый слот (quick_slot_ui.gd) в этом проекте.
##
## Сам по себе ничего не применяет и не сохраняет: значения живут в
## автозагрузке GameSettings, панель только показывает их и пишет обратно.

signal closed

# Палитра взята из MenuButton.gd — панель должна выглядеть частью меню,
# а не чужим окном
const COLOR_TEXT := Color(0.70, 0.62, 0.52)
const COLOR_BRIGHT := Color(0.92, 0.85, 0.72)
const COLOR_ACCENT := Color(0.78, 0.50, 0.19)
const COLOR_DIM := Color(0.45, 0.40, 0.34)

const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")

# Панель занимает большую часть экрана. Задаём долями (якорями), а не
# пикселями — иначе на другом разрешении окно съедет или обрежется
const PANEL_MARGIN_H := 0.11  # слева/справа: остаётся 78% ширины
const PANEL_MARGIN_V := 0.07  # сверху/снизу: остаётся 86% высоты

# Прозрачность. Сквозь панель должен читаться фон меню, но текст поверх
# движущихся обоев и дождя обязан оставаться разборчивым — отсюда компромисс:
# лёгкое затемнение всего экрана + полупрозрачная, но всё же тёмная подложка
# самой панели. Оба вынесены в @export, чтобы подбирать на глаз в инспекторе
@export_range(0.0, 1.0) var dim_alpha := 0.38
@export_range(0.0, 1.0) var panel_alpha := 0.55

var _dim: ColorRect
var _panel: PanelContainer
var _audio: AudioStreamPlayer
var _tween: Tween
var _is_open := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Панель ловит ввод только когда открыта — иначе она перехватывала бы
	# клики по кнопкам меню под собой
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Затемнение и аудио создаются один раз и живут всё время; содержимое
	# панели пересобирается при каждом открытии (_rebuild)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.03, dim_alpha)
	add_child(_dim)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	_rebuild()


# ----------------------------------------------------------
# ОТКРЫТИЕ / ЗАКРЫТИЕ
# ----------------------------------------------------------

func open() -> void:
	if _is_open:
		return
	_is_open = true
	# Пересобираем перед показом: значения могли измениться извне (сброс к
	# умолчаниям, перезагрузка конфига)
	_rebuild()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Появление: затемнение + лёгкий "наплыв" панели — тот же язык анимации,
	# что у интро меню (cubic ease-out). Масштаб, а не сдвиг: панель растянута
	# по якорям, и позиция у неё пересчитывается движком при каждом layout
	modulate.a = 0.0
	# Ждём кадр, чтобы панель получила реальный размер — иначе pivot окажется
	# в нуле и она "наплывала" бы из левого верхнего угла, а не из центра
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
	# Пишем на диск один раз при закрытии, а не на каждое движение ползунка
	GameSettings.save_settings()

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
		close()


# ----------------------------------------------------------
# ПОСТРОЕНИЕ UI
# ----------------------------------------------------------

func _rebuild() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()

	_panel = PanelContainer.new()
	# Растягиваем по якорям на большую часть экрана вместо CenterContainer
	# с фиксированной шириной — так панель одинаково хорошо смотрится на
	# любом разрешении
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
	# Рамку и тень делаем заметнее прежнего: у полупрозрачной панели края
	# сливаются с фоном, и без них она перестаёт читаться как отдельный слой
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

	# --- Заголовок ---
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COLOR_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(title, 6)
	vbox.add_child(title)
	_add_rule(vbox, 16)

	# Содержимое в прокрутке: на большой панели всё влезает с запасом, но на
	# низком разрешении список настроек иначе обрезался бы снизу
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# --- Звук ---
	_add_section(content, "ЗВУК")
	_add_slider(content, "Общая громкость", GameSettings.master_volume,
		func(v: float): GameSettings.master_volume = v; GameSettings.apply_all())
	_add_slider(content, "Музыка", GameSettings.music_volume,
		func(v: float): GameSettings.music_volume = v; GameSettings.apply_all())
	# На ползунке эффектов даём послушать пример — иначе в меню его крутишь
	# вслепую, боевых звуков тут нет
	_add_slider(content, "Эффекты", GameSettings.sfx_volume,
		func(v: float): GameSettings.sfx_volume = v; GameSettings.apply_all(),
		true)

	# --- Геймплей ---
	_add_section(content, "ГЕЙМПЛЕЙ")
	_add_slider(content, "Тряска камеры", GameSettings.shake_multiplier,
		func(v: float): GameSettings.shake_multiplier = v)

	# --- Экран ---
	_add_section(content, "ЭКРАН")
	_add_toggle(content, "Полный экран", GameSettings.fullscreen,
		func(v: bool): GameSettings.fullscreen = v; GameSettings.apply_all())
	_add_toggle(content, "Верт. синхронизация", GameSettings.vsync,
		func(v: bool): GameSettings.vsync = v; GameSettings.apply_all())

	# --- Кнопки внизу ---
	_add_rule(vbox, 18)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 64)
	vbox.add_child(row)

	var reset_btn := _make_text_button("ПО УМОЛЧАНИЮ", 26)
	reset_btn.pressed.connect(_on_reset)
	row.add_child(reset_btn)

	var back_btn := _make_text_button("НАЗАД", 30)
	back_btn.pressed.connect(func(): _play(SOUND_ACCEPT); close())
	row.add_child(back_btn)


func _add_rule(parent: Control, spacing: int) -> void:
	## Тонкая горизонтальная линия-разделитель
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", int(spacing / 2.0))
	wrap.add_theme_constant_override("margin_bottom", int(spacing / 2.0))
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.28)
	wrap.add_child(rule)
	parent.add_child(wrap)


func _add_section(parent: Control, section_title: String) -> void:
	var lbl := Label.new()
	lbl.text = section_title
	lbl.add_theme_font_size_override("font_size", 27)
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_outline(lbl, 5)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 22)
	wrap.add_child(lbl)
	parent.add_child(wrap)


func _make_row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 25)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.custom_minimum_size = Vector2(360, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(lbl)
	row.add_child(lbl)
	return row


func _add_slider(parent: Control, label_text: String, value: float,
		on_change: Callable, preview_sound := false) -> void:
	var row := _make_row(parent, label_text)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	# Числовое значение справа — фиксированной ширины, иначе ползунок дёргался
	# бы туда-сюда при смене "5%" на "100%"
	var value_lbl := Label.new()
	value_lbl.text = "%d%%" % roundi(value * 100.0)
	value_lbl.add_theme_font_size_override("font_size", 23)
	value_lbl.add_theme_color_override("font_color", COLOR_DIM)
	value_lbl.custom_minimum_size = Vector2(82, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(value_lbl)
	row.add_child(value_lbl)

	slider.value_changed.connect(func(v: float):
		value_lbl.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v)
	)
	if preview_sound:
		# Звук по отпусканию, а не на каждый шаг — иначе при перетаскивании
		# он строчил бы очередью
		slider.drag_ended.connect(func(changed: bool):
			if changed:
				_play(SOUND_CHOICE)
		)


func _add_toggle(parent: Control, label_text: String, value: bool, on_change: Callable) -> void:
	var row := _make_row(parent, label_text)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Вместо CheckButton — текстовая кнопка ВКЛ/ВЫКЛ: тема меню уже стилизует
	# кнопки как плоский текст, а дефолтный чекбокс Godot выбивался бы из
	# общего вида
	var btn := _make_text_button("ВКЛ" if value else "ВЫКЛ", 25)
	btn.custom_minimum_size = Vector2(130, 0)
	btn.add_theme_color_override("font_color", COLOR_BRIGHT if value else COLOR_DIM)
	row.add_child(btn)

	var state := {"on": value}
	btn.pressed.connect(func():
		state["on"] = not state["on"]
		btn.text = "ВКЛ" if state["on"] else "ВЫКЛ"
		btn.add_theme_color_override("font_color", COLOR_BRIGHT if state["on"] else COLOR_DIM)
		_play(SOUND_CHOICE)
		on_change.call(state["on"])
	)


# Сквозь полупрозрачную панель просвечивают движущиеся обои и дождь, и
# светлый текст на светлых участках фона теряется. Обводка держит читаемость
# на любой подложке — тот же приём, что у цифр быстрого слота в quick_slot_ui.gd
func _outline(node: Control, thickness := 4) -> void:
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	node.add_theme_constant_override("outline_size", thickness)


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


func _style_slider(slider: HSlider) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.14, 0.13, 0.11, 1.0)
	groove.content_margin_top = 3
	groove.content_margin_bottom = 3
	groove.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("slider", groove)

	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_ACCENT
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	fill.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	# Ползунок — круг, собранный радиальным градиентом: резкая граница даёт
	# сплошной кружок, а не размытое пятно (тот же приём, что и маска иконки
	# в quick_slot_ui.gd)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.78, 0.92])
	grad.colors = PackedColorArray([COLOR_BRIGHT, COLOR_BRIGHT, Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 24
	tex.height = 24
	slider.add_theme_icon_override("grabber", tex)
	slider.add_theme_icon_override("grabber_highlight", tex)


# ----------------------------------------------------------
# ПРОЧЕЕ
# ----------------------------------------------------------

func _on_reset() -> void:
	_play(SOUND_CHOICE)
	GameSettings.reset_to_defaults()
	_rebuild()


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()
