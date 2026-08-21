# res://ui/inventory_ui.gd
extends CanvasLayer

signal closed

const COLOR_BG          = Color(0.04, 0.03, 0.02, 0.97)
const COLOR_PANEL       = Color(0.08, 0.06, 0.04, 1.0)
const COLOR_SLOT_EMPTY  = Color(0.11, 0.09, 0.06, 1.0)
const COLOR_SLOT_HOVER  = Color(0.20, 0.15, 0.09, 1.0)
const COLOR_SLOT_SEL    = Color(0.22, 0.16, 0.08, 1.0)
const COLOR_BORDER      = Color(0.45, 0.35, 0.15, 1.0)
const COLOR_BORDER_HI   = Color(0.80, 0.62, 0.22, 1.0)
const COLOR_TEXT        = Color(0.92, 0.84, 0.66, 1.0)
const COLOR_TEXT_DIM    = Color(0.52, 0.47, 0.36, 1.0)
const COLOR_TEXT_GOLD   = Color(0.98, 0.78, 0.28, 1.0)
const COLOR_DIVIDER     = Color(0.40, 0.30, 0.12, 0.7)

const COLOR_WARN        = Color(0.85, 0.35, 0.20, 1.0)

const GRID_COLS := 3
const GRID_ROWS := 4

# Настройки — та же панель, что и в главном меню, а не её копия: значения живут
# в автозагрузке GameSettings, и второй реализации взяться неоткуда
const SettingsPanelScript := preload("res://Main_Menu/scripts/SettingsPanel.gd")

# ─── UI-ЗВУКИ ──────────────────────────────────────────────────────────────────
const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_OPEN := preload("res://Sound/openUI_sound.mp3")
var _ui_audio: AudioStreamPlayer

func _play_ui_sound(stream: AudioStream) -> void:
	_ui_audio.stream = stream
	_ui_audio.play()

var _ability_system: AbilitySystem
var _inventory_system: InventorySystem

var _root: Control
var _grid_slots: Array[Control] = []
var _selected_index: int = -1

# Оверлеи поверх инвентаря (настройки / навыки). Пока хоть один открыт, Esc
# закрывает его, а не весь инвентарь
var _settings_panel: Control
var _skills_panel: Control
var _is_closing := false

var _detail_icon: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_count: Label
var _detail_max_count: Label
var _detail_desc: Label
var _detail_effect: Label
var _btn_equip: Button
var _quick_slot_preview: Control
var _quick_slot_header: Label
var _quick_slot_status: Label

var _screen: Vector2
var _panel_w: float
var _panel_h: float
var _slot_size: Vector2
var _slot_gap: float
var _grid_x: float
var _grid_y: float
var _detail_x: float
var _detail_w: float


func _ready() -> void:
	visible = false
	# продолжаем работать во время паузы, чтобы инвентарь оставался интерактивным
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_audio = AudioStreamPlayer.new()
	add_child(_ui_audio)


func init(ability_system: AbilitySystem, inventory_system: InventorySystem) -> void:
	_ability_system = ability_system
	_inventory_system = inventory_system
	# Заряды списывает быстрый слот, а лежат они в сумке — связываем одно с другим
	_ability_system.inventory = inventory_system
	_inventory_system.count_changed.connect(_on_count_changed)
	_build_ui()


