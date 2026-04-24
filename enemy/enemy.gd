extends CharacterBody2D

@export var speed := 80.0
@export var run_speed_multiplier := 1.45
@export var max_health := 5
@export var attack_distance := 40.0
@export var strafe_distance := 120.0
@export var attack_cooldown := 1.0
@export var attack_cooldown_random := 0.25
@export var spawn_invincible_time := 1.0
@export var low_health_ratio := 0.35
@export var separation_radius := 60.0
@export var separation_strength := 0.85
@export var min_move_speed := 45.0
@export var max_move_speed := 85.0
@export var acceleration := 720.0
@export var deceleration := 860.0
@export var hit_reaction_time := 0.22
@export var death_anim_speed_scale := 0.7
@export var death_linger_time := 1.0
@export var death_fade_time := 0.8

# Decision layer tuning.
@export var think_interval_min := 0.08
@export var think_interval_max := 0.2
@export var hesitation_min := 0.08
@export var hesitation_max := 0.25
@export var aggression_base := 0.65
@export var aggression_jitter := 0.25
@export var fear_base := 0.35
@export var fear_jitter := 0.25
@export var reengage_delay := 1.8
@export var memory_decay_per_second := 0.65
@export var strafe_bias := 0.35
@export var strafe_max_duration := 1.2
@export var force_attack_distance_ratio := 1.1
@export var strafe_cooldown_after_exit := 0.9
@export var state_lock_min_time := 0.18
@export var attack_enter_distance_ratio := 0.95
@export var attack_exit_distance_ratio := 1.2
@export var strafe_enter_distance_ratio := 1.15
@export var strafe_exit_distance_ratio := 1.02
@export var strafe_direction_change_interval := 1.25
@export var stun_on_hit_time := 0.32
@export var damage_flash_time := 0.09
@export var damage_flash_color := Color(1.7, 1.7, 1.7, 1.0)
@export var post_attack_retreat_time := 0.28
@export var post_attack_retreat_speed_multiplier := 0.8
@export var post_attack_prep_time := 0.2
@export var combo_every_attacks := 3
@export var combo_burst_hits := 3
@export var combo_between_hits_time := 0.08
@export var combo_recovery_time := 0.16
@export var stuck_repath_time := 0.38

const TAU := PI * 2.0
const PREDICT_TIME := 0.45

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	STRAFE,
	RETREAT,
	HIT_REACTION,
	DEAD
}

var health := 0
var player: Node2D = null
var see_player := false
var is_dead := false
var spawn_timer := 0.0
var desired_velocity := Vector2.ZERO
var facing_dir := Vector2.RIGHT
var strafe_sign := 1.0
var personal_speed := 80.0
var current_state: State = State.IDLE
var state_elapsed := 0.0

# AI personality per-instance.
var aggression := 0.6
var fear := 0.4

# Combat and memory.
var attack_timer := 0.0
var current_attack := 1
var prefer_attack := 1
var attack_streak := 0
var attack_dir := Vector2.RIGHT
var recent_damage := 0.0
var retreat_timer := 0.0
var think_timer := 0.0
var action_memory := {
	"attack": 0.0,
	"strafe": 0.0,
	"retreat": 0.0,
	"chase": 0.0
}

# State-local runtime.
var idle_timer := 0.0
var wander_timer := 0.0
var wander_dir := Vector2.ZERO
var attack_phase := 0
var attack_phase_timer := 0.0
var queued_attack_damage := 0
var hit_reaction_timer := 0.0
var strafe_cooldown_timer := 0.0
var strafe_direction_timer := 0.0
var _damage_flash_token := 0
var post_attack_retreat_timer := 0.0
var combo_ready := false
var combo_hits_left := 0
var completed_attacks := 0
var _stuck_timer := 0.0
var _last_position := Vector2.ZERO

