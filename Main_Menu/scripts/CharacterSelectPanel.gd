extends "res://Main_Menu/scripts/MenuPanel.gd"
## CharacterSelectPanel.gd — выбор персонажа при создании нового прохождения.
##
## Список героев берётся из реестра Characters, а не задан здесь: добавишь
## четвёртого в Characters.DATA/ORDER — он появится и в списке слева, и во
## всех панелях справа.
##
## Вёрстка: слева список классов, по центру анимация Idle_Down выбранного
## героя, справа описание со статами, дальше цитата и CONFIRM. Каркас
## MenuPanel (затемнение, наплыв, Esc) используем, а вот его _rebuild()
## переопределяем целиком — там панель с рамкой и заголовком по центру,
## а здесь нужен полноэкранный экран без рамки.
##
## Панель НИЧЕГО не сохраняет — только сообщает выбор сигналом. Слот заводит
## MainMenu.gd через SaveManager.create_slot(), и именно там character_id
## записывается в сейв один-единственный раз.

signal character_chosen(id: String)

const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")
const OrnamentSeparatorScript := preload("res://Main_Menu/scripts/OrnamentSeparator.gd")
# Скрипты подключаются через set_script, а не через class_name: глобальный
# кэш классов в этом проекте уже подводил (стыковка "Could not find type X"
# после правок), да и остальные вспомогательные ноды меню сделаны так же
const GlyphIconScript := preload("res://Main_Menu/scripts/GlyphIcon.gd")
const SpriteSheetAnimationScript := preload("res://Main_Menu/scripts/SpriteSheetAnimation.gd")

# Тот же шрифт, что у навигации: тема меню сюда не доходит — панель лежит под
# CanvasLayer, а он рвёт наследование темы (см. SettingsPanel.gd)
const MENU_FONT := preload("res://Font/sikandinarie.ttf")
# Арт в рамке справа — то же ключевое изображение, что и фон меню; отдельной
# картинки "региона" в проекте пока нет
const FRAME_ART := preload("res://Main_Menu/IMG_mainMenu.png")

const COLOR_DIVIDER := Color(0.55, 0.50, 0.40, 0.35)

const SIDEBAR_WIDTH := 330.0
const INFO_WIDTH := 520.0
const ASIDE_WIDTH := 400.0
const STAT_SEGMENTS := 14

var _selected_id := ""
var _hero_rows := {}   # id -> {"btn": Button, "marker": Control, "icon": GlyphIcon}
var _hints: Control

var _portrait: TextureRect
var _name_lbl: Label
var _desc_lbl: Label
var _stats_box: VBoxContainer
var _quote_lbl: Label


func _ready() -> void:
	# Экран полноэкранный и почти непрозрачный — затемнение под ним должно
	# быть плотнее, чем у всплывающих панелей, иначе сквозь него читается меню
	dim_alpha = 0.55
	panel_alpha = 0.9
	super._ready()


func open() -> void:
	# В отличие от прежних карточек тут всегда кто-то подсвечен: справа живут
	# описание, статы и цитата, и пустым этот блок показывать нечего. Первый
	# герой по умолчанию, подтверждает выбор кнопка CONFIRM
	_selected_id = Characters.ORDER[0]
	super.open()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not _is_open:
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_cycle_hero(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_cycle_hero(1)


# ----------------------------------------------------------
# ПОСТРОЕНИЕ UI
# ----------------------------------------------------------

func _rebuild() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	if is_instance_valid(_hints):
		_hints.queue_free()

	_panel = PanelContainer.new()
	# Именно ...and_offsets_preset: один set_anchors_preset оставил бы размер
	# нулевым, и панель схлопнулась бы в левый верхний угол (см. MenuPanel._ready)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, panel_alpha)
	_panel.add_theme_stylebox_override("panel", style)

	var panel_theme := Theme.new()
	panel_theme.default_font = MENU_FONT
	_panel.theme = panel_theme
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 44)
	# Снизу оставляем полосу под подсказки клавиш, они лежат отдельно
	margin.add_theme_constant_override("margin_bottom", 96)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	margin.add_child(row)

	_build_sidebar(row)
	_build_divider(row)
	_build_portrait(row)
	_build_divider(row)
	_build_info(row)
	_build_aside(row)

	_build_hints()
	_refresh_selection()


# --- Слева: заголовок и список классов ------------------------------------

func _build_sidebar(parent: Control) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0)
	sidebar.add_theme_constant_override("separation", 2)
	parent.add_child(sidebar)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	sidebar.add_child(title_row)

	var mark := Control.new()
	mark.set_script(DiamondMarkerScript)
	mark.custom_minimum_size = Vector2(22, 22)
	title_row.add_child(mark)

	var title := _make_label("SELECT HERO", 42, COLOR_BRIGHT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)

	_add_rule(sidebar, 22)

	_hero_rows.clear()
	for id in Characters.ORDER:
		sidebar.add_child(_make_hero_row(id))


