extends CharacterBody2D

@export var walk_speed := 100.0
@export var run_speed := 200.0
@export var hit_vfx_scene: PackedScene
@export var running_hit_vfx_scene: PackedScene
@export var move_start_vfx_scene: PackedScene
@export var melee_hit_vfx_scene: PackedScene
@export var melee_hit_2_vfx_scene: PackedScene
const SkidDust := preload("res://VFX/VFX_scene/skid_dust.gd")
const DirectionUtil := preload("res://Player_scene/direction_util.gd")
const FocusSystemScript := preload("res://Player_scene/focus_system.gd")
const DepthComponentScript := preload("res://Player_scene/depth_component.gd")
const MotionFeelScript := preload("res://Player_scene/motion_feel.gd")
const ExhaustVeinsScript := preload("res://UI/sigrid_exhaust.gd")
## Магия рыцаря: Одр и «Благословение богов» (Player_scene/magic/knight_magic.gd)
const KnightMagicScript := preload("res://Player_scene/magic/knight_magic.gd")

@export var snap_radius := 80.0  # радиус поиска врагов
@export var focus_break_range := 260.0  # дальше — фокус слетает сам
@export var focus_marker_offset := Vector2(0, -24)  # приподнять метку к центру врага, а не к его ногам
@export var posture_regen_rate := 10.0
@export var posture_regen_delay := 2.5
# --- БЛОК (зажатое ПКМ, is_blocking) ---
# Сколько концентрации заполняет один заблокированный удар — блок не убирает
# урон бесплатно, вместо этого копится усталость от держания щита
@export var block_posture_gain := 16.0
## Каждый принятый на щит удар стоит стамины. Кончилась — щит выбит: стан
## (guard_break_stun_duration), как и при полной концентрации
@export var block_stamina_cost := 14.0
@export var guard_break_stun_duration := 1.4
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
## В отличие от ability_system/inventory_system — не узел в player.tscn, а
## создаётся кодом в _ready(), как у лучницы (archer.gd::_setup_inventory):
## нового поля в .tscn не требует, а плейлист узлов там и так длинный
var talisman_system: TalismanSystem
## Магия: книга заклинаний, слоты магии, Одр, молитва (создаётся в _ready)
var magic: Node = null
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
@export var damage_shake_strength := 4.0
# Тряска при ПОПАДАНИИ своего удара по врагу — слабее, чем от урона: атака
# должна ощущаться весомо, но не путаться с "меня бьют"
@export var hit_shake_strength := 3.6
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
@export var spin_impact_mult := 2.8
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
@export var exhaust_shake_strength := 2.0
@export var exhaust_shake_update_rate := 0.09  # как часто меняется цель дрожи
@export var exhaust_shake_smoothing := 18.0    # скорость, с которой камера догоняет цель
var _exhaust_shake_target := Vector2.ZERO
var _exhaust_shake_current := Vector2.ZERO
var _exhaust_shake_timer := 0.0
# Громкость пульса и одышки убавлена (было -18 / +3 / -3): в долгой игре
# давили на уши. Те же числа — в character_base.gd у остальных героев
@export var heartbeat_volume_low_hp := -26.0
@export var heartbeat_volume_exhausted := -6.0
@export var heartbeat_fade_speed := 25.0  # дБ в секунду, плавность нарастания
const HEARTBEAT_SILENT_DB := -40.0
# Одышка (dyspnea) — играется вместе с громким сердцебиением ТОЛЬКО при
# истощении (не на низком HP, в отличие от сердцебиения)
@export var dyspnea_volume := -12.0
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
@export var body_layer_pitch := 0.85
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
const PARRY_SOUND := preload("res://Sound/melee_sound/parry.mp3")
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
# Кровь на получении урона — та же процедурная, что и у врагов
# (enemy.gd::play_blood_vfx): брызги летят от того, кто ударил
const BloodFx := preload("res://VFX/VFX_scene/blood_fx.gd")
# Дуги клинка, удар по щиту, парирование (VFX/VFX_scene/knight_fx.gd)
const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")
const FlurryFx := preload("res://VFX/VFX_scene/flurry_fx.gd")
const SoundBank := preload("res://Levels/sound_bank.gd")

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
# Тот же толчок, но слабее — щит гасит урон, но не всю инерцию удара
@export var block_knockback_force := 70.0
var knockback_velocity := Vector2.ZERO

# Хитстоп — короткая заморозка в момент попадания (даёт «мясистость» удара)
# Удары рыцаря тяжёлые (вес лат) — стоп-кадр чуть длиннее, отдача ощутимее
@export var hitstop_duration := 0.075
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

## Доджа (короткого уворота) больше нет — остаётся только как всегда-false
## поле: по всему файлу разбросаны проверки вида "is_dodging or is_rolling"
## (неуязвимость, блокировка движения и т.д.), трогать каждую по отдельности
## рискованнее, чем просто держать это условие вечно ложным
var is_dodging := false
## Несущая скорость переката — общее имя с бывшим доджем, используется и
## dash() (см. ability dash_ability.gd), поэтому не переименовано
var dodge_velocity := Vector2.ZERO
var is_invulnerable := false
var baldur_revive_ready := false  # Благословение Бальдра: одноразовое воскрешение
var i_frame_time := 0.2
var facing_dir: Vector2 = Vector2.DOWN
var turn_lock := false

# Фокус на враге — включается/выключается вручную (см. handle_focus_input).
# Пока враг в фокусе, взгляд каждый кадр держится на нём независимо от
# ввода движения — ходьба (WASD) при этом свободная, не привязана к взгляду.
# Сама цель, метка на экране и авто-переключение после убийства живут в
# общем компоненте FocusSystem (Player_scene/focus_system.gd) — тем же
# пользуются лучник и маг. Здесь остаётся только то, что завязано на
# анимации рыцаря: взгляд, развороты и наведение удара
var _focus: Node = null

## Только чтение. Пишется через _set_focused_enemy(), как и раньше — так все
## существующие проверки вида is_instance_valid(focused_enemy) продолжают
## работать без единой правки
var focused_enemy: Node2D:
	get:
		return _focus.target if is_instance_valid(_focus) else null

var is_rolling := false
## Было 225 — дистанция переката = roll_speed * roll_duration * ~0.64
## (площадь под синусоидой скорости), поэтому вдвое короче именно через
## скорость, а не длительность: сам перекат по времени/анимации не меняется,
## меняется только то, насколько далеко за это же время уезжает игрок
## Длина переката ≈ roll_speed * roll_duration * 2/π: 150 → ~85 px (было 112.5,
## ~64 px — вдвое короче, чем у лучницы и мага; они теперь 190, ~110 px)
@export var roll_speed := 150.0
## Неуязвимость переката — первые roll_iframes_end секунд (клип ~0.83 с), а
## не весь перекат. Идеальный уворот (замедление + контратака) — только если
## удар пришёлся в первые perfect_dodge_window секунд
@export var roll_iframes_end := 0.45
@export var perfect_dodge_window := 0.2

## ── Отзывчивость (жалоба тестеров: «деревянное» управление) ──
## С какого места переката (с) удар/перекат/пинок его обрывают — сразу после
## конца неуязвимости, а не на последнем кадре клипа (0.83 с)
@export var roll_cancel_time := 0.55
## Удар серии: окно клинка (enable/disable_attack_hitbox) у каждого клипа и
## направления своё — читается из самой анимации (_hit_window). Через
## attack_chain_after_hit после конца окна следующий удар серии начинается
## сразу, через attack_move_cancel_after_hit хвост обрывается движением.
## У третьего удара окно идёт до конца клипа — его не оборвать.
## Пинок (клип 1 с) — с kick_move_cancel_time
@export var attack_chain_after_hit := 0.02
@export var attack_move_cancel_after_hit := 0.05

## ── Вес лат (просьба: «удары слишком быстрые для человека в латах») ──
## Клип удара идёт с разной скоростью по фазам: тяжёлый медленный замах до
## окна клинка, быстрый сам удар, тяжёлый отмах. Хитбокс и вспышки висят на
## метод-треках клипа, поэтому остаются точно с картинкой. Финиш серии —
## замах ещё тяжелее, рипост — быстрее (наказание за открытого врага)
@export var attack_windup_speed := 0.6
@export var attack_finisher_windup_speed := 0.5
@export var riposte_windup_speed := 0.85

## ── Флёрри: быстрая серия из четырёх ударов ──
## Первый удар остаётся весомым (замах на атакующем), дальше серия разгоняется:
## каждый следующий удар быстрее, замахи короче, хитстоп мельче — рыцарь
## «входит в ритм». Четвёртый — вихрь с кольцом. Всё по шагам [1, 2, 3, 4]
## Темп всего клипа по шагу серии
@export var flurry_speed: Array[float] = [1.0, 1.12, 1.25, 1.0]
## Скорость замаха (до окна клинка) по шагу — множится на flurry_speed
@export var flurry_windup: Array[float] = [0.9, 0.95, 1.0, 0.7]
## Отмах после удара: пока в очереди следующий удар, хвост проматывается быстрее
@export var flurry_recovery_queued := 1.25
## Хитстоп удара по шагу — на быстрых шагах короче, чтобы поток не рвался
@export var flurry_hitstop: Array[float] = [1.0, 0.7, 0.7, 1.0]
## Рывок к врагу на каждом ударе: на сколько px ближе остановиться, дальше
## какой дистанции не рвёмся, максимальная скорость рывка
@export var flurry_lunge_stop := 24.0
@export var flurry_lunge_reach := 110.0
@export var flurry_lunge_speed := 250.0
## Сколько ударов в серии (последний — вихрь)
@export var combo_length := 4
## Когда в клипе вихря (Attack_4_) меч бьёт о землю — метод-трек play_fire_ring_vfx
const SPIN_SLAM_TIME := 0.667
## Двойники клинка: интервал между ними (с) на окне удара, начиная со 2-го шага
@export var flurry_ghost_interval := 0.035
var _ghost_cd := 0.0
@export var attack_strike_speed := 1.0
@export var attack_recovery_speed := 0.75
## За сколько (с клипа) до окна клинка уже начинается быстрый удар
@export var attack_strike_lead := 0.03
@export var run_attack_anim_speed := 0.85
@export var kick_anim_speed := 0.9
## Шаг вперёд всем весом — в момент удара, а не на замахе
@export var attack_step_speed := 125.0
@export var attack_windup_step_speed := 20.0
var _strike_fired := false
static var _hit_window_cache := {}
@export var kick_move_cancel_time := 0.6
## Разворот на бегу (Turn_) больше не отнимает управление. true — как было
@export var turn_locks_movement := false
## Скорость картинки разворота (клип 0.625 с)
@export var turn_anim_speed := 1.3
## Наведение удара: при зажатом направлении бьём туда, а к врагу доворачиваем,
## только если он в этом конусе (полуугол, градусы). Без направления — к
## ближайшему, в фокусе — всегда к цели фокуса
@export var aim_assist_cone_deg := 40.0
var roll_duration := 0.9
var roll_timer := 1.5
var roll_dir := Vector2.ZERO
var roll_control := 0.0

# --- BLOCK / PARRY ---
# Держать ПКМ — всегда блок (Block_). Парирование не отдельное действие по
# кнопке: пока держишь блок, стойка сама переключается на Parry_, когда
# враг спереди вот-вот ударит (читаем его настоящий замах через
# Enemy.is_about_to_strike — тот же таймер, что двигает мид-свинг попадание,
# см. enemy.gd _state_attack). Если удар приходится в это окно — идеальное
# парирование; если просто держал блок без такого совпадения — обычный блок
# (см. receive_attack). Вся отрисовка стойки идёт через ЕДИНУЮ функцию
# _update_block_parry_pose — раньше анимацию дёргали из пяти разных мест
# (start_parry/оба перехода в блок/whiff/check_for_turn), и они друг друга
# перебивали: то блок не проигрывался, то зависал на idle
var is_parrying := false
var is_blocking := false
# За сколько секунд ДО реального попадания враг считается "вот-вот ударит" —
# ровно на это время стойка успевает показать Parry_ прежде, чем прилетит удар
@export var parry_react_lead := 0.15
var can_counter := false         # флаг — был perfect parry?
var counter_window := 0.5       # сколько времени есть на контратаку
var counter_timer := 0.0

# Сколько держим позу Parry_ после удачного парирования, пока не отпустят
# блок — отдельно от can_counter/counter_timer (та пара про доступность
# контратаки, эта — чисто про то, что показывать на экране). Совпадает с
# длиной самого клипа Parry_* (0.5с) — даём ему доиграть, не обрывая раньше
const PARRY_POSE_HOLD := 0.5
var _parry_pose_timer := 0.0
var is_staggered := false       # враг застаггерен — доп. визуал/логика
# --------------------

