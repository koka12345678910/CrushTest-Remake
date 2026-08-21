extends CharacterBody2D

@export var walk_speed := 100.0
@export var run_speed := 200.0
@export var hit_vfx_scene: PackedScene
@export var running_hit_vfx_scene: PackedScene
@export var move_start_vfx_scene: PackedScene
@export var melee_hit_vfx_scene: PackedScene
@export var melee_hit_2_vfx_scene: PackedScene
@export var turn_around_vfx_scene: PackedScene
@export var snap_radius := 80.0  # радиус поиска врагов
@export var posture_regen_rate := 10.0
@export var posture_regen_delay := 2.5
# --- БЛОК (зажатое ПКМ, is_blocking) ---
# Сколько концентрации заполняет один заблокированный удар — блок не убирает
# урон бесплатно, вместо этого копится усталость от держания щита
@export var block_posture_gain := 16.0
@export var block_shake_strength := 3.0
# Блок работает только спереди — щит не закрывает спину. dot(facing, to_attacker)
# > 0 — это ровно фронтальная половина (180°); выше — уже конус, ниже —
# шире прикрытие по бокам
@export_range(-1.0, 1.0) var block_frontal_dot_threshold := 0.0
@export var fenrir_hit_vfx_scene: PackedScene
@export var fire_ring_vfx_scene: PackedScene
@export var berserk_hit_vfx_scene: PackedScene

@onready var melee_hit = $MeleeHit
@onready var weapon_tip := $WeaponTip
@onready var anim: AnimationPlayer = $PlayerAnimation
@onready var gfx := $PlayerAnim
@onready var foot_point = $FootPoint
@onready var foot_point2 = $FootPoint2
@onready var ability_system: AbilitySystem = $AbilitySystem
@onready var inventory_system: InventorySystem = $InventorySystem
@onready var health_bar = $HealthStaminaBar
@onready var inventory_ui = $InventoryUI
@onready var hurtbox: Area2D = $HurtBox
@onready var player_hitbox: Area2D = $PlayerHitbox
@onready var parry_vfx: AnimatedSprite2D = $ParryVFXanim
@onready var hud = $HUD
@onready var damage_vignette = $DamageVignette
@onready var hit_flash = $HitFlash
@onready var exhaust_vignette = $ExhaustVignette
@onready var heartbeat_audio: AudioStreamPlayer = $HeartbeatAudio
@onready var dyspnea_audio: AudioStreamPlayer = $DyspneaAudio
@onready var camera: Camera2D = $Camera2D

# Тряска камеры при получении урона
@export var damage_shake_strength := 10.0
# Тряска при ПОПАДАНИИ своего удара по врагу — слабее, чем от урона: атака
# должна ощущаться весомо, но не путаться с "меня бьют"
@export var hit_shake_strength := 3.0
# Тряска при удачном парировании — короткий металлический "чирк", заметно
# слабее урона, но чуть сильнее обычного попадания: парировать должно
# ощущаться весомо (звон металла), а не как лёгкий тычок
@export var parry_shake_strength := 5.0
# Более высокий тон читается ухом как "звонче" — обычный лязг ощущается
# глуше, чем чистый высокий звон металла
@export var parry_pitch_mult := 1.15
# Тряска на идеальный уворот — слабее парирования: это не столкновение
# металла, а лёгкий рывок в сторону от удара
@export var perfect_dodge_shake_strength := 4.0
# Тряска, когда КОНТРАТАКУЮТ игрока (receive_parry — враг спарировал/пробил
# концентрацию и оглушил, оба сценария стана). Полное пробитие концентрации —
# стан держится дольше, и тряска должна
# держаться ВСЁ это время, а не мигнуть один раз. В отличие от дрожи
# истощения (та специально сглажена, "усталые руки") здесь наоборот нужна
# РЕЗКАЯ, дёрганая тряска — игрока только что оглушили, это должно
# ощущаться как потеря контроля, а не мягкое покачивание. Цель меняется
# очень часто (маленький update_rate) и камера почти мгновенно её
# догоняет (высокий smoothing) — сумма даёт дёрганое, а не плавное дрожание
@export var full_stun_duration := 3.0
@export var stun_shake_strength := 11.0
@export var stun_shake_update_rate := 0.025
@export var stun_shake_smoothing := 45.0
var _stun_shake_active := false
var _stun_shake_target := Vector2.ZERO
var _stun_shake_current := Vector2.ZERO
var _stun_shake_timer := 0.0
# Вспышка при подборе монеты — тёплый золотой блик поверх спрайта игрока.
# Цвет специально ЗАСВЕЧЕН выше 1.0 (пересвет) — при обычных 1.0-1.7 это
# читается как лёгкий тон, а не как вспышка. Такой сильный пересвет + очень
# короткий in_time — тот самый "мини-флэш" из Sekiro на удачных действиях
@export var coin_glow_color := Color(4.0, 3.6, 1.8, 1.0)
@export var coin_glow_in_time := 0.03
@export var coin_glow_out_time := 0.15
# Разброс высоты тона на повторяющихся звуках (доля от 1.0)
@export var pitch_variation := 0.12
# Разброс громкости на повторяющихся звуках (в дБ, +/- от базовой)
@export var volume_variation_db := 1.8
# Базовая громкость каждого аудио-узла, снятая из сцены в _ready — джиттер
# всегда считается от неё, а не от текущего значения
var _base_volume_db: Dictionary = {}
# Индекс последнего сыгранного семпла в каждом пуле (чтобы не повторяться)
var _last_sample_idx: Dictionary = {}

# Вид игрока во время неуязвимости (додж/перекат/i-frames) — призрачный и
# холодный, чтобы игрок ВИДЕЛ, что тайминг сработал и урон сейчас не проходит.
# Красим self_modulate, а не modulate: последний занят вспышкой урона, они бы
# перетирали друг друга
@export var immune_tint := Color(0.6, 0.85, 1.0, 0.5)
@export var immune_visual_speed := 14.0

# Сила удара -> сила отдачи (тряска + длительность хитстопа). Раньше у лёгкого
# тычка и у добивающего вихря отдача была одинаковой, и разница между слабым и
# мощным ударом никак не ощущалась физически
@export var run_attack_impact_mult := 1.4
@export var spin_impact_mult := 2.2
@export var shake_decay := 6.0   # чем больше — тем быстрее гаснет
var _shake_strength := 0.0

# --- Состояния "на грани": низкое здоровье и полное истощение ---
# Низкое HP — только приглушённое сердцебиение.
@export var low_health_threshold := 20.0
# Истощение (стамина на нуле) — голубая виньетка, тряска и громкое
# сердцебиение. Включается на 0 и держится, пока стамина не восстановится
# до exhaust_fx_recover_threshold (гистерезис: иначе эффекты моргали бы,
# дёргаясь у самого нуля при малейшем регене)
@export var exhaust_fx_recover_threshold := 50.0
# Дрожь истощения — НЕ через общую систему тряски от удара (та рассчитана на
# одиночный импульс с затуханием). Здесь своя, отдельная и более мягкая логика:
# см. _exhaust_shake_target/_exhaust_shake_current и _process
@export var exhaust_shake_strength := 7.0
@export var exhaust_shake_update_rate := 0.09  # как часто меняется цель дрожи
@export var exhaust_shake_smoothing := 18.0    # скорость, с которой камера догоняет цель
var _exhaust_shake_target := Vector2.ZERO
var _exhaust_shake_current := Vector2.ZERO
var _exhaust_shake_timer := 0.0
@export var heartbeat_volume_low_hp := -18.0
@export var heartbeat_volume_exhausted := 3.0
@export var heartbeat_fade_speed := 25.0  # дБ в секунду, плавность нарастания
const HEARTBEAT_SILENT_DB := -40.0
# Одышка (dyspnea) — играется вместе с громким сердцебиением ТОЛЬКО при
# истощении (не на низком HP, в отличие от сердцебиения)
@export var dyspnea_volume := -3.0
var _exhaust_fx_active := false

# Плавное покачивание камеры во время бега — фигура-восьмёрка (лемниската):
# X колеблется на одинарной частоте, Y — на двойной, поэтому камера описывает
# плавную петлю по разным точкам, а не просто дёргается вверх-вниз по прямой
@export var run_bob_amplitude_x := 5.0
@export var run_bob_amplitude_y := 3.5
@export var run_bob_cycle_distance := 90.0  # больше = медленнее и спокойнее качает
@export var run_bob_fade_speed := 7.5       # скорость нарастания/затухания покачивания
# Доп. сглаживание итогового движения камеры. ВАЖНО: lerp с фиксированным
# коэффициентом работает как low-pass фильтр — на частоте покачивания при
# полном разгоне (Y-составляющая колеблется вдвое чаще X) он заметно СЪЕДАЕТ
# амплитуду сверху, а не только убирает рывки. Поэтому smoothing поднят вместе
# с амплитудой — иначе прибавка амплитуды просто терялась бы в фильтре
@export var run_bob_smoothing := 11.0
var _bob_phase := 0.0
var _bob_intensity := 0.0
var _bob_smoothed := Vector2.ZERO
@onready var swing_audio: AudioStreamPlayer2D = $SwingAudio
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio
@onready var voice_audio: AudioStreamPlayer2D = $VoiceAudio
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var block_audio: AudioStreamPlayer2D = $BlockAudio
@onready var parry_audio: AudioStreamPlayer2D = $ParryAudio
@onready var stun_audio: AudioStreamPlayer2D = $StunAudio
@onready var hurt_audio: AudioStreamPlayer2D = $HurtAudio
@onready var drink_audio: AudioStreamPlayer2D = $DrinkAudio
@onready var coin_audio: AudioStreamPlayer2D = $CoinAudio
@onready var body_impact_audio: AudioStreamPlayer2D = $BodyImpactAudio

