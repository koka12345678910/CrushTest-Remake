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
@onready var swing_audio: AudioStreamPlayer2D = $SwingAudio
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio
@onready var voice_audio: AudioStreamPlayer2D = $VoiceAudio
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var block_audio: AudioStreamPlayer2D = $BlockAudio
@onready var parry_audio: AudioStreamPlayer2D = $ParryAudio

# Замах (whoosh) — играется всегда при ударе
const SWING_SOUND := preload("res://Sound/melee_sound/swing.mp3")
const RUN_SWING_SOUND := preload("res://Sound/melee_sound/running_attack_swing.wav")
# Попадание по врагу — свой звук в зависимости от удара серии
const HIT_1_SOUND := preload("res://Sound/melee_sound/hit.mp3")          # 1-й удар
const HIT_REST_SOUND := preload("res://Sound/melee_sound/hit2.wav")      # 2-й и 3-й удары
const RUN_HIT_SOUND := preload("res://Sound/melee_sound/running_attack_hit.wav")  # удар на бегу
# Выхватывание меча — на старте игры
const UNSHEATH_SOUND := preload("res://Sound/melee_sound/unsneath_sword.wav")
# Боевые вскрики — вместе с замахом, по номеру удара серии
const GRUNT_1_SOUND := preload("res://Sound/groaning_sound/attack1.mp3")
const GRUNT_2_SOUND := preload("res://Sound/groaning_sound/attack2.mp3")
const GRUNT_3_SOUND := preload("res://Sound/groaning_sound/attack3.mp3")
const GRUNT_RUN_SOUND := preload("res://Sound/groaning_sound/running_attack.mp3")
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
var _hitstop_token := 0
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
var parry_window := 0.2     # секунды активного окна
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
	
	anim.play("Started_" + last_direction)
	# Выхватывание меча из ножен в начале игры
	swing_audio.stream = UNSHEATH_SOUND
	swing_audio.play()
	print(anim.get_animation_list())
	add_to_group("player")
	player_hitbox.add_to_group("player_attack")
	player_hitbox.set_meta("damage", attack_damage)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
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
	
	# Блокируем всё кроме инвентаря если он открыт
	if inventory_ui.visible:
		if event.is_action_pressed("ui_cancel"):
			inventory_ui.close()
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
		if inventory_ui.visible:
			inventory_ui.close()
		else:
			inventory_ui.open()

func _physics_process(delta):
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
	if is_taking_damage or is_parrying:
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
		use_stamina(20.5)
		attack_velocity = attack_velocity.lerp(Vector2.ZERO, friction * delta)
		velocity = attack_velocity
		move_and_slide()
		return

	# --- обычная атака с микро-рывком ---
	if is_attacking:
		combo_timer -= delta
		
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
	if is_running:
		use_stamina(15.0 * delta)
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
		if not is_instance_valid(enemy):
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
	if not use_stamina(30.0):
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
		anim.play("Idle_" + last_direction)
		return
	elif speed < 120:
		anim_name = "Walk_" + last_direction
	else:
		anim_name = "Run_" + last_direction

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
	if not use_stamina(20.0):
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
		footstep_audio.play()
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
	if parry_cd_timer > 0:
		parry_cd_timer -= delta
		return
	# just_pressed ПЕРВЫМ — иначе pressed перехватывает
	if Input.is_action_just_pressed("parry"):
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
	# Во время уворота И переката игрок неуязвим — иначе его бьёт посреди
	# переката и анимация take_damage проигрывается поверх движения.
	# (то же условие, что и в _on_hurtbox_area_entered — держим их синхронно)
	if is_invulnerable or is_dodging or is_rolling:
		return false

	# --- PERFECT PARRY ---
	if is_parrying:
		end_parry(true)
		on_perfect_parry(attack_data)
		return true

	# --- ОБЫЧНЫЙ УРОН ---
	take_damage(attack_data.get("damage", 10), attack_data.get("source", null))
	return true

func play_parry_vfx() -> void:
	parry_vfx.global_position = melee_hit.global_position
	parry_vfx.play("parry_vfx")
	await parry_vfx.animation_finished
	parry_vfx.stop()

func on_perfect_parry(attack_data: Dictionary):
	can_counter = true
	counter_timer = counter_window
	play_parry_vfx()
	parry_audio.stream = PARRY_SOUND
	parry_audio.play()
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
	use_stamina(10.0)
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
	swing_audio.stream = SWING_SOUND
	swing_audio.play()

	# Боевой вскрик — свой на каждый из первых трёх ударов, 4-й (вихрь) — без вскрика
	var grunt: AudioStream = null
	match step:
		1: grunt = GRUNT_1_SOUND
		2: grunt = GRUNT_2_SOUND
		3: grunt = GRUNT_3_SOUND
	if grunt:
		voice_audio.stream = grunt
		voice_audio.play()

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
	swing_audio.stream = RUN_SWING_SOUND
	swing_audio.play()
	voice_audio.stream = GRUNT_RUN_SOUND
	voice_audio.play()
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
	for e: Node2D in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) > spin_radius:
			continue
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
	
	if combo_queued and combo_step < 4:  # теперь до 4 шагов
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

func start_heal_over_time(amount_per_tick: float, interval: float, ticks: int) -> void:
	for i in ticks:
		await get_tree().create_timer(interval * i).timeout
		if is_instance_valid(self):
			heal(amount_per_tick)

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

func is_dead() -> bool:
	return health <= 0.0

func _on_player_dead() -> void:
	# TODO: анимация смерти, game over
	print("[Player] Умер")

# ============== ENABLE/DISABLE HITBOX ==============

func enable_attack_hitbox() -> void:
	hit_targets.clear()  # ← сброс перед каждым ударом
	player_hitbox.monitoring = true
	player_hitbox.get_child(0).disabled = false

func disable_attack_hitbox() -> void:
	player_hitbox.monitoring = false
	if player_hitbox.get_child(0):
		player_hitbox.get_child(0).disabled = true

func _on_player_hitbox_area_entered(area: Area2D) -> void:
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
		_play_hit_sound()
		do_hitstop()

func do_hitstop() -> void:
	# Замораживаем время на пару кадров. Таймер с ignore_time_scale=true
	# продолжает идти в реальном времени, поэтому разморозка сработает.
	# Токен защищает от наложения нескольких попаданий в один кадр:
	# время восстанавливает только самый последний вызов.
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = hitstop_scale
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func _play_hit_sound() -> void:
	var snd: AudioStream = null
	if is_run_attacking:
		snd = RUN_HIT_SOUND
	elif combo_step == 1:
		snd = HIT_1_SOUND
	elif combo_step == 2 or combo_step == 3:
		snd = HIT_REST_SOUND
	# 4-й удар (вихрь) — без звука попадания
	if snd:
		hit_audio.stream = snd
		hit_audio.play()

func play_block_hit_sound() -> void:
	block_audio.stream = BLOCK_HIT_SOUND
	block_audio.play()

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
	is_invulnerable = true
	is_stunned = true
	_trigger_damage_flash()
	
	anim.play("Stunned_" + last_direction)
	
	if current_posture >= max_posture:
		# концентрация полная — долгий стан 5 секунд
		is_invulnerable = false  # ← игрок открыт для урона
		await get_tree().create_timer(4.0).timeout
		is_stunned = false
		_posture_break()
	else:
		# pummel — ждём конца анимации stunned
		is_invulnerable = false  # ← тоже открыт
		await anim.animation_finished
		is_stunned = false
