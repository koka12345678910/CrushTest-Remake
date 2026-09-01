extends CharacterBody2D

# ============== ПАРАМЕТРЫ ==============
# Движение
@export var walk_speed := 40.0
@export var run_speed := 80.0
@export var friction := 500.0
@export var direction_smoothness := 8.0

# Хитбокс атаки — как у игрока: одна форма, которая двигается по направлению
# взгляда (вместо 8 отдельных хитбоксов под каждое направление)
@onready var attack_shape: CollisionShape2D = $Hitbox/Atack_hitbox/CollisionShape2D
@export var attack_hitbox_offset := 24.0

# Здоровье
# Было 3 (ровно комбо рыцаря из 3 ударов) — поднято, чтобы лук с уроном 1 за
# стрелу (меньше уже некуда, int) не убивал так же быстро, как раньше
@export var max_health := 5
@export var damage_flash_time := 0.3
# Боевые параметры
@export var attack_range := 45
@export var attack_cooldown := 1.5
@export var attack_damage_min := 15
@export var attack_damage_max := 15
@export var attack_duration := 0.5
# Насколько замедлить проигрывание анимации замаха (1.0 = как нарисовано,
# меньше — медленнее). Читается через custom_speed у AnimationPlayer.play(),
# а не через persistent speed_scale — так замедление не "утекает" в другие
# анимации (idle/walk и т.п.) после атаки, откатывать вручную не нужно
@export_range(0.3, 1.0) var attack_speed_scale := 0.85
# На каком проценте замаха ЗАСЧИТЫВАЕТСЯ удар (0.55 = чуть за серединой).
# Раньше удар засчитывался только когда анимация ПОЛНОСТЬЮ доигрывала —
# смотрелось неестественно (клинок явно долетел до цели давно, а урон
# всё ещё не шёл). Оставшаяся часть клипа после этой точки — визуальный
# доигрыш/возврат в стойку, уже не связанный с уроном
@export_range(0.3, 0.9) var attack_impact_fraction := 0.55
@onready var attack_hitbox: Area2D = $Hitbox/Atack_hitbox
var current_attack_anim := "attack"
# Реальная (с учётом attack_speed_scale) длительность текущего замаха и
# момент внутри неё, когда засчитывается удар — считаются один раз при
# входе в ATTACK (см. _change_state) и читаются в _state_attack
var _attack_windup_time := 0.0
var _attack_impact_time := 0.0

func get_attack_damage() -> int:
	return randi_range(attack_damage_min, attack_damage_max)

# Визуальные эффекты
@export var damage_flash_color := Color(2.0, 0.2, 0.2, 1.0)
@export var berserk_highlight_color := Color(5.0, 4.5, 2.5, 1.0)
var _rest_modulate := Color.WHITE
# Исходный масштаб спрайта — считываем реальный (0.64/0.77, не 1.0) в _ready,
# чтобы пульсация замаха возвращалась ровно к нему, а не схлопывала спрайт к
# неверному размеру
var _rest_scale := Vector2.ONE
# Зацикленный tween пульсации замаха — храним ссылку, чтобы гарантированно
# остановить его при прерывании атаки (стан, смерть, новый замах и т.п.).
# Обычные одноразовые tween-ы в этом файле никто не хранит и не убивает —
# им не нужно, они сами доигрывают и пропадают. Зацикленный — другое дело:
# если не убить его явно, он будет вечно дёргать scale/modulate даже после
# того, как враг давно вышел из атаки
var _telegraph_tween: Tween

# AI поведение
@export var preferred_distance := 35.0
@export var vision_range := 150.0
@export var chase_range := 120.0
@export var think_rate := 0.25
@export var wander_speed_multiplier := 0.6
@export var target_refresh_interval := 0.15
@export var prediction_strength := 0.2
# Смерть
@export var death_fade_time := 0.8
# Концентрация (Posture)
@export var max_posture := 100.0
@export var posture_regen_rate := 15.0
@export var posture_regen_delay := 2.0
@export var block_posture_damage := 25.0
@export var block_chance := 0.4
# Реакция на дальний удар (стрела лучника): обычный vision_range/attack_range
# рассчитан на ближний бой с рыцарем, а лучник бьёт с гораздо большей
# дистанции — без этого враг просто не замечает, что в него стреляют издалека
@export var ranged_alert_range := 700.0
@export var ranged_block_chance := 0.5
# Радиус, в котором заметивший лучника враг поднимает тревогу остальным —
# без этого на лучника реагирует только тот, кого он реально задел, и враги
# сходятся по одному, а не толпой
@export var pack_alert_radius := 300.0
@export var coin_scene: PackedScene
@export var coin_drop_min := 1
@export var coin_drop_max := 3
@export var blood_vfx_scene: PackedScene
@export var parry_vfx_scene: PackedScene

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	HIT_STUN,
	DEAD,
	BLOCK,
	PARRY,    # ← добавь
	COUNTER,
	STAGGER   # ← добавь
}

# ============== ПЕРЕМЕННЫЕ ==============

var health := 0
var is_dead := false

var _stuck_timer := 0.0
var _last_position := Vector2.ZERO
var _direction_change_cooldown := 0.0  # добавь к переменным вверху

var current_state := State.IDLE
var state_time := 0.0

var player: Node2D = null
var see_player := false
# true пока враг "помнит" дальний выстрел — на это время игнорируем обычный
# vision_range, иначе _decide_state()/_state_chase() тут же вернут в WANDER,
# ведь стрелявший физически всё ещё далеко за пределами обычной видимости
var is_ranged_alert := false
var _pending_ranged_block := false

var direction := Vector2.DOWN
var move_velocity := Vector2.ZERO

var target_position: Vector2
var target_refresh_timer := 0.0
var attack_started := false


var hit_targets := []

var attack_cooldown_timer := 0.0

var hit_stun_timer := 0.0
var think_timer := 0.0
var can_attack := true
var attack_active := false
var attack_hit_window := false

var wander_direction := Vector2.DOWN
# роум-блуждание: каждый отрезок пути — случайный шаг от ТЕКУЩЕЙ позиции
# (а не орбита вокруг одной точки), поэтому враг реально обходит area, а не
# топчется на пятачке. Мягкий поводок (patrol_leash_radius) вокруг точки
# спавна не даёт разбрестись по всей карте.
@export var wander_step_min := 70.0
@export var wander_step_max := 220.0
@export var patrol_leash_radius := 360.0
@export var wander_pause_min := 0.8
@export var wander_pause_max := 2.5
var home_position := Vector2.ZERO
var _home_set := false
var wander_target := Vector2.ZERO
var wander_pause_timer := 0.0

var last_anim_direction := "down"
var posture := 0.0
var posture_regen_timer := 0.0
var is_blocking := false
var is_posture_broken := false