func open() -> void:
	if visible:
		return
	# ставим игру на паузу — враги останавливаются и не бьют игрока
	get_tree().paused = true
	_is_closing = false
	_play_ui_sound(SOUND_OPEN)
	visible = true
	_refresh_grid()
	_root.modulate = Color(1, 1, 1, 0)
	_root.scale = Vector2(0.96, 0.96)
	_root.pivot_offset = _screen / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(_root, "modulate", Color.WHITE, 0.18)
	tw.tween_property(_root, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func close() -> void:
	# Esc может прилететь дважды (пока идёт твин закрытия) — без флага мир
	# снимался бы с паузы повторно и сигнал closed летел бы два раза
	if _is_closing or not visible:
		return
	_is_closing = true
	_play_ui_sound(SOUND_OPEN)
	_root.pivot_offset = _screen / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(_root, "modulate", Color(1, 1, 1, 0), 0.14)
	tw.tween_property(_root, "scale", Vector2(0.96, 0.96), 0.14)
	await tw.finished
	visible = false
	_is_closing = false
	# снимаем паузу — мир снова оживает
	get_tree().paused = false
	emit_signal("closed")


func add_item(ability: Ability) -> void:
	# Стаки и счётчики целиком на стороне InventorySystem — UI только рисует
	if _inventory_system == null:
		push_warning("[Инвентарь] add_item до init() — предмет потерян: %s" % ability.ability_name)
		return
	_inventory_system.add_item(ability)
	if visible:
		_refresh_grid()


## Открыт ли поверх инвентаря какой-то подраздел — по этому же признаку player.gd
## понимает, что Esc сейчас не его
func has_overlay_open() -> bool:
	if is_instance_valid(_skills_panel) and _skills_panel.visible:
		return true
	if is_instance_valid(_settings_panel) and _settings_panel.visible:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		# Помечаем ввод обработанным, чтобы player.gd не закрыл инвентарь вторым
		# обработчиком того же нажатия
		get_viewport().set_input_as_handled()
		# Панель настроек гасит Esc сама (у неё свой _unhandled_input и она в
		# дереве ниже), сюда событие доходит только когда её нет
		if is_instance_valid(_skills_panel) and _skills_panel.visible:
			_close_skills()
			return
		close()
		return

	# E работает на весь экран инвентаря, а не только по сфокусированной ячейке:
	# у слотов gui_input срабатывает лишь при фокусе, поэтому подсказка "[E] в
	# слот" без этого обработчика была бы враньём
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if has_overlay_open():
			return
		get_viewport().set_input_as_handled()
		_on_equip_pressed()


# ─────────────────────────────────────────────
# BUILD UI
# ─────────────────────────────────────────────

func _build_ui() -> void:
	_screen = get_viewport().get_visible_rect().size

	var margin  := 30.0
	_panel_w    = _screen.x - margin * 2.0
	_panel_h    = _screen.y - margin * 2.0

	var grid_area_w := _panel_w * 0.36
	_slot_size = Vector2(
		(grid_area_w - 60.0) / GRID_COLS,
		(grid_area_w - 60.0) / GRID_COLS
	)
	_slot_gap  = 12.0
	_grid_x    = 36.0
	_grid_y    = 90.0

	_detail_x  = _grid_x + GRID_COLS * (_slot_size.x + _slot_gap) + 36.0
	_detail_w  = _panel_w - _detail_x - 36.0

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var custom_font := load("res://Font/sikandinarie.ttf") as Font
	if custom_font:
		var font_theme := Theme.new()
		font_theme.default_font = custom_font
		_root.theme = font_theme
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	_root.add_child(bg)
	_root.add_child(_make_rune_pattern())

	var panel := _make_panel(Vector2(margin, margin), Vector2(_panel_w, _panel_h))
	_root.add_child(panel)

	var title := _make_label("СНАРЯЖЕНИЕ", 28)
	title.position = Vector2(36, 18)
	title.add_theme_color_override("font_color", COLOR_BORDER_HI)
	panel.add_child(title)

	_build_top_bar(panel)
	_add_divider(panel, Vector2(20, 62), _panel_w - 40.0)

	var vdiv := ColorRect.new()
	vdiv.position = Vector2(_detail_x - 20.0, 70.0)
	vdiv.size = Vector2(1, _panel_h - 140.0)
	vdiv.color = COLOR_DIVIDER
	panel.add_child(vdiv)

	_build_grid(panel)
	_build_detail_panel(panel)
	_build_quick_slot_bar(panel)
	_build_hints(panel)


# Кнопки разделов в шапке инвентаря — справа от заголовка, над разделителем.
# Порядок справа налево: сначала "Настройки" (край панели), левее "Навыки"
func _build_top_bar(parent: Control) -> void:
	var btn_w := 150.0
	var btn_h := 34.0
	var gap := 10.0
	var y := 16.0
	var x := _panel_w - 36.0 - btn_w

	var btn_settings := _make_button("НАСТРОЙКИ", Vector2(x, y), Vector2(btn_w, btn_h))
	btn_settings.add_theme_font_size_override("font_size", 13)
	btn_settings.pressed.connect(_open_settings)
	parent.add_child(btn_settings)

	x -= btn_w + gap
	var btn_skills := _make_button("НАВЫКИ", Vector2(x, y), Vector2(btn_w, btn_h))
	btn_skills.add_theme_font_size_override("font_size", 13)
	btn_skills.pressed.connect(_open_skills)
	parent.add_child(btn_skills)


func _build_grid(parent: Control) -> void:
	var hdr := _make_label("ИНВЕНТАРЬ", 13)
	hdr.position = Vector2(_grid_x, 68.0)
	hdr.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(hdr)

	for row in GRID_ROWS:
		for col in GRID_COLS:
			var idx := row * GRID_COLS + col
			var pos := Vector2(
				_grid_x + col * (_slot_size.x + _slot_gap),
				_grid_y + row * (_slot_size.y + _slot_gap)
			)
			var slot := _build_slot(idx, pos)
			parent.add_child(slot)
			_grid_slots.append(slot)


func _build_slot(idx: int, pos: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = _slot_size

	var bg := ColorRect.new()
	bg.size = _slot_size
	bg.color = COLOR_SLOT_EMPTY
	c.add_child(bg)

	for side in ["t", "b", "l", "r"]:
		var line := ColorRect.new()
		line.color = COLOR_BORDER
		match side:
			"t": line.position = Vector2(0, 0);                    line.size = Vector2(_slot_size.x, 1)
			"b": line.position = Vector2(0, _slot_size.y - 1);     line.size = Vector2(_slot_size.x, 1)
			"l": line.position = Vector2(0, 0);                    line.size = Vector2(1, _slot_size.y)
			"r": line.position = Vector2(_slot_size.x - 1, 0);     line.size = Vector2(1, _slot_size.y)
		c.add_child(line)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(8, 8)
	icon.size = Vector2(_slot_size.x - 16, _slot_size.y - 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.add_child(icon)

	var lbl := Label.new()
	lbl.name = "Name"
	lbl.position = Vector2(4, _slot_size.y - 22)
	lbl.size = Vector2(_slot_size.x - 30, 20)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	lbl.clip_text = true
	c.add_child(lbl)

	var cnt := Label.new()
	cnt.name = "Count"
	cnt.position = Vector2(_slot_size.x - 28, _slot_size.y - 22)
	cnt.size = Vector2(26, 20)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 13)
	cnt.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	c.add_child(cnt)

	var sel := Control.new()
	sel.name = "SelectionBorder"
	sel.position = Vector2(-2, -2)
	sel.size = _slot_size + Vector2(4, 4)
	sel.visible = false
	for side in ["t", "b", "l", "r"]:
		var line := ColorRect.new()
		line.color = COLOR_BORDER_HI
		match side:
			"t": line.position = Vector2(0, 0);                          line.size = Vector2(_slot_size.x + 4, 2)
			"b": line.position = Vector2(0, _slot_size.y + 2);           line.size = Vector2(_slot_size.x + 4, 2)
			"l": line.position = Vector2(0, 0);                          line.size = Vector2(2, _slot_size.y + 4)
			"r": line.position = Vector2(_slot_size.x + 2, 0);           line.size = Vector2(2, _slot_size.y + 4)
		sel.add_child(line)
	c.add_child(sel)

	var area := Control.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(func(ev): _on_slot_input(ev, idx))
	area.mouse_entered.connect(func(): _on_slot_hover(idx, true))
	area.mouse_exited.connect(func(): _on_slot_hover(idx, false))
	c.add_child(area)

	return c


func _build_detail_panel(parent: Control) -> void:
	var x  := _detail_x
	var w  := _detail_w
	var y  := 70.0

	var icon_size := minf(w * 0.42, _panel_h * 0.38)
	var icon_x    := x + w - icon_size

	var iborder := ColorRect.new()
	iborder.position = Vector2(icon_x - 3, y - 3)
	iborder.size = Vector2(icon_size + 6, icon_size + 6)
	iborder.color = COLOR_BORDER_HI
	parent.add_child(iborder)

	var ibg := ColorRect.new()
	ibg.position = Vector2(icon_x, y)
	ibg.size = Vector2(icon_size, icon_size)
	ibg.color = Color(0.06, 0.05, 0.03, 1.0)
	parent.add_child(ibg)

	_detail_icon = TextureRect.new()
	_detail_icon.position = Vector2(icon_x + 10, y + 10)
	_detail_icon.size = Vector2(icon_size - 20, icon_size - 20)
	_detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST 
	parent.add_child(_detail_icon)

	var tw := w - icon_size - 28.0

	_detail_name = _make_label("", 26)
	_detail_name.position = Vector2(x, y)
	_detail_name.size = Vector2(tw, 38)
	_detail_name.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(_detail_name)
	y += 42.0

	_detail_type = _make_label("", 14)
	_detail_type.position = Vector2(x, y)
	_detail_type.size = Vector2(tw, 22)
	_detail_type.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(_detail_type)
	y += 30.0

	_add_divider(parent, Vector2(x, y), tw)
	y += 14.0

	var lbl_carried := _make_label("При себе", 14)
	lbl_carried.position = Vector2(x, y)
	parent.add_child(lbl_carried)

	_detail_count = _make_label("", 14)
	_detail_count.position = Vector2(x, y)
	_detail_count.size = Vector2(tw, 22)
	_detail_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_count.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(_detail_count)
	y += 26.0

	var lbl_max := _make_label("Макс. за сессию", 14)
	lbl_max.position = Vector2(x, y)
	parent.add_child(lbl_max)

	_detail_max_count = _make_label("", 14)
	_detail_max_count.position = Vector2(x, y)
	_detail_max_count.size = Vector2(tw, 22)
	_detail_max_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_max_count.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	parent.add_child(_detail_max_count)
	y += 32.0

	_add_divider(parent, Vector2(x, y), tw)
	y += 16.0

	_detail_desc = _make_label("", 14)
	_detail_desc.position = Vector2(x, y)
	_detail_desc.size = Vector2(tw, 120)
	_detail_desc.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_detail_desc)
	y += 130.0

	_add_divider(parent, Vector2(x, y), tw)
	y += 14.0

	var eff_hdr := _make_label("Эффект", 13)
	eff_hdr.position = Vector2(x, y)
	eff_hdr.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(eff_hdr)
	y += 22.0

	_detail_effect = _make_label("", 15)
	_detail_effect.position = Vector2(x, y)
	_detail_effect.size = Vector2(tw, 60)
	_detail_effect.add_theme_color_override("font_color", COLOR_TEXT)
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_detail_effect)

	_btn_equip = _make_button(
		"[ E ]  В БЫСТРЫЙ ДОСТУП",
		Vector2(x, _panel_h - 100.0),
		Vector2(w, 48.0)
	)
	_btn_equip.pressed.connect(_on_equip_pressed)
	_btn_equip.disabled = true
	parent.add_child(_btn_equip)