var attacks = {
	1: {"name": "attack", "damage": 1},
	2: {"name": "attack2", "damage": 5}
}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	health = max_health
	add_to_group("enemy_ai")
	personal_speed = clampf(speed * randf_range(0.8, 1.05), min_move_speed, max_move_speed)
	aggression = clampf(aggression_base + randf_range(-aggression_jitter, aggression_jitter), 0.05, 1.0)
	fear = clampf(fear_base + randf_range(-fear_jitter, fear_jitter), 0.0, 1.0)
	current_attack = randi() % attacks.size() + 1
	prefer_attack = current_attack
	spawn_timer = spawn_invincible_time
	strafe_sign = -1.0 if (get_instance_id() % 2 == 0) else 1.0
	$VisionArea.body_entered.connect(_on_enter)
	$VisionArea.body_exited.connect(_on_exit)
	$Hitbox.body_entered.connect(_on_hitbox_entered)
	$Hitbox.area_entered.connect(_on_hitbox_entered)
	_last_position = global_position
	_change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	spawn_timer = max(0.0, spawn_timer - delta)
	attack_timer = max(0.0, attack_timer - delta)
	think_timer = max(0.0, think_timer - delta)
	strafe_cooldown_timer = max(0.0, strafe_cooldown_timer - delta)
	strafe_direction_timer = max(0.0, strafe_direction_timer - delta)
	state_elapsed += delta
	_decay_memory(delta)
	decay_recent_damage(delta)

	if is_dead and current_state != State.DEAD:
		_change_state(State.DEAD)

	_evaluate_decision_if_needed()
	_state_update(current_state, delta)
	_update_stuck_recovery(delta)
	velocity = _approach_velocity(velocity, desired_velocity, delta)
	move_and_slide()

func _evaluate_decision_if_needed() -> void:
	if current_state in [State.ATTACK, State.HIT_REACTION, State.DEAD]:
		return
	if think_timer > 0.0:
		return
	think_timer = randf_range(think_interval_min, think_interval_max)
	_change_state(_choose_next_state())

func _choose_next_state() -> State:
	if is_dead:
		return State.DEAD
	if hit_reaction_timer > 0.0:
		return State.HIT_REACTION
	if not _has_player_target():
		return State.WANDER if randf() < 0.68 else State.IDLE

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > 0.001:
		facing_dir = to_player.normalized()

	var health_ratio := _health_ratio()
	var attack_enter_distance := attack_distance * attack_enter_distance_ratio
	var attack_exit_distance := attack_distance * attack_exit_distance_ratio
	var strafe_enter_distance := attack_distance * strafe_enter_distance_ratio
	var strafe_exit_distance := attack_distance * strafe_exit_distance_ratio
	var can_attack := distance <= attack_enter_distance and attack_timer <= 0.0
	var in_strafe_band := distance > strafe_enter_distance and distance <= strafe_distance
	if current_state == State.STRAFE:
		in_strafe_band = distance > strafe_exit_distance and distance <= strafe_distance
	var panic := clampf(recent_damage / max(1.0, float(max_health)), 0.0, 1.0)
	var retreat_need := (1.0 - health_ratio) * 0.55 + panic * 0.45 + fear * 0.35
	var attack_desire := aggression * 0.7 + (1.0 - health_ratio) * 0.15
	attack_desire += max(0.0, 1.0 - distance / max(attack_distance, 1.0)) * 0.45
	attack_desire -= action_memory["attack"] * 0.55
	attack_desire -= panic * 0.25
	attack_desire += 0.05 if can_attack else -0.45

	var strafe_desire := aggression * 0.35 + strafe_bias
	strafe_desire += clampf(1.0 - abs(distance - strafe_distance * 0.75) / max(strafe_distance, 1.0), 0.0, 1.0) * 0.55
	strafe_desire -= action_memory["strafe"] * 0.45
	strafe_desire -= retreat_need * 0.3
	if not in_strafe_band:
		strafe_desire -= 0.6
	if strafe_cooldown_timer > 0.0:
		strafe_desire -= 0.9

	var chase_desire := aggression * 0.5 + 0.25
	chase_desire += clampf(distance / max(strafe_distance, 1.0), 0.0, 1.0) * 0.55
	chase_desire -= action_memory["chase"] * 0.25
	chase_desire -= retreat_need * 0.25

	var retreat_desire: float = retreat_need - float(action_memory["retreat"]) * 0.25
	if not _is_low_health() and panic < 0.32 and retreat_timer <= 0.0:
		retreat_desire -= 0.65
	if retreat_timer > 0.0:
		retreat_desire += 0.35

	# Prevent endless orbiting near target: force ATTACK when in close range and stable.
	if can_attack and distance <= attack_exit_distance and retreat_desire < 0.85:
		return State.ATTACK

	var best_state := State.CHASE
	var best_score := chase_desire

	if can_attack and attack_desire > best_score:
		best_score = attack_desire
		best_state = State.ATTACK
	if in_strafe_band and strafe_desire > best_score:
		best_score = strafe_desire
		best_state = State.STRAFE
	if retreat_desire > best_score:
		best_state = State.RETREAT

	if best_score < 0.1:
		return State.IDLE
	return best_state