var _nan_reported := false
var block_hit_count := 0          # сколько ударов заблокировал подряд (для анимации/статистики)
# Парирование решается рандомно на каждый заблокированный удар — не по
# фиксированному счётчику, чтобы не было предсказуемого паттерна
# "блок-блок-всегда парирует"
@export var parry_chance := 0.35
# Блок держится, пока игрок атакует; после того как перестал — ещё столько секунд,
# затем враг выходит из блока (иначе застревал в блоке и таскался за игроком)
@export var block_hold_time := 0.45
var block_hold_timer := 0.0
var is_parrying := false          # окно парирования
var parry_timer := 0.0
var parry_window := 0.3         # длительность окна парирования
var counter_timer := 0.0
var is_countering := false
var is_player_berserk := false
@export var counter_duration := 0.75
@export var pummel_posture_damage := 20.0  # урон по концентрации игрока
@onready var anim: AnimationPlayer = $EnemyAnim
@onready var vision_area: Area2D = $VisionArea
@onready var hitbox: Area2D = $Hitbox
@onready var hp_bar: ProgressBar = $EnemyUI/HPBar
@onready var posture_bar: ProgressBar = $EnemyUI/PostureBar
@onready var block_vfx: GPUParticles2D = $BlockVFX
@onready var state_label: Label = $StateLabel
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var impact_audio: AudioStreamPlayer2D = $ImpactAudio
@onready var voice_audio: AudioStreamPlayer2D = $VoiceAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio

# Враг переиспользует боевые сэмплы игрока, но звучит ниже: Death Knight —
# крупнее и тяжелее, и по одному тону слышно, чей это удар. Позиционный
# AudioStreamPlayer2D + attenuation в сцене довершают: дальний враг тише
const ENEMY_SWING_SOUND := preload("res://Sound/melee_sound/swing.mp3")
const ENEMY_HIT_SOUND := preload("res://Sound/melee_sound/hit.mp3")
const ENEMY_DEATH_SOUND := preload("res://Sound/death_sound/death.mp3")
# Реакция на боль при получении урона — те же 4 файла, что и у игрока (уже
# заведён принцип "враг переиспользует боевые сэмплы игрока, но звучит ниже"
# через enemy_pitch_down в _play_enemy_sound). Раньше здесь заглушкой играл
# ENEMY_GRUNT_SOUNDS — тот же пул, что и на замахе атаки, теперь он остаётся
# только под атаку, а боль звучит отдельно
const ENEMY_HURT_SOUNDS := [
	preload("res://Sound/take_damage_sound/take_damage_sound_1.mp3"),
	preload("res://Sound/take_damage_sound/take_damage_sound_2.mp3"),
	preload("res://Sound/take_damage_sound/take_damage_sound_3.mp3"),
	preload("res://Sound/take_damage_sound/take_damage_sound_4.mp3"),
]
const ENEMY_GRUNT_SOUNDS := [
	preload("res://Sound/groaning_sound/attack1.mp3"),
	preload("res://Sound/groaning_sound/attack2.mp3"),
	preload("res://Sound/groaning_sound/attack3.mp3"),
]
@export var enemy_pitch_down := 0.78   # общий сдвиг тона вниз — "крупнее" игрока
@export var enemy_pitch_variation := 0.1
# Вскрик не на каждой атаке — иначе враг тараторит без остановки
@export var enemy_grunt_chance := 0.5

# ============== READY ==============

func _ready() -> void:
	randomize()

	health = max_health
	hp_bar.max_value = max_health
	hp_bar.value = health
	posture_bar.max_value = max_posture
	posture_bar.value = 0.0
	hp_bar.visible = false
	posture_bar.visible = false
	if state_label:
		state_label.visible = false  # отладочный флаг состояния над головой — скрыт
	attack_hitbox.body_entered.connect(_on_attack_body_entered)

	$Hurtbox.add_to_group("enemy_hurtbox")
	
	if vision_area:
		vision_area.body_entered.connect(_on_vision_body_entered)
		vision_area.body_exited.connect(_on_vision_body_exited)

	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.body_entered.connect(_on_hitbox_hit)

	_rest_scale = $AnimatedSprite2D.scale

	_change_state(State.IDLE)
	anim.animation_finished.connect(_on_animation_finished)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if _is_player_attack(area):
		var dmg = _get_damage_from(area)
		var source = area.get_parent()
		take_damage(dmg, source)

# И в атаке врага по игроку — используй receive_attack:
func _deal_damage_to_player() -> void:
	if player and player.has_method("receive_attack"):
		var attack_data = {
			"damage": get_attack_damage(),
			"source": self
		}
		player.receive_attack(attack_data)

# ============== PHYSICS ==============
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Санитизация от NaN: если позиция/скорость/направление стали нефинитными,
	# сбрасываем в безопасное состояние. Иначе NaN самораспространяется и
	# move_and_slide каждый кадр спамит "cannot be normalized", игра встаёт колом.
	if not (global_position.is_finite() and velocity.is_finite() and move_velocity.is_finite() and direction.is_finite()):
		if not _nan_reported:
			_nan_reported = true
			var _ppos: Vector2 = player.global_position if (player and is_instance_valid(player)) else Vector2(INF, INF)
			var _pvel: Vector2 = player.velocity if (player and is_instance_valid(player)) else Vector2(INF, INF)
			push_warning("[enemy NaN] state=%s pos=%s vel=%s mv=%s dir=%s home=%s wander=%s target=%s ppos=%s pvel=%s" % [State.keys()[current_state], global_position, velocity, move_velocity, direction, home_position, wander_target, target_position, _ppos, _pvel])
		if not home_position.is_finite():
			home_position = Vector2.ZERO
		if not global_position.is_finite():
			global_position = home_position
		if not wander_target.is_finite():
			wander_target = global_position
		velocity = Vector2.ZERO
		move_velocity = Vector2.ZERO
		direction = Vector2.DOWN
	state_time += delta
	think_timer += delta
	_direction_change_cooldown = max(0.0, _direction_change_cooldown - delta)
	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)
	if attack_cooldown_timer <= 0.0:
		can_attack = true
	# реген концентрации
	if not is_blocking and posture > 0.0:
		posture_regen_timer += delta
		if posture_regen_timer >= posture_regen_delay:
			posture = max(0.0, posture - posture_regen_rate * delta)
	else:
		posture_regen_timer = 0.0
	if current_state not in [
		State.ATTACK,
		State.BLOCK,
		State.HIT_STUN,
		State.DEAD,
		State.PARRY,
		State.COUNTER,
		State.STAGGER  # ← добавь
	]:
		if think_timer >= think_rate:
			think_timer = 0.0
			_decide_state()
	_update_state(delta)
	move_velocity = move_velocity.move_toward(
		Vector2.ZERO,
		friction * delta
	)
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * 2 * delta)
		velocity = knockback_velocity
	else:
		velocity = move_velocity
	_separate_from_player(delta)
	_separate_from_enemies(delta)
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	move_and_slide()
	if current_state == State.WANDER and get_slide_collision_count() > 0:
		if _direction_change_cooldown <= 0.0:
			# наткнулись на препятствие — выбираем новую точку блуждания
			_pick_new_wander_direction()
			_direction_change_cooldown = 0.8
	# таймеры парирования и контратаки

	if is_countering:
		counter_timer -= delta
		if counter_timer <= 0.0:
			is_countering = false
			_change_state(State.CHASE)
	
	state_label.text = State.keys()[current_state]

