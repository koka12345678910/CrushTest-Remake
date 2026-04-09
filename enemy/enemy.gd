extends CharacterBody2D

@export var speed := 80
@export var max_health := 100
@export var attack_distance := 40
@export var attack_cooldown := 1.0
@export var spawn_invincible_time := 1.0

var health := max_health
var player = null
var see_player = false
var is_attacking := false
var is_dead := false
var attack_timer := 0.0
var current_attack := 1
var attack_dir := Vector2.ZERO
var spawn_timer := 0.0

var wander_timer := 0.0
var wander_dir := Vector2.ZERO
var is_wandering := false

const TAU = PI * 2
var attacks = {1: {"name": "attack", "damage": 10}, 2: {"name": "attack2", "damage": 25}}
@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("idle_right")
	$VisionArea.body_entered.connect(_on_enter)
	$VisionArea.body_exited.connect(_on_exit)
	$Hitbox.body_entered.connect(_on_hitbox_entered)
	current_attack = randi() % attacks.size() + 1
	spawn_timer = spawn_invincible_time

func _physics_process(delta):
	spawn_timer = max(0, spawn_timer - delta)
	if is_dead:
		_stop_movement()
		return
	if is_attacking:
		_stop_movement()
		return
	if not see_player or not player:
		_wander(delta)
		move_and_slide()
		return

	var dir_to_player = player.global_position - global_position
	var distance = dir_to_player.length()
	var dir = Vector2.RIGHT
	if distance != 0:
		dir = dir_to_player.normalized()

	if attack_timer > 0:
		attack_timer -= delta

	if distance <= attack_distance:
		velocity = Vector2.ZERO
		anim.play(_get_anim("idle2", dir))
		if attack_timer <= 0:
			_start_attack(dir)
			attack_timer = attack_cooldown
	elif distance < attack_distance * 0.8:
		_move(-dir * speed, _get_anim("walk", -dir))
	else:
		var vel = dir * speed
		var anim_name = _get_anim("walk", dir)
		if distance > attack_distance * 1.5:
			vel = dir * speed * 1.5
			anim_name = _get_anim("run", dir)
		_move(vel, anim_name)

	move_and_slide()

func _wander(delta):
	wander_timer -= delta
	if wander_timer <= 0:
		is_wandering = not is_wandering
		if is_wandering:
			wander_dir = Vector2(randf()*2-1, randf()*2-1).normalized()
			anim.play(_get_anim("walk", wander_dir))
		else:
			wander_dir = Vector2.ZERO
			anim.play("idle2")
		wander_timer = randf_range(0.5,1.5)

	if is_wandering:
		velocity = wander_dir * speed * 0.5
	else:
		velocity = Vector2.ZERO

func _move(vel, anim_name):
	velocity = vel
	anim.play(anim_name)

func _stop_movement():
	velocity = Vector2.ZERO
	move_and_slide()

func _on_enter(body):
	if body.is_in_group("player"):
		player = body
		see_player = true

func _on_exit(body):
	if body.is_in_group("player"):
		player = null
		see_player = false

func _on_hitbox_entered(body):
	if spawn_timer > 0:
		return
	if body.is_in_group("player_attack") and not is_dead:
		var dmg = 10
		if body.has_method("damage"):
			dmg = body.damage
		take_damage(dmg)

func _start_attack(dir: Vector2):
	is_attacking = true
	if dir.length() != 0:
		attack_dir = dir.normalized()
	else:
		attack_dir = Vector2.RIGHT
	anim.play(_get_anim(attacks[current_attack]["name"], attack_dir))
	var dmg = attacks[current_attack]["damage"]
	await get_tree().create_timer(0.3).timeout
	_deal_damage(dmg)
	await get_tree().create_timer(0.5).timeout
	_end_attack()

func _deal_damage(amount):
	if player and player.has_method("take_damage") and global_position.distance_to(player.global_position) <= attack_distance:
		player.take_damage(amount)

func _end_attack():
	is_attacking = false
	current_attack = randi() % attacks.size() + 1
	if player:
		var dir = player.global_position - global_position
		if dir.length() != 0:
			dir = dir.normalized()
		else:
			dir = Vector2.RIGHT
		anim.play(_get_anim("idle2", dir))

func take_damage(amount):
	if is_dead or spawn_timer > 0:
		return
	health -= amount
	if health <= 0:
		_die()
	elif player:
		var dir = player.global_position - global_position
		if dir.length() != 0:
			dir = dir.normalized()
		else:
			dir = Vector2.RIGHT
		anim.play(_get_anim("hit", dir))

func _die():
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	var dir = Vector2.RIGHT
	if player:
		dir = player.global_position - global_position
		if dir.length() != 0:
			dir = dir.normalized()
	anim.play(_get_anim("die", dir))
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	var anim_name = _get_anim("die", dir)
	var duration = anim.frames.get_frame_count(anim_name) / anim.frames.get_animation_speed(anim_name)
	await get_tree().create_timer(duration).timeout
	queue_free()

func _get_anim(state:String, dir:Vector2) -> String:
	return state + "_" + _dir8(dir)

func _dir8(dir:Vector2) -> String:
	var a = fposmod(dir.angle(), TAU)
	if a < PI/8 or a >= 15*PI/8: return "right"
	if a < 3*PI/8: return "down_right"
	if a < 5*PI/8: return "down"
	if a < 7*PI/8: return "down_left"
	if a < 9*PI/8: return "left"
	if a < 11*PI/8: return "up_left"
	if a < 13*PI/8: return "up"
	return "up_right"
