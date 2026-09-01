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
@onready var ui_audio: AudioStreamPlayer = $UIAudio
@onready var settings_panel := $UILayer/SettingsPanel

## Первый уровень. main_scene в project.godot — это само меню, поэтому игра
## всегда стартует отсюда, а на уровень уходит только через выбор героя или
## загрузку сейва: иначе SaveManager остался бы пустым и персонаж выбирался бы
## сам собой (Characters.FALLBACK). Настройки — не отдельная сцена, а оверлей
const SCENE_GAME := "res://Levels/level_01.tscn"

const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")

# Панель создаётся кодом и по требованию — как настройки внутри инвентаря
# (inventory_ui.gd). Отдельного .tscn у неё нет, вся вёрстка в скрипте
const CharacterSelectScript := preload("res://Main_Menu/scripts/CharacterSelectPanel.gd")

var _character_panel: Control

# ВРЕМЕННО: экран выбора слотов (SaveSlotsPanel) убран, пока не нужен для
# тестов — играем всегда в один и тот же слот 0, "Новая игра" затирает его.
# SaveManager по-прежнему умеет несколько слотов (SLOT_COUNT), их вернёт сама
# панель, когда понадобится — здесь достаточно перестать хардкодить 0
const SINGLE_SLOT := 0

func _play_ui_sound(stream: AudioStream) -> void:
	ui_audio.stream = stream
	ui_audio.play()

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

	# Дождь НЕ зацикливаем через loop_mode. Этот же WAV стоит и на уровне
	# (Levels/level_01.tscn -> RainPlayer), а Godot кэширует ресурсы — то есть
	# это ОДИН объект на обе сцены. Выставляя ему LOOP_FORWARD здесь, мы
	# портили общий ресурс: у файла невалидный loop_end, получалась петля
	# нулевой длины, и после старта игры из меню дождь на уровне пропадал
	# совсем. Зацикливаем перезапуском по сигналу — ресурс при этом не
	# трогаем вообще (так же сделано в level_music_manager.gd)
	if not rain_ambience.finished.is_connected(_replay_rain):
		rain_ambience.finished.connect(_replay_rain)


func _replay_rain() -> void:
	rain_ambience.play()


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
	_play_ui_sound(SOUND_ACCEPT)
	_get_character_panel().open()


## Игрок выбрал героя. Слот заводим здесь — это единственное место в проекте,
## где character_id попадает в сейв, дальше он только читается. Слот всегда
## один и тот же (SINGLE_SLOT) — без панели выбора спросить "куда писать"
## всё равно негде, так что новая игра просто затирает прошлое прохождение
func _on_character_chosen(id: String) -> void:
	SaveManager.create_slot(SINGLE_SLOT, id)
	_start_game()


## "Продолжить" и "Загрузить" сейчас делают одно и то же — слот один, выбирать
## нечего. Разделены на две кнопки на случай, если панель слотов вернётся:
## тогда "Загрузить" снова начнёт открывать список, а "Продолжить" — как
## сейчас, сразу грузить последний
func _on_continue() -> void:
	_try_resume($UILayer/LeftPanel/MenuButtons/BtnContinue)


func _on_load() -> void:
	_try_resume($UILayer/LeftPanel/MenuButtons/BtnLoad)


func _try_resume(source_btn: Button) -> void:
	if not SaveManager.slot_exists(SINGLE_SLOT):
		_play_ui_sound(SOUND_DENIED)
		_flash_button(source_btn)
		return
	_play_ui_sound(SOUND_ACCEPT)
	SaveManager.load_slot(SINGLE_SLOT)
	_start_game()


## Гасим открытую панель перед уходом в игру. modulate самой сцены её не
## затемняет: она лежит под CanvasLayer, а он не CanvasItem и прозрачность
## родителя не наследует — без этого панель висела бы поверх экрана всю
## анимацию перехода
func _start_game() -> void:
	if is_instance_valid(_character_panel):
		_character_panel.close()
	_transition_to(SCENE_GAME)


# ── Ленивое создание панели ───────────────────────────────────────────────────
# Кладём туда же, где лежит панель настроек — чтобы порядок отрисовки и слой
# были те же самые, без догадок про структуру MainMenu.tscn

func _get_character_panel() -> Control:
	if not is_instance_valid(_character_panel):
		_character_panel = CharacterSelectScript.new()
		_character_panel.character_chosen.connect(_on_character_chosen)
		settings_panel.get_parent().add_child(_character_panel)
	return _character_panel

func _on_settings() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	settings_panel.open()

func _on_quit() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	await t.finished
	get_tree().quit()


# ── Утилиты ───────────────────────────────────────────────────────────────────
func _flash_button(btn: Button) -> void:
	## Мигает кнопкой если действие недоступно
	var t := create_tween()
	t.tween_property(btn, "modulate", Color(1, 0.3, 0.3), 0.1)
	t.tween_property(btn, "modulate", Color(1, 1, 1), 0.3)