# VFX
var active_hit_vfx_override: PackedScene = null

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
## Базовые значения ДО бонусов дерева навыков — max_health/max_stamina выше
## пересчитываются от этих констант заново при каждом recompute_skill_modifiers(),
## а не домножаются сами на себя, иначе повторная загрузка сейва задваивала бы бонус
const BASE_MAX_HEALTH := 100.0
const BASE_MAX_STAMINA := 100.0

# --- Дерево навыков (Руны Стойкости и другие — см. Save/skill_trees.gd) ---
## id открытых узлов дерева навыков. Персистится через SaveManager так же, как
## gold/skill_points (см. apply_to/capture_from), содержимое читается ТОЛЬКО
## этим персонажем — сам список ничего не применяет, это делает recompute_skill_modifiers()
var unlocked_skills: Array[String] = []
## Сумма эффектов всех открытых узлов трёх деревьев: ключ -> число
## (SkillTrees.sum_effects). Читать через skill(key)
var skill_fx: Dictionary = {}
## Окна после идеального парирования (Ответ стража / Судный взмах) и после
## полного блока (Клятва стража): бонус расходуется одной атакой
var _parry_bonus_left := 0.0
var _block_followup_ready := false
## После спасения Бальдром — снижение урона на 5 с (Последний луч)
var _baldur_shield_left := 0.0
# Накопленные бонусы — пересчитываются целиком в recompute_skill_modifiers(),
# никогда не изменяются напрямую нигде больше
var _skill_max_hp_percent := 0.0
var _skill_max_stamina_percent := 0.0
var _skill_physical_defense_percent := 0.0
var _skill_posture_resist_percent := 0.0
var _skill_stagger_resist_percent := 0.0
## Пока инертны при текущей боевой системе — блок уже гасит 100% урона и не
## тратит стамину вовсе, снижать там нечего. Учтены и применяются в нужных
## местах на случай, если бой изменится — см. get_damage_reduction_factor()/
## get_posture_damage_reduction_factor() и комментарий в try_unlock_skill()
var _skill_block_damage_reduction_percent := 0.0
var _skill_block_stamina_cost_reduction_percent := 0.0

# --- Стена трофеев (Player_scene/knight_trophies.gd) ---
const Trophies := preload("res://Player_scene/knight_trophies.gd")
const LootUI := preload("res://Levels/loot/loot_ui.gd")
## Счётчики подвигов: grunt/shield/brute/duelist/kills/executions/parries/
## prayers -> сколько набрано. Сейв — SaveManager.hero_progress
## (get_hero_progress/set_hero_progress)
var trophy_counts: Dictionary = {}
var _skill_capstone_conditional_posture_resist := false

# --- Стамина: расход по действиям (снижено относительно старых значений) ---
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

var is_starting := true
var is_stunned := false
var is_taking_damage := false
## Реакция на удар: столько секунд рыцарь не ходит, не бьёт и не блокирует —
## только перекат. Сам клип Take_Damage_ (0.75 с) длиннее, его хвост
## перебивает обычная анимация движения
@export var hurt_lock_time := 0.45
## Неуязвимость сразу после урона — та же, что у лучницы и мага
## (character_base.gd::post_hit_invulnerability). Свой таймер, а не
## is_invulnerable: тот же флаг держат баффы (Кровь Фенрира), и таймер урона
## не должен их снимать
@export var post_hit_invulnerability := 0.4
var _hit_invuln_timer := 0.0
var _hurt_token := 0

var hit_targets: Array = []
var _nan_reported := false
var gold := 0
## Копится на прокачку выбранного класса (см. UI/skill_points_bar.gd и
## SaveManager.gd), тот же контракт, что у gold. Растёт НЕ за каждое убийство —
## только когда skill_progress долился до skill_progress_per_point (см. ниже)
var skill_points := 0
## Сырой прогресс убийств к следующему очку — заливка полоски в
## UI/skill_points_bar.gd. По достижении skill_progress_per_point обнуляется
## (с переносом остатка) и конвертируется в +1 skill_points
var skill_progress := 0
@export var skill_progress_per_point := 10
var is_in_shop := false

func _ready() -> void:
	_setup_focus()
	# Этажность карты: лестницы (Levels/stairs_zone.gd) меняют высоту героя,
	# компонент масштабирует картинку и скорость (Player_scene/depth_component.gd)
	var depth := DepthComponentScript.new()
	depth.name = "DepthComponent"
	add_child(depth)
	# Вес в движении: наклон на беге, сжатие на старте/остановке, пыль на
	# остановке (пыль старта у рыцаря своя — handle_movement_vfx)
	var feel := MotionFeelScript.new()
	feel.name = "MotionFeel"
	feel.start_dust = false
	add_child(feel)
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
	# Новые звуки меча (Levels/sound_bank.gd) записаны тише прежних
	# перегруженных — база громче, чем в сцене (там под старые файлы)
	if SoundBank.pick("knight_hit_light"):
		_base_volume_db[hit_audio] = -6.0
		_base_volume_db[body_impact_audio] = -7.0
		_base_volume_db[block_audio] = -6.0
		_base_volume_db[parry_audio] = -7.0
	# Лязг доспеха — отдельный тихий слой поверх шага
	_armor_audio = AudioStreamPlayer2D.new()
	_armor_audio.name = "ArmorAudio"
	_armor_audio.bus = &"Combat"
	add_child(_armor_audio)

	anim.play("Started_" + last_direction)
	# Выхватывание меча из ножен в начале игры
	swing_audio.stream = SoundBank.pick_or("knight_draw", UNSHEATH_SOUND)
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
	# Истощение — как у Сигрид: багровая рамка с венами в такт сердцу
	# (UI/sigrid_exhaust.gd) вместо голубой виньетки ExhaustVignette (она в
	# сцене остаётся, но больше не включается). Первым ребёнком — слой рисуется
	# ПОД интерфейсом рыцаря (слои одного номера идут в порядке детей)
	var veins: CanvasLayer = ExhaustVeinsScript.new()
	veins.name = "ExhaustVeins"
	add_child(veins)
	move_child(veins, 0)
	exhaust_vignette = veins
	# Сначала инициализируем все системы
	health_bar.set_max_hp(max_health)
	health_bar.set_max_stamina(max_stamina)
	health_bar.set_max_posture(max_posture)
	# unlocked_skills сейчас пуст (SaveManager.apply_to зальёт его чуть позже,
	# отложенным вызовом из player_spawner.gd — оно и повторит этот пересчёт).
	# Вызываем и здесь тоже: без сейва (F6 из редактора) apply_to не вызовется
	# вовсе, а recompute должен отработать хотя бы раз и на голых значениях
	recompute_skill_modifiers()
	talisman_system = TalismanSystem.new()
	talisman_system.name = "TalismanSystem"
	add_child(talisman_system)
	magic = KnightMagicScript.new()
	magic.name = "KnightMagic"
	add_child(magic)
	magic.setup(self)
	# Стартовое заклинание: Благословение Тора — в книге и в слоте магии сразу
	magic.learn("Благословение Тора")
	# ТЕСТ: Сурт сразу в книге и во втором слоте магии (обычно — лут в амбаре,
	# LootBarn). Убрать эту строку, когда тест не нужен
	magic.learn("Благословение Сурта")
	inventory_ui.init(ability_system, inventory_system, self, talisman_system,
			magic.magic_inventory, magic.magic_slots)
	hud.init(ability_system)
	magic.build_hud(hud, health_bar)
	
	# Только потом загружаем предметы
	_load_starting_abilities()

## Страховка от "залипшего" бега — то же, что в character_base.gd::_input:
## Windows иногда съедает отпускание Shift (Alt+Shift — смена раскладки и
## т.п.), и рыцарь бежал сам после одного нажатия. Любое событие
## клавиатуры/мыши несёт реальное состояние Shift — по нему и отпускаем
func _input(event: InputEvent) -> void:
	if not (event is InputEventWithModifiers) or event.shift_pressed:
		return
	# Событие самой клавиши Shift не в счёт — Godot на Windows отдаёт его
	# с shift_pressed = false даже при нажатии
	if event is InputEventKey and (event.physical_keycode == KEY_SHIFT or event.keycode == KEY_SHIFT):
		return
	if Input.is_action_pressed("run") and _run_bound_to_shift():
		Input.action_release("run")


## ── Буфер ввода — тот же, что в character_base.gd (_pressed/_consume) ──
## Удар, перекат или пинок, нажатые, пока действие невозможно (перекат, стан,
## реакция на удар, молитва, последний удар серии), ждут input_buffer_time
## секунд реального времени и срабатывают, как только станет можно.
## Блок/парирование не буферизуются — там важен точный тайминг
@export var input_buffer_time := 0.2
const BUFFERED_ACTIONS := ["attack", "ui_accept", "kick"]
var _press_ms := {}


func _record_buffered_presses() -> void:
	for action in BUFFERED_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			_press_ms[action] = Time.get_ticks_msec()


func _pressed(action: String) -> bool:
	if not _press_ms.has(action):
		return false
	if Time.get_ticks_msec() - int(_press_ms[action]) > int(input_buffer_time * 1000.0):
		_press_ms.erase(action)
		return false
	return true


func _consume(action: String) -> void:
	_press_ms.erase(action)


func _run_bound_to_shift() -> bool:
	for e in InputMap.action_get_events("run"):
		if e is InputEventKey and (e.physical_keycode == KEY_SHIFT or e.keycode == KEY_SHIFT):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if is_in_shop or _net_down:
		return  # ← добавь, магазин сам обрабатывает свой Esc
	
	# Блокируем всё кроме инвентаря если он открыт. Esc обрабатывает сам
	# инвентарь (у него есть подразделы — настройки и навыки, и Esc должен
	# закрывать сначала их, а не всё окно целиком)
	if inventory_ui.visible:
		return
	
	# Переключение слотов только когда не атакуем и не уклоняемся
	if is_attacking or is_dodging or is_rolling:
		return
	if magic and magic.is_praying and not event.is_action_pressed("ui_cancel"):
		return
	# Колесо: slot_next — вверх, slot_prev — вниз (project.godot). У рыцаря
	# с магией колесо делится: вниз — следующая абилка, вверх — следующее
	# благословение (слот магии слева внизу)
	if magic and event.is_action_pressed("slot_next"):
		magic.magic_slots.next_slot()
	elif magic and event.is_action_pressed("slot_prev"):
		ability_system.next_slot()
	elif event.is_action_pressed("slot_next"):
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
	_parry_bonus_left = maxf(_parry_bonus_left - delta, 0.0)
	_baldur_shield_left = maxf(_baldur_shield_left - delta, 0.0)
	# Обновляем состояния "на грани" ДО расчёта тряски — истощение подкачивает
	# _shake_strength, и так тряска применится уже в этом же кадре
	_update_condition_fx(delta)
	_update_immunity_visual(delta)
	# слежение за целью и авто-переключение после убийства ведёт сам FocusSystem
	# в своём _process — отдельно дёргать его отсюда больше не нужно

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
		+ _bob_smoothed + _update_look_ahead(delta)


## Камера с упреждением: на бегу чуть уходит вперёд по ходу движения — видно,
## куда бежишь, и движение ощущается живее. С целью в фокусе — сдвиг к врагу
## (в кадре и герой, и противник). Плавно, без рывков
@export var look_ahead_distance := 22.0
@export var look_ahead_focus_share := 0.3
@export var look_ahead_focus_max := 36.0
@export var look_ahead_smoothing := 2.5
var _look := Vector2.ZERO

func _update_look_ahead(delta: float) -> Vector2:
	var target := Vector2.ZERO
	if is_instance_valid(focused_enemy):
		target = ((focused_enemy as Node2D).global_position - global_position) * look_ahead_focus_share
		target = target.limit_length(look_ahead_focus_max)
	elif not is_attacking and not is_rolling:
		target = (velocity / maxf(run_speed, 1.0)).limit_length(1.0) * look_ahead_distance
	_look = _look.lerp(target, minf(look_ahead_smoothing * delta, 1.0))
	return _look


