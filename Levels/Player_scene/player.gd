extends CharacterBody2D

@export var walk_speed := 100.0
@export var run_speed := 200.0
@export var hit_vfx_scene: PackedScene
@export var running_hit_vfx_scene: PackedScene
@export var move_start_vfx_scene: PackedScene
@export var melee_hit_vfx_scene: PackedScene
@export var melee_hit_2_vfx_scene: PackedScene
@export var turn_around_vfx_scene: PackedScene

@onready var melee_hit = $MeleeHit
@onready var weapon_tip := $WeaponTip
@onready var anim: AnimationPlayer = $PlayerAnimation
@onready var gfx := $PlayerAnim
@onready var foot_point = $FootPoint
@onready var foot_point2 = $FootPoint2

var prev_velocity := Vector2.ZERO
var move_vfx_cooldown := 0.0
var input_vector := Vector2.ZERO
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

var normal_scale := Vector2(0.5, 0.5)
var ladder_scale := Vector2(0.65, 0.65)

var is_starting := true

func _ready() -> void:
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)
		
	anim.play("Started_" + last_direction)
	print(anim.get_animation_list())
	
func _physics_process(delta):
	if is_starting:
		return
	if is_rolling:
		handle_roll(delta)
		return
	prev_velocity = velocity
	# --- ввод ---
	if not is_rolling:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")
	
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
		
	handle_attack_input()
	handle_kick_input()
	handle_dodge_input()
	check_for_turn()
	if is_rolling:
		roll_control += delta
		# 🔥 фаза ускорения и торможения
		var t: float = clamp(roll_control / roll_duration, 0.0, 1.0) as float
		var speed_multiplier := sin(t * PI)  # плавная кривая
		dodge_velocity = roll_dir * roll_speed * speed_multiplier
		velocity = dodge_velocity
		move_and_slide()
		return

	if is_dodging:
		dodge_velocity = dodge_velocity.lerp(Vector2.ZERO, dodge_friction * delta)
		velocity = dodge_velocity
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

	# --- обычное движение ---
	var target_speed = walk_speed
	if is_running:
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

func check_for_turn():
	if input_vector == Vector2.ZERO:
		return
	if turn_lock:
		return

	var input_dir = input_vector.normalized()

	# если почти противоположное направление
	if input_dir.dot(facing_dir) < -0.7:
		start_turn(input_dir)

func start_turn(new_dir: Vector2):
	turn_lock = true
	is_turning = true

	var old_dir = facing_dir
	var new_facing = new_dir.normalized()

	# фиксируем новое направление заранее (как в Hades)
	facing_dir = new_facing
	last_direction = get_direction(new_facing)

	# стоп движения (важно для feel)
	turn_velocity = velocity * 0.4

	# анимация
	var anim_name = "Turn_" + last_direction
	if anim.has_animation(anim_name):
		anim.play(anim_name)

	play_turn_vfx(old_dir, new_facing)

func start_roll():
	if is_rolling:
		return
	roll_control = 0.0
	is_rolling = true
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
	if is_dodging or is_rolling:
		return
	is_dodging = true
	
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

func start_i_frames():
	await get_tree().create_timer(i_frame_time).timeout
	is_invulnerable = false

func interrupt_all_actions():
	is_attacking = false
	is_run_attacking = false
	is_turning = false
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

func handle_attack_input():
	if is_dodging or is_rolling:
		return
	
	if Input.is_action_just_pressed("attack"):

		# --- RUN ATTACK ---
		if is_running and input_vector != Vector2.ZERO and not is_attacking and not is_run_attacking:
			start_run_attack()
			return

		# --- COMBO ---
		if is_attacking:
			combo_queued = true
		elif not is_run_attacking:
			start_combo()

func start_combo():
	combo_step = 1
	play_attack(combo_step)

func play_attack(step: int):
	is_attacking = true
	combo_timer = combo_window
	combo_queued = false
	dodge_velocity = Vector2.ZERO
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
	
	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return

	anim.play(anim_name)

	# --- микро-рывок вперёд после удара ---
	attack_velocity = direction_to_vector(last_direction) * 150  # сила рывка подбирается

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
	anim.play(anim_name)
	# задаём скорость для скольжения
	attack_velocity = input_vector.normalized() * 250

func update_weapon_tip():
	var dir = direction_to_vector(last_direction)
	var offset = 35  # подгони под свою анимацию
	weapon_tip.position = dir * offset

func melee_weapon_tip():
	var dir = direction_to_vector(last_direction)
	var offset = 35  # подгони под свою анимацию
	
	melee_hit.position = dir * offset

func play_hit_vfx():
	if hit_vfx_scene == null:
		print("⚠ VFX не назначен")
		return
		
	var vfx = hit_vfx_scene.instantiate()
	vfx.global_position = weapon_tip.global_position
	
	var dir = direction_to_vector(last_direction)

	# передаём направление
	vfx.set("move_direction", dir)
	vfx.rotation = dir.angle()  # 👈 ВОТ ЭТО НОВОЕ
	
	get_tree().current_scene.add_child(vfx)


func play_melee_hit_vfx():
	if melee_hit_vfx_scene == null:
		print("⚠ VFX не назначен")
		return
		
	var vfx_melee = melee_hit_vfx_scene.instantiate()
	vfx_melee.global_position = melee_hit.global_position
	
	var dir = direction_to_vector(last_direction)

	# передаём направление
	vfx_melee.set("move_direction", dir)
	vfx_melee.rotation = dir.angle()  # 👈 ВОТ ЭТО НОВОЕ
	
	get_tree().current_scene.add_child(vfx_melee)

func play_melee_2_hit_vfx():
	if melee_hit_2_vfx_scene == null:
		print("⚠ VFX не назначен")
		return
		
	var vfx_melee2 = melee_hit_2_vfx_scene.instantiate()
	vfx_melee2.global_position = melee_hit.global_position
	
	var dir = direction_to_vector(last_direction)

	# передаём направление
	vfx_melee2.set("move_direction", dir)
	vfx_melee2.rotation = dir.angle()  # 👈 ВОТ ЭТО НОВОЕ
	
	get_tree().current_scene.add_child(vfx_melee2)

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
	if finished_anim.begins_with("Started_"):
		is_starting = false
		play_idle_animation()
		return
	# --- DODGE SYSTEM ---
	if finished_anim.begins_with("Dodge_"):
		is_dodging = false
		dodge_velocity = Vector2.ZERO
		velocity = velocity.lerp(input_vector * walk_speed, 0.2)
		return
	if finished_anim.begins_with("Rolling_"):
		is_rolling = false
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
	# --- COMBO ---
	if not finished_anim.begins_with("Attack"):
		return
	
	if combo_queued and combo_step < 4:  # теперь до 4 шагов
		combo_step += 1
		play_attack(combo_step)
	else:
		reset_combo()

func reset_combo():
	is_attacking = false
	combo_step = 0
	combo_queued = false
	play_idle_animation()

func reset_all_states():
	is_attacking = false
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	play_idle_animation()

# ----------------------------------------------------------
# SCALE
# ----------------------------------------------------------

func _on_area_2d_body_entered(body) -> void:
	if body == self:
		var t = create_tween()
		t.tween_property(gfx, "scale", ladder_scale, 0.4)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == self:
		var t = create_tween()
		t.tween_property(gfx, "scale", normal_scale, 0.2)