# move_and_slide() не расталкивает уже перекрывшиеся тела с нулевой скоростью —
# без этого враг может "прилипнуть" к игроку и отлепится только от столкновения со стеной.
# ВАЖНО: коррекция ограничена по скорости (separation_push_speed), а не мгновенная.
# Раньше global_position восстанавливалась на полную величину КАЖДЫЙ кадр — если
# игрок непрерывно шёл на врага, коррекция идеально компенсировала его движение,
# и враг просто ехал вместе с игроком 1-в-1 (особенно заметно в BLOCK/PARRY/COUNTER,
# где у врага move_velocity = 0 и больше ничего его не двигает). Ограничение скорости
# ломает это "идеальное слежение": если игрок давит быстрее, чем едет коррекция,
# дистанция реально уменьшается до настоящего физического столкновения капсул.
#
# НО: додж/перекат (dodge_speed=300, roll_speed=225) временно отключают коллизию
# с врагами и МОГУТ прогнать игрока глубоко "сквозь" врага за один рывок — а пока
# is_dodging/is_rolling мы коррекцию вообще не запускаем. Если после такого рывка
# просто ползти с ограниченной скоростью, глубокий нахлёст будет расползаться
# заметно долго ("прилипает, потом сам отлипает"). Поэтому: маленькие постоянные
# нахлёсты (игрок давит вплотную) — ползут с кэпом, а большие одноразовые
# нахлёсты (после доджа/переката) — снапаются мгновенно, как раньше.
@export var separation_push_speed := 140.0
@export var separation_snap_distance := 18.0

# .normalized() на векторе с NaN/Inf-компонентами — это и есть источник
# "Vector2 cannot be normalized" (не просто нулевая длина, её Godot нормализует
# молча в (0,0)). Если позиции двух тел совпали точно (после доджа/переката,
# скопления врагов), безопаснее взять запасное направление, чем звать
# normalized() на потенциально проблемном векторе.
func _safe_direction(vec: Vector2, fallback: Vector2 = Vector2.DOWN) -> Vector2:
	if vec.length() > 0.001 and vec.is_finite():
		return vec.normalized()
	return fallback

func _separate_from_player(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	# Пока игрок реально прокатывается/уворачивается на заметной скорости — не
	# расталкиваем, чтобы он проходил сквозь врагов. НО is_dodging/is_rolling
	# держатся до конца АНИМАЦИИ, а сама скорость рывка (dodge_velocity) гасится
	# заметно быстрее — если ориентироваться только на флаг, враг застревает на
	# слишком близкой (физически столкнулся) дистанции на весь хвост анимации,
	# и это выглядит как "прилип прямо во время доджа/переката".
	if (player.is_dodging or player.is_rolling) and player.dodge_velocity.length() > 20.0:
		return
	# во время своей атаки/контратаки враг подходит ближе, чтобы хитбокс доставал,
	# но всё равно не даём телам полностью наложиться
	var min_separation := 34.0
	if current_state in [State.ATTACK, State.COUNTER]:
		min_separation = 22.0
	var offset := global_position - player.global_position
	var dist := offset.length()
	if dist < min_separation:
		var dir := _safe_direction(offset)
		var needed := min_separation - dist
		if needed > separation_snap_distance:
			global_position += dir * needed
		else:
			global_position += dir * min(needed, separation_push_speed * delta)

# Раздвигаем врагов друг от друга — без этого два врага могут оказаться
# почти в одной точке (пачка спавна, нокбэк и т.п.), и тогда move_and_slide
# сам пытается их разъединить и падает на normalize(0,0) ("Vector2 cannot
# be normalized"), потому что дистанция между центрами равна нулю
func _separate_from_enemies(delta: float) -> void:
	# Копим коррекцию от ВСЕХ близких врагов сразу и применяем один раз в
	# конце — а не сразу по каждому соседу по очереди. При скоплении 3+ врагов
	# последовательные коррекции могут частично гасить друг друга (оттолкнулись
	# от одного — придвинулись к другому), оставляя остаточное перекрытие,
	# на котором Godot спотыкается в своей собственной физике.
	var min_separation := 26.0
	var push := Vector2.ZERO
	var deepest_needed := 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e) or e.is_dead:
			continue
		var offset: Vector2 = global_position - e.global_position
		var dist: float = offset.length()
		if dist < min_separation:
			# ровно наложенные тела — расталкиваем в случайную сторону,
			# а не normalized(), которое на нулевом/NaN векторе даёт (0,0)/NaN
			var dir: Vector2 = _safe_direction(offset, Vector2.RIGHT.rotated(randf() * TAU))
			var needed: float = (min_separation - dist) * 0.5
			push += dir * needed
			deepest_needed = max(deepest_needed, needed)

	if push == Vector2.ZERO:
		return
	if deepest_needed > separation_snap_distance:
		global_position += push
	else:
		var push_len := push.length()
		var capped_len: float = min(push_len, separation_push_speed * delta)
		global_position += push * (capped_len / push_len)

# ============== AI ==============

func _effective_vision_range() -> float:
	return max(vision_range, ranged_alert_range) if is_ranged_alert else vision_range

# Проактивно замечаем лучника на дистанции ranged_alert_range, даже если по
# врагу ещё ни разу не попали — физическая VisionArea рассчитана на ближний
# бой (~150px) и лук с гораздо большей дистанции для неё попросту невидим
func _scan_for_ranged_threat() -> void:
	for p in get_tree().get_nodes_in_group("ranged_player"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_dead") and p.is_dead():
			continue
		if global_position.distance_to(p.global_position) <= ranged_alert_range:
			player = p
			see_player = true
			is_ranged_alert = true
			_alert_nearby_allies(p)
			return

# Поднимает тревогу соседним врагам — иначе на лучника реагирует только тот,
# кого он реально подстрелил, и толпа сходится по одному вместо разом
func _alert_nearby_allies(source: Node2D) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e) or e.is_dead or e.is_ranged_alert:
			continue
		if e.current_state in [
			State.DEAD, State.HIT_STUN, State.ATTACK,
			State.PARRY, State.COUNTER, State.BLOCK
		]:
			continue
		if global_position.distance_to(e.global_position) > pack_alert_radius:
			continue
		e.player = source
		e.see_player = true
		e.is_ranged_alert = true
		e._change_state(State.CHASE)