func _build_quick_slot_bar(parent: Control) -> void:
	var y := _panel_h - 52.0
	_quick_slot_header = _make_label("БЫСТРЫЙ ДОСТУП", 12)
	_quick_slot_header.position = Vector2(_grid_x, y)
	_quick_slot_header.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(_quick_slot_header)

	_quick_slot_preview = Control.new()
	_quick_slot_preview.position = Vector2(_grid_x, y + 18.0)
	_quick_slot_preview.size = Vector2(GRID_COLS * (_slot_size.x + _slot_gap), 30.0)
	parent.add_child(_quick_slot_preview)

	# Строка обратной связи под кнопкой экипировки: "слоты заняты", "предмет
	# кончился" и т.п. Без неё отказ добавить четвёртый предмет был бы слышен
	# (звук denied), но не виден
	_quick_slot_status = _make_label("", 13)
	_quick_slot_status.position = Vector2(_detail_x, _panel_h - 46.0)
	_quick_slot_status.size = Vector2(_detail_w, 20)
	_quick_slot_status.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(_quick_slot_status)

	_refresh_quick_slot_preview()


func _build_hints(parent: Control) -> void:
	var hints := [["ESC", "Закрыть"], ["ЛКМ", "Выбрать"], ["E", "В слот / из слота"]]
	var x := _panel_w - 20.0
	var y := _panel_h - 16.0
	for h in hints:
		var txt := "[%s]  %s" % [h[0], h[1]]
		var lbl := _make_label(txt, 11)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		lbl.size = Vector2(200, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		x -= 210.0
		lbl.position = Vector2(x, y)
		parent.add_child(lbl)


# ─────────────────────────────────────────────
# LOGIC
# ─────────────────────────────────────────────

func _refresh_grid() -> void:
	var items := _inventory_system.get_all()
	for i in _grid_slots.size():
		var slot    := _grid_slots[i]
		var icon    := slot.get_node("Icon") as TextureRect
		var name_l  := slot.get_node("Name") as Label
		var count_l := slot.get_node("Count") as Label
		var sel     := slot.get_node("SelectionBorder") as Control
		var bg      := slot.get_child(0) as ColorRect

		if i < items.size():
			var ab      := items[i] as Ability
			icon.texture = ab.icon
			name_l.text  = ab.ability_name
			var cnt := _inventory_system.get_count(ab.ability_name)
			count_l.text = "x%d" % cnt
			# Последний заряд подсвечиваем красным: предмет вот-вот исчезнет из
			# сумки, и это должно быть видно ещё до того, как игрок его потратит
			count_l.add_theme_color_override(
				"font_color", COLOR_WARN if cnt <= 1 else COLOR_TEXT_GOLD)
		else:
			icon.texture  = null
			name_l.text   = ""
			count_l.text  = ""

		sel.visible = i == _selected_index
		bg.color    = COLOR_SLOT_SEL if i == _selected_index else COLOR_SLOT_EMPTY

	_refresh_quick_slot_preview()


func _refresh_quick_slot_preview() -> void:
	if not is_instance_valid(_quick_slot_preview):
		return
	for ch in _quick_slot_preview.get_children():
		ch.queue_free()
	if _ability_system == null:
		return

	var used := _ability_system.abilities.size()
	if is_instance_valid(_quick_slot_header):
		_quick_slot_header.text = "БЫСТРЫЙ ДОСТУП   %d / %d" % [used, AbilitySystem.MAX_SLOTS]

	var ss := Vector2(28, 28)
	# Рисуем ВСЕ три ячейки, включая пустые — так видно, сколько места осталось,
	# а не только то, что уже занято
	for i in AbilitySystem.MAX_SLOTS:
		var bx := i * (ss.x + 4.0)
		var bg := ColorRect.new()
		bg.position = Vector2(bx, 0)
		bg.size = ss
		bg.color = COLOR_SLOT_EMPTY
		_quick_slot_preview.add_child(bg)

	for i in used:
		var ab := _ability_system.abilities[i]
		var bx := i * (ss.x + 4.0)

		if ab.icon:
			var ic := TextureRect.new()
			ic.position = Vector2(bx + 3, 3)
			ic.size = Vector2(ss.x - 6, ss.y - 6)
			ic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture = ab.icon
			_quick_slot_preview.add_child(ic)

		if i == _ability_system.current_index:
			for side in ["t", "b", "l", "r"]:
				var line := ColorRect.new()
				line.color = COLOR_BORDER_HI
				match side:
					"t": line.position = Vector2(bx - 1, -1);        line.size = Vector2(ss.x + 2, 2)
					"b": line.position = Vector2(bx - 1, ss.y - 1);  line.size = Vector2(ss.x + 2, 2)
					"l": line.position = Vector2(bx - 1, -1);        line.size = Vector2(2, ss.y + 2)
					"r": line.position = Vector2(bx + ss.x - 1, -1); line.size = Vector2(2, ss.y + 2)
				_quick_slot_preview.add_child(line)


# play_sound=false — для перерисовки после действия (экипировка, трата заряда):
# карточка справа пересобирается тем же кодом, но щелчок выбора звучать не должен
func _select_slot(idx: int, play_sound := true) -> void:
	var items := _inventory_system.get_all()
	_selected_index = idx

	if idx >= 0 and idx < items.size():
		if play_sound:
			_play_ui_sound(SOUND_CHOICE)
		var ab       := items[idx] as Ability
		var cnt      := _inventory_system.get_count(ab.ability_name)
		var max_cnt  := _get_max_count(ab.ability_name)
		var equipped := _ability_system.has_ability(ab.ability_name)

		_detail_icon.texture   = ab.icon
		_detail_name.text      = ab.ability_name
		_detail_type.text      = "Расходуемое  •  в слоте" if equipped else "Расходуемое"
		_detail_desc.text      = ab.description
		_detail_effect.text    = ab.description
		_detail_count.text     = "%d / %d" % [cnt, max_cnt]
		_detail_max_count.text = "%d" % max_cnt
		# Кнопка работает как переключатель: повторное нажатие на предмет,
		# который уже в быстром доступе, освобождает слот. Без этого при трёх
		# занятых ячейках поменять набор было бы нечем
		_btn_equip.text     = "[ E ]  УБРАТЬ ИЗ СЛОТА" if equipped else "[ E ]  В БЫСТРЫЙ ДОСТУП"
		_btn_equip.disabled = false
		_set_status("")
	else:
		_detail_icon.texture   = null
		_detail_name.text      = ""
		_detail_type.text      = ""
		_detail_desc.text      = ""
		_detail_effect.text    = ""
		_detail_count.text     = ""
		_detail_max_count.text = ""
		_btn_equip.text        = "[ E ]  В БЫСТРЫЙ ДОСТУП"
		_btn_equip.disabled    = true

	_refresh_grid()


func _get_max_count(ability_name: String) -> int:
	match ability_name:
		"Мёд Поэзии":        return 5
		"Песнь Валькирии":   return 3
		"Эликсир Вальгаллы": return 3
		_:                   return 1


func _on_slot_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_slot(idx)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_equip_pressed()


func _on_slot_hover(idx: int, entered: bool) -> void:
	if idx == _selected_index:
		return
	var items := _inventory_system.get_all()
	if idx >= items.size():
		return
	var bg := _grid_slots[idx].get_child(0) as ColorRect
	bg.color = COLOR_SLOT_HOVER if entered else COLOR_SLOT_EMPTY


func _on_equip_pressed() -> void:
	var items := _inventory_system.get_all()
	if _selected_index < 0 or _selected_index >= items.size():
		return
	var ab: Ability = items[_selected_index] as Ability

	# Уже в слоте — снимаем (переключатель), освобождая место под другой предмет
	var slot := _ability_system.find_slot(ab.ability_name)
	if slot != -1:
		_ability_system.remove_ability(slot)
		_play_ui_sound(SOUND_CHOICE)
		# Перерисовку делаем ДО статуса: _select_slot чистит строку сообщения
		_select_slot(_selected_index, false)
		_set_status("Убрано из быстрого доступа: %s" % ab.ability_name, COLOR_TEXT_DIM)
		return

	if _ability_system.is_full():
		_play_ui_sound(SOUND_DENIED)
		_set_status("Быстрый доступ заполнен (%d/%d) — сначала уберите предмет"
			% [_ability_system.abilities.size(), AbilitySystem.MAX_SLOTS], COLOR_WARN)
		return

	if not _inventory_system.has_charges(ab.ability_name):
		_play_ui_sound(SOUND_DENIED)
		_set_status("Предмет закончился", COLOR_WARN)
		return

	_ability_system.add_ability(ab)
	_play_ui_sound(SOUND_ACCEPT)
	_select_slot(_selected_index, false)
	_set_status("В быстром доступе: %s" % ab.ability_name, COLOR_TEXT_GOLD)


func _set_status(text: String, color := COLOR_TEXT_DIM) -> void:
	if not is_instance_valid(_quick_slot_status):
		return
	_quick_slot_status.text = text
	_quick_slot_status.add_theme_color_override("font_color", color)


# Заряды могли измениться, пока инвентарь открыт (нельзя — игра на паузе) или
# закрыт (обычный случай: применили способность в бою). Перерисовываем только
# когда окно на экране — иначе это лишняя работа каждый раз
func _on_count_changed(_item_name: String, _count: int) -> void:
	if visible:
		# Через _select_slot, а не просто _refresh_grid: если предмет кончился и
		# выпал из сумки, карточка справа обязана перестроиться под новый список
		_select_slot(_selected_index, false)


# ─────────────────────────────────────────────
# РАЗДЕЛЫ: НАСТРОЙКИ / НАВЫКИ
# ─────────────────────────────────────────────

func _open_settings() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	if not is_instance_valid(_settings_panel):
		# Панель из главного меню создаётся скриптом, без .tscn — поэтому new()
		# по самому скрипту, а не instantiate() по сцене
		_settings_panel = SettingsPanelScript.new()
		_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Добавляем в _root последним — значит, рисуется поверх всей вёрстки
		# инвентаря и перехватывает клики по ней
		_root.add_child(_settings_panel)
	_settings_panel.open()


func _open_skills() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	if not is_instance_valid(_skills_panel):
		_skills_panel = _build_skills_panel()
		_root.add_child(_skills_panel)
	_skills_panel.visible = true
	_skills_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_skills_panel, "modulate", Color.WHITE, 0.18)


