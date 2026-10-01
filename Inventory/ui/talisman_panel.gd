extends Control
## talisman_panel.gd — вкладка "ТАЛИСМАНЫ" в окне инвентаря.
##
## Тот же визуальный язык, что у самого инвентаря (Inventory/systems/
## inventory/inventory_ui.gd): орнаментные рамки, тот же серебристо-золотой
## текст, та же плашка-кнопка действия. Три колонки:
##   слева  — сетка ВСЕХ пассивных предметов (Ability.is_passive) в сумке;
##   в центре — карточка выбранного талисмана (иконка, тип, эффект);
##   справа — четыре секции-слота, куда его экипируют.
##
## В отличие от быстрого слота (AbilitySystem) талисман не тратится и не
## имеет кулдауна — слот либо занят (эффект действует), либо пуст
## (TalismanSystem, см. рядом).
##
## init() вызывается один раз при создании панели (родитель уже выставил
## position/size); _refresh() перестраивает содержимое заново — талисманов
## мало, пересобрать сетку целиком дешевле, чем патчить точечно.

const COLOR_FRAME_FILL := Color(0.062, 0.054, 0.046, 0.97)
const COLOR_CELL_FILL  := Color(0.03, 0.027, 0.024, 0.95)
const COLOR_BORDER     := Color(0.45, 0.35, 0.15, 1.0)
const COLOR_BORDER_HI  := Color(0.80, 0.62, 0.22, 1.0)
const COLOR_TEXT       := Color(0.88, 0.81, 0.68, 1.0)
const COLOR_TEXT_DIM   := Color(0.56, 0.50, 0.40, 1.0)
const COLOR_TEXT_GOLD  := Color(0.96, 0.76, 0.34, 1.0)
const COLOR_DIVIDER    := Color(0.52, 0.42, 0.24, 0.55)
const COLOR_WARN       := Color(0.85, 0.35, 0.20, 1.0)

const OrnateFrameScript := preload("res://Main_Menu/scripts/OrnateFrame.gd")
const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")
const OrnamentSeparatorScript := preload("res://Main_Menu/scripts/OrnamentSeparator.gd")
const GlyphIconScript := preload("res://Main_Menu/scripts/GlyphIcon.gd")

const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")

const GRID_COLS := 3
const GRID_ROWS := 2

var _inventory_system: InventorySystem
var _talisman_system: TalismanSystem
var _play_sound: Callable = func(_s): pass

var _pad := 30.0
var _left_w := 0.0
var _mid_x := 0.0
var _mid_w := 0.0
var _right_x := 0.0
var _btn_y := 0.0
var _slot_size := Vector2.ZERO
var _slot_gap := 16.0
var _grid_x := 0.0
var _grid_y := 0.0

var _grid_slots: Array[Control] = []
var _talisman_slots: Array[Control] = []
var _selected_name := ""

var _detail_icon: TextureRect
var _detail_icon_frame: Control
var _detail_name: Label
var _detail_type: Label
var _detail_effect: Label
var _detail_count: Label
var _btn_equip: Button
var _btn_equip_deco: Control
var _status_label: Label

## play_sound: Callable(AudioStream) — переиспользуем звуки хозяина
## (Inventory/systems/inventory/inventory_ui.gd), отдельный плеер не нужен
func init(inventory_system: InventorySystem, talisman_system: TalismanSystem,
		play_sound: Callable) -> void:
	_inventory_system = inventory_system
	_talisman_system = talisman_system
	_play_sound = play_sound
	_inventory_system.count_changed.connect(func(_n, _c): _refresh())
	_talisman_system.slot_changed.connect(func(_i, _t): _refresh())
	_refresh()


## Все пассивные предметы в сумке — то, что вообще можно экипировать
func _talismans() -> Array[Ability]:
	var out: Array[Ability] = []
	for item in _inventory_system.get_all():
		var ab := item as Ability
		if ab and ab.is_passive:
			out.append(ab)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_on_equip_pressed()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────
# ПОСТРОЕНИЕ
# ─────────────────────────────────────────────