func _update_immunity_visual(delta: float) -> void:
	# то же условие, что и в receive_attack — визуал показывает РЕАЛЬНУЮ
	# неуязвимость, а не приблизительную (иначе игрок учился бы врать себе)
	var immune := is_invulnerable or is_dodging or _roll_invulnerable()
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
	if _hit_invuln_timer > 0.0:
		_hit_invuln_timer -= delta
	if not is_in_shop and not inventory_ui.visible:
		_record_buffered_presses()
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
	# Кооп: при нуле здоровья рыцарь падает и лежит, пока Net не поднимет его
	# (net_respawn). В одиночной игре — как раньше: смерти у рыцаря пока нет
	if _net_down:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if Net.is_online() and health <= 0.0:
		_net_fall()
		return
	if is_in_shop:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Молитва (благословение богов) — рыцарь стоит с поднятым мечом, всё
	# остальное ждёт. Сбить её может только урон (knight_magic.gd)
	if magic and magic.is_praying:
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
	# Хвост переката (неуязвимость уже кончилась) обрывается ударом, пинком или
	# новым перекатом — нажатыми хоть заранее (буфер ввода). Раньше герой
	# катился до последнего кадра клипа, и нажатое ждало ~0.4 с
	if is_rolling and roll_control >= roll_cancel_time \
			and (_pressed("attack") or _pressed("ui_accept") or _pressed("kick")):
		_end_roll()
	if is_rolling:
		handle_roll(delta)
		return

	# --- ПЕРЕКАТ «ВНЕ ОЧЕРЕДИ» --------------------------------------------------
	# Ввод и запуск переката обрабатываем ДО стана получения урона и нокбэка,
	# чтобы зажатого игрока нельзя было залочить: он всегда может вырваться
	# перекатом (даёт неуязвимость в _on_hurtbox). Доджа (короткого уворота по
	# двойному тапу) больше нет — одно нажатие пробела сразу запускает перекат
	if not is_rolling:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")
	handle_roll_input()
	# Перекат, запущенный этим же кадром, отрабатываем сразу
	if is_rolling:
		handle_roll(delta)
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
	handle_focus_input()
	# Реакция на удар: ни удара, ни пинка, ни блока, пока не отыграла (раньше
	# ввод атаки шёл ДО этой проверки — бить можно было прямо из реакции)
	if is_taking_damage:
		is_blocking = false
		is_parrying = false
		velocity = Vector2.ZERO
		move_and_slide()
		return
	handle_attack_input()
	handle_kick_input()
	handle_parry_input(delta)
	check_for_turn()
	if is_parrying or is_blocking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_turning:
		if turn_locks_movement:
			# Старое поведение: на время клипа Turn_ управление отнято
			turn_velocity = turn_velocity.lerp(Vector2.ZERO, turn_friction * delta)
			velocity = turn_velocity
			move_and_slide()
			return
		# Разворот больше не держит: клип Turn_ — только картинка (с пылью),
		# а бежать в новую сторону можно сразу. Отпустили клавиши, повернули
		# ещё раз или клип чем-то перебили — картинка обрывается
		if input_vector == Vector2.ZERO or input_vector.normalized().dot(facing_dir) < 0.5 \
				or not String(anim.current_animation).begins_with("Turn_"):
			is_turning = false
			turn_lock = false

	# --- RUN ATTACK ---
	if is_run_attacking:
		combo_timer -= delta
		use_stamina(run_attack_stamina_drain * delta)
		anim.speed_scale = (exhausted_attack_speed_scale if is_exhausted() else 1.0) * _attack_phase_speed()
		attack_velocity = attack_velocity.lerp(Vector2.ZERO, friction * delta)
		velocity = attack_velocity
		move_and_slide()
		return

	# --- окна отмены удара ---
	# Клинок уже прошёл (хитбокс гаснет на ~0.40 с клипа), а клип ещё
	# доигрывает отмах. Раньше герой стоял до самого конца (0.6 с), и даже
	# нажатый следующий удар ждал. Теперь сразу после окна клинка (_hit_window) следующий удар
	# серии (или новая серия) начинается сразу, а чуть позже
	# хвост удара обрывается движением
	if is_attacking and not is_run_attacking and _attack_cancel(delta):
		pass
	# --- обычная атака с микро-рывком ---
	elif is_attacking:
		_steer_attack()
		combo_timer -= delta
		# выдохся — удары идут медленнее и тяжелее (каждый кадр, а не один раз
		# в play_attack: speed_scale общий на весь AnimationPlayer и сбрасывается
		# в 1.0 в начале каждого физического кадра)
		anim.speed_scale = (exhausted_attack_speed_scale if is_exhausted() else 1.0) * _attack_phase_speed()
		# Замах кончился — пошёл сам удар: свист, вскрик, шаг всем весом
		var atk_clip := String(anim.current_animation)
		if not _strike_fired and atk_clip.begins_with("Attack") \
				and anim.current_animation_position >= _hit_window(atk_clip).x - attack_strike_lead:
			_on_strike_start()
		# Флёрри: пока клинок идёт (окно удара), за рыцарем тянутся светлые
		# двойники — со 2-го шага серии
		_ghost_cd -= delta
		if _strike_fired and combo_step >= 2 and _ghost_cd <= 0.0 and atk_clip.begins_with("Attack") \
				and anim.current_animation_position <= _hit_window(atk_clip).y + 0.04 \
				and not _is_riposte and not is_instance_valid(_exec_target):
			_ghost_cd = flurry_ghost_interval
			FlurryFx.ghost(self, gfx, combo_step, facing_dir)
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
	# Резкие: до полной скорости и до остановки — около 0.1с. Раньше (6 и 4)
	# рыцарь секунду разгонялся и докатывался, и анимации плавно перетекали
	# бег → шаг → стойка; теперь анимация меняется сразу по клавишам
	# (play_movement_animation), и тело не должно скользить после неё
	var accel := 30.0      # разгон
	var friction_run := 30.0   # торможение

	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(target_velocity, accel * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction_run * delta)

	move_and_slide()
	_update_facing()
	# Пока доигрывает картинка разворота, её не перебиваем бегом
	if not is_turning:
		play_movement_animation()
	handle_movement_vfx(delta)
	handle_footsteps(delta)


## Доворот в начале замаха: первые attack_steer_time секунд удара серии его
## можно повернуть стрелками (или мышью с «Прицелом мышью») — клип того же
## удара переключается на новую сторону с того же места, хитбокс и рывок
## поворачиваются следом. С целью в фокусе, на добивании и рипосте — нет:
## там удар и так идёт точно во врага
@export var attack_steer_time := 0.12

func _steer_attack() -> void:
	if is_instance_valid(focused_enemy) or is_instance_valid(_exec_target) or _is_riposte:
		return
	var clip := String(anim.current_animation)
	if not clip.begins_with("Attack") or anim.current_animation_position > attack_steer_time:
		return
	var d := _aim_dir()
	if d == Vector2.ZERO:
		return
	var nd := get_direction(d)
	if nd == "" or nd == last_direction or not clip.ends_with(last_direction):
		return
	var new_clip := clip.substr(0, clip.length() - last_direction.length()) + nd
	if not anim.has_animation(new_clip):
		return
	var pos := anim.current_animation_position
	facing_dir = d
	last_direction = nd
	anim.play(new_clip)
	anim.seek(pos, true)
	update_weapon_tip()
	melee_weapon_tip()
	attack_velocity = d * attack_velocity.length()


## Окна отмены удара (см. _physics_process). true — удар отменён или сменён
## следующим и этот кадр уже идёт как обычное движение/новый удар
func _attack_cancel(_delta: float) -> bool:
	var clip := String(anim.current_animation)
	var pos := anim.current_animation_position
	if clip.begins_with("Attack"):
		var hit_end := _hit_window(clip).y
		if pos < hit_end + attack_chain_after_hit:
			return false
		if combo_queued:
			# Следующий удар серии — сразу, не дожидаясь конца клипа
			_advance_combo()
			return false
		if combo_step >= combo_length and _pressed("attack"):
			# Последний удар серии отыгран — нажатие начинает новую серию
			reset_combo()
			handle_attack_input()
			return false
		if input_vector != Vector2.ZERO and pos >= hit_end + attack_move_cancel_after_hit:
			reset_combo()
			return true
	elif clip.begins_with("Kick_") and input_vector != Vector2.ZERO and pos >= kick_move_cancel_time:
		reset_all_states()
		return true
	return false


# ----------------------------------------------------------
# НАПРАВЛЕНИЯ
# ----------------------------------------------------------

# Сами таблицы направлений переехали в DirectionUtil — они задают суффиксы
# имён анимаций и обязаны быть одинаковыми у всех персонажей. Обёртки здесь
# оставлены намеренно: get_direction/direction_to_vector зовутся из этого файла
# несколько десятков раз, и переписывать все вызовы ради переезда — лишний
# повод что-нибудь сломать
func get_direction(vec: Vector2) -> String:
	return DirectionUtil.from_vector(vec)

func direction_to_vector(dir: String) -> Vector2:
	return DirectionUtil.to_vector(dir)

# Компонент фокуса создаётся кодом, а не лежит нодой в player.tscn: так его
# подключение новому персонажу — две строки в _ready(), без правки сцены.
# Настройки прокидываем из @export-полей игрока, чтобы крутить их по-прежнему
# в инспекторе самого персонажа, а не искать вложенную ноду
func _setup_focus() -> void:
	_focus = FocusSystemScript.new()
	_focus.name = "FocusSystem"
	_focus.snap_radius = snap_radius
	_focus.break_range = focus_break_range
	_focus.marker_offset = focus_marker_offset
	add_child(_focus)


# Поиск ближайшего врага нужен не только фокусу: сюда же ходят нокбэк от
# урона (_apply_knockback_from) и наведение удара, когда цель не выбрана
func get_nearest_enemy() -> Node2D:
	return _focus.get_nearest_enemy() if is_instance_valid(_focus) else null


# Переключатель фокуса. Зовётся из _physics_process ПОСЛЕ проверок на магазин,
# стан и открытый инвентарь — поэтому опрос ввода остался на стороне игрока,
# а не уехал внутрь компонента
func handle_focus_input() -> void:
	if is_instance_valid(_focus):
		_focus.poll_input()


func _set_focused_enemy(enemy: Node2D) -> void:
	if is_instance_valid(_focus):
		_focus.set_target(enemy)


func _is_fleeing_focus() -> bool:
	return _focus.is_fleeing(input_vector, is_running) if is_instance_valid(_focus) else false


# Единая точка, решающая, куда смотрит игрок в обычном движении (вне атак/
# доджей/блока — у тех свой снап). Пока враг в фокусе, взгляд держится на нём
# каждый кадр вместо направления ввода — WASD при этом продолжает свободно
# управлять движением, не завися от того, куда смотрит персонаж
func _update_facing() -> void:
	if is_instance_valid(focused_enemy) and not _is_fleeing_focus():
		# Тип указан явно: _focus объявлен как Node (динамический preload-скрипт),
		# и вывести Vector2 из его метода парсер не может
		var to_target: Vector2 = _focus.direction_to_target()
		if to_target != Vector2.ZERO:
			var new_dir := get_direction(to_target)
			if new_dir != "":
				facing_dir = to_target
				last_direction = new_dir
			return

	if input_vector != Vector2.ZERO and not turn_lock:
		facing_dir = input_vector.normalized()
		last_direction = get_direction(facing_dir)


# Ходьба (не бег) при развёрнутом на фокус взгляде и движении назад — своя
# раскадровка Backwards_, а не Walk_. Во время бега сюда не попадаем: прямой
# побег от цели уже снял лок в _update_facing, и facing_dir там смотрит по
# движению — dot почти всегда положительный
func _is_moving_backward() -> bool:
	return _locomotion_mode() == LOCO_BACK


## Клипы Backwards_ рыцаря подписаны по направлению ДВИЖЕНИЯ (в player.tres
## Backwards_Right собран из строки листа, где он смотрит влево). Берём
## направление строго от взгляда — тогда лицо смотрит ровно на врага, даже если
## пятишься от него чуть наискосок
func _backwards_row() -> String:
	var i := DIR_RING.find(last_direction)
	return DIR_RING[(i + 4) % 8] if i >= 0 else get_direction(input_vector.normalized())


## Добивание: враг с пробитой концентрацией (руна над головой) в досягаемости
## удара. Сначала — тот, что в фокусе, иначе ближайший такой
@export var execution_reach := 72.0
var _exec_target: Node2D = null

func _execution_target() -> Node2D:
	if is_instance_valid(focused_enemy) and not focused_enemy.is_dead and focused_enemy.get("is_posture_broken") == true \
			and global_position.distance_to(focused_enemy.global_position) <= execution_reach:
		return focused_enemy
	var best: Node2D = null
	var best_d := execution_reach
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead or e.get("is_posture_broken") != true:
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


## Кого «доворачивать» удар без фокуса. Зажато направление — только врага в
## конусе aim_assist_cone_deg вокруг него (иначе бьём туда, куда жмут: раньше
## удар уходил к ближайшему врагу, даже если игрок целился в другого).
## Направления нет — ближайший в радиусе snap_radius
## Куда целится игрок: с «Прицелом мышью» (GameSettings.mouse_aim) — на курсор,
## иначе — по стрелкам. ZERO — направления нет
func _aim_dir() -> Vector2:
	if GameSettings.mouse_aim:
		var to := get_global_mouse_position() - global_position
		return to.normalized() if to.length() > 4.0 else Vector2.ZERO
	return input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO


