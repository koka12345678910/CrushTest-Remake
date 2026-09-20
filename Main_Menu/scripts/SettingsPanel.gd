extends Control
## SettingsPanel.gd — панель настроек поверх главного меню.
##
## Не отдельная сцена, а оверлей: фон меню, дождь и музыка продолжают жить,
## пока игрок крутит настройки. Вся вёрстка собирается кодом — как HUD
## (health_stamina_bar.gd) и быстрый слот (quick_slot_ui.gd) в этом проекте.
##
## Дизайн — сайдбар с категориями слева (GENERAL/GRAPHICS/AUDIO/CONTROLS/
## LANGUAGE) + список настроек справа, подсказка с описанием наведённого
## пункта и строка RESET/BACK внизу — по референсу, который скинул пользователь.
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
const COLOR_DIVIDER := Color(0.55, 0.50, 0.40, 0.35)

const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")

const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")
const OrnamentSeparatorScript := preload("res://Main_Menu/scripts/OrnamentSeparator.gd")
const ToggleSwitchScript := preload("res://Main_Menu/scripts/ToggleSwitch.gd")
const CategoryTabScript := preload("res://Main_Menu/scripts/CategoryTab.gd")

# Тот же шрифт, что у навигации меню (MenuTheme.tres). Сама тема сюда не
# доходит: между MainMenu и панелью стоит CanvasLayer, а он рвёт наследование
# темы — по этой же причине в MainMenu.tscn тема продублирована на MenuButtons
const MENU_FONT := preload("res://Font/sikandinarie.ttf")

# Панель прибита к левому краю и тянется во всю высоту экрана. Справа
# остаётся открытый фон меню — рыцарь и руины должны просматриваться
const PANEL_WIDTH_RATIO := 0.68
const SIDEBAR_WIDTH := 280.0

const CATEGORIES := ["GENERAL", "GRAPHICS", "AUDIO", "CONTROLS", "LANGUAGE"]

# Прозрачность. Сквозь панель должен читаться фон меню, но текст поверх
# движущихся обоев и дождя обязан оставаться разборчивым — отсюда компромисс:
# едва заметное затемнение всего экрана (иначе арт справа темнеет вместе с
# панелью) + полупрозрачная тёмная подложка слева, гаснущая к правому краю.
# Оба вынесены в @export, чтобы подбирать на глаз в инспекторе
@export_range(0.0, 1.0) var dim_alpha := 0.12
@export_range(0.0, 1.0) var panel_alpha := 0.72

var _dim: ColorRect
var _panel: PanelContainer
var _audio: AudioStreamPlayer
var _tween: Tween
var _is_open := false

# Какая вкладка открыта — переживает пересборку (переключение вкладки,
# сброс к умолчаниям), чтобы игрок не улетал обратно на GENERAL
var _current_category := "GENERAL"

var _rows_box: VBoxContainer
var _header_lbl: Label
var _desc_title: Label
var _desc_body: Label
var _hints: HBoxContainer


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
	if is_instance_valid(_hints):
		_hints.queue_free()

	_panel = PanelContainer.new()
	# Прибита к левому краю, во всю высоту экрана. Доли, а не пиксели —
	# иначе на другом разрешении панель съедет или обрежется
	_panel.anchor_left = 0.0
	_panel.anchor_right = PANEL_WIDTH_RATIO
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0

	# Ни рамки, ни заливки у самой панели: фон даёт градиентная подложка ниже,
	# которая к правому краю уходит в ноль — так арт с рыцарем не обрезается
	# резкой вертикальной границей
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# Шрифт навигации для всего содержимого. Ставим отдельной темой только с
	# default_font, а не MenuTheme.tres целиком — иначе её стили кнопок
	# (отступы, размер 26) перебили бы вёрстку строк настроек
	var panel_theme := Theme.new()
	panel_theme.default_font = MENU_FONT
	_panel.theme = panel_theme
	add_child(_panel)

	var backdrop := TextureRect.new()
	backdrop.texture = _make_backdrop()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	_panel.add_child(margin)

	var root_hbox := HBoxContainer.new()
	margin.add_child(root_hbox)

	_build_sidebar(root_hbox)
	_build_divider(root_hbox)
	_build_content(root_hbox)
	_build_hints()


func _make_backdrop() -> GradientTexture2D:
	## Горизонтальный градиент: слева плотная тёмная подложка под текст,
	## справа — полная прозрачность, чтобы фон меню переходил в панель плавно
	var base := Color(0.03, 0.03, 0.035)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(base.r, base.g, base.b, panel_alpha),
		Color(base.r, base.g, base.b, panel_alpha * 0.9),
		Color(base.r, base.g, base.b, 0.0),
	])

	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 4
	return tex


