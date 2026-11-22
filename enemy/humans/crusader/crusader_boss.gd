extends "res://enemy/humans/human_enemy.gd"
## crusader_boss.gd — босс храма Бальдра: Крестоносец Тёмного Солнца
## (листы крестоносца Ордена: плащ, двуручный меч), крупнее и злее рядового.
##
## Чем отличается от обычного врага:
##   * не станится и не отлетает: удары героя проходят (кровь, вспышка
##     попадания, урон), но реакции TakeDamage нет — он продолжает рубить;
##   * каждый удар героя по телу копит его концентрацию (posture); полная —
##     концентрация пробита: босс шатается, над ним руна, и в это окно
##     сокрушительный удар героя (Attack_4_, player.gd CRUSH_STEP) снимает
##     большую долю здоровья. Добить сразу, как рядового, нельзя;
##   * бьёт сериями (2–3 удара подряд), доворачивается на замахе за героем и
##     делает шаг всем весом в момент удара — стоять рядом и меняться ударами
##     нельзя, ответ — перекат сквозь удар; издалека — рывок через пол-арены;
##   * на половине здоровья — вторая фаза: рёв, быстрее, серии длиннее.
## Бой ведёт reference_map_level/scripts/boss_arena.gd (fight_active, сброс
## после гибели героя, полоса здоровья на экране).

signal health_changed(hp: int, max_hp: int)
signal posture_changed(value: float, max_value: float, broken: bool)
signal phase_changed(phase: int)
signal defeated

@export var boss_name := "Крестоносец Тёмного Солнца"
## Концентрация за удар героя по телу (рядовой копит её только щитом).
## 4.5 из 100 — пробивается примерно за 22 удара, а не за каждую серию
@export var hit_posture := 4.5
## Рипост, пинок, идеальное парирование бьют по концентрации босса слабее,
## чем по рядовому (иначе пара рипостов — и она пробита)
@export var posture_resist := 0.45
## Сокрушительный удар: доля полного здоровья. Это не добивание — он снимает
## большой кусок, а бой идёт дальше (убить может, только если босс уже на
## последнем издыхании)
@export var crush_damage_frac := 0.25
## Окно для сокрушительного удара после пробитой концентрации, с
@export var break_window := 3.2
## Вторая фаза — с этой доли здоровья
@export var phase2_at := 0.5
## Шаг всем весом в момент удара, px/с (рывковая атака — сильнее)
@export var strike_step := 170.0
@export var lunge_strike_step := 300.0
## Рывок: с какой дистанции и как часто (за решение)
@export var lunge_min := 150.0
@export var lunge_max := 420.0
@export var lunge_chance := 0.28
## Доворот на замахе: доля угла в секунду (поздний перекат наказывается)
@export var windup_turn := 5.0

## Эффекты: дуги, удары о землю, разломы, аура второй фазы
const BossFx := preload("res://enemy/humans/crusader/crusader_boss_fx.gd")
## Дуга клинка появляется за столько секунд до удара
const FX_SWING_LEAD := 0.1

const CLOSE_PATTERNS_1 := [["attack"], ["attack", "attack3"], ["attack2"], ["attack", "attack2"], ["attack3"]]
const CLOSE_PATTERNS_2 := [["attack", "attack3", "attack2"], ["attack2", "attack"], ["attack3", "attack", "attack3"],
	["attack", "attack", "attack2"], ["attack2", "attack2"]]

## Бой идёт (иначе стоит на месте лицом ко входу)
var fight_active := false
var phase := 1
var spawn_point := Vector2.ZERO
var spawn_facing := Vector2.DOWN

var _pattern: Array = []
var _lunging := false
var _lunge_strike := false
var _allow_stun := false
var _roaring := false
var _break_token := 0
# Эффекты: номер удара (прерванный удар не рисует дугу), удар уже отыгран,
# таймеры шагов и шлейфа рывка, аура второй фазы
var _fx_id := 0
var _fx_impacted := true
var _step_t := 0.0
var _ghost_t := 0.0
var _aura: Node2D


func _ready() -> void:
	super()
	add_to_group("boss")
	spawn_point = global_position
	spawn_facing = direction
	# Своя полоса здоровья — на экране (boss_arena.gd), маленькая над головой не нужна
	var ui := get_node_or_null("EnemyUI") as CanvasItem
	if ui:
		ui.visible = false
	# Взмах двуручника шире рядового, и сам он крупнее — по нему проще попасть
	attack_hitbox.scale = Vector2(1.55, 1.45)
	var hurt := get_node_or_null("Hitbox/CollisionShape2D") as Node2D
	if hurt:
		hurt.scale = Vector2(1.3, 1.3)
	_emit_all()


