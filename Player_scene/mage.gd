extends "res://Player_scene/character_base.gd"
## Маг. Движение, направления и серия ударов — в общей базе
## (character_base.gd), здесь только то, что отличает его от остальных.
##
## Вид — Frost-маг (Character/Mage_Frost), анимации собирает
## tools/build_mage_anims.gd в mage_frames.tres / mage_anims.tres. Набор клипов
## почти как у лучника (Idle_/Walk_/Run_/Attack_/Attack_2_/Take_Damage_ на 8
## направлений); ходьба спиной — Backwards_. Клипа разворота у Frost-мага нет —
## база тогда поворачивает его мгновенно. Цель (фокус) — из базы:
## радиус взятия у мага, как у лучника, большой (snap_radius в mage.tscn) —
## он бьёт издалека. Монет маг не копит (collects_gold = false): его валюта —
## души.
##
## Скорости и длину серии не переопределяем кодом: они объявлены как @export в
## базе, и правильное место их крутить — инспектор в mage.tscn. Присваивание в
## _ready() затирало бы то, что выставлено в сцене

const FireballScript := preload("res://Player_scene/mage_fireball.gd")


func _ready() -> void:
	super()
	# По этой группе кровь от его заклинаний брызжет "магическим" видом —
	# во все стороны и темнее, обожжённая (VFX/VFX_scene/blood_fx.gd::kind_from)
	add_to_group("caster_player")

## Первая атака (Attack_, лист Attack1) — синий огненный шар. Пауза до вылета
## подогнана под анимацию: маг выбрасывает руку вперёд на 6-м кадре из 15
## (15 к/с, клип 1с)
@export var fireball_cast_delay := 0.4
## Откуда вылетает шар — смещение от центра тела в сторону взгляда
@export var fireball_offset := 18.0


## Зовётся базой (start_attack) сразу после запуска клипа удара. aim — цель,
## на которую развернулось наведение (фокус > ближайший враг > null)
func _on_attack_started(step: int, aim: Node2D) -> void:
	if step == 2:
		_cast_sweep()
		return
	if step == 3:
		_cast_pulses()
		return
	# step 0 — удар на бегу (Run_Attack_, лист AttackRun): тот же огненный шар
	if step != 1 and step != 0:
		return
	var clip := anim.current_animation
	await get_tree().create_timer(fireball_cast_delay).timeout
	# Пока маг замахивался, его могли перебить (перекат, удар) или убить —
	# тогда клип удара уже сменился и шар не выпускаем
	if is_dead() or anim.current_animation != clip:
		return
	var dir: Vector2
	if is_instance_valid(aim) and not aim.is_dead:
		dir = (aim.global_position - global_position).normalized()
	else:
		dir = direction_to_vector(last_direction)
		if dir == Vector2.ZERO:
			dir = facing_dir
	var ball: Area2D = FireballScript.new()
	get_tree().current_scene.add_child(ball)
	ball.launch(global_position + dir * fireball_offset, dir, self)


const ScorchScript := preload("res://Player_scene/mage_scorch.gd")

## Вторая атака (Attack_2_, ПКМ) — выжигание: голубой огонь вспыхивает у ног
## мага и нарастающе ползёт вперёд конусом (mage_scorch.gd). Враг горит, когда
## до него дошёл фронт, а не весь сектор разом. Поджиг — на 4-м кадре из 15
## листа Attack5 (0.27с), когда сила срывается с руки мага
@export var sweep_start_delay := 0.27
@export var sweep_damage := 1
@export var sweep_knockback := 180.0


func _cast_sweep() -> void:
	var clip := anim.current_animation
	var facing := facing_dir
	await get_tree().create_timer(sweep_start_delay).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var scorch: Node2D = ScorchScript.new()
	# В мире, а не на маге: выжженная земля остаётся на месте, если он отойдёт
	scorch.setup(self, facing, global_position + _body_anchor()[1], sweep_damage, sweep_knockback)
	get_tree().current_scene.add_child(scorch)