func _decide_state() -> void:
	if current_state in [
		State.DEAD,
		State.HIT_STUN,
		State.ATTACK,
		State.PARRY,    # ← добавь
		State.COUNTER   # ← добавь
	]:
		return

	if current_state == State.BLOCK:
		return

	if not is_ranged_alert:
		_scan_for_ranged_threat()

	# пробуем заблокировать если игрок атакует рядом
	if player and is_instance_valid(player):
		if _is_player_in_range(attack_range * 1.5):
			if player.is_attacking and not is_blocking and not is_posture_broken and not is_player_berserk:
				_try_block()
				return
	
	if player and is_instance_valid(player):

		if _is_player_in_range(_effective_vision_range()):

			var dist = global_position.distance_to(
				player.global_position
			)

			if dist <= attack_range and can_attack:
				_change_state(State.ATTACK)

			elif dist <= chase_range or is_ranged_alert:
				_change_state(State.CHASE)

			else:
				_change_state(State.WANDER)

		else:
			is_ranged_alert = false
			_change_state(State.WANDER)

	else:
		_change_state(State.WANDER)
		
	# контратака если игрок атакует во время нашего парирования
	if is_parrying and player and player.is_attacking and not is_player_berserk:
		is_parrying = false
		_change_state(State.COUNTER)
		return

func play_parry_vfx() -> void:
	if parry_vfx_scene == null:
		return
	var vfx = parry_vfx_scene.instantiate()
	# Не привязано к хитбоксу — сдвиг в сторону игрока, туда, где встречаются
	# клинки, а не в центр врага
	var dir := Vector2.RIGHT
	if is_instance_valid(player):
		dir = global_position.direction_to(player.global_position)
	vfx.global_position = global_position + dir * 32.0
	get_tree().current_scene.add_child(vfx)

func play_blood_vfx() -> void:
	if blood_vfx_scene == null:
		return
	var vfx = blood_vfx_scene.instantiate()
	vfx.global_position = global_position + Vector2(15, 0)  # смещение вправо
	get_tree().current_scene.add_child(vfx)

func _update_state(delta: float) -> void:
	match current_state:

		State.IDLE:
			_state_idle(delta)

		State.WANDER:
			_state_wander(delta)

		State.CHASE:
			_state_chase(delta)

		State.ATTACK:
			_state_attack(delta)

		State.HIT_STUN:
			_state_hit_stun(delta)

		State.BLOCK:
			_state_block(delta)

		State.DEAD:
			pass

		State.PARRY:
			_state_parry(delta)

		State.COUNTER:
			_state_counter(delta)
		State.STAGGER:
			_state_stagger(delta)

# ============== STATE MACHINE ==============

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# Ловим ЛЮБОЙ уход из ATTACK, а не только через _exit_attack() — врага
	# могли застаннить/убить/парировать прямо посреди замаха (HIT_STUN,
	# STAGGER, DEAD и т.п. переключают состояние напрямую, не заходя в
	# _exit_attack), и без этой подстраховки зацикленный tween пульсации
	# телеграфа так и продолжил бы дёргать scale/modulate до бесконечности
	if current_state == State.ATTACK and _telegraph_tween:
		_stop_attack_telegraph()

	current_state = new_state
	state_time = 0.0

	match new_state:

		State.COUNTER:
			move_velocity = Vector2.ZERO
			is_countering = true
			counter_timer = counter_duration
			attack_active = true
			hit_targets.clear()
			_update_attack_shape()
			# стан игрока — только если он в досягаемости (не издалека)
			if player and player.has_method("receive_parry") and _is_player_in_range(attack_range * 1.4):
				player.receive_parry(pummel_posture_damage)

		State.IDLE:
			move_velocity = Vector2.ZERO

		State.WANDER:
			pass

		State.CHASE:
			pass

		State.ATTACK:
			move_velocity = Vector2.ZERO
			attack_started = false
			if player:
				var to_player := player.global_position - global_position
				# на случай точного совпадения позиций (после доджа/переката,
				# скопления врагов и т.п.) — не даём normalized() получить (0,0)
				if to_player.length() > 0.001:
					direction = to_player.normalized()
			can_attack = false
			hit_targets.clear()
			_update_attack_shape()
			# рандомно выбираем атаку
			var attacks = ["attack", "attack2"]
			current_attack_anim = attacks[randi() % attacks.size()]
			attack_direction_name = _get_direction_name(direction)
			# Замах показывает НАСТОЯЩИЙ свинг оружия, а не заглушку с цветом —
			# парирование завязано на чтение движения врага, а не на вспышку
			# (см. _state_attack). Проигрываем чуть медленнее (attack_speed_scale)
			# — так замах читается яснее и оставляет больше времени на реакцию.
			# current_animation_length — "сырая" длина клипа БЕЗ учёта скорости
			# воспроизведения, поэтому реальную длительность считаем сами
			_play_animation(current_attack_anim, attack_speed_scale)
			_play_attack_sound()
			_attack_windup_time = anim.current_animation_length / attack_speed_scale
			# Удар засчитывается не в конце анимации, а в её середине —
			# клинок долетает до цели раньше, чем доигрывает весь замах и
			# возврат в стойку. Остаток клипа после этой точки — чистый
			# доигрыш, уже не завязанный на попадание
			_attack_impact_time = _attack_windup_time * attack_impact_fraction
			_trigger_attack_telegraph(_attack_impact_time)

		State.HIT_STUN:
			move_velocity = Vector2.ZERO
			knockback_velocity = Vector2.ZERO
			hit_stun_timer = 1.0
			print("hit_stun_timer установлен: ", hit_stun_timer)

		State.BLOCK:
			move_velocity = Vector2.ZERO
			is_blocking = true
			block_hold_timer = block_hold_time

		State.DEAD:
			_on_dead()
			
		State.PARRY:
			move_velocity = Vector2.ZERO
			is_parrying = true
			parry_timer = parry_window
			var anim_name = "parry_" + _get_direction_name(direction)
			anim.play(anim_name)
		
		State.STAGGER:
			move_velocity = Vector2.ZERO
			attack_active = false


# ============== СОСТОЯНИЯ ==============
# IDLE

func _state_idle(_delta: float) -> void:

	# Полная остановка
	move_velocity = Vector2.ZERO

	# Idle анимация
	_play_animation("idle")

