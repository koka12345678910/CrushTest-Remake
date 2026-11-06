extends Control
## CharacterSelectPanel.gd — выбор героя при создании нового прохождения.
##
## Вид — как инвентарь героя (hero_inventory_skin.gd, тема CLEAN): три
## тёмные панели на затемнённом фоне меню:
##   слева  — список героев (клетки как разделы настроек инвентаря);
##   центр  — сам герой: анимация стойки Idle_Down с целым увеличением
##            (пиксель-арт без мыла), под ним цитата;
##   справа — имя, описание, характеристики и кнопка «Выбрать».
## Золото — только у выбранного.
##
## Список героев берётся из реестра Characters: добавишь четвёртого в
## Characters.DATA/ORDER — он появится здесь сам.
##
## Панель НИЧЕГО не сохраняет — только сообщает выбор сигналом. Слот заводит
## MainMenu.gd через SaveManager.create_slot().
##
## Управление: ↑↓ / ←→ — герой, Enter — выбрать, Esc — назад; мышью —
## клик по герою, двойной клик или кнопка «Выбрать».

signal character_chosen(id: String)
signal closed

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")
const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const CleanHud := preload("res://UI/clean_hud.gd")
# Скрипты подключаются через set_script, а не через class_name: глобальный
# кэш классов в этом проекте уже подводил ("Could not find type X")
const GlyphIconScript := preload("res://Main_Menu/scripts/GlyphIcon.gd")
const SpriteSheetAnimationScript := preload("res://Main_Menu/scripts/SpriteSheetAnimation.gd")

## Как и настройки, экран поднят: вкладок инвентаря здесь нет
const LIFT := 46.0
## Целое увеличение кадра 128×128 — пиксели героя остаются чёткими
const SPRITE_SCALE := 5
const STAT_SEGMENTS := 10

var _selected_id := ""
var _is_open := false
var _tween: Tween
var _audio: AudioStreamPlayer
var _content: Control
var _cells := {}   # id -> {"frame": HeroCell, "name": Label, "icon": GlyphIcon}
var _portrait: TextureRect
var _quote: Label
var _name_lbl: Label
var _tag_lbl: Label
var _desc_lbl: Label
var _stats_box: VBoxContainer
var _info: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio = Style.ui_player(self)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	if _selected_id == "":
		_selected_id = Characters.ORDER[0]
	_build()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_content, "position:y", _content.position.y, 0.34)\
		.from(_content.position.y + 18.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await _tween.finished
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		Style.play_back(_audio)
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_cycle_hero(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_cycle_hero(1)
	elif event.is_action_pressed("ui_accept"):
		_on_confirm()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Нужен HeroSkin.plaque (заголовок колонки) — как у inventory_ui
func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Style.TEXT)
	return l


# ═════════════════════ Вёрстка ═════════════════════

func _build() -> void:
	for c in get_children():
		if c != _audio:
			c.queue_free()
	_cells.clear()
	Style.make_dim(self)
	HeroSkin.use_theme(HeroSkin.CLEAN)
	var stage := Style.make_stage(self)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.position = Vector2(0, -LIFT)
	_content.size = Style.BASE
	stage.add_child(_content)

	var lay: Dictionary = HeroSkin.T["layout"]
	var top := float(HeroSkin.TOP)
	var h := float(HeroSkin.FRAME_H)
	var x0 := float(lay["x0"])
	var list_w := float(lay["right_w"])
	var stage_w := float(lay["grid_w"])
	var info_w := float(lay["detail_w"])
	_build_list(Rect2(x0, top, list_w, h))
	_build_stage(Rect2(x0 + list_w + 14, top, stage_w, h))
	_build_info(Rect2(x0 + list_w + 14 + stage_w + 14, top, info_w, h))

	var hints := Style.hint_row([["↑ ↓", "Герой"], ["Enter", "Выбрать"], ["Esc", "Назад"]])
	hints.position = Vector2(0, top + h + 22.0)
	hints.size = Vector2(Style.BASE.x, 32)
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(hints)

	_refresh_selection(false)


func _build_list(r: Rect2) -> void:
	var f := HeroSkin.build_frame(_content, r, null)
	var ty: float = f.position.y + float(HeroSkin.T["layout"]["title_dy"])
	HeroSkin.plaque(self, _content, "ВЫБОР ГЕРОЯ", f.position.x, f.size.x, ty)
	var cw := f.size.x - 40.0
	var y := f.position.y + HeroSkin.column_top()
	for id in Characters.ORDER:
		_make_cell(id, Rect2(f.position.x + 20.0, y, cw, 104))
		y += 118.0


func _make_cell(id: String, r: Rect2) -> void:
	var holder := Control.new()
	holder.position = r.position.round()
	holder.size = r.size
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(holder)
	HeroSkin.cell_plate(holder, r.size)
	var frame := HeroSkin.make_cell_frame()
	frame.size = r.size
	holder.add_child(frame)

	var icon := Control.new()
	icon.set_script(GlyphIconScript)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(26, r.size.y * 0.5 - 20)
	icon.size = Vector2(40, 40)
	holder.add_child(icon)

	var data := Characters.get_data(id)
	var name_l := Style.label(String(data.get("name", "?")), 24, Style.TEXT, true)
	name_l.position = Vector2(92, 22)
	name_l.size = Vector2(r.size.x - 104, 32)
	holder.add_child(name_l)
	var sub := Style.label(String(data.get("tagline", "")), 16, Style.TEXT_DIM)
	sub.position = Vector2(92, 56)
	sub.size = Vector2(r.size.x - 104, 24)
	holder.add_child(sub)

	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.double_click and id == _selected_id:
				_on_confirm()
			elif id != _selected_id:
				_selected_id = id
				Style.play_move(_audio)
				_refresh_selection(true))
	holder.mouse_entered.connect(func():
		if id != _selected_id:
			frame.highlight = 0.45)
	holder.mouse_exited.connect(func():
		frame.highlight = 1.0 if id == _selected_id else 0.0)
	_cells[id] = {"frame": frame, "name": name_l, "icon": icon}