# Слой "тела" звучит сильно ниже слоя оружия — это и делает его отдельным
# событием на слух, а не эхом того же удара
@export var body_layer_pitch := 0.55
# Сила удара -> звук. Лёгкий тычок и добивающий вихрь раньше звучали одинаково,
# хотя тряска камеры и хитстоп у них уже разные. Мощный удар громче И ниже —
# низкий тон ухо считывает как "тяжелее", это работает сильнее громкости
@export var impact_power_volume_db := 4.0
@export var impact_power_pitch_drop := 0.14
# Ниже этого веса удар музыку не трогает: если давить её на каждом тычке серии,
# эффект перестаёт читаться как акцент и превращается в постоянное "бульканье"
# громкости музыки
@export var duck_power_threshold := 1.3

# --- Пулы боевых сэмплов ---
# Каждое действие озвучивается НАБОРОМ файлов, а не одним. Питч-вариация
# маскирует повтор только первые минуты боя — дальше ухо всё равно узнаёт один
# и тот же семпл. Реальная вариативность = разные записи. Пул может содержать
# один файл (тогда работает как раньше); чтобы добавить вариантов, достаточно
# дописать сюда preload новой строкой — вся остальная логика не меняется.
const SWING_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/melee_sound/swing.mp3"),
]
const RUN_SWING_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/melee_sound/running_attack_swing.wav"),
]
# Попадание по врагу — свой пул в зависимости от удара серии
const HIT_1_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/melee_sound/hit.mp3"),          # 1-й удар
]
const HIT_REST_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/melee_sound/hit2.wav"),         # 2-й и 3-й удары
]
const RUN_HIT_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/melee_sound/running_attack_hit.wav"),  # удар на бегу
]
# --- Второй слой удара ("тело") ---
# Одиночный семпл на попадание звучит плоско, потому что настоящий удар — это
# ДВА события разом: звонкий лязг оружия и глухой тяжёлый удар по телу. Играем
# их параллельно разными плеерами. Здесь пока тот же семпл, но сильно
# опущенный по тону (body_layer_pitch) — низкая часть читается ухом как "туша",
# а не как металл. Заменить на настоящий thud-семпл = просто поменять preload
const BODY_IMPACT_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/melee_sound/hit2.wav"),
]
# Выхватывание меча — на старте игры
const UNSHEATH_SOUND := preload("res://Sound/melee_sound/unsneath_sword.wav")
# Боевые вскрики — вместе с замахом, по номеру удара серии
const GRUNT_1_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/groaning_sound/attack1.mp3"),
]
const GRUNT_2_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/groaning_sound/attack2.mp3"),
]
const GRUNT_3_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/groaning_sound/attack3.mp3"),
]
const GRUNT_RUN_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/groaning_sound/running_attack.mp3"),
]
# Шаги при ходьбе/беге — чередуются по пройденному расстоянию
const FOOTSTEP_LEFT := preload("res://Sound/Run/left-leg.wav")
const FOOTSTEP_RIGHT := preload("res://Sound/Run/right-leg.wav")
@export var footstep_step_distance := 42.0  # px пройденного пути на один шаг
var _footstep_distance := 0.0
# Звук блока — играется, когда удар игрока натыкается на блок врага
const BLOCK_HIT_SOUND := preload("res://Sound/melee_sound/block.wav")
var _footstep_left_next := true
# Звук парирования — играется при успешном парировании удара врага
const PARRY_SOUND := preload("res://Sound/melee_sound/parry.wav")
# Звук идеального уворота — играется через parry_audio (тот же узел, что и
# парирование: оба defensive-действия, звучат в разные моменты, конфликта
# нет). pulse.mp3 ранее нигде не использовался — свободный ассет в проекте
const PERFECT_DODGE_SOUND := preload("res://Sound/pulse.mp3")
# Звук ломающейся концентрации/оглушения — играется, когда игрока
# контратакуют (receive_parry), звучит на протяжении стана
const STUN_SOUND := preload("res://Sound/posture_break.mp3")
# Питьё зелья — общий звук для всех трёх аптечек
const DRINK_SOUND := preload("res://Sound/abilities_sound/drink_potion_sound.mp3")
# Крик боли при получении урона — пул из 4 разных вскриков вместо одного, чтобы
# на серии ударов не было слышно, что это один и тот же семпл по кругу
const HURT_SOUNDS: Array[AudioStream] = [
	preload("res://Sound/take_damage_sound/take_damage_sound_1.mp3"),
	preload("res://Sound/take_damage_sound/take_damage_sound_2.mp3"),
	preload("res://Sound/take_damage_sound/take_damage_sound_3.mp3"),
	preload("res://Sound/take_damage_sound/take_damage_sound_4.mp3"),
]
# Подбор монеты — сам звук уже звонкий, шина CoinEcho добавляет лёгкий
# металлический хвост, а не меняет тембр заново
const COIN_SOUND := preload("res://Sound/coin_picking.mp3")

var max_posture := 100.0
var current_posture := 0.0
var posture_regen_timer := 0.0

var attack_damage := 1
# 4-й удар серии — вихрь: урон и отброс по всем врагам вокруг
@export var spin_radius := 100.0
@export var spin_damage_mult := 2.0
@export var spin_knockback := 320.0
var prev_velocity := Vector2.ZERO
var move_vfx_cooldown := 0.0
var input_vector := Vector2.ZERO

# Нокбэк игрока при получении удара — игрок отлетает от врага.
# friction здесь — коэффициент lerp-затухания (больше = быстрее гаснет).
@export var knockback_force := 180.0
@export var knockback_friction := 9.0
var knockback_velocity := Vector2.ZERO

# Хитстоп — короткая заморозка в момент попадания (даёт «мясистость» удара)
@export var hitstop_duration := 0.06
@export var hitstop_scale := 0.0  # 0.0 = полная заморозка, 0.05 = лёгкий слоу-мо
# Слоу-мо на идеальный уворот («witch time») — заметно мягче хитстопа и
# ощутимо дольше: хитстоп — стоп-кадр на миг удара, это — растянутое
# мгновение "я успел" перед контратакой
@export var perfect_dodge_slowmo_scale := 0.25
@export var perfect_dodge_slowmo_duration := 0.35
# Общий счётчик для ЛЮБОГО управления Engine.time_scale от игрока (хитстоп
# и слоу-мо уворота) — если оба сработают почти одновременно (уворот →
# мгновенная контратака → хитстоп от попадания), должен победить самый
# ПОСЛЕДНИЙ вызов, а не тот, что запустился раньше. Раздельные токены дали
# бы рассинхрон: например, короткий хитстоп мог бы восстановить time_scale
# раньше, чем достоверно завершится более длинное слоу-мо, запущенное позже
var _timescale_token := 0
var is_running := false
var last_direction := "Down"

var is_attacking := false
var is_run_attacking := false
var attack_velocity := Vector2.ZERO
var friction := 3.0
var start_triggered := false
var was_running := false
var is_turning := false
var turn_direction := ""
var turn_threshold := -0.8
var turn_velocity := Vector2.ZERO
var turn_friction := 6.0

# --- COMBO SYSTEM ---
var combo_step := 0
var combo_timer := 0.0
var combo_window := 0.4
var combo_queued := false
# --------------------

var is_dodging := false
var dodge_velocity := Vector2.ZERO
var dodge_speed := 300.0
var dodge_friction := 4.0
var is_invulnerable := false
var baldur_revive_ready := false  # Благословение Бальдра: одноразовое воскрешение
var i_frame_time := 0.2
var dodge_tap_timer := 0.0
var dodge_tap_window := 0.18
var dodge_tap_count := 0
var facing_dir: Vector2 = Vector2.DOWN
var turn_lock := false

var is_rolling := false
var roll_speed := 225.0
var roll_duration := 0.9
var roll_timer := 1.5
var roll_dir := Vector2.ZERO
var roll_control := 0.0

# --- PARRY SYSTEM ---
var is_parrying := false
# Раньше 0.2 — при вспышке-предупреждении этого хватало, чтобы парировать
# "на глаз", не глядя на реальный замах врага. Теперь тайминг удара берётся
# из настоящей анимации замаха (enemy.gd, _state_attack), и окно сужено —
# нужно целиться в конкретный момент свинга, а не иметь запас на угадать
var parry_window := 0.12     # секунды активного окна
var parry_timer := 0.0
var parry_cooldown := 0.6       # кулдаун между парированиями
var parry_cd_timer := 0.0
var can_counter := false         # флаг — был perfect parry?
var counter_window := 0.5       # сколько времени есть на контратаку
var counter_timer := 0.0
var is_staggered := false       # враг застаггерен — доп. визуал/логика
var is_blocking := false
# --------------------

# VFX
var active_hit_vfx_override: PackedScene = null

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0

# --- Стамина: расход по действиям (снижено относительно старых значений) ---
@export var dodge_stamina_cost := 15.0     # было 20
@export var roll_stamina_cost := 22.0      # было 30
@export var attack_stamina_cost := 7.0     # было 10, за каждый удар серии
@export var run_stamina_drain := 10.0      # было 15, в секунду
@export var run_attack_stamina_drain := 12.0  # было 20.5 — но с багом: тратилось
# каждый КАДР, а не в секунду (~1230/сек), из-за чего стамина обнулялась мгновенно

# --- Истощение: когда стамина кончилась, игрок "выдохся" ---
@export var exhausted_speed_multiplier := 0.5   # во сколько раз медленнее ходьба
@export var exhausted_attack_speed_scale := 0.55  # во сколько раз медленнее анимация удара

func is_exhausted() -> bool:
	return health_bar.current_stamina <= 0.0

var active_buffs: Dictionary = {}
var active_ability_name := ""
var coins: int = 0

var normal_scale := Vector2(0.5, 0.5)
var ladder_scale := Vector2(0.65, 0.65)
var is_starting := true
var is_stunned := false
var is_taking_damage := false

var hit_targets: Array = []
var _nan_reported := false
var gold := 0
var is_in_shop := false