func _assist_target() -> Node2D:
	var dir := _aim_dir()
	var min_dot := cos(deg_to_rad(aim_assist_cone_deg))
	var best: Node2D = null
	var best_d := snap_radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var to: Vector2 = (e as Node2D).global_position - global_position
		var d := to.length()
		if d > best_d or d < 0.001:
			continue
		if dir != Vector2.ZERO and to.normalized().dot(dir) < min_dot:
			continue
		best_d = d
		best = e
	return best


func try_snap_to_enemy() -> void:
	# Враг в ручном фокусе — приоритетная цель для атаки, а не просто
	# ближайший из толпы. Без этого удары при зажатом фокусе всё равно
	# наводились на ближайшего врага, а не на выбранного
	var enemy = focused_enemy if is_instance_valid(focused_enemy) else _assist_target()
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
	# ...и во время блока/парирования — иначе Turn_ перебивает Block_/Parry_
	# ровно тем же способом, что раньше ломало стойку: игрок держит щит и
	# зажимает направление, противоположное взгляду, Turn доигрывает и роняет
	# в нейтральную позу, а is_blocking при этом остаётся true
	if is_blocking or is_parrying:
		return
	# ...и пока враг в фокусе — взгляд держит _update_facing, а не эта резкая
	# анимация разворота. Без этой проверки любой бег в сторону от цели с
	# зафиксированным взглядом читался бы как рывок Turn_ каждый кадр.
	# Исключение — прямой побег бегом: там _update_facing уже сам снял лок,
	# и разворот должен работать как обычно
	if is_instance_valid(focused_enemy) and not _is_fleeing_focus():
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

	# стоп движения (важно для feel) — только в старом режиме с блокировкой
	turn_velocity = velocity * 0.4

	anim.play(anim_name, -1, 1.0 if turn_locks_movement else turn_anim_speed)
	play_turn_vfx(old_dir, new_facing)

func _roll_invulnerable() -> bool:
	return is_rolling and roll_control <= roll_iframes_end


## Проиграть клип с начала, даже если он уже идёт: перекат, оборванный новым
## перекатом в ту же сторону, или тот же удар — anim.play() одного и того же
## клипа просто продолжил бы его с середины
func _play_restart(clip: String, custom_speed := 1.0) -> void:
	var same := String(anim.current_animation) == clip
	anim.play(clip, -1, custom_speed)
	if same:
		anim.seek(0.0, true)


## Перекат кончился (доиграл клип) или его оборвал удар на хвосте
func _end_roll() -> void:
	is_rolling = false
	set_collision_mask_value(3, true)
	dodge_velocity = Vector2.ZERO
	roll_control = 0.0


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
	is_turning = false
	turn_lock = false
	_play_restart("Rolling_" + last_direction)
	dodge_velocity = roll_dir * roll_speed
	roll_timer = roll_duration

func play_movement_animation():
	if is_taking_damage or is_stunned:
		return
	if is_parrying or is_blocking:  # 👈 добавь эту проверку
		return
	
	var anim_name = ""

	# Анимация — по нажатым клавишам, а не по скорости: отпустил — сразу
	# стойка, зажал бег — сразу бег. Выбор по скорости давал плавные переходы
	# бег → шаг → стойка, пока тело разгонялось и тормозило
	anim.speed_scale = 1.0
	if input_vector == Vector2.ZERO:
		anim.play("Idle_" + last_direction)
		return
	elif not is_running or is_exhausted():
		var strafe := _strafe_animation()
		if strafe != "":
			_play_keep_phase(strafe)
			return
		# Ходьба спиной вперёд (взгляд держит фокус на враге) — своя
		# раскадровка Backwards_, а не Walk_. Суффикс здесь — направление
		# ДВИЖЕНИЯ (куда шагает нога), а не взгляда: Backwards_Right — шаг
		# спиной вправо, а не "лицом вправо" (см. правку по фидбэку).
		# На бег не распространяется: прямой побег от цели снимает лок в
		# _update_facing, и там facing_dir уже смотрит по движению — сюда
		# мы просто не попадаем (см. _is_moving_backward)
		if _is_moving_backward():
			var move_dir := _backwards_row()
			var backwards_name := "Backwards_" + move_dir
			if move_dir != "" and anim.has_animation(backwards_name):
				anim_name = backwards_name
			else:
				anim_name = "Walk_" + last_direction
		else:
			anim_name = "Walk_" + last_direction
	else:
		# Под фокусом бег вбок — тот же стрейф, только темп шага быстрее (раньше
		# тут играл обычный бег лицом к врагу, а тело ехало боком)
		var run_strafe := _strafe_animation()
		if run_strafe != "":
			anim.speed_scale = run_strafe_speed
			_play_keep_phase(run_strafe)
			return
		# Бег назад под фокусом — пятится лицом к врагу (фокус больше не
		# отпускает взгляд на бегу, focus_system.gd::release_on_flee)
		if _is_moving_backward():
			var back_name := "Backwards_" + _backwards_row()
			if anim.has_animation(back_name):
				anim.speed_scale = run_strafe_speed
				_play_keep_phase(back_name)
				return
		# Бег сразу в полном темпе (клипы Run_* сняты на 25 fps = speed_scale
		# 1.0), без прежнего разгона анимации с 0.35
		anim_name = "Run_" + last_direction

	_play_keep_phase(anim_name)


## Направления по кругу по часовой стрелке на экране — в этом же порядке идут
## строки листов анимаций рыцаря (Right, Down_Right, Down, ...)
const DIR_RING := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]
## Под фокусом: куда идёт корпус относительно взгляда на врага. Пороги — cos
## угла между движением и взглядом, с запасом (гистерезис): в стрейф входим
## при |cos| < strafe_enter (~63..117°), выходим только при |cos| >
## strafe_exit (~41°/139°) — иначе, кружа вокруг врага, анимация дёргалась
## бы между Walk_, стрейфом и Backwards_ на каждом пересечении порога
@export var strafe_enter := 0.45
@export var strafe_exit := 0.75
## Темп шага стрейфа на бегу под фокусом (тело едет вдвое быстрее ходьбы)
@export var run_strafe_speed := 1.6
const LOCO_FORWARD := 0
const LOCO_SIDE := 1
const LOCO_BACK := 2
var _loco_mode := LOCO_FORWARD


func _locomotion_mode() -> int:
	if input_vector == Vector2.ZERO or not is_instance_valid(focused_enemy) or _is_fleeing_focus():
		_loco_mode = LOCO_FORWARD
		return _loco_mode
	var d := input_vector.normalized().dot(facing_dir)
	match _loco_mode:
		LOCO_SIDE:
			if d > strafe_exit:
				_loco_mode = LOCO_FORWARD
			elif d < -strafe_exit:
				_loco_mode = LOCO_BACK
		_:
			if absf(d) < strafe_enter:
				_loco_mode = LOCO_SIDE
			elif d < -strafe_enter:
				_loco_mode = LOCO_BACK
			else:
				_loco_mode = LOCO_FORWARD
	return _loco_mode


## Стрейф (шаг вбок) под фокусом: взгляд держится на враге, а ноги идут в
## сторону. Строка листа StrafeLeft/StrafeRight — направление ДВИЖЕНИЯ, взгляд
## в ней повёрнут на 90° (в StrafeRight_Right рыцарь смотрит вверх и шагает
## вправо). Поэтому строку берём от направления ВЗГЛЯДА со сдвигом на четверть
## круга — так рыцарь на всём стрейфе смотрит лицом на врага, туда же, куда и
## до него (last_direction). "" — стрейф сейчас не нужен
func _strafe_animation() -> String:
	var side := _strafe_side()
	if side == 0:
		return ""
	var i := DIR_RING.find(last_direction)
	if i < 0:
		return ""
	var clip: String
	if side > 0:
		clip = "StrafeRight_" + DIR_RING[(i + 2) % 8]
	else:
		clip = "StrafeLeft_" + DIR_RING[(i + 6) % 8]
	return clip if anim.has_animation(clip) else ""


## Идёт ли шаг вбок от взгляда на врага: 1 — вправо, -1 — влево, 0 — нет
## (вперёд, назад, без фокуса)
func _strafe_side() -> int:
	if _locomotion_mode() != LOCO_SIDE:
		return 0
	# cross > 0 — движение вправо от взгляда (на экране y вниз)
	return 1 if facing_dir.cross(input_vector.normalized()) > 0.0 else -1


## Шаговые клипы (Walk_, Run_, Backwards_, StrafeLeft_, ...) при смене
## направления продолжаются с того же места шага, а не с первого кадра:
## под фокусом направление меняется на ходу, пока рыцарь обходит врага, и
## перезапуск каждый раз давал бы спотыкание
func _play_keep_phase(anim_name: String) -> void:
	var prev := anim.current_animation
	if prev == anim_name:
		return
	var pos := anim.current_animation_position if prev != "" else 0.0
	anim.play(anim_name)
	if prev != "" and prev.get_slice("_", 0) == anim_name.get_slice("_", 0):
		anim.seek(pos, true)

func play_idle_animation():
	anim.play("Idle_" + last_direction)

## Один тап пробела — сразу перекат, без доджа и без окна двойного тапа
## (та же идея, что у лучника в character_base.gd::handle_roll_input)
func handle_roll_input() -> void:
	if is_rolling:
		return
	if _pressed("ui_accept"):
		_consume("ui_accept")
		interrupt_all_actions()
		start_roll()

func add_coins(amount: int):
	coins += amount

func start_i_frames():
	await get_tree().create_timer(i_frame_time).timeout
	is_invulnerable = false

func interrupt_all_actions():
	_end_riposte()
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

	# Двойной тап уворота обрывает атаку на полпути тем же способом, что и
	# стан в receive_parry() — анимация удара не доигрывает, её method-track
	# с disable_attack_hitbox() не вызывается, и хитбокс залипает включённым
	# (именно поэтому баг с "хитбокс сам не выключается" выглядел случайным:
	# он ловится только если додж пришёлся ровно на окно между enable/disable)
	disable_attack_hitbox()

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
		var step_stream := SoundBank.step(get_tree(), global_position)
		footstep_audio.stream = step_stream if step_stream else (FOOTSTEP_LEFT if _footstep_left_next else FOOTSTEP_RIGHT)
		_play_armor_step()
		_play_varied(footstep_audio)
		_footstep_left_next = not _footstep_left_next

var _armor_audio: AudioStreamPlayer2D


## Пластины доспеха звякают под шаг — тише самого шага и не каждый раз
func _play_armor_step() -> void:
	if not is_instance_valid(_armor_audio) or randf() > 0.7:
		return
	var st := SoundBank.pick("knight_armor")
	if st:
		_armor_audio.stream = st
		_armor_audio.pitch_scale = randf_range(0.92, 1.08)
		_armor_audio.volume_db = randf_range(-1.5, 1.5)
		_armor_audio.play()


## Пыль на развороте — общий процедурный эффект (VFX/VFX_scene/skid_dust.gd),
## тот же, что у лучника и мага
func play_turn_vfx(_old_dir: Vector2, _new_dir: Vector2):
	var dir := velocity.normalized()
	if dir == Vector2.ZERO:
		dir = direction_to_vector(last_direction)
	var power := clampf(velocity.length() / maxf(run_speed, 1.0), 0.6, 1.2)
	SkidDust.skid(get_tree(), global_position + Vector2(0, 14) - dir * 4.0, dir, SkidDust.Kind.TURN, power)

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
	Net.echo_scene(vfx, {"move_direction": vfx.get("move_direction"), "anim_name": vfx.get("anim_name")})

# ----------------------------------------------------------
# АТАКИ / COMBO / RUN ATTACK / DASH
# ----------------------------------------------------------

func handle_parry_input(delta):
	if is_dodging or is_rolling or is_attacking:
		is_blocking = false
		is_parrying = false
		return

	# just_pressed берём ДО is_action_pressed — второй остаётся true и в тот
	# же кадр, когда сработал just_pressed, но нам нужен именно момент
	# свежего нажатия — см. _update_block_parry_pose
	var just_pressed := Input.is_action_just_pressed("parry")
	if Input.is_action_pressed("parry"):
		is_blocking = true
		velocity = Vector2.ZERO
	else:
		is_blocking = false
		is_parrying = false

	# Единая точка, которая решает, что сейчас должно быть на экране —
	# остальной код только меняет is_blocking/is_parrying, саму анимацию
	# трогает только эта функция
	_update_block_parry_pose(just_pressed)

	if _parry_pose_timer > 0.0:
		_parry_pose_timer = max(_parry_pose_timer - delta, 0.0)

	if can_counter:
		counter_timer -= delta
		if counter_timer <= 0:
			can_counter = false