func _build_stage(r: Rect2) -> void:
	var f := HeroSkin.build_frame(_content, r, null)
	# Тёплый свет сверху вниз и пятно пола под героем — чтобы фигура стояла,
	# а не висела в пустоте
	var glow := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.86, 0.6, 0.07), Color(1.0, 0.86, 0.6, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.0, 0.45)
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.position = f.position
	glow.size = f.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(glow)

	var box := Vector2(128, 128) * SPRITE_SCALE
	var center := Vector2(f.get_center().x, f.position.y + f.size.y * 0.44)
	var floor_y := center.y + box.y * 0.5 - box.y * 0.09
	var shadow := Control.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = Vector2(center.x - 160, floor_y - 20)
	shadow.size = Vector2(320, 40)
	shadow.draw.connect(func():
		for i in 8:
			var k := 1.0 - i / 8.0
			shadow.draw_set_transform(Vector2(160, 20), 0.0, Vector2(1.0, 0.22))
			shadow.draw_circle(Vector2.ZERO, 150.0 * k, Color(0, 0, 0, 0.09)))
	_content.add_child(shadow)
	HeroSkin.hline(_content, center.x - 260, 520, floor_y + 14)

	_portrait = TextureRect.new()
	_portrait.set_script(SpriteSheetAnimationScript)
	_portrait.position = (center - box * 0.5).round()
	_portrait.size = box
	_content.add_child(_portrait)

	_quote = Style.label("", 20, Style.TEXT_DIM)
	_quote.add_theme_font_override("font", Style.italic_font())
	_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote.position = Vector2(f.position.x + 40, f.end.y - 120)
	_quote.size = Vector2(f.size.x - 80, 80)
	_content.add_child(_quote)


