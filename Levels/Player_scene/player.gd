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
	var anim_name = ""
	if is_running:
		anim_name = "Run_" + last_direction
	else:
		anim_name = "Walk_" + last_direction

	anim.play(anim_name)

func play_idle_animation():
	anim.play("Idle_" + last_direction)

# ----------------------------------------------------------
# АТАКИ
# ----------------------------------------------------------

func handle_attack_input():
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack(1)

	if Input.is_action_just_pressed("strong_attack") and not is_attacking:
		start_attack(2)

func start_attack(stage: int) -> void:
	is_attacking = true

	var anim_name := ""

	if stage == 1:
		anim_name = "Attack_" + last_direction
	else:
		anim_name = "Attack_2_" + last_direction

	if not anim.has_animation(anim_name):
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
	if invulnerable:
		return

	health -= amount
	print("HP:", health)

	invulnerable = true
	
	var t = create_tween()
	t.tween_interval(0.3)
	t.finished.connect(func(): invulnerable = false)

	# (опционально) анимация получения урона
	if anim.has_animation("Hit_" + last_direction):
		anim.play("Hit_" + last_direction)

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