# ===================== WANDER =====================

func _state_wander(delta: float) -> void:
	# «Дом» фиксируем на первой точке блуждания (для заспавненных врагов
	# позиция выставляется уже после _ready, поэтому берём её здесь)
	if not _home_set:
		home_position = global_position
		_home_set = true
		_pick_new_wander_direction()

	# Пауза на месте — враг стоит и осматривается
	if wander_pause_timer > 0.0:
		wander_pause_timer -= delta
		move_velocity = Vector2.ZERO
		_play_animation("idle")
		return

	var to_target := wander_target - global_position
	var dist := to_target.length()

	# Дошли до точки — пауза, затем новая точка
	if dist < 12.0:
		wander_pause_timer = randf_range(wander_pause_min, wander_pause_max)
		_pick_new_wander_direction()
		move_velocity = Vector2.ZERO
		_play_animation("idle")
		return

	# Застряли (стена/другой враг) — выбираем новую точку
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	if moved < 0.5:
		_stuck_timer += delta
		if _stuck_timer >= 0.5:
			_stuck_timer = 0.0
			_pick_new_wander_direction()
	else:
		_stuck_timer = 0.0

	# Плавно поворачиваемся к цели и идём
	var target_dir := to_target / dist
	direction = direction.lerp(target_dir, 6.0 * delta).normalized()
	move_velocity = direction * walk_speed * wander_speed_multiplier
	_play_animation("walk")

func _pick_new_wander_direction() -> void:
	# Случайный шаг от ТЕКУЩЕЙ позиции в случайном направлении и на случайную
	# длину — так враг реально обходит территорию, а не орбитирует вокруг
	# одной точки (движение непредсказуемо: разный угол и длина каждый раз).
	var angle := randf() * TAU
	var step := randf_range(wander_step_min, wander_step_max)
	var candidate := global_position + Vector2(cos(angle), sin(angle)) * step

	# Мягкий поводок: если предложенный шаг уводит слишком далеко от точки
	# спавна — вместо жёсткого ограничения направляем шаг обратно к дому,
	# так враг сам "спохватывается" и возвращается в свою зону патрулирования
	if candidate.distance_to(home_position) > patrol_leash_radius:
		var back_dir := (home_position - global_position).normalized()
		if back_dir == Vector2.ZERO:
			back_dir = -Vector2(cos(angle), sin(angle))
		candidate = global_position + back_dir * step

	wander_target = candidate