func _ready() -> void:
	player_hitbox.area_entered.connect(_on_player_hitbox_area_entered)
	player_hitbox.monitoring = false  # выключен по умолчанию, включается при атаке
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)
	
	# Запоминаем базовые громкости ДО первого проигрывания — дальше джиттер
	# в _play_varied отсчитывается от них
	for p: AudioStreamPlayer2D in [
		swing_audio, hit_audio, voice_audio, footstep_audio, block_audio, parry_audio,
		body_impact_audio, stun_audio, coin_audio, hurt_audio, drink_audio
	]:
		_base_volume_db[p] = p.volume_db

	anim.play("Started_" + last_direction)
	# Выхватывание меча из ножен в начале игры
	swing_audio.stream = UNSHEATH_SOUND
	swing_audio.play()
	print(anim.get_animation_list())
	add_to_group("player")
	player_hitbox.add_to_group("player_attack")
	player_hitbox.set_meta("damage", attack_damage)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	# Сердцебиение должно звучать непрерывно, пока держится состояние —
	# зацикливаем сам поток (тот же приём, что для музыки в главном меню)
	var heartbeat_stream := heartbeat_audio.stream as AudioStreamMP3
	if heartbeat_stream:
		heartbeat_stream.loop = true
	heartbeat_audio.volume_db = HEARTBEAT_SILENT_DB
	var dyspnea_stream := dyspnea_audio.stream as AudioStreamMP3
	if dyspnea_stream:
		dyspnea_stream.loop = true
	dyspnea_audio.volume_db = HEARTBEAT_SILENT_DB
	# Сначала инициализируем все системы
	health_bar.set_max_hp(max_health)
	health_bar.set_max_stamina(max_stamina)
	health_bar.set_max_posture(max_posture)
	inventory_ui.init(ability_system, inventory_system)
	hud.init(ability_system)
	
	# Только потом загружаем предметы
	_load_starting_abilities()

func _unhandled_input(event: InputEvent) -> void:
	if is_in_shop:
		return  # ← добавь, магазин сам обрабатывает свой Esc
	
	# Блокируем всё кроме инвентаря если он открыт. Esc обрабатывает сам
	# инвентарь (у него есть подразделы — настройки и навыки, и Esc должен
	# закрывать сначала их, а не всё окно целиком)
	if inventory_ui.visible:
		return
	
	# Переключение слотов только когда не атакуем и не уклоняемся
	if is_attacking or is_dodging or is_rolling:
		return
	if event.is_action_pressed("slot_next"):
		ability_system.next_slot()
	elif event.is_action_pressed("slot_prev"):
		ability_system.prev_slot()
	elif event.is_action_pressed("ability_use"):
		# Не даём использовать абилку во время атаки/додже
		if not is_attacking and not is_dodging and not is_rolling and not is_parrying:
			ability_system.use_current(self)
	if event.is_action_pressed("ui_cancel"):
		# Сюда доходим только с закрытым инвентарём (открытый отсекается выше и
		# сам гасит Esc), так что здесь остаётся только открытие
		inventory_ui.open()

func _process(delta: float) -> void:
	# Обновляем состояния "на грани" ДО расчёта тряски — истощение подкачивает
	# _shake_strength, и так тряска применится уже в этом же кадре
	_update_condition_fx(delta)
	_update_immunity_visual(delta)

	# Итоговое смещение камеры = тряска от урона + плавное покачивание на беге.
	# Считаем их по отдельности и складываем, а не перезаписываем camera.offset
	# в двух местах — иначе один эффект стирал бы другой.

	# Тряска от урона — случайное смещение, угасающее со временем ("trauma"-
	# подход: просто затухающая величина, а не путь твина, поэтому повторные
	# удары естественно накладываются друг на друга без рывков)
	var shake_offset := Vector2.ZERO
	if _shake_strength > 0.01:
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, shake_decay * _shake_strength * delta + 1.0 * delta)
	else:
		_shake_strength = 0.0

	# Плавное покачивание камеры на беге — фигура-восьмёрка, а не прямая
	# вверх-вниз: X колеблется на одинарной частоте, Y — на двойной, вместе
	# камера описывает плавную петлю по разным точкам. Цикл длиннее, чем шаг
	# (run_bob_cycle_distance > footstep_step_distance), поэтому качает спокойнее,
	# а не резко в такт каждому шагу. Амплитуда плавно нарастает/гаснет при
	# старте/остановке бега, а сверху ещё лёгкое сглаживание итоговой позиции —
	# камера "догоняет" цель, а не дёргается к ней рывком
	var is_sprinting := velocity.length() >= 120.0
	_bob_intensity = move_toward(_bob_intensity, 1.0 if is_sprinting else 0.0, run_bob_fade_speed * delta)
	var bob_target := Vector2.ZERO
	if _bob_intensity > 0.001:
		_bob_phase += velocity.length() * delta
		var t := _bob_phase / run_bob_cycle_distance * TAU
		bob_target = Vector2(sin(t) * run_bob_amplitude_x, sin(t * 2.0) * run_bob_amplitude_y) * _bob_intensity

	_bob_smoothed = _bob_smoothed.lerp(bob_target, minf(run_bob_smoothing * delta, 1.0))

	_exhaust_shake_current = _exhaust_shake_current.lerp(_exhaust_shake_target, minf(exhaust_shake_smoothing * delta, 1.0))

	# Дрожь полного стана — обновляем цель, только пока активна (см.
	# _start_stun_shake/_stop_stun_shake, дёргаются из receive_parry)
	if _stun_shake_active:
		_stun_shake_timer -= delta
		if _stun_shake_timer <= 0.0:
			_stun_shake_timer = stun_shake_update_rate
			_stun_shake_target = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * stun_shake_strength
	_stun_shake_current = _stun_shake_current.lerp(_stun_shake_target, minf(stun_shake_smoothing * delta, 1.0))

	# Множитель тряски из настроек применяем ОДНОЙ точкой на сумму всех трёх
	# трясок (удар, истощение, стан) — так настройка накрывает их разом, и
	# добавив четвёртую, её не забудешь подключить. Покачивание на беге
	# (_bob_smoothed) сюда намеренно не входит: это не тряска, а походка,
	# и выключать её вместе с тряской неправильно
	var shake_scale: float = GameSettings.shake_multiplier
	camera.offset = (shake_offset + _exhaust_shake_current + _stun_shake_current) * shake_scale \
		+ _bob_smoothed


func _update_immunity_visual(delta: float) -> void:
	# то же условие, что и в receive_attack — визуал показывает РЕАЛЬНУЮ
	# неуязвимость, а не приблизительную (иначе игрок учился бы врать себе)
	var immune := is_invulnerable or is_dodging or is_rolling
	var target := immune_tint if immune else Color.WHITE
	# вес lerp обязательно ограничиваем: при просадке FPS speed*delta уходит
	# за 1.0, и цвет проскакивает мимо цели, начиная колебаться вокруг неё
	var weight := minf(immune_visual_speed * delta, 1.0)
	gfx.self_modulate = gfx.self_modulate.lerp(target, weight)


func _update_condition_fx(delta: float) -> void:
	var stamina: float = health_bar.current_stamina
	var hp: float = health_bar.current_hp

	# --- Истощение: входим при нулевой стамине, выходим только когда она
	# восстановится до порога (гистерезис против мерцания у нуля) ---
	if _exhaust_fx_active:
		if stamina >= exhaust_fx_recover_threshold:
			_exhaust_fx_active = false
	elif stamina <= 0.0:
		_exhaust_fx_active = true

	exhaust_vignette.set_active(_exhaust_fx_active)

	# Дрожь истощения: цель обновляется РЕДКО (exhaust_shake_update_rate), а
	# не каждый кадр — раньше здесь был shake_camera() на каждом кадре, из-за
	# чего сила тряски держалась на максимуме и каждый кадр выдавала новое
	# случайное смещение. Глазом это читалось как шум, а не как дрожание.
	# Плавный lerp к редко сменяемой цели (в _process) даёт характерное
	# дрожание уставших рук вместо мельтешения
	_exhaust_shake_timer -= delta
	if _exhaust_fx_active:
		if _exhaust_shake_timer <= 0.0:
			_exhaust_shake_timer = exhaust_shake_update_rate
			_exhaust_shake_target = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * exhaust_shake_strength
	else:
		_exhaust_shake_target = Vector2.ZERO

	# --- Сердцебиение: тихое на низком HP, громкое при истощении ---
	var low_hp := hp > 0.0 and hp <= low_health_threshold
	var want_heartbeat := _exhaust_fx_active or low_hp

	var target_db := HEARTBEAT_SILENT_DB
	if want_heartbeat:
		target_db = heartbeat_volume_exhausted if _exhaust_fx_active else heartbeat_volume_low_hp

	# стартуем с тишины и плавно выводим громкость — иначе звук "щёлкал" бы
	# при включении и при переходе тихое->громкое
	if want_heartbeat and not heartbeat_audio.playing:
		heartbeat_audio.volume_db = HEARTBEAT_SILENT_DB
		heartbeat_audio.play()

	if heartbeat_audio.playing:
		heartbeat_audio.volume_db = move_toward(
			heartbeat_audio.volume_db, target_db, heartbeat_fade_speed * delta
		)
		if not want_heartbeat and heartbeat_audio.volume_db <= HEARTBEAT_SILENT_DB + 0.01:
			heartbeat_audio.stop()

	# --- Одышка: только при истощении, вместе с сердцебиением и виньеткой ---
	var dyspnea_target_db := dyspnea_volume if _exhaust_fx_active else HEARTBEAT_SILENT_DB

	if _exhaust_fx_active and not dyspnea_audio.playing:
		dyspnea_audio.volume_db = HEARTBEAT_SILENT_DB
		dyspnea_audio.play()

	if dyspnea_audio.playing:
		dyspnea_audio.volume_db = move_toward(
			dyspnea_audio.volume_db, dyspnea_target_db, heartbeat_fade_speed * delta
		)
		if not _exhaust_fx_active and dyspnea_audio.volume_db <= HEARTBEAT_SILENT_DB + 0.01:
			dyspnea_audio.stop()


func shake_camera(strength: float) -> void:
	_shake_strength = max(_shake_strength, strength)


func _start_stun_shake() -> void:
	_stun_shake_active = true
	_stun_shake_timer = 0.0


func _stop_stun_shake() -> void:
	_stun_shake_active = false
	_stun_shake_target = Vector2.ZERO