func _change_state(next_state: State) -> void:
	if current_state == next_state:
		return
	if current_state not in [State.DEAD, State.HIT_REACTION, State.ATTACK] and state_elapsed < state_lock_min_time:
		return
	_state_exit(current_state)
	current_state = next_state
	state_elapsed = 0.0
	_state_enter(current_state)

func _state_enter(state: State) -> void:
	match state:
		State.IDLE:
			idle_timer = randf_range(0.2, 0.55)
			_play_anim_safe(_get_anim("idle2", facing_dir))
		State.WANDER:
			wander_timer = randf_range(0.45, 1.35)
			wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			if wander_dir == Vector2.ZERO:
				wander_dir = facing_dir
		State.CHASE:
			action_memory["chase"] += 0.26
		State.ATTACK:
			_enter_attack_state()
		State.STRAFE:
			action_memory["strafe"] += 0.33
			strafe_direction_timer = strafe_direction_change_interval
		State.RETREAT:
			if post_attack_retreat_timer <= 0.0:
				retreat_timer = max(retreat_timer, reengage_delay)
			action_memory["retreat"] += 0.3
		State.HIT_REACTION:
			hit_reaction_timer = max(hit_reaction_timer, hit_reaction_time)
			desired_velocity = Vector2.ZERO
			_play_anim_safe(_get_anim("hit", facing_dir))
		State.DEAD:
			_enter_dead_state()

func _state_update(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			_update_idle(delta)
		State.WANDER:
			_update_wander(delta)
		State.CHASE:
			_update_chase()
		State.ATTACK:
			_update_attack(delta)
		State.STRAFE:
			_update_strafe()
		State.RETREAT:
			_update_retreat(delta)
		State.HIT_REACTION:
			_update_hit_reaction(delta)
		State.DEAD:
			desired_velocity = Vector2.ZERO

func _state_exit(state: State) -> void:
	match state:
		State.ATTACK:
			attack_phase = 0
			attack_phase_timer = 0.0
		State.STRAFE:
			strafe_cooldown_timer = strafe_cooldown_after_exit
		_:
			pass

func _update_idle(delta: float) -> void:
	idle_timer -= delta
	desired_velocity = Vector2.ZERO
	_play_anim_safe(_get_anim("idle2", facing_dir))
	if idle_timer <= 0.0:
		think_timer = 0.0

func _update_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.35, 0.95)
		wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if wander_dir == Vector2.ZERO:
			wander_dir = facing_dir
	var move_dir := (wander_dir + _avoid_player_overlap()).normalized()
	if move_dir == Vector2.ZERO:
		move_dir = wander_dir
	_move(move_dir * personal_speed * 0.5, _get_anim("walk", move_dir))

func _update_chase() -> void:
	if not _has_player_target():
		desired_velocity = Vector2.ZERO
		_play_anim_safe(_get_anim("idle2", facing_dir))
		return
	var predicted_pos := _predict_player_position()
	var chase_dir := (predicted_pos - global_position).normalized()
	if chase_dir == Vector2.ZERO:
		chase_dir = facing_dir
	var final_dir := (chase_dir + _avoid_allies()).normalized()
	if final_dir == Vector2.ZERO:
		final_dir = chase_dir
	var dist := global_position.distance_to(player.global_position)
	var move_speed := personal_speed * (run_speed_multiplier if dist > attack_distance * 1.5 else 1.0)
	var anim_name := _get_anim("run", final_dir) if dist > attack_distance * 1.5 else _get_anim("walk", final_dir)
	_move(final_dir * move_speed, anim_name)

