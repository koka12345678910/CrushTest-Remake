extends CanvasLayer
## bonfire_ui.gd — всё, что видно у костра (bonfire.gd): затемнение экрана
## на отдых и перемещение, надпись «КОСТЁР ЗАЖЖЁН» и панель костра.
##
## Панель — слева, как меню костра в Dark Souls 3: имя костра и пункты
## «Перемещение» (список других зажжённых костров), «Сумка» (инвентарь
## героя) и «Покинуть костёр». Управление: W/S или стрелки, E/Enter — выбрать,
## Esc — назад/уйти; мышью — наведение и клик.
##
## Мир на паузу не ставится (как в DS3): герой просто стоит (is_in_shop —
## тот же флаг, что держит его у магазина), враги после отдыха и так далеко.
## Слой живёт и на паузе — сумка ставит игру на паузу, пока открыта.

const Clean := preload("res://UI/clean_hud.gd")
const UiSounds := preload("res://UI/ui_sounds.gd")
const SOUND_MOVE := UiSounds.MOVE
const SOUND_ACCEPT := UiSounds.SELECT

const PANEL_W := 440.0
const FADE_OUT := 0.35
const FADE_IN := 0.5

var _fade: ColorRect
var _banner: Control
var _banner_label: Label
var _panel: Control
var _shade: TextureRect
var _col: VBoxContainer
var _title: Label
var _subtitle: Label
var _list: VBoxContainer
var _hint: Label
var _audio: AudioStreamPlayer

var _bonfire: Node2D
var _hero: Node2D
var _open := false
var _transition := false
var _inventory_open := false
## Кнопки текущего списка: [{label, action}], выбранный — _sel
var _items: Array = []
var _sel := 0
var _rows: Array[Control] = []
var _travel_mode := false
## После выхода — короткая пауза, чтобы та же E не открыла костёр снова
var _cooldown_until := 0


static func of(tree: SceneTree) -> CanvasLayer:
	var root := tree.current_scene if tree.current_scene else tree.root
	var ui := root.get_node_or_null("BonfireUI") as CanvasLayer
	if ui == null:
		ui = load("res://Levels/bonfire/bonfire_ui.gd").new()
		ui.name = "BonfireUI"
		root.add_child(ui)
	return ui


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = AudioStreamPlayer.new()
	_audio.bus = UiSounds.bus()
	add_child(_audio)
	_build_panel()
	_build_banner()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


## Занят ли костёр: открыта панель, идёт затемнение или только что ушли
func is_busy() -> bool:
	return _open or _transition or Time.get_ticks_msec() < _cooldown_until


# ===================== ПОСТРОЕНИЕ =====================

func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)

	# Тень слева — меню читается на любом фоне, справа мир остаётся виден
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(shade)
	_shade = shade

	var col := VBoxContainer.new()
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_top = -230.0
	col.offset_bottom = 230.0
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_col = col
	_place_panel(false)

	_title = Clean.label("Костёр", 38, Clean.GOLD_HI)
	col.add_child(_title)
	_subtitle = Clean.label("", 18, Clean.TEXT_DIM)
	col.add_child(_subtitle)
	var line := ColorRect.new()
	line.color = Color(Clean.GOLD, 0.45)
	line.custom_minimum_size = Vector2(PANEL_W, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_list)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap2)
	_hint = Clean.label("W/S — выбор    E — выбрать    Esc — назад", 15, Clean.TEXT_DIM)
	col.add_child(_hint)