func _make_hero_row(id: String) -> Button:
	var btn := Button.new()
	btn.text = Characters.display_name(id)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_hover_color", COLOR_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
	_outline(btn)

	# Пустой стиль с отступом слева: место под ромбик и иконку класса, они
	# лежат отдельными нодами поверх кнопки (Button — не контейнер, детей он
	# сам не раскладывает, поэтому они заанкорены вручную)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 96
	empty.content_margin_top = 10
	empty.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)

	var marker := Control.new()
	marker.set_script(DiamondMarkerScript)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.modulate.a = 0.0
	_pin_left(marker, 2.0, 18.0)
	btn.add_child(marker)

	var icon := Control.new()
	icon.set_script(GlyphIconScript)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.call("set_glyph",
		Characters.get_data(id).get("icon", "rune"), Characters.get_color(id))
	_pin_left(icon, 40.0, 34.0)
	btn.add_child(icon)

	btn.pressed.connect(func():
		if _selected_id == id:
			return
		_selected_id = id
		_play(SOUND_CHOICE)
		_refresh_selection()
	)

	_hero_rows[id] = {"btn": btn, "marker": marker, "icon": icon}
	return btn


## Прижимает ноду к левому краю кнопки по центру высоты — так она не зависит
## от того, когда контейнер выставит кнопке финальный размер
func _pin_left(node: Control, offset_x: float, box: float) -> void:
	node.anchor_left = 0.0
	node.anchor_right = 0.0
	node.anchor_top = 0.5
	node.anchor_bottom = 0.5
	node.offset_left = offset_x
	node.offset_right = offset_x + box
	node.offset_top = -box / 2.0
	node.offset_bottom = box / 2.0


func _build_divider(parent: Control) -> void:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 28)
	wrap.add_theme_constant_override("margin_right", 28)
	parent.add_child(wrap)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1.5, 0)
	line.color = COLOR_DIVIDER
	wrap.add_child(line)


# --- По центру: анимация Idle_Down выбранного героя ------------------------

func _build_portrait(parent: Control) -> void:
	# Обычный Control, а не контейнер: подложка и спрайт должны лежать друг
	# на друге, а контейнер растащил бы их по своей раскладке
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stage)

	var glow := TextureRect.new()
	glow.texture = _make_stage_gradient()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(glow)

	_portrait = TextureRect.new()
	_portrait.set_script(SpriteSheetAnimationScript)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_portrait)


func _make_stage_gradient() -> GradientTexture2D:
	## Вертикальный "столб света" за героем: сверху чуть теплее, к низу уходит
	## в прозрачность, чтобы спрайт не висел в пустоте
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([
		Color(0.16, 0.13, 0.09, 0.0),
		Color(0.16, 0.13, 0.09, 0.45),
		Color(0.05, 0.04, 0.03, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 256
	return tex


# --- Справа: имя, описание, статы -----------------------------------------

func _build_info(parent: Control) -> void:
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(INFO_WIDTH, 0)
	info.add_theme_constant_override("separation", 8)
	parent.add_child(info)

	_name_lbl = _make_label("", 54, COLOR_BRIGHT)
	info.add_child(_name_lbl)

	var sep := Control.new()
	sep.set_script(OrnamentSeparatorScript)
	sep.custom_minimum_size = Vector2(0, 20)
	info.add_child(sep)

	_desc_lbl = _make_label("", 25, COLOR_TEXT)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_desc_lbl)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	info.add_child(gap)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 14)
	info.add_child(_stats_box)

	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(tail)


func _fill_stats(id: String) -> void:
	for c in _stats_box.get_children():
		c.queue_free()

	for stat in Characters.STAT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_stats_box.add_child(row)

		var icon := Control.new()
		icon.set_script(GlyphIconScript)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.call("set_glyph", Characters.STAT_ICONS.get(stat, "rune"), COLOR_ACCENT)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

		var lbl := _make_label(stat, 25, COLOR_TEXT)
		lbl.custom_minimum_size = Vector2(195, 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

		row.add_child(_make_stat_bar(Characters.get_stat(id, stat)))


func _make_stat_bar(value: float) -> Control:
	## Полоска набрана из сегментов, а не сплошная — так читается "сколько из
	## скольких", как на референсе
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var filled := int(round(clampf(value, 0.0, 1.0) * STAT_SEGMENTS))
	for i in STAT_SEGMENTS:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(13, 11)
		seg.color = COLOR_ACCENT if i < filled else Color(0.18, 0.16, 0.14, 0.9)
		bar.add_child(seg)
	return bar


# --- Крайняя правая колонка: арт, цитата, CONFIRM -------------------------

func _build_aside(parent: Control) -> void:
	var aside := VBoxContainer.new()
	aside.custom_minimum_size = Vector2(ASIDE_WIDTH, 0)
	aside.add_theme_constant_override("separation", 22)
	parent.add_child(aside)

	var art_frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.06, 0.05, 0.04, 0.9)
	frame_style.border_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.55)
	frame_style.set_border_width_all(1)
	frame_style.set_content_margin_all(5)
	art_frame.add_theme_stylebox_override("panel", frame_style)
	aside.add_child(art_frame)

	var art := TextureRect.new()
	art.texture = FRAME_ART
	art.custom_minimum_size = Vector2(0, 200)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art)

	_quote_lbl = _make_label("", 24, COLOR_DIM)
	_quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aside.add_child(_quote_lbl)

	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aside.add_child(tail)

	aside.add_child(_make_confirm_button())


