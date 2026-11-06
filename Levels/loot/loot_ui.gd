extends CanvasLayer
## loot_ui.gd — экранные подсказки лута в ключе инвентаря (UI/clean_hud.gd):
## внизу по центру "E  Подобрать", пока герой стоит у находки; после подбора
## у правого края выезжает плашка с иконкой, названием и подсказкой
## "Нажмите Tab, чтобы узнать подробнее" и уезжает обратно, как флажок.
## Пока плашка видна, Tab открывает панель находки: большая иконка, предание
## (откуда вещь в мире) и назначение (что она даёт в игре). Игра на паузе,
## Tab или Esc закрывают. Один на сцену, создаётся сам:
##   LootUI.of(get_tree()).show_prompt(true)

const Clean := preload("res://UI/clean_hud.gd")

## Лента находок справа: верх ленты (доля высоты экрана), отступ от края,
## промежуток между плашками, сколько плашка висит, откуда выезжает (за краем)
const FEED_TOP := 0.3
const EDGE := 26.0
const GAP := 10.0
const HOLD := 5.0
const OFF_X := 16.0

## Панель находки: размер и колонка иконки (в макете 1920x1080)
const CARD := Vector2(1100, 620)
const ICON_CELL := 400.0
const PAD := 44.0

var _prompt: PanelContainer
var _prompt_label: Label
var _feed: Control
var _toasts: Array[Control] = []
var _prompt_tween: Tween
var _prompt_on := false

var _card_root: Control
var _card_backdrop: ColorRect
var _card_panel: Control
var _card_icon: TextureRect
var _card_title: Label
var _card_subtitle: Label
var _card_lore: Label
var _card_desc: Label
var _card_open := false
var _card_closing := false
var _hidden_layers: Array[CanvasLayer] = []


static func of(tree: SceneTree) -> CanvasLayer:
	var root := tree.current_scene if tree.current_scene else tree.root
	var ui := root.get_node_or_null("LootUI") as CanvasLayer
	if ui == null:
		ui = load("res://Levels/loot/loot_ui.gd").new()
		ui.name = "LootUI"
		root.add_child(ui)
	return ui


func _ready() -> void:
	layer = 8
	# Панель находки ставит игру на паузу — сам слой должен жить и на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_prompt()
	_build_feed()
	_build_card()


func _box(r := 4, shadow := 0) -> StyleBoxFlat:
	var sb := Clean.ProcSkin.CleanU.box(Clean.FILL, Clean.BORDER, r, shadow)
	return sb


