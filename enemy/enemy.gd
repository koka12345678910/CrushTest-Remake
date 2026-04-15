extends CharacterBody2D

@export var speed := 80
@export var run_speed_multiplier := 1.45
@export var max_health := 5 # Enemy HP: change this number to increase/decrease health.
@export var attack_distance := 40
@export var strafe_distance := 120
@export var attack_cooldown := 1.0
@export var attack_cooldown_random := 0.25
@export var spawn_invincible_time := 1.0
@export var low_health_ratio := 0.35
@export var separation_radius := 60.0
@export var separation_strength := 0.85
@export var strafe_chance := 0.35
@export var min_move_speed := 45.0
@export var max_move_speed := 85.0
@export var acceleration := 720.0
@export var deceleration := 860.0
@export var behavior_update_interval := 0.22
@export var hit_reaction_time := 0.22
@export var death_anim_speed_scale := 0.7
@export var death_linger_time := 1.0
@export var death_fade_time := 0.8

var health := 10
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
var strafe_sign := 1.0
var facing_dir := Vector2.RIGHT
var personal_speed := 80.0
var prefer_attack := 1
var attack_streak := 0
var desired_velocity := Vector2.ZERO
var behavior_timer := 0.0
var use_strafe := false
var hit_reaction_timer := 0.0

const TAU = PI * 2
const PREDICT_TIME := 0.45
var attacks = {1: {"name": "attack", "damage": 1}, 2: {"name": "attack2", "damage": 5}} # Enemy attack damage values.
@onready var anim = $AnimatedSprite2D

func _ready():
	health = max_health
	add_to_group("enemy_ai")
	personal_speed = clampf(speed * randf_range(0.8, 1.05), min_move_speed, max_move_speed)
	anim.play("idle_right")
	$VisionArea.body_entered.connect(_on_enter)
	$VisionArea.body_exited.connect(_on_exit)
	$Hitbox.body_entered.connect(_on_hitbox_entered)
	$Hitbox.area_entered.connect(_on_hitbox_entered)
	current_attack = randi() % attacks.size() + 1
	prefer_attack = current_attack
	spawn_timer = spawn_invincible_time
	strafe_sign = -1.0 if (get_instance_id() % 2 == 0) else 1.0

func _physics_process(delta):
	spawn_timer = max(0, spawn_timer - delta)
	behavior_timer -= delta
	hit_reaction_timer = max(0.0, hit_reaction_timer - delta)
	if is_dead:
		_stop_movement()
		return
	if hit_reaction_timer > 0.0:
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
		facing_dir = dir

	if attack_timer > 0:
		attack_timer -= delta

	if distance <= attack_distance:
		desired_velocity = Vector2.ZERO
		_play_anim_safe(_get_anim("idle2", facing_dir))
		if attack_timer <= 0:
			_start_attack(dir)
			attack_timer = _next_attack_cooldown()
	elif _is_low_health() and distance < attack_distance * 1.5:
		var retreat = (-dir + _avoid_allies()).normalized()
		_move(retreat * personal_speed, _get_anim("walk", retreat))
	elif distance <= strafe_distance and _should_strafe():
		var tangent = dir.rotated(PI * 0.5 * strafe_sign)
		var strafing = (tangent + dir * 0.45 + _avoid_allies()).normalized()
		_move(strafing * personal_speed * 0.85, _get_anim("walk", strafing))
	else:
		var predicted_pos = _predict_player_position()
		var chase_dir = (predicted_pos - global_position).normalized()
		if chase_dir == Vector2.ZERO:
			chase_dir = dir
		var separation = _avoid_allies()
		var final_dir = (chase_dir + separation).normalized()
		if final_dir == Vector2.ZERO:
			final_dir = chase_dir
		var vel = final_dir * personal_speed
		var anim_name = _get_anim("walk", dir)
		if distance > attack_distance * 1.5:
			vel = final_dir * personal_speed * run_speed_multiplier
			anim_name = _get_anim("run", final_dir)
		else:
			anim_name = _get_anim("walk", final_dir)
		_move(vel, anim_name)

	velocity = _approach_velocity(velocity, desired_velocity, delta)
	move_and_slide()

func _wander(delta):
	wander_timer -= delta
	if wander_timer <= 0:
		is_wandering = not is_wandering
		if is_wandering:
			wander_dir = Vector2(randf()*2-1, randf()*2-1).normalized()
			facing_dir = wander_dir
			anim.play(_get_anim("walk", wander_dir))
		else:
			wander_dir = Vector2.ZERO
			anim.play(_get_anim("idle2", facing_dir))
		wander_timer = randf_range(0.5,1.5)

	if is_wandering:
		desired_velocity = (wander_dir + _avoid_player_overlap()).normalized() * personal_speed * 0.5
		_play_anim_safe(_get_anim("walk", wander_dir))
	else:
		desired_velocity = Vector2.ZERO
		_play_anim_safe(_get_anim("idle2", facing_dir))

	velocity = _approach_velocity(velocity, desired_velocity, delta)

func _move(vel, anim_name):
	desired_velocity = vel
	if vel.length() > 0.001:
		facing_dir = vel.normalized()
	_play_anim_safe(anim_name)

func _stop_movement():
	desired_velocity = Vector2.ZERO
	velocity = _approach_velocity(velocity, desired_velocity, 1.0 / 60.0)
	move_and_slide()

func _on_enter(body):
	if body.is_in_group("player"):
		player = body
		see_player = true