func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	_grid_slots.clear()
	_talisman_slots.clear()

	var w := size.x
	var h := size.y
	_left_w = round(w * 0.40)
	_right_x = round(w * 0.78)
	_mid_x = _left_w + 40.0
	_mid_w = _right_x - 34.0 - _mid_x
	_btn_y = h - 104.0

	_grid_x = _pad
	_grid_y = 10.0
	var grid_w := _left_w - _pad - 20.0
	var grid_h := 210.0
	_slot_size = Vector2(
		floor((grid_w - _slot_gap * (GRID_COLS - 1)) / GRID_COLS),
		floor((grid_h - _slot_gap * (GRID_ROWS - 1)) / GRID_ROWS))

	_build_column_dividers()
	_build_subtitle()
	_build_grid()
	_build_detail_panel()
	_build_talisman_column()
	_build_equip_button()

	_select(_selected_name)


## Подпись под сеткой предметов — заголовок "ТАЛИСМАНЫ" уже даёт обёртка
## (см. inventory_ui.gd::_build_talismans_panel), здесь только пояснение
func _build_subtitle() -> void:
	var sub := _make_label("Пассивные обереги — действуют, пока экипированы", 15)
	sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	sub.position = Vector2(_pad, _grid_y + 210.0 + 22.0)
	sub.size = Vector2(_left_w - _pad * 2.0, 40.0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(sub)


func _build_column_dividers() -> void:
	var h := size.y - 40.0
	for x in [_left_w, _right_x - 34.0]:
		var line := _make_fade_line(h, true, COLOR_DIVIDER)
		line.position = Vector2(x, 20.0)
		add_child(line)
		var d := _make_diamond(8.0)
		d.position = Vector2(x - 4.0, h / 2.0 + 20.0 - 4.0)
		add_child(d)


func _build_grid() -> void:
	var items := _talismans()
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var idx := row * GRID_COLS + col
			var pos := Vector2(
				_grid_x + col * (_slot_size.x + _slot_gap),
				_grid_y + row * (_slot_size.y + _slot_gap))
			var slot := _build_slot(idx, pos, items[idx] if idx < items.size() else null)
			add_child(slot)
			_grid_slots.append(slot)


func _build_slot(idx: int, pos: Vector2, item: Ability) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = _slot_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var equipped := item != null and _talisman_system.has_talisman(item.ability_name)

	var frame := _make_frame()
	frame.name = "Frame"
	frame.size = _slot_size
	frame.set("fill_color", COLOR_CELL_FILL)
	frame.set("corner_length", 14.0)
	frame.set("show_cross", item == null)
	frame.set("highlight", 1.0 if (item != null and item.ability_name == _selected_name) else 0.0)
	c.add_child(frame)

	if item != null:
		var icon := TextureRect.new()
		icon.position = Vector2(_slot_size.x * 0.2, 8.0)
		icon.size = Vector2(_slot_size.x * 0.6, _slot_size.y - 44.0)
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate.a = 1.0 if equipped else 0.55
		c.add_child(icon)

		var lbl := _make_label(item.ability_name, 13)
		lbl.position = Vector2(8.0, _slot_size.y - 30.0)
		lbl.size = Vector2(_slot_size.x - 16.0, 22.0)
		lbl.clip_text = true
		lbl.add_theme_color_override("font_color", COLOR_TEXT_GOLD if equipped else COLOR_TEXT_DIM)
		c.add_child(lbl)

		if equipped:
			var mark := _make_diamond(9.0)
			mark.position = Vector2(_slot_size.x - 18.0, 4.0)
			c.add_child(mark)

		var area := Control.new()
		area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select(item.ability_name))
		c.add_child(area)

	return c


