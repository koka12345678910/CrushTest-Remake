extends Control
## hero_settings_screen.gd — вкладка «НАСТРОЙКИ» внутри нарисованного
## инвентаря героя: те же три панели вместо панели главного меню поверх:
##   слева  — разделы (Общие, Графика, Звук, Управление, Язык);
##   центр  — настройки раздела: ползунки, переключатели, выбор;
##   справа — описание наведённой настройки, «Сбросить» и «Назад».
## Значения живут в автозагрузке GameSettings (как у Main_Menu/scripts/
## SettingsPanel.gd), на диск пишутся один раз — когда экран закрывается.

signal closed

const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")

const CATEGORIES := [
	["general", "ОБЩИЕ", "Камера и ощущение боя"],
	["graphics", "ГРАФИКА", "Экран и синхронизация"],
	["audio", "ЗВУК", "Громкость музыки и эффектов"],
	["controls", "УПРАВЛЕНИЕ", "Клавиши"],
	["language", "ЯЗЫК", "Язык интерфейса"],
]

var _ui
var _category := "general"
var _cat_cells: Array = []
var _rows_root: Control
var _plaque: Label
var _desc_title: Label
var _desc_body: Label
var _rows_rect := Rect2()

## Стрелки/геймпад: ↑↓ — строка, ←→ — значение, Enter — переключить,
## Tab / бамперы — раздел. Включает главное меню (SettingsPanel.gd); в
## инвентаре выключено — там у клавиш свои роли
var keyboard_nav := false
var _rows: Array[Control] = []
var _sel := -1


func init(ui) -> void:
	_ui = ui
	_build()
	# Пишем на диск при закрытии экрана (вкладкой, Esc или «Назад»), а не на
	# каждое движение ползунка
	visibility_changed.connect(func():
		if not visible:
			GameSettings.save_settings())


func _make_label(text: String, font_size: int) -> Label:
	return _ui._make_label(text, font_size)


func refresh() -> void:
	_show_category(_category, false)


## Вызывается инвентарём при переключении вкладки (как у панели меню)
func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var lay: Dictionary = HeroSkin.T["layout"]
	# Слева — разделы
	var gf := HeroSkin.build_frame(self, Rect2(HeroSkin.grid_x(), HeroSkin.TOP, lay["grid_w"], HeroSkin.FRAME_H), null)
	var ty: float = gf.position.y + lay["title_dy"]
	var hdr := _make_label("НАСТРОЙКИ", 24)
	hdr.add_theme_color_override("font_color", HeroSkin.GOLD)
	hdr.position = Vector2(gf.position.x, ty)
	hdr.size = Vector2(gf.size.x, 32)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hdr)
	HeroSkin.divider(self, gf.position.x + 40, gf.size.x - 80, ty + 36)
	var cw := minf(gf.size.x - 120.0, 520.0)
	var cx := roundf(gf.get_center().x - cw * 0.5)
	var y := ty + 90.0
	_cat_cells.clear()
	for c in CATEGORIES:
		var cell := _category_cell(c, Rect2(cx, y, cw, 96))
		_cat_cells.append([c[0], cell])
		y += 112.0

	# Центр — сами настройки
	var mf := HeroSkin.build_frame(self, Rect2(HeroSkin.detail_x(), HeroSkin.TOP, lay["detail_w"], HeroSkin.FRAME_H), null, false)
	_plaque = HeroSkin.plaque(self, self, "", mf.position.x, mf.size.x, mf.position.y + lay["title_dy"])
	var top: float = mf.position.y + HeroSkin.column_top() + 10.0
	_rows_rect = Rect2(mf.position.x + 30, top, mf.size.x - 60, mf.end.y - 30 - top)
	_rows_root = Control.new()
	_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_root.position = _rows_rect.position
	_rows_root.size = _rows_rect.size
	add_child(_rows_root)

	# Справа — описание и кнопки
	var rf := HeroSkin.build_frame(self, HeroSkin.right_rect(), null)
	HeroSkin.plaque(self, self, "ОПИСАНИЕ", rf.position.x, rf.size.x, rf.position.y + lay["title_dy"])
	var dy: float = rf.position.y + HeroSkin.column_top()
	_desc_title = _make_label("", 21)
	_desc_title.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
	_desc_title.position = Vector2(rf.position.x + 20, dy)
	_desc_title.size = Vector2(rf.size.x - 40, 30)
	_desc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_desc_title)
	HeroSkin.divider(self, rf.position.x + 20, rf.size.x - 40, dy + 40)
	_desc_body = _make_label("", 17)
	_desc_body.add_theme_color_override("font_color", HeroSkin.TEXT)
	_desc_body.position = Vector2(rf.position.x + 24, dy + 76)
	_desc_body.size = Vector2(rf.size.x - 48, 220)
	_desc_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc_body)
	var by := rf.end.y - 150.0
	_button("СБРОСИТЬ ВСЁ", Rect2(rf.position.x + 30, by - 58, rf.size.x - 60, 44), _on_reset)
	_button("[ ESC ]   НАЗАД", Rect2(rf.position.x + 30, by, rf.size.x - 60, 44), func(): _ui._close_settings_screen())

	_show_category(_category, false)