# ===================== CHASE =====================
func _state_chase(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_change_state(State.WANDER)
		return

	if not _is_player_in_range(_effective_vision_range()):
		is_ranged_alert = false
		_change_state(State.WANDER)
		return

	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0:
		target_position = player.global_position + player.velocity * prediction_strength
		target_refresh_timer = target_refresh_interval

	var to_player := target_position - global_position
	var dist := to_player.length()
	
	if dist == 0:
		move_velocity = Vector2.ZERO
		return

	var dir := to_player / dist
	var error := dist - preferred_distance
	
	# если слишком близко — останавливаемся полностью
	if dist < preferred_distance * 0.5:
		move_velocity = Vector2.ZERO
		_play_animation("idle")
		return
	
	if abs(error) > 5.0:
		var move_dir := dir if error > 0.0 else -dir
		direction = direction.lerp(move_dir, direction_smoothness * delta).normalized()

		if is_ranged_alert:
			# Погоня за лучником — тут важна скорость закрытия дистанции, а
			# не "убегает ли он". Если решать по флаг-скорости игрока, как
			# ниже, враг трусцой идёт на стоящего лучника, и тот безнаказанно
			# отстреливается на месте
			move_velocity = direction * run_speed
			_play_animation("run")
		else:
			# Смотрим как быстро игрок убегает ОТ нас
			# dot > 0 означает что игрок движется в сторону от врага
			var player_flee_speed :float = player.velocity.dot(dir)

			if player_flee_speed > walk_speed * 0.4:
				# Игрок убегает достаточно быстро — бежим
				move_velocity = direction * run_speed
				_play_animation("run")
			else:
				# Игрок стоит или идёт — просто идём
				move_velocity = direction * walk_speed
				_play_animation("walk")
	else:
		move_velocity = Vector2.ZERO
		_play_animation("idle")

# Публичный признак "вот-вот ударю" — читает его блок игрока (player.gd,
# _find_incoming_attacker), чтобы понять, когда переключаться на анимацию
# парирования вместо обычного блока. Не заглядывает в приватные таймеры
# врага напрямую — отдаёт готовый bool через один явный вызов.
# Истинно от (impact - lead_time) и ДО КОНЦА замаха включительно, а не
# гаснет ровно в момент удара: порядок обработки _physics_process у разных
# нод не гарантирован, и если закрыть окно точно на _attack_impact_time,
# на кадре самого попадания оно могло бы уже читаться как false в
# зависимости от того, кто раньше отработал в этом кадре — игрок или враг
func is_about_to_strike(lead_time: float) -> bool:
	if current_state != State.ATTACK or is_dead:
		return false
	# Окно держится от (impact - lead_time) до КОРОТКОГО фиксированного
	# запаса ПОСЛЕ удара (не до конца замаха!). Раньше верхней границы не
	# было вообще — окно оставалось открытым всю добивочную часть анимации
	# после попадания, из-за чего ЛЮБОЙ блокированный удар засчитывался как
	# идеальное парирование. 0.08с — это только страховка на случай, если
	# player.gd успел обновить is_parrying на кадр позже, чем враг долетел
	# ударом в этот же кадр, а не намеренное окно для парирования
	var since_impact := state_time - _attack_impact_time
	return since_impact >= -lead_time and since_impact <= 0.08


var attack_direction_name := ""  # добавь в переменные
func _state_attack(_delta: float) -> void:
	move_velocity = Vector2.ZERO

	# Игрок исчез — прерываем атаку. Проверяем на ЛЮБОЙ фазе (замах или уже
	# бьёт), а не только после активации хитбокса — иначе враг доигрывал бы
	# замах против пустоты
	if not player or not is_instance_valid(player):
		_exit_attack()
		_change_state(State.WANDER)
		return

	if not attack_started:
		# Хитбокс активируется в _attack_impact_time — момент ВНУТРИ реальной
		# анимации замаха (см. _change_state), а не когда она полностью
		# доиграет. Раньше ждали конец всего клипа — смотрелось неестественно:
		# клинок уже давно долетел до цели по картинке, а урон всё ещё не
		# шёл. Оставшиеся кадры после этой точки — чистый доигрыш/возврат в
		# стойку, уже никак не завязанный на попадание. Парировать/уворачиваться
		# нужно по движению оружия, а не по цветной вспышке — та осталась лишь
		# фоновой подсказкой (см. _trigger_attack_telegraph)
		if state_time < _attack_impact_time:
			return
		# Направление НЕ переприцеливаем здесь специально: свинг уже играет
		# в направлении, зафиксированном в момент входа в замах (иначе хитбокс
		# бил бы не туда же, куда визуально размахивается оружие). Раньше
		# переприцел был нужен, пока замах был невидимой паузой без всякого
		# движения — теперь то, что видит игрок, и есть честная цель удара
		attack_started = true
		attack_active = true
		attack_hit_window = true
		hit_targets.clear()
		_update_attack_shape()
		_stop_attack_telegraph()

	# Прямой опрос перекрытия каждый кадр, пока хитбокс активен — подстраховка
	# к сигналу body_entered. На самом первом кадре активации форма ещё
	# физически выключена (disabled=false применится позже, на следующий кадр,
	# через call_deferred в _update_attack_shape), так что опрос ничего не
	# найдёт — но со следующего кадра он надёжно поймает игрока, даже если тот
	# уже стоял в зоне, а не только что в неё зашёл
	if attack_active:
		for body in attack_hitbox.get_overlapping_bodies():
			_try_hit_body(body)


func _exit_attack() -> void:
	attack_active = false
	attack_hit_window = false
	attack_started = false
	attack_shape.call_deferred("set", "disabled", true)
	attack_cooldown_timer = attack_cooldown
	# Атака могла прерваться прямо посреди замаха (игрок исчез, врага
	# застаннило и т.п.) — гасим пульсацию телеграфа и здесь тоже, иначе
	# зацикленный tween так и продолжит дёргать scale/modulate до бесконечности
	_stop_attack_telegraph()
# =========================================================
# HIT STUN
# =========================================================
func _state_hit_stun(delta: float) -> void:
	# НЕ обнуляем move_velocity сразу — даём нокбэку сработать
	hit_stun_timer -= delta
	
	var anim_name = "take_damage_" + _get_direction_name(direction)
	if anim.current_animation != anim_name or not anim.is_playing():
		anim.play(anim_name)
	
	if hit_stun_timer <= 0.0:
		move_velocity = Vector2.ZERO
		_change_state(State.CHASE)

# ===================== ANIMATION =====================
func _play_animation(state: String, speed := 1.0) -> void:
	var dir_name = _get_direction_name(direction)

	# маппинг правильных имён анимаций
	var anim_map = {
		"idle": "idle2",
		"walk": "walk",
		"run": "run",
		"attack": "attack",
		"attack2": "attack2",
		"attack3": "attack3",
		"stagger": "stagger",   # ← сюда
		"stagger2": "stagger2",
		"stagger3": "stagger3",
		"take_damage": "take_damage",
		"block": "block",
		"parry": "parry",
		"pummel": "pummel",
		"die": "die"
	}

	var mapped = anim_map.get(state, state)
	var anim_name = mapped + "_" + dir_name
	if anim.current_animation == anim_name and anim.is_playing():
		return
	# custom_speed, а не persistent anim.speed_scale — замедление действует
	# только на ЭТОТ конкретный проигрыш, не остаётся висеть на следующих
	# анимациях (idle/walk и т.п.), сбрасывать вручную не нужно
	anim.play(anim_name, -1, speed)


func _get_direction_name(dir: Vector2) -> String:
	if dir.length() < 0.1:
		dir = Vector2.DOWN

	var angle = dir.angle()
	var pi_8 = PI / 8.0

	if angle >= -pi_8 and angle < pi_8:
		return "right"
	elif angle >= pi_8 and angle < 3 * pi_8:
		return "down_right"
	elif angle >= 3 * pi_8 and angle < 5 * pi_8:
		return "down"
	elif angle >= 5 * pi_8 and angle < 7 * pi_8:
		return "down_left"
	elif angle >= 7 * pi_8 or angle < -7 * pi_8:
		return "left"
	elif angle >= -7 * pi_8 and angle < -5 * pi_8:
		return "up_left"
	elif angle >= -5 * pi_8 and angle < -3 * pi_8:
		return "up"
	else:
		return "up_right"
	
	

# ===================== ATTACK DAMAGE FIX =====================

func _on_attack_body_entered(body: Node2D) -> void:
	_try_hit_body(body)


# Основная логика попадания — вынесена из сигнала body_entered в отдельную
# функцию, потому что теперь вызывается из ДВУХ мест: из самого сигнала (для
# игрока, который заходит в зону хитбокса ПОСЛЕ его активации) и из прямого
# опроса get_overlapping_bodies() в _state_attack (для игрока, который уже
# стоял в зоне ДО активации — body_entered ловит только момент входа, а форма
# включается с задержкой в кадр через call_deferred, из-за чего этот случай
# мог остаться незамеченным движком)
func _try_hit_body(body: Node2D) -> void:
	if is_dead:
		return

	# атака не активна → урона нет
	if not attack_active:
		return

	# уже бил этого юнита в этой атаке
	if body in hit_targets:
		return

	if body.is_in_group("player"):
		if body.has_method("receive_attack"):
			var attack_data = {
				"damage": get_attack_damage(),
				"source": self
			}
			body.receive_attack(attack_data)
			hit_targets.append(body)  # ← добавь
			_play_enemy_sound(impact_audio, ENEMY_HIT_SOUND)


# ===================== HIT DAMAGE =====================

var knockback_velocity := Vector2.ZERO

func take_damage(amount: int, source: Node2D = null) -> void:
	if is_dead:
		return

	# Любой попавший удар выдаёт позицию атакующего — даже если это стрела
	# лучника, прилетевшая издалека, задолго до того, как враг физически
	# зашёл бы в VisionArea. Обычный ближний vision_range на это не рассчитан
	if source and is_instance_valid(source) and source.is_in_group("player"):
		player = source
		see_player = true
		if not is_ranged_alert and global_position.distance_to(source.global_position) > attack_range * 2.0:
			is_ranged_alert = true
			_alert_nearby_allies(source)

	# Безумие Берсерка — ломает защиту врага с первого удара: без блока, парирования и контратаки
	if is_player_berserk:
		is_parrying = false
		is_blocking = false
		health -= amount
		hp_bar.visible = true
		hp_bar.value = health
		_trigger_damage_flash()
		play_blood_vfx()
		_play_enemy_sound(voice_audio, ENEMY_HURT_SOUNDS.pick_random())

		if health <= 0:
			health = 0
			is_dead = true
			_change_state(State.DEAD)
		else:
			_trigger_stagger()

		if source and not is_dead:
			var knockback_dir := _safe_direction(global_position - source.global_position)
			knockback_velocity = knockback_dir * 150.0
		return

	# Парирование — если игрок ударил во время окна парирования
	if is_parrying:
		is_parrying = false
		if source and source.has_method("receive_parry"):
			source.receive_parry(pummel_posture_damage)
		_change_state(State.COUNTER)
		return
	
	# Проверяем блок
	if is_blocking and not is_posture_broken:
		posture += block_posture_damage
		posture_bar.visible = true
		posture_bar.value = posture
		posture_regen_timer = 0.0
		block_hit_count += 1

		if source:
			var knockback_dir := _safe_direction(global_position - source.global_position)
			knockback_velocity = knockback_dir * 80.0
			if source.has_method("play_block_hit_sound"):
				source.play_block_hit_sound()

		if posture >= max_posture:
			posture = max_posture
			_trigger_block_effect()
			_posture_break()
			return

		# рандомный шанс парировать именно этот удар — не зависит от того,
		# сколько ударов уже заблокировано, поэтому нет предсказуемого паттерна.
		# У парирования свой VFX (не искры блока), чтобы игрок видел разницу
		if randf() < parry_chance:
			play_parry_vfx()
			_start_parry()
			return

		_trigger_block_effect()
		return
	
	health -= amount
	hp_bar.visible = true
	hp_bar.value = health
	_trigger_damage_flash()
	play_blood_vfx()
	_play_enemy_sound(voice_audio, ENEMY_HURT_SOUNDS.pick_random())

	if health <= 0:
		health = 0
		is_dead = true
		_change_state(State.DEAD)
	else:
		# Стрела прилетела издалека — вместо того чтобы дальше стоять истуканом,
		# враг либо после стагера кидается на лучника (обычный переход
		# stagger → CHASE), либо, по шансу, вместо этого поднимает блок
		if is_ranged_alert:
			_pending_ranged_block = randf() < ranged_block_chance
		_change_state(State.HIT_STUN)

	if source and not is_dead:
		var knockback_dir := _safe_direction(global_position - source.global_position)
		knockback_velocity = knockback_dir * 150.0

func _try_block() -> void:
	if is_posture_broken or is_player_berserk:
		return
	if randf() < block_chance:
		is_blocking = true
		_change_state(State.BLOCK)

func _start_parry() -> void:
	if is_player_berserk:
		return
	is_blocking = false
	block_hit_count = 0
	_change_state(State.PARRY)
	# ждём удара игрока во время окна

func _state_block(delta: float) -> void:
	move_velocity = Vector2.ZERO
	var anim_name = "block_" + _get_direction_name(direction)
	if anim.current_animation != anim_name:
		anim.play(anim_name)

	# игрок ушёл из зоны — сразу выходим из блока. Для лучника зона — как у
	# погони (ranged_alert_range), иначе блок ломался тут же: враг вставал
	# в стойку блока, но лучник почти всегда дальше attack_range*2 (90px),
	# и следующим же кадром блок сбрасывался обратно в CHASE, так и не
	# успев ни разу заблокировать долетевшую стрелу
	var block_range := ranged_alert_range if is_ranged_alert else attack_range * 2.0
	if not player or not _is_player_in_range(block_range):
		_exit_block()
		return

	# держим блок, пока игрок реально атакует; как только перестал —
	# короткая задержка и выходим, чтобы враг не залипал в блоке
	if player.is_attacking:
		block_hold_timer = block_hold_time
	else:
		block_hold_timer -= delta
		if block_hold_timer <= 0.0:
			_exit_block()

func _exit_block() -> void:
	is_blocking = false
	block_hit_count = 0
	block_hold_timer = 0.0
	_change_state(State.CHASE)

func _posture_break() -> void:
	is_posture_broken = true
	is_blocking = false
	hit_stun_timer = 2.0
	_change_state(State.HIT_STUN)
	await get_tree().create_timer(3.0).timeout
	posture = 0.0
	posture_bar.value = 0.0
	posture_bar.visible = false
	is_posture_broken = false

func take_posture_damage(amount: float) -> void:
	posture += amount
	posture_bar.visible = true
	posture_bar.value = posture
	posture_regen_timer = 0.0
	_trigger_block_effect()  # VFX искр
	_trigger_stagger()       # ← добавь
	
	if posture >= max_posture:
		posture = max_posture
		_posture_break()

func _trigger_stagger() -> void:
	var stagger_name: String
	match current_attack_anim:
		"attack":  stagger_name = "stagger"
		"attack2": stagger_name = "stagger2"
		"attack3": stagger_name = "stagger3"
		_:         stagger_name = "stagger"
	
	_change_state(State.STAGGER)
	
	var anim_name = stagger_name + "_" + _get_direction_name(direction)
	anim.play(anim_name)
	
	if player:
		var knockback_dir := _safe_direction(global_position - player.global_position)
		knockback_velocity = knockback_dir * 200.0

func _state_stagger(_delta: float) -> void:
	move_velocity = Vector2.ZERO

func _state_parry(_delta: float) -> void:
	move_velocity = Vector2.ZERO
	var anim_name = "parry_" + _get_direction_name(direction)
	if anim.current_animation != anim_name:
		anim.play(anim_name)

func _state_counter(_delta: float) -> void:
	move_velocity = Vector2.ZERO
	var anim_name = "pummel_" + _get_direction_name(direction)
	if anim.current_animation != anim_name:
		anim.play(anim_name)
	# наносим урон по концентрации игрока — только если он реально в досягаемости
	# (иначе отброшенный/отбежавший враг стунил бы издалека)
	if attack_active and player and is_instance_valid(player) and _is_player_in_range(attack_range * 1.4):
		if player not in hit_targets:
			if player.has_method("receive_parry"):
				player.receive_parry(pummel_posture_damage)
				hit_targets.append(player)
				attack_active = false

# Телеграф атаки — раньше был ОСНОВНЫМ сигналом для тайминга (держался на
# пике весь замах), из-за чего парирование сводилось к "жди, пока цвет
# погаснет" — не имело значения, куда враг реально бьёт. Теперь тайминг
# читается по настоящей анимации замаха (она играет с самого входа в ATTACK,
# см. _change_state), а вспышка — лишь короткая приглушённая подсветка в
# начале, чтобы боковым зрением зацепить "враг начал действие". Она гаснет
# быстро и заведомо ДО того, как замах реально закончится — весь смысл в
# том, чтобы дальше игрок читал движение оружия, а не ждал цвет
@export var telegraph_color := Color(1.35, 1.1, 0.85, 1.0)
@export var telegraph_flash_time := 0.18

func _trigger_attack_telegraph(_windup_duration: float) -> void:
	if _telegraph_tween:
		_telegraph_tween.kill()
	var sp = $AnimatedSprite2D
	sp.modulate = telegraph_color
	sp.scale = _rest_scale
	_telegraph_tween = create_tween()
	_telegraph_tween.tween_property(sp, "modulate", _rest_modulate, telegraph_flash_time)


# Подчищает вспышку — вызывается либо когда хитбокс реально активировался
# (удар пошёл, см. _state_attack), либо когда атака прервалась раньше срока
# (см. _exit_attack). К этому моменту вспышка обычно уже сама погасла
# (telegraph_flash_time короче всего замаха), это просто гарантия, что
# ничего не зависло на середине
func _stop_attack_telegraph() -> void:
	if _telegraph_tween:
		_telegraph_tween.kill()
		_telegraph_tween = null
	var sp = $AnimatedSprite2D
	sp.scale = _rest_scale
	var tween = create_tween()
	tween.tween_property(sp, "modulate", _rest_modulate, 0.05)

func _trigger_block_effect() -> void:
	block_vfx.restart()
	block_vfx.emitting = true
	var sp = $AnimatedSprite2D
	sp.modulate = Color(2.0, 2.0, 0.5, 1.0)
	var tween = create_tween()
	tween.tween_property(sp, "modulate", _rest_modulate, 0.15)

func _trigger_damage_flash() -> void:
	var sp = $AnimatedSprite2D
	sp.material = CanvasItemMaterial.new()
	sp.modulate = Color(10.0, 10.0, 10.0, 1.0)  # экстремально яркий белый
	var tween = create_tween()
	tween.tween_property(sp, "modulate", _rest_modulate, 0.4)

func set_berserk_vulnerable(enabled: bool) -> void:
	is_player_berserk = enabled
	if enabled:
		is_blocking = false
		is_parrying = false
		is_countering = false

func set_berserk_highlight(enabled: bool) -> void:
	_rest_modulate = berserk_highlight_color if enabled else Color.WHITE
	var sp = $AnimatedSprite2D
	var tween = create_tween()
	tween.tween_property(sp, "modulate", _rest_modulate, 0.25)

# ===================== DEATH =====================
var death_handled := false

# Мгновенная казнь (Глаз Одина) — убивает независимо от блока/парирования
func execute_kill() -> void:
	if is_dead:
		return
	health = 0
	hp_bar.visible = true
	hp_bar.value = 0
	is_blocking = false
	is_parrying = false
	play_blood_vfx()
	is_dead = true
	_change_state(State.DEAD)

func _on_dead() -> void:
	if death_handled:
		return
	death_handled = true

	move_velocity = Vector2.ZERO
	anim.play("die_" + _get_direction_name(direction))
	_play_enemy_sound(death_audio, ENEMY_DEATH_SOUND)

	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if vision_area:
		vision_area.set_deferred("monitoring", false)

	_drop_coins()  # ← добавь

	await get_tree().create_timer(death_fade_time).timeout

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished

	queue_free()

func _drop_coins() -> void:
	if not coin_scene:
		return
	var count = randi_range(coin_drop_min, coin_drop_max)
	var spawn_pos = global_position
	for i in count:
		var coin = coin_scene.instantiate()
		coin.global_position = spawn_pos
		
		# 30% шанс что монетка "блестящая" с большим номиналом
		if randf() < 0.3:
			coin.coin_value = randi_range(10, 15)
			coin.is_big_coin = true
		else:
			coin.coin_value = 5
			coin.is_big_coin = false
		
		get_tree().current_scene.call_deferred("add_child", coin)

# ============== СИГНАЛЫ ==============
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("parry_"):
		is_parrying = false
		_change_state(State.COUNTER)
	elif anim_name.begins_with("pummel_"):
		is_countering = false
		_change_state(State.CHASE)
	elif anim_name.begins_with("stagger"):
		if _pending_ranged_block and not is_posture_broken and not is_player_berserk:
			_pending_ranged_block = false
			is_blocking = true
			_change_state(State.BLOCK)
		else:
			_pending_ranged_block = false
			_change_state(State.CHASE)
	elif anim_name.begins_with("attack") or anim_name.begins_with("attack2") or anim_name.begins_with("attack3"):
		if current_state == State.ATTACK:
			_exit_attack()
			if _is_player_in_range(attack_range):
				_change_state(State.IDLE)
			else:
				_change_state(State.CHASE)

func _on_vision_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):

		player = body
		see_player = true

