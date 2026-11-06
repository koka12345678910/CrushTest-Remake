extends Control
## SettingsPanel.gd — настройки поверх главного меню.
##
## Своей вёрстки больше нет: показывается тот же экран, что вкладка
## «НАСТРОЙКИ» инвентаря героя (Inventory/ui/hero_settings_screen.gd) — три
## тёмные панели: разделы | настройки | описание с «Сбросить всё» и «Назад».
## Меню и игра выглядят одинаково, а настройка, добавленная в инвентарь,
## сразу появляется и здесь.
##
## Экран ждёт от хозяина то же, что даёт инвентарь (inventory_ui.gd):
## _make_label, _play_ui_sound, SOUND_CHOICE и _close_settings_screen —
## они ниже. Значения живут в автозагрузке GameSettings, на диск пишутся
## при закрытии.

signal closed

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")
const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const SettingsScreen := preload("res://Inventory/ui/hero_settings_screen.gd")
const SOUND_CHOICE := Style.SOUND_CHOICE
const SOUND_TOGGLE := Style.SOUND_TOGGLE

## Панели инвентаря начинаются ниже его вкладок (layout.top 118) — здесь
## вкладок нет, поэтому весь экран чуть поднят и под ним остаётся место
## для подсказок клавиш
const LIFT := 46.0

var _audio: AudioStreamPlayer
var _content: Control
var _tween: Tween
var _is_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Ловим ввод только когда открыты — иначе перехватывали бы клики по меню
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio = Style.ui_player(self)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_build()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_content, "position:y", _content.position.y, 0.32)\
		.from(_content.position.y + 18.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Пишем на диск один раз при закрытии, а не на каждое движение ползунка
	GameSettings.save_settings()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await _tween.finished
	visible = false
	for c in get_children():
		if c != _audio:
			c.queue_free()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Style.play_back(_audio)
		close()


func _build() -> void:
	for c in get_children():
		if c != _audio:
			c.queue_free()
	Style.make_dim(self)
	HeroSkin.use_theme(HeroSkin.CLEAN)
	var stage := Style.make_stage(self)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.position = Vector2(0, -LIFT)
	_content.size = Style.BASE
	stage.add_child(_content)

	# Без типа: keyboard_nav/init — поля самого экрана, а не Control
	var screen = SettingsScreen.new()
	screen.keyboard_nav = true
	screen.size = Style.BASE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(screen)
	screen.init(self)

	var hints := Style.hint_row([["↑ ↓", "Пункт"], ["← →", "Значение"], ["Tab", "Раздел"], ["Esc", "Назад"]])
	hints.position = Vector2(0, HeroSkin.TOP + HeroSkin.FRAME_H + 22.0)
	hints.size = Vector2(Style.BASE.x, 32)
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(hints)


# ── То, что экран настроек берёт у хозяина (как у inventory_ui.gd) ───────────

func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Style.TEXT)
	return l


func _play_ui_sound(stream: AudioStream) -> void:
	if stream == SOUND_CHOICE:
		Style.play_move(_audio)
	else:
		Style.play(_audio, stream, -3.0)


func _close_settings_screen() -> void:
	Style.play_back(_audio)
	close()