func _update_strafe() -> void:
	if not _has_player_target():
		desired_velocity = Vector2.ZERO
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance <= attack_distance * strafe_exit_distance_ratio:
		# Too close for lateral movement: break orbit loop.
		think_timer = 0.0
		if distance <= attack_distance * attack_enter_distance_ratio and attack_timer <= 0.0:
			_change_state(State.ATTACK)
		else:
			_change_state(State.CHASE)
		return
	var dir := to_player.normalized()
	var tangent := dir.rotated(PI * 0.5 * strafe_sign)
	var desired_radius := clampf(attack_distance * 1.25, attack_distance + 8.0, strafe_distance)
	var radius_error := clampf((to_player.length() - desired_radius) / max(desired_radius, 1.0), -1.0, 1.0)
	var radial_correction := dir * radius_error * 1.15
	var move_dir := (tangent + radial_correction + _avoid_allies()).normalized()
	if move_dir == Vector2.ZERO:
		move_dir = tangent
	_move(move_dir * personal_speed * 0.86, _get_anim("walk", move_dir))
	if strafe_direction_timer <= 0.0 and distance > attack_distance * 1.2:
		# Flip strafe direction rarely to avoid twitching.
		strafe_sign *= -1.0
		strafe_direction_timer = strafe_direction_change_interval
		think_timer = max(think_timer, 0.06)
	if state_elapsed >= strafe_max_duration:
		# Hard cap on strafe time to avoid getting stuck circling.
		think_timer = 0.0
		if global_position.distance_to(player.global_position) <= attack_distance * force_attack_distance_ratio and attack_timer <= 0.0:
			_change_state(State.ATTACK)
		else:
			_change_state(State.CHASE)

func _enter_attack_state() -> void:
	if not _has_player_target():
		_change_state(State.CHASE)
		return
	var dir := (player.global_position - global_position).normalized()
	attack_dir = dir if dir != Vector2.ZERO else facing_dir
	desired_velocity = Vector2.ZERO
	attack_phase = 0
	attack_phase_timer = randf_range(hesitation_min, hesitation_max)
	if combo_ready:
		combo_hits_left = max(1, combo_burst_hits)
		combo_ready = false
		attack_phase_timer = min(attack_phase_timer, combo_recovery_time)
	else:
		combo_hits_left = 1
	queued_attack_damage = int(attacks[current_attack]["damage"])
	_play_anim_safe(_get_anim("idle2", attack_dir))

func _update_attack(delta: float) -> void:
	desired_velocity = Vector2.ZERO
	attack_phase_timer -= delta
	if attack_phase == 0:
		# Hesitation makes attacks feel intentional, not frame-perfect.
		_play_anim_safe(_get_anim("idle2", attack_dir))
		if attack_phase_timer <= 0.0:
			attack_phase = 1
			attack_phase_timer = 0.3
			_play_anim_safe(_get_anim(attacks[current_attack]["name"], attack_dir))
	elif attack_phase == 1:
		if attack_phase_timer <= 0.0:
			attack_phase = 2
			attack_phase_timer = 0.42
			_deal_damage(queued_attack_damage)
	else:
		if attack_phase_timer <= 0.0:
			if combo_hits_left > 1:
				combo_hits_left -= 1
				current_attack = _pick_next_attack_weighted()
				attack_phase = 0
				attack_phase_timer = combo_between_hits_time
				var chain_dir := attack_dir
				if _has_player_target():
					var to_player := player.global_position - global_position
					if to_player.length() > 0.001:
						chain_dir = to_player.normalized()
				attack_dir = chain_dir
				_play_anim_safe(_get_anim("idle2", attack_dir))
				return
			attack_timer = _next_attack_cooldown()
			completed_attacks += 1
			if combo_every_attacks > 0 and completed_attacks % combo_every_attacks == 0:
				combo_ready = true
			post_attack_retreat_timer = post_attack_retreat_time
			action_memory["attack"] += 0.62
			current_attack = _pick_next_attack_weighted()
			think_timer = max(think_timer, post_attack_prep_time)
			_change_state(State.RETREAT)