func _build_hints() -> void:
	## RESET/BACK живут не внутри панели, а в правом нижнем углу экрана —
	## поверх открытого арта, как на референсе
	_hints = HBoxContainer.new()
	_hints.anchor_left = 1.0
	_hints.anchor_top = 1.0
	_hints.anchor_right = 1.0
	_hints.anchor_bottom = 1.0
	_hints.offset_left = -440.0
	_hints.offset_top = -88.0
	_hints.offset_right = -48.0
	_hints.offset_bottom = -30.0
	_hints.alignment = BoxContainer.ALIGNMENT_END
	_hints.add_theme_constant_override("separation", 18)

	var hints_theme := Theme.new()
	hints_theme.default_font = MENU_FONT
	_hints.theme = hints_theme
	add_child(_hints)

	_hints.add_child(_make_hint_button("RESET", _on_reset))
	_hints.add_child(_make_hint_button("BACK", func(): _play(SOUND_ACCEPT); close()))


# --- Сайдбар: заголовок "SETTINGS" + список категорий ---------------------

func _build_sidebar(parent: Control) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0)
	sidebar.add_theme_constant_override("separation", 2)
	parent.add_child(sidebar)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	sidebar.add_child(title_row)

	var mark := Control.new()
	mark.set_script(DiamondMarkerScript)
	mark.custom_minimum_size = Vector2(18, 18)
	mark.size = Vector2(18, 18)
	title_row.add_child(mark)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", COLOR_BRIGHT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(title, 5)
	title_row.add_child(title)

	_add_rule(sidebar, 22)

	for cat in CATEGORIES:
		var row := _make_category_row(cat)
		sidebar.add_child(row)
		# Метод из CategoryTab.gd, а не из Button — только через .call(),
		# иначе статическая типизация GDScript откажется компилировать файл
		row.call("set_active", cat == _current_category)


func _make_category_row(cat_name: String) -> Button:
	var btn := Button.new()
	btn.set_script(CategoryTabScript)
	btn.text = cat_name
	btn.pressed.connect(func():
		if _current_category == cat_name:
			return
		_current_category = cat_name
		_play(SOUND_CHOICE)
		_rebuild()
	)
	return btn


# --- Вертикальный разделитель между сайдбаром и содержимым -----------------

func _build_divider(parent: Control) -> void:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 26)
	wrap.add_theme_constant_override("margin_right", 26)
	parent.add_child(wrap)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1.5, 0)
	line.color = COLOR_DIVIDER
	wrap.add_child(line)


# --- Содержимое вкладки: заголовок, список настроек, подсказка, RESET/BACK -

func _build_content(parent: Control) -> void:
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	parent.add_child(content)

	_header_lbl = Label.new()
	_header_lbl.add_theme_font_size_override("font_size", 32)
	_header_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	_outline(_header_lbl, 5)
	content.add_child(_header_lbl)

	var sep := Control.new()
	sep.set_script(OrnamentSeparatorScript)
	sep.custom_minimum_size = Vector2(0, 18)
	content.add_child(sep)

	# Панель теперь во всю высоту экрана, а настроек в категории единицы —
	# прокрутка не нужна: список ложится сразу под заголовок, а пустоту внизу
	# добирает распорка перед подсказкой
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 16)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_rows_box)

	_add_rule(content, 12)

	# Подсказка: ромбик + название и описание наведённого пункта
	var desc_row := HBoxContainer.new()
	desc_row.add_theme_constant_override("separation", 12)
	content.add_child(desc_row)

	var desc_mark := Control.new()
	desc_mark.set_script(DiamondMarkerScript)
	desc_mark.custom_minimum_size = Vector2(15, 15)
	desc_mark.size = Vector2(15, 15)
	desc_row.add_child(desc_mark)

	var desc_col := VBoxContainer.new()
	desc_col.add_theme_constant_override("separation", 2)
	desc_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_row.add_child(desc_col)

	_desc_title = Label.new()
	_desc_title.add_theme_font_size_override("font_size", 23)
	_desc_title.add_theme_color_override("font_color", COLOR_BRIGHT)
	_outline(_desc_title, 4)
	desc_col.add_child(_desc_title)

	_desc_body = Label.new()
	_desc_body.add_theme_font_size_override("font_size", 19)
	_desc_body.add_theme_color_override("font_color", COLOR_DIM)
	_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_outline(_desc_body, 4)
	desc_col.add_child(_desc_body)

	# Распорка: подсказка держится сразу под списком настроек, а не улетает
	# в самый низ полноэкранной панели
	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tail)

	_populate_rows(_current_category)