# Единственное место, которое проигрывает Block_/Parry_. Сравниваем с
# anim.current_animation, а не с внутренним флагом "поменялось ли
# is_parrying" — тот подход был у прошлой версии и ломался на самом первом
# кадре блока (is_parrying оставался false→false, "ничего не поменялось",
# и Block_ просто никогда не проигрывался). Сверяясь с реальной текущей
# анимацией, функция всегда знает, стоит ли уже нужная поза, независимо от
# истории — и корректно перерисовывает при смене направления (last_direction).
#
# ВАЖНО: держим позу через play(name, -1, 0.0) — custom_speed=0, — а НЕ через
# anim.pause(). Проверено напрямую: AnimationPlayer.pause() в Godot 4 не
# "замирает на текущем кадре", а фактически ведёт себя как stop() — сбрасывает
# current_animation в пустую строку и is_playing() в false. Именно это и было
# причиной "ни одна анимация не играет": играли позу и тут же сами её гасили.
# custom_speed=0 держит current_animation и is_playing()=true, кадр просто не
# продвигается — ровно то самое "замерла в стойке", которое нужно
#
# ПАРИРОВАНИЕ ТРЕБУЕТ СВЕЖЕГО НАЖАТИЯ, А НЕ ПРОСТО УДЕРЖАНИЯ: раньше
# is_parrying включался автоматически, стоило врагу оказаться в окне замаха —
# и получалось, что можно было держать блок бесконечно заранее и парировать
# бесплатно, без всякой реакции. Теперь is_parrying становится true ТОЛЬКО в
# тот кадр, когда игрок ЗАНОВО нажал ПКМ (just_pressed) ровно во время
# открытого окна — то есть нужно осознанно отпустить и нажать снова именно
# сейчас, а не просто стоять зажатым. Держится true до конца окна (вдруг
# попадание засчитается на кадр позже), сбрасывается, как только окно
# закрывается — не переживает до следующей, никак не связанной атаки
func _update_block_parry_pose(just_pressed: bool) -> void:
	if not is_blocking:
		return
	var window_open := _find_incoming_attacker() != null
	if not window_open:
		is_parrying = false
	elif just_pressed:
		is_parrying = true
	# receive_attack() гасит is_parrying в тот же момент, когда засчитывает
	# перфект-парирование (чтобы не сработать дважды на один удар) — без
	# _parry_pose_timer поза тут же откатывалась бы в Block_. Сам таймер
	# форсируется синхронно в on_perfect_parry(), а не ждёт следующего кадра
	var show_parry := is_parrying or _parry_pose_timer > 0.0
	var desired := ("Parry_" if show_parry else "Block_") + last_direction
	if anim.current_animation == desired:
		return
	if not anim.has_animation(desired):
		return
	anim.play(desired, -1, 0.0)


func _find_incoming_attacker() -> Node:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or ("is_dead" in e and e.is_dead):
			continue
		if not e.has_method("is_about_to_strike"):
			continue
		if not e.is_about_to_strike(parry_react_lead):
			continue
		if _is_facing_attacker(e):
			return e
	return null

# Вызывается врагом (или hitbox-ом) когда его атака задела игрока
func receive_attack(attack_data: Dictionary) -> bool:
	# Павшего в коопе больше не бьют — он ждёт возрождения
	if _net_down:
		return false
	# Уворот/перекат — не просто неуязвимость, а НАГРАДА за тайминг: раньше
	# атака молча "проваливалась" здесь без всякой обратной связи, будто
	# игрок и не был под угрозой. Проверяем ДО общей is_invulnerable — та же
	# неуязвимость стоит и в грейс-период после урона, и от баффов (Кровь
	# Фенрира), а награждать имеет смысл именно активное уклонение
	# Награда — только за уворот в самом начале переката (perfect_dodge_window):
	# раньше неуязвим был весь перекат, и замедление с контрой давал любой
	# перекат сквозь удар. Дальше — просто неуязвимость (roll_iframes_end), а
	# на хвосте переката удар уже достаёт
	if is_dodging or (is_rolling and roll_control <= perfect_dodge_window):
		_on_perfect_dodge(attack_data)
		return false
	if _roll_invulnerable():
		return false

	# Неуязвимость из других источников (грейс-период после урона, баффы) —
	# молча гасим, здесь награждать нечего, это не игровой навык
	if is_invulnerable or _hit_invuln_timer > 0.0:
		return false

	# --- PERFECT PARRY ---
	# is_parrying тут истинно, только если стойка успела прочитать реальный
	# замах атакующего (см. _update_block_parry_pose/is_about_to_strike) —
	# то есть держал блок, и удар пришёлся ровно на прочитанный тайминг.
	# Следующий кадр _update_block_parry_pose сам решит, остаться в Parry_
	# или вернуться в обычный Block_ — отдельно дёргать анимацию тут не нужно
	if is_parrying:
		is_parrying = false
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


# Общая точка для нокбэка — источник урона может не передать source (тогда
# берём ближайшего врага, как и раньше в take_damage), а сила настраивается
# отдельно под обычный удар и под блок (щит гасит часть инерции, не всю)
func _apply_knockback_from(source: Node, force: float) -> void:
	var attacker = source if source else get_nearest_enemy()
	if attacker and is_instance_valid(attacker):
		var knockback_dir = (global_position - attacker.global_position).normalized()
		knockback_velocity = knockback_dir * force


# Удар остановлен щитом: урон не проходит, но держать блок не бесплатно —
# концентрация заполняется так же, как от обычного попадания (см. take_damage),
# и при полной шкале срабатывает тот же _posture_break()
func _on_blocked_attack(attack_data: Dictionary) -> void:
	# Блок гасит 100% HP-урона, но каждый удар в щит стоит стамины (навык
	# block_stamina_cost_reduction_percent — дешевле). Стамины нет — щит
	# выбит: этот удар ещё принят, но рыцарь в стане и открыт для следующего.
	# Без этой цены блок был бесконечной неуязвимостью спереди
	var cost := block_stamina_cost * (1.0 - _skill_block_stamina_cost_reduction_percent / 100.0)
	if not use_stamina(cost):
		play_block_hit_sound()
		_guard_break()
		return
	current_posture += block_posture_gain * get_posture_damage_reduction_factor()
	current_posture = min(current_posture, max_posture)
	health_bar.set_posture(current_posture)
	posture_regen_timer = posture_regen_delay
	# Клятва стража: удар принят щитом целиком — следующая атака тяжелее
	# бьёт по стойкости
	if skill("block_followup_posture_bonus_percent") > 0.0:
		_block_followup_ready = true

	# Щит гасит урон, но не всю инерцию удара — раньше игрок просто стоял на
	# месте, будто удара и не было
	_apply_knockback_from(attack_data.get("source", null), block_knockback_force)

	play_block_hit_sound()
	shake_camera(block_shake_strength)
	# Искры о щит — со стороны удара, искры летят обратно к бьющему
	var to_src := _dir_to_source(attack_data.get("source", null))
	_kfx("shield_hit", [get_tree(), global_position + KnightFx.CHEST + to_src * 16.0, to_src])
	# Холодная бело-голубая искра щита — отличается и от белой вспышки урона,
	# и от тёплых тонов лечения/монет: блок должен читаться как "звон металла",
	# а не как что-то из этих двух категорий
	flash_tint(Color(1.3, 1.4, 1.7, 1.0), 0.04, 0.18)

	if current_posture >= max_posture:
		_posture_break()

func play_parry_vfx() -> void:
	# Не на MeleeHit (тот маркер под обычные удары, парированию не подходит) и
	# не привязано к хитбоксу — просто сдвиг вперёд по направлению взгляда,
	# туда, где скрещиваются клинки, а не в центр игрока
	var dir = direction_to_vector(last_direction)
	var offset = 24.0  # чуть в сторону от центра игрока — здесь встречаются клинки
	_kfx("parry", [get_tree(), global_position + KnightFx.CHEST + dir * offset, dir])


## Направление от рыцаря к тому, кто ударил (нет источника — куда смотрит)
func _dir_to_source(source: Variant) -> Vector2:
	var src := source as Node2D
	if is_instance_valid(src):
		var d := src.global_position - global_position
		if d.length() > 0.001:
			return d.normalized()
	return direction_to_vector(last_direction)

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
	# Смелость под ударом — боги дают Одр
	if magic:
		magic.on_parry()
	trophy_note("parries")
	# Форсируем позу Parry_ прямо сейчас, а не ждём следующего кадра
	# _update_block_parry_pose — is_parrying receive_attack() уже погасил
	# (см. выше по стеку), и без явного форса поза откатилась бы в Block_,
	# толком не показавшись.
	# В отличие от Block_ (статичная стойка — держим кадр 0 через
	# custom_speed=0) Parry_ — это раскадровка самого отбива клинка, и на
	# 0-м кадре она визуально почти не отличается от готовности к блоку.
	# Поэтому здесь НЕ замораживаем, а даём клипу доиграть целиком
	_parry_pose_timer = PARRY_POSE_HOLD
	var parry_anim := "Parry_" + last_direction
	if anim.has_animation(parry_anim):
		anim.play(parry_anim)
	play_parry_vfx()
	parry_audio.stream = SoundBank.pick_or("knight_parry", PARRY_SOUND)
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
		source.take_posture_damage(35.0 * (1.0 + skill("posture_damage_percent") / 100.0))
	# Ответ стража / Судный взмах: окно 3 с на усиленную следующую атаку
	if skill("parry_next_sword_damage_percent") > 0.0 or skill("parry_next_posture_percent") > 0.0:
		_parry_bonus_left = 3.0

func take_damage(amount: int, source: Node = null) -> void:
	# Снижение урона (Благословение Бальдра и т.п.)
	amount = int(amount * get_damage_reduction_factor())
	# Кора от союзника (кооп, Net/ally_shield.gd) принимает удар первой
	var through: float = preload("res://Net/ally_shield.gd").absorb(self, float(amount))
	if through <= 0.0:
		_trigger_damage_flash()
		_hit_invuln_timer = post_hit_invulnerability
		return
	amount = int(ceilf(through))
	health_bar.take_damage(float(amount))
	health = health_bar.current_hp

	# Благословение Бальдра — одноразовое воскрешение вместо гибели
	if health <= 0.0 and baldur_revive_ready:
		_baldur_revive()
		return

	_hit_invuln_timer = post_hit_invulnerability
	# Тяжёлый удар (третий в серии, с разбега, добивание) попадание не
	# сбивает — урон проходит, но без отлёта и без реакции
	# В стане — тоже без реакции: поза Stunned_ остаётся, стан и так держит
	var armored := _has_hyper_armor() or is_stunned
	if not armored:
		# нокбэк от источника урона — игрок отлетает от врага
		_apply_knockback_from(source, knockback_force)
		_interrupt_for_hurt()

	_trigger_damage_flash()
	_play_pool(hurt_audio, HURT_SOUNDS, "hurt")
	damage_vignette.flash()
	hit_flash.flash()
	shake_camera(damage_shake_strength)

	BloodFx.hit(self, source as Node2D, BloodFx.power_for(amount, max_health, health <= 0.0))
	if is_instance_valid(source as Node2D):
		var hit_dir := -_dir_to_source(source)
		_kfx("impact", [get_tree(), global_position + KnightFx.CHEST - hit_dir * 6.0, hit_dir, 0.8])
	
	current_posture += 10.0 * get_posture_damage_reduction_factor()
	current_posture = min(current_posture, max_posture)
	posture_regen_timer = posture_regen_delay
	health_bar.set_posture(current_posture)

	if armored:
		if current_posture >= max_posture:
			_posture_break()
		return

	# Реакция — клипом AnimationPlayer, а не gfx.play() мимо него: раньше
	# флаг снимался по animation_finished самого спрайта, а AnimationPlayer
	# перебивал его своим клипом (конец удара → Idle_), сигнал не приходил,
	# и рыцарь стоял до переката. Теперь — таймер; токен отсекает старые
	# таймеры, если за время реакции прилетел следующий удар
	is_taking_damage = true
	_hurt_token += 1
	var token := _hurt_token
	var hurt_anim := "Take_Damage_" + last_direction
	if anim.has_animation(hurt_anim):
		anim.play(hurt_anim)
	await get_tree().create_timer(hurt_lock_time).timeout
	if token != _hurt_token or not is_taking_damage:
		return
	is_taking_damage = false

	if current_posture >= max_posture:
		_posture_break()


## Тяжёлые удары рыцаря держат попадание: третий в серии (Attack_3_), удар с
## разбега и добивание. Лёгкие (1-й, 2-й, пинок, контратака) — сбиваются
func _has_hyper_armor() -> bool:
	if not is_attacking:
		return false
	return is_run_attacking or combo_step >= 3 or _is_riposte or is_instance_valid(_exec_target)