## Раздел слева: нарисованная клетка темы, название и подпись; выбранный —
## с подсветкой темы
func _category_cell(c: Array, r: Rect2) -> Control:
	var holder := Control.new()
	holder.position = r.position.round()
	holder.size = r.size
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	HeroSkin.cell_plate(holder, r.size)
	var frame := HeroSkin.make_cell_frame()
	frame.name = "Frame"
	frame.size = r.size
	holder.add_child(frame)
	var name_l := _make_label(c[1], 24)
	name_l.name = "Name"
	name_l.position = Vector2(0, 18)
	name_l.size = Vector2(r.size.x, 32)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(name_l)
	var sub := _make_label(c[2], 15)
	sub.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	sub.position = Vector2(0, 54)
	sub.size = Vector2(r.size.x, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(sub)
	var id: String = c[0]
	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_category(id, true))
	holder.mouse_entered.connect(func():
		if id != _category:
			frame.highlight = 0.45)
	holder.mouse_exited.connect(func():
		frame.highlight = 1.0 if id == _category else 0.0)
	return holder


func _show_category(id: String, sound: bool) -> void:
	if sound and id != _category:
		_ui._play_ui_sound(_ui.SOUND_CHOICE)
	_category = id
	for cc in _cat_cells:
		var on: bool = cc[0] == id
		var cell: Control = cc[1]
		cell.get_node("Frame").set("highlight", 1.0 if on else 0.0)
		(cell.get_node("Name") as Label).add_theme_color_override("font_color", HeroSkin.GOLD_HI if on else HeroSkin.TEXT)
	for c in CATEGORIES:
		if c[0] == id:
			_plaque.text = c[1]
	for ch in _rows_root.get_children():
		ch.queue_free()
	_rows.clear()
	var y := 0.0
	var first := true
	for d in _defs(id):
		var row := _row(d, y)
		_rows_root.add_child(row)
		var idx := _rows.size()
		_rows.append(row)
		if keyboard_nav:
			row.mouse_entered.connect(func(): _set_sel(idx, false))
		if first:
			_describe(d)
			first = false
		y += 76.0
	if first:
		_desc_title.text = ""
		_desc_body.text = ""
	_sel = -1
	if keyboard_nav and not _rows.is_empty():
		_set_sel(0, false)


## Настройки раздела: kind slider/toggle/select/info
func _defs(id: String) -> Array:
	match id:
		"general":
			return [{"kind": "toggle", "label": "Тряска камеры",
				"desc": "Тряска экрана от ударов, оглушения и усталости. Выключите, если от неё укачивает.",
				"get": func(): return GameSettings.shake_multiplier > 0.0,
				"set": func(v): GameSettings.shake_multiplier = 1.0 if v else 0.0}]
		"graphics":
			return [
				{"kind": "select", "label": "Режим экрана", "options": ["ОКНО", "ВЕСЬ ЭКРАН"],
					"desc": "Играть в окне или на весь экран.",
					"get": func(): return 1 if GameSettings.fullscreen else 0,
					"set": func(i): GameSettings.fullscreen = (i == 1); GameSettings.apply_all()},
				{"kind": "toggle", "label": "Вертикальная синхр.",
					"desc": "Подстраивает частоту кадров под монитор — без разрывов картинки.",
					"get": func(): return GameSettings.vsync,
					"set": func(v): GameSettings.vsync = v; GameSettings.apply_all()},
			]
		"audio":
			return [
				{"kind": "slider", "label": "Общая громкость", "desc": "Громкость всего звука игры.",
					"get": func(): return GameSettings.master_volume,
					"set": func(v): GameSettings.master_volume = v; GameSettings.apply_all()},
				{"kind": "slider", "label": "Музыка", "desc": "Громкость музыки и саундтрека.",
					"get": func(): return GameSettings.music_volume,
					"set": func(v): GameSettings.music_volume = v; GameSettings.apply_all()},
				{"kind": "slider", "label": "Эффекты", "preview": true, "desc": "Громкость боя и звуков интерфейса. Отпустите ползунок — прозвучит пример.",
					"get": func(): return GameSettings.sfx_volume,
					"set": func(v): GameSettings.sfx_volume = v; GameSettings.apply_all()},
			]
		"controls":
			return [
				{"kind": "toggle", "label": "Прицел мышью",
					"desc": "Удары, выстрелы и заклинания идут туда, куда указывает мышь, а не по стрелкам. Цель в фокусе по-прежнему важнее.",
					"get": func(): return GameSettings.mouse_aim,
					"set": func(v): GameSettings.mouse_aim = v},
				{"kind": "info", "label": "Переназначение клавиш", "value": "скоро",
					"desc": "Настройка клавиш появится в одном из следующих обновлений."},
			]
		"language":
			# Названия языков — каждое на своём языке и не переводятся (их нет
			# в Localization/strings_en.gd). Смена сразу перерисовывает экран
			return [{"kind": "select", "label": "Язык", "options": ["РУССКИЙ", "ENGLISH"],
				"desc": "Язык меню и настроек. Остальная игра будет переведена в следующих обновлениях.",
				"get": func(): return maxi(GameSettings.LANGUAGES.find(GameSettings.language), 0),
				"set": func(i): GameSettings.language = GameSettings.LANGUAGES[i]; GameSettings.apply_all()}]
	return []