func _physics_process(delta):
	# speed_scale — общее свойство AnimationPlayer на ВСЕ анимации, не только
	# на бег. Сбрасываем его тут по умолчанию каждый кадр; если в этом же
	# кадре ниже сработает бег — play_movement_animation() перезапишет его
	# скейлом под скорость. Иначе оставшийся с бега scale тянется на атаку,
	# додж, парирование и т.д., и они играют в замедлении.
	anim.speed_scale = 1.0
	# Санитизация от NaN — не даём нефинитной позиции/скорости уронить физику
	# (иначе move_and_slide спамит "cannot be normalized" и игра встаёт)
	if not (global_position.is_finite() and velocity.is_finite()):
		if not _nan_reported:
			_nan_reported = true
			push_warning("[player NaN] pos=%s vel=%s kb=%s dodge=%s attack=%s" % [global_position, velocity, knockback_velocity, dodge_velocity, attack_velocity])
		if not global_position.is_finite():
			global_position = Vector2.ZERO
		velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
		dodge_velocity = Vector2.ZERO
		attack_velocity = Vector2.ZERO
	if is_in_shop:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Блокируем всё если инвентарь открыт
	if inventory_ui.visible:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if is_starting:
		return
	if is_rolling:
		handle_roll(delta)
		return

	# --- ДОДЖ / ПЕРЕКАТ «ВНЕ ОЧЕРЕДИ» ------------------------------------------
	# Ввод и запуск уворота/переката обрабатываем ДО стана получения урона и
	# нокбэка, чтобы зажатого игрока нельзя было залочить: он всегда может
	# вырваться уворотом/перекатом (оба дают неуязвимость в _on_hurtbox).
	if not is_rolling:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")
	handle_dodge_input()
	if dodge_tap_timer > 0:
		dodge_tap_timer -= delta
		if dodge_tap_timer <= 0:
			# 🔥 РЕШАЕМ: dodge или roll
			if dodge_tap_count >= 2:
				interrupt_all_actions()
				start_roll()
			else:
				interrupt_all_actions()
				start_dodge()
			dodge_tap_count = 0
	# Перекат, запущенный этим же кадром, отрабатываем сразу
	if is_rolling:
		handle_roll(delta)
		return
	# Активный уворот двигается здесь — до блоков стана/нокбэка
	if is_dodging:
		dodge_velocity = dodge_velocity.lerp(Vector2.ZERO, dodge_friction * delta)
		velocity = dodge_velocity
		move_and_slide()
		return

	# Нокбэк от удара врага — короткая потеря контроля, игрок отлетает.
	# Плавное экспоненциальное затухание (мягкий выкат, без резкого рывка).
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_friction * delta)
		if knockback_velocity.length() < 5.0:
			knockback_velocity = Vector2.ZERO
		velocity = knockback_velocity
		move_and_slide()
		return

	prev_velocity = velocity
	handle_attack_input()
	handle_kick_input()
	handle_parry_input(delta)
	check_for_turn()
	if is_taking_damage or is_parrying or is_blocking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_turning:
	# 🔥 плавно гасим скорость
		turn_velocity = turn_velocity.lerp(Vector2.ZERO, turn_friction * delta)
		
		velocity = turn_velocity
		move_and_slide()
		return
	
	# --- RUN ATTACK ---
	if is_run_attacking:
		combo_timer -= delta
		use_stamina(run_attack_stamina_drain * delta)
		anim.speed_scale = exhausted_attack_speed_scale if is_exhausted() else 1.0
		attack_velocity = attack_velocity.lerp(Vector2.ZERO, friction * delta)
		velocity = attack_velocity
		move_and_slide()
		return

	# --- обычная атака с микро-рывком ---
	if is_attacking:
		combo_timer -= delta
		# выдохся — удары идут медленнее и тяжелее (каждый кадр, а не один раз
		# в play_attack: speed_scale общий на весь AnimationPlayer и сбрасывается
		# в 1.0 в начале каждого физического кадра)
		anim.speed_scale = exhausted_attack_speed_scale if is_exhausted() else 1.0
		attack_velocity = attack_velocity.lerp(Vector2.ZERO, friction * delta)
		velocity = attack_velocity
		move_and_slide()
		return
		
	# реген концентрации игрока
	if current_posture > 0.0:
		posture_regen_timer -= delta
		if posture_regen_timer <= 0.0:
			current_posture = max(0.0, current_posture - posture_regen_rate * delta)
			health_bar.set_posture(current_posture)

	# --- обычное движение ---
	var target_speed = walk_speed
	if is_exhausted():
		# выдохся — бежать не может вообще, даже ходьба медленнее
		target_speed = walk_speed * exhausted_speed_multiplier
	elif is_running:
		use_stamina(run_stamina_drain * delta)
		target_speed = run_speed

	var target_velocity = input_vector.normalized() * target_speed

# --- разные коэффициенты для разгона и торможения ---
	var accel := 6.0      # разгон
	var friction_run := 4.0   # торможение

	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(target_velocity, accel * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction_run * delta)

	move_and_slide()
	if input_vector != Vector2.ZERO and not turn_lock:
		facing_dir = input_vector.normalized()
		last_direction = get_direction(facing_dir)
	play_movement_animation()
	handle_movement_vfx(delta)
	handle_footsteps(delta)


# ----------------------------------------------------------
# НАПРАВЛЕНИЯ
# ----------------------------------------------------------

func get_direction(vec: Vector2) -> String:
	var dir = ""

	if vec.y < -0.3:
		dir = "Up"
	elif vec.y > 0.3:
		dir = "Down"

	if vec.x < -0.3:
		if dir == "":
			dir = "Left"
		else:
			dir += "_Left"
	elif vec.x > 0.3:
		if dir == "":
			dir = "Right"
		else:
			dir += "_Right"

	return dir

func direction_to_vector(dir: String) -> Vector2:
	match dir:
		"Up": return Vector2.UP
		"Down": return Vector2.DOWN
		"Left": return Vector2.LEFT
		"Right": return Vector2.RIGHT
		"Up_Left": return Vector2(-1, -1).normalized()
		"Up_Right": return Vector2(1, -1).normalized()
		"Down_Left": return Vector2(-1, 1).normalized()
		"Down_Right": return Vector2(1, 1).normalized()
	return Vector2.ZERO

func get_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := snap_radius
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		# враг доигрывает fade ещё death_fade_time секунд после смерти, всё
		# ещё числясь в группе — без этой проверки таргет/снап цепляется за
		# труп вместо переключения на живого врага
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

func try_snap_to_enemy() -> void:
	var enemy = get_nearest_enemy()
	if enemy == null:
		return
	
	var dir = (enemy.global_position - global_position).normalized()
	var new_dir = get_direction(dir)
	
	if new_dir == "":  # get_direction вернул пустую строку — не применяем
		return
	
	facing_dir = dir
	last_direction = new_dir

func check_for_turn():
	if is_attacking or is_run_attacking:  # 👈 добавь эту строку
		return
	# нельзя разворачиваться во время додже/переката — иначе Turn-анимация
	# перекрывает Dodge/Rolling, и застревают флаги (игрок замерзает)
	if is_dodging or is_rolling:
		return
	if input_vector == Vector2.ZERO:
		return
	if turn_lock:
		return
	if velocity.length() < run_speed * 0.6:
		return

	var input_dir = input_vector.normalized()

	# если почти противоположное направление
	if input_dir.dot(facing_dir) < -0.7:
		start_turn(input_dir)

func start_turn(new_dir: Vector2):
	var old_dir = facing_dir
	var new_facing = new_dir.normalized()
	var new_last_direction = get_direction(new_facing)
	var anim_name = "Turn_" + new_last_direction

	# Если для этого направления нет анимации разворота — просто меняем направление
	# без блокирующего состояния. Иначе флаги is_turning/turn_lock залипали бы навсегда
	# (они сбрасываются только по окончании Turn_-анимации), и игрок застревал.
	if not anim.has_animation(anim_name):
		facing_dir = new_facing
		last_direction = new_last_direction
		return

	turn_lock = true
	is_turning = true

	# фиксируем новое направление заранее (как в Hades)
	facing_dir = new_facing
	last_direction = new_last_direction

	# стоп движения (важно для feel)
	turn_velocity = velocity * 0.4

	anim.play(anim_name)
	play_turn_vfx(old_dir, new_facing)

func start_roll():
	if is_rolling:
		return
	if not use_stamina(roll_stamina_cost):
		return
	roll_control = 0.0
	is_rolling = true
	set_collision_mask_value(3, false)
	is_dodging = false
	var dir := Vector2.ZERO
	if input_vector == Vector2.ZERO:
		dir = direction_to_vector(last_direction)
	else:
		dir = input_vector.normalized()
	roll_dir = dir
	last_direction = get_direction(dir)
	anim.play("Rolling_" + last_direction)
	dodge_velocity = roll_dir * roll_speed
	roll_timer = roll_duration

func play_movement_animation():
	if is_taking_damage or is_stunned:
		return
	if is_parrying or is_blocking:  # 👈 добавь эту проверку
		return
	
	var speed = velocity.length()
	var anim_name = ""

	# --- пороги скорости ---
	if speed < 10:
		anim.speed_scale = 1.0
		anim.play("Idle_" + last_direction)
		return
	elif speed < 120:
		anim.speed_scale = 1.0
		anim_name = "Walk_" + last_direction
	else:
		anim_name = "Run_" + last_direction
		# Клипы Run_* сняты на 25 fps (шаг кадра 0.04с = speed_scale 1.0) — это и
		# есть "естественный максимум", выше него не поднимаем. Растягиваем
		# видимый диапазон от 0.35 (только вбежал в зону бега) до 1.0 (полный
		# разгон) — простое speed/run_speed давало разницу всего 0.6-1.0 (40%),
		# что на глаз почти незаметно за доли секунды разгона
		var t = clamp((speed - 120.0) / (run_speed - 120.0), 0.0, 1.0)
		anim.speed_scale = lerp(0.35, 1.0, t)

	anim.play(anim_name)

func play_idle_animation():
	anim.play("Idle_" + last_direction)

func handle_dodge_input():
	if is_dodging or is_rolling:
		return
	if Input.is_action_just_pressed("ui_accept"):
		dodge_tap_count += 1
		dodge_tap_timer = dodge_tap_window