func _build_detail_panel() -> void:
	var x := _mid_x
	var w := _mid_w
	var icon_size := 150.0
	var text_w := w - icon_size - 24.0

	_detail_icon_frame = _make_frame()
	_detail_icon_frame.position = Vector2(x + w - icon_size, 20.0)
	_detail_icon_frame.size = Vector2(icon_size, icon_size)
	_detail_icon_frame.set("fill_color", COLOR_CELL_FILL)
	_detail_icon_frame.set("corner_length", 18.0)
	_detail_icon_frame.set("double_border", true)
	add_child(_detail_icon_frame)

	_detail_icon = TextureRect.new()
	_detail_icon.position = Vector2(12.0, 12.0)
	_detail_icon.size = Vector2(icon_size - 24.0, icon_size - 24.0)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon_frame.add_child(_detail_icon)

	_detail_name = _make_label("", 30)
	_detail_name.position = Vector2(x, 24.0)
	_detail_name.size = Vector2(text_w, 42.0)
	_detail_name.clip_text = true
	add_child(_detail_name)

	_detail_type = _make_label("", 18)
	_detail_type.position = Vector2(x, 72.0)
	_detail_type.size = Vector2(text_w, 26.0)
	_detail_type.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	add_child(_detail_type)

	var y := 20.0 + icon_size + 20.0
	var sep := Control.new()
	sep.set_script(OrnamentSeparatorScript)
	sep.position = Vector2(x, y)
	sep.size = Vector2(w, 18.0)
	add_child(sep)
	y += 30.0

	_detail_count = _make_label("", 18)
	var cap := _make_label("В сумке", 18)
	cap.position = Vector2(x, y)
	cap.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	add_child(cap)
	_detail_count.position = Vector2(x, y)
	_detail_count.size = Vector2(w, 26.0)
	_detail_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_count.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	add_child(_detail_count)
	y += 42.0

	_add_divider(Vector2(x, y), w)
	y += 18.0

	var eff_hdr := _make_label("Эффект", 19)
	eff_hdr.position = Vector2(x, y)
	eff_hdr.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	add_child(eff_hdr)
	y += 32.0

	_detail_effect = _make_label("", 19)
	_detail_effect.position = Vector2(x, y)
	_detail_effect.size = Vector2(w, _btn_y - 56.0 - y)
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail_effect)

	_status_label = _make_label("", 15)
	_status_label.position = Vector2(x, _btn_y - 30.0)
	_status_label.size = Vector2(w, 22.0)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	add_child(_status_label)


## Правая колонка: ровно четыре секции-слота столбиком — сколько талисманов
## герой может нести одновременно
func _build_talisman_column() -> void:
	var x := _right_x + 30.0
	var col_w := size.x - _right_x - 60.0

	var hdr := _make_label("ЭКИПИРОВАНО", 20)
	hdr.position = Vector2(x, 26.0)
	add_child(hdr)

	var line := _make_fade_line(col_w, false, COLOR_DIVIDER)
	line.position = Vector2(x, 60.0)
	add_child(line)

	# Высота секции подгоняется под реально доступное место, а не берётся
	# фиксированной (150, как у "БЫСТРОГО СЛОТА" из 3 ячеек у инвентаря) —
	# четыре секции в ту же колонку иначе не влезают и вылезают за рамку
	var top_y := 78.0
	var bottom_margin := 16.0
	var gap := 16.0
	var avail_h := size.y - top_y - bottom_margin
	var ss := minf(col_w, (avail_h - gap * (TalismanSystem.MAX_SLOTS - 1)) / float(TalismanSystem.MAX_SLOTS))
	var y := top_y
	for i in TalismanSystem.MAX_SLOTS:
		var s := _build_equip_slot(Vector2(x, y), Vector2(ss, ss), i)
		add_child(s)
		_talisman_slots.append(s)
		y += ss + gap