func _row(d: Dictionary, y: float) -> Control:
	var w := _rows_rect.size.x
	var row := Control.new()
	row.position = Vector2(0, y)
	row.size = Vector2(w, 60)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(func(): _describe(d))
	row.set_meta("def", d)
	if keyboard_nav:
		# Подсветка выбранной с клавиатуры строки: золотая черта слева и
		# полоса света, гаснущая вправо
		var sel := Control.new()
		sel.name = "Sel"
		sel.visible = false
		sel.position = Vector2(-14, 2)
		sel.size = Vector2(w + 14, 58)
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel.draw.connect(func():
			for i in 16:
				var t := i / 16.0
				sel.draw_rect(Rect2(i * sel.size.x / 16.0, 0, sel.size.x / 16.0 + 0.5, sel.size.y),
					Color(HeroSkin.GOLD_HI, 0.07 * (1.0 - t) * (1.0 - t)))
			sel.draw_rect(Rect2(0, 6, 2, sel.size.y - 12), HeroSkin.GOLD))
		row.add_child(sel)
	var lbl := _make_label(d["label"], 20)
	lbl.position = Vector2(0, 14)
	lbl.size = Vector2(w * 0.5, 30)
	lbl.clip_text = true
	row.add_child(lbl)
	var line := ColorRect.new()
	line.color = HeroSkin.LINE
	line.position = Vector2(0, 66)
	line.size = Vector2(w, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var cx := w * 0.5
	var cw := w * 0.5
	match d["kind"]:
		"slider":
			var s := HSlider.new()
			s.min_value = 0.0
			s.max_value = 1.0
			s.step = 0.05
			s.value = d["get"].call()
			s.position = Vector2(cx, 18)
			s.size = Vector2(cw - 62, 24)
			_style_slider(s)
			row.add_child(s)
			row.set_meta("slider", s)
			var val := _make_label("%d%%" % roundi(s.value * 100.0), 18)
			val.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
			val.position = Vector2(w - 56, 14)
			val.size = Vector2(56, 30)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(val)
			s.value_changed.connect(func(v: float):
				val.text = "%d%%" % roundi(v * 100.0)
				d["set"].call(v))
			s.mouse_entered.connect(func(): _describe(d))
			if d.get("preview", false):
				s.drag_ended.connect(func(changed: bool):
					if changed:
						_ui._play_ui_sound(_ui.SOUND_TOGGLE))
		"toggle":
			var b := _chip_button(Rect2(w - 150, 12, 150, 38))
			var on: bool = d["get"].call()
			b.text = "ВКЛ" if on else "ВЫКЛ"
			b.add_theme_color_override("font_color", HeroSkin.GOLD_HI if on else HeroSkin.TEXT_DIM)
			b.pressed.connect(func():
				var nv: bool = not d["get"].call()
				d["set"].call(nv)
				b.text = "ВКЛ" if nv else "ВЫКЛ"
				b.add_theme_color_override("font_color", HeroSkin.GOLD_HI if nv else HeroSkin.TEXT_DIM)
				_ui._play_ui_sound(_ui.SOUND_TOGGLE))
			b.mouse_entered.connect(func(): _describe(d))
			row.add_child(b)
			row.set_meta("toggle", b)
		"select":
			var opts: Array = d["options"]
			var val := _make_label("", 18)
			val.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
			val.position = Vector2(cx + 34, 14)
			val.size = Vector2(cw - 68, 30)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(val)
			var idx := {"i": int(d["get"].call())}
			val.text = str(opts[idx["i"]])
			for step: int in [-1, 1]:
				var arrow := _chip_button(Rect2(cx if step < 0 else w - 32, 14, 32, 32))
				arrow.text = "‹" if step < 0 else "›"
				arrow.pressed.connect(func():
					idx["i"] = (idx["i"] + step + opts.size()) % opts.size()
					val.text = str(opts[idx["i"]])
					d["set"].call(idx["i"])
					_ui._play_ui_sound(_ui.SOUND_TOGGLE))
				arrow.mouse_entered.connect(func(): _describe(d))
				row.add_child(arrow)
				row.set_meta("arrow_next" if step > 0 else "arrow_prev", arrow)
		_:
			var val := _make_label(d.get("value", "—"), 18)
			val.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
			val.position = Vector2(cx, 14)
			val.size = Vector2(cw, 30)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(val)
	return row


func _describe(d: Dictionary) -> void:
	_desc_title.text = d["label"]
	_desc_body.text = d["desc"]


func _chip_button(r: Rect2) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", HeroSkin.TEXT)
	b.add_theme_color_override("font_hover_color", HeroSkin.GOLD_HI)
	b.add_theme_color_override("font_pressed_color", HeroSkin.GOLD_HI)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.5) if st == "normal" else Color(HeroSkin.GOLD_HI, 0.08)
		sb.border_color = Color(HeroSkin.GOLD, 0.5 if st == "normal" else 0.9)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _button(text: String, r: Rect2, on_press: Callable) -> Button:
	var b := _chip_button(r)
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(on_press)
	add_child(b)
	return b


