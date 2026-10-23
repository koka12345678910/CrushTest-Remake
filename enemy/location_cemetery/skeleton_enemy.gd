extends "res://enemy/enemy.gd"
## Скелеты кладбища (enemy/location_cemetery). Вся основа — enemy.gd
## (стая, блок, концентрация, добивание); здесь только то, чем виды
## отличаются друг от друга. Вид — kind, цифры — в сцене каждого вида:
##   GRUNT   — обычный скелет, «мясо»: мало здоровья, без блока, прёт в лоб
##   SHIELD  — щитовик: стоит в щите даже один, изредка выходит на удар,
##             после блока может отбить щитом и пнуть (PARRY -> COUNTER)
##   BRUTE   — с топором: много здоровья, крупнее, медленные тяжёлые удары,
##             замах не сбивается, оглушает только каждый poise_hits-й удар
##   DUELIST — ловкий: дерётся как игрок — кружит вокруг стрейфом, бьёт
##             сериями, уходит перекатом и парирует клинком с ответным ударом
## Анимации собирает tools/build_skeleton_anims.gd.

enum Kind { GRUNT, SHIELD, BRUTE, DUELIST }
@export var kind := Kind.GRUNT

## Из каких атак выбирать (имена клипов без направления)
@export var attack_pool: PackedStringArray = ["attack", "attack2", "attack3"]
## Можно ли вставать в осторожную стойку в стае. Мясу — нет: оно просто прёт
@export var uses_guard := true
## Стойка со щитом и в одиночку, а не только в стае (щитовик)
@export var always_guard := false

@export_group("Танк")
## Замах не сбивается ударами, вне замаха оглушает только каждый poise_hits-й
@export var hyper_armor := false
@export var poise_hits := 3
## Доля отброса от ударов, которая доходит до врага (тяжёлый — почти стоит)
@export_range(0.0, 1.0) var knockback_taken := 1.0
## Своей анимации смерти нет — падает программно (поворот + проседание)
@export var fake_death := false
## Сколько длится оглушение от удара (у базы — 1 с; тяжёлому — ровно на
## реакцию, чтобы серия ударов не держала его в оглушении бесконечно)
@export var hit_stun_time := 1.0
## Ровное тяжёлое преследование вместо базового: медленный поворот, плавный
## разгон, шаг; бег — только когда игрок дальше steady_run_from (с запасом,
## чтобы не мигать между шагом и бегом)
@export var steady_pursuit := false
@export var steady_run_from := 170.0
@export var steady_turn := 4.0

@export_group("Ловкий")
@export var can_evade := false
## Реакция на начало замаха игрока: шанс уйти перекатом / поднять клинок
@export_range(0.0, 1.0) var evade_chance := 0.35
@export_range(0.0, 1.0) var sword_parry_chance := 0.35
@export var evade_speed := 210.0
@export var evade_cooldown := 2.2
## Сколько секунд клинок ждёт удара, прежде чем парирование «прогорит»
@export var sword_parry_hold := 0.45
## Эффекты боя (duelist_fx.gd): дуги клинка, блеск глаз перед ударом,
## призрачный шлейф рывка и переката, пыль, блик парирования
@export var combat_fx := false
## Ударов в серии (1 — без серий)
@export var combo_max := 1
## Шаг вперёд на замахе — враг доходит ударом, а не бьёт в воздух
@export var lunge_speed := 0.0
## Кружить вокруг игрока, пока атака на перезарядке
@export var strafes := false
@export var strafe_distance := 70.0
@export var strafe_speed_mult := 0.85

@export_group("Атака с разбега")
## Окно дистанции, с которой враг может броситься в атаку с разбега
@export var run_attack_range := Vector2.ZERO
@export var run_attack_lunge := 230.0

## Момент удара (доля замаха) по атакам; чего нет — attack_impact_fraction
const IMPACT := {
	Kind.GRUNT: {"attack": 0.47, "attack2": 0.47, "attack3": 0.47},
	Kind.SHIELD: {"attack": 0.47, "attack2": 0.47, "attack3": 0.75},
	Kind.BRUTE: {"attack": 0.47, "attack2": 0.5, "attack3": 0.5, "run_attack": 0.5},
	Kind.DUELIST: {"attack": 0.45, "attack2": 0.45, "attack3": 0.45, "run_attack": 0.45},
}
## Множитель урона по атакам (рубящий сверху у танка бьёт сильнее)
const DAMAGE_MULT := {
	Kind.BRUTE: {"attack2": 1.25, "run_attack": 1.15},
}
const BONE_COLOR := Color(0.86, 0.82, 0.72)
const DuelistFx := preload("res://enemy/location_cemetery/duelist_fx.gd")
## Дуга появляется чуть раньше засчитанного удара — вместе со смазанными
## кадрами взмаха на спрайте
const FX_SWING_LEAD := 0.09