func _build_equip_slot(pos: Vector2, sz: Vector2, index: int) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var talisman: Ability = _talisman_system.slots[index]

	var frame := _make_frame()
	frame.name = "Frame"
	frame.size = sz
	frame.set("fill_color", COLOR_CELL_FILL)
	frame.set("corner_length", 16.0)
	frame.set("corner_width", 1.5)
	frame.set("show_cross", talisman == null)
	c.add_child(frame)

	# Номер секции — маленький ромб-бейдж в углу, как порядковый номер
	# быстрого слота у AbilitySystem
	var badge := _make_diamond(14.0)
	badge.position = Vector2(-6.0, -6.0)
	c.add_child(badge)
	var num := _make_label(str(index + 1), 13)
	num.position = Vector2(-11.0, -12.0)
	num.size = Vector2(18.0, 18.0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	c.add_child(num)

	if talisman != null:
		var icon := TextureRect.new()
		icon.position = Vector2(sz.x * 0.16, 14.0)
		icon.size = Vector2(sz.x * 0.68, sz.y - 50.0)
		icon.texture = talisman.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(icon)

		var lbl := _make_label(talisman.ability_name, 13)
		lbl.position = Vector2(8.0, sz.y - 30.0)
		lbl.size = Vector2(sz.x - 16.0, 22.0)
		lbl.clip_text = true
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
		c.add_child(lbl)

		var area := Control.new()
		area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select(talisman.ability_name))
		c.add_child(area)
	else:
		var hint := _make_label("пусто", 14)
		hint.position = Vector2(0, sz.y * 0.5 - 10.0)
		hint.size = Vector2(sz.x, 20.0)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(COLOR_TEXT_DIM, 0.6))
		c.add_child(hint)

	return c


func _build_equip_button() -> void:
	# Только ширина колонки описания — в отличие от инвентаря, справа тут не
	# пусто под кнопкой: там секции-слоты идут почти на всю высоту панели,
	# и кнопка шире _mid_w наехала бы на нижние секции
	var w := _mid_w
	var h := 64.0

	_btn_equip = Button.new()
	_btn_equip.position = Vector2(_mid_x, _btn_y)
	_btn_equip.size = Vector2(w, h)
	_btn_equip.focus_mode = Control.FOCUS_NONE
	_btn_equip.add_theme_font_size_override("font_size", 20)
	_btn_equip.add_theme_color_override("font_color", COLOR_TEXT)
	_btn_equip.add_theme_color_override("font_hover_color", COLOR_TEXT_GOLD)
	_btn_equip.add_theme_color_override("font_pressed_color", COLOR_TEXT_GOLD)
	_btn_equip.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	_btn_equip.add_theme_stylebox_override("normal",
		_flat_box(Color(0.06, 0.052, 0.045, 0.95), Color(0.55, 0.44, 0.26, 0.7)))
	_btn_equip.add_theme_stylebox_override("hover",
		_flat_box(Color(0.13, 0.1, 0.065, 0.97), COLOR_BORDER_HI))
	_btn_equip.add_theme_stylebox_override("pressed",
		_flat_box(Color(0.04, 0.035, 0.03, 0.97), Color(0.55, 0.44, 0.26, 0.7)))
	_btn_equip.add_theme_stylebox_override("disabled",
		_flat_box(Color(0.05, 0.045, 0.04, 0.85), Color(0.35, 0.3, 0.22, 0.5)))
	_btn_equip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_btn_equip.pressed.connect(_on_equip_pressed)
	_btn_equip.disabled = true
	add_child(_btn_equip)

	_btn_equip_deco = Control.new()
	_btn_equip_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_equip_deco.size = Vector2(w, h)
	_btn_equip.add_child(_btn_equip_deco)

	var inner := _make_frame()
	inner.position = Vector2(6.0, 6.0)
	inner.size = Vector2(w - 12.0, h - 12.0)
	inner.set("fill_color", Color(0.0, 0.0, 0.0, 0.0))
	inner.set("border_color", Color(0.55, 0.44, 0.26, 0.28))
	inner.set("corner_length", 10.0)
	_btn_equip_deco.add_child(inner)

	for p in [Vector2(-9.0, h / 2.0 - 9.0), Vector2(w - 9.0, h / 2.0 - 9.0)]:
		var d := _make_diamond(18.0)
		d.position = p
		_btn_equip_deco.add_child(d)
	for p in [Vector2(w / 2.0 - 6.0, -6.0), Vector2(w / 2.0 - 6.0, h - 6.0)]:
		var d := _make_diamond(12.0)
		d.position = p
		_btn_equip_deco.add_child(d)


# ─────────────────────────────────────────────
# ВЫБОР И ЭКИПИРОВКА
# ─────────────────────────────────────────────

func _find(name: String) -> Ability:
	for item in _talismans():
		if item.ability_name == name:
			return item
	return null