## ЛКМ — дальняя атака (Attack_, огненный шар), ПКМ ("parry", у мага парирования
## нет) — ближняя (Attack_2_, пелена с отбросом), V ("kick", пинка у мага нет) —
## двойной импульс вокруг себя (Attack_3_), B ("special") — столпы огня под
## врагами (SpecialAttack_). Это отдельные кнопки, а не серия:
## повторное нажатие во время удара в очередь не ставится, как это делала база.
## Бег на Attack_ работает как раньше (Run_Attack_, если нарисована)
func handle_attack_input() -> void:
	var fireball := Input.is_action_just_pressed("attack")
	var sweep := Input.is_action_just_pressed("parry")
	var pulse := Input.is_action_just_pressed("kick")
	var special := Input.is_action_just_pressed("special")
	if not fireball and not sweep and not pulse and not special:
		return
	if is_attacking:
		return
	# Заклинание стоит стамины — как выстрел у лучника. Не хватает — не
	# колдуем: нельзя бесконечно спамить сильнейшим импульсом
	var cost := special_stamina_cost if special else (pulse_stamina_cost if pulse else (sweep_stamina_cost if sweep else fireball_stamina_cost))
	if is_instance_valid(health_bar) and not health_bar.use_stamina(cost):
		return
	if special:
		start_special()
	elif pulse:
		start_attack(3)
	elif sweep:
		start_attack(2)
	elif is_running and input_vector != Vector2.ZERO:
		start_run_attack()
	else:
		start_attack(1)


## Цена заклинаний в стамине (её шкала — HealthStaminaBar, восполняется сама)
@export var fireball_stamina_cost := 12.0
@export var sweep_stamina_cost := 16.0
@export var pulse_stamina_cost := 28.0
@export var special_stamina_cost := 40.0


const PulseScript := preload("res://Player_scene/mage_pulse.gd")

## Третья атака (Attack_3_) — два импульса вокруг мага. Тайминги по анимации,
## в КАДРАХ клипа (длительность кадра — из самого клипа, _clip_frame_time):
## лист Special1 (10 к/с, тот же, что у столпов): маг поднимает посох на 2-5
## кадре — малый импульс, выброс силы на 9-10 кадре — большая волна.
##   1-й — маленький и короткий, вплотную вокруг мага, лишь чуть толкает
##   2-й — большая волна: уходит далеко, по пути рассеивается, бьёт фронтом
@export var pulse_damage := 1
@export var pulse_small_frame := 4.0
@export var pulse_small_radius := 56.0
## За сколько кадров маленький импульс доходит до края
@export var pulse_small_expand_frames := 2.4
@export var pulse_small_knockback := 100.0
@export var pulse_big_frame := 9.5
@export var pulse_big_radius := 150.0
## За сколько кадров большая волна доходит до края
@export var pulse_big_expand_frames := 9.0
@export var pulse_big_knockback := 280.0
## Тряска экрана на каждый заряд: первый — лёгкий толчок, второй (большая
## волна) — сильнее и дольше. Сила — смещение камеры в пикселях
@export var pulse_small_shake := 2.5
@export var pulse_small_shake_time := 0.15
@export var pulse_big_shake := 6.0
@export var pulse_big_shake_time := 0.32


func _cast_pulses() -> void:
	var clip := anim.current_animation
	var frame := _clip_frame_time(clip)
	await get_tree().create_timer(pulse_small_frame * frame).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var small: Node2D = PulseScript.new()
	var body := _body_anchor()
	# Рунический круг под магом (circle = true) убран — к новому виду мага не
	# подошёл. Сам круг в mage_pulse.gd остался, включается этим флагом
	small.setup(self, pulse_small_radius, pulse_small_expand_frames * frame, 0.0, pulse_damage, pulse_small_knockback, 0.45, false, body[0], body[1], frame)
	add_child(small)
	shake_camera(pulse_small_shake, pulse_small_shake_time)

	await get_tree().create_timer(maxf(pulse_big_frame - pulse_small_frame, 0.0) * frame).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var big: Node2D = PulseScript.new()
	big.setup(self, pulse_big_radius, pulse_big_expand_frames * frame, 1.0, pulse_damage, pulse_big_knockback, 1.0, false, body[0], body[1], frame)
	add_child(big)
	shake_camera(pulse_big_shake, pulse_big_shake_time)


## Где у мага на картинке центр тела и точка под ногами (относительно узла).
## Кадры 128x128 — рендер 3D-модели: корень модели (середина между ступнями)
## во всех 8 направлениях стоит ровно по центру кадра по X (замерено: ±3 px,
## это просто разная стойка ног). Рамку фигуры для этого брать нельзя — в
## кадры запечена полупрозрачная тень, которая уходит вбок, и посох; из-за
## них центр съезжал на 6-9 px. Поэтому точки фиксированные, в пикселях кадра
## от его центра, и только масштабируются вместе со спрайтом
const BODY_CENTER_PX := Vector2(0, 3)
const FEET_PX := Vector2(0, 27)

## [центр тела, ноги]
func _body_anchor() -> Array:
	if not is_instance_valid(sprite):
		return [Vector2(0, -4), Vector2.ZERO]
	return [sprite.position + BODY_CENTER_PX * sprite.scale, sprite.position + FEET_PX * sprite.scale]


const PillarScript := preload("res://Player_scene/mage_pillar.gd")