func _close_skills() -> void:
	if not is_instance_valid(_skills_panel):
		return
	_play_ui_sound(SOUND_OPEN)
	_skills_panel.visible = false


# Пока это только каркас раздела: сетки навыков и прокачки ещё нет, но место под
# неё уже занято — чтобы кнопка в шапке вела в настоящий экран, а не в пустоту
func _build_skills_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.02, 0.72)
	root.add_child(dim)

	var pw := _panel_w * 0.7
	var ph := _panel_h * 0.7
	var panel := _make_panel(
		Vector2((_screen.x - pw) / 2.0, (_screen.y - ph) / 2.0), Vector2(pw, ph))
	root.add_child(panel)

	var title := _make_label("НАВЫКИ", 30)
	title.position = Vector2(32, 22)
	title.add_theme_color_override("font_color", COLOR_BORDER_HI)
	panel.add_child(title)

	_add_divider(panel, Vector2(20, 68), pw - 40.0)

	var stub := _make_label("Раздел в разработке", 18)
	stub.position = Vector2(0, ph / 2.0 - 20.0)
	stub.size = Vector2(pw, 26)
	stub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	panel.add_child(stub)

	var hint := _make_label("Здесь появится древо навыков", 13)
	hint.position = Vector2(0, ph / 2.0 + 12.0)
	hint.size = Vector2(pw, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	panel.add_child(hint)

	var back := _make_button("[ ESC ]  НАЗАД", Vector2((pw - 220.0) / 2.0, ph - 76.0), Vector2(220, 44))
	back.pressed.connect(_close_skills)
	panel.add_child(back)

	return root


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func _add_divider(parent: Control, pos: Vector2, width: float) -> void:
	var d := ColorRect.new()
	d.position = pos
	d.size = Vector2(width, 1)
	d.color = COLOR_DIVIDER
	parent.add_child(d)


func _make_panel(pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz

	var style := StyleBoxFlat.new()
	style.bg_color            = COLOR_PANEL
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color        = COLOR_BORDER
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size  = 20

	var rect := PanelContainer.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.add_theme_stylebox_override("panel", style)
	c.add_child(rect)
	return c


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	return lbl


func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz

	var make_style := func(bg_col: Color, border_col: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color            = bg_col
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color        = border_col
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		return s

	btn.add_theme_stylebox_override("normal",   make_style.call(Color(0.14, 0.10, 0.04), COLOR_BORDER))
	btn.add_theme_stylebox_override("hover",    make_style.call(Color(0.26, 0.18, 0.07), COLOR_BORDER_HI))
	btn.add_theme_stylebox_override("pressed",  make_style.call(Color(0.10, 0.07, 0.02), COLOR_BORDER))
	btn.add_theme_stylebox_override("disabled", make_style.call(Color(0.10, 0.09, 0.08), COLOR_TEXT_DIM))
	btn.add_theme_color_override("font_color",          COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color",    COLOR_TEXT_GOLD)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	btn.add_theme_font_size_override("font_size", 15)
	return btn


func _make_rune_pattern() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 10:
		var line := ColorRect.new()
		line.color    = Color(0.45, 0.35, 0.15, 0.03)
		line.position = Vector2(0, i * (_screen.y / 10.0))
		line.size     = Vector2(_screen.x, 1)
		c.add_child(line)
	for i in 14:
		var line := ColorRect.new()
		line.color    = Color(0.45, 0.35, 0.15, 0.025)
		line.position = Vector2(i * (_screen.x / 14.0), 0)
		line.size     = Vector2(1, _screen.y)
		c.add_child(line)
	return c