func _on_vision_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):

		player = null
		see_player = false

func _on_hitbox_hit(body: Node2D) -> void:
	if is_dead:
		return
	if _is_player_attack(body):
		var dmg = _get_damage_from(body)
		take_damage(dmg, body) 

# ============== УТИЛИТЫ ==============

func _is_player_in_range(range_dist: float) -> bool:
	if not player:
		return false

	if not is_instance_valid(player):
		return false

	if is_dead:
		return false

	return (
		global_position.distance_to(
			player.global_position
		) <= range_dist
	)

func _is_player_attack(body: Node2D) -> bool:
	if body.is_in_group("player_attack"):
		return true

	var parent = body.get_parent()

	if parent and parent.is_in_group("player_attack"):
		return true

	return false

func _get_damage_from(body: Node2D) -> int:

	if body.has_meta("damage"):
		return int(body.get_meta("damage"))

	var parent = body.get_parent()

	if parent:

		if parent.has_meta("damage"):
			return int(parent.get_meta("damage"))

		if parent.has_method("get_damage"):
			return int(parent.call("get_damage"))

	if body.has_method("get_damage"):
		return int(body.call("get_damage"))
	return get_attack_damage()

func _play_enemy_sound(player_node: AudioStreamPlayer2D, stream: AudioStream) -> void:
	if stream == null:
		return
	player_node.stream = stream
	player_node.pitch_scale = enemy_pitch_down * randf_range(
		1.0 - enemy_pitch_variation, 1.0 + enemy_pitch_variation
	)
	player_node.play()


func _play_attack_sound() -> void:
	_play_enemy_sound(attack_audio, ENEMY_SWING_SOUND)
	if randf() < enemy_grunt_chance:
		_play_enemy_sound(voice_audio, ENEMY_GRUNT_SOUNDS.pick_random())


func _get_attack_dir_name(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func _update_attack_shape() -> void:
	# Хитбокс — как у игрока: одна форма, вынесенная вперёд по направлению
	# взгляда (непрерывный вектор, а не 8 хвостатых хитбоксов под фиксированные углы)
	if current_state == State.ATTACK or current_state == State.COUNTER:
		var dir_vec := direction.normalized()
		if dir_vec == Vector2.ZERO:
			dir_vec = Vector2.DOWN
		attack_hitbox.position = dir_vec * attack_hitbox_offset
		attack_shape.call_deferred("set", "disabled", false)
	else:
		attack_shape.call_deferred("set", "disabled", true)