func _populate_rows(category: String) -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	_header_lbl.text = category

	match category:
		"GENERAL":
			_add_toggle(_rows_box, "Camera Shake", GameSettings.shake_multiplier > 0.0,
				"Reduce or disable camera shake from hits, stagger, and exhaustion.",
				func(v: bool): GameSettings.shake_multiplier = 1.0 if v else 0.0)
		"GRAPHICS":
			_add_selector(_rows_box, "Display Mode", ["WINDOWED", "FULLSCREEN"],
				1 if GameSettings.fullscreen else 0,
				"Switch between windowed and fullscreen display.",
				func(i: int): GameSettings.fullscreen = (i == 1); GameSettings.apply_all())
			_add_toggle(_rows_box, "VSync", GameSettings.vsync,
				"Synchronize the frame rate with your monitor to reduce screen tearing.",
				func(v: bool): GameSettings.vsync = v; GameSettings.apply_all())
		"AUDIO":
			_add_slider(_rows_box, "Master Volume", GameSettings.master_volume,
				"Overall volume for all game audio.",
				func(v: float): GameSettings.master_volume = v; GameSettings.apply_all())
			_add_slider(_rows_box, "Music Volume", GameSettings.music_volume,
				"Volume of the background music and soundtrack.",
				func(v: float): GameSettings.music_volume = v; GameSettings.apply_all())
			# На ползунке эффектов даём послушать пример — иначе в меню его
			# крутишь вслепую, боевых звуков тут нет
			_add_slider(_rows_box, "SFX Volume", GameSettings.sfx_volume,
				"Volume of combat and interface sound effects.",
				func(v: float): GameSettings.sfx_volume = v; GameSettings.apply_all(),
				true)
		"CONTROLS":
			_add_placeholder(_rows_box, "Key Rebinding",
				"Control customization is planned for a future update.")
		"LANGUAGE":
			_add_placeholder(_rows_box, "English",
				"More languages are planned for a future update.")

	# Подсказка по умолчанию — первый пункт вкладки, до первого наведения
	if _rows_box.get_child_count() > 0:
		var first := _rows_box.get_child(0)
		if first.has_meta("desc_title"):
			_desc_title.text = first.get_meta("desc_title")
			_desc_body.text = first.get_meta("desc_body")
	else:
		_desc_title.text = ""
		_desc_body.text = ""


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


func _make_row(parent: Control, label_text: String, description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	# Название/описание пункта — читает подсказка внизу панели при наведении
	row.set_meta("desc_title", label_text)
	row.set_meta("desc_body", description)
	row.mouse_entered.connect(func():
		_desc_title.text = label_text
		_desc_body.text = description
	)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.custom_minimum_size = Vector2(330, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(lbl)
	row.add_child(lbl)
	return row


func _add_slider(parent: Control, label_text: String, value: float, description: String,
		on_change: Callable, preview_sound := false) -> void:
	var row := _make_row(parent, label_text, description)

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
	value_lbl.custom_minimum_size = Vector2(86, 0)
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


func _add_toggle(parent: Control, label_text: String, value: bool, description: String,
		on_change: Callable) -> void:
	var row := _make_row(parent, label_text, description)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var sw := Button.new()
	sw.set_script(ToggleSwitchScript)
	row.add_child(sw)
	# Выставляем начальное значение БЕЗ сигнала (set_pressed_no_signal), иначе
	# сразу же сработал бы toggled и лишний раз дёрнул on_change/звук на
	# каждую пересборку панели
	sw.set_pressed_no_signal(value)
	sw.call("sync")
	sw.toggled.connect(func(v: bool):
		_play(SOUND_CHOICE)
		on_change.call(v)
	)


func _add_selector(parent: Control, label_text: String, options: Array, current_index: int,
		description: String, on_change: Callable) -> void:
	var row := _make_row(parent, label_text, description)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var prev_btn := _make_arrow_button("<")
	row.add_child(prev_btn)

	var value_lbl := Label.new()
	value_lbl.add_theme_font_size_override("font_size", 25)
	value_lbl.add_theme_color_override("font_color", COLOR_BRIGHT)
	value_lbl.custom_minimum_size = Vector2(190, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(value_lbl)
	row.add_child(value_lbl)

	var next_btn := _make_arrow_button(">")
	row.add_child(next_btn)

	var idx := {"i": current_index}
	var refresh := func(): value_lbl.text = str(options[idx["i"]])
	refresh.call()

	prev_btn.pressed.connect(func():
		idx["i"] = (idx["i"] - 1 + options.size()) % options.size()
		refresh.call()
		_play(SOUND_CHOICE)
		on_change.call(idx["i"])
	)
	next_btn.pressed.connect(func():
		idx["i"] = (idx["i"] + 1) % options.size()
		refresh.call()
		_play(SOUND_CHOICE)
		on_change.call(idx["i"])
	)


func _add_placeholder(parent: Control, label_text: String, description: String) -> void:
	## Пункт-заглушка для вкладок без реальных настроек (CONTROLS/LANGUAGE) —
	## просто показывает текущее/единственное значение, без интерактива
	var row := _make_row(parent, label_text, description)
	var note := Label.new()
	note.text = "—"
	note.add_theme_font_size_override("font_size", 23)
	note.add_theme_color_override("font_color", COLOR_DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(note)
	row.add_child(note)


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


func _make_arrow_button(glyph: String) -> Button:
	var btn := _make_text_button(glyph, 26)
	btn.custom_minimum_size = Vector2(34, 0)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return btn


func _make_hint_button(label_text: String, on_press: Callable) -> Button:
	## Кнопка-подсказка внизу справа (RESET / BACK) — окантованный "чип",
	## а не обычная плоская кнопка, чтобы читаться как хоткей-плашка
	var btn := Button.new()
	btn.text = label_text
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
	_outline(btn, 4)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.09, 0.85)
	normal.border_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7

	var hover := normal.duplicate()
	hover.border_color = COLOR_BRIGHT

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus", normal)

	btn.pressed.connect(on_press)
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
