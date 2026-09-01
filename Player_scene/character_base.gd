extends CharacterBody2D
## character_base.gd — общая база играбельных персонажей: движение по 8
## направлениям, выбор анимации по скорости и серия ударов.
##
## Сейчас на ней сидят лучник и маг — у них одинаковый набор клипов (Idle_/
## Walk_/Run_/Attack_/Attack_2_/Take_Damage_ на 8 направлений), и без общей базы
## это были бы два файла-близнеца. Рыцарь (player.gd) пока живёт отдельно: там
## ~2000 строк боёвки, инвентаря и способностей, и переезд на эту базу — это
## отдельная задача, а не побочный эффект добавления мага.
##
## AnimationPlayer ищется ПО ТИПУ, а не по имени: у лучника нода называется
## ArcherAnimation, у мага — MageAnimations, и хардкод имени заставил бы
## наследников переопределять его ради одной строки.

const DirectionUtil := preload("res://Player_scene/direction_util.gd")
const FocusSystemScript := preload("res://Player_scene/focus_system.gd")

@export var walk_speed := 100.0
@export var run_speed := 200.0
@export var combo_window := 0.5
## Сколько ударов в серии — столько, сколько нарисовано (Attack_, Attack_2_)
@export var combo_length := 2
@export var max_health := 100.0
## Настройки фокуса. Дублируют поля самого FocusSystem намеренно: компонент
## создаётся кодом, в дереве сцены его нет, и покрутить его @export в
## инспекторе нельзя — а так они лежат прямо на персонаже
@export var snap_radius := 80.0
@export var focus_break_range := 260.0
@export var focus_marker_offset := Vector2(0, -24)

## Нокбэк и неуязвимость на попадание — та же пара, что у рыцаря
## (player.gd::_apply_knockback_from / is_invulnerable), сильно упрощённая:
## там ещё завязаны додж/парирование, здесь только реакция на голый урон
@export var knockback_force := 160.0
@export var knockback_friction := 9.0
@export var post_hit_invulnerability := 0.4

## Атака на бегу — та же идея, что у рыцаря (player.gd::start_run_attack):
## отдельная анимация вместо обычного удара стоя, и рывок вперёд вместо
## полной остановки. Скорость рывка, а не константа rush — гасится трением,
## как и у рыцаря (attack_velocity.lerp(ZERO, friction*delta))
@export var run_attack_dash_speed := 220.0
@export var run_attack_friction := 5.0
## true — во время Run_Attack_ персонаж просто продолжает бежать с обычной
## скоростью (для лучника: выстрел на бегу не должен тормозить). false (по
## умолчанию, как у рыцаря) — рывок вперёд, гаснущий трением, для будущего
## рукопашного класса это ближе к ощущению удара с разбега
@export var run_attack_keeps_moving := false

## Перекат — та же механика, что у рыцаря (player.gd::start_roll/handle_roll):
## синусоидальный разгон-торможение, неуязвимость на всю длительность и
## временное прохождение сквозь врагов (collision_mask layer 3). Разница
## только в вводе: у рыцаря на пробел завязаны ДВА действия через окно
## двойного тапа (один тап — короткий додж, два — перекат), лучнику додж не
## нужен, поэтому один тап сразу запускает перекат
@export var roll_speed := 225.0
@export var roll_duration := 0.9
@export var roll_stamina_cost := 22.0

var anim: AnimationPlayer

var input_vector := Vector2.ZERO
var is_running := false
var facing_dir: Vector2 = Vector2.DOWN
var last_direction := "Down"

var is_attacking := false
var is_run_attacking := false
var combo_step := 0
var combo_queued := false
var combo_timer := 0.0
var _run_dash_velocity := Vector2.ZERO

# --- Контракт игрока ---
# К этим полям враги обращаются НАПРЯМУЮ, без has_method/in-проверок (см.
# enemy.gd: player.is_dodging, player.is_rolling, player.dodge_velocity), и без
# них лучник с магом заваливают консоль ошибками "Invalid access to property".
# Доджа (короткого уворота) у них по-прежнему нет — is_dodging всегда false.
# is_rolling/dodge_velocity теперь реально используются перекатом ниже —
# он переиспользует dodge_velocity как несущую скорость, как и у рыцаря
var is_dodging := false
var is_rolling := false
var dodge_velocity := Vector2.ZERO
var roll_dir := Vector2.ZERO
var roll_control := 0.0
var gold := 0