var _fx_attack_id := 0
var _fx_power := 1.0
var _ghost_t := 0.0

var _damage_mult := 1.0
var _forced_attack := ""
var _combo_left := 0
var _combo_step := 0
## true, пока следующий удар серии входит в ATTACK (серия не начинается заново)
var _chaining := false
var _poise_count := 0
var _armor_hit := false
var _react_timer := 0.0
var _evade_cd := 0.0
var _evade_dir := Vector2.ZERO
var _evade_time := 0.6
var _parry_hold := 0.0
var _strafe_sign := 1.0
var _strafe_flip_timer := 0.0
var _gap_timer := 0.0
## Отшатывание на удар: сдвиг спрайта (px) и наклон (рад)
@export var flinch_px := 3.0
@export var flinch_tilt := 0.1
var _flinch_tween: Tween
var _sprite_rest_pos := Vector2.ZERO


## Приглушить рыжий щит в тёмное дерево (sprite_detail ochre_mute): упавший
## рядом с трупом круглый щит читался как монета, которую не подобрать
@export_range(0.0, 1.0) var ochre_mute := 0.0
## Копии материала с приглушённой охрой — одна на исходный материал, общая
## для всех щитовиков (не своя на каждого)
static var _muted_materials := {}


func _ready() -> void:
	super()
	var sp: AnimatedSprite2D = $AnimatedSprite2D
	_sprite_rest_pos = sp.position
	if ochre_mute > 0.0 and sp.material is ShaderMaterial:
		var key := "%s/%s" % [sp.material.resource_path, ochre_mute]
		if not _muted_materials.has(key):
			var m: ShaderMaterial = sp.material.duplicate()
			m.set_shader_parameter("ochre_mute", ochre_mute)
			_muted_materials[key] = m
		sp.material = _muted_materials[key]


func _physics_process(delta: float) -> void:
	_react_timer = maxf(0.0, _react_timer - delta)
	_evade_cd = maxf(0.0, _evade_cd - delta)
	_gap_timer = maxf(0.0, _gap_timer - delta)
	super(delta)
	if combat_fx:
		_update_ghost_trail(delta)


## Шлейф призрачных силуэтов: пока катится и пока несётся в удар с разбега
func _update_ghost_trail(delta: float) -> void:
	var dashing := current_state == State.EVADE \
			or (current_state == State.ATTACK and current_attack_anim == "run_attack" and not attack_started)
	if not dashing:
		_ghost_t = 0.0
		return
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.05
		DuelistFx.ghost(self, 0.22 if current_state == State.EVADE else 0.32)


## Вход в удар: блеск глаз сразу, дуга клинка — к моменту удара. Прервали
## (оглушили, убили, сменилась атака) — дуга не появится
func _start_swing_fx() -> void:
	_fx_attack_id += 1
	var id := _fx_attack_id
	var power := _fx_power
	_fx_power = 1.0
	DuelistFx.eye_glint(self)
	if current_attack_anim == "run_attack":
		DuelistFx.dust(self, direction, 6)
	# Метод, а не лямбда: если ловкача уже удалили, движок сам снимет связь
	get_tree().create_timer(maxf(0.0, _attack_impact_time - FX_SWING_LEAD)).timeout.connect(
			_fire_swing_fx.bind(id, power))


func _fire_swing_fx(id: int, power: float) -> void:
	if current_state == State.ATTACK and _fx_attack_id == id and not is_dead:
		DuelistFx.swing(self, current_attack_anim, direction, power)


func get_attack_damage() -> int:
	return int(round(super() * _damage_mult))


# ===================== ВЫБОР АТАКИ =====================

func _pick_attack_anim() -> String:
	var pick := _forced_attack
	_forced_attack = ""
	if pick == "":
		if combo_max > 1:
			# Серия идёт по порядку, как комбо игрока: дуга, обратная дуга, сверху
			pick = attack_pool[_combo_step % attack_pool.size()]
		else:
			pick = attack_pool[randi() % attack_pool.size()]
	_combo_step += 1
	attack_impact_fraction = IMPACT.get(kind, {}).get(pick, attack_impact_fraction)
	_damage_mult = DAMAGE_MULT.get(kind, {}).get(pick, 1.0)
	return pick