## Панель слева, как в DS3, — но если герой с костром на экране слева (у
## края карты камера упирается в границу), она уходит направо, чтобы не
## закрывать огонь
func _place_panel(right: bool) -> void:
	var shade_w := PANEL_W + 380.0
	if right:
		_shade.anchor_left = 1.0
		_shade.anchor_right = 1.0
		_shade.offset_left = -shade_w
		_shade.offset_right = 0.0
		_shade.flip_h = true
		_col.anchor_left = 1.0
		_col.anchor_right = 1.0
		_col.offset_left = -90.0 - PANEL_W
		_col.offset_right = -90.0
	else:
		_shade.anchor_left = 0.0
		_shade.anchor_right = 0.0
		_shade.offset_left = 0.0
		_shade.offset_right = shade_w
		_shade.flip_h = false
		_col.anchor_left = 0.0
		_col.anchor_right = 0.0
		_col.offset_left = 90.0
		_col.offset_right = 90.0 + PANEL_W


func _hero_on_left() -> bool:
	if not is_instance_valid(_hero):
		return false
	var x: float = _hero.get_global_transform_with_canvas().origin.x
	return x < get_viewport().get_visible_rect().size.x * 0.5


func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_banner.visible = false
	add_child(_banner)
	# Тёмная полоса через экран с мягкими краями сверху и снизу
	var band := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	band.texture = gt
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = -80.0
	band.offset_bottom = 80.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(band)
	_banner_label = Clean.label("", 64, Color(1.0, 0.78, 0.42))
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.anchor_right = 1.0
	_banner_label.anchor_top = 0.5
	_banner_label.anchor_bottom = 0.5
	_banner_label.offset_top = -50.0
	_banner_label.offset_bottom = 50.0
	_banner_label.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.02, 0.8))
	_banner_label.add_theme_constant_override("outline_size", 10)
	_banner.add_child(_banner_label)


# ===================== НАДПИСЬ =====================

## «КОСТЁР ЗАЖЖЁН» — проступает, держится и медленно гаснет, как в DS
func show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_label.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_banner.hide)


# ===================== ОТДЫХ =====================

## Сесть у костра: затемнение, отдых (bonfire.rest), панель
func open_rest(bonfire: Node2D, hero: Node2D) -> void:
	if is_busy():
		return
	_bonfire = bonfire
	_hero = hero
	_set_hero_locked(true)
	_transition = true
	await _fade_to(1.0, FADE_OUT)
	bonfire.rest(hero)
	_show_menu()
	await _fade_to(0.0, FADE_IN)
	_transition = false


## Перемещение к другому зажжённому костру: затемнение, герой у цели, там же
## отдых (как в DS3 — прибытие к костру и есть отдых)
func _travel(target: Node2D) -> void:
	_transition = true
	_play(SOUND_ACCEPT)
	_panel.visible = false
	await _fade_to(1.0, FADE_OUT)
	if is_instance_valid(_hero):
		_hero.global_position = target.rest_position()
		_hero.set("velocity", Vector2.ZERO)
		_face_bonfire(target)
	_bonfire = target
	target.rest(_hero)
	_show_menu()
	# Камера догоняет героя со сглаживанием — без сброса она бы ехала через карту
	await get_tree().process_frame
	if is_instance_valid(_hero):
		var cam := _hero.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_smoothing()
	await get_tree().process_frame
	# Сторона панели — по новому положению героя на экране
	_place_panel(_hero_on_left())
	await _fade_to(0.0, FADE_IN)
	_transition = false


func _leave() -> void:
	_play(SOUND_ACCEPT)
	_open = false
	_panel.visible = false
	_cooldown_until = Time.get_ticks_msec() + 350
	# Отпускаем героя чуть позже: клик ЛКМ по «Покинуть» — это ещё и нажатие
	# удара, и в этот же кадр герой замахнулся бы
	get_tree().create_timer(0.15).timeout.connect(_set_hero_locked.bind(false))


func _open_bag() -> void:
	var inv = _hero.get("inventory_ui") if is_instance_valid(_hero) else null
	if inv == null:
		return
	_play(SOUND_ACCEPT)
	_inventory_open = true
	_panel.visible = false
	inv.open()
	await inv.closed
	_inventory_open = false
	if _open:
		_panel.visible = true