var knockback_velocity := Vector2.ZERO
var is_invulnerable := false
var _invuln_timer := 0.0

## Настоящее здоровье, а не только реакция анимацией — враг может убить
## этого персонажа. Канонично именно это поле (не health_bar): персонаж
## обязан корректно жить/умирать и без HUD в сцене — на HUD (если он есть,
## см. _find_health_bar) только зеркалится для отображения
var health := max_health
signal died

## HealthStaminaBar — та же нода/скрипт, что у рыцаря (UI/health_stamina_bar.gd,
## $HealthStaminaBar в player.tscn). Ищем по имени, а не заводим обязательным
## полем: пока у мага её нет в сцене, health по-прежнему считается верно,
## просто нечем показать
var health_bar: CanvasLayer = null
var sprite: AnimatedSprite2D = null
var camera: Camera2D = null

# Фокус на враге — тот же компонент, что у рыцаря (focus_system.gd). Пока
# цель взята, взгляд держится на ней, а WASD продолжает свободно двигать
# персонажа: можно кружить вокруг врага, не теряя его из виду
var _focus: Node = null

## Текущая цель, только чтение. Такое же поле есть у рыцаря — так любой код
## снаружи может спросить у ЛЮБОГО персонажа, кого он держит в фокусе, не
## разбираясь, какой это класс
var focused_enemy: Node2D:
	get:
		return _focus.target if is_instance_valid(_focus) else null


func _ready() -> void:
	# Враги, монеты и триггеры уровня ищут игрока через группу, а не по имени
	# ноды (см. enemy.gd, coin.gd, shop_trigger.gd) — без этого персонаж просто
	# не существует для всего остального мира
	add_to_group("player")

	_focus = FocusSystemScript.new()
	_focus.name = "FocusSystem"
	_focus.snap_radius = snap_radius
	_focus.break_range = focus_break_range
	_focus.marker_offset = focus_marker_offset
	add_child(_focus)

	sprite = _find_child_of_type(AnimatedSprite2D) as AnimatedSprite2D
	camera = _find_child_of_type(Camera2D) as Camera2D
	health_bar = get_node_or_null("HealthStaminaBar")
	if health_bar:
		health_bar.set_max_hp(max_health)

	anim = _find_animation_player()
	if anim == null:
		push_error("[%s] Не найден AnimationPlayer" % name)
		return
	anim.animation_finished.connect(_on_animation_finished)
	play_movement_animation()


func _find_animation_player() -> AnimationPlayer:
	return _find_child_of_type(AnimationPlayer) as AnimationPlayer


func _find_child_of_type(type) -> Node:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null


func _physics_process(delta: float) -> void:
	if anim == null or is_dead():
		return

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			is_invulnerable = false

	if is_rolling:
		_handle_roll(delta)
		return

	# Перекат обрабатываем ДО нокбэка — та же идея, что у рыцаря
	# (player.gd::_physics_process, "ДОДЖ/ПЕРЕКАТ ВНЕ ОЧЕРЕДИ"): зажатого
	# попаданиями персонажа нельзя залочить, перекат обязан всегда давать
	# вырваться, а не ждать своей очереди после нокбэка
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_running = Input.is_action_pressed("run")
	handle_roll_input()
	if is_rolling:
		_handle_roll(delta)
		return

	# Нокбэк от удара — перехватывает движение на несколько кадров, тот же
	# приём, что у рыцаря. Проверяем ДО ввода атаки: получив удар, нельзя в
	# тот же кадр как ни в чём не бывало продолжить бить
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_friction * delta)
		if knockback_velocity.length() < 5.0:
			knockback_velocity = Vector2.ZERO
		velocity = knockback_velocity
		move_and_slide()
		return

	_focus.poll_input()
	handle_attack_input()

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0
			combo_queued = false

	if is_attacking:
		if is_run_attacking and run_attack_keeps_moving:
			# Выстрел на бегу не тормозит — бежал и продолжает бежать с той же
			# скоростью, что и без атаки (см. run_attack_keeps_moving). Только
			# анимация здесь Run_Attack_, а не Run_ — её выбирает start_run_attack,
			# play_movement_animation тут специально не зовём, чтобы не перебить
			_apply_free_movement(delta)
			move_and_slide()
			return
		if is_run_attacking:
			_run_dash_velocity = _run_dash_velocity.lerp(Vector2.ZERO, run_attack_friction * delta)
			velocity = _run_dash_velocity
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		return

	_apply_free_movement(delta)
	move_and_slide()
	_update_facing()
	play_movement_animation()