func start_dodge():
	if not use_stamina(dodge_stamina_cost):
		return
	if is_dodging or is_rolling:
		return
	is_dodging = true
	set_collision_mask_value(3, false) 
	# 🔥 ВКЛЮЧАЕМ НЕУЯЗВИМОСТЬ
	is_invulnerable = true
	start_i_frames()

	var dir = input_vector
	
	if dir == Vector2.ZERO:
		dir = direction_to_vector(last_direction)
	else:
		dir = dir.normalized()
	
	last_direction = get_direction(dir)
	
	var anim_name = "Dodge_" + last_direction
	
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		print("⚠ Нет анимации dodge:", anim_name)
		is_dodging = false
		return
	
	dodge_velocity = dir * dodge_speed

func add_coins(amount: int):
	coins += amount

func start_i_frames():
	await get_tree().create_timer(i_frame_time).timeout
	is_invulnerable = false

func interrupt_all_actions():
	is_attacking = false
	is_run_attacking = false
	# Уворот/перекат снимают стан получения урона и нокбэк — это и даёт игроку
	# вырваться, когда его зажали (иначе is_taking_damage лочит движение)
	is_taking_damage = false
	knockback_velocity = Vector2.ZERO
	is_turning = false
	turn_lock = false
	dodge_velocity = Vector2.ZERO
	
	combo_step = 0
	combo_queued = false

	attack_velocity = Vector2.ZERO
	turn_velocity = Vector2.ZERO

func handle_roll(delta):
	roll_control += delta
	
	var t: float = clamp(roll_control / roll_duration, 0.0, 1.0) as float
	var speed_multiplier := sin(t * PI)
	
	dodge_velocity = roll_dir * roll_speed * speed_multiplier
	velocity = dodge_velocity
	
	move_and_slide()

func handle_movement_vfx(delta):
	move_vfx_cooldown -= delta
	var is_moving_now = input_vector != Vector2.ZERO
	var was_moving = prev_velocity.length() > 5

	# --- 1. СТАРТ ДВИЖЕНИЯ ---
	if not was_moving and is_moving_now and is_running and move_vfx_cooldown <= 0:
		play_move_start_vfx()
		move_vfx_cooldown = 0.2
	# --- 2. НАЧАЛ БЕЖАТЬ (walk → run) ---
	if is_moving_now and is_running and not was_running and move_vfx_cooldown <= 0:
		play_move_start_vfx()
		move_vfx_cooldown = 0.2
	# обновляем состояние
	was_running = is_running

func handle_footsteps(delta: float) -> void:
	if velocity.length() < 10.0:
		_footstep_distance = 0.0
		return
	_footstep_distance += velocity.length() * delta
	if _footstep_distance >= footstep_step_distance:
		_footstep_distance = 0.0
		footstep_audio.stream = FOOTSTEP_LEFT if _footstep_left_next else FOOTSTEP_RIGHT
		_play_varied(footstep_audio)
		_footstep_left_next = not _footstep_left_next

func play_turn_vfx(_old_dir: Vector2, _new_dir: Vector2):
	if turn_around_vfx_scene == null:
		return
	
	var vfx = turn_around_vfx_scene.instantiate()
	var dir = velocity.normalized()
	if dir == Vector2.ZERO:
		dir = direction_to_vector(last_direction) 
	# чуть позади игрока
	vfx.global_position = foot_point.global_position - dir * 5

	# передаём направление (если используешь движение внутри VFX)
	vfx.set("move_direction", dir)

	# поворот под направление
	vfx.rotation = dir.angle()

	get_tree().current_scene.add_child(vfx)

func play_move_start_vfx():
	if move_start_vfx_scene == null:
		return
	
	var vfx = move_start_vfx_scene.instantiate()
	var dir = velocity.normalized()
	if dir == Vector2.ZERO:
		dir = direction_to_vector(last_direction) 
	# чуть позади игрока
	vfx.global_position = foot_point.global_position - dir * 5

	# передаём направление (если используешь движение внутри VFX)
	vfx.set("move_direction", dir)

	# поворот под направление
	vfx.rotation = dir.angle()

	get_tree().current_scene.add_child(vfx)

# ----------------------------------------------------------
# АТАКИ / COMBO / RUN ATTACK / DASH
# ----------------------------------------------------------

func handle_parry_input(delta):
	if is_dodging or is_rolling or is_attacking:
		is_blocking = false
		return
	# Кулдаун считаем ОТДЕЛЬНО от остального — раньше ранний return на все
	# 0.6с кулдауна глушил весь остаток функции, включая отсчёт parry_timer
	# ниже. Из-за этого переход в блок (когда parry_timer истекает, см. ниже)
	# физически не мог сработать раньше, чем закончится кулдаун — поза блока
	# появлялась с задержкой ~0.6-0.7с после нажатия вместо почти мгновенной.
	# Кулдаун должен запрещать только НОВУЮ попытку идеального парирования,
	# а не тормозить уже идущий переход в блок
	if parry_cd_timer > 0:
		parry_cd_timer -= delta
	# just_pressed ПЕРВЫМ — иначе pressed перехватывает. Новую попытку
	# парирования можно начать только вне кулдауна
	if parry_cd_timer <= 0 and Input.is_action_just_pressed("parry"):
		is_blocking = false
		start_parry()
	elif Input.is_action_pressed("parry"):
		if not is_blocking and not is_parrying:
			is_blocking = true
			anim.play("Parry_" + last_direction)  # та же анимация
			anim.pause()  # останавливаем на первом кадре — стойка)
	else:
		is_blocking = false
	if is_parrying:
		parry_timer -= delta
		if parry_timer <= 0:
			# Кнопка всё ещё зажата — игрок не пытался поймать тайминг заново,
			# а просто продолжает держать щит. Штрафовать станом за промах
			# нечестно в этом случае: это осознанный переход в блок, а не
			# сорвавшееся парирование. Стан-наказание остаётся только для
			# случая, когда кнопку уже отпустили до конца окна (см. else)
			if Input.is_action_pressed("parry"):
				is_parrying = false
				is_blocking = true
				anim.play("Parry_" + last_direction)
				anim.pause()
			else:
				end_parry(false)
	if can_counter:
		counter_timer -= delta
		if counter_timer <= 0:
			can_counter = false

func start_parry():
	print("start_parry вызван, last_direction=", last_direction)
	is_parrying = true
	parry_timer = parry_window
	parry_cd_timer = parry_cooldown
	velocity = Vector2.ZERO

	var anim_name = "Parry_" + last_direction
	print("ищем анимацию: ", anim_name)
	if anim.has_animation(anim_name):
		print("анимация найдена, играем")
		anim.play(anim_name)
	else:
		print("⚠ Нет анимации: ", anim_name)

func end_parry(was_hit: bool):
	is_parrying = false
	parry_timer = 0.0
	if not was_hit:
		_parry_whiff()
	else:
		play_idle_animation()

func _parry_whiff() -> void:
	# штраф за промах — 0.5 сек нельзя атаковать и двигаться
	is_stunned = true
	velocity = Vector2.ZERO
	# анимация промаха — используем существующую или idle
	var anim_name = "Parry_" + last_direction
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	await get_tree().create_timer(0.5).timeout
	is_stunned = false
	play_idle_animation()

# Вызывается врагом (или hitbox-ом) когда его атака задела игрока
func receive_attack(attack_data: Dictionary) -> bool:
	# Уворот/перекат — не просто неуязвимость, а НАГРАДА за тайминг: раньше
	# атака молча "проваливалась" здесь без всякой обратной связи, будто
	# игрок и не был под угрозой. Проверяем ДО общей is_invulnerable — та же
	# неуязвимость стоит и в грейс-период после урона, и от баффов (Кровь
	# Фенрира), а награждать имеет смысл именно активное уклонение
	if is_dodging or is_rolling:
		_on_perfect_dodge(attack_data)
		return false

	# Неуязвимость из других источников (грейс-период после урона, баффы) —
	# молча гасим, здесь награждать нечего, это не игровой навык
	if is_invulnerable:
		return false

	# --- PERFECT PARRY ---
	if is_parrying:
		end_parry(true)
		on_perfect_parry(attack_data)
		return true

	# --- БЛОК ---
	# Щит закрывает только фронт. Бьют сзади/сбоку за пределами конуса —
	# урон проходит насквозь, как будто блока и не было: держать щит имеет
	# смысл, только если реально смотришь на противника, а не бегать в блоке
	# спиной к бою и ничего не бояться
	if is_blocking and _is_facing_attacker(attack_data.get("source", null)):
		_on_blocked_attack(attack_data)
		return true

	# --- ОБЫЧНЫЙ УРОН ---
	take_damage(attack_data.get("damage", 10), attack_data.get("source", null))
	return true


func _is_facing_attacker(attacker: Node) -> bool:
	if attacker == null or not is_instance_valid(attacker) or not (attacker is Node2D):
		return true  # источник неизвестен — не наказываем игрока недоверием
	var to_attacker: Vector2 = (attacker as Node2D).global_position - global_position
	if to_attacker.length() < 0.001:
		return true
	return facing_dir.dot(to_attacker.normalized()) > block_frontal_dot_threshold


# Удар остановлен щитом: урон не проходит, но держать блок не бесплатно —
# концентрация заполняется так же, как от обычного попадания (см. take_damage),
# и при полной шкале срабатывает тот же _posture_break()
func _on_blocked_attack(_attack_data: Dictionary) -> void:
	current_posture += block_posture_gain
	current_posture = min(current_posture, max_posture)
	health_bar.set_posture(current_posture)
	posture_regen_timer = posture_regen_delay

	play_block_hit_sound()
	shake_camera(block_shake_strength)
	# Холодная бело-голубая искра щита — отличается и от белой вспышки урона,
	# и от тёплых тонов лечения/монет: блок должен читаться как "звон металла",
	# а не как что-то из этих двух категорий
	flash_tint(Color(1.3, 1.4, 1.7, 1.0), 0.04, 0.18)

	if current_posture >= max_posture:
		_posture_break()

func play_parry_vfx() -> void:
	# На самом игроке, а не на MeleeHit — тот маркер смещается вперёд по
	# направлению атаки (для обычных ударов) и не всегда подходит под анимацию парирования
	parry_vfx.global_position = global_position
	parry_vfx.play("parry_vfx")
	await parry_vfx.animation_finished
	parry_vfx.stop()