## Ползунок в цветах темы: тёмный жёлоб с тонкой каймой, заливка — золото
## (у мага — серебро) темы, ромб-ручка
func _style_slider(s: HSlider) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0, 0, 0, 0.6)
	groove.border_color = Color(HeroSkin.GOLD, 0.35)
	groove.set_border_width_all(1)
	groove.content_margin_top = 3
	groove.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", groove)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(HeroSkin.GOLD, 0.85)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for yy in 22:
		for xx in 22:
			var d := absf(xx - 10.5) + absf(yy - 10.5)
			if d <= 10.0:
				img.set_pixel(xx, yy, HeroSkin.GOLD_HI if d <= 7.5 else Color(0, 0, 0, 0.9))
	var tex := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", tex)
	s.add_theme_icon_override("grabber_highlight", tex)


func _on_reset() -> void:
	_ui._play_ui_sound(_ui.SOUND_TOGGLE)
	GameSettings.reset_to_defaults()
	_show_category(_category, false)


# ═════════════════════ Клавиатура и геймпад ═════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_nav or not is_visible_in_tree():
		return
	var handled := true
	if event.is_action_pressed("ui_down"):
		_move_sel(1)
	elif event.is_action_pressed("ui_up"):
		_move_sel(-1)
	elif event.is_action_pressed("ui_left"):
		_adjust(-1)
	elif event.is_action_pressed("ui_right"):
		_adjust(1)
	elif event.is_action_pressed("ui_accept"):
		_adjust(0)
	elif event.is_action_pressed("ui_focus_next") or _joy(event, JOY_BUTTON_RIGHT_SHOULDER):
		_cycle_category(1)
	elif event.is_action_pressed("ui_focus_prev") or _joy(event, JOY_BUTTON_LEFT_SHOULDER):
		_cycle_category(-1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _joy(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


func _set_sel(i: int, sound: bool) -> void:
	if _rows.is_empty():
		return
	i = clampi(i, 0, _rows.size() - 1)
	if sound and i != _sel:
		_ui._play_ui_sound(_ui.SOUND_CHOICE)
	_sel = i
	for k in _rows.size():
		var s := _rows[k].get_node_or_null("Sel") as Control
		if s:
			s.visible = k == _sel
	_describe(_rows[_sel].get_meta("def"))


func _move_sel(step: int) -> void:
	if _rows.is_empty():
		return
	_set_sel((_sel + step + _rows.size()) % _rows.size(), true)


## Изменить значение выбранной строки: ползунок — шагом, переключатель —
## на любое нажатие, выбор — стрелкой в ту же сторону (Enter — вперёд)
func _adjust(dir: int) -> void:
	if _sel < 0 or _sel >= _rows.size():
		return
	var row := _rows[_sel]
	if row.has_meta("slider"):
		if dir == 0:
			return
		var s: HSlider = row.get_meta("slider")
		var before := s.value
		s.value = clampf(s.value + s.step * 2.0 * dir, s.min_value, s.max_value)
		if s.value != before:
			_ui._play_ui_sound(_ui.SOUND_TOGGLE)
	elif row.has_meta("toggle"):
		(row.get_meta("toggle") as Button).pressed.emit()
	elif row.has_meta("arrow_next"):
		(row.get_meta("arrow_prev" if dir < 0 else "arrow_next") as Button).pressed.emit()


func _cycle_category(step: int) -> void:
	var i := 0
	for k in CATEGORIES.size():
		if CATEGORIES[k][0] == _category:
			i = k
	_show_category(CATEGORIES[(i + step + CATEGORIES.size()) % CATEGORIES.size()][0], true)