## Обычное свободное движение по input_vector — вынесено отдельно, чтобы тем
## же кодом мог пользоваться выстрел на бегу (run_attack_keeps_moving): там
## нужна ровно та же скорость и тот же разгон/торможение, что и без атаки
func _apply_free_movement(delta: float) -> void:
	var target_speed := run_speed if is_running else walk_speed
	var target_velocity := input_vector.normalized() * target_speed

	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(target_velocity, 6.0 * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 9.0 * delta)


## Куда смотрит персонаж. Взгляд и движение — разные вещи: пока цель в фокусе,
## смотрим на неё, а WASD свободно двигает корпус (можно кружить вокруг врага).
## Прямой побег бегом фокус на этот кадр отпускает — убегать с намертво
## повёрнутой на врага головой выглядит нелепо
func _update_facing() -> void:
	if _focus.has_target() and not _focus.is_fleeing(input_vector, is_running):
		var to_target: Vector2 = _focus.direction_to_target()
		if to_target != Vector2.ZERO:
			var new_dir := get_direction(to_target)
			if new_dir != "":
				facing_dir = to_target
				last_direction = new_dir
			return

	if input_vector != Vector2.ZERO:
		facing_dir = input_vector.normalized()
		last_direction = get_direction(facing_dir)


func play_movement_animation() -> void:
	var speed := velocity.length()
	var anim_name := "Idle_" + last_direction
	if speed >= 120.0:
		anim_name = "Run_" + last_direction
	elif speed >= 10.0:
		anim_name = "Walk_" + last_direction

	_play(anim_name)


# ─────────────────────────────────────────────
# ПЕРЕКАТ
# ─────────────────────────────────────────────

## У рыцаря пробел копится в окне dodge_tap_window и решает додж/перекат по
## числу тапов. Лучнику додж не нужен — один тап сразу перекат
func handle_roll_input() -> void:
	if is_rolling:
		return
	if Input.is_action_just_pressed("ui_accept"):
		start_roll()


func start_roll() -> void:
	if is_rolling:
		return

	var dir := input_vector.normalized() if input_vector != Vector2.ZERO else direction_to_vector(last_direction)
	if dir == Vector2.ZERO:
		dir = facing_dir
	var dir_name := get_direction(dir)

	# Проверяем клип ДО траты стамины — иначе без нарисованной Rolling_
	# анимации нажатие тихо съедало бы стамину без всякого видимого эффекта
	if not anim.has_animation("Rolling_" + dir_name):
		return
	if is_instance_valid(health_bar) and not health_bar.use_stamina(roll_stamina_cost):
		return

	roll_control = 0.0
	is_rolling = true
	# Перекат прерывает начатую атаку — как двойной тап у рыцаря
	# (interrupt_all_actions): иначе можно застрять между Attack_ и Rolling_
	is_attacking = false
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	knockback_velocity = Vector2.ZERO
	# Слой 3 = "enemy" (project.godot/layer_names) — на время переката
	# проходим сквозь врагов физически, как и рыцарь
	set_collision_mask_value(3, false)

	roll_dir = dir
	facing_dir = dir
	last_direction = dir_name
	_play("Rolling_" + dir_name)
	dodge_velocity = roll_dir * roll_speed


