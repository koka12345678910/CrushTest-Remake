extends CanvasLayer
## loot_ui.gd — экранные подсказки лута: внизу по центру "E  Подобрать", пока
## герой стоит у находки, а после подбора у правого края выезжает мини-панель
## с иконкой и названием и уезжает обратно, как флажок. Один на сцену,
## создаётся сам:
##   LootUI.of(get_tree()).show_prompt(true)
## Цвета и шрифт — как у магазина (Shop/shop_menu.gd): тёмная панель,
## тусклое золото, шрифт с засечками.

const C_PANEL := Color(0.045, 0.04, 0.036, 0.9)
const C_BORDER := Color(0.55, 0.45, 0.3, 0.65)
const C_GOLD := Color(0.78, 0.62, 0.37)
const C_TEXT := Color(0.9, 0.85, 0.75)
const C_TEXT_DIM := Color(0.62, 0.57, 0.48)

## Лента находок справа: верх ленты (доля высоты экрана), отступ от края,
## промежуток между панелями, сколько панель висит, откуда выезжает (за краем)
const FEED_TOP := 0.3
const EDGE := 22.0
const GAP := 8.0
const HOLD := 2.6
const OFF_X := 16.0

var _font: SystemFont
var _prompt: PanelContainer
var _feed: Control
var _toasts: Array[Control] = []
var _prompt_tween: Tween
var _prompt_on := false


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
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	_build_prompt()
	_build_feed()


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = C_BORDER
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.set_content_margin_all(14)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## Прижатая к низу экрана по центру панель (якоря — центр-низ)
func _anchor_bottom(c: Control, bottom_margin: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.offset_bottom = -bottom_margin


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _panel_style())
	_anchor_bottom(_prompt, 150)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_label("E", 26, C_GOLD))
	row.add_child(_label("Подобрать", 24, C_TEXT))
	_prompt.add_child(row)
	_prompt.modulate.a = 0.0
	_prompt.visible = false
	add_child(_prompt)


## Лента находок у правого края: пустой Control, прижатый к правому краю на
## трети высоты экрана — между полоской навыков сверху и быстрым слотом снизу.
## Панели внутри раскладываются вручную (не VBox): их надо двигать твинами
func _build_feed() -> void:
	_feed = Control.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.anchor_top = FEED_TOP
	_feed.anchor_bottom = FEED_TOP
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)


func _toast_style() -> StyleBoxFlat:
	var sb := _panel_style()
	sb.set_content_margin_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 18
	sb.border_width_left = 3
	sb.border_color = C_BORDER
	sb.shadow_size = 6
	return sb


## Мини-панель: иконка, название, подпись мелко
func _make_toast(icon: Texture2D, title: String, subtitle: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _toast_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if icon:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(34, 34)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(title, 19, C_TEXT))
	if subtitle != "":
		texts.add_child(_label(subtitle, 14, C_GOLD))
	row.add_child(texts)
	p.add_child(row)
	return p


func show_prompt(on: bool) -> void:
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


## Подобрал — справа выезжает мини-панель (иконка может быть null), висит и
## уезжает обратно за край, как флажок. Новая — сверху, старые сдвигаются вниз
func show_pickup(icon: Texture2D, title: String, subtitle: String) -> void:
	show_prompt(false)
	var t := _make_toast(icon, title, subtitle)
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
	# Уход — ускоряясь вправо за край
	tw.tween_property(t, "position:x", OFF_X, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.35).set_delay(0.12)
	tw.tween_callback(func():
		_toasts.erase(t)
		t.queue_free()
		_relayout())


## Раскладка ленты по высоте: каждая панель плавно едет на своё место
func _relayout() -> void:
	var y := 0.0
	for t in _toasts:
		if not is_instance_valid(t):
			continue
		if t.position.y != y:
			t.create_tween().tween_property(t, "position:y", y, 0.2) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		y += t.size.y + GAP