func _change_state(new_state: State) -> void:
	# Танк: удар не сбивает замах, а вне замаха оглушает лишь каждый
	# poise_hits-й. Пробитая концентрация и молния оглушают как обычно
	if _armor_hit and new_state == State.HIT_STUN and not is_posture_broken:
		if current_state == State.ATTACK:
			return
		_poise_count += 1
		if _poise_count < poise_hits:
			return
		_poise_count = 0
	# Новая серия ударов — только при «свежем» входе в атаку
	if new_state == State.ATTACK and not _chaining and current_state != State.ATTACK:
		_combo_left = randi_range(1, combo_max) if combo_max > 1 else 1
		_combo_step = 0
	super(new_state)
	if combat_fx and new_state == State.ATTACK and current_state == State.ATTACK:
		_start_swing_fx()
	if new_state == State.HIT_STUN and current_state == State.HIT_STUN and not is_posture_broken:
		hit_stun_timer = hit_stun_time
	elif new_state == State.CHASE:
		_chase_speed = move_velocity.length()
	if new_state == State.DEAD and fake_death:
		_fall_down()


# ===================== СТАЯ / СТОЙКА =====================

func _update_pack_role() -> void:
	super()
	if not uses_guard and pack_role == PackRole.CAUTIOUS:
		pack_role = PackRole.SOLO
	elif always_guard and pack_role == PackRole.SOLO and see_player \
			and player and is_instance_valid(player):
		pack_role = PackRole.CAUTIOUS


# ===================== ПОГОНЯ =====================

func _state_chase(delta: float) -> void:
	if not player or not is_instance_valid(player) or is_ranged_alert:
		super(delta)
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()

	# Бросок с разбега: из окна дистанции — сразу в атаку с рывком
	if run_attack_range != Vector2.ZERO and can_attack and _gap_timer <= 0.0 \
			and dist >= run_attack_range.x and dist <= run_attack_range.y:
		_gap_timer = 1.2
		if randf() < 0.45 and anim.has_animation("run_attack_down"):
			_forced_attack = "run_attack"
			_change_state(State.ATTACK)
			return

	if strafes and not can_attack and dist < strafe_distance + 50.0 and dist > 0.001:
		_strafe_around(to_player / dist, dist, delta)
		return
	if steady_pursuit:
		_steady_chase(to_player, dist, delta)
		return
	super(delta)


var _chase_speed := 0.0
var _steady_running := false

## Тяжёлое преследование: базовая погоня переключает шаг/бег по скорости
## бегства игрока каждые доли секунды и мгновенно доворачивает — у крупного
## врага это читалось как дёрганье. Здесь всё плавно и с запасом
func _steady_chase(to_player: Vector2, dist: float, delta: float) -> void:
	if not _is_player_in_range(_effective_vision_range()):
		_change_state(State.WANDER)
		return
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0:
		target_refresh_timer = target_refresh_interval
		nav_agent.target_position = player.global_position
	var dir := to_player / maxf(dist, 0.001)

	# На дистанции удара — плавно останавливается лицом к игроку и ждёт
	# отката атаки (сам удар запускает _decide_state)
	if dist <= preferred_distance + 6.0:
		_chase_speed = move_toward(_chase_speed, 0.0, walk_speed * 4.0 * delta)
		_turn_toward(dir, steady_turn * delta)
		move_velocity = direction * _steady_velocity(_chase_speed, delta)
		if _chase_speed < 2.0:
			_play_animation("idle")
		else:
			_play_animation("walk", clampf(_chase_speed / walk_speed, 0.6, 1.0))
		return

	if dist > steady_run_from:
		_steady_running = true
	elif dist < steady_run_from - 60.0:
		_steady_running = false
	var target_speed := run_speed if _steady_running else walk_speed
	var move_dir := _nav_direction_to(dir)
	_turn_toward(move_dir, steady_turn * delta)
	# На повороте сбавляет ход, разгон — плавный
	var align := clampf(direction.dot(move_dir), 0.0, 1.0)
	# Подходя к дистанции удара, сбавляет шаг — замах начинается почти с
	# места, а не с разбега "как вкопанный"
	var arrive := clampf((dist - preferred_distance) / 45.0, 0.55, 1.0)
	_chase_speed = move_toward(_chase_speed, target_speed * lerpf(0.4, 1.0, align) * arrive, walk_speed * 2.5 * delta)
	move_velocity = direction * _steady_velocity(_chase_speed, delta)
	# Бег или шаг — по фактической скорости: тормозящий у цели не "бежит на месте"
	var running := _chase_speed > walk_speed * 1.15
	_play_animation("run" if running else "walk", clampf(_chase_speed / (run_speed if running else walk_speed), 0.6, 1.0))