## Синусоидальный разгон-торможение — та же кривая, что у рыцаря
## (player.gd::handle_roll): плавный старт и плавное гашение к концу клипа,
## а не рывок на постоянной скорости
func _handle_roll(delta: float) -> void:
	roll_control += delta
	var t: float = clamp(roll_control / roll_duration, 0.0, 1.0)
	var speed_multiplier := sin(t * PI)
	dodge_velocity = roll_dir * roll_speed * speed_multiplier
	velocity = dodge_velocity
	move_and_slide()


# ─────────────────────────────────────────────
# АТАКА
# ─────────────────────────────────────────────

func handle_attack_input() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	if is_attacking:
		if combo_step < combo_length:
			combo_queued = true
		return
	if is_running and input_vector != Vector2.ZERO:
		start_run_attack()
		return
	start_attack(1)


## Атака на бегу — отдельное действие, а не шаг серии: не входит в комбо
## (combo_step/combo_queued тут не участвуют), запускается и заканчивается
## сама по себе, как рывок мечом у рыцаря
func start_run_attack() -> void:
	is_attacking = true
	combo_step = 0
	combo_queued = false

	facing_dir = input_vector.normalized()
	last_direction = get_direction(facing_dir)

	# Анимации ещё может не быть (has_animation-паттерн, как и везде в этом
	# файле) — тогда тихо откатываемся на обычный удар стоя, а не на пустое
	# нажатие без всякой реакции
	if not _play("Run_Attack_" + last_direction):
		is_attacking = false
		start_attack(1)
		return

	is_run_attacking = true
	_run_dash_velocity = facing_dir * run_attack_dash_speed

	var aim: Node2D = _focus.target if _focus.has_target() else _focus.get_nearest_enemy()
	_on_attack_started(0, aim)


func start_attack(step: int) -> void:
	is_attacking = true
	is_run_attacking = false
	combo_step = step
	combo_queued = false
	combo_timer = combo_window

	# Приоритет наведения: взятая в фокус цель > ближайший враг > направление
	# ввода. Тот же порядок, что у рыцаря (player.gd::try_snap_to_enemy):
	# если игрок явно выбрал врага, бить надо именно его, а не того, кто
	# случайно оказался ближе в толпе
	var aim: Node2D = _focus.target if _focus.has_target() else _focus.get_nearest_enemy()
	if is_instance_valid(aim):
		var to_aim := (aim.global_position - global_position).normalized()
		var aim_dir := get_direction(to_aim)
		if aim_dir != "":
			facing_dir = to_aim
			last_direction = aim_dir
	elif input_vector != Vector2.ZERO:
		facing_dir = input_vector.normalized()
		last_direction = get_direction(facing_dir)

	# Первый удар — Attack_, дальше Attack_2_, Attack_3_ и т.д. Клипа под шаг
	# может не быть — тогда переигрываем первый, а не обрываем всю серию (тот
	# же подход, что у рыцаря в player.gd: комбо не должно молча ломаться)
	var prefix := "Attack_" if step == 1 else "Attack_%d_" % step
	if not _play(prefix + last_direction):
		if not _play("Attack_" + last_direction):
			is_attacking = false
			return

	_on_attack_started(step, aim)


## Переопределяют наследники — сюда вешается конкретный эффект удара: выстрел
## стрелой у лучника, заклинание у мага. В базе пусто: сама анимация уже
## отыграна к этому моменту, aim — та же цель, на которую только что
## развернулось наведение (null, если целей рядом не было)
func _on_attack_started(_step: int, _aim: Node2D) -> void:
	pass


func _on_animation_finished(finished_anim: String) -> void:
	if finished_anim.begins_with("Rolling_"):
		is_rolling = false
		set_collision_mask_value(3, true)
		dodge_velocity = Vector2.ZERO
		roll_control = 0.0
		velocity = Vector2.ZERO
		play_movement_animation()
		return
	if finished_anim.begins_with("Run_Attack"):
		is_attacking = false
		is_run_attacking = false
		_run_dash_velocity = Vector2.ZERO
		play_movement_animation()
		return
	if not finished_anim.begins_with("Attack"):
		return
	if combo_queued and combo_step < combo_length:
		start_attack(combo_step + 1)
	else:
		is_attacking = false
		combo_step = 0
		combo_queued = false
		play_movement_animation()