func _emit_all() -> void:
	health_changed.emit(health, max_health)
	posture_changed.emit(posture, max_posture, is_posture_broken)


# ───────────────────────── урон ─────────────────────────

func take_damage(amount: int, source: Node2D = null, unblockable := false) -> void:
	if is_dead:
		return
	if net_replica:
		super(amount, source, unblockable)
		return
	if is_posture_broken and is_instance_valid(source) and source.is_in_group("player"):
		_crushed_by(source)
		return
	var before := health
	super(amount, source, unblockable)
	if health < before and not is_dead:
		_add_posture(hit_posture * _hero_posture_mult(source))
		_check_phase()
	health_changed.emit(health, max_health)


## Удар по концентрации (рипост, пинок, идеальное парирование героя) — без
## шатания: только шкала
func take_posture_damage(amount: float) -> void:
	if net_replica:
		super(amount)
		return
	if is_dead or is_posture_broken:
		return
	_add_posture(amount * posture_resist)


func _add_posture(amount: float) -> void:
	if is_posture_broken:
		return
	posture = minf(posture + amount, max_posture)
	posture_regen_timer = 0.0
	posture_changed.emit(posture, max_posture, false)
	if posture >= max_posture:
		_posture_break()


## Концентрация пробита: шатается и открыт для сокрушительного удара
func _posture_break() -> void:
	if net_replica:
		super()
		return
	if is_dead or is_posture_broken:
		return
	_net_ev("guard_break")
	is_posture_broken = true
	posture = max_posture
	_pattern.clear()
	_lunging = false
	if current_state == State.ATTACK:
		_exit_attack()
	_allow_stun = true
	_change_state(State.STAGGER)
	anim.play("stagger3_" + _get_direction_name(direction), -1, 0.55)
	_break_marker = Juice.guard_break(self)
	posture_changed.emit(posture, max_posture, true)
	_break_token += 1
	var token := _break_token
	var window := break_window
	var hero := get_tree().get_first_node_in_group("player")
	if hero and hero.has_method("execution_window_mult"):
		window *= float(hero.execution_window_mult())
	await get_tree().create_timer(window).timeout
	if token != _break_token or is_dead or not is_posture_broken:
		return
	_end_break()


func _end_break() -> void:
	if is_instance_valid(_break_marker):
		_break_marker.queue_free()
	is_posture_broken = false
	posture = 0.0
	_allow_stun = false
	posture_changed.emit(posture, max_posture, false)
	if current_state == State.STAGGER:
		_change_state(State.CHASE)


## Сокрушительный удар героя по пробитой концентрации: большая доля
## здоровья, тяжёлый отклик (без вспышек света — кровь, пыль, трещина)
func _crushed_by(source: Node2D) -> void:
	_break_token += 1
	if is_instance_valid(_break_marker):
		_break_marker.queue_free()
	player = source
	var dmg := maxi(1, ceili(max_health * crush_damage_frac))
	health = maxi(health - dmg, 0)
	_trigger_damage_flash()
	_play_hurt_sound()
	_net_ev("hurt")
	var dir := _safe_direction(global_position - source.global_position)
	BloodFx.hit(self, source, 3.0)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			BloodFx.hit(self, source, 2.2))
	Juice.freeze(0.12)
	Juice.slow(0.2, 0.9, 0.5)
	Juice.zoom_punch(0.14, 0.45)
	Juice.pulse("vignette", 0.6, 0.45)
	Juice.kick(dir, 7.0)
	Juice.shake(5.0)
	Juice.ground_crack(global_position + Vector2(0, 14), 0.8)
	_play_blade_impact(source)
	var magic = source.get("magic")
	if magic and magic.has_method("on_execution"):
		magic.on_execution()
	is_posture_broken = false
	posture = 0.0
	posture_changed.emit(posture, max_posture, false)
	health_changed.emit(health, max_health)
	if health <= 0:
		is_dead = true
		_change_state(State.DEAD)
		return
	var was := phase
	_check_phase()
	if phase != was:
		return  # вместо шатания — рёв второй фазы
	# Удар его потряс: короткое шатание, и снова в бой
	_allow_stun = true
	_change_state(State.STAGGER)
	anim.play("stagger_" + _get_direction_name(direction), -1, 0.8)


