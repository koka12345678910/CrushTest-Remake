extends CharacterBody2D

# ============== ПАРАМЕТРЫ ==============

# Движение
@export var walk_speed := 60.0
@export var run_speed := 100.0
@export var friction := 500.0
@export var direction_smoothness := 8.0
@onready var shapes := {
	"left": $Hitbox/Atack_hitbox/left,
	"left_up": $Hitbox/Atack_hitbox/left_up,
	"left_down": $Hitbox/Atack_hitbox/left_down,
	"right": $Hitbox/Atack_hitbox/right,
	"right_up":$Hitbox/Atack_hitbox/right_up,
	"right_down":$Hitbox/Atack_hitbox/right_down,
	"up": $Hitbox/Atack_hitbox/up,
	"down": $Hitbox/Atack_hitbox/down,
	
}

# Здоровье
@export var max_health := 3
@export var damage_flash_time := 0.15

# Боевые параметры
@export var attack_range := 40.0
@export var attack_cooldown := 1.5
@export var attack_damage := 1
@export var attack_duration := 0.5
@onready var attack_hitbox: Area2D = $Hitbox/Atack_hitbox

# Визуальные эффекты
@export var damage_flash_color := Color(1.5, 1.5, 1.5, 1.0)

# AI поведение
@export var vision_range := 150.0
@export var chase_range := 120.0
@export var think_rate := 0.25
@export var wander_speed_multiplier := 0.6

# Смерть
@export var death_fade_time := 0.8

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	HIT_STUN,
	DEAD
}

# ============== ПЕРЕМЕННЫЕ ==============

var health := 0
var is_dead := false

var current_state := State.IDLE
var state_time := 0.0

var player: Node2D = null
var see_player := false

var direction := Vector2.DOWN
var move_velocity := Vector2.ZERO


var hit_targets := []

var attack_cooldown_timer := 0.0
var hit_stun_timer := 0.0
var think_timer := 0.0
var can_attack := true

var wander_direction := Vector2.DOWN
var wander_timer := 0.0

var last_anim_direction := "down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_area: Area2D = $VisionArea
@onready var hitbox: Area2D = $Hitbox

# ============== READY ==============

func _ready() -> void:
	randomize()

	health = max_health
	attack_hitbox.body_entered.connect(_on_attack_body_entered)

	add_to_group("enemy")
	
	if vision_area:
		vision_area.body_entered.connect(_on_vision_body_entered)
		vision_area.body_exited.connect(_on_vision_body_exited)

	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_hit)
		hitbox.body_entered.connect(_on_hitbox_hit)

	wander_timer = randf_range(2.0, 4.0)

	_change_state(State.IDLE)

# ============== PHYSICS ==============

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	state_time += delta
	think_timer += delta

	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)
	hit_stun_timer = max(0.0, hit_stun_timer - delta)

	if attack_cooldown_timer <= 0.0:
		can_attack = true

	# НЕ думаем во время атаки/стана/смерти
	if current_state not in [
		State.ATTACK,
		State.HIT_STUN,
		State.DEAD
	]:
		if think_timer >= think_rate:
			think_timer = 0.0
			_decide_state()

	_update_state(delta)

	move_velocity = move_velocity.move_toward(
		Vector2.ZERO,
		friction * delta
	)

	velocity = move_velocity

	move_and_slide()

# ============== AI ==============

func _decide_state() -> void:
	if current_state in [
		State.DEAD,
		State.HIT_STUN,
		State.ATTACK
	]:
		return

	if player and is_instance_valid(player):

		if _is_player_in_range(vision_range):

			var dist = global_position.distance_to(
				player.global_position
			)

			if dist <= attack_range and can_attack:
				_change_state(State.ATTACK)

			elif dist <= chase_range:
				_change_state(State.CHASE)

			else:
				_change_state(State.WANDER)

		else:
			_change_state(State.WANDER)

	else:
		_change_state(State.WANDER)

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

		State.DEAD:
			pass

# ============== STATE MACHINE ==============

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_time = 0.0

	match new_state:

		State.IDLE:
			move_velocity = Vector2.ZERO

		State.WANDER:
			wander_timer = randf_range(2.0, 4.0)

		State.CHASE:
			pass

		State.ATTACK:
			move_velocity = Vector2.ZERO

			if player:
				direction = (player.global_position - global_position).normalized()

			can_attack = false
			hit_targets.clear()
			
			_update_attack_shape()

		State.HIT_STUN:
			move_velocity = Vector2.ZERO
			hit_stun_timer = 0.4

		State.DEAD:
			_on_dead()