# ─────────────────────────────────────────────
# УРОН И ДОБЫЧА — минимум, чтобы мир работал
# ─────────────────────────────────────────────

## Враг зовёт это, когда его удар достал игрока (enemy.gd::_try_hit_body).
## Концентрации/блока/парирования у этих персонажей ещё нет (см. player.gd —
## там receive_attack умеет гораздо больше), поэтому здесь только урон и
## реакция анимацией — но метод обязан существовать и возвращать true, иначе
## враг считает, что промахнулся, и бьёт снова и снова
func receive_attack(attack_data: Dictionary) -> bool:
	if is_dead() or is_invulnerable or is_rolling:
		return false
	var amount: float = attack_data.get("damage", 0)
	health = maxf(health - amount, 0.0)
	if is_instance_valid(health_bar):
		health_bar.take_damage(amount)
	play_take_damage()
	_flash_hit()
	shake_camera(4.0)
	_apply_knockback(attack_data.get("source", null))
	is_invulnerable = true
	_invuln_timer = post_hit_invulnerability
	if is_dead():
		_die()
	return true


func is_dead() -> bool:
	return health <= 0.0


## source — Node2D-атакующий из attack_data. Если враг его не передал (не
## должно случаться, но source в словаре необязателен), берём ближайшего —
## тот же запасной путь, что у рыцаря (get_nearest_enemy() в _apply_knockback_from)
func _apply_knockback(source: Variant) -> void:
	var attacker: Node2D = source as Node2D
	if attacker == null and is_instance_valid(_focus):
		attacker = _focus.get_nearest_enemy()
	if attacker == null or not is_instance_valid(attacker):
		return
	var dir: Vector2 = global_position - attacker.global_position
	if dir.length() > 0.01:
		knockback_velocity = dir.normalized() * knockback_force


## Белая вспышка спрайта на попадание — та же идея, что у рыцаря
## (player.gd::_trigger_damage_flash), только без отдельного gfx-узла: у
## лучника/мага сам AnimatedSprite2D и есть весь визуал
func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.6, 1.6, 1.6), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


## Короткая тряска камеры на попадание — сильно упрощённая версия
## player.gd::shake_camera (там — затухающая "trauma"-величина в _process,
## здесь — один твин на удар, для этого хватает)
func shake_camera(strength: float, duration := 0.18) -> void:
	if not is_instance_valid(camera):
		return
	var tween := create_tween()
	var steps := 6
	for i in steps:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(camera, "offset", offset, duration / steps)
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / steps)


## TODO: анимация смерти, game over — то же самое, что у рыцаря
## (player.gd::_on_player_dead), нигде в проекте пока не реализовано.
## is_dead() уже останавливает _physics_process персонажа (см. выше), так что
## смерть хотя бы не выглядит как зависшее управление
func _die() -> void:
	is_attacking = false
	is_run_attacking = false
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	died.emit()


## Игрок ударил в момент парирования врага — у рыцаря это накапливает
## концентрацию и валит в стан. Здесь заглушка: шкалы концентрации нет
func receive_parry(_posture_damage: float) -> void:
	pass


## Подбор монеты (coin.gd). Золото хранится в сейве, поэтому копить его должен
## уметь любой персонаж, даже пока у него нет HUD, чтобы это показать
func add_gold(amount: int) -> void:
	gold += amount


func play_take_damage() -> void:
	_play("Take_Damage_" + last_direction)


# ─────────────────────────────────────────────
# УТИЛИТЫ
# ─────────────────────────────────────────────

## Проигрывает клип, если он есть. false = такого клипа в библиотеке нет,
## решение (переиграть другой / промолчать) остаётся за вызывающим
func _play(anim_name: String) -> bool:
	if not anim.has_animation(anim_name):
		return false
	if anim.current_animation != anim_name:
		anim.play(anim_name)
	return true


## Общая с рыцарем таблица направлений (DirectionUtil) — имена секторов это
## суффиксы клипов, и расходиться копиям тут нельзя
func get_direction(vec: Vector2) -> String:
	return DirectionUtil.from_vector(vec)


func direction_to_vector(dir: String) -> Vector2:
	return DirectionUtil.to_vector(dir)
