extends Control
## ConfirmDialog.gd — окно «да/нет» поверх меню в ключе инвентаря: тёмная
## плашка с каймой, золотой заголовок, две кнопки-плашки.
##
## Используется для «Покинуть игру?» и «Начать заново?» (новая игра затирает
## единственный слот). Создаётся кодом на каждый показ, удаляет себя сам:
##   var d := ConfirmDialog.new(); d.title = ...; d.answered.connect(...)
##   parent.add_child(d)
## Esc / B на геймпаде — «нет»; Enter / A — нажимает кнопку в фокусе.

signal answered(yes: bool)

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")

var title := ""
var body := ""
var yes_text := "ДА"
var no_text := "НЕТ"
## В фокусе сразу «да» (для безопасных действий) или «нет» (для опасных)
var default_yes := false

var _panel: PanelContainer
var _audio: AudioStreamPlayer
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.make_theme()
	Style.make_dim(self, 0.55)
	_audio = Style.ui_player(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	var sb := Style.panel_box(6)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 48)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 34)
	_panel.add_child(m)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)

	var t := Style.label(title, 25, Style.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var line := Style.FadeLine.new()
	line.color = Color(Style.GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)

	if body != "":
		var b := Style.label(body, 19, Style.TEXT)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(560, 0)
		v.add_child(b)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var no_btn := Style.chip_button(no_text)
	var yes_btn := Style.chip_button(yes_text)
	for btn in [no_btn, yes_btn]:
		btn.custom_minimum_size = Vector2(220, 46)
		btn.focus_entered.connect(func(): Style.play_move(_audio))
		row.add_child(btn)
	no_btn.pressed.connect(_answer.bind(false))
	yes_btn.pressed.connect(_answer.bind(true))
	no_btn.focus_neighbor_left = no_btn.get_path_to(yes_btn)
	no_btn.focus_neighbor_right = no_btn.get_path_to(yes_btn)
	yes_btn.focus_neighbor_left = yes_btn.get_path_to(no_btn)
	yes_btn.focus_neighbor_right = yes_btn.get_path_to(no_btn)

	# Фокус до звука перемещения: первый щелчок не нужен — звучит открытие
	(yes_btn if default_yes else no_btn).call_deferred("grab_focus")
	Style.play_open(_audio)

	modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).from(Vector2(0.96, 0.96))\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		_answer(false)
	# Окно модальное: до меню под ним не доходят ни клавиши, ни клики
	if not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


func _answer(yes: bool) -> void:
	if _closing:
		return
	_closing = true
	if yes:
		Style.play(_audio, Style.SOUND_ACCEPT)
	else:
		Style.play_back(_audio)
	answered.emit(yes)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2(0.97, 0.97), 0.16)
	await tw.finished
	queue_free()
