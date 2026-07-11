extends Control
## MainMenu.gd
## Главный контроллер меню — управляет анимациями появления,
## зумом фона и переходами между сценами.

@onready var background: TextureRect = $Background
@onready var fog: ColorRect = $EffectsLayer/FogOverlay
@onready var left_panel: VBoxContainer = $UILayer/LeftPanel
@onready var title_label: Label = $UILayer/GameTitle/TitleLabel
@onready var menu_buttons: VBoxContainer = $UILayer/LeftPanel/MenuButtons
@onready var ambient_music: AudioStreamPlayer = $AmbientMusic
@onready var rain_ambience: AudioStreamPlayer = $RainAmbience

const SCENE_GAME := "res://scenes/Game.tscn"
const SCENE_SETTINGS := "res://scenes/Settings.tscn"

var _tween: Tween

# ── Параллакс фона от мыши (эффект "живых обоев") ──────────────────────────────
@export var parallax_strength := 0.025
@export var parallax_smoothing := 4.0
var _parallax_current := Vector2.ZERO


func _ready() -> void:
	_setup_audio_loops()
	_setup_fog_pulse()
	_animate_intro()
	_connect_buttons()


# ── Звук: музыка на переднем плане + тихий фоновый дождь, оба зациклены ────────
func _setup_audio_loops() -> void:
	var music := ambient_music.stream as AudioStreamMP3
	if music:
		music.loop = true
	var rain := rain_ambience.stream as AudioStreamWAV
	if rain:
		rain.loop_mode = AudioStreamWAV.LOOP_FORWARD


func _process(delta: float) -> void:
	if not background.material:
		return
	var viewport_size := get_viewport_rect().size
	var mouse_norm := (get_viewport().get_mouse_position() / viewport_size) - Vector2(0.5, 0.5)
	var target := mouse_norm * parallax_strength
	_parallax_current = _parallax_current.lerp(target, min(1.0, parallax_smoothing * delta))
	background.material.set_shader_parameter("parallax_offset", _parallax_current)


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
