extends CanvasLayer
## demo_end.gd — финал демо: после победы над боссом храма (boss_arena.gd)
## мир медленно уходит в темноту, на чёрном — «ДЕМО ОКОНЧЕНО» и благодарность,
## затем подсказка. Любая клавиша, клик или кнопка геймпада — в главное меню
## (в коопе — с выходом из сеанса).
##
## Запуск — boss_arena.gd::_demo_end (узел в корне дерева, переживает смену сцены)

const Clean := preload("res://UI/clean_hud.gd")
const MENU_SCENE := "res://Main_Menu/scenes/MainMenu.tscn"

## Затемнение мира, с
const FADE_TIME := 2.8
## Пауза на чёрном перед надписью, с
const TITLE_DELAY := 0.6
## Через сколько после надписи можно уйти (чтобы не пролистнуть случайно), с
const HINT_DELAY := 2.4

var _black: ColorRect
var _title: Label
var _thanks: Label
var _hint: Label
var _line: ColorRect
var _can_leave := false
var _leaving := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_lock_heroes()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_black)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.offset_left = 0.0
	box.offset_right = 0.0
	box.offset_top = -110.0
	box.offset_bottom = 110.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	_title = Clean.label(tr("ДЕМО ОКОНЧЕНО"), 72, Clean.GOLD_HI)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.02, 0.8))
	_title.add_theme_constant_override("outline_size", 10)
	_title.modulate.a = 0.0
	box.add_child(_title)

	var line_wrap := CenterContainer.new()
	line_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line_wrap)
	_line = ColorRect.new()
	_line.color = Color(Clean.GOLD, 0.55)
	_line.custom_minimum_size = Vector2(420, 2)
	_line.modulate.a = 0.0
	line_wrap.add_child(_line)

	_thanks = Clean.label(tr("Спасибо за игру"), 30, Clean.TEXT)
	_thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thanks.modulate.a = 0.0
	box.add_child(_thanks)

	_hint = Clean.label(tr("Нажмите любую клавишу, чтобы вернуться в главное меню"), 20, Clean.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -96.0
	_hint.offset_bottom = -60.0
	_hint.modulate.a = 0.0
	root.add_child(_hint)


## Герои больше не слушают ввод (тот же замок, что у костра и лавки)
func _lock_heroes() -> void:
	for h in get_tree().get_nodes_in_group("player"):
		if "is_in_shop" in h:
			h.is_in_shop = true
		if h.has_method("play_idle_animation"):
			h.play_idle_animation()


func _run() -> void:
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	await get_tree().create_timer(TITLE_DELAY).timeout
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(_title, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	t2.tween_property(_line, "modulate:a", 1.0, 1.6).set_delay(0.5)
	t2.tween_property(_thanks, "modulate:a", 1.0, 1.4).set_delay(1.1)
	await get_tree().create_timer(HINT_DELAY).timeout
	_can_leave = true
	var t3 := create_tween().set_loops()
	t3.tween_property(_hint, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	t3.tween_property(_hint, "modulate:a", 0.45, 1.2).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if not _can_leave or _leaving:
		get_viewport().set_input_as_handled()
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_leave()


func _leave() -> void:
	_leaving = true
	if Net.is_online():
		Net.leave()
	# Загрузчик (слой выше) гасит в чёрное и грузит меню; экран живёт у
	# корня и уходит, как только меню встало
	SceneLoader.scene_changed.connect(queue_free, CONNECT_ONE_SHOT)
	SceneLoader.change_scene(MENU_SCENE)
