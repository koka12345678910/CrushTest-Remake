extends "res://Inventory/ui/talisman_panel.gd"
## hero_talisman_panel.gd — вкладка "ТАЛИСМАНЫ" в стиле инвентаря героя
## (раскладка и детали — hero_inventory_skin.gd).
## Логика — та же, что у обычной вкладки (talisman_panel.gd: выбор,
## экипировка/снятие, клавиша E), здесь только раскладка:
##   слева  — та же сетка, в ней талисманы;
##   в центре — та же карточка, что у инвентаря;
##   справа — табличка "ЭКИПИРОВАНО", под ней четыре секции 2x2 (те же
##            клетки, что в сетке).
## Встаёт на место содержимого инвентаря (вкладки остаются).

const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")

var skin
var _lore_label: Label
var _slot_label: Label


func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	_grid_slots.clear()
	_talisman_slots.clear()
	_build_hero_grid()
	var d: Dictionary = HeroSkin.make_detail(self, self, "В сумке", "Секция")
	_detail_icon_frame = d["icon_box"]
	_detail_icon = d["icon"]
	_detail_name = d["name"]
	_detail_type = d["type"]
	_detail_count = d["row1"]
	_slot_label = d["row2"]
	_detail_effect = d["effect"]
	_btn_equip = d["button"]
	_status_label = d["status"]
	_lore_label = d["lore"]
	_btn_equip.pressed.connect(_on_equip_pressed)
	_build_amulet_column()
	_select(_selected_name)


func _build_hero_grid() -> void:
	var cells := HeroSkin.build_grid(self, self, "ТАЛИСМАНЫ")
	var items := _talismans()
	for i in cells.size():
		var item: Ability = items[i] if i < items.size() else null
		var r: Rect2 = cells[i]
		var s := _cell(r.position, r.size, item, -1)
		add_child(s)
		_grid_slots.append(s)
	var hint := _make_label("Пассивные обереги — действуют, пока экипированы", 16)
	hint.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	hint.position = Vector2(HeroSkin.grid_x() + 26, HeroSkin.TOP + HeroSkin.FRAME_H + 12)
	add_child(hint)


## Ячейка с талисманом: подсветка выбранного (как в инвентаре), надетый —
## ярче, с ромбиком в углу; снятый чуть приглушён. equip_index >= 0 — секция
## амулетницы: своя золотая рамка с листа, номер в углу, пустая — "пусто"
func _cell(pos: Vector2, sz: Vector2, item: Ability, equip_index: int) -> Control:
	var c := Control.new()
	c.position = pos.round()
	c.size = sz.round()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HeroSkin.cell_plate(c, c.size)
	var frame := HeroSkin.make_cell_frame()
	frame.name = "Frame"
	frame.size = c.size
	frame.thin = equip_index >= 0
	frame.highlight = 1.0 if (item != null and item.ability_name == _selected_name) else 0.0
	c.add_child(frame)
	var equipped := item != null and _talisman_system.has_talisman(item.ability_name)
	if equip_index >= 0:
		var num := _make_label(str(equip_index + 1), 15)
		num.add_theme_color_override("font_color", HeroSkin.GOLD)
		num.position = Vector2(18, 8)
		c.add_child(num)
	if item == null:
		if equip_index >= 0:
			var empty := _make_label("пусто", 13)
			empty.add_theme_color_override("font_color", Color(HeroSkin.TEXT_DIM, 0.7))
			empty.size = c.size
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c.add_child(empty)
		return c
	# Надетый (и в секции амулетницы) — как в инвентаре, снятый — приглушён
	var icon := HeroSkin.make_icon(1.15 if (equipped or equip_index >= 0) else 0.75)
	icon.texture = item.icon
	if equip_index >= 0:
		icon.position = Vector2(14, 14)
		icon.size = c.size - Vector2(28, 28)
	else:
		icon.position = Vector2(10, 8)
		icon.size = c.size - Vector2(20, 38)
	c.add_child(icon)
	if equip_index < 0:
		var lbl := _make_label(item.ability_name, 12)
		lbl.position = Vector2(8, c.size.y - 28)
		lbl.size = Vector2(c.size.x - 16, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.add_theme_color_override("font_color", HeroSkin.GOLD if equipped else HeroSkin.TEXT_DIM)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		c.add_child(lbl)
		if equipped:
			var mark := _make_diamond(10.0)
			mark.position = Vector2(c.size.x - 30, 12)
			c.add_child(mark)
	var area := Control.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	var item_name := item.ability_name
	area.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_play_sound.call(SOUND_CHOICE)
			_select(item_name))
	c.add_child(area)
	return c


## Правая колонка: рамка, табличка, амулетница с четырьмя секциями, штандарт
func _build_amulet_column() -> void:
	var f := HeroSkin.build_frame(self, HeroSkin.right_rect(), null)
	HeroSkin.plaque(self, self, "ЭКИПИРОВАНО", f.position.x, f.size.x, f.position.y + HeroSkin.T["layout"]["title_dy"])
	# Четыре секции 2x2 — такие же клетки, как в сетке, под табличкой
	var gap := 12.0
	var cell := 132.0
	var start := Vector2(round(f.get_center().x - cell - gap * 0.5), f.position.y + HeroSkin.column_top())
	for i in TalismanSystem.MAX_SLOTS:
		var p := start + Vector2((i % 2) * (cell + gap), (i / 2) * (cell + gap))
		var s := _cell(p, Vector2(cell, cell), _talisman_system.slots[i], i)
		add_child(s)
		_talisman_slots.append(s)
	var y := start.y + cell * 2.0 + gap + 24.0
	HeroSkin.divider(self, f.position.x + 20, f.size.x - 40, y)


func _select(item_name: String) -> void:
	super(item_name)
	var ab := _find(_selected_name)
	if not is_instance_valid(_lore_label):
		return
	if ab == null:
		_lore_label.text = ""
		_slot_label.text = "—"
		_detail_effect.text = ""
		return
	# Как в карточке инвентаря: золотое название, предание, эффект абзацем,
	# и в какой секции амулетницы талисман сейчас
	_detail_name.add_theme_color_override("font_color", HeroSkin.GOLD)
	_lore_label.text = HeroSkin.lore_for(get_tree(), ab.ability_name)
	_detail_effect.text = tr(ab.description).replace("\n", " ")
	var slot := _talisman_system.find_slot(ab.ability_name)
	_slot_label.text = str(slot + 1) if slot != -1 else tr("не надет")
	# Секции амулетницы подсвечиваются вместе с сеткой (сетку — база)
	for i in _talisman_slots.size():
		var t: Ability = _talisman_system.slots[i]
		var f := _talisman_slots[i].get_node_or_null("Frame")
		if f:
			f.set("highlight", 1.0 if (t != null and t.ability_name == _selected_name) else 0.0)