func _select(name: String) -> void:
	var ab := _find(name)
	_selected_name = name if ab != null else ""

	if ab != null:
		var equipped := _talisman_system.has_talisman(ab.ability_name)
		_detail_icon.texture = ab.icon
		_detail_icon_frame.visible = true
		_detail_name.text = ab.ability_name
		_detail_name.add_theme_color_override("font_color", COLOR_TEXT)
		var type_name := ab.item_type if ab.item_type != "" else "Талисман"
		_detail_type.text = type_name + ("  •  экипирован" if equipped else "")
		_detail_effect.text = ab.description
		var cnt := _inventory_system.get_count(ab.ability_name)
		_detail_count.text = "%d" % cnt

		_btn_equip.text = "[E]   СНЯТЬ" if equipped else "[E]   ЭКИПИРОВАТЬ"
		_btn_equip.disabled = (not equipped) and _talisman_system.is_full()
		_set_status("")
	else:
		_detail_icon.texture = null
		_detail_icon_frame.visible = false
		_detail_name.text = "Выберите талисман"
		_detail_name.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_detail_type.text = "Нажмите на ячейку слева"
		_detail_effect.text = ""
		_detail_count.text = "—"
		_btn_equip.text = "[E]   ЭКИПИРОВАТЬ"
		_btn_equip.disabled = true
		_set_status("")

	_update_equip_deco()
	_refresh_highlights()


func _refresh_highlights() -> void:
	var items := _talismans()
	for i in _grid_slots.size():
		if i >= items.size():
			continue
		var frame := _grid_slots[i].get_node_or_null("Frame")
		if frame:
			frame.set("highlight", 1.0 if items[i].ability_name == _selected_name else 0.0)


func _on_equip_pressed() -> void:
	var ab := _find(_selected_name)
	if ab == null:
		return

	var slot := _talisman_system.find_slot(ab.ability_name)
	if slot != -1:
		_talisman_system.unequip(slot)
		_play_sound.call(SOUND_CHOICE)
		_select(_selected_name)
		_set_status("Снято: %s" % ab.ability_name, COLOR_TEXT_DIM)
		return

	var empty := _talisman_system.find_empty_slot()
	if empty == -1:
		_play_sound.call(SOUND_DENIED)
		_set_status("Все %d секции заняты — сначала снимите талисман" % TalismanSystem.MAX_SLOTS, COLOR_WARN)
		return

	_talisman_system.equip(empty, ab)
	_play_sound.call(SOUND_ACCEPT)
	_select(_selected_name)
	_set_status("Экипирован: %s" % ab.ability_name, COLOR_TEXT_GOLD)


func _set_status(text: String, color := COLOR_TEXT_DIM) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)


func _update_equip_deco() -> void:
	if is_instance_valid(_btn_equip_deco):
		_btn_equip_deco.modulate.a = 0.4 if _btn_equip.disabled else 1.0


# ─────────────────────────────────────────────
# ХЕЛПЕРЫ (тот же язык, что у inventory_ui.gd)
# ─────────────────────────────────────────────

func _make_frame() -> Control:
	var f := Control.new()
	f.set_script(OrnateFrameScript)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _make_diamond(d: float) -> Control:
	var m := Control.new()
	m.set_script(DiamondMarkerScript)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size = Vector2(d, d)
	return m


func _make_glyph(glyph: String, color: Color, d: float) -> Control:
	var g := Control.new()
	g.set_script(GlyphIconScript)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.size = Vector2(d, d)
	g.call("set_glyph", glyph, color)
	return g


func _make_fade_line(length: float, vertical: bool, color: Color, thickness := 1.0) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4 if vertical else 64
	tex.height = 64 if vertical else 4
	tex.fill_from = Vector2(0.5, 0.0) if vertical else Vector2(0.0, 0.5)
	tex.fill_to = Vector2(0.5, 1.0) if vertical else Vector2(1.0, 0.5)

	var line := TextureRect.new()
	line.texture = tex
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(thickness, length) if vertical else Vector2(length, thickness)
	return line


func _add_divider(pos: Vector2, width: float) -> void:
	var d := _make_fade_line(width, false, COLOR_DIVIDER)
	d.position = pos
	add_child(d)


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	return lbl


func _flat_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
