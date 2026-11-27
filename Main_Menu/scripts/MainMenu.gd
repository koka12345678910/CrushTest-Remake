extends Control
## MainMenu.gd
## Главный контроллер меню: появление, навигация (мышь, клавиатура,
## геймпад), атмосфера фона и переходы в панели и в игру.
##
## Вид — минимализм souls-like: всё по центру (лого сверху, под ним колонка
## мелких пунктов без плашек), выбор — только светом (MenuButton.gd). Фон —
## утёс с мечом в костре (MenuBackdrop.gd: слои, туман, огонь, искры), сверху
## цветокоррекция (menu_grade.gdshader): атмосфера важнее картинки. Окна
## поверх меню — в ключе инвентаря (MenuStyle.gd).

@onready var effects_layer: CanvasLayer = $EffectsLayer
@onready var left_panel: VBoxContainer = $UILayer/LeftPanel
@onready var title_label: TextureRect = $UILayer/GameTitle
@onready var bottom_bar: HBoxContainer = $UILayer/BottomBar
@onready var version_label: Label = $UILayer/BottomBar/VersionLabel
@onready var ambient_music: AudioStreamPlayer = $AmbientMusic
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
const SCENE_GAME := "res://reference_map_level/reference_map.tscn"

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
## Цветокоррекция кадра: приглушённый цвет, туман, виньетка, зерно
const GRADE_SHADER := preload("res://Main_Menu/assets/shaders/menu_grade.gdshader")
## Лого остывшее, как пепел: жар разгорается только при появлении
const LOGO_ASH := 0.7

# Панели создаются кодом и по требованию — отдельных .tscn у них нет
const CharacterSelectScript := preload("res://Main_Menu/scripts/CharacterSelectPanel.gd")
const InDevelopmentScript := preload("res://Main_Menu/scripts/InDevelopmentPanel.gd")
const ControlsScript := preload("res://Main_Menu/scripts/ControlsPanel.gd")
const ConfirmDialogScript := preload("res://Main_Menu/scripts/ConfirmDialog.gd")
## Живой фон: утёс, туман, костёр
const BackdropScript := preload("res://Main_Menu/scripts/MenuBackdrop.gd")
const SoundBank := preload("res://Levels/sound_bank.gd")

var _character_panel: Control
const CoopPanelScript := preload("res://Main_Menu/scripts/CoopPanel.gd")
var btn_coop: Button
## Строка под пунктами — что продолжит «Продолжить» (видна, пока он выбран)
var _save_line: Label
var _save_line_tween: Tween

# ── Заставка «Нажмите любую клавишу» ──────────────────────────────────────────
# Только при запуске игры: лого разгорается и остывает, на месте меню мерцает
# подсказка; любая клавиша / кнопка / клик — далёкий гром, и на её месте
# проступают пункты. Лого не двигается — композиция одна и та же.
# Из игры в меню возвращаемся уже без неё (static — переживает смену сцены)
static var _title_seen := false
var _title_active := false
var _title_prompt: Label
var _prompt_tween: Tween
var _prompt_loop: Tween
var _intro_tween: Tween

# ВРЕМЕННО: экран выбора слотов (SaveSlotsPanel) убран, пока не нужен для
# тестов — играем всегда в один и тот же слот 0, "Новая игра" затирает его
# (теперь — после подтверждения). Кнопка «Загрузить» спрятана в .tscn
const SINGLE_SLOT := 0

## Далёкая гроза в облаках: пауза между вспышками, секунды
@export var lightning_interval := Vector2(24.0, 48.0)

var _logo_mat: ShaderMaterial
var _sweep_tween: Tween
var _menu_fade_tween: Tween
var _fade_rect: ColorRect
var _backdrop: Control
var _thunder: AudioStreamPlayer
## Ветер на утёсе и треск костра — фоновые петли
var _wind: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _grass: AudioStreamPlayer
var _gust_noise := FastNoiseLite.new()
var _gust_t := 0.0
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
	# Вернулись в меню из совместной игры — сеанс закончен
	if Net.is_online():
		Net.leave()
	# Приглашение друга в Steam — сразу в окно коопа (и при запуске игры из
	# приглашения, +connect_lobby)
	Net.invite_join_started.connect(_on_invite_join)
	Net.take_pending_invite.call_deferred()
	# Сеанс коопа оборвался (хост вышел, пропала связь) — окно коопа скажет,
	# что случилось (Net.notice)
	if Net.notice != "":
		_on_invite_join.call_deferred()

	title_label.call("setup_grid", LOGO_ANIM_SHEET, LOGO_ANIM_COLUMNS, LOGO_ANIM_ROWS,
		1.0 / LOGO_ANIM_FPS)
	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = LOGO_SHADER
	_logo_mat.set_shader_parameter("rect_size", title_label.size)
	_logo_mat.set_shader_parameter("ash", LOGO_ASH)
	title_label.material = _logo_mat

	_move_audio = Style.ui_player(self)
	_setup_audio_loops()
	_setup_atmosphere()
	_setup_bottom_bar()
	_connect_buttons()
	_setup_save_line()
	_refresh_continue()
	settings_panel.closed.connect(_on_overlay_closed)
	_animate_intro()