func _make_confirm_button() -> Control:
	# Двойная рамка: внешний контейнер даёт тонкий контур, внутри — сама
	# кнопка со своей рамкой. Одним StyleBox такого канта не собрать
	var outer := PanelContainer.new()
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color(0, 0, 0, 0)
	outer_style.border_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.45)
	outer_style.set_border_width_all(1)
	outer_style.set_content_margin_all(5)
	outer.add_theme_stylebox_override("panel", outer_style)

	var btn := Button.new()
	btn.text = "CONFIRM"
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", COLOR_BRIGHT)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.82))
	btn.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
	_outline(btn)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.09, 0.06, 0.9)
	normal.border_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.85)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(14)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.14, 0.08, 0.95)
	hover.border_color = COLOR_BRIGHT

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus", normal)

	btn.pressed.connect(_on_confirm)
	outer.add_child(btn)
	return outer


# --- Подсказки клавиш по нижним углам экрана ------------------------------

func _build_hints() -> void:
	_hints = Control.new()
	_hints.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hints_theme := Theme.new()
	hints_theme.default_font = MENU_FONT
	_hints.theme = hints_theme
	add_child(_hints)

	var back := HBoxContainer.new()
	back.add_theme_constant_override("separation", 12)
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 56.0
	back.offset_top = -82.0
	back.offset_right = 400.0
	back.offset_bottom = -26.0
	_hints.add_child(back)

	back.add_child(_make_key_chip("ESC"))
	var back_btn := _make_text_button("BACK", 25)
	back_btn.pressed.connect(func(): _play(SOUND_CHOICE); close())
	back.add_child(back_btn)

	var change := HBoxContainer.new()
	change.add_theme_constant_override("separation", 10)
	change.alignment = BoxContainer.ALIGNMENT_END
	change.anchor_left = 1.0
	change.anchor_top = 1.0
	change.anchor_right = 1.0
	change.anchor_bottom = 1.0
	change.offset_left = -470.0
	change.offset_top = -82.0
	change.offset_right = -56.0
	change.offset_bottom = -26.0
	_hints.add_child(change)

	change.add_child(_make_key_chip("<"))
	change.add_child(_make_key_chip(">"))
	var change_lbl := _make_label("CHANGE CLASS", 25, COLOR_TEXT)
	change_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	change.add_child(change_lbl)


func _make_key_chip(key: String) -> Control:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.09, 0.9)
	style.border_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)

	var lbl := _make_label(key, 21, COLOR_BRIGHT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	return box


# ----------------------------------------------------------
# ВЫБОР
# ----------------------------------------------------------

func _cycle_hero(step: int) -> void:
	var order := Characters.ORDER
	var idx := order.find(_selected_id)
	if idx == -1:
		idx = 0
	_selected_id = order[(idx + step + order.size()) % order.size()]
	_play(SOUND_CHOICE)
	_refresh_selection()


func _refresh_selection() -> void:
	var data := Characters.get_data(_selected_id)
	var accent := Characters.get_color(_selected_id)

	for id in _hero_rows:
		var parts: Dictionary = _hero_rows[id]
		var active: bool = id == _selected_id
		parts["btn"].add_theme_color_override(
			"font_color", Characters.get_color(id) if active else COLOR_TEXT)
		parts["marker"].modulate.a = 1.0 if active else 0.0
		parts["icon"].modulate.a = 1.0 if active else 0.55

	if is_instance_valid(_portrait):
		var region := Characters.get_idle_region(_selected_id)
		_portrait.call("setup",
			Characters.get_idle_sheet(_selected_id),
			region.position.y, region.size,
			Characters.get_idle_frame_time(_selected_id))

	if is_instance_valid(_name_lbl):
		_name_lbl.text = data.get("name", "?")
		_name_lbl.add_theme_color_override("font_color", accent)
		_desc_lbl.text = data.get("description", "")
		_quote_lbl.text = "\"%s\"" % data.get("quote", "")
		_fill_stats(_selected_id)


func _on_confirm() -> void:
	if _selected_id == "":
		_play(SOUND_DENIED)
		return
	_play(SOUND_ACCEPT)
	character_chosen.emit(_selected_id)