## База после состояния каждый кадр гасит скорость трением (friction) —
## на малой скорости от шага почти ничего не оставалось, и тяжёлый враг
## у цели еле полз. Добавляем ровно то, что трение отнимет
func _steady_velocity(speed: float, delta: float) -> float:
	return speed + friction * delta if speed > 0.5 else 0.0


## Кружит вокруг игрока лицом к нему, держась на strafe_distance — ждёт,
## пока откатится атака. Направление обхода иногда меняет; упёрся — сразу
func _strafe_around(dir: Vector2, dist: float, delta: float) -> void:
	_turn_toward(dir, direction_smoothness * delta)
	_strafe_flip_timer -= delta
	if _strafe_flip_timer <= 0.0 or get_slide_collision_count() > 0:
		_strafe_flip_timer = randf_range(1.0, 2.4)
		_strafe_sign = -_strafe_sign if randf() < 0.6 or get_slide_collision_count() > 0 else _strafe_sign
	# rotated(+PI/2) на экране (y вниз) — шаг по часовой
	var tangent := dir.rotated(PI * 0.5 * _strafe_sign)
	var radial := clampf((dist - strafe_distance) / 30.0, -1.0, 1.0)
	move_velocity = (tangent + dir * radial * 0.7).normalized() * walk_speed * strafe_speed_mult
	if radial < -0.6:
		_play_animation("backwards")
	else:
		_play_animation("strafe_cw" if _strafe_sign > 0.0 else "strafe_ccw")


# ===================== АТАКА =====================

func _state_attack(delta: float) -> void:
	super(delta)
	if current_state != State.ATTACK or attack_started:
		return
	# Шаг на замахе: доходим ударом до цели, но не наезжаем на неё вплотную
	var speed := run_attack_lunge if current_attack_anim == "run_attack" else lunge_speed
	if speed > 0.0 and player and is_instance_valid(player) \
			and global_position.distance_to(player.global_position) > attack_range * 0.6:
		move_velocity = direction * speed


func _on_animation_finished(anim_name: StringName) -> void:
	# Ловкий держит клинок поднятым, пока не прилетит удар (_state_parry)
	if can_evade and anim_name.begins_with("parry_"):
		return
	var is_attack_clip := anim_name.begins_with("attack") or anim_name.begins_with("run_attack")
	if is_attack_clip and current_state == State.ATTACK:
		_combo_left -= 1
		if _combo_left > 0 and _is_player_in_range(attack_range * 1.6):
			# Следующий удар серии без паузы (IDLE между — чтобы вход в ATTACK
			# сработал заново и выбрал следующий клип)
			_exit_attack()
			_chaining = true
			_change_state(State.IDLE)
			_change_state(State.ATTACK)
			_chaining = false
			return
		_combo_left = 0
		if anim_name.begins_with("run_attack"):
			# База узнаёт конец атаки по приставке "attack" — рывок закрываем сами
			_exit_attack()
			_change_state(State.IDLE if _is_player_in_range(attack_range) else State.CHASE)
			return
	super(anim_name)


# ===================== ЗАЩИТА ЛОВКОГО =====================

## База зовёт это, когда игрок замахнулся рядом. Ловкий не стоит в блоке:
## либо уходит перекатом, либо ловит удар клинком, либо принимает его
func _try_block() -> void:
	if not can_evade:
		super()
		return
	if _react_timer > 0.0 or is_posture_broken or is_player_berserk:
		return
	_react_timer = 0.7
	var r := randf()
	if r < evade_chance and _evade_cd <= 0.0:
		_start_evade()
	elif r < evade_chance + sword_parry_chance:
		_start_parry()
		_parry_hold = sword_parry_hold
		if combat_fx:
			DuelistFx.parry_ready(self, _dir_to(player))