func _exit_tree() -> void:
	get_tree().root.content_scale_aspect = _prev_aspect


# ── Звук: музыка на шине Music (её крутит ползунок «Музыка»), ветер на утёсе
# ── и треск костра фоном, интерфейс — на шине "UI" ────────────────────────────
func _setup_audio_loops() -> void:
	var music := ambient_music.stream as AudioStreamMP3
	if music:
		music.loop = true

	# Петли — через SoundBank.loop_stream: он делает КОПИЮ потока с петлёй.
	# Сам WAV общий с уровнями, и выставлять ему loop_mode напрямую нельзя
	# (было: невалидный loop_end портил общий ресурс, и звук пропадал на уровне)
	_wind = _ambience_loop("ambience/wind_loop.wav", -17.0)
	_fire = _ambience_loop("ambience/fire_loop.wav", -21.0)
	# Шелест сухой травы на утёсе (синтез: tools/menu_grass_bake.gd)
	_grass = _ambience_loop("ambience/grass_loop.wav", -26.0)
	_gust_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_gust_noise.frequency = 1.0
	_gust_noise.seed = randi()

	_thunder = AudioStreamPlayer.new()
	_thunder.stream = SOUND_THUNDER
	add_child(_thunder)


func _ambience_loop(rel: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = SoundBank.loop_stream(rel)
	p.volume_db = db
	add_child(p)
	if p.stream:
		# С разного места: ветер и огонь не начинают вместе каждый запуск
		p.play(randf() * p.stream.get_length() * 0.7)
	return p


func _play_ui_sound(stream: AudioStream) -> void:
	Style.play(ui_audio, stream)


## Порывы ветра: одна медленная кривая качает громкость ветра и травы (трава
## в порыв шуршит заметно сильнее, в затишье почти смолкает) и снос искр
## костра. Порыв — раз в 10–20 секунд
func _process(delta: float) -> void:
	if _quitting:
		return
	_gust_t += delta
	var g := clampf(0.5 + _gust_noise.get_noise_1d(_gust_t * 0.08) * 0.95, 0.0, 1.0)
	if _wind:
		_wind.volume_db = lerpf(-23.0, -12.0, g)
	if _grass:
		_grass.volume_db = lerpf(-36.0, -17.0, g * g)
	if _backdrop:
		_backdrop.set("gust", g)


# ── Атмосфера: живой фон, цветокоррекция, гроза ───────────────────────────────
func _setup_atmosphere() -> void:
	# Фон — первым ребёнком корня: рисуется под всем интерфейсом
	_backdrop = BackdropScript.new()
	add_child(_backdrop)
	move_child(_backdrop, 0)

	# Цветокоррекция кадра (menu_grade.gdshader) — лёгкая: картинка уже
	# ночная и холодная, тёмные эффекты (колодец под меню, тяжёлая виньетка,
	# зерно) её только душили. Осталось чуть приглушённого цвета с холодом в
	# тенях и мягкие края кадра. Туман живёт в самом фоне (MenuBackdrop)
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = GRADE_SHADER
	gm.set_shader_parameter("use_fog", false)
	gm.set_shader_parameter("desat", 0.12)
	gm.set_shader_parameter("exposure", 1.0)
	gm.set_shader_parameter("well_dark", 0.0)
	gm.set_shader_parameter("vignette", 0.3)
	gm.set_shader_parameter("grain", 0.0)
	gm.set_shader_parameter("shadow_tint", Color(0.9, 0.94, 1.0))
	gm.set_shader_parameter("light_tint", Color(1.0, 0.98, 0.95))
	grade.material = gm
	effects_layer.add_child(grade)
	effects_layer.move_child(grade, 0)

	# Огонь, искры и щепки — поверх цветокоррекции: это источники света
	_backdrop.call("setup_fx", effects_layer)

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


func _schedule_lightning(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(_lightning)


## Двойная вспышка, следом — раскат грома с задержкой (молния далеко).
## reschedule = false — разовая вспышка (выход с заставки), цепочку
## случайных молний она не трогает
func _lightning(reschedule := true) -> void:
	if not is_inside_tree() or _quitting:
		return
	# Далёкая гроза, а не спецэффект: свет вспыхивает внутри облаков
	# (только небо — горы и скала остаются силуэтами), гром тихий
	var peak := randf_range(0.3, 0.5)
	var set_flash := func(v: float): _backdrop.call("set_flash", v)
	var t := create_tween()
	t.tween_method(set_flash, 0.0, peak * 0.6, 0.04)
	t.tween_method(set_flash, peak * 0.6, 0.1, 0.08)
	t.tween_method(set_flash, 0.1, peak, 0.05)
	t.tween_method(set_flash, peak, 0.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	get_tree().create_timer(randf_range(0.5, 1.4)).timeout.connect(func():
		if is_instance_valid(_thunder) and not _quitting:
			_thunder.volume_db = randf_range(-16.0, -11.0)
			_thunder.pitch_scale = randf_range(0.88, 1.04)
			_thunder.play())
	if reschedule:
		_schedule_lightning(randf_range(lightning_interval.x, lightning_interval.y))


# ── Нижняя строка: версия слева, подсказки клавиш справа ──────────────────────
func _setup_bottom_bar() -> void:
	version_label.add_theme_font_override("font", Style.caps_font())
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", Color(Style.TEXT_DIM, 0.45))
	# Текст собирается руками — переводить готовую строку целиком не нужно
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_refresh_version()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(spacer)
	# Подсказки — тише версии не надо, но и не на первом плане
	var hints := Style.hint_row([["Enter", "Выбрать"], ["Esc", "Выход"]])
	hints.modulate.a = 0.6
	bottom_bar.add_child(hints)


## Версия — из настроек проекта (application/config/version), а не строкой
## в сцене: меняется в одном месте, и в экспорте та же
func _refresh_version() -> void:
	var ver := String(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	version_label.text = "v%s  ·  %s" % [ver, tr("ранний доступ")]


# ── Интро: из темноты проявляется фон, затем лого, затем пункты по одному ─────
# При первом запуске между лого и пунктами — заставка «Нажмите любую клавишу»
func _animate_intro() -> void:
	# Фон неподвижен с первого кадра: наезд камеры (масштаб 1.05 → 1) убран —
	# с округлением позиции до пикселя картинка мелко тряслась весь наезд
	title_label.modulate.a = 0.0
	left_panel.modulate.a = 0.0
	bottom_bar.modulate.a = 0.0
	for c in _menu_items():
		c.modulate.a = 0.0

	var title := not _title_seen
	# Из темноты — медленно: souls-like не торопится
	var bg_t := create_tween().set_parallel(true)
	bg_t.tween_property(_fade_rect, "color:a", 0.0, 3.0 if title else 1.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Лого проступает из темноты раскалённым и остывает до пепла
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(title_label, "modulate:a", 1.0, 2.4)\
		.set_delay(1.2 if title else 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_intro_tween.tween_method(func(v: float): _logo_mat.set_shader_parameter("heat", v), 1.0, 0.0, 4.0)\
		.set_delay(1.2 if title else 0.6).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(4.6 if title else 2.6).timeout.connect(_logo_sweep)

	if title:
		_start_title()
	else:
		_reveal_menu(1.4)


## Пункты проступают по одному на месте подсказки, следом — низ экрана.
## Без выезда сбоку: только свет
func _reveal_menu(delay: float) -> void:
	left_panel.modulate.a = 1.0
	left_panel.visible = true
	var t := create_tween().set_parallel(true)
	var i := 0
	for c in _menu_items():
		t.tween_property(c, "modulate:a", 1.0, 0.7).set_delay(delay + i * 0.12)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		i += 1
	t.tween_property(bottom_bar, "modulate:a", 1.0, 1.2).set_delay(delay + 0.4 + i * 0.12)
	# Фокус на главном пункте: с клавиатуры/геймпада можно сразу листать
	get_tree().create_timer(delay + 0.25).timeout.connect(func():
		if not _overlay_open and not _title_active:
			_focus_quiet(_default_button()))


## Видимые пункты колонки по порядку
func _menu_items() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	for c in btn_new.get_parent().get_children():
		if c is CanvasItem and c.visible:
			out.append(c)
	return out


func _start_title() -> void:
	_title_active = true
	left_panel.visible = false

	# Подсказка — на месте будущего меню, в его колонке
	var vp := get_viewport_rect().size
	_title_prompt = Style.label("НАЖМИТЕ ЛЮБУЮ КЛАВИШУ", 19, Color(0.86, 0.83, 0.78), true)
	_title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Размытая тень вокруг букв: подсказка читается на светлых камнях утёса
	_title_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_title_prompt.add_theme_constant_override("shadow_offset_x", 0)
	_title_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_title_prompt.add_theme_constant_override("shadow_outline_size", 14)
	_title_prompt.position = Vector2(0, left_panel.position.y + 90.0).round()
	_title_prompt.size = Vector2(vp.x, 40)
	_title_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_prompt.modulate.a = 0.0
	title_label.get_parent().add_child(_title_prompt)
	get_tree().create_timer(3.6).timeout.connect(_pulse_prompt)


## Подсказка «дышит»: медленно разгорается и гаснет, но не пропадает совсем
func _pulse_prompt() -> void:
	if not _title_active or not is_instance_valid(_title_prompt):
		return
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_title_prompt, "modulate:a", 0.75, 1.6).set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_callback(func():
		if not _title_active or not is_instance_valid(_title_prompt):
			return
		_prompt_loop = create_tween().set_loops()
		_prompt_loop.tween_property(_title_prompt, "modulate:a", 0.2, 2.0)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_prompt_loop.tween_property(_title_prompt, "modulate:a", 0.75, 2.0)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE))


## Любая клавиша на заставке: тусклая далёкая вспышка с громом, подсказка
## гаснет, на её месте проступают пункты.
## instant — без вспышки (например, пришло приглашение в Steam)
func _leave_title(instant := false) -> void:
	if not _title_active:
		return
	_title_active = false
	_title_seen = true
	for tw in [_intro_tween, _prompt_tween, _prompt_loop]:
		if tw:
			tw.kill()
	if not instant:
		_play_ui_sound(SOUND_ACCEPT)
		_lightning(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade_rect, "color:a", 0.0, 0.4)
	t.tween_property(title_label, "modulate:a", 1.0, 0.4)
	# Разогрев лого мог оборваться на середине — гасим жар плавно
	var heat := float(_logo_mat.get_shader_parameter("heat"))
	t.tween_method(func(v: float): _logo_mat.set_shader_parameter("heat", v), heat, 0.0, 1.2)
	if is_instance_valid(_title_prompt):
		t.tween_property(_title_prompt, "modulate:a", 0.0, 0.35)
		t.chain().tween_callback(_title_prompt.queue_free)
	_reveal_menu(0.0 if instant else 0.45)


func _input(event: InputEvent) -> void:
	if not _title_active:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_leave_title()
	elif not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


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
	get_tree().create_timer(randf_range(14.0, 22.0)).timeout.connect(_logo_sweep)


# ── Пункты меню ───────────────────────────────────────────────────────────────
func _connect_buttons() -> void:
	# «Кооп» — копия пункта меню (тот же MenuButton.gd), встаёт перед «Настройками»
	btn_coop = btn_settings.duplicate(Node.DUPLICATE_SCRIPTS) as Button
	btn_coop.name = "BtnCoop"
	btn_coop.text = "КООП"
	btn_settings.get_parent().add_child(btn_coop)
	btn_settings.get_parent().move_child(btn_coop, btn_settings.get_index())
	btn_continue.pressed.connect(_on_continue)
	btn_new.pressed.connect(_on_new_game)
	btn_load.pressed.connect(_on_load)
	btn_coop.pressed.connect(_on_coop)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)
	_buttons = [btn_continue, btn_new, btn_load, btn_coop, btn_settings, btn_quit]
	for b in _buttons:
		b.focus_entered.connect(_on_item_focus.bind(b))


func _on_item_focus(b: Button) -> void:
	_last_focus = b
	_show_save_line(b == btn_continue and btn_continue.visible)
	if not _quiet_focus:
		Style.play_move(_move_audio)


## Мягкая тень за текстом пунктов: размытое тёмное пятно под каждой строкой,
## а не затемнение кадра. У Button нет размытой тени шрифта, поэтому — слой
## под колонкой меню, который повторяет её прозрачность
class TextHalo extends Control:
	var items: Array = []
	var follow: CanvasItem
	var _tex: GradientTexture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 128
		_tex.height = 64

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if follow == null or not follow.visible:
			return
		var base := follow.modulate.a
		for it: Control in items:
			if not is_instance_valid(it) or not it.is_visible_in_tree():
				continue
			var a := base * it.modulate.a
			if a <= 0.01:
				continue
			var txt := tr(it.get("text")) if it is Button else tr((it as Label).text)
			if txt == "":
				continue
			var f: Font = it.get_theme_font("font")
			var fs: int = it.get_theme_font_size("font_size")
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var c := it.get_global_rect().get_center() - global_position
			var sz := Vector2(tw + 150.0, fs * 2.6)
			draw_texture_rect(_tex, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, 0.5 * a))


## Строка под пунктами: «Воин · 1 ч 12 мин в пути · 25.11.2026». Тусклая,
## видна только пока выбран «Продолжить» — как подпись к нему, а не отдельный
## блок. Лежит в колонке меню и гаснет вместе с ней (_set_menu_shown)
func _setup_save_line() -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(gap)
	_save_line = Style.label("", 15, Color(0.7, 0.68, 0.64))
	_save_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_save_line.add_theme_font_override("font", Style.italic_font())
	_save_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_line.modulate.a = 0.0
	left_panel.add_child(_save_line)

	# Тени за текстом — под колонкой меню, в том же слое интерфейса
	var halo := TextHalo.new()
	halo.follow = left_panel
	var items: Array = []
	items.append_array(_buttons)
	items.append(_save_line)
	halo.items = items
	left_panel.get_parent().add_child(halo)
	left_panel.get_parent().move_child(halo, left_panel.get_index())


func _show_save_line(on: bool) -> void:
	if _save_line == null:
		return
	if _save_line_tween:
		_save_line_tween.kill()
	_save_line_tween = create_tween()
	_save_line_tween.tween_property(_save_line, "modulate:a", 1.0 if on else 0.0, 0.5 if on else 0.25)\
		.set_ease(Tween.EASE_OUT)


func _focus_quiet(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		return
	_quiet_focus = true
	c.grab_focus()
	_quiet_focus = false


func _default_button() -> Button:
	return btn_continue if btn_continue.visible else btn_new


## «Продолжить» — только если есть сохранение; что именно продолжим,
## говорит строка под пунктами
func _refresh_continue() -> void:
	var has := SaveManager.slot_exists(SINGLE_SLOT)
	btn_continue.visible = has
	_save_line.text = _save_line_text() if has else ""
	_link_focus_chain()


func _save_line_text() -> String:
	var s := _save_summary()
	var ms := int(SaveManager.peek_slot(SINGLE_SLOT).get("last_played_ms", 0))
	if ms > 0:
		var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var d := Time.get_datetime_dict_from_unix_time(ms / 1000 + bias)
		s += "  ·  %02d.%02d.%d" % [d.day, d.month, d.year]
	return s


## Язык сменили в настройках — строки версии и сейва собраны руками и сами
## не переводятся (пункты меню и прочие Label переводятся сами)
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_version()
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
	if _overlay_open or _quitting or _title_active:
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
					_open_character_select(), true)
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


## Приняли приглашение в Steam, пока сидим в меню: окно коопа покажет, как
## идёт подключение (если оно ещё не открыто)
func _on_invite_join() -> void:
	_leave_title(true)
	for c in settings_panel.get_parent().get_children():
		if c.get_script() == CoopPanelScript:
			return
	_on_coop()


## Лобби совместной игры (CoopPanel.gd, сеть — Net/net.gd)
func _on_coop() -> void:
	_play_ui_sound(SOUND_ACCEPT)
	var p: Control = CoopPanelScript.new()
	p.scene_path = SCENE_GAME
	p.closed.connect(_on_overlay_closed)
	settings_panel.get_parent().add_child(p)
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
	for p: AudioStreamPlayer in [ambient_music, _wind, _fire, _grass]:
		t.tween_property(p, "volume_db", -60.0, 0.7).set_ease(Tween.EASE_IN)
	await t.finished
	get_tree().quit()


## Окно «да/нет» поверх меню; пока оно открыто, меню ввод не получает
func _confirm(title: String, body: String, yes_text: String, no_text: String,
		default_yes: bool, on_answer: Callable, danger := false) -> void:
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
	d.danger = danger
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