func _on_exit(body):
	if body.is_in_group("player"):
		player = null
		see_player = false

func _on_hitbox_entered(body: Node):
	if spawn_timer > 0:
		return
	if is_dead:
		return
	if _is_player_attack_source(body):
		var dmg = _extract_damage(body)
		take_damage(dmg)

func _extract_damage(source: Node) -> int:
	var default_damage := 10 # Damage taken if attack object has no explicit damage value.
	if source == null:
		return default_damage
	var source_owner = _resolve_source_owner(source)
	if source_owner.has_method("get_damage"):
		return int(source_owner.call("get_damage"))
	for prop in source_owner.get_property_list():
		if prop.name == "damage":
			return int(source_owner.get("damage"))
	for prop in source.get_property_list():
		if prop.name == "damage":
			return int(source.get("damage"))
	return default_damage

func _is_player_attack_source(source: Node) -> bool:
	if source == null:
		return false
	if source.is_in_group("player_attack"):
		return true
	var source_owner = _resolve_source_owner(source)
	if source_owner.is_in_group("player_attack"):
		return true
	if source_owner.is_in_group("player"):
		for prop in source_owner.get_property_list():
			if prop.name == "is_attacking":
				return bool(source_owner.get("is_attacking"))
	return false

func _resolve_source_owner(source: Node) -> Node:
	if source is CollisionShape2D and source.get_parent() != null:
		return source.get_parent()
	return source

func _start_attack(dir: Vector2):
	is_attacking = true
	if dir.length() != 0:
		attack_dir = dir.normalized()
	else:
		attack_dir = Vector2.RIGHT
	anim.play(_get_anim(attacks[current_attack]["name"], attack_dir))
	var dmg = attacks[current_attack]["damage"]
	await get_tree().create_timer(0.3).timeout
	if is_dead:
		return
	_deal_damage(dmg)
	await get_tree().create_timer(0.5).timeout
	_end_attack()

func _deal_damage(amount):
	if player and player.has_method("take_damage") and global_position.distance_to(player.global_position) <= attack_distance:
		player.take_damage(amount)

func _end_attack():
	is_attacking = false
	current_attack = _pick_next_attack()
	if player:
		var dir = player.global_position - global_position
		if dir.length() != 0:
			dir = dir.normalized()
		else:
			dir = Vector2.RIGHT
		anim.play(_get_anim("idle2", dir))

func _approach_velocity(current: Vector2, target: Vector2, delta: float) -> Vector2:
	var rate = acceleration if target.length() > current.length() else deceleration
	return current.move_toward(target, rate * delta)

func _should_strafe() -> bool:
	if behavior_timer > 0:
		return use_strafe
	behavior_timer = behavior_update_interval
	use_strafe = randf() < strafe_chance
	return use_strafe

func _play_anim_safe(anim_name: String):
	if anim.animation != anim_name:
		anim.play(anim_name)

func _next_attack_cooldown() -> float:
	var random_part = randf_range(-attack_cooldown_random, attack_cooldown_random)
	return max(0.15, attack_cooldown + random_part)

func _pick_next_attack() -> int:
	if attacks.size() < 2:
		return 1
	# Usually alternate attacks, but sometimes allow short streaks.
	if attack_streak >= 2:
		prefer_attack = 1 if prefer_attack == 2 else 2
		attack_streak = 0
		return prefer_attack
	if randf() < 0.7:
		prefer_attack = 1 if prefer_attack == 2 else 2
		attack_streak = 0
	else:
		attack_streak += 1
	return prefer_attack

func _predict_player_position() -> Vector2:
	if not player:
		return global_position
	if player is CharacterBody2D:
		return player.global_position + player.velocity * PREDICT_TIME
	return player.global_position

func _avoid_player_overlap() -> Vector2:
	if not player:
		return Vector2.ZERO
	var to_self = global_position - player.global_position
	var d = to_self.length()
	if d < 0.001 or d > separation_radius:
		return Vector2.ZERO
	return to_self.normalized() * ((separation_radius - d) / separation_radius) * separation_strength

func _avoid_allies() -> Vector2:
	var push := _avoid_player_overlap()
	for ally in get_tree().get_nodes_in_group("enemy_ai"):
		if ally == self or not (ally is CharacterBody2D):
			continue
		var to_self = global_position - ally.global_position
		var d = to_self.length()
		if d > 0.001 and d < separation_radius:
			push += to_self.normalized() * ((separation_radius - d) / separation_radius)
	return push * separation_strength

func _is_low_health() -> bool:
	if max_health <= 0:
		return false
	return health <= int(max_health * low_health_ratio)

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
		hit_reaction_timer = hit_reaction_time
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
	anim.speed_scale = max(0.1, death_anim_speed_scale)
	anim.play(_get_anim("die", dir))
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("Hitbox"):
		$Hitbox.set_deferred("monitoring", false)
	if has_node("VisionArea"):
		$VisionArea.set_deferred("monitoring", false)
	var anim_name = _get_anim("die", dir)
	var frames_res: SpriteFrames = anim.sprite_frames
	var duration := 0.6
	if frames_res != null and frames_res.has_animation(anim_name):
		var fps = frames_res.get_animation_speed(anim_name)
		if fps <= 0:
			fps = 1.0
		duration = float(frames_res.get_frame_count(anim_name)) / (fps * anim.speed_scale)
	await get_tree().create_timer(duration).timeout
	await get_tree().create_timer(max(0.0, death_linger_time)).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, max(0.05, death_fade_time))
	await fade_tween.finished
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