func _update_retreat(delta: float) -> void:
	var retreat_dir := -attack_dir
	if _has_player_target():
		retreat_timer = max(0.0, retreat_timer - delta)
		var dir_from_player := (global_position - player.global_position).normalized()
		retreat_dir = (dir_from_player + _avoid_allies() * 0.7).normalized()
	else:
		post_attack_retreat_timer = max(0.0, post_attack_retreat_timer - delta)
		retreat_dir = (-attack_dir + _avoid_allies() * 0.45).normalized()
	if retreat_dir == Vector2.ZERO:
		retreat_dir = -facing_dir
	var retreat_speed := personal_speed * run_speed_multiplier
	if post_attack_retreat_timer > 0.0:
		post_attack_retreat_timer = max(0.0, post_attack_retreat_timer - delta)
		retreat_speed = personal_speed * post_attack_retreat_speed_multiplier
	_move(retreat_dir * retreat_speed, _get_anim("walk", retreat_dir))
	if post_attack_retreat_timer <= 0.0 and retreat_timer <= 0.0 and not _is_low_health():
		think_timer = 0.0

func _update_hit_reaction(delta: float) -> void:
	hit_reaction_timer = max(0.0, hit_reaction_timer - delta)
	desired_velocity = Vector2.ZERO
	if hit_reaction_timer <= 0.0:
		_change_state(_choose_next_state())

func _enter_dead_state() -> void:
	is_dead = true
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	var dir := facing_dir
	if _has_player_target():
		var d := player.global_position - global_position
		if d.length() > 0.001:
			dir = d.normalized()
	anim.speed_scale = max(0.1, death_anim_speed_scale)
	anim.play(_get_anim("die", dir))
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("Hitbox"):
		$Hitbox.set_deferred("monitoring", false)
	if has_node("VisionArea"):
		$VisionArea.set_deferred("monitoring", false)
	_finalize_death(dir)

func _finalize_death(dir: Vector2) -> void:
	var anim_name := _get_anim("die", dir)
	var frames_res: SpriteFrames = anim.sprite_frames
	var duration := 0.6
	if frames_res != null and frames_res.has_animation(anim_name):
		var fps := frames_res.get_animation_speed(anim_name)
		if fps <= 0.0:
			fps = 1.0
		duration = float(frames_res.get_frame_count(anim_name)) / (fps * anim.speed_scale)
	await get_tree().create_timer(duration).timeout
	await get_tree().create_timer(max(0.0, death_linger_time)).timeout
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, max(0.05, death_fade_time))
	await fade_tween.finished
	queue_free()

func _move(vel: Vector2, anim_name: String) -> void:
	desired_velocity = vel
	if vel.length() > 0.001:
		facing_dir = vel.normalized()
	_play_anim_safe(anim_name)

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		see_player = true
		think_timer = 0.0

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		player = null
		see_player = false
		think_timer = 0.0

func _on_hitbox_entered(body: Node) -> void:
	if spawn_timer > 0.0 or is_dead:
		return
	if _is_player_attack_source(body):
		take_damage(_extract_damage(body))

func _extract_damage(source: Node) -> int:
	var default_damage := 10
	if source == null:
		return default_damage
	var source_owner := _resolve_source_owner(source)
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
	var source_owner := _resolve_source_owner(source)
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

func _deal_damage(amount: int) -> void:
	if _has_player_target() and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) <= attack_distance:
			player.take_damage(amount)

func _approach_velocity(current: Vector2, target: Vector2, delta: float) -> Vector2:
	var rate := acceleration if target.length() > current.length() else deceleration
	return current.move_toward(target, rate * delta)

func _play_anim_safe(anim_name: String) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)

func _next_attack_cooldown() -> float:
	var random_part := randf_range(-attack_cooldown_random, attack_cooldown_random)
	return max(0.15, attack_cooldown + random_part)

func _pick_next_attack_weighted() -> int:
	if attacks.size() < 2:
		return 1
	# Bias against repeating same attack chain too much.
	var alt: int = 1 if prefer_attack == 2 else 2
	var same_weight: float = max(0.05, 0.28 - float(action_memory["attack"]) * 0.2)
	var alt_weight: float = 0.72 + float(action_memory["attack"]) * 0.2
	if attack_streak >= 2:
		prefer_attack = alt
		attack_streak = 0
		return prefer_attack
	if randf() < same_weight / (same_weight + alt_weight):
		attack_streak += 1
		return prefer_attack
	prefer_attack = alt
	attack_streak = 0
	return prefer_attack