## Удар обрывает начатое действие: анимацию заменит Take_Damage_, и её
## method-track с disable_attack_hitbox() уже не сработает
func _interrupt_for_hurt() -> void:
	# Удар на хвосте переката (после roll_iframes_end): Rolling_ заменится
	# реакцией и уже не доиграет — без этого is_rolling залип бы навсегда
	if is_rolling:
		_end_roll()
	_end_riposte()
	is_attacking = false
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	_exec_target = null
	attack_velocity = Vector2.ZERO
	is_turning = false
	turn_lock = false
	turn_velocity = Vector2.ZERO
	disable_attack_hitbox()

func heal(amount: float) -> void:
	health_bar.heal(amount)
	health = health_bar.current_hp

func use_stamina(amount: float) -> bool:
	if _has_free_stamina():
		return true
	return health_bar.use_stamina(amount)

# Пока активен бафф с флагом free_stamina (Кровь Фенрира, Безумие Берсерка) —
# бег/додж/атаки ничего не стоят. Тот же паттерн, что get_damage_multiplier/
# get_damage_reduction_factor: перебор active_buffs по ключу, а не завязка на
# конкретное имя баффа — новая способность подключается без правок здесь
func _has_free_stamina() -> bool:
	for buff in active_buffs.values():
		if buff.get("free_stamina", false):
			return true
	return false

## Концентрация переполнена (удары в щит, пропущенные удары) — стан, как у
## выбитого щита. Раньше здесь был только print, и срыв ничего не значил
func _posture_break() -> void:
	_guard_break()


## Стан на guard_break_stun_duration: рыцарь открыт, ни удара, ни блока, ни
## переката. Та же поза Stunned_, звук и дрожь, что у стана от контратаки
## врага (receive_parry). После — концентрация обнуляется
func _guard_break() -> void:
	if is_stunned:
		return
	reset_combo()
	is_run_attacking = false
	is_blocking = false
	is_parrying = false
	is_taking_damage = false
	attack_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	is_stunned = true
	current_posture = max_posture
	health_bar.set_posture(current_posture)
	_trigger_damage_flash()
	shake_camera(stun_shake_strength * 0.5)
	if anim.has_animation("Stunned_" + last_direction):
		anim.play("Stunned_" + last_direction)
	stun_audio.stream = STUN_SOUND
	var stun_stream := stun_audio.stream as AudioStreamMP3
	if stun_stream:
		stun_stream.loop = false
	_play_varied(stun_audio, 0.06)
	_start_stun_shake()
	await get_tree().create_timer(guard_break_stun_duration).timeout
	_stop_stun_shake()
	is_stunned = false
	_reset_posture()
	play_idle_animation()


func _reset_posture() -> void:
	current_posture = 0.0
	posture_regen_timer = 0.0
	health_bar.set_posture(0.0)

func handle_attack_input():
	if is_dodging or is_rolling:
		return
	# Нажатие — из буфера ввода (_pressed): нажатое во время переката, стана
	# или последнего удара серии сработает сразу, как только станет можно.
	# Гасим (_consume) только когда удар реально начат или встал в очередь
	if _pressed("attack"):
		if can_counter and not is_attacking:
			_consume("attack")
			can_counter = false
			start_counter_attack()
			return
		# Рядом враг с пробитой концентрацией (горит руна) — добивание: сразу
		# тяжёлый третий удар серии (Attack_3_), прямо в него. Важнее удара
		# с разбега; посреди серии — встаёт следующим в очередь
		var exec_target := _execution_target()
		if exec_target:
			_exec_target = exec_target
			if is_attacking:
				_consume("attack")
				combo_queued = true
			elif not is_run_attacking:
				_consume("attack")
				combo_step = 3
				play_attack(3)
			return
		if is_running and input_vector != Vector2.ZERO and not is_attacking and not is_run_attacking:
			_consume("attack")
			start_run_attack()
			return
		if is_attacking:
			# Последний удар серии — очереди дальше нет: нажатие ждёт в буфере
			# и начнёт новую серию сразу после
			if combo_step < combo_length:
				_consume("attack")
				combo_queued = true
		elif not is_run_attacking:
			_consume("attack")
			var aim_dir := _aim_dir()
			if aim_dir != Vector2.ZERO:
				facing_dir = aim_dir
				last_direction = get_direction(facing_dir)
			try_snap_to_enemy()
			start_combo()

func start_combo():
	combo_step = 1
	play_attack(combo_step)

func play_attack(step: int):
	_end_riposte()
	_take_attack_bonuses()
	is_attacking = true
	use_stamina(attack_stamina_cost)
	combo_timer = combo_window
	combo_queued = false
	dodge_velocity = Vector2.ZERO
	try_snap_to_enemy() 
	# Добивание — лицом ровно к врагу с руной, а не к ближайшему/в фокусе
	if is_instance_valid(_exec_target):
		var to_exec := (_exec_target.global_position - global_position).normalized()
		if get_direction(to_exec) != "":
			facing_dir = to_exec
			last_direction = get_direction(to_exec)
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
	# Своя анимация под 2/3/4-й удар серии есть не всегда — раньше это молча
	# обрывало ВСЮ атаку через reset_all_states() (урон, звук, VFX 4-го удара
	# включительно), а не просто оставляло картинку прежней. Пока для шага нет
	# своей анимации, переигрываем Attack_ — как только появится своя
	# Attack_2_/3_/4_, has_animation найдёт её сама, без правок кода
	if not anim.has_animation(anim_name):
		anim_name = "Attack_" + last_direction

	# Удар может начаться, пока прошлый ещё доигрывает (окно отмены) — и тем же
	# клипом (добивание после Attack_3_): с начала, а не с середины
	is_turning = false
	turn_lock = false
	_play_restart(anim_name)
	# Вихрь (4-й удар): на замахе рыцарь собирает силу — пыль тянется к ногам,
	# камешки подпрыгивают, на груди разгорается свет. Время — до удара о
	# землю (play_fire_ring_vfx на SPIN_SLAM_TIME клипа) с учётом темпа фаз
	if step == 4 and anim_name.begins_with("Attack_4") and not _is_riposte and not is_instance_valid(_exec_target):
		var w := _hit_window(anim_name)
		var wind_end := maxf(w.x - attack_strike_lead, 0.0)
		var wind_t := wind_end / maxf(flurry_windup[3] * flurry_speed[3], 0.1)
		var strike_t := maxf(SPIN_SLAM_TIME - wind_end, 0.0) / maxf(attack_strike_speed * flurry_speed[3], 0.1)
		_ffx("charge", [self, wind_t + strike_t])

	# Замах тяжёлый и почти на месте; свист, вскрик и шаг вперёд всем весом —
	# в момент самого удара (_on_strike_start), а не на замахе
	_strike_fired = false
	attack_velocity = direction_to_vector(last_direction) * attack_windup_step_speed


## Начался сам удар (клинок пошёл): свист, боевой вскрик (свой на каждый из
## первых трёх ударов, рипост кричит сам), шаг вперёд всем весом
func _on_strike_start() -> void:
	_strike_fired = true
	_play_pool(swing_audio, SoundBank.pool_or("knight_swing", SWING_SOUNDS), "swing")
	if not _is_riposte:
		match combo_step:
			1: _play_pool(voice_audio, GRUNT_1_SOUNDS, "grunt1")
			2: _play_pool(voice_audio, GRUNT_2_SOUNDS, "grunt2")
			3, 4: _play_pool(voice_audio, GRUNT_3_SOUNDS, "grunt3")
	var dir := facing_dir if facing_dir != Vector2.ZERO else direction_to_vector(last_direction)
	attack_velocity = dir * maxf(attack_step_speed, attack_velocity.length())
	# Флёрри: удар идёт вдогонку за врагом — рыцарь сам доскакивает до него
	var lunge := _lunge_velocity()
	if lunge != Vector2.ZERO:
		attack_velocity = lunge
		_ffx("lunge", [self, lunge, 1.0 if combo_step > 1 else 0.7])


## Окно клинка клипа удара (с, по метод-треку enable/disable_attack_hitbox) —
## у каждого клипа и направления своё. Нет трека — средние значения
func _hit_window(clip: String) -> Vector2:
	if _hit_window_cache.has(clip):
		return _hit_window_cache[clip]
	var w := Vector2(0.23, 0.43)
	if anim.has_animation(clip):
		var a := anim.get_animation(clip)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_METHOD:
				continue
			for k in a.track_get_key_count(t):
				var m := String(a.method_track_get_name(t, k))
				if m == "enable_attack_hitbox":
					w.x = a.track_get_key_time(t, k)
				elif m == "disable_attack_hitbox":
					w.y = a.track_get_key_time(t, k)
		w.y = minf(w.y, a.length)
	_hit_window_cache[clip] = w
	return w


## Скорость клипа по фазам удара (вес лат): замах — медленно, клинок — быстро,
## отмах — тяжело. Удар на бегу и пинок — просто чуть медленнее. Обычная серия
## идёт флёрри: первый удар весомый, дальше темп растёт (flurry_*). Рипост и
## добивание остаются тяжёлыми — их темп не разгоняется
func _attack_phase_speed() -> float:
	var clip := String(anim.current_animation)
	if clip.begins_with("Attack"):
		var pos := anim.current_animation_position
		var w := _hit_window(clip)
		var heavy := _is_riposte or is_instance_valid(_exec_target)
		var si := clampi(combo_step, 1, flurry_speed.size()) - 1
		var mult := 1.0 if heavy else flurry_speed[si]
		if pos < w.x - attack_strike_lead:
			if _is_riposte:
				return riposte_windup_speed
			if heavy:
				return attack_finisher_windup_speed
			return flurry_windup[si] * mult
		if pos < w.y:
			return attack_strike_speed * mult
		# Отмах: пока следующий удар уже в очереди — проматывается быстрее
		var rec := attack_recovery_speed * (flurry_recovery_queued if combo_queued and not heavy else 1.0)
		return rec * mult
	if clip.begins_with("Run_Attack"):
		return run_attack_anim_speed
	if clip.begins_with("Kick_"):
		return kick_anim_speed
	return 1.0


## Скорость рывка к цели на ударе серии: ближайший враг (в фокусе — он) в
## пределах flurry_lunge_reach, но дальше flurry_lunge_stop — летим к нему так,
## чтобы остановиться вплотную (затухание трения friction даёт путь ≈ v/friction).
## Zero — рывка нет (цели нет, уже вплотную, добивание/рипост идут своим шагом)
func _lunge_velocity() -> Vector2:
	if _is_riposte or is_instance_valid(_exec_target):
		return Vector2.ZERO
	var target: Node2D = focused_enemy if is_instance_valid(focused_enemy) else _assist_target()
	if target == null or target.get("is_dead") == true:
		return Vector2.ZERO
	var to := target.global_position - global_position
	var dist := to.length()
	if dist > flurry_lunge_reach or dist <= flurry_lunge_stop + 2.0:
		return Vector2.ZERO
	var v := minf((dist - flurry_lunge_stop) * friction, flurry_lunge_speed)
	return to / dist * v

## Рипост — контратака после идеального парирования или уворота. Раньше это
## был голый Attack_ без звука и без позиционирования хитбокса; теперь —
## первый удар серии (наводка на врага, хитбокс, замах), только тяжелее:
## урон × riposte_damage_mult, удар по концентрации врага, вес удара
## riposte_impact_mult (стоп-кадр, тряска, звук), суперброня. Дальше серия
## продолжается как обычно
@export var riposte_damage_mult := 2.0
@export var riposte_posture_damage := 30.0
@export var riposte_impact_mult := 1.8
var _is_riposte := false

func start_counter_attack():
	combo_step = 1
	play_attack(1)
	_is_riposte = true
	player_hitbox.set_meta("damage", maxi(1, int(round(attack_damage * riposte_damage_mult))))
	_play_pool(voice_audio, GRUNT_3_SOUNDS, "grunt3")
	attack_velocity = direction_to_vector(last_direction) * 200


func _end_riposte() -> void:
	if not _is_riposte:
		return
	_is_riposte = false
	player_hitbox.set_meta("damage", attack_damage)

func handle_kick_input():
	if is_dodging or is_rolling or is_attacking:
		return

	if _pressed("kick"):
		_consume("kick")
		start_kick()

func start_kick():
	is_attacking = true
	is_turning = false
	turn_lock = false
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
	_take_attack_bonuses()
	is_run_attacking = true
	is_attacking = true
	is_turning = false
	turn_lock = false

	var anim_name = "Run_Attack_" + last_direction

	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return
	update_weapon_tip()
	melee_weapon_tip()  # позиционируем player_hitbox перед игроком, иначе удар на бегу не попадает
	anim.play(anim_name)
	_play_pool(swing_audio, SoundBank.pool_or("knight_run_swing", RUN_SWING_SOUNDS), "run_swing")
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

