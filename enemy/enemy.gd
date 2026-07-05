extends CharacterBody2D

# ============== ПАРАМЕТРЫ ==============
# Движение
@export var walk_speed := 40.0
@export var run_speed := 80.0
@export var friction := 500.0
@export var direction_smoothness := 8.0

@onready var shapes := {
	"left":       $Hitbox/Atack_hitbox/left,
	"up_left":    $Hitbox/Atack_hitbox/left_up,
	"down_left":  $Hitbox/Atack_hitbox/left_down,
	"right":      $Hitbox/Atack_hitbox/right,
	"up_right":   $Hitbox/Atack_hitbox/right_up,
	"down_right": $Hitbox/Atack_hitbox/right_down,
	"up":         $Hitbox/Atack_hitbox/up,
	"down":       $Hitbox/Atack_hitbox/down,
}

# Здоровье
@export var max_health := 3
@export var damage_flash_time := 0.3
# Боевые параметры
@export var attack_range := 45
@export var attack_cooldown := 1.5
@export var attack_damage_min := 30
@export var attack_damage_max := 40
@export var attack_duration := 0.5
@onready var attack_hitbox: Area2D = $Hitbox/Atack_hitbox
var current_attack_anim := "attack"

func get_attack_damage() -> int:
	return randi_range(attack_damage_min, attack_damage_max)

# Визуальные эффекты
@export var damage_flash_color := Color(2.0, 0.2, 0.2, 1.0)
@export var berserk_highlight_color := Color(5.0, 4.5, 2.5, 1.0)
var _rest_modulate := Color.WHITE

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
@export var coin_scene: PackedScene
@export var coin_drop_min := 1
@export var coin_drop_max := 3
@export var blood_vfx_scene: PackedScene

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
var wander_timer := 0.0

var last_anim_direction := "down"
var posture := 0.0
var posture_regen_timer := 0.0
var is_blocking := false
var is_posture_broken := false

var block_hit_count := 0          # сколько ударов заблокировал подряд
var parry_threshold := 2          # после скольки ударов парирует
var is_parrying := false          # окно парирования
var parry_timer := 0.0
var parry_window := 0.3         # длительность окна парирования
var counter_timer := 0.0
var is_countering := false
var is_player_berserk := false
@export var counter_duration := 0.75
@export var pummel_posture_damage := 40.0  # урон по концентрации игрока
@onready var anim: AnimationPlayer = $EnemyAnim
@onready var vision_area: Area2D = $VisionArea
@onready var hitbox: Area2D = $Hitbox
@onready var hp_bar: ProgressBar = $EnemyUI/HPBar
@onready var posture_bar: ProgressBar = $EnemyUI/PostureBar
@onready var block_vfx: GPUParticles2D = $BlockVFX
@onready var state_label: Label = $StateLabel

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
	attack_hitbox.body_entered.connect(_on_attack_body_entered)

	$Hurtbox.add_to_group("enemy_hurtbox")
	
	if vision_area:
		vision_area.body_entered.connect(_on_vision_body_entered)
		vision_area.body_exited.connect(_on_vision_body_exited)

	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.body_entered.connect(_on_hitbox_hit)

	wander_timer = randf_range(2.0, 4.0)

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
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
		velocity = move_velocity
	_separate_from_player()
	move_and_slide()
	if current_state == State.WANDER and get_slide_collision_count() > 0:
		if _direction_change_cooldown <= 0.0:
			var collision := get_slide_collision(0)
			wander_direction = wander_direction.bounce(collision.get_normal())
			wander_timer = randf_range(2.0, 4.0)
			_direction_change_cooldown = 0.8
	# таймеры парирования и контратаки

	if is_countering:
		counter_timer -= delta
		if counter_timer <= 0.0:
			is_countering = false
			_change_state(State.CHASE)
	
	state_label.text = State.keys()[current_state]

# move_and_slide() не расталкивает уже перекрывшиеся тела с нулевой скоростью —
# без этого враг может "прилипнуть" к игроку и отлепится только от столкновения со стеной
func _separate_from_player() -> void:
	if not player or not is_instance_valid(player):
		return
	# пока игрок в додже/перекате — не расталкиваем, чтобы он проходил сквозь врагов
	if player.is_dodging or player.is_rolling:
		return
	# во время своей атаки/контратаки враг подходит ближе, чтобы хитбокс доставал,
	# но всё равно не даём телам полностью наложиться
	var min_separation := 34.0
	if current_state in [State.ATTACK, State.COUNTER]:
		min_separation = 22.0
	var offset := global_position - player.global_position
	var dist := offset.length()
	if dist < min_separation:
		var dir := offset.normalized() if dist > 0.001 else Vector2.DOWN
		global_position += dir * (min_separation - dist)