func _predict_player_position() -> Vector2:
	if not _has_player_target():
		return global_position
	if player is CharacterBody2D:
		return player.global_position + player.velocity * PREDICT_TIME
	return player.global_position

func _avoid_player_overlap() -> Vector2:
	if not _has_player_target():
		return Vector2.ZERO
	var to_self := global_position - player.global_position
	var d := to_self.length()
	if d < 0.001 or d > separation_radius:
		return Vector2.ZERO
	return to_self.normalized() * ((separation_radius - d) / separation_radius) * separation_strength

func _avoid_allies() -> Vector2:
	var push := _avoid_player_overlap()
	for ally in get_tree().get_nodes_in_group("enemy_ai"):
		if ally == self or not (ally is CharacterBody2D):
			continue
		var ally_body: CharacterBody2D = ally
		var to_self: Vector2 = global_position - ally_body.global_position
		var d: float = to_self.length()
		if d > 0.001 and d < separation_radius:
			push += to_self.normalized() * ((separation_radius - d) / separation_radius)
	return push * separation_strength

func _is_low_health() -> bool:
	return _health_ratio() <= low_health_ratio

func _health_ratio() -> float:
	if max_health <= 0:
		return 1.0
	return clampf(float(health) / float(max_health), 0.0, 1.0)

func take_damage(amount: int) -> void:
	if is_dead or spawn_timer > 0.0:
		return
	health -= amount
	recent_damage += float(amount)
	_trigger_damage_flash()
	if health <= 0:
		_change_state(State.DEAD)
		return
	if _has_player_target():
		var dir := player.global_position - global_position
		if dir.length() > 0.001:
			facing_dir = dir.normalized()
	hit_reaction_timer = max(hit_reaction_timer, stun_on_hit_time)
	_change_state(State.HIT_REACTION)

func decay_recent_damage(delta: float) -> void:
	recent_damage = max(0.0, recent_damage - delta * 1.6)

func _decay_memory(delta: float) -> void:
	for key in action_memory.keys():
		action_memory[key] = max(0.0, action_memory[key] - memory_decay_per_second * delta)

func _has_player_target() -> bool:
	return see_player and player != null and is_instance_valid(player)

func _trigger_damage_flash() -> void:
	_damage_flash_token += 1
	var token := _damage_flash_token
	modulate = damage_flash_color
	anim.modulate = damage_flash_color
	await get_tree().create_timer(damage_flash_time).timeout
	if token == _damage_flash_token and not is_dead:
		modulate = Color(1, 1, 1, 1)
		anim.modulate = Color(1, 1, 1, 1)

func _update_stuck_recovery(delta: float) -> void:
	var moved := global_position.distance_to(_last_position)
	if desired_velocity.length() > 18.0 and moved < 1.2:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_position = global_position
	if _stuck_timer >= stuck_repath_time and current_state in [State.CHASE, State.STRAFE, State.RETREAT]:
		_stuck_timer = 0.0
		strafe_sign *= -1.0
		think_timer = 0.0
		var nudge := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if nudge == Vector2.ZERO:
			nudge = -facing_dir
		desired_velocity = (desired_velocity.normalized() + nudge * 0.65).normalized() * max(desired_velocity.length(), personal_speed * 0.7)

func _get_anim(state: String, dir: Vector2) -> String:
	return state + "_" + _dir8(dir)

func _dir8(dir: Vector2) -> String:
	var safe_dir := dir if dir.length() > 0.001 else facing_dir
	var a := fposmod(safe_dir.angle(), TAU)
	if a < PI / 8.0 or a >= 15.0 * PI / 8.0:
		return "right"
	if a < 3.0 * PI / 8.0:
		return "down_right"
	if a < 5.0 * PI / 8.0:
		return "down"
	if a < 7.0 * PI / 8.0:
		return "down_left"
	if a < 9.0 * PI / 8.0:
		return "left"
	if a < 11.0 * PI / 8.0:
		return "up_left"
	if a < 13.0 * PI / 8.0:
		return "up"
	return "up_right"