func _build_info(r: Rect2) -> void:
	var f := HeroSkin.build_frame(_content, r, null)
	var ty: float = f.position.y + float(HeroSkin.T["layout"]["title_dy"])
	HeroSkin.plaque(self, _content, "О ГЕРОЕ", f.position.x, f.size.x, ty)

	_info = Control.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.position = Vector2(f.position.x + 34, f.position.y + HeroSkin.column_top())
	_info.size = Vector2(f.size.x - 68, f.size.y - HeroSkin.column_top() - 140)
	_content.add_child(_info)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size = _info.size
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(v)

	_name_lbl = Style.label("", 36, Style.GOLD_HI, true)
	v.add_child(_name_lbl)
	_tag_lbl = Style.label("", 17, Style.TEXT_DIM, true)
	v.add_child(_tag_lbl)
	var line := Style.FadeLine.new()
	line.color = Color(Style.GOLD, 0.3)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	_desc_lbl = Style.label("", 19, Style.TEXT)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(_info.size.x, 0)
	v.add_child(_desc_lbl)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap2)
	var cap := Style.label("ХАРАКТЕРИСТИКИ", 15, Style.TEXT_DIM, true)
	v.add_child(cap)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 12)
	v.add_child(_stats_box)

	var btn := Style.chip_button("ВЫБРАТЬ", 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(f.position.x + 34, f.end.y - 96)
	btn.size = Vector2(f.size.x - 68, 56)
	btn.pressed.connect(_on_confirm)
	btn.mouse_entered.connect(func(): Style.play_move(_audio))
	_content.add_child(btn)


func _fill_stats(id: String) -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	for stat in Characters.STAT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_box.add_child(row)

		var icon := Control.new()
		icon.set_script(GlyphIconScript)
		icon.custom_minimum_size = Vector2(20, 20)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.call("set_glyph", Characters.STAT_ICONS.get(stat, "rune"), Color(Style.GOLD, 0.8))
		row.add_child(icon)

		var lbl := Style.label(String(Characters.STAT_NAMES.get(stat, stat)), 18, Style.TEXT)
		lbl.custom_minimum_size = Vector2(160, 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

		var value := clampf(Characters.get_stat(id, stat), 0.0, 1.0)
		var bar := StatBar.new()
		bar.value = value
		bar.custom_minimum_size = Vector2(220, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)

		# Число рядом с полоской: длину не надо угадывать на глаз
		var num := Style.label("%d" % roundi(value * STAT_SEGMENTS), 17, Style.TEXT_DIM)
		num.custom_minimum_size = Vector2(28, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(num)


## Полоска характеристики в духе полосок HUD: тёмный канал, светлая
## заливка, деления по 1/10
class StatBar extends Control:
	var value := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(0, roundf((size.y - 8) * 0.5)), Vector2(size.x, 8))
		draw_rect(r, CleanHud.TRACK)
		draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * value), r.size.y)), Color(CleanHud.TEXT, 0.82))
		for i in range(1, 10):
			var x := roundf(r.size.x * i / 10.0)
			draw_rect(Rect2(x, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.55))
		draw_rect(r, CleanHud.BORDER, false, 1.0)


# ═════════════════════ Выбор ═════════════════════

func _cycle_hero(step: int) -> void:
	var order := Characters.ORDER
	var idx := order.find(_selected_id)
	if idx == -1:
		idx = 0
	_selected_id = order[(idx + step + order.size()) % order.size()]
	Style.play_move(_audio)
	_refresh_selection(true)


func _refresh_selection(animate: bool) -> void:
	var data := Characters.get_data(_selected_id)
	for id in _cells:
		var parts: Dictionary = _cells[id]
		var active: bool = id == _selected_id
		parts["frame"].highlight = 1.0 if active else 0.0
		(parts["name"] as Label).add_theme_color_override("font_color", Style.GOLD_HI if active else Style.TEXT)
		# Цвет класса — только у значка выбранного, остальные серые
		parts["icon"].call("set_glyph", Characters.get_data(id).get("icon", "rune"),
			Characters.get_color(id) if active else Color(Style.TEXT_DIM, 0.7))

	if is_instance_valid(_portrait):
		var region := Characters.get_idle_region(_selected_id)
		_portrait.call("setup", Characters.get_idle_sheet(_selected_id),
			region.position.y, region.size, Characters.get_idle_frame_time(_selected_id))
	_name_lbl.text = String(data.get("name", "?"))
	_tag_lbl.text = String(data.get("tagline", ""))
	_desc_lbl.text = String(data.get("description", ""))
	# Цитату переводим до склейки строк: ключ перевода — с переносом \n
	_quote.text = "«%s»" % tr(String(data.get("quote", ""))).replace("\n", " ")
	_fill_stats(_selected_id)

	if animate:
		for c: CanvasItem in [_portrait, _info, _quote]:
			c.modulate.a = 0.0
			create_tween().tween_property(c, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)


func _on_confirm() -> void:
	if _selected_id == "":
		Style.play(_audio, Style.SOUND_DENIED)
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	character_chosen.emit(_selected_id)
