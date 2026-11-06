extends RefCounted
## MenuStyle.gd — общий вид главного меню в ключе инвентаря и HUD.
##
## Своей палитры у меню больше нет: цвета, шрифт и плашки берутся из
## UI/clean_hud.gd (а тот — из темы CLEAN инвентаря, hero_inventory_skin.gd).
## Тёмные почти непрозрачные панели, кайма в 7% белого, текст тёплый
## почти белый, золото — только на выбранном/наведённом.
##
## Подключается через preload (как остальные помощники меню), без class_name.

const CleanHud := preload("res://UI/clean_hud.gd")
const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")

const GOLD := CleanHud.GOLD
const GOLD_HI := CleanHud.GOLD_HI
const TEXT := CleanHud.TEXT
const TEXT_DIM := CleanHud.TEXT_DIM
const LINE := CleanHud.LINE
const BORDER := CleanHud.BORDER
## Заливка панелей инвентаря (CLEAN["pal"]["fill"]): почти чёрная, почти
## непрозрачная — фон меню сквозь неё не читается
const PANEL_FILL := Color(0.012, 0.012, 0.012, 0.95)
## Затемнение всего экрана под панелями (как world_dim инвентаря)
const SCREEN_DIM := Color(0.0, 0.0, 0.0, 0.78)

## Звуки интерфейса — общие для всей игры (UI/ui_sounds.gd): короткие тихие
## щелчки на шине "UI", которая идёт в эффекты (ползунок «Эффекты»)
const UiSounds := preload("res://UI/ui_sounds.gd")
const SOUND_ACCEPT := UiSounds.SELECT
const SOUND_CHOICE := UiSounds.MOVE
const SOUND_DENIED := UiSounds.ERROR
const SOUND_TOGGLE := UiSounds.TOGGLE
const SOUND_OPEN := UiSounds.OPEN
const SOUND_BACK := UiSounds.BACK
## Базовый размер экрана: панели меню свёрстаны под него (как инвентарь)
const BASE := Vector2(1920, 1080)

static var _caps: FontVariation
static var _italic: SystemFont


static func font() -> Font:
	return CleanHud.font()


## Та же антиква с разрядкой — для заглавных пунктов и заголовков (как
## разрядка в меню DS3)
static func caps_font() -> Font:
	if _caps == null:
		_caps = FontVariation.new()
		_caps.base_font = CleanHud.font()
		_caps.spacing_glyph = 3
	return _caps


static func italic_font() -> Font:
	if _italic == null:
		_italic = SystemFont.new()
		_italic.font_names = CleanHud.font().font_names
		_italic.font_italic = true
	return _italic


## Тема для корня панели: шрифт инвентаря у всех Label/Button внутри.
## CanvasLayer рвёт наследование темы, поэтому её ставят на каждый корень
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	return t


static func label(text: String, font_size: int, color := TEXT, caps := false) -> Label:
	var l := CleanHud.label(text, font_size, color)
	if caps:
		l.add_theme_font_override("font", caps_font())
	return l


## Плашка как у панелей инвентаря
static func panel_box(radius := 6) -> StyleBoxFlat:
	return CleanHud.box(radius, PANEL_FILL, BORDER)