## Вспышка попадания: белый всполох и тёмно-красный отсвет — видно, что
## удар прошёл, хотя босс не дрогнул
func _trigger_damage_flash() -> void:
	var sp := $AnimatedSprite2D as CanvasItem
	if _telegraph_tween:
		_telegraph_tween.kill()
	sp.modulate = Color(4.0, 3.6, 3.2, 1.0)
	var tw := create_tween()
	tw.tween_property(sp, "modulate", Color(1.9, 0.55, 0.5, 1.0), 0.06)
	tw.tween_property(sp, "modulate", _rest_modulate, 0.22)


# Не станится, не отлетает, не шатается от рядовых ударов
func _pushes(_source: Node) -> bool:
	return false


func _trigger_stagger() -> void:
	pass


func lightning_stun(_from: Vector2) -> void:
	pass


func _change_state(new_state: State) -> void:
	if (new_state == State.HIT_STUN or new_state == State.STAGGER) and not _allow_stun:
		return
	if new_state != State.STAGGER:
		_allow_stun = false
	super(new_state)
	if new_state == State.ATTACK and current_state == State.ATTACK and not net_replica:
		_fx_windup()


func _on_animation_finished(anim_name: StringName) -> void:
	if net_replica:
		return
	var n := String(anim_name)
	if n.begins_with("stagger"):
		# Пробитая концентрация — стоит, шатаясь, до конца окна (или удара)
		if is_posture_broken:
			return
		_allow_stun = false
		_change_state(State.CHASE)
		return
	if n.begins_with("taunt"):
		_roaring = false
		_change_state(State.CHASE)
		return
	if n.begins_with("attack") and current_state == State.ATTACK:
		# Серия: следующий удар — сразу, если герой ещё рядом
		if not _pattern.is_empty() and player and is_instance_valid(player) \
				and global_position.distance_to(player.global_position) < attack_range * 2.4:
			_exit_attack()
			attack_cooldown_timer = 0.0
			can_attack = true
			current_state = State.IDLE
			_change_state(State.ATTACK)
			return
		_pattern.clear()
		_lunge_strike = false
		_exit_attack()
		_change_state(State.CHASE)
		return
	super(anim_name)


# ───────────────────────── поведение ─────────────────────────

func _decide_state() -> void:
	if net_replica or is_dead:
		return
	if not fight_active:
		if current_state != State.IDLE and current_state != State.WANDER:
			_change_state(State.WANDER)
		return
	if current_state in [State.ATTACK, State.STAGGER, State.HIT_STUN, State.DEAD, State.EVADE]:
		return
	var hero := _hero()
	if hero == null:
		return
	player = hero
	see_player = true
	var d := global_position.distance_to(hero.global_position)
	if can_attack and d <= attack_range + 6.0:
		_pattern = (CLOSE_PATTERNS_2 if phase == 2 else CLOSE_PATTERNS_1).pick_random().duplicate()
		_change_state(State.ATTACK)
	elif can_attack and not _lunging and d >= lunge_min and d <= lunge_max and randf() < lunge_chance:
		_lunging = true
		_change_state(State.CHASE)
	else:
		_change_state(State.CHASE)


func _hero() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for h in get_tree().get_nodes_in_group("player"):
		if not (h is Node2D) or (h.has_method("is_dead") and h.is_dead()):
			continue
		var dd := global_position.distance_to((h as Node2D).global_position)
		if dd < bd:
			bd = dd
			best = h
	return best


## Вне боя (fight_active = false): вернуться на свою точку и стоять лицом ко входу
func _state_wander(delta: float) -> void:
	var to := spawn_point - global_position
	if to.length() > 10.0:
		nav_agent.target_position = spawn_point
		var dir := _nav_direction_to(to.normalized())
		_turn_toward(dir, direction_smoothness * delta)
		move_velocity = direction * walk_speed
		_play_animation("walk")
	else:
		move_velocity = Vector2.ZERO
		_turn_toward(spawn_facing, 4.0 * delta)
		_play_animation("idle")