func _state_parry(delta: float) -> void:
	super(delta)
	if not can_evade:
		return
	_parry_hold -= delta
	if _parry_hold <= 0.0:
		# Удар так и не прилетел — опускаем клинок
		is_parrying = false
		_change_state(State.CHASE)


func _start_evade() -> void:
	var away := -_dir_to(player)
	# В сторону и чуть назад — не строго от игрока, иначе читается как бегство
	_evade_dir = away.rotated(randf_range(0.7, 1.4) * (1.0 if randf() < 0.5 else -1.0))
	_evade_cd = evade_cooldown
	is_blocking = false
	_change_state(State.EVADE)
	direction = _evade_dir
	_play_animation("roll")
	_evade_time = anim.current_animation_length if anim.current_animation_length > 0.0 else 0.6
	if combat_fx:
		DuelistFx.dust(self, _evade_dir)


func _state_evade(_delta: float) -> void:
	var k := clampf(state_time / _evade_time, 0.0, 1.0)
	move_velocity = _evade_dir * evade_speed * (1.0 - k * k)
	if state_time >= _evade_time:
		if combat_fx:
			DuelistFx.dust(self, _evade_dir, 3)
		if player and is_instance_valid(player):
			direction = _dir_to(player)
		_change_state(State.CHASE)


func take_damage(amount: int, source: Node2D = null, unblockable := false) -> void:
	if is_dead:
		return
	if can_evade:
		# Перекат — неуязвимость
		if current_state == State.EVADE:
			return
		# Удар пойман клинком: игрок сбит с ритма (receive_parry), а скелет
		# тут же отвечает своим ударом — как парирование игрока
		if is_parrying and not unblockable and not is_player_berserk \
				and _is_guarding_against(source) and is_instance_valid(source):
			is_parrying = false
			if source.has_method("receive_parry"):
				source.receive_parry(pummel_posture_damage)
			play_parry_vfx()
			Juice.hit(self, source, 0, false, true)
			if combat_fx:
				DuelistFx.parry_caught(self, _dir_to(source))
				# Ответный удар — ярче и с искрами
				_fx_power = 1.35
			_forced_attack = attack_pool[0]
			_change_state(State.IDLE)
			_change_state(State.ATTACK)
			return
	_armor_hit = hyper_armor
	var hp_before := health
	super(amount, source, unblockable)
	_armor_hit = false
	knockback_velocity *= knockback_taken
	if health < hp_before and not is_dead:
		_flinch(source)


## Отшатывание на каждый прошедший удар — поверх любой анимации: короткий
## рывок спрайта от удара с наклоном и возврат. Так удар виден, даже когда
## враг не оглушён (броня танка, удар посреди замаха)
func _flinch(source: Node2D) -> void:
	var sp: AnimatedSprite2D = $AnimatedSprite2D
	var away := -_dir_to(source) if is_instance_valid(source) else -direction
	if _flinch_tween:
		_flinch_tween.kill()
	sp.position = _sprite_rest_pos + away * flinch_px
	# Посреди своего замаха не наклоняем — удар перекашивало
	sp.rotation = 0.0 if current_state == State.ATTACK else clampf(away.x, -1.0, 1.0) * flinch_tilt
	_flinch_tween = create_tween().set_parallel()
	_flinch_tween.tween_property(sp, "position", _sprite_rest_pos, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(sp, "rotation", 0.0, 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ===================== БЕЗ КРОВИ =====================

## Скелет не кровит: от удара летят костяная крошка и пыль
func _play_bloodless_hit(source: Node2D, amount: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var dir := -_dir_to(source) if is_instance_valid(source) else Vector2.UP
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = int(clampf(8.0 + amount * 4.0, 8.0, 26.0))
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = 55.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0 + amount * 20.0
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = BONE_COLOR
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(0.7, 0.68, 0.62, 0))
	p.color_ramp = ramp
	root.add_child(p)
	p.global_position = global_position + Vector2(0, -10)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Нет листа смерти — оседает и заваливается набок
func _fall_down() -> void:
	var sp: AnimatedSprite2D = $AnimatedSprite2D
	if _flinch_tween:
		_flinch_tween.kill()
	sp.position = _sprite_rest_pos
	var side := -1.0 if direction.x < 0.0 else 1.0
	var t := create_tween().set_parallel()
	t.tween_property(sp, "rotation", side * 1.35, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(sp, "position", sp.position + Vector2(side * 10.0, 12.0), 0.45).set_ease(Tween.EASE_IN)