## Эффекты взмаха — зовутся из клипов ударов (method-трек AnimationPlayer) в
## момент взмаха. Обычный удар — процедурная дуга клинка (knight_fx.gd), а под
## способностью (Фенрир, Берсерк) — её собственные спрайтовые вспышки
func play_hit_vfx():
	if active_hit_vfx_override == null:
		_kfx("slash", [self, KnightFx.Swing.HEAVY, direction_to_vector(last_direction)])
		return
	var scene_to_use: PackedScene = active_hit_vfx_override
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
	Net.echo_scene(vfx, {"move_direction": vfx.get("move_direction"), "anim_name": vfx.get("anim_name")})

func play_melee_hit_vfx():
	if active_hit_vfx_override == null:
		_kfx("slash", [self, KnightFx.Swing.RISING, direction_to_vector(last_direction)])
		return
	var scene_to_use: PackedScene = active_hit_vfx_override
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
	Net.echo_scene(vfx, {"move_direction": vfx.get("move_direction"), "anim_name": vfx.get("anim_name")})

func play_melee_2_hit_vfx():
	if active_hit_vfx_override == null:
		_kfx("slash", [self, KnightFx.Swing.SWEEP, direction_to_vector(last_direction)])
		return
	var scene_to_use: PackedScene = active_hit_vfx_override
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
	Net.echo_scene(vfx, {"move_direction": vfx.get("move_direction"), "anim_name": vfx.get("anim_name")})