func _state_chase(delta: float) -> void:
	var hero := _hero()
	if hero == null:
		_change_state(State.WANDER)
		return
	player = hero
	var to := hero.global_position - global_position
	var d := to.length()
	if _lunging:
		# Рывок через арену — бегом и сразу в удар сверху
		if d <= attack_range * 1.7:
			_lunging = false
			_lunge_strike = true
			_pattern = ["attack2"]
			if phase == 2:
				_pattern.append("attack")
			attack_cooldown_timer = 0.0
			can_attack = true
			_change_state(State.ATTACK)
			return
		_move_to(hero.global_position, run_speed * 1.45, "run", delta)
		return
	if d <= attack_range:
		# Рядом, но удар ещё не готов — стоит лицом к герою, чуть отступая
		_turn_toward(to / maxf(d, 0.001), direction_smoothness * delta)
		move_velocity = -direction * walk_speed * 0.35 if d < attack_range * 0.6 else Vector2.ZERO
		_play_animation("idle")
		return
	if d > 170.0:
		_move_to(hero.global_position, run_speed, "run", delta)
	else:
		_move_to(hero.global_position, walk_speed * 1.25, "walk", delta)


func _move_to(target: Vector2, speed: float, clip: String, delta: float) -> void:
	nav_agent.target_position = target
	var to := target - global_position
	var dir := _nav_direction_to(to.normalized())
	direction = direction.lerp(dir, clampf(direction_smoothness * delta, 0.0, 1.0)).normalized()
	move_velocity = direction * speed
	_play_animation(clip)


## Удар: на замахе доворачивается за героем (меняя сторону клипа с того же
## кадра), в момент удара — шаг вперёд всем весом
func _state_attack(delta: float) -> void:
	var lead := _attack_impact_time - 0.16
	if not attack_started and state_time < lead and player and is_instance_valid(player):
		var want := _safe_direction(player.global_position - global_position, direction)
		var nd := direction.slerp(want, clampf(windup_turn * delta, 0.0, 1.0)).normalized()
		var old_name := _get_direction_name(direction)
		direction = nd
		var new_name := _get_direction_name(direction)
		if new_name != old_name:
			var clip := current_attack_anim + "_" + new_name
			if anim.has_animation(clip):
				var pos := anim.current_animation_position
				anim.play(clip, -1, anim.get_playing_speed())
				anim.seek(pos, true)
	super(delta)
	if attack_started and not _fx_impacted and current_state == State.ATTACK:
		_fx_impacted = true
		_fx("impact", [current_attack_anim, direction, phase, _lunge_strike])
	if state_time >= lead and state_time <= _attack_impact_time + 0.06:
		move_velocity = direction * (lunge_strike_step if _lunge_strike else strike_step)


func _pick_attack_anim() -> String:
	var pick: String = "attack"
	if not _pattern.is_empty():
		pick = String(_pattern.pop_front())
	else:
		pick = attack_pool[randi() % attack_pool.size()]
	attack_impact_fraction = float(impact_fractions.get(pick, _default_impact))
	_damage_mult = float(damage_mults.get(pick, 1.0)) * (1.15 if phase == 2 else 1.0)
	return pick


# ───────────────────────── фазы ─────────────────────────

func _check_phase() -> void:
	if phase == 1 and health <= int(max_health * phase2_at) and not is_dead:
		phase = 2
		_enter_phase2()


## Рёв: стоит и ревёт (клип taunt), воздух дрожит — дальше быстрее и злее
func _enter_phase2() -> void:
	phase_changed.emit(2)
	attack_cooldown = 0.95
	attack_speed_scale = 0.95
	lunge_chance = 0.45
	walk_speed *= 1.15
	run_speed *= 1.15
	_rest_modulate = Color(1.12, 0.9, 0.88)
	_fx("phase", [2])
	if is_posture_broken:
		return
	_roar()


## Рёв (начало боя, вторая фаза): стоит, ревёт, воздух дрожит
func _roar() -> void:
	_pattern.clear()
	_lunging = false
	if current_state == State.ATTACK:
		_exit_attack()
	_roaring = true
	current_state = State.EVADE
	state_time = 0.0
	move_velocity = Vector2.ZERO
	anim.play("taunt_" + _get_direction_name(direction), -1, 1.1)
	Juice.shake(4.0)
	Juice.pulse("vignette", 0.5, 0.6)
	Juice.shockwave(global_position + Vector2(0, -10), 120.0, 0.6, 0.015)
	_play_enemy_sound(voice_audio, ENEMY_GRUNT_SOUNDS.pick_random())
	_fx("roar", [phase])


func _state_evade(_delta: float) -> void:
	move_velocity = Vector2.ZERO
	if not _roaring or state_time > 2.5:
		_roaring = false
		_change_state(State.CHASE)