## Особая атака (SpecialAttack_, B — действие "special") — столпы голубого
## огня под ближайшими врагами. Тайминги — в КАДРАХ клипа, а не в секундах:
## длительность кадра берётся из самого клипа (_clip_frame_time), так что
## при смене скорости анимации столпы подстраиваются сами. Лист Special1: на
## 2-8 кадре маг поднимает посох и собирает силу — под целями в это время
## проступают руны (видно, куда ударит), на 9-10 кадре вырываются столпы
@export var special_max_targets := 5
## Радиус, в котором ищутся цели
@export var special_radius := 240.0
@export var special_mark_frame := 3.0
@export var special_erupt_frame := 9.5
## Столпы вырываются не разом, а волной от ближнего врага к дальнему (в кадрах)
@export var special_stagger_frames := 0.7
## Если длительность кадра из клипа не прочиталась (клипа нет) — эта скорость
@export var clip_fallback_fps := 10.0
@export var special_shake := 4.0
@export var special_shake_time := 0.25


func start_special() -> void:
	is_attacking = true
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	var targets := _special_targets()
	_turn_to_aim(targets[0] if not targets.is_empty() else _pick_aim())
	if not _play("SpecialAttack_" + last_direction):
		is_attacking = false
		return
	_cast_pillars(targets)


## До special_max_targets живых врагов в радиусе, ближние первыми. Взятая в
## фокус цель идёт первой, даже если она не ближайшая — игрок выбрал её сам
func _special_targets() -> Array:
	var found := []
	for e in get_tree().get_nodes_in_group("enemy"):
		# Мини-босс тоже в группе "enemy", но урона пока не принимает (нет ни
		# is_dead, ни take_damage) — пропускаем, иначе заклинание упадёт
		if not is_instance_valid(e) or not "is_dead" in e or e.is_dead or not e.has_method("take_damage"):
			continue
		if global_position.distance_to(e.global_position) <= special_radius:
			found.append(e)
	found.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var focus: Node2D = _focus.target if is_instance_valid(_focus) and _focus.has_target() else null
	if is_instance_valid(focus) and found.has(focus):
		found.erase(focus)
		found.push_front(focus)
	return found.slice(0, special_max_targets)


func _cast_pillars(targets: Array) -> void:
	var clip := anim.current_animation
	var frame := _clip_frame_time(clip)
	await get_tree().create_timer(special_mark_frame * frame).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var delay := maxf(special_erupt_frame - special_mark_frame, 0.0) * frame
	var spawned := 0
	for i in targets.size():
		var e: Node2D = targets[i]
		if not is_instance_valid(e) or e.is_dead:
			continue
		var p: Node2D = PillarScript.new()
		p.setup(self, e, _ground_offset(e), Vector2.ZERO, delay + spawned * special_stagger_frames * frame, frame)
		get_tree().current_scene.add_child(p)
		spawned += 1
	# Врагов рядом нет — один столп перед магом, чтобы заклинание не уходило
	# в пустоту без всякого эффекта
	if spawned == 0:
		var p: Node2D = PillarScript.new()
		var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.DOWN
		p.setup(self, null, Vector2.ZERO, global_position + _body_anchor()[1] + dir * 70.0, delay, frame)
		get_tree().current_scene.add_child(p)
	await get_tree().create_timer(delay).timeout
	if not is_dead():
		shake_camera(special_shake, special_shake_time)


## Сколько секунд длится один кадр клипа: шаг между первыми ключами дорожки
## кадров (tracks/0 — AnimatedSprite2D:frame) в AnimationPlayer
func _clip_frame_time(clip: String) -> float:
	if anim.has_animation(clip):
		var a := anim.get_animation(clip)
		if a.get_track_count() > 0 and a.track_get_key_count(0) > 1:
			var step := a.track_get_key_time(0, 1) - a.track_get_key_time(0, 0)
			if step > 0.0:
				return step
	return 1.0 / clip_fallback_fps


## Точка под ногами врага относительно его узла. Враги из того же набора
## 3D-рендеров 128x128, что и маг: ноги на FEET_PX от центра кадра
func _ground_offset(e: Node2D) -> Vector2:
	var spr := e.get_node_or_null("AnimatedSprite2D") as Node2D
	if spr == null:
		return Vector2.ZERO
	return spr.position + FEET_PX * spr.scale


## База завершает удар только по клипам "Attack*" — SpecialAttack_ сюда не
## попадает, и без этого маг так и остался бы в is_attacking
func _on_animation_finished(finished_anim: String) -> void:
	if finished_anim.begins_with("SpecialAttack"):
		is_attacking = false
		combo_step = 0
		combo_queued = false
		play_movement_animation()
		return
	super(finished_anim)