## Прижатая к низу экрана по центру панель (якоря — центр-низ)
func _anchor_bottom(c: Control, bottom_margin: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.offset_bottom = -bottom_margin


## Клавиша в рамке ("E", "Tab") — как подпись клавиши на клетке слота
func _keycap(text: String, font_size: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Clean.ProcSkin.CleanU.box(Color(0, 0, 0, 0.35), Color(Clean.TEXT, 0.35), 3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Clean.label(text, font_size, Clean.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	var sb := _box(4, 8)
	sb.content_margin_left = 22
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_prompt.add_theme_stylebox_override("panel", sb)
	_anchor_bottom(_prompt, 170)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_keycap("E", 22))
	_prompt_label = Clean.label("Подобрать", 24, Clean.TEXT)
	row.add_child(_prompt_label)
	_prompt.add_child(row)
	_prompt.modulate.a = 0.0
	_prompt.visible = false
	add_child(_prompt)


## Лента находок у правого края: пустой Control, прижатый к правому краю на
## трети высоты экрана — между полоской навыков сверху и быстрым слотом снизу.
## Плашки внутри раскладываются вручную (не VBox): их надо двигать твинами
func _build_feed() -> void:
	_feed = Control.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.anchor_top = FEED_TOP
	_feed.anchor_bottom = FEED_TOP
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)


## Плашка: иконка в клетке, название, подпись мелко; есть подробности —
## внизу подсказка про Tab
func _make_toast(icon: Texture2D, title: String, subtitle: String, has_info: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(4, 6)
	sb.set_content_margin_all(12)
	sb.content_margin_right = 22
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	if icon:
		var cell := PanelContainer.new()
		var cb := Clean.ProcSkin.CleanU.box(Color(0, 0, 0, 0.32), Clean.BORDER, 4)
		cb.set_content_margin_all(4)
		cell.add_theme_stylebox_override("panel", cb)
		var ic := TextureRect.new()
		ic.material = Clean.icon_material()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(56, 56)
		ic.texture = icon
		cell.add_child(ic)
		row.add_child(cell)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.add_child(Clean.label(title, 22, Clean.GOLD))
	if subtitle != "":
		texts.add_child(Clean.label(subtitle, 16, Clean.TEXT_DIM))
	if has_info:
		var hint := HBoxContainer.new()
		hint.add_theme_constant_override("separation", 8)
		hint.add_child(Clean.label("Нажмите", 16, Clean.TEXT_DIM))
		# Запятая — вплотную к клавише
		var key := HBoxContainer.new()
		key.add_theme_constant_override("separation", 2)
		key.add_child(_keycap("Tab", 14))
		# В английском «Press [Tab] to learn more» запятой нет: её «перевод» —
		# пробел нулевой ширины (Localization/strings_en.gd)
		key.add_child(Clean.label(",", 16, Clean.TEXT_DIM))
		hint.add_child(key)
		hint.add_child(Clean.label("чтобы узнать подробнее", 16, Clean.TEXT_DIM))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		texts.add_child(gap)
		texts.add_child(hint)
	row.add_child(texts)
	p.add_child(row)
	return p


## text — что делает E (у лута «Подобрать», у костра — своё, bonfire.gd)
func show_prompt(on: bool, text := "Подобрать") -> void:
	if on:
		_prompt_label.text = text
	if on == _prompt_on:
		return
	_prompt_on = on
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt.visible = true
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0 if on else 0.0, 0.15)
	if not on:
		_prompt_tween.tween_callback(_prompt.hide)


## Подобрал — справа выезжает плашка (иконка может быть null), висит и
## уезжает обратно за край, как флажок. Новая — сверху, старые сдвигаются
## вниз. info {"lore", "desc"} — подробности для панели по Tab (пусто — без
## подсказки)
func show_pickup(icon: Texture2D, title: String, subtitle: String, info := {}) -> void:
	show_prompt(false)
	var has_info: bool = info.get("lore", "") != "" or info.get("desc", "") != ""
	var t := _make_toast(icon, title, subtitle, has_info)
	if has_info:
		t.set_meta("card", {"icon": icon, "title": title, "subtitle": subtitle,
				"lore": info.get("lore", ""), "desc": info.get("desc", "")})
	_feed.add_child(t)
	t.size = t.get_combined_minimum_size()
	# Стартует за правым краем, у верха ленты
	t.position = Vector2(OFF_X, 0.0)
	t.modulate.a = 0.0
	_toasts.push_front(t)
	_relayout()
	var tw := t.create_tween()
	tw.tween_property(t, "position:x", -t.size.x - EDGE, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "modulate:a", 1.0, 0.2)
	tw.tween_interval(HOLD)
	tw.tween_callback(func(): _dismiss(t, false))
	t.set_meta("tween", tw)


## Плашка уходит — ускоряясь вправо за край
func _dismiss(t: Control, kill_hold := true) -> void:
	if not is_instance_valid(t) or t.has_meta("leaving"):
		return
	t.set_meta("leaving", true)
	var old: Tween = t.get_meta("tween")
	if kill_hold and old and old.is_valid():
		old.kill()
	var tw := t.create_tween()
	tw.tween_property(t, "position:x", OFF_X, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.35).set_delay(0.12)
	tw.tween_callback(func():
		_toasts.erase(t)
		t.queue_free()
		_relayout())


## Раскладка ленты по высоте: каждая плашка плавно едет на своё место
func _relayout() -> void:
	var y := 0.0
	for t in _toasts:
		if not is_instance_valid(t):
			continue
		if t.position.y != y:
			t.create_tween().tween_property(t, "position:y", y, 0.2) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		y += t.size.y + GAP


# ===================== ПАНЕЛЬ НАХОДКИ (Tab) =====================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var tab: bool = event.physical_keycode == KEY_TAB or event.keycode == KEY_TAB
	if _card_open:
		if tab or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close_card()
		return
	if not tab:
		return
	# Свежайшая видимая плашка с подробностями; при открытом инвентаре,
	# магазине и т.п. (игра уже на паузе) — не открываем
	if get_tree().paused:
		return
	for t in _toasts:
		if is_instance_valid(t) and t.has_meta("card") and not t.has_meta("leaving"):
			get_viewport().set_input_as_handled()
			open_card(t.get_meta("card"))
			_dismiss(t)
			return


func _build_card() -> void:
	_card_root = Control.new()
	_card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_root.visible = false
	add_child(_card_root)

	# Мир за панелью — затемнён, как за инвентарём
	_card_backdrop = ColorRect.new()
	_card_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_backdrop.color = Color(0, 0, 0, 0.55)
	_card_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(_card_backdrop)

	var center := Control.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(center)

	_card_panel = Clean.Plate.new()
	_card_panel.radius = 6
	_card_panel.position = -CARD * 0.5
	_card_panel.size = CARD
	_card_panel.pivot_offset = CARD * 0.5
	center.add_child(_card_panel)

	# Левая колонка — большая иконка в клетке
	var cell := Clean.Plate.new()
	cell.fill = Color(0, 0, 0, 0.32)
	cell.position = Vector2(PAD, PAD)
	cell.size = Vector2(ICON_CELL, ICON_CELL)
	_card_panel.add_child(cell)
	_card_icon = TextureRect.new()
	_card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_icon.material = Clean.icon_material(1.1)
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.position = Vector2(24, 24)
	_card_icon.size = Vector2(ICON_CELL - 48.0, ICON_CELL - 48.0)
	cell.add_child(_card_icon)

	_card_subtitle = Clean.label("", 18, Clean.TEXT_DIM)
	_card_subtitle.position = Vector2(PAD, PAD + ICON_CELL + 16.0)
	_card_subtitle.size = Vector2(ICON_CELL, 26)
	_card_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_panel.add_child(_card_subtitle)

	# Правая колонка — название, предание, назначение
	var x := PAD + ICON_CELL + 44.0
	var w := CARD.x - x - PAD
	_card_title = Clean.label("", 34, Clean.GOLD)
	_card_title.position = Vector2(x, PAD - 6.0)
	_card_title.size = Vector2(w, 44)
	_card_title.clip_text = true
	_card_panel.add_child(_card_title)
	_line(Vector2(x, PAD + 48.0), 120.0, Color(Clean.GOLD, 0.45))

	var y := PAD + 76.0
	_card_panel.add_child(_section("ПРЕДАНИЕ", Vector2(x, y)))
	_card_lore = _body(Vector2(x, y + 30.0), Vector2(w, 200))
	y += 30.0 + 200.0 + 18.0
	_line(Vector2(x, y), w, Clean.LINE)
	y += 20.0
	_card_panel.add_child(_section("НАЗНАЧЕНИЕ", Vector2(x, y)))
	_card_desc = _body(Vector2(x, y + 30.0), Vector2(w, CARD.y - PAD - 40.0 - (y + 30.0)))

	# Подсказка закрытия — внизу справа
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 8)
	hint.add_child(_keycap("Tab", 14))
	hint.add_child(Clean.label("/", 16, Clean.TEXT_DIM))
	hint.add_child(_keycap("Esc", 14))
	hint.add_child(Clean.label("закрыть", 16, Clean.TEXT_DIM))
	hint.size = hint.get_combined_minimum_size()
	hint.position = Vector2(CARD.x - PAD - hint.size.x, CARD.y - PAD + 6.0 - hint.size.y)
	_card_panel.add_child(hint)


func _section(text: String, pos: Vector2) -> Label:
	var l := Clean.label(text, 16, Clean.TEXT_DIM)
	l.position = pos
	l.size = Vector2(300, 24)
	return l


func _body(pos: Vector2, sz: Vector2) -> Label:
	var l := Clean.label("", 20, Clean.TEXT)
	l.position = pos
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.add_theme_constant_override("line_spacing", 4)
	_card_panel.add_child(l)
	return l


func _line(pos: Vector2, w: float, col: Color) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = col
	r.position = pos
	r.size = Vector2(w, 1)
	_card_panel.add_child(r)


## card: {icon, title, subtitle, lore, desc}
func open_card(card: Dictionary) -> void:
	if _card_open:
		return
	_card_open = true
	_card_closing = false
	_card_icon.texture = card.get("icon")
	_card_title.text = card.get("title", "")
	_card_subtitle.text = card.get("subtitle", "")
	_card_lore.text = card.get("lore", "")
	_card_desc.text = card.get("desc", "")
	# Мир — на паузу, игровой HUD прячется (как при открытом инвентаре)
	get_tree().paused = true
	_hide_game_hud(true)
	_card_root.visible = true
	_card_backdrop.modulate.a = 0.0
	_card_panel.modulate = Color(1, 1, 1, 0)
	_card_panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel()
	tw.tween_property(_card_backdrop, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card_panel, "modulate", Color.WHITE, 0.18)
	tw.tween_property(_card_panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func close_card() -> void:
	if not _card_open or _card_closing:
		return
	_card_closing = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_card_backdrop, "modulate:a", 0.0, 0.15)
	tw.tween_property(_card_panel, "modulate", Color(1, 1, 1, 0), 0.14)
	tw.tween_property(_card_panel, "scale", Vector2(0.96, 0.96), 0.14)
	await tw.finished
	_card_root.visible = false
	_hide_game_hud(false)
	get_tree().paused = false
	_card_open = false
	_card_closing = false


## Прячет прочие слои интерфейса (CanvasLayer с layer >= 1) на время панели
func _hide_game_hud(on: bool) -> void:
	if not on:
		for l in _hidden_layers:
			if is_instance_valid(l):
				l.visible = true
		_hidden_layers.clear()
		return
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var l := n as CanvasLayer
		if l == self or not l.visible or l.layer < 1:
			continue
		l.visible = false
		_hidden_layers.append(l)
