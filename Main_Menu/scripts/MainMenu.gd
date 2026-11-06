extends Control
## MainMenu.gd
## Главный контроллер меню: появление, навигация (мышь, клавиатура,
## геймпад), атмосфера фона и переходы в панели и в игру.
##
## Вид — как у инвентаря и HUD (MenuStyle.gd берёт палитру из
## UI/clean_hud.gd): слева тёмная колонка с логотипом и пунктами, справа
## открытый арт с рыцарем.

@onready var background: TextureRect = $Background
@onready var background_near: TextureRect = $BackgroundNear
@onready var fog: ColorRect = $EffectsLayer/FogOverlay
@onready var effects_layer: CanvasLayer = $EffectsLayer
@onready var left_panel: VBoxContainer = $UILayer/LeftPanel
@onready var title_label: TextureRect = $UILayer/GameTitle
@onready var bottom_bar: HBoxContainer = $UILayer/BottomBar
@onready var version_label: Label = $UILayer/BottomBar/VersionLabel
@onready var ambient_music: AudioStreamPlayer = $AmbientMusic
@onready var rain_ambience: AudioStreamPlayer = $RainAmbience
@onready var ui_audio: AudioStreamPlayer = $UIAudio
@onready var settings_panel := $UILayer/SettingsPanel
@onready var btn_continue: Button = $UILayer/LeftPanel/MenuButtons/BtnContinue
@onready var btn_new: Button = $UILayer/LeftPanel/MenuButtons/BtnNewGame
@onready var btn_load: Button = $UILayer/LeftPanel/MenuButtons/BtnLoad
@onready var btn_settings: Button = $UILayer/LeftPanel/MenuButtons/BtnSettings
@onready var btn_quit: Button = $UILayer/LeftPanel/MenuButtons/BtnQuit

## Первый уровень. main_scene в project.godot — это само меню, поэтому игра
## всегда стартует отсюда, а на уровень уходит только через выбор героя или
## загрузку сейва: иначе SaveManager остался бы пустым и персонаж выбирался бы
## сам собой (Characters.FALLBACK).
# Ночное кладбище по референсу. Старая карта цела — вернуть её можно,
# поставив сюда "res://Levels/level_01.tscn"
const SCENE_GAME := "res://Levels/level_graveyard.tscn"

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")
const SOUND_ACCEPT := Style.SOUND_ACCEPT
const SOUND_DENIED := Style.SOUND_DENIED
const SOUND_THUNDER := preload("res://Sound/thunder.mp3")

# Лого — мерцающий спрайт-лист (сетка 6×6 = 36 кадров тлеющих углей на
# гравировке). GameTitle несёт SpriteSheetAnimation.gd (smooth = true в
# .tscn: сглаживание с мип-картами), сам лист прокручивается через .call()
const LOGO_ANIM_SHEET := preload("res://Main_Menu/TLO_anim.png")
const LOGO_ANIM_COLUMNS := 6
const LOGO_ANIM_ROWS := 6
const LOGO_ANIM_FPS := 15.0
## Жар и полоса света по лого (вместо прежнего мигания прозрачностью)
const LOGO_SHADER := preload("res://Main_Menu/assets/shaders/logo_ember.gdshader")

# Панели создаются кодом и по требованию — отдельных .tscn у них нет
const CharacterSelectScript := preload("res://Main_Menu/scripts/CharacterSelectPanel.gd")
const InDevelopmentScript := preload("res://Main_Menu/scripts/InDevelopmentPanel.gd")
const ControlsScript := preload("res://Main_Menu/scripts/ControlsPanel.gd")
const ConfirmDialogScript := preload("res://Main_Menu/scripts/ConfirmDialog.gd")
# Угольки экрана загрузки — те же поднимаются от костров и здесь
const SceneLoaderScript := preload("res://Main_Menu/scripts/SceneLoader.gd")

var _character_panel: Control

# ВРЕМЕННО: экран выбора слотов (SaveSlotsPanel) убран, пока не нужен для
# тестов — играем всегда в один и тот же слот 0, "Новая игра" затирает его
# (теперь — после подтверждения). Кнопка «Загрузить» спрятана в .tscn
const SINGLE_SLOT := 0

# ── Параллакс фона от мыши (эффект "живых обоев") ──────────────────────────────
# Два слоя двигаются с разной силой — так и получается ощущение глубины:
# дальний план (руины/небо) почти неподвижен, ближний (рыцарь) заметно ведёт
# за курсором, будто стоит ощутимо ближе к камере
@export var parallax_strength_far := 0.012
@export var parallax_strength_near := 0.05
@export var parallax_smoothing := 4.0
var _parallax_far := Vector2.ZERO
var _parallax_near := Vector2.ZERO