# ============== СОСТОЯНИЯ ==============

func _state_idle(_delta: float) -> void:
	move_velocity = Vector2.ZERO

	_play_animation("idle")

func _state_wander(delta: float) -> void:
	wander_timer -= delta

	if wander_timer <= 0.0:

		wander_direction = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		if wander_direction == Vector2.ZERO:
			wander_direction = Vector2.DOWN

		wander_timer = randf_range(2.0, 4.0)

	var speed = walk_speed * wander_speed_multiplier

	direction = direction.lerp(
		wander_direction,
		direction_smoothness * delta
	).normalized()

	move_velocity = direction * speed

	_play_animation("walk")

func _state_chase(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_change_state(State.WANDER)
		return

	if not _is_player_in_range(vision_range):
		_change_state(State.WANDER)
		return

	var chase_dir = (
		player.global_position - global_position
	).normalized()

	var dist = global_position.distance_to(
		player.global_position
	)

	var speed = (
		run_speed
		if dist > chase_range * 0.6
		else walk_speed
	)

	var anim = (
		"run"
		if dist > chase_range * 0.6
		else "walk"
	)

	# СГЛАЖИВАНИЕ НАПРАВЛЕНИЯ
	direction = direction.lerp(
		chase_dir,
		direction_smoothness * delta
	).normalized()

	move_velocity = direction * speed

	_play_animation(anim)

func _state_attack(_delta: float) -> void:
	move_velocity = Vector2.ZERO

	_play_animation("attack")

	_update_attack_shape()

	if state_time >= attack_duration:

		for s in shapes.values():
			s.disabled = true

		hit_targets.clear()
		attack_cooldown_timer = attack_cooldown

		if player and _is_player_in_range(attack_range):
			_change_state(State.IDLE)
		else:
			_change_state(State.CHASE)

func _state_hit_stun(_delta: float) -> void:
	move_velocity = Vector2.ZERO

	_play_animation("hit")

	if hit_stun_timer <= 0.0:
		_change_state(State.CHASE)

# ============== АНИМАЦИИ ==============

func _play_animation(state: String) -> void:
	var dir_name = _get_direction_name(direction)

	# Защита от дёргания
	if dir_name != last_anim_direction:
		last_anim_direction = dir_name

	var anim_name = state + "_" + last_anim_direction

	if sprite.animation != anim_name:
		sprite.play(anim_name)

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

# ============== УРОН ==============

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount

	_trigger_damage_flash()

	if health <= 0:

		health = 0
		is_dead = true

		_change_state(State.DEAD)

	else:
		_change_state(State.HIT_STUN)


func _trigger_damage_flash() -> void:
	if not sprite:
		return

	sprite.modulate = damage_flash_color

	var tween = create_tween()

	tween.tween_property(
		sprite,
		"modulate",
		Color.WHITE,
		damage_flash_time
	)
	
func _on_attack_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body in hit_targets:
		return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			hit_targets.append(body)


func apply_damage_from_hitbox(body: Node) -> void:
	if is_dead:
		return

	var dmg := 0

	if body.has_method("get_damage"):
		dmg = body.get_damage()
	elif body.has_meta("damage"):
		dmg = int(body.get_meta("damage"))
	else:
		return

	take_damage(dmg)
# ============== СМЕРТЬ ==============

func _on_dead() -> void:
	move_velocity = Vector2.ZERO

	sprite.play(
		"death_" + _get_direction_name(direction)
	)

	if hitbox:
		hitbox.set_deferred("monitoring", false)

	if vision_area:
		vision_area.set_deferred("monitoring", false)

	await get_tree().create_timer(
		death_fade_time
	).timeout

	var tween = create_tween()

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.5
	)

	await tween.finished

	queue_free()

# ============== СИГНАЛЫ ==============

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

		take_damage(dmg)

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

	return attack_damage
	
func _get_attack_dir_name(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"


func _update_attack_shape() -> void:
	var dir_name = _get_attack_dir_name(direction)

	for key in shapes.keys():
		shapes[key].disabled = true

	if shapes.has(dir_name):
		shapes[dir_name].disabled = false
