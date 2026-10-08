extends "res://Player_scene/character_base.gd"
## Маг. Движение, направления и серия ударов — в общей базе
## (character_base.gd), здесь только то, что отличает его от остальных.
##
## Набор клипов у мага такой же, как у лучника (Idle_/Walk_/Run_/Attack_/
## Attack_2_/Take_Damage_ на 8 направлений), поэтому база подходит как есть.
## Заклинания и посох — следующий шаг, и им место здесь, а не в базе.
##
## Скорости и длину серии не переопределяем кодом: они объявлены как @export в
## базе, и правильное место их крутить — инспектор в mage.tscn. Присваивание в
## _ready() затирало бы то, что выставлено в сцене

const FireballScript := preload("res://Player_scene/mage_fireball.gd")

## Первая атака (Attack_) — синий огненный шар. Пауза до вылета подогнана под
## анимацию: маг выбрасывает руку с магией на 7-8 кадре из 15 (клип 1с)
@export var fireball_cast_delay := 0.5
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
	if step != 1:
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


const SweepScript := preload("res://Player_scene/mage_sweep.gd")

## Вторая атака (Attack_2_) — ближний удар: пелена магии за рукой по
## диагонали, бьёт всех в секторе перед магом и отбрасывает. Рука начинает
## вести поток примерно с 3-го кадра из 15 (0.2с)
@export var sweep_start_delay := 0.2
@export var sweep_damage := 1
@export var sweep_knockback := 330.0


func _cast_sweep() -> void:
	var clip := anim.current_animation
	var facing := facing_dir
	await get_tree().create_timer(sweep_start_delay).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var sweep: Node2D = SweepScript.new()
	sweep.setup(self, facing, sweep_damage, sweep_knockback)
	# Ребёнок мага — пелена держится у руки, даже если мага сдвинет
	add_child(sweep)


## ЛКМ — дальняя атака (Attack_, огненный шар), ПКМ ("parry", у мага парирования
## нет) — ближняя (Attack_2_, пелена с отбросом), V ("kick", пинка у мага нет) —
## двойной импульс вокруг себя (Attack_3_). Это отдельные кнопки, а не серия:
## повторное нажатие во время удара в очередь не ставится, как это делала база.
## Бег на Attack_ работает как раньше (Run_Attack_, если нарисована)
func handle_attack_input() -> void:
	var fireball := Input.is_action_just_pressed("attack")
	var sweep := Input.is_action_just_pressed("parry")
	var pulse := Input.is_action_just_pressed("kick")
	if not fireball and not sweep and not pulse:
		return
	if is_attacking:
		return
	if pulse:
		start_attack(3)
	elif sweep:
		start_attack(2)
	elif is_running and input_vector != Vector2.ZERO:
		start_run_attack()
	else:
		start_attack(1)


const PulseScript := preload("res://Player_scene/mage_pulse.gd")

## Третья атака (Attack_3_) — два импульса вокруг мага. Тайминги по анимации:
## маг разводит руки на 2-4 кадре и второй раз, со вспышкой, на 8-9 кадре
## (клип — 15 кадров за 1с).
##   1-й — маленький и короткий, вплотную вокруг мага, лишь чуть толкает
##   2-й — большая волна: уходит далеко, по пути рассеивается, бьёт фронтом
@export var pulse_damage := 1
@export var pulse_small_time := 0.2
@export var pulse_small_radius := 56.0
@export var pulse_small_knockback := 100.0
@export var pulse_big_time := 0.55
@export var pulse_big_radius := 150.0
## За сколько большая волна доходит до края
@export var pulse_big_expand := 0.6
@export var pulse_big_knockback := 280.0


func _cast_pulses() -> void:
	var clip := anim.current_animation
	await get_tree().create_timer(pulse_small_time).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var small: Node2D = PulseScript.new()
	small.setup(self, pulse_small_radius, 0.16, 0.0, pulse_damage, pulse_small_knockback, 0.45)
	add_child(small)

	await get_tree().create_timer(maxf(pulse_big_time - pulse_small_time, 0.0)).timeout
	if is_dead() or anim.current_animation != clip:
		return
	var big: Node2D = PulseScript.new()
	big.setup(self, pulse_big_radius, pulse_big_expand, 1.0, pulse_damage, pulse_big_knockback, 1.0)
	add_child(big)
