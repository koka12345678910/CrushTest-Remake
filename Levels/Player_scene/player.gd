extends CharacterBody2D

@export var walk_speed := 100.0
@export var run_speed := 200.0

@onready var anim: AnimationPlayer = $PlayerAnimation
@onready var gfx := $PlayerAnim

var input_vector := Vector2.ZERO
var is_running := false
var last_direction := "Down"

var is_attacking := false
var is_run_attacking := false
var attack_velocity := Vector2.ZERO
var friction := 3.0

# --- COMBO SYSTEM ---
var combo_step := 0
var combo_timer := 0.0
var combo_window := 0.4
var combo_queued := false
# --------------------

var normal_scale := Vector2(0.5, 0.5)
var ladder_scale := Vector2(0.65, 0.65)


func _ready() -> void:
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)


func _physics_process(delta):
	# --- ввод ---
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")

	handle_attack_input()

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
	var speed = walk_speed
	if is_running:
		speed = run_speed

	velocity = input_vector.normalized() * speed
	move_and_slide()

	if input_vector != Vector2.ZERO:
		last_direction = get_direction(input_vector)
		play_movement_animation()
	else:
		play_idle_animation()


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


func play_movement_animation():
	var anim_name = ""
	if is_running:
		anim_name = "Run_" + last_direction
	else:
		anim_name = "Walk_" + last_direction
	anim.play(anim_name)

func play_idle_animation():
	anim.play("Idle_" + last_direction)


# ----------------------------------------------------------
# АТАКИ / COMBO / RUN ATTACK / DASH
# ----------------------------------------------------------

func handle_attack_input():
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

	var anim_name := ""

	if step == 1:
		anim_name = "Attack_" + last_direction
	elif step == 2:
		anim_name = "Attack_2_" + last_direction
	elif step == 3:
		anim_name = "Attack_3_" + last_direction
	elif step == 4:
		anim_name = "Attack_4_" + last_direction

	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return

	anim.play(anim_name)

	# --- микро-рывок вперёд после удара ---
	attack_velocity = direction_to_vector(last_direction) * 150  # сила рывка подбирается


func start_run_attack():
	is_run_attacking = true
	is_attacking = true

	var anim_name = "Run_Attack_" + last_direction

	if not anim.has_animation(anim_name):
		print("⚠ Нет анимации: ", anim_name)
		reset_all_states()
		return

	anim.play(anim_name)

	# задаём скорость для скольжения
	attack_velocity = input_vector.normalized() * 250


# ----------------------------------------------------------
# ЗАВЕРШЕНИЕ
# ----------------------------------------------------------

func _on_anim_finished(finished_anim: StringName) -> void:
	# --- RUN ATTACK ---
	if finished_anim.begins_with("Run_Attack"):
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
