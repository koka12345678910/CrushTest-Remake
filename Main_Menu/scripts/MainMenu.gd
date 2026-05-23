extends Control
## MainMenu.gd
## Главный контроллер меню — управляет анимациями появления,
## зумом фона и переходами между сценами.

@onready var background: TextureRect = $Background
@onready var camera_anim: AnimationPlayer = $Background/CameraAnim
@onready var fog: ColorRect = $EffectsLayer/FogOverlay
@onready var left_panel: VBoxContainer = $UILayer/LeftPanel
@onready var title_label: Label = $UILayer/LeftPanel/GameTitle/TitleLabel
@onready var menu_buttons: VBoxContainer = $UILayer/LeftPanel/MenuButtons

const SCENE_GAME := "res://scenes/Game.tscn"
const SCENE_SETTINGS := "res://scenes/Settings.tscn"

var _tween: Tween


func _ready() -> void:
	_setup_background_zoom()
	_setup_fog_pulse()
	_animate_intro()
	_connect_buttons()


# ── Фон: плавный кинематографический зум ──────────────────────────────────────
func _setup_background_zoom() -> void:
	var anim := AnimationLibrary.new()
	var zoom_anim := Animation.new()
	zoom_anim.length = 20.0
	zoom_anim.loop_mode = Animation.LOOP_PINGPONG

	# Трек масштаба фона
	var track_idx := zoom_anim.add_track(Animation.TYPE_VALUE)
	zoom_anim.track_set_path(track_idx, ".:scale")
	zoom_anim.track_insert_key(track_idx, 0.0, Vector2(1.0, 1.0))
	zoom_anim.track_insert_key(track_idx, 20.0, Vector2(1.06, 1.06))
	zoom_anim.value_track_set_update_mode(track_idx, Animation.UPDATE_CONTINUOUS)

	# Трек смещения (лёгкое покачивание)
	var pos_track := zoom_anim.add_track(Animation.TYPE_VALUE)
	zoom_anim.track_set_path(pos_track, ".:position")
	zoom_anim.track_insert_key(pos_track, 0.0, Vector2(0, 0))
	zoom_anim.track_insert_key(pos_track, 10.0, Vector2(-8, -5))
	zoom_anim.track_insert_key(pos_track, 20.0, Vector2(4, 0))

	anim.add_animation("zoom", zoom_anim)
	camera_anim.add_animation_library("bg", anim)
	camera_anim.play("bg/zoom")


# ── Туман: пульсирующая прозрачность ──────────────────────────────────────────
func _setup_fog_pulse() -> void:
	var t := create_tween()
	t.set_loops()
	t.tween_property(fog, "color:a", 0.18, 6.0).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fog, "color:a", 0.06, 6.0).set_ease(Tween.EASE_IN_OUT)


# ── Интро: всё появляется плавно ──────────────────────────────────────────────
func _animate_intro() -> void:
	# Начальные состояния
	left_panel.modulate.a = 0.0
	left_panel.position.x -= 30.0
	title_label.modulate.a = 0.0

	_tween = create_tween().set_parallel(false)

	# Небольшая пауза перед началом
	_tween.tween_interval(0.6)

	# Заголовок появляется первым
	_tween.tween_property(title_label, "modulate:a", 1.0, 1.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Потом весь левый панель
	_tween.tween_interval(0.3)
	_tween.set_parallel(true)
	_tween.tween_property(left_panel, "modulate:a", 1.0, 1.5)\
		.set_ease(Tween.EASE_OUT)
	_tween.tween_property(left_panel, "position:x", 0.0, 1.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ── Подключение кнопок к действиям ────────────────────────────────────────────
func _connect_buttons() -> void:
	$UILayer/LeftPanel/MenuButtons/BtnNewGame.pressed.connect(_on_new_game)
	$UILayer/LeftPanel/MenuButtons/BtnContinue.pressed.connect(_on_continue)
	$UILayer/LeftPanel/MenuButtons/BtnLoad.pressed.connect(_on_load)
	$UILayer/LeftPanel/MenuButtons/BtnSettings.pressed.connect(_on_settings)
	$UILayer/LeftPanel/MenuButtons/BtnQuit.pressed.connect(_on_quit)


# ── Переходы ──────────────────────────────────────────────────────────────────
func _transition_to(scene_path: String) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	await t.finished
	get_tree().change_scene_to_file(scene_path)


func _on_new_game() -> void:
	_transition_to(SCENE_GAME)

func _on_continue() -> void:
	# Здесь можно проверить наличие сейва
	if _has_save():
		_transition_to(SCENE_GAME)
	else:
		_flash_button($UILayer/LeftPanel/MenuButtons/BtnContinue)

func _on_load() -> void:
	# TODO: открыть LoadGame диалог
	pass

func _on_settings() -> void:
	_transition_to(SCENE_SETTINGS)

func _on_quit() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	await t.finished
	get_tree().quit()


# ── Утилиты ───────────────────────────────────────────────────────────────────
func _has_save() -> bool:
	return FileAccess.file_exists("user://savegame.sav")

func _flash_button(btn: Button) -> void:
	## Мигает кнопкой если действие недоступно
	var t := create_tween()
	t.tween_property(btn, "modulate", Color(1, 0.3, 0.3), 0.1)
	t.tween_property(btn, "modulate", Color(1, 1, 1), 0.3)