# ============== AI ==============

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
	
	# пробуем заблокировать если игрок атакует рядом
	if player and is_instance_valid(player):
		if _is_player_in_range(attack_range * 1.5):
			if player.is_attacking and not is_blocking and not is_posture_broken and not is_player_berserk:
				_try_block()
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
		
	# контратака если игрок атакует во время нашего парирования
	if is_parrying and player and player.is_attacking and not is_player_berserk:
		is_parrying = false
		_change_state(State.COUNTER)
		return

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
			# стан игрока
			if player and player.has_method("receive_parry"):
				player.receive_parry(pummel_posture_damage)

		State.IDLE:
			move_velocity = Vector2.ZERO

		State.WANDER:
			wander_timer = randf_range(2.0, 4.0)

		State.CHASE:
			pass

		State.ATTACK:
			move_velocity = Vector2.ZERO
			attack_started = false
			if player:
				direction = (player.global_position - global_position).normalized()
			can_attack = false
			hit_targets.clear()
			_update_attack_shape()
			# рандомно выбираем атаку
			var attacks = ["attack", "attack2"]
			current_attack_anim = attacks[randi() % attacks.size()]

		State.HIT_STUN:
			move_velocity = Vector2.ZERO
			knockback_velocity = Vector2.ZERO
			hit_stun_timer = 1.0
			print("hit_stun_timer установлен: ", hit_stun_timer)

		State.BLOCK:
			move_velocity = Vector2.ZERO
			is_blocking = true

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
	wander_timer -= delta

	var moved := global_position.distance_to(_last_position)
	_last_position = global_position

	if moved < 0.5:
		_stuck_timer += delta
		if _stuck_timer >= 0.3:
			_stuck_timer = 0.0
			_pick_new_wander_direction()
	else:
		_stuck_timer = 0.0

	if wander_timer <= 0.0:
		_pick_new_wander_direction()

	var speed := walk_speed * wander_speed_multiplier

	# БЫЛО: direction_smoothness * delta  — слишком резко
	# СТАЛО: фиксированный медленный коэффициент
	direction = wander_direction


	move_velocity = direction * speed
	_play_animation("walk")
	
func _pick_new_wander_direction() -> void:
	wander_direction = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	if wander_direction == Vector2.ZERO:
		wander_direction = Vector2.DOWN

	# БЫЛО: 2.0 - 4.0 сек — слишком часто
	wander_timer = randf_range(2.0, 6.0)

# ===================== CHASE =====================
func _state_chase(delta: float) -> void:
	if not player or not is_instance_valid(player):
		_change_state(State.WANDER)
		return

	if not _is_player_in_range(vision_range):
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

var attack_direction_name := ""  # добавь в переменные
func _state_attack(delta: float) -> void:
	move_velocity = Vector2.ZERO

	if not attack_started:
		attack_started = true
		attack_active = true
		attack_hit_window = true
		hit_targets.clear()
		attack_direction_name = _get_direction_name(direction)  # ← фиксируем направление
		_update_attack_shape()
		_play_animation(current_attack_anim)

	# Игрок исчез — прерываем атаку
	if not player or not is_instance_valid(player):
		_exit_attack()
		_change_state(State.WANDER)


func _exit_attack() -> void:
	attack_active = false
	attack_hit_window = false
	attack_started = false
	for s in shapes.values():
		s.call_deferred("set", "disabled", true)
	attack_cooldown_timer = attack_cooldown
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
func _play_animation(state: String) -> void:
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
	anim.play(anim_name)


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


# ===================== HIT DAMAGE =====================

var knockback_velocity := Vector2.ZERO

func take_damage(amount: int, source: Node2D = null) -> void:
	if is_dead:
		return

	# Безумие Берсерка — ломает защиту врага с первого удара: без блока, парирования и контратаки
	if is_player_berserk:
		is_parrying = false
		is_blocking = false
		health -= amount
		hp_bar.visible = true
		hp_bar.value = health
		_trigger_damage_flash()
		play_blood_vfx()

		if health <= 0:
			health = 0
			is_dead = true
			_change_state(State.DEAD)
		else:
			_trigger_stagger()

		if source and not is_dead:
			var knockback_dir = (global_position - source.global_position).normalized()
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
		_trigger_block_effect()

		if source:
			var knockback_dir = (global_position - source.global_position).normalized()
			knockback_velocity = knockback_dir * 80.0

		if posture >= max_posture:
			posture = max_posture
			_posture_break()
			return

		# после N ударов — парируем
		if block_hit_count >= parry_threshold:
			_change_state(State.PARRY)
			return

		return
	
	health -= amount
	hp_bar.visible = true
	hp_bar.value = health
	_trigger_damage_flash()
	play_blood_vfx()
	
	if health <= 0:
		health = 0
		is_dead = true
		_change_state(State.DEAD)
	else:
		_change_state(State.HIT_STUN)
	
	if source and not is_dead:
		var knockback_dir = (global_position - source.global_position).normalized()
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

func _state_block(_delta: float) -> void:
	move_velocity = Vector2.ZERO
	var anim_name = "block_" + _get_direction_name(direction)
	if anim.current_animation != anim_name:
		anim.play(anim_name)
	
	# парируем после N ударов
	if block_hit_count >= parry_threshold and not is_parrying:
		_start_parry()
		return
	
	if not player or not _is_player_in_range(attack_range * 2.0):
		is_blocking = false
		block_hit_count = 0
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
		var knockback_dir = (global_position - player.global_position).normalized()
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
	# наносим урон по концентрации игрока
	if attack_active and player and is_instance_valid(player):
		if player not in hit_targets:
			if player.has_method("receive_parry"):
				player.receive_parry(pummel_posture_damage)
				hit_targets.append(player)
				attack_active = false

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

func _get_attack_dir_name(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func _update_attack_shape() -> void:
	for key in shapes:
		shapes[key].call_deferred("set", "disabled", true)
	if current_state == State.ATTACK or current_state == State.COUNTER:
		var dir_name = attack_direction_name if attack_direction_name != "" else _get_direction_name(direction)
		if dir_name in shapes:
			shapes[dir_name].call_deferred("set", "disabled", false)