## Кнопка-плашка как «Сбросить всё»/«Назад» в настройках инвентаря. Фокус
## выглядит так же, как наведение: с клавиатуры и геймпада видно, где ты
static func chip_button(text: String, font_size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", caps_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD_HI)
	b.add_theme_color_override("font_focus_color", GOLD_HI)
	b.add_theme_color_override("font_pressed_color", GOLD_HI)
	b.add_theme_color_override("font_hover_pressed_color", GOLD_HI)
	b.add_theme_color_override("font_disabled_color", Color(TEXT_DIM, 0.5))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var lit: bool = st == "hover" or st == "pressed" or st == "focus"
		sb.bg_color = Color(GOLD_HI, 0.08) if lit else Color(0, 0, 0, 0.5)
		sb.border_color = Color(GOLD, 0.9 if lit else (0.2 if st == "disabled" else 0.5))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.anti_aliasing = false
		b.add_theme_stylebox_override(st, sb)
	# Наведение мышью = фокус: одно состояние на всё, клавиатура подхватывает
	# с того места, куда показала мышь
	b.mouse_entered.connect(func():
		if not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	return b


## Подсказка клавиши: тёмная плашка с каймой, как значки клавиш в HUD
static func key_chip(key: String, font_size := 15) -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(1, 1, 1, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", sb)
	var l := label(key, font_size, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


## Строка подсказок «[клавиша] действие  [клавиша] действие» — как внизу
## инвентаря. pairs: [[клавиша, действие], ...]
static func hint_row(pairs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	for i in pairs.size():
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(18, 0)
			row.add_child(gap)
		row.add_child(key_chip(pairs[i][0]))
		var l := label(pairs[i][1], 17, TEXT_DIM, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	return row


## Плеер звуков интерфейса на шине "UI"
static func ui_player(parent: Node) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = UiSounds.bus()
	parent.add_child(p)
	return p


static func play(p: AudioStreamPlayer, stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if p == null:
		return
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Наведение/перемещение по пунктам — самый тихий тик с лёгким разбросом
## высоты, чтобы частое листание не звенело одной нотой
static func play_move(p: AudioStreamPlayer) -> void:
	play(p, SOUND_CHOICE, -5.0, randf_range(0.97, 1.04))


static func play_back(p: AudioStreamPlayer) -> void:
	play(p, SOUND_BACK, -2.0)


## Всплывающее окно (подтверждение, памятка)
static func play_open(p: AudioStreamPlayer) -> void:
	play(p, SOUND_OPEN, -4.0)


## Затемнение экрана под окнами: чёрный 78% + тёмные края
static func make_dim(parent: Control, alpha := SCREEN_DIM.a) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var vig := TextureRect.new()
	vig.texture = vignette_texture(0.6)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(vig)
	return dim


## Радиальная виньетка: прозрачный центр, к краям — чёрный strength
static func vignette_texture(strength := 0.55) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, strength * 0.35), Color(0, 0, 0, strength)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.08, 1.08)
	t.width = 256
	t.height = 256
	return t


## «Сцена» 1920x1080 по центру экрана: панели свёрстаны в базовых
## координатах (как инвентарь) и на широких экранах не разъезжаются к краю
static func make_stage(parent: Control) -> Control:
	var st := Control.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.anchor_left = 0.5
	st.anchor_right = 0.5
	st.anchor_top = 0.5
	st.anchor_bottom = 0.5
	st.offset_left = -BASE.x * 0.5
	st.offset_right = BASE.x * 0.5
	st.offset_top = -BASE.y * 0.5
	st.offset_bottom = BASE.y * 0.5
	st.theme = make_theme()
	parent.add_child(st)
	return st


## Тонкая черта, растворяющаяся к концам (как разделители инвентаря)
static func fade_line(parent: Control, pos: Vector2, width: float, color := LINE) -> Control:
	var l := FadeLine.new()
	l.color = color
	l.position = pos.round()
	l.size = Vector2(roundf(width), 1)
	parent.add_child(l)
	return l


class FadeLine extends Control:
	var color := Color(1, 1, 1, 0.08)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := 24
		var w := size.x / n
		for i in n:
			var t := (i + 0.5) / n
			var a := 1.0 - absf(t - 0.5) * 2.0
			draw_rect(Rect2(i * w, 0, w + 0.5, 1), Color(color, color.a * smoothstep(0.0, 0.6, a)))


## Подсветка выбранной строки: золотая черта слева + полоса света,
## гаснущая вправо (как подсветка выбранного в инвентаре, только строкой)
static func draw_row_highlight(c: CanvasItem, r: Rect2, k: float) -> void:
	if k <= 0.001:
		return
	var n := 16
	var w := r.size.x / n
	for i in n:
		var t := float(i) / n
		c.draw_rect(Rect2(r.position.x + i * w, r.position.y, w + 0.5, r.size.y),
			Color(GOLD_HI, 0.075 * k * (1.0 - t) * (1.0 - t)))
	c.draw_rect(Rect2(r.position.x, r.position.y + 4, 2, r.size.y - 8), Color(GOLD, 0.95 * k))