## Молния в разломе неба: пауза между вспышками, секунды
@export var lightning_interval := Vector2(16.0, 34.0)

var _logo_mat: ShaderMaterial
var _sweep_tween: Tween
var _menu_fade_tween: Tween
var _fade_rect: ColorRect
var _flash: TextureRect
var _thunder: AudioStreamPlayer
var _move_audio: AudioStreamPlayer
var _buttons: Array[Button] = []
## Пока открыто окно поверх меню, его навигация не работает
var _overlay_open := false
## Программный перенос фокуса не щёлкает звуком перемещения
var _quiet_focus := true
var _last_focus: Control
var _quitting := false
var _prev_aspect := Window.CONTENT_SCALE_ASPECT_KEEP


func _ready() -> void:
	# Меню растягивается на любой формат экрана (16:10, 21:9) без чёрных полос:
	# фон «накрывает» экран, интерфейс держится за края. В игре остаётся
	# режим проекта (keep) — вернём его на выходе из меню (_exit_tree)
	_prev_aspect = get_tree().root.content_scale_aspect
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	title_label.call("setup_grid", LOGO_ANIM_SHEET, LOGO_ANIM_COLUMNS, LOGO_ANIM_ROWS,
		1.0 / LOGO_ANIM_FPS)
	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = LOGO_SHADER
	_logo_mat.set_shader_parameter("rect_size", title_label.size)
	title_label.material = _logo_mat

	_move_audio = Style.ui_player(self)
	_setup_audio_loops()
	_setup_atmosphere()
	_setup_fog_pulse()
	_setup_bottom_bar()
	_connect_buttons()
	_refresh_continue()
	settings_panel.closed.connect(_on_overlay_closed)
	_animate_intro()


func _exit_tree() -> void:
	get_tree().root.content_scale_aspect = _prev_aspect


# ── Звук: музыка на шине Music (её крутит ползунок «Музыка»), дождь фоном,
# ── интерфейс — на шине эффектов (Style.BUS_SFX) ──────────────────────────────
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

	_thunder = AudioStreamPlayer.new()
	_thunder.stream = SOUND_THUNDER
	add_child(_thunder)


func _replay_rain() -> void:
	rain_ambience.play()


func _play_ui_sound(stream: AudioStream) -> void:
	Style.play(ui_audio, stream)


func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var mouse_norm := (get_viewport().get_mouse_position() / viewport_size) - Vector2(0.5, 0.5)

	if background.material:
		var target_far := mouse_norm * parallax_strength_far
		_parallax_far = _parallax_far.lerp(target_far, min(1.0, parallax_smoothing * delta))
		background.material.set_shader_parameter("parallax_offset", _parallax_far)

	if background_near.material:
		var target_near := mouse_norm * parallax_strength_near
		_parallax_near = _parallax_near.lerp(target_near, min(1.0, parallax_smoothing * delta))
		background_near.material.set_shader_parameter("parallax_offset", _parallax_near)


# ── Атмосфера: угли от костров, тёмная колонка под меню, виньетка, молния ─────
func _setup_atmosphere() -> void:
	# Угли — над фоном, но под затемнением колонки: у пунктов меню они не мельтешат
	var embers: Control = SceneLoaderScript.Embers.new()
	embers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embers.modulate.a = 0.8
	effects_layer.add_child(embers)

	# Вспышка молнии: свет сверху (небо), к середине экрана гаснет. Сложение,
	# а не наложение: тёмное светлеет, чёрный силуэт рыцаря проступает
	_flash = TextureRect.new()
	_flash.texture = _vertical_gradient([0.0, 0.62], [Color(0.62, 0.68, 0.85, 0.9), Color(0.62, 0.68, 0.85, 0.0)])
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add
	_flash.modulate.a = 0.0
	effects_layer.add_child(_flash)

	# Колонка меню: слева почти чёрный (как панели инвентаря), к середине
	# экрана сходит на нет — текст читается, рыцарь справа открыт
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.58])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(shade)

	var vig := TextureRect.new()
	vig.texture = Style.vignette_texture(0.62)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(vig)

	# Чёрный экран интро и выхода — поверх всего меню
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 10
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade_rect)

	_schedule_lightning(randf_range(7.0, 12.0))