# Идеальный уворот — атака врага реально задела бы игрока (сработал
# receive_attack), но в этот момент шёл уворот/перекат. В отличие от
# парирования это не столкновение с ударом, а чистая уклончивость — поэтому
# урон по концентрации врага не наносится (нечем клэшить), награда чисто в
# темпе: короткое "witch time" слоу-мо + то же окно на свободную контратаку,
# что даёт perfect parry
func _on_perfect_dodge(_attack_data: Dictionary) -> void:
	can_counter = true
	counter_timer = counter_window
	_perfect_dodge_slowmo()
	shake_camera(perfect_dodge_shake_strength)
	# Холодная бело-голубая вспышка вместо белой (урон) или золотой (монеты/
	# лечение) — свой узнаваемый цвет момента, чтобы уворот не путался с
	# другими вспышками на глаз
	flash_tint(Color(1.15, 1.25, 1.5), 0.05, 0.25)
	parry_audio.stream = PERFECT_DODGE_SOUND
	_play_varied(parry_audio, 0.05, 0.0, 1.1)


func on_perfect_parry(attack_data: Dictionary):
	can_counter = true
	counter_timer = counter_window
	play_parry_vfx()
	parry_audio.stream = PARRY_SOUND
	# парирование — особый момент, разброс меньше, чтобы звук оставался
	# узнаваемым и "чистым", а не плавал как рядовые удары. Питч приподнят
	# сверху (parry_pitch_mult) — так лязг звучит звонче, а не глухо
	_play_varied(parry_audio, 0.05, 0.0, parry_pitch_mult)
	# короткая тряска — удар металла о металл должен ощущаться физически,
	# но парирование не урон, поэтому заметно слабее damage_shake_strength
	shake_camera(parry_shake_strength)
	# урон по концентрации врага
	var source = attack_data.get("source", null)
	if source and source.has_method("take_posture_damage"):
		source.take_posture_damage(35.0)

func take_damage(amount: int, source: Node = null) -> void:
	# Снижение урона (Благословение Бальдра и т.п.)
	amount = int(amount * get_damage_reduction_factor())
	health_bar.take_damage(float(amount))
	health = health_bar.current_hp

	# Благословение Бальдра — одноразовое воскрешение вместо гибели
	if health <= 0.0 and baldur_revive_ready:
		_baldur_revive()
		return

	# нокбэк от источника урона — игрок отлетает от врага
	var attacker = source if source else get_nearest_enemy()
	if attacker and is_instance_valid(attacker):
		var knockback_dir = (global_position - attacker.global_position).normalized()
		knockback_velocity = knockback_dir * knockback_force
	
	is_taking_damage = true
	gfx.play("Take_Damage_" + last_direction)
	_trigger_damage_flash()
	_play_pool(hurt_audio, HURT_SOUNDS, "hurt")
	damage_vignette.flash()
	hit_flash.flash()
	shake_camera(damage_shake_strength)
	
	current_posture += 10.0
	current_posture = min(current_posture, max_posture)
	posture_regen_timer = posture_regen_delay
	health_bar.set_posture(current_posture)

	await gfx.animation_finished
	is_taking_damage = false

	if current_posture >= max_posture:
		_posture_break()

func heal(amount: float) -> void:
	health_bar.heal(amount)
	health = health_bar.current_hp

func use_stamina(amount: float) -> bool:
	return health_bar.use_stamina(amount)

func _posture_break() -> void:
	current_posture = max_posture
	health_bar.set_posture(current_posture)
	# игрок открыт — можно добавить анимацию оглушения
	print("[Player] Концентрация сломана!")
	await get_tree().create_timer(2.0).timeout
	current_posture = 0.0
	health_bar.set_posture(0.0)

func handle_attack_input():
	if is_dodging or is_rolling:
		return
	if Input.is_action_just_pressed("attack"):
		if can_counter:
			can_counter = false
			start_counter_attack()
			return
		if is_running and input_vector != Vector2.ZERO and not is_attacking and not is_run_attacking:
			start_run_attack()
			return
		# ← добавь это
		if input_vector != Vector2.ZERO:
			facing_dir = input_vector.normalized()
			last_direction = get_direction(facing_dir)
		if is_attacking:
			combo_queued = true
		elif not is_run_attacking:
			try_snap_to_enemy()
			start_combo()

func start_combo():
	combo_step = 1
	play_attack(combo_step)

func play_attack(step: int):
	is_attacking = true
	use_stamina(attack_stamina_cost)
	combo_timer = combo_window
	combo_queued = false
	dodge_velocity = Vector2.ZERO
	try_snap_to_enemy() 
	var anim_name := ""

	if step == 1:
		anim_name = "Attack_" + last_direction
	elif step == 2:
		anim_name = "Attack_2_" + last_direction
	elif step == 3:
		anim_name = "Attack_3_" + last_direction
	elif step == 4:
		anim_name = "Attack_4_" + last_direction
	
	update_weapon_tip()
	melee_weapon_tip()
	player_hitbox.monitoring = true
	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return

	anim.play(anim_name)

	# Звук замаха (whoosh) — на каждом ударе серии
	_play_pool(swing_audio, SWING_SOUNDS, "swing")

	# Боевой вскрик — свой на каждый из первых трёх ударов, 4-й (вихрь) — без вскрика
	match step:
		1: _play_pool(voice_audio, GRUNT_1_SOUNDS, "grunt1")
		2: _play_pool(voice_audio, GRUNT_2_SOUNDS, "grunt2")
		3: _play_pool(voice_audio, GRUNT_3_SOUNDS, "grunt3")

	# --- микро-рывок вперёд после удара ---
	attack_velocity = direction_to_vector(last_direction) * 125  # сила рывка подбирается

func start_counter_attack():
	is_attacking = true
	combo_step = 0
	var anim_name = "Attack_" + last_direction
	anim.play(anim_name)
	attack_velocity = direction_to_vector(last_direction) * 200

func handle_kick_input():
	if is_dodging or is_rolling or is_attacking:
		return
	
	if Input.is_action_just_pressed("kick"):
		start_kick()

func start_kick():
	is_attacking = true
	dodge_velocity = Vector2.ZERO
	attack_velocity = Vector2.ZERO
	
	var anim_name = "Kick_" + last_direction
	
	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return
	
	anim.play(anim_name)
	attack_velocity = direction_to_vector(last_direction) * 100

func start_run_attack():
	is_run_attacking = true
	is_attacking = true

	var anim_name = "Run_Attack_" + last_direction

	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return
	update_weapon_tip()
	melee_weapon_tip()  # позиционируем player_hitbox перед игроком, иначе удар на бегу не попадает
	anim.play(anim_name)
	_play_pool(swing_audio, RUN_SWING_SOUNDS, "run_swing")
	_play_pool(voice_audio, GRUNT_RUN_SOUNDS, "grunt_run")
	# задаём скорость для скольжения
	attack_velocity = input_vector.normalized() * 250

func update_weapon_tip():
	var dir = direction_to_vector(last_direction)
	var offset = 35  # подгони под свою анимацию
	weapon_tip.position = dir * offset

func melee_weapon_tip():
	var dir = direction_to_vector(last_direction)
	melee_hit.position = dir * 35     # VFX спавнится здесь — дальше
	player_hitbox.position = dir * 25

func play_hit_vfx():
	var scene_to_use: PackedScene = active_hit_vfx_override if active_hit_vfx_override != null else hit_vfx_scene
	if scene_to_use == null:
		return
	var vfx = scene_to_use.instantiate()
	vfx.global_position = weapon_tip.global_position
	var dir = direction_to_vector(last_direction)
	vfx.set("move_direction", dir)
	vfx.rotation = dir.angle()
	if active_hit_vfx_override != null:
		match active_ability_name:
			"fenrir":  vfx.set("anim_name", "fenrir_hit_3")
			"berserk": vfx.set("anim_name", "berserk_hit_3")
	get_tree().current_scene.add_child(vfx)

func play_melee_hit_vfx():
	var scene_to_use: PackedScene = active_hit_vfx_override if active_hit_vfx_override != null else melee_hit_vfx_scene
	if scene_to_use == null:
		return
	var vfx = scene_to_use.instantiate()
	vfx.global_position = melee_hit.global_position
	var dir = direction_to_vector(last_direction)
	vfx.set("move_direction", dir)
	vfx.rotation = dir.angle()
	if active_hit_vfx_override != null:
		match active_ability_name:
			"fenrir":  vfx.set("anim_name", "fenrir_hit")
			"berserk": vfx.set("anim_name", "berserk_hit_1")
	get_tree().current_scene.add_child(vfx)

func play_melee_2_hit_vfx():
	var scene_to_use: PackedScene = active_hit_vfx_override if active_hit_vfx_override != null else melee_hit_2_vfx_scene
	if scene_to_use == null:
		return
	var vfx = scene_to_use.instantiate()
	vfx.global_position = melee_hit.global_position
	var dir = direction_to_vector(last_direction)
	vfx.set("move_direction", dir)
	vfx.rotation = dir.angle()
	if active_hit_vfx_override != null:
		match active_ability_name:
			"fenrir":  vfx.set("anim_name", "fenrir_hit_2")
			"berserk": vfx.set("anim_name", "berserk_hit_2")
	get_tree().current_scene.add_child(vfx)

func play_fire_ring_vfx():
	# Вихревой финишер 4-го удара: урон и отброс по всем врагам вокруг
	_spin_finisher()

	if active_ability_name != "fenrir":  # ← кольцо только для Фенрира
		return

	if active_hit_vfx_override == null:
		return  # кольцо только при активной способности

	if fire_ring_vfx_scene == null:
		print("⚠ VFX огненного кольца не назначен")
		return

	var vfx = fire_ring_vfx_scene.instantiate()
	vfx.global_position = global_position  # на месте игрока
	get_tree().current_scene.add_child(vfx)