func play_fire_ring_vfx():
	# Вихревой финишер 4-го удара: урон и отброс по всем врагам вокруг
	_spin_finisher()
	_ffx("finisher", [self, spin_radius])

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
	Net.echo_scene(vfx, {"move_direction": vfx.get("move_direction"), "anim_name": vfx.get("anim_name")})

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
			# Кооп: у копии врага поля защиты — только вид; настоящему (у хоста)
			# удар идёт мимо блока и парирования — тот же смысл
			e.take_damage(dmg, self, e.get("net_replica") == true)
		# усиленный отброс от игрока
		var dir: Vector2 = (e.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		if "knockback_velocity" in e:
			e.knockback_velocity = dir * spin_knockback
			# Отброшенный врезается ногами в землю — пыль тянется за ним
			SkidDust.skid(get_tree(), e.global_position + Vector2(0, 14), dir, SkidDust.Kind.STOP, 1.2)

	# отдача вихря — один раз на весь замах, а не на каждого задетого врага,
	# иначе в толпе стоп-кадр и тряска складывались бы в кашу
	if hit_any:
		shake_camera(hit_shake_strength * spin_impact_mult)
		do_hitstop(spin_impact_mult)
		# combo_step == 4, поэтому слой оружия внутри промолчит и сыграет только
		# низкий слой тела — самый тяжёлый звук в серии, ровно на добивании
		_play_hit_sound(spin_impact_mult)

## Удар на бегу: дуга идёт ровно со следом клинка на спрайте — когда, откуда и
## куда, снято с кадров MeleeRun.png (tools/build_knight_run_swing.gd ->
## knight_run_swing_data.gd). Заготовка Swing.RUN вела дугу в обратную
## сторону и раньше взмаха. Метод-трек клипа зовёт это незадолго до взмаха —
## досчитываем остаток сами (с учётом замедления удара при усталости)
const KnightRunSwing := preload("res://Player_scene/knight_run_swing_data.gd")
const RUN_SWING_LEAD := 0.03
## Удар с разбега тяжёлый и медленный — дуга крупнее и размашистее следа на
## спрайте: радиус, ширина полосы, яркость и охват сверх измеренного (с
## каждой стороны). Плюс внешняя бледная волна для веса
@export var run_swing_radius_mult := 1.35
@export var run_swing_width := 0.46
@export var run_swing_power := 1.45
@export var run_swing_extra_span_deg := 18.0

func play_running_hit_vfx():
	var sw: Dictionary = KnightRunSwing.DATA.get(last_direction, {})
	if sw.is_empty():
		_kfx("slash", [self, KnightFx.Swing.RUN, direction_to_vector(last_direction)])
		return
	var clip := anim.current_animation
	var speed := maxf(anim.speed_scale, 0.05)
	var t0: float = sw.t0 - RUN_SWING_LEAD
	var late := anim.current_animation_position - t0
	if late < 0.0:
		await get_tree().create_timer(-late / speed).timeout
		# Удар успели оборвать (перекат, урон) — дуге рисоваться не к чему
		if anim.current_animation != clip:
			return
		late = 0.0
	# Размах шире измеренного в обе стороны — середина остаётся там, где клинок
	var extra := deg_to_rad(run_swing_extra_span_deg) * signf(sw.to - sw.from)
	var a_from: float = sw.from - extra
	var a_to: float = sw.to + extra
	# Опоздали к началу взмаха — дуга стартует оттуда, где клинок уже сейчас
	var total: float = sw.t1 - t0
	var k := clampf(late / total, 0.0, 0.7)
	var from: float = lerpf(a_from, a_to, k)
	var dur := maxf(total * (1.0 - k), 0.08) / speed
	var radius := clampf(sw.radius * run_swing_radius_mult, 40.0, 58.0)
	_kfx("arc", [self, from, a_to, radius, run_swing_width, dur, run_swing_power,
			KnightFx.CHEST, true, true])
	# Внешняя волна — широкая и бледная, чуть позади клинка
	_kfx("arc", [self, from, a_to, radius * 1.18, run_swing_width * 0.7, dur * 1.1,
			run_swing_power * 0.35, KnightFx.CHEST, true, false])

# ----------------------------------------------------------
# ЗАВЕРШЕНИЕ
# ----------------------------------------------------------

func _on_anim_finished(finished_anim: StringName) -> void:
	print(">>> ЗАКОНЧИЛАСЬ: ", finished_anim)
	if finished_anim.begins_with("Started_"):
		is_starting = false
		play_idle_animation()
		return
	if finished_anim.begins_with("Rolling_"):
		_end_roll()
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

	# Серия — combo_length шагов (4: последний — вихрь/spin finisher, флёрри).
	# Раньше было урезано до 3 — 4-й удар (вихрь/spin finisher) временно
	# вынут из обычной цепочки, станет отдельным навыком. Код 4-го удара не
	# удалён (play_attack умеет step==4, _spin_finisher/play_fire_ring_vfx на
	# месте) — серия просто больше до него не доходит. Когда навык будет
	# готов и получит свой отдельный вызов play_attack(4), эту цифру можно
	# вернуть обратно на 4, если 4-й удар снова понадобится и в обычной серии
	_advance_combo()


## Следующий удар серии (из очереди) или конец серии. Зовётся по концу клипа
## удара и раньше — из окна отмены (_attack_cancel), как только клинок прошёл
func _advance_combo() -> void:
	if combo_queued and is_instance_valid(_exec_target) and not _exec_target.is_dead:
		# В очереди добивание — следующим идёт Attack_3_, с какого бы шага
		combo_step = 3
		play_attack(3)
	elif combo_queued and combo_step < combo_length:
		_exec_target = null
		combo_step += 1
		play_attack(combo_step)
	else:
		reset_combo()

func reset_combo():
	_end_riposte()
	is_attacking = false
	combo_step = 0
	combo_queued = false
	_exec_target = null
	# disable_attack_hitbox(), а не прямое monitoring=false — та же причина,
	# что и в interrupt_all_actions()/receive_parry(): гасить нужно и
	# monitoring, и disabled коллизии, иначе они могут разъехаться
	disable_attack_hitbox()
	play_idle_animation()

func reset_all_states():
	_end_riposte()
	is_attacking = false
	is_run_attacking = false
	is_turning = false
	turn_lock = false
	combo_step = 0
	combo_queued = false
	# На всякий случай — та же страховка, что в reset_combo()/interrupt_all_actions()
	disable_attack_hitbox()
	play_idle_animation()

func dash(force: float, _duration: float) -> void:
	# ПРЕДСУЩЕСТВУЮЩАЯ ЗАМЕТКА: это уже не применяется нигде — раньше
	# dodge_velocity двигал игрока только внутри ветки "if is_dodging" в
	# _physics_process, а сюда is_dodging никогда не выставлялся. То есть
	# dash() не двигал персонажа ещё до удаления доджа; сейчас — тем более.
	# Не чинил: не входит в задачу "убрать додж", отдельный баг способности
	if is_dodging or is_rolling or is_attacking:
		return
	var dir := facing_dir if facing_dir != Vector2.ZERO else direction_to_vector(last_direction)
	dodge_velocity = dir * force

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
	# В коопе время общее — одному его не замедлить
	if not Net.is_online():
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


## Награда за убийство (enemy.gd::_on_dead) — без физического подбора, в
## отличие от золота. Копит skill_progress (заливку полоски в
## UI/skill_points_bar.gd, которая сама опрашивает оба поля каждый кадр);
## skill_points растёт только когда полоска долилась целиком — while, а не if,
## на случай если amount за раз больше одного деления (перенос остатка).
## Блеск/звук — на каждый удар, независимо от того, набралось ли целое очко:
## это обратная связь "получил награду", а не "получил именно очко"
## Удар рыцаря дошёл до врага (enemy.gd::take_damage) — благословение на мече
## добавляет стихию (knight_magic.gd). blocked — удар пришёлся в щит
func on_weapon_hit(enemy: Node2D, blocked: bool) -> void:
	if magic:
		magic.on_weapon_hit(enemy, blocked)


func add_skill_points(amount: int) -> void:
	skill_progress += amount
	while skill_progress >= skill_progress_per_point:
		skill_progress -= skill_progress_per_point
		skill_points += 1
	_trigger_coin_glow()
	coin_audio.stream = COIN_SOUND
	_play_varied(coin_audio, 0.08)


# ============== ТРОФЕИ ==============

## Подвиг засчитан (counter — см. knight_trophies.gd LIST). Если трофей
## добыт прямо сейчас — табличка-уведомление справа и пересчёт бонусов
func trophy_note(counter: String, amount := 1) -> void:
	var before: int = int(trophy_counts.get(counter, 0))
	trophy_counts[counter] = before + amount
	var done := Trophies.newly_done(counter, before, before + amount)
	if done.is_empty():
		return
	for t in done:
		LootUI.of(get_tree()).show_pickup(null, tr("Трофей: %s") % tr(t["name"]), tr(t["bonus_text"]))
	# Бонус к максимуму HP/выносливости/Одра — как «уровень» дерева навыков
	recompute_skill_modifiers()
	SaveManager.capture_from(self)


func trophy_bonus(key: String) -> float:
	return Trophies.bonus(key, trophy_counts)


## Враг погиб от рыцаря (enemy.gd::_award_skill_points): вид скелета и общий счёт
func on_enemy_killed(enemy: Node) -> void:
	var kind = enemy.get("kind")
	if kind is int and kind >= 0 and kind < Trophies.KIND_COUNTERS.size():
		trophy_note(Trophies.KIND_COUNTERS[kind])
	trophy_note("kills")


## Прогресс героя сверх общих полей сейва (SaveManager.hero_progress)
func get_hero_progress() -> Dictionary:
	return {"trophies": trophy_counts.duplicate()}


func set_hero_progress(data: Dictionary) -> void:
	trophy_counts = (data.get("trophies", {}) as Dictionary).duplicate()
	recompute_skill_modifiers()

# ============== HITBOX ==============

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_invulnerable or is_dodging or _roll_invulnerable() or _hit_invuln_timer > 0.0:
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


## Эффект удара (дуга клинка, искры, рывок, вихрь): у себя — и эхом у других
## игроков на кукле рыцаря (кооп, Net.echo_static). fn — статическая функция
## knight_fx.gd / flurry_fx.gd, args — её аргументы как есть
const _KFX_PATH := "res://VFX/VFX_scene/knight_fx.gd"
const _FFX_PATH := "res://VFX/VFX_scene/flurry_fx.gd"

func _kfx(fn: String, args: Array) -> void:
	(load(_KFX_PATH) as Script).callv(fn, args)
	Net.echo_static(_KFX_PATH, fn, args)


func _ffx(fn: String, args: Array) -> void:
	(load(_FFX_PATH) as Script).callv(fn, args)
	Net.echo_static(_FFX_PATH, fn, args)


# ── Кооп: падение и возрождение (Net/net.gd) ──
# В одиночной игре смерти у рыцаря пока нет (_on_player_dead — TODO). В коопе
# павший лежит: ни ввода, ни движения, удары по нему не проходят, а через
# Net.RESPAWN_DELAY секунд Net поднимает его у костра (net_respawn). Своего
# клипа смерти у рыцаря нет — лежит в позе оглушения, потемнев
var _net_down := false

func _net_fall() -> void:
	_net_down = true
	interrupt_all_actions()
	is_stunned = false
	is_dodging = false
	is_rolling = false
	is_blocking = false
	is_parrying = false
	velocity = Vector2.ZERO
	var clip := "Stunned_" + last_direction
	if anim.has_animation(clip):
		anim.play(clip)
	create_tween().tween_property(self, "modulate", Color(0.55, 0.5, 0.5), 0.6)


func net_respawn(at: Vector2) -> void:
	global_position = at
	preload("res://Levels/bonfire/bonfire.gd").restore_hero(self)
	health = max_health
	if health_bar:
		health_bar.heal(health_bar.max_hp)
		health = health_bar.current_hp
	_net_down = false
	is_taking_damage = false
	is_stunned = false
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	is_invulnerable = true
	get_tree().create_timer(2.0).timeout.connect(func(): is_invulnerable = false)
	play_movement_animation()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()

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
		# удар на бегу весомее обычного удара серии, рипост — ещё весомее
		var power := run_attack_impact_mult if is_run_attacking else 1.0
		if _is_riposte:
			power = riposte_impact_mult
			# Отложенно: сначала враг примет сам удар (его hurtbox ловит этот же
			# контакт), и только потом — по концентрации. Иначе пробитая этим же
			# касанием концентрация превратила бы рипост в мгновенное добивание
			if enemy.has_method("take_posture_damage") and not enemy.is_dead:
				enemy.call_deferred("take_posture_damage", riposte_posture_damage * posture_mult_vs(enemy))
		_play_hit_sound(power)
		shake_camera(hit_shake_strength * power)
		# Флёрри: на быстрых шагах серии хитстоп короче — поток ударов не рвётся
		var hs := 1.0
		if not is_run_attacking and not _is_riposte and combo_step >= 1:
			hs = flurry_hitstop[clampi(combo_step, 1, flurry_hitstop.size()) - 1]
		do_hitstop(power * hs)

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
	# Теперь через общий учёт времени (VFX/juice.gd): там же замедление
	# последнего убийства и добивания — заявки копятся, действует самая
	# медленная, и стоп-кадр больше не обрывает чужое замедление
	Juice.slow(scale, duration, 1.0)


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
		_play_pool(hit_audio, SoundBank.pool_or("knight_hit_run", RUN_HIT_SOUNDS), "run_hit", -1.0, vol_offset, pitch_mult)
	elif combo_step == 1:
		_play_pool(hit_audio, SoundBank.pool_or("knight_hit_light", HIT_1_SOUNDS), "hit1", -1.0, vol_offset, pitch_mult)
	elif combo_step == 2 or combo_step == 3:
		_play_pool(hit_audio, SoundBank.pool_or("knight_hit_heavy", HIT_REST_SOUNDS), "hit_rest", -1.0, vol_offset, pitch_mult)

	# Слой тела — глухой низкий удар, играется ПОД любым попаданием, включая
	# вихрь (у него нет своего лязга, но вес чувствоваться должен)
	_play_pool(
		body_impact_audio, SoundBank.pool_or("knight_body", BODY_IMPACT_SOUNDS), "body",
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
	block_audio.stream = SoundBank.pick_or("knight_block", BLOCK_HIT_SOUND)
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
	# Постоянный бонус дерева навыков (physical_defense_percent) — тем же
	# множителем, что и временные баффы выше, а не отдельной системой
	factor *= (1.0 - _skill_physical_defense_percent / 100.0)
	# Трофей «Сломанный клинок»
	factor *= (1.0 - trophy_bonus("defense"))
	# Последний луч / Свет неугасших: 5 с после спасения Бальдром
	if _baldur_shield_left > 0.0:
		factor *= maxf(1.0 + skill("baldur_after_damage_taken_percent") / 100.0, 0.1)
	return factor


## Множитель входящего урона СТОЙКОСТИ (posture/concentration) — тот же
## принцип, что у get_damage_reduction_factor(), только для стойкости. Копит
## posture_resist_percent + stagger_resist_percent (у существующей боевой
## системы это один и тот же рычаг — накопление current_posture, отдельного
## "оглушения" как самостоятельного стата в игре нет), плюс пассив Сердца
## Йотуна (доп. -15%, пока HP > 70%)
func get_posture_damage_reduction_factor() -> float:
	var factor := 1.0 - (_skill_posture_resist_percent + _skill_stagger_resist_percent) / 100.0
	if _skill_capstone_conditional_posture_resist and max_health > 0.0 and health / max_health > 0.7:
		factor *= 0.85
	# Трофей «Расколотый щит»
	factor *= (1.0 - trophy_bonus("posture_resist"))
	return max(factor, 0.0)


# ─────────────────────────────────────────────
# ДЕРЕВО НАВЫКОВ
# ─────────────────────────────────────────────

## Полностью пересчитывает все производные бонусов деревьев навыков с нуля
## из unlocked_skills — а не домножает текущие значения на очередной эффект.
## Идемпотентно: можно звать сколько угодно раз (при покупке узла, при
## загрузке сейва) без риска задвоить бонус. Все три дерева рыцаря
## (Save/skill_trees.gd) — одной суммой skill_fx; часто читаемые числа
## первого дерева дублируются в _skill_* полях
func recompute_skill_modifiers() -> void:
	skill_fx = SkillTrees.sum_effects("knight", unlocked_skills)
	_skill_max_hp_percent = skill("max_hp_percent")
	_skill_max_stamina_percent = skill("max_stamina_percent")
	_skill_physical_defense_percent = skill("physical_defense_percent")
	_skill_posture_resist_percent = skill("posture_resist_percent")
	_skill_stagger_resist_percent = skill("stagger_resist_percent")
	_skill_block_damage_reduction_percent = skill("block_damage_reduction_percent")
	_skill_block_stamina_cost_reduction_percent = skill("block_stamina_cost_reduction_percent")
	_skill_capstone_conditional_posture_resist = skill("capstone_conditional_posture_resist") > 0.0

	# Трофеи прибавляют к максимуму сверх процентов дерева
	max_health = BASE_MAX_HEALTH * (1.0 + _skill_max_hp_percent / 100.0) + trophy_bonus("max_hp")
	max_stamina = BASE_MAX_STAMINA * (1.0 + _skill_max_stamina_percent / 100.0) + trophy_bonus("max_stamina")
	if magic:
		magic.max_odr = magic.BASE_MAX_ODR + trophy_bonus("max_odr")
	if is_instance_valid(health_bar):
		# set_max_hp/set_max_stamina тоже полностью восполняют HP/стамину —
		# ожидаемо здесь: пересчёт дерева навыков это по сути "level up",
		# как и в большинстве игр с деревьями умений
		health_bar.set_max_hp(max_health)
		health_bar.set_max_stamina(max_stamina)
		health = health_bar.current_hp


## Сумма эффекта key по открытым узлам рыцаря (0 — нет такого)
func skill(key: String) -> float:
	return float(skill_fx.get(key, 0.0))


## true, если узел из дерева рыцаря, ещё не куплен, все prerequisites
## открыты (и у финала набрано min_unlocked_in_tree узлов дерева)
func can_unlock_skill(tree_id: String, node_id: String) -> bool:
	return SkillTrees.can_unlock("knight", unlocked_skills, tree_id, node_id)


## Покупка узла — тратит skill_points, отмечает узел открытым, пересчитывает
## все бонусы и сохраняет прогресс. false = отказ (уже куплен/не выполнены
## требования/не хватает очков), UI не должен ничего менять в этом случае
func try_unlock_skill(tree_id: String, node_id: String) -> bool:
	if not can_unlock_skill(tree_id, node_id):
		return false
	var node := SkillTrees.get_node_data(tree_id, node_id)
	var cost: int = node.get("cost", 1)
	if skill_points < cost:
		return false
	skill_points -= cost
	unlocked_skills.append(node_id)
	recompute_skill_modifiers()
	SaveManager.capture_from(self)
	return true

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
	# Последний луч / Свет неугасших: ещё 5 с урон снижен
	if skill("baldur_after_damage_taken_percent") < 0.0:
		_baldur_shield_left = 5.0
	print("[БлагословениеБальдра] Воскрешение! HP восстановлено")


# ── Навыки рыцаря в бою (Save/skill_trees.gd: Кара рассвета, Свет последнего дня) ──

## Атака началась — бонусы «на следующую атаку» переходят в неё и
## расходуются: окно после парирования (Ответ стража, Судный взмах) и после
## полного блока (Клятва стража). Действуют на всех задетых этим ударом
var _attack_parry_bonus := false
var _attack_block_followup := false

func _take_attack_bonuses() -> void:
	_attack_parry_bonus = _parry_bonus_left > 0.0
	_parry_bonus_left = 0.0
	_attack_block_followup = _block_followup_ready
	_block_followup_ready = false


## Удар мечом дошёл до врага (enemy.gd::_hero_melee_damage) — итоговый урон.
## «Четвёртый удар комбинации» — последний, тяжёлый удар серии (вихрь)
func melee_damage_to(enemy: Node, dmg: int) -> int:
	var pct := skill("sword_damage_percent")
	if _attack_parry_bonus:
		pct += skill("parry_next_sword_damage_percent")
	if combo_step >= combo_length and not _is_riposte and not is_run_attacking:
		pct += skill("combo_final_damage_percent")
	return SkillTrees.scale_int(dmg, pct)


## Множитель урона по стойкости врага от удара мечом (удар в щит, рипост)
func posture_mult_vs(enemy: Node) -> float:
	var pct := skill("sword_posture_percent") + skill("posture_damage_percent")
	if enemy.get("is_blocking") == true:
		pct += skill("vs_blocking_posture_percent")
	if _attack_parry_bonus:
		pct += skill("parry_next_posture_percent")
	if _attack_block_followup:
		pct += skill("block_followup_posture_bonus_percent")
	return 1.0 + pct / 100.0


## Добивание (enemy.gd::_execute_by): Второе пламя продлевает благословение,
## Чистый разрез / Последняя черта возвращают выносливость, Приговор Бальдра
## бьёт ударной волной по врагам рядом
func on_execution_of(enemy: Node) -> void:
	if magic:
		magic.extend_blessing_on_execution()
	var st := skill("execution_stamina_percent")
	if st > 0.0 and is_instance_valid(health_bar):
		health_bar.current_stamina = minf(health_bar.current_stamina + health_bar.max_stamina * st / 100.0,
				health_bar.max_stamina)
	if skill("execution_wave_radius") > 0.0 and enemy is Node2D:
		# Отложенно: сначала сам добиваемый умирает, потом волна идёт по соседям
		_execution_wave.call_deferred((enemy as Node2D).global_position, enemy)


## Ударная волна добивания: соседям урон и удар по стойкости. Врага, у
## которого стойкость уже сломана, волна не добивает — только рыцарь сам
## (иначе одна руна снимала бы всю толпу без участия игрока)
func _execution_wave(at: Vector2, victim: Node) -> void:
	var radius := skill("execution_wave_radius")
	var posture := skill("execution_wave_posture") * (1.0 + skill("posture_damage_percent") / 100.0)
	var dmg := int(skill("execution_wave_damage"))
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == victim or not is_instance_valid(e) or e.is_dead or not (e is Node2D):
			continue
		var to: Vector2 = (e as Node2D).global_position - at
		if Vector2(to.x, to.y / 0.8).length() > radius:
			continue
		if e.get("is_posture_broken") == true:
			continue
		if dmg > 0 and e.has_method("take_damage"):
			e.take_damage(dmg, self, true)
		if is_instance_valid(e) and not e.is_dead and e.has_method("take_posture_damage"):
			e.take_posture_damage(posture)
	_kfx("impact", [get_tree(), at + Vector2(0, -6), Vector2.UP, 1.4])
	shake_camera(hit_shake_strength * 1.5)
	SoundBank.play_at(get_tree(), "execution_wave", at, -4.0)


## Брешь в обороне: окно добивания после сломанной стойки врага длиннее
## (enemy.gd::_posture_break спрашивает героя)
func execution_window_mult() -> float:
	return 1.0 + skill("execution_window_percent") / 100.0

func receive_parry(posture_damage: float) -> void:
	# Неуязвимость (дэш/Кровь Фенрира) снимает и урон, и стан от контратак.
	# is_rolling/is_dodging — туда же: обычную атаку (receive_attack) перекат
	# уже не пробивает, а этот канал (контратака/pummel врага) той же проверки
	# не имел. Баг: anim.play("Stunned_...") обрывал анимацию "Rolling_" на
	# середине, а is_rolling сбрасывается ТОЛЬКО в animation_finished для
	# "Rolling_" — она так и не доигрывала, и игрок навсегда застревал в
	# handle_roll() с нулевой скоростью (и заодно неуязвимым, раз is_rolling
	# держит защиту и от обычных атак тоже)
	if is_invulnerable or is_dodging or is_rolling:
		return
	# Уже в стане (выбитый щит) — второй стан поверх запутал бы оба таймера
	if is_stunned:
		return
	current_posture += posture_damage * get_posture_damage_reduction_factor()
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
		# Стан уже отбыт — только обнуляем шкалу (_posture_break застанил бы снова)
		_reset_posture()
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
