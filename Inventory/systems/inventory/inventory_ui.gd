# res://ui/inventory_ui.gd
extends CanvasLayer

signal closed

const COLOR_BG          = Color(0.04, 0.03, 0.05, 0.97)
const COLOR_PANEL       = Color(0.08, 0.06, 0.09, 1.0)
const COLOR_SLOT_EMPTY  = Color(0.11, 0.09, 0.13, 1.0)
const COLOR_SLOT_HOVER  = Color(0.18, 0.14, 0.20, 1.0)
const COLOR_SLOT_SEL    = Color(0.22, 0.16, 0.08, 1.0)
const COLOR_BORDER      = Color(0.45, 0.35, 0.15, 1.0)
const COLOR_BORDER_HI   = Color(0.80, 0.62, 0.22, 1.0)
const COLOR_TEXT        = Color(0.92, 0.84, 0.66, 1.0)
const COLOR_TEXT_DIM    = Color(0.52, 0.47, 0.36, 1.0)
const COLOR_TEXT_GOLD   = Color(0.98, 0.78, 0.28, 1.0)
const COLOR_DIVIDER     = Color(0.40, 0.30, 0.12, 0.7)

const GRID_COLS := 3
const GRID_ROWS := 4

var _ability_system: AbilitySystem
var _inventory_system: InventorySystem

var _root: Control
var _grid_slots: Array[Control] = []
var _selected_index: int = -1
var _item_counts: Dictionary = {}

var _detail_icon: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_count: Label
var _detail_max_count: Label
var _detail_desc: Label
var _detail_effect: Label
var _btn_equip: Button
var _quick_slot_preview: Control

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


func init(ability_system: AbilitySystem, inventory_system: InventorySystem) -> void:
	_ability_system = ability_system
	_inventory_system = inventory_system
	_build_ui()


func open() -> void:
	visible = true
	_refresh_grid()
	_root.modulate = Color(1, 1, 1, 0)
	_root.scale = Vector2(0.96, 0.96)
	_root.pivot_offset = _screen / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(_root, "modulate", Color.WHITE, 0.18)
	tw.tween_property(_root, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func close() -> void:
	_root.pivot_offset = _screen / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(_root, "modulate", Color(1, 1, 1, 0), 0.14)
	tw.tween_property(_root, "scale", Vector2(0.96, 0.96), 0.14)
	await tw.finished
	visible = false
	emit_signal("closed")


func add_item(ability: Ability) -> void:
	var aname := ability.ability_name
	if _item_counts.has(aname):
		_item_counts[aname] += 1
	else:
		_item_counts[aname] = 1
		_inventory_system.add_item(ability)
	if visible:
		_refresh_grid()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()


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
	ibg.color = Color(0.05, 0.04, 0.06, 1.0)
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
	var lbl := _make_label("БЫСТРЫЙ ДОСТУП", 12)
	lbl.position = Vector2(_grid_x, y)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(lbl)

	_quick_slot_preview = Control.new()
	_quick_slot_preview.position = Vector2(_grid_x, y + 18.0)
	_quick_slot_preview.size = Vector2(GRID_COLS * (_slot_size.x + _slot_gap), 30.0)
	parent.add_child(_quick_slot_preview)
	_refresh_quick_slot_preview()


func _build_hints(parent: Control) -> void:
	var hints := [["ESC", "Закрыть"], ["ЛКМ", "Выбрать"], ["E", "В быстрый доступ"]]
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
			var cnt: int = _item_counts.get(ab.ability_name, 1)
			count_l.text = "x%d" % cnt
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
	var ss := Vector2(28, 28)
	for i in _ability_system.abilities.size():
		var ab := _ability_system.abilities[i]
		var bx := i * (ss.x + 4.0)

		var bg := ColorRect.new()
		bg.position = Vector2(bx, 0)
		bg.size = ss
		bg.color = COLOR_SLOT_EMPTY
		_quick_slot_preview.add_child(bg)

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


func _select_slot(idx: int) -> void:
	var items := _inventory_system.get_all()
	_selected_index = idx

	if idx >= 0 and idx < items.size():
		var ab       := items[idx] as Ability
		var cnt: int  = _item_counts.get(ab.ability_name, 1)
		var max_cnt  := _get_max_count(ab.ability_name)

		_detail_icon.texture   = ab.icon
		_detail_name.text      = ab.ability_name
		_detail_type.text      = "Расходуемое"
		_detail_desc.text      = ab.description
		_detail_effect.text    = ab.description
		_detail_count.text     = "%d / %d" % [cnt, max_cnt]
		_detail_max_count.text = "%d" % max_cnt
		_btn_equip.disabled    = false
	else:
		_detail_icon.texture   = null
		_detail_name.text      = ""
		_detail_type.text      = ""
		_detail_desc.text      = ""
		_detail_effect.text    = ""
		_detail_count.text     = ""
		_detail_max_count.text = ""
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
	for i in _ability_system.abilities.size():
		if _ability_system.abilities[i].ability_name == ab.ability_name:
			print("[Инвентарь] Уже в быстром доступе")
			return
	_ability_system.add_ability(ab)
	_refresh_quick_slot_preview()
	print("[Инвентарь] Добавлено: ", ab.ability_name)


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