func _spin_finisher() -> void:
	var dmg: int = maxi(1, int(round(attack_damage * spin_damage_mult * get_damage_multiplier())))
	var hit_any := false
	for e: Node2D in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) > spin_radius:
			continue
		hit_any = true
		# сбрасываем защиту/контратаку врага, чтобы вихрь прерывал его в HIT_STUN,
		# а не давал провести контратаку во время отлёта
		e.is_parrying = false
		e.is_blocking = false
		e.is_countering = false
		if e.has_method("take_damage"):
			e.take_damage(dmg, self)
		# усиленный отброс от игрока
		var dir: Vector2 = (e.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		if "knockback_velocity" in e:
			e.knockback_velocity = dir * spin_knockback

	# отдача вихря — один раз на весь замах, а не на каждого задетого врага,
	# иначе в толпе стоп-кадр и тряска складывались бы в кашу
	if hit_any:
		shake_camera(hit_shake_strength * spin_impact_mult)
		do_hitstop(spin_impact_mult)
		# combo_step == 4, поэтому слой оружия внутри промолчит и сыграет только
		# низкий слой тела — самый тяжёлый звук в серии, ровно на добивании
		_play_hit_sound(spin_impact_mult)

func play_running_hit_vfx():
	if running_hit_vfx_scene == null:
		print("⚠ Running VFX не назначен")
		return
		
	var vfx_running = running_hit_vfx_scene.instantiate()
	vfx_running.global_position = weapon_tip.global_position
	
	var dir_running = direction_to_vector(last_direction)

	# передаём направление
	vfx_running.set("move_direction", dir_running)
	vfx_running.rotation = dir_running.angle()  # 👈 ВОТ ЭТО НОВОЕ
	
	get_tree().current_scene.add_child(vfx_running)

# ----------------------------------------------------------
# ЗАВЕРШЕНИЕ
# ----------------------------------------------------------

func _on_anim_finished(finished_anim: StringName) -> void:
	print(">>> ЗАКОНЧИЛАСЬ: ", finished_anim)
	if finished_anim.begins_with("Started_"):
		is_starting = false
		play_idle_animation()
		return
	# --- DODGE SYSTEM ---
	if finished_anim.begins_with("Dodge_"):
		is_dodging = false
		set_collision_mask_value(3, true) 
		dodge_velocity = Vector2.ZERO
		velocity = velocity.lerp(input_vector * walk_speed, 0.2)
		return
	if finished_anim.begins_with("Rolling_"):
		is_rolling = false
		set_collision_mask_value(3, true) 
		dodge_velocity = Vector2.ZERO
		roll_control = 0.0
		velocity = Vector2.ZERO
		return
	# --- TURN SYSTEM ---
	if finished_anim.begins_with("Turn_"):
		is_turning = false
		turn_lock = false
		return
	# --- RUN ATTACK ---
	if finished_anim.begins_with("Run_Attack"):
		reset_all_states()
		return
	if finished_anim.begins_with("Kick_"):
		reset_all_states()
		return
	if finished_anim.begins_with("Parry_"):
		is_parrying = false
		play_idle_animation()
		return
	# --- COMBO ---
	if not finished_anim.begins_with("Attack"):
		return
	
	player_hitbox.monitoring = true
	
	# Урезано до 3 шагов серии — 4-й удар (вихрь/spin finisher) временно
	# вынут из обычной цепочки, станет отдельным навыком. Код 4-го удара не
	# удалён (play_attack умеет step==4, _spin_finisher/play_fire_ring_vfx на
	# месте) — серия просто больше до него не доходит. Когда навык будет
	# готов и получит свой отдельный вызов play_attack(4), эту цифру можно
	# вернуть обратно на 4, если 4-й удар снова понадобится и в обычной серии
	if combo_queued and combo_step < 3:
		combo_step += 1
		play_attack(combo_step)
	else:
		reset_combo()

func reset_combo():
	is_attacking = false
	combo_step = 0
	combo_queued = false
	player_hitbox.monitoring = false  # ← добавь
	play_idle_animation()

func reset_all_states():
	is_attacking = false
	is_run_attacking = false
	is_turning = false
	turn_lock = false
	combo_step = 0
	combo_queued = false
	play_idle_animation()

func dash(force: float, _duration: float) -> void:
	# Использует твою существующую систему dodge_velocity
	# Не конфликтует — это отдельный импульс поверх движения
	if is_dodging or is_rolling or is_attacking:
		return
	var dir := facing_dir if facing_dir != Vector2.ZERO else direction_to_vector(last_direction)
	dodge_velocity = dir * force
	# Гаситься будет через твой существующий dodge_friction в _physics_process

func _load_starting_abilities() -> void:
	ability_system.add_ability(HoneyMeadAbility.new())
	ability_system.add_ability(ValhallaElixirAbility.new())
	var honey := HoneyMeadAbility.new()
	inventory_ui.add_item(honey)

	var elixir := ValhallaElixirAbility.new()
	inventory_ui.add_item(elixir)

	var fenrir := FenrirBloodAbility.new()
	inventory_ui.add_item(fenrir)

# --- ПОСТЕПЕННОЕ ЛЕЧЕНИЕ (для Мёда Поэзии и Песни Валькирии) ---

func start_heal_over_time(amount_per_tick: float, interval: float, ticks: int,
		tint := Color(0.6, 1.5, 0.8, 1.0)) -> void:
	# Пауза между тиками РОВНАЯ (interval), а не interval * i. Раньше каждая
	# итерация ждала всё дольше предыдущей (0, 0.5, 1.0, 1.5...), и "лечение
	# за 3 секунды" на деле растягивалось на 7.5 с нарастающими паузами
	for i in ticks:
		if not is_instance_valid(self):
			return
		heal(amount_per_tick)
		flash_tint(tint)
		await get_tree().create_timer(interval).timeout

# --- СИСТЕМА БАФФОВ (заглушка — подключишь когда нужно) ---

func apply_buff(buff: Dictionary) -> void:
	var buff_name = buff.get("name", "unknown")
	active_buffs[buff_name] = buff

	# Скорость
	if buff.has("speed_bonus"):
		walk_speed += buff["speed_bonus"]
		run_speed += buff["speed_bonus"]

	# Убираем бафф через duration
	var duration = buff.get("duration", 5.0)
	await get_tree().create_timer(duration).timeout
	remove_buff(buff_name, buff)

func remove_buff(buff_name: String, buff: Dictionary) -> void:
	if not active_buffs.has(buff_name):
		return
	active_buffs.erase(buff_name)

	# Откатываем скорость
	if buff.has("speed_bonus"):
		walk_speed -= buff["speed_bonus"]
		run_speed -= buff["speed_bonus"]

	print("[Бафф] ", buff_name, " закончился")

# --- СНЯТИЕ НЕГАТИВНЫХ ЭФФЕКТОВ (заглушка) ---

func clear_negative_effects() -> void:
	# TODO: когда появятся статусы — чистить их здесь
	# remove_status("poison")
	# remove_status("bleed")
	print("[Player] Негативные эффекты сняты")

# --- ГЛАЗ ОДИНА (заглушка) ---

func activate_odin_eye(duration: float, slow: float, max_targets: int) -> void:
	Engine.time_scale = slow
	print("[ГлазОдина] Время замедлено, выбери до ", max_targets, " целей")
	get_tree().create_timer(duration, true, false, true).timeout.connect(
		func():
			Engine.time_scale = 1.0
			print("[ГлазОдина] Время восстановлено")
	)
	# TODO: логика выбора и убийства врагов

func add_gold(amount: int) -> void:
	gold += amount
	if hud:
		hud.update_gold(gold)
	_trigger_coin_glow()
	coin_audio.stream = COIN_SOUND
	_play_varied(coin_audio, 0.08)

# ============== HITBOX ==============

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_invulnerable or is_dodging or is_rolling:
		return
	if area.is_in_group("enemy_attack"):
		var dmg = 50
		if area.has_meta("damage"):
			dmg = int(area.get_meta("damage"))
		take_damage(dmg)

func _trigger_damage_flash() -> void:
	var tween = create_tween()
	tween.tween_property(gfx, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
	tween.tween_property(gfx, "modulate", Color.WHITE, 0.15)

# Короткая тёплая золотая вспышка — визуальное подтверждение, что монета
# долетела и засчиталась (тот же приём, что и _trigger_damage_flash, только
# тёплый цвет вместо белого). Висит на modulate, а не self_modulate — тот
# уже занят под тинт неуязвимости (_update_immunity_visual)
func _trigger_coin_glow() -> void:
	flash_tint(coin_glow_color, coin_glow_in_time, coin_glow_out_time)


# Короткая цветная вспышка на спрайте игрока. Общая точка для всех подсветок
# (подбор монеты, тик лечения, мгновенный хил) — цвет и тайминги задаёт
# вызывающий, поэтому событиям не нужен свой почти одинаковый метод
func flash_tint(tint: Color, in_time := 0.08, out_time := 0.22) -> void:
	var tween = create_tween()
	tween.tween_property(gfx, "modulate", tint, in_time)
	tween.tween_property(gfx, "modulate", Color.WHITE, out_time)


# Проигрывает звук питья и ЖДЁТ, пока он доиграет до конца. Аптечки вызывают
# через await, поэтому лечение начинается только после того, как игрок реально
# "допил" — сначала действие, потом эффект.
# Ждём именно сигнал finished, а не таймер на глазок: питч слегка случайный
# (_play_varied), значит фактическая длительность каждый раз чуть разная, и
# захардкоженная пауза рассинхронизировалась бы со звуком
func play_drink_sound() -> void:
	drink_audio.stream = DRINK_SOUND
	_play_varied(drink_audio, 0.04)
	await drink_audio.finished

func is_dead() -> bool:
	return health <= 0.0

func _on_player_dead() -> void:
	# TODO: анимация смерти, game over
	print("[Player] Умер")

# ============== ENABLE/DISABLE HITBOX ==============

func enable_attack_hitbox() -> void:
	hit_targets.clear()  # ← сброс перед каждым ударом
	# set_deferred, а не прямое присваивание — эти вызовы прилетают из
	# method-track анимации, который может сработать прямо во время
	# обработки физических запросов (Godot тогда пишет в консоль "Can't
	# change this state while flushing queries"). Отложенный вызов дожидается
	# конца текущего физического шага, прежде чем менять monitoring/disabled
	player_hitbox.set_deferred("monitoring", true)
	player_hitbox.get_child(0).set_deferred("disabled", false)

func disable_attack_hitbox() -> void:
	player_hitbox.set_deferred("monitoring", false)
	if player_hitbox.get_child(0):
		player_hitbox.get_child(0).set_deferred("disabled", true)

func _on_player_hitbox_area_entered(area: Area2D) -> void:
	# Оглушённый игрок не наносит урон. Это ГЛАВНАЯ страховка: хитбокс мог
	# остаться включённым, если стан прервал атаку на полпути — анимация
	# оборвалась, и её method-track с disable_attack_hitbox() уже не сработает.
	# Проверять состояние здесь надёжнее, чем гасить хитбокс в каждой точке,
	# откуда игрока можно застанить
	if is_stunned:
		return
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy in hit_targets:
			return
		hit_targets.append(enemy)
		if enemy.has_method("receive_attack"):
			var attack_data = {
				"damage": int(attack_damage * get_damage_multiplier()),
				"source": self
			}
			enemy.receive_attack(attack_data)
		# удар на бегу весомее обычного удара серии
		var power := run_attack_impact_mult if is_run_attacking else 1.0
		_play_hit_sound(power)
		shake_camera(hit_shake_strength * power)
		do_hitstop(power)

func do_hitstop(power := 1.0) -> void:
	# power — множитель "веса" удара: чем мощнее, тем дольше стоп-кадр.
	_apply_timescale(hitstop_scale, hitstop_duration * power)


# Слоу-мо идеального уворота — та же механика, что и хитстоп (см.
# _apply_timescale), но мягче и заметно дольше: не стоп-кадр удара, а
# растянутое "я успел увернуться" перед контратакой
func _perfect_dodge_slowmo() -> void:
	_apply_timescale(perfect_dodge_slowmo_scale, perfect_dodge_slowmo_duration)


# Общая точка входа для любого временного управления Engine.time_scale от
# игрока. Замораживаем/замедляем время на реальную (не игровую) длительность
# — таймер с ignore_time_scale=true идёт в реальном времени, поэтому
# разморозка сработает вовремя даже при scale=0. Токен общий для ВСЕХ
# вызовов (хитстоп и слоу-мо), поэтому при наложении (уворот → мгновенная
# контратака → хитстоп от попадания) время корректно восстановит только
# самый последний по времени вызов, а не тот, что запустился раньше
func _apply_timescale(scale: float, duration: float) -> void:
	_timescale_token += 1
	var token := _timescale_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _timescale_token:
		Engine.time_scale = 1.0


# Проигрывает звук со случайным разбросом высоты тона. Без этого каждый удар,
# вскрик и шаг звучат абсолютно идентично, и ухо быстро считывает повтор одного
# и того же семпла — бой начинает ощущаться "механическим"
func _play_varied(player: AudioStreamPlayer2D, variation := -1.0, volume_offset_db := 0.0, pitch_mult := 1.0) -> void:
	var v: float = pitch_variation if variation < 0.0 else variation
	player.pitch_scale = randf_range(1.0 - v, 1.0 + v) * pitch_mult
	# Живой человек не бьёт дважды с одинаковой силой — небольшой разброс
	# громкости делает серию ударов "неровной" так же, как питч делает её
	# неодинаковой по тону. Отсчитываем от БАЗОВОЙ громкости из сцены, иначе
	# volume_db дрейфовал бы всё дальше с каждым выстрелом
	if _base_volume_db.has(player):
		var base: float = _base_volume_db[player]
		player.volume_db = base + randf_range(-volume_variation_db, volume_variation_db) + volume_offset_db
	player.play()


# Берёт случайный семпл из пула, никогда не повторяя предыдущий подряд.
# Чистый randf() на пуле из 2-3 файлов регулярно выдаёт один и тот же дважды,
# и ухо ловит именно эти повторы — а не общую случайность
func _pick_from_pool(pool: Array[AudioStream], key: String) -> AudioStream:
	if pool.is_empty():
		return null
	if pool.size() == 1:
		return pool[0]
	var last: int = _last_sample_idx.get(key, -1)
	var idx := randi() % pool.size()
	if idx == last:
		idx = (idx + 1 + randi() % (pool.size() - 1)) % pool.size()
	_last_sample_idx[key] = idx
	return pool[idx]


# Единая точка "сыграть звук действия": выбор семпла из пула + питч + громкость
func _play_pool(player: AudioStreamPlayer2D, pool: Array[AudioStream], key: String, variation := -1.0, volume_offset_db := 0.0, pitch_mult := 1.0) -> void:
	var snd := _pick_from_pool(pool, key)
	if snd == null:
		return
	player.stream = snd
	_play_varied(player, variation, volume_offset_db, pitch_mult)


func _play_hit_sound(power := 1.0) -> void:
	# power приходит тот же самый, что уже управляет тряской камеры и хитстопом
	# (1.0 = обычный удар серии ... spin_impact_mult = вихрь), поэтому звук,
	# картинка и время реагируют на силу удара согласованно
	var t: float = clamp((power - 1.0) / (spin_impact_mult - 1.0), 0.0, 1.0)
	var vol_offset: float = lerpf(0.0, impact_power_volume_db, t)
	var pitch_mult: float = lerpf(1.0, 1.0 - impact_power_pitch_drop, t)

	# Слой оружия — лязг, свой семпл под конкретный удар серии
	if is_run_attacking:
		_play_pool(hit_audio, RUN_HIT_SOUNDS, "run_hit", -1.0, vol_offset, pitch_mult)
	elif combo_step == 1:
		_play_pool(hit_audio, HIT_1_SOUNDS, "hit1", -1.0, vol_offset, pitch_mult)
	elif combo_step == 2 or combo_step == 3:
		_play_pool(hit_audio, HIT_REST_SOUNDS, "hit_rest", -1.0, vol_offset, pitch_mult)

	# Слой тела — глухой низкий удар, играется ПОД любым попаданием, включая
	# вихрь (у него нет своего лязга, но вес чувствоваться должен)
	_play_pool(
		body_impact_audio, BODY_IMPACT_SOUNDS, "body",
		-1.0, vol_offset, body_layer_pitch * pitch_mult
	)

	_duck_music(power)


# Короткая просадка музыки под сильный удар — освобождает место удару в миксе.
# Менеджер музыки живёт в сцене уровня, поэтому находим его через группу
# (тот же приём, которым магазин приглушает дождь)
func _duck_music(power: float) -> void:
	if power < duck_power_threshold:
		return
	var music_mgr := get_tree().get_first_node_in_group("level_music")
	if music_mgr and music_mgr.has_method("duck_music"):
		music_mgr.duck_music(power, spin_impact_mult)

func play_block_hit_sound() -> void:
	block_audio.stream = BLOCK_HIT_SOUND
	_play_varied(block_audio)

func get_damage_multiplier() -> float:
	var mult := 1.0
	for buff in active_buffs.values():
		if buff.has("damage_multiplier"):
			mult *= buff["damage_multiplier"]
	return mult

func get_damage_reduction_factor() -> float:
	# итоговый множитель входящего урона (1.0 = без снижения)
	var factor := 1.0
	for buff in active_buffs.values():
		if buff.has("damage_reduction"):
			factor *= (1.0 - buff["damage_reduction"])
	return factor

func _baldur_revive() -> void:
	baldur_revive_ready = false
	is_taking_damage = false
	is_stunned = false
	health_bar.heal(health_bar.max_hp * 0.45)
	health = health_bar.current_hp
	_trigger_damage_flash()
	# короткая неуязвимость после воскрешения
	is_invulnerable = true
	get_tree().create_timer(1.5).timeout.connect(func(): is_invulnerable = false)
	print("[БлагословениеБальдра] Воскрешение! HP восстановлено")

func receive_parry(posture_damage: float) -> void:
	# Неуязвимость (дэш/Кровь Фенрира) снимает и урон, и стан от контратак
	if is_invulnerable:
		return
	current_posture += posture_damage
	current_posture = min(current_posture, max_posture)
	health_bar.set_posture(current_posture)
	posture_regen_timer = posture_regen_delay
	
	reset_combo()
	# Стан обрывает атаку на полпути: анимация удара не доигрывает, поэтому её
	# method-track с disable_attack_hitbox() не вызовется, а reset_combo()
	# гасит только monitoring, оставляя саму коллизию включённой. Гасим руками
	# и то и другое
	disable_attack_hitbox()
	# reset_combo() не знает про беговой удар — без этого флаг залипает
	# (анимацию Run_Attack прервали, её reset_all_states() уже не сработает)
	is_run_attacking = false
	attack_velocity = Vector2.ZERO

	is_invulnerable = true
	is_stunned = true
	_trigger_damage_flash()

	anim.play("Stunned_" + last_direction)

	stun_audio.stream = STUN_SOUND
	var stun_stream := stun_audio.stream as AudioStreamMP3

	# Тряска всегда через постоянную дрожь (_start_stun_shake), а не разовый
	# затухающий импульс — раньше короткий стан тряс один раз и гас сам по
	# себе быстрее, чем доигрывала анимация. Теперь длительность тряски
	# ЖЁСТКО привязана к тому, сколько реально идёт анимация/таймер
	_start_stun_shake()

	if current_posture >= max_posture:
		# Концентрация полная — долгий стан. Тряска и звук держатся весь
		# фиксированный таймер — игрок должен физически чувствовать, что
		# застрял в стане, а не что его один раз тряхнуло
		is_invulnerable = false  # ← игрок открыт для урона
		if stun_stream:
			stun_stream.loop = true
		_play_varied(stun_audio, 0.06)
		await get_tree().create_timer(full_stun_duration).timeout
		_stop_stun_shake()
		stun_audio.stop()
		is_stunned = false
		_posture_break()
	else:
		# pummel — короткий стан, тряска держится РОВНО пока играет анимация
		# Stunned_, а не гаснет раньше неё
		if stun_stream:
			stun_stream.loop = false
		_play_varied(stun_audio, 0.06)
		is_invulnerable = false  # ← тоже открыт
		await anim.animation_finished
		_stop_stun_shake()
		is_stunned = false