func _set_hero_locked(on: bool) -> void:
	if is_instance_valid(_hero) and "is_in_shop" in _hero:
		_hero.is_in_shop = on
	if on and is_instance_valid(_bonfire):
		_face_bonfire(_bonfire)
		# Стойка лицом к огню, а не застывший кадр бега
		if _hero.has_method("play_idle_animation"):
			_hero.play_idle_animation()


## Герой смотрит на огонь
func _face_bonfire(b: Node2D) -> void:
	if not is_instance_valid(_hero) or not _hero.has_method("get_direction"):
		return
	var to := b.global_position - _hero.global_position
	if to.length() < 0.01:
		return
	var dir_name: String = _hero.get_direction(to.normalized())
	if dir_name != "":
		_hero.set("facing_dir", to.normalized())
		_hero.set("last_direction", dir_name)


func _fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


# ===================== МЕНЮ =====================

func _show_menu() -> void:
	_open = true
	_travel_mode = false
	_title.text = _bonfire.bonfire_name
	_subtitle.text = "Силы восстановлены · мир пробудился · сохранено"
	_set_items([
		{"label": "Перемещение", "action": "travel"},
		{"label": "Сумка", "action": "bag"},
		{"label": "Покинуть костёр", "action": "leave"},
	])
	_place_panel(_hero_on_left())
	_panel.visible = true


func _show_travel() -> void:
	_travel_mode = true
	var items := []
	for b in get_tree().get_nodes_in_group("bonfire"):
		if b == _bonfire or not b.lit:
			continue
		items.append({"label": b.bonfire_name, "action": "go", "target": b})
	if items.is_empty():
		_subtitle.text = "Других зажжённых костров нет"
	else:
		_subtitle.text = "Куда отправиться?"
	items.append({"label": "Назад", "action": "back"})
	_set_items(items)


func _set_items(items: Array) -> void:
	_items = items
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in items.size():
		var row := _make_row(items[i]["label"], i)
		_list.add_child(row)
		_rows.append(row)
	_sel = 0
	_refresh_rows()


func _make_row(text: String, index: int) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(PANEL_W, 48)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := Clean.label(text, 26, Clean.TEXT)
	lbl.name = "Label"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	row.mouse_entered.connect(func():
		if _sel != index:
			_sel = index
			_play(SOUND_MOVE)
			_refresh_rows())
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_sel = index
			_activate())
	return row


func _refresh_rows() -> void:
	for i in _rows.size():
		var row := _rows[i] as PanelContainer
		var on := i == _sel
		var sb := Clean.box(3, Color(Clean.GOLD, 0.12) if on else Color(0, 0, 0, 0), Color(Clean.GOLD, 0.5) if on else Color(0, 0, 0, 0))
		sb.content_margin_left = 22 if on else 16
		sb.content_margin_right = 12
		row.add_theme_stylebox_override("panel", sb)
		var lbl := row.get_node("Label") as Label
		lbl.add_theme_color_override("font_color", Clean.GOLD_HI if on else Clean.TEXT)


func _activate() -> void:
	if _sel < 0 or _sel >= _items.size() or _transition:
		return
	var it: Dictionary = _items[_sel]
	match it["action"]:
		"travel":
			_play(SOUND_ACCEPT)
			_show_travel()
		"bag":
			_open_bag()
		"leave":
			_leave()
		"back":
			_play(SOUND_ACCEPT)
			_show_menu()
		"go":
			_travel(it["target"])


func _input(event: InputEvent) -> void:
	if not _open or _transition or _inventory_open or not _panel.visible:
		return
	if event.is_echo():
		return
	var handled := true
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move(1)
	elif event.is_action_pressed("interact") or (event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		if _travel_mode:
			_play(SOUND_ACCEPT)
			_show_menu()
		else:
			_leave()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	if _items.is_empty():
		return
	_sel = posmod(_sel + d, _items.size())
	_play(SOUND_MOVE)
	_refresh_rows()


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()
