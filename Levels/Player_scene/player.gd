extends CharacterBody2D

@export var walk_speed := 100.0
@export var run_speed := 200.0

@export var max_health := 100
var health := max_health
var invulnerable := false

@onready var anim: AnimationPlayer = $PlayerAnimation
@onready var gfx := $PlayerAnim

var input_vector := Vector2.ZERO
var is_running := false
var last_direction := "Down"
var is_attacking := false

var normal_scale := Vector2(0.5, 0.5)
var ladder_scale := Vector2(0.65, 0.65)

func _ready() -> void:
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

func _physics_process(_delta):
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")

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

	handle_attack_input()

# ----------------------------------------------------------
# НАПРАВЛЕНИЯ И ДВИЖЕНИЕ
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

func play_movement_animation():
	# Plays run/walk with safe fallback if exact direction clip is missing.
	var prefix = "Run_" if is_running else "Walk_"
	_play_directional_animation(prefix, last_direction)

func play_idle_animation():
	# Plays idle with directional fallback to stop animation-not-found spam.
	_play_directional_animation("Idle_", last_direction)

# ----------------------------------------------------------
# АТАКИ
# ----------------------------------------------------------

func handle_attack_input():
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack(1)

	if Input.is_action_just_pressed("strong_attack") and not is_attacking:
		start_attack(2)

func start_attack(stage: int) -> void:
	# Selects attack animation with fallback for missing directional clips.
	is_attacking = true

	var prefix := "Attack_" if stage == 1 else "Attack_2_"
	var anim_name := _resolve_directional_animation(prefix, last_direction)
	if anim_name == "":
		print("Нет анимации: ", anim_name)
		is_attacking = false
		return

	anim.play(anim_name)

func _on_anim_finished(finished_anim: StringName) -> void:
	if not finished_anim.begins_with("Attack"):
		return

	is_attacking = false
	play_idle_animation()

# ----------------------------------------------------------
# УРОН
# ----------------------------------------------------------

func take_damage(amount):
	# Applies damage and plays hit animation with safe directional fallback.
	if invulnerable:
		return

	health -= amount
	print("HP:", health)

	invulnerable = true
	
	var t = create_tween()
	t.tween_interval(0.3)
	t.finished.connect(func(): invulnerable = false)

	var hit_anim = _resolve_directional_animation("Hit_", last_direction)
	if hit_anim != "":
		anim.play(hit_anim)

	if health <= 0:
		die()

func die():
	is_attacking = true
	velocity = Vector2.ZERO

	if anim.has_animation("Death"):
		anim.play("Death")
	else:
		queue_free()

# ----------------------------------------------------------
# ЗОНА (твоя логика масштабирования)
# ----------------------------------------------------------

func _on_area_2d_body_entered(body):
	if body == self:
		var t = create_tween()
		t.tween_property(gfx, "scale", ladder_scale, 0.4)

func _on_area_2d_body_exited(body: Node2D):
	if body == self:
		var t = create_tween()
		t.tween_property(gfx, "scale", normal_scale, 0.2)

func _play_directional_animation(prefix: String, direction: String) -> void:
	# Tries to play directional animation only when a valid clip exists.
	var anim_name = _resolve_directional_animation(prefix, direction)
	if anim_name != "":
		anim.play(anim_name)

func _resolve_directional_animation(prefix: String, direction: String) -> String:
	# Resolves missing diagonals to nearest existing animation variant.
	var candidate = prefix + direction
	if anim.has_animation(candidate):
		return candidate
	match direction:
		"Up_Right":
			if anim.has_animation(prefix + "Up"):
				return prefix + "Up"
			if anim.has_animation(prefix + "Right"):
				return prefix + "Right"
		"Up_Left":
			if anim.has_animation(prefix + "Up"):
				return prefix + "Up"
			if anim.has_animation(prefix + "Left"):
				return prefix + "Left"
		"Down_Right":
			if anim.has_animation(prefix + "Down"):
				return prefix + "Down"
			if anim.has_animation(prefix + "Right"):
				return prefix + "Right"
		"Down_Left":
			if anim.has_animation(prefix + "Down"):
				return prefix + "Down"
			if anim.has_animation(prefix + "Left"):
				return prefix + "Left"
	return ""