# ───────────────────────── бой ─────────────────────────

func start_fight() -> void:
	fight_active = true
	var hero := _hero()
	if hero:
		player = hero
		see_player = true
		direction = _safe_direction(hero.global_position - global_position, direction)
	_roar()
	_emit_all()


## Герой пал — бой заново: здоровье, концентрация, фаза, на свою точку
func reset_fight() -> void:
	fight_active = false
	_break_token += 1
	if is_instance_valid(_break_marker):
		_break_marker.queue_free()
	if current_state == State.ATTACK:
		_exit_attack()
	_pattern.clear()
	_lunging = false
	_lunge_strike = false
	_roaring = false
	is_posture_broken = false
	posture = 0.0
	health = max_health
	if phase == 2:
		phase = 1
		attack_cooldown = _base["attack_cooldown"]
		attack_speed_scale = _base["attack_speed_scale"]
		lunge_chance = _base["lunge_chance"]
		walk_speed = _base["walk_speed"]
		run_speed = _base["run_speed"]
		_rest_modulate = Color.WHITE
	_fx("phase", [1])
	player = null
	see_player = false
	_allow_stun = false
	# Герой далеко (у костра) — сразу на место, мог и уснуть (EnemySleep)
	global_position = spawn_point
	direction = spawn_facing
	knockback_velocity = Vector2.ZERO
	move_velocity = Vector2.ZERO
	_change_state(State.WANDER)
	_emit_all()


var _base := {}


func _enter_tree() -> void:
	if _base.is_empty():
		_base = {"attack_cooldown": attack_cooldown, "attack_speed_scale": attack_speed_scale,
			"lunge_chance": lunge_chance, "walk_speed": walk_speed, "run_speed": run_speed}


func _on_dead() -> void:
	defeated.emit()
	Juice.slow(0.25, 1.4, 0.6)
	_set_aura(false)
	BossFx.death(self)
	super()


# Копия босса у клиента в коопе тоже сообщает о победе — конец демо у всех
func _net_die() -> void:
	if not is_dead:
		defeated.emit()
		_set_aura(false)
		BossFx.death(self)
	super()


# ───────────────────────── эффекты ─────────────────────────

## Начало удара: блик, всполох, метка удара сверху; дуга — к моменту удара
func _fx_windup() -> void:
	_fx_id += 1
	_fx_impacted = false
	var id := _fx_id
	_fx("windup", [current_attack_anim, direction, phase, _attack_impact_time, _lunge_strike])
	get_tree().create_timer(maxf(0.0, _attack_impact_time - FX_SWING_LEAD)).timeout.connect(_fx_swing.bind(id))


func _fx_swing(id: int) -> void:
	if id == _fx_id and current_state == State.ATTACK and not is_dead:
		_fx("swing", [current_attack_anim, direction, phase])


## Эффект здесь и у копий клиентов в коопе (enemy.gd::net_event → net_skel_fx)
func _fx(kind: String, a: Array) -> void:
	_fx_play(kind, a)
	_net_ev("bfx", [kind, a])


func _fx_play(kind: String, a: Array) -> void:
	match kind:
		"windup":
			BossFx.windup(self, String(a[0]), a[1], int(a[2]), float(a[3]), bool(a[4]))
		"swing":
			BossFx.swing(self, String(a[0]), a[1], int(a[2]))
		"impact":
			BossFx.impact(self, String(a[0]), a[1], int(a[2]), bool(a[3]))
		"roar":
			BossFx.roar(self, int(a[0]))
		"phase":
			_set_aura(int(a[0]) == 2)


func net_skel_fx(kind: String, arg) -> void:
	if kind == "bfx" and arg is Array and arg.size() == 2:
		_fx_play(String(arg[0]), arg[1])


func _set_aura(on: bool) -> void:
	if on and not is_instance_valid(_aura):
		_aura = BossFx.aura(self)
	elif not on and is_instance_valid(_aura):
		_aura.queue_free()
		_aura = null


## Шаги бегом — пыль из-под сапог, рывок — тёмно-красный шлейф (по клипу,
## так что и у копии клиента)
func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead:
		return
	var clip := String(anim.current_animation)
	if clip.begins_with("run"):
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.2 if _lunging else 0.3
			BossFx.step(self, direction, phase, 1.3 if _lunging else 1.0)
	else:
		_step_t = 0.0
	if _lunging and not net_replica:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.06
			BossFx.ghost(self)