func _vertical_gradient(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 256
	return t


func _schedule_lightning(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(_lightning)


## Двойная вспышка, следом — раскат грома с задержкой (молния далеко)
func _lightning() -> void:
	if not is_inside_tree() or _quitting:
		return
	var peak := randf_range(0.55, 0.85)
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", peak * 0.6, 0.04)
	t.tween_property(_flash, "modulate:a", 0.1, 0.08)
	t.tween_property(_flash, "modulate:a", peak, 0.05)
	t.tween_property(_flash, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	get_tree().create_timer(randf_range(0.5, 1.4)).timeout.connect(func():
		if is_instance_valid(_thunder) and not _quitting:
			_thunder.volume_db = randf_range(-16.0, -11.0)
			_thunder.pitch_scale = randf_range(0.88, 1.04)
			_thunder.play())
	_schedule_lightning(randf_range(lightning_interval.x, lightning_interval.y))


# ── Туман: пульсирующая прозрачность ──────────────────────────────────────────
func _setup_fog_pulse() -> void:
	var t := create_tween()
	t.set_loops()
	t.tween_property(fog, "color:a", 0.16, 6.0).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fog, "color:a", 0.05, 6.0).set_ease(Tween.EASE_IN_OUT)


# ── Нижняя строка: версия слева, подсказки клавиш справа ──────────────────────
func _setup_bottom_bar() -> void:
	version_label.add_theme_font_override("font", Style.caps_font())
	version_label.add_theme_font_size_override("font_size", 15)
	version_label.add_theme_color_override("font_color", Color(Style.TEXT_DIM, 0.8))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(spacer)
	bottom_bar.add_child(Style.hint_row([["Enter", "Выбрать"], ["Esc", "Выход"]]))


# ── Интро: из темноты проявляется фон, затем лого, затем пункты по одному ─────
func _animate_intro() -> void:
	var center := get_viewport_rect().size * 0.5
	for bg: Control in [background, background_near]:
		bg.pivot_offset = center - bg.global_position
		bg.scale = Vector2(1.06, 1.06)
	title_label.modulate.a = 0.0
	title_label.position.y -= 14.0
	left_panel.position.x -= 24.0
	bottom_bar.modulate.a = 0.0
	for b in _buttons:
		b.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(_fade_rect, "color:a", 0.0, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	for bg: Control in [background, background_near]:
		t.tween_property(bg, "scale", Vector2.ONE, 7.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	t.tween_property(title_label, "modulate:a", 1.0, 1.4).set_delay(0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(title_label, "position:y", title_label.position.y + 14.0, 1.6)\
		.set_delay(0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_method(func(v: float): _logo_mat.set_shader_parameter("heat", v), 0.9, 0.0, 2.6).set_delay(0.5)

	t.tween_property(left_panel, "position:x", left_panel.position.x + 24.0, 1.0)\
		.set_delay(1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var i := 0
	for b in _buttons:
		if b.visible:
			t.tween_property(b, "modulate:a", 1.0, 0.45).set_delay(1.15 + i * 0.08)
			i += 1
	t.tween_property(bottom_bar, "modulate:a", 1.0, 0.8).set_delay(1.8)

	# Первый проход света по лого — когда оно уже проявилось
	get_tree().create_timer(2.0).timeout.connect(_logo_sweep)
	# Фокус на главном пункте: с клавиатуры/геймпада можно сразу листать
	get_tree().create_timer(1.3).timeout.connect(func():
		if not _overlay_open:
			_focus_quiet(_default_button()))


## Полоса света проходит по лого раз в 10–16 секунд
func _logo_sweep() -> void:
	if not is_inside_tree():
		return
	if _sweep_tween:
		_sweep_tween.kill()
	_sweep_tween = create_tween()
	_sweep_tween.tween_method(func(v: float): _logo_mat.set_shader_parameter("sweep", v),
		-0.1, 1.25, 1.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_sweep_tween.tween_callback(func(): _logo_mat.set_shader_parameter("sweep", -1.0))
	get_tree().create_timer(randf_range(10.0, 16.0)).timeout.connect(_logo_sweep)


# ── Пункты меню ───────────────────────────────────────────────────────────────
func _connect_buttons() -> void:
	btn_continue.pressed.connect(_on_continue)
	btn_new.pressed.connect(_on_new_game)
	btn_load.pressed.connect(_on_load)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)
	_buttons = [btn_continue, btn_new, btn_load, btn_settings, btn_quit]
	for b in _buttons:
		b.focus_entered.connect(_on_item_focus.bind(b))


func _on_item_focus(b: Button) -> void:
	_last_focus = b
	if not _quiet_focus:
		Style.play_move(_move_audio)


func _focus_quiet(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		return
	_quiet_focus = true
	c.grab_focus()
	_quiet_focus = false


func _default_button() -> Button:
	return btn_continue if btn_continue.visible else btn_new


## «Продолжить» — только если есть сохранение, с подписью «кем и сколько»
func _refresh_continue() -> void:
	var has := SaveManager.slot_exists(SINGLE_SLOT)
	btn_continue.visible = has
	if has:
		btn_continue.set("subtitle", _save_summary())
	_link_focus_chain()


## Язык сменили в настройках — подпись под «Продолжить» рисуется руками и
## сама не переводится (пункты меню и прочие Label переводятся сами)
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_continue()


## Подпись «кем и сколько» на текущем языке (шаблоны — в strings_en.gd)
func _save_summary() -> String:
	var info: Dictionary = SaveManager.peek_slot(SINGLE_SLOT)
	if info.is_empty():
		return ""
	var hero := tr(String(Characters.display_name(info.get("character_id", Characters.FALLBACK))))
	hero = hero.substr(0, 1) + hero.substr(1).to_lower()
	return "%s  ·  %s" % [hero, tr("%s в пути") % _format_playtime(float(info.get("playtime", 0.0)))]


func _format_playtime(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 1:
		return tr("меньше минуты")
	if m < 60:
		return tr("%d мин") % m
	return tr("%d ч %d мин") % [m / 60, m % 60]


## Стрелки и геймпад ходят по видимым пунктам по кругу
func _link_focus_chain() -> void:
	var vis: Array[Button] = []
	for b in _buttons:
		if b.visible and not b.disabled:
			vis.append(b)
	for i in vis.size():
		var prev := vis[(i - 1 + vis.size()) % vis.size()]
		var next := vis[(i + 1) % vis.size()]
		vis[i].focus_neighbor_top = vis[i].get_path_to(prev)
		vis[i].focus_neighbor_bottom = vis[i].get_path_to(next)
		vis[i].focus_previous = vis[i].get_path_to(prev)
		vis[i].focus_next = vis[i].get_path_to(next)
		vis[i].focus_neighbor_left = vis[i].get_path_to(vis[i])
		vis[i].focus_neighbor_right = vis[i].get_path_to(vis[i])


func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open or _quitting:
		return
	# Esc: сначала переводит на «Выход» (как в DS), второй раз — спрашивает
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if btn_quit.has_focus():
			_on_quit()
		else:
			btn_quit.grab_focus()
		return
	# Фокус потерян (кликнули мимо) — любая навигационная клавиша его вернёт
	if get_viewport().gui_get_focus_owner() == null:
		for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
			if event.is_action_pressed(a):
				get_viewport().set_input_as_handled()
				_focus_quiet(_last_focus if is_instance_valid(_last_focus) and _last_focus.visible else _default_button())
				return


# ── Переходы ──────────────────────────────────────────────────────────────────
# Затемнение, звук и фоновую загрузку уровня делает автозагрузка SceneLoader
# (экран загрузки поверх всего) — здесь только передаём ей путь
func _transition_to(scene_path: String) -> void:
	SceneLoader.change_scene(scene_path)


## «Новый путь» затирает единственный слот — если там есть прохождение,
## сначала спрашиваем
func _on_new_game() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	if SaveManager.slot_exists(SINGLE_SLOT):
		_confirm("НАЧАТЬ ЗАНОВО?",
			tr("Прошлое прохождение (%s) будет стёрто без возврата.") % _save_summary(),
			"НАЧАТЬ", "ОТМЕНА", false, func(yes: bool):
				if yes:
					_open_character_select())
		return
	_open_character_select()


func _open_character_select() -> void:
	_get_character_panel().open()
	# Выбор героя полноэкранный — логотип и навигация под ним лишние
	_set_menu_shown(false)


## Игрок выбрал героя. Слот заводим здесь — это единственное место в проекте,
## где character_id попадает в сейв, дальше он только читается. Слот всегда
## один и тот же (SINGLE_SLOT)
func _on_character_chosen(id: String) -> void:
	# Класс ещё не готов (Characters.AVAILABLE) — не стартуем и сейв не
	# трогаем, а показываем окно "в разработке" поверх экрана выбора
	if not Characters.is_available(id):
		_show_in_development(id)
		return
	# Сейв заводим только после «Начать путь» — если с памятки вернулись
	# назад, прошлое прохождение не должно быть уже затёрто
	_show_controls(func():
		SaveManager.create_slot(SINGLE_SLOT, id)
		_start_game())


## Памятка по управлению перед стартом (ControlsPanel.gd). on_begin — что
## сделать по «Начать путь»: создать/загрузить сейв и уйти на уровень
func _show_controls(on_begin: Callable) -> void:
	var p: Control = ControlsScript.new()
	# Из главного меню (Продолжить) прячем логотип и кнопки под окном; с экрана
	# выбора героя — он и так полноэкранный
	var from_menu := not (is_instance_valid(_character_panel) and _character_panel.visible)
	if from_menu:
		_set_menu_shown(false)
	p.confirmed.connect(on_begin)
	p.cancelled.connect(func():
		if from_menu:
			_set_menu_shown(true))
	settings_panel.get_parent().add_child(p)


func _show_in_development(id: String) -> void:
	var p: Control = InDevelopmentScript.new()
	p.hero_id = id
	# Туда же, где панели выбора и настроек, — и последним, чтобы лечь поверх
	settings_panel.get_parent().add_child(p)


## «Продолжить» и «Загрузить» сейчас делают одно и то же — слот один, выбирать
## нечего. «Загрузить» спрятана, пока не вернётся панель слотов
func _on_continue() -> void:
	_try_resume(btn_continue)


func _on_load() -> void:
	_try_resume(btn_load)


func _try_resume(source_btn: Button) -> void:
	if not SaveManager.slot_exists(SINGLE_SLOT):
		_play_ui_sound(SOUND_DENIED)
		_flash_button(source_btn)
		return
	# Старый сейв за класс, который сейчас закрыт, — тоже не пускаем
	var saved_id: String = SaveManager.peek_slot(SINGLE_SLOT).get("character_id", Characters.FALLBACK)
	if not Characters.is_available(saved_id):
		_show_in_development(saved_id)
		return
	_play_ui_sound(SOUND_ACCEPT)
	_show_controls(func():
		SaveManager.load_slot(SINGLE_SLOT)
		_start_game())


## Гасим открытую панель перед уходом в игру: она лежит под CanvasLayer и
## прозрачность сцены не наследует — без этого висела бы поверх перехода
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
		_character_panel.closed.connect(_on_overlay_closed)
		settings_panel.get_parent().add_child(_character_panel)
	return _character_panel


func _on_settings() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	settings_panel.open()
	_set_menu_shown(false)


## Любой полноэкранный оверлей (настройки, выбор героя) закрылся — возвращаем
## логотип и навигацию
func _on_overlay_closed() -> void:
	_set_menu_shown(true)


func _set_menu_shown(shown: bool) -> void:
	_overlay_open = not shown
	if _menu_fade_tween:
		_menu_fade_tween.kill()
	if shown:
		left_panel.visible = true
	else:
		# Спрятанные пункты не должны ловить стрелки под окном
		var f := get_viewport().gui_get_focus_owner()
		if f in _buttons:
			_last_focus = f
			f.release_focus()

	_menu_fade_tween = create_tween().set_parallel(true)
	for c: CanvasItem in [left_panel, title_label, bottom_bar]:
		_menu_fade_tween.tween_property(c, "modulate:a", 1.0 if shown else 0.0, 0.25 if shown else 0.2)\
			.set_ease(Tween.EASE_OUT)
	await _menu_fade_tween.finished
	if shown:
		_focus_quiet(_last_focus if is_instance_valid(_last_focus) and _last_focus.visible else _default_button())
	else:
		left_panel.visible = false


func _on_quit() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	_confirm("ПОКИНУТЬ ИГРУ?", "", "ВЫЙТИ", "ОСТАТЬСЯ", false, func(yes: bool):
		if yes:
			_quit())


func _quit() -> void:
	_quitting = true
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade_rect, "color:a", 1.0, 0.7).set_ease(Tween.EASE_IN)
	for p: AudioStreamPlayer in [ambient_music, rain_ambience]:
		t.tween_property(p, "volume_db", -60.0, 0.7).set_ease(Tween.EASE_IN)
	await t.finished
	get_tree().quit()


## Окно «да/нет» поверх меню; пока оно открыто, меню ввод не получает
func _confirm(title: String, body: String, yes_text: String, no_text: String,
		default_yes: bool, on_answer: Callable) -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f in _buttons:
		_last_focus = f
	_overlay_open = true
	var d: Control = ConfirmDialogScript.new()
	d.title = title
	d.body = body
	d.yes_text = yes_text
	d.no_text = no_text
	d.default_yes = default_yes
	d.answered.connect(func(yes: bool):
		_overlay_open = false
		if not yes:
			_focus_quiet(_last_focus)
		on_answer.call(yes))
	settings_panel.get_parent().add_child(d)


# ── Утилиты ───────────────────────────────────────────────────────────────────
func _flash_button(btn: Button) -> void:
	## Мигает кнопкой если действие недоступно
	var t := create_tween()
	t.tween_property(btn, "modulate", Color(1, 0.3, 0.3), 0.1)
	t.tween_property(btn, "modulate", Color(1, 1, 1), 0.3)
