extends "res://Player_scene/character_base.gd"
## Лучник. Движение, направления, серия ударов и здоровье — в общей базе
## (character_base.gd), здесь только то, что отличает его от остальных:
## каждый удар серии выпускает стрелу вместо чистого рукопашного взмаха.

const ArrowScript := preload("res://Player_scene/arrow.gd")
const SHOOT_SOUND := preload("res://Sound/archer_sound/arrow.mp3")

@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio
@onready var kick_hitbox: Area2D = $KickHitbox

## Метка "стрелок" для enemy.gd — по ней враги замечают лучника издалека
## (см. _scan_for_ranged_threat в enemy.gd), в обход обычной ближней VisionArea.
## Тем же тут заводим хитбокс пинка — та же группа/meta, что у PlayerHitbox
## рыцаря (player.gd::_ready), это единственное, что даёт enemy.gd опознать
## удар как "атака игрока" (см. enemy.gd::_is_player_attack/_get_damage_from)
func _ready() -> void:
	super._ready()
	add_to_group("ranged_player")
	kick_hitbox.add_to_group("player_attack")
	kick_hitbox.set_meta("damage", kick_damage)

## Базовый враг (enemy.gd) — 5 HP, рыцарь бьёт 1 уроном за удар. Было 12 —
## враг гарантированно умирал с одной стрелы. Держим ту же цену удара, что
## у рыцаря (враги стали живучее в enemy.gd, а не лук — слабее)
@export var arrow_damage := 1
@export var arrow_speed := 520.0
## Смещение точки выстрела от центра тела по направлению взгляда — иначе
## стрела стартует из центра персонажа, а не от рук
@export var shoot_offset := 20.0
## Пауза между нажатием и вылетом стрелы — под натяжение лука в анимации
## (без неё стрела срывалась в тот же кадр, что и нажатие кнопки)
@export var shoot_delay := 0.3
## Цена выстрела в стамине и минимальная пауза между ними — лук не пулемёт.
## Стамина берётся из общего HealthStaminaBar (см. character_base._ready) —
## бар уже умеет копить/тратить её, здесь только цена конкретного действия
@export var shoot_stamina_cost := 15.0
@export var shoot_cooldown := 0.5

## Пинок — единственный рукопашный удар лучника, на отдельной кнопке ("kick",
## V), а не в серии выстрелов: с одной анимацией сериями бить незачем.
## Урон — как у стрелы/рыцаря (1), это ближний добивающий, а не замена лука
@export var kick_damage := 1
@export var kick_reach := 22.0
@export var kick_windup := 0.15
@export var kick_active_time := 0.15
@export var kick_stamina_cost := 10.0
@export var kick_cooldown := 0.6

## Быстрый выстрел — на ПКМ ("parry", рыцарю парирование не нужно у лучника,
## свободна). Одно нажатие — quick_shot_count стрел подряд по одной и той же
## линии (направление фиксируется один раз в начале, как и у остальных ударов:
## фокус > ближайший враг > направление ввода/взгляда). Дороже и с более
## длинным кулдауном, чем обычный выстрел — это залповый спецприём, не замена
## основного лука
@export var quick_shot_count := 3
@export var quick_shot_windup := 0.15
@export var quick_shot_interval := 0.08
@export var quick_shot_stamina_cost := 30.0
@export var quick_shot_cooldown := 1.5

var _shoot_cooldown_timer := 0.0
var _kick_cooldown_timer := 0.0
var _quick_shot_cooldown_timer := 0.0


## Полностью переопределяет базовую версию (а не зовёт super + добавляет
## проверки сверху): у Input.is_action_just_pressed внутри super всё равно
## пришлось бы читать заново, а так гейты стамины/кулдауна встают ровно перед
## start_attack, не трогая саму механику комбо — ей по-прежнему пользуется
## рукопашный маг. Здесь же тикает кулдаун: handle_attack_input дёргается из
## базового _physics_process каждый кадр независимо от того, нажата ли кнопка
func handle_attack_input() -> void:
	if _shoot_cooldown_timer > 0.0:
		_shoot_cooldown_timer -= get_physics_process_delta_time()
	if _kick_cooldown_timer > 0.0:
		_kick_cooldown_timer -= get_physics_process_delta_time()
	if _quick_shot_cooldown_timer > 0.0:
		_quick_shot_cooldown_timer -= get_physics_process_delta_time()

	# Пинок и быстрый выстрел проверяем первыми и отдельно от серии обычных
	# выстрелов — свои кнопки, не участвуют в комбо/is_attacking-очереди лука
	if Input.is_action_just_pressed("kick") and not is_attacking and _kick_cooldown_timer <= 0.0:
		_start_kick()
		return
	if Input.is_action_just_pressed("parry") and not is_attacking and _quick_shot_cooldown_timer <= 0.0:
		_start_quick_shot()
		return

	if not Input.is_action_just_pressed("attack"):
		return
	if is_attacking:
		if combo_step < combo_length:
			combo_queued = true
		return
	if _shoot_cooldown_timer > 0.0:
		return
	if is_instance_valid(health_bar) and not health_bar.use_stamina(shoot_stamina_cost):
		return
	_shoot_cooldown_timer = shoot_cooldown
	# Выстрел на бегу — та же цена (стамина/кулдаун уже списаны выше), только
	# другая анимация и рывок вместо остановки. Логика самого рывка и отката
	# на Attack_, если Run_Attack_ ещё не нарисована — в базе (character_base.gd)
	if is_running and input_vector != Vector2.ZERO:
		start_run_attack()
	else:
		start_attack(1)


## Дёргается из базы (start_attack) сразу после того, как отыграна анимация
## удара — aim это та же цель, на которую только что развернулось наведение
## (фокус > ближайший враг > null). Не await'ится вызывающим (start_attack) —
## отрабатывает как fire-and-forget, комбо продолжается независимо
func _on_attack_started(_step: int, aim: Node2D) -> void:
	# Звук — здесь, ДО паузы: "перед выстрелом" значит до того, как стрела
	# реально появится (натяжение), а не в момент её вылета
	shoot_audio.stream = SHOOT_SOUND
	shoot_audio.play()
	await get_tree().create_timer(shoot_delay).timeout
	# Пока стрела натягивалась, лучник мог умереть — стрелять уже некому.
	# aim/цель отдельно проверять не нужно: _shoot_arrow сам откатывается на
	# выстрел по направлению взгляда, если aim за это время протух
	if is_dead():
		return
	_shoot_arrow(aim)


func _shoot_arrow(aim: Node2D) -> void:
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	else:
		# Целей рядом нет — стреляем туда, куда смотрим (тот же вектор, что
		# приняла анимация в start_attack)
		dir = direction_to_vector(last_direction)
		if dir == Vector2.ZERO:
			dir = facing_dir
	_fire_arrow(dir)


## Сам спавн стрелы, без выбора направления — общий кусок между обычным
## выстрелом (_shoot_arrow, направление берёт из aim-узла) и быстрым залпом
## (_start_quick_shot, направление фиксировано заранее на весь залп)
func _fire_arrow(dir: Vector2) -> void:
	var arrow: Area2D = ArrowScript.new()
	get_tree().current_scene.add_child(arrow)
	arrow.speed = arrow_speed
	arrow.launch(global_position + dir * shoot_offset, dir, self, arrow_damage)


# ─────────────────────────────────────────────
# ПИНОК
# ─────────────────────────────────────────────

## Тайминг по коду (await), а не method-track в анимации — тот же приём, что
## и у выстрела (_on_attack_started/shoot_delay): не нужно лезть в keyframe'ы
## Kick_-клипов, чтобы воткнуть туда enable/disable_hitbox
func _start_kick() -> void:
	var aim: Node2D = _focus.target if _focus.has_target() else _focus.get_nearest_enemy()
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	elif input_vector != Vector2.ZERO:
		dir = input_vector.normalized()
	else:
		dir = facing_dir
	var dir_name := get_direction(dir)

	# Клипа может не быть — тогда просто не пинаем, ничего не тратим (тот же
	# приём, что и у переката: has_animation ДО расхода стамины/кулдауна)
	if not anim.has_animation("Kick_" + dir_name):
		return
	if is_instance_valid(health_bar) and not health_bar.use_stamina(kick_stamina_cost):
		return

	_kick_cooldown_timer = kick_cooldown
	is_attacking = true
	facing_dir = dir
	last_direction = dir_name
	_play("Kick_" + dir_name)

	await get_tree().create_timer(kick_windup).timeout
	# Перекат/смерть могли прервать пинок, пока он натягивался (is_attacking
	# сбрасывается и start_roll(), и _die()) — тогда хитбокс включать некому
	if not is_attacking:
		return
	_enable_kick_hitbox(dir)

	await get_tree().create_timer(kick_active_time).timeout
	if is_instance_valid(kick_hitbox):
		_disable_kick_hitbox()


func _enable_kick_hitbox(dir: Vector2) -> void:
	kick_hitbox.position = dir * kick_reach
	kick_hitbox.set_deferred("monitoring", true)
	kick_hitbox.get_child(0).set_deferred("disabled", false)


func _disable_kick_hitbox() -> void:
	kick_hitbox.set_deferred("monitoring", false)
	kick_hitbox.get_child(0).set_deferred("disabled", true)


## "Kick_" не начинается ни с "Attack", ни с "Run_Attack", ни с "Rolling_" —
## база (character_base.gd::_on_animation_finished) его не узнает и ничего не
## сделает, поэтому здесь свой обработчик именно для него; всё остальное
## отдаём наверх, как было
func _on_animation_finished(finished_anim: String) -> void:
	if finished_anim.begins_with("Kick_"):
		is_attacking = false
		play_movement_animation()
		return
	super._on_animation_finished(finished_anim)


# ─────────────────────────────────────────────
# БЫСТРЫЙ ВЫСТРЕЛ (ЗАЛП)
# ─────────────────────────────────────────────

## Сброс is_attacking делает сама функция в конце залпа, а не
## _on_animation_finished (как у пинка) — клип QuickShot_ может быть короче
## или длиннее, чем windup + count*interval, и если довериться его концу,
## можно оборвать залп на середине или наоборот держать очередь ЖДАТЬ уже
## отыгранной анимации. Код сам себе тайминг, анимация — просто картинка сверху
func _start_quick_shot() -> void:
	var aim: Node2D = _focus.target if _focus.has_target() else _focus.get_nearest_enemy()
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	elif input_vector != Vector2.ZERO:
		dir = input_vector.normalized()
	else:
		dir = facing_dir
	var dir_name := get_direction(dir)

	if not anim.has_animation("QuickShot_" + dir_name):
		return
	if is_instance_valid(health_bar) and not health_bar.use_stamina(quick_shot_stamina_cost):
		return

	_quick_shot_cooldown_timer = quick_shot_cooldown
	is_attacking = true
	facing_dir = dir
	last_direction = dir_name
	_play("QuickShot_" + dir_name)

	await get_tree().create_timer(quick_shot_windup).timeout
	for i in quick_shot_count:
		# Перекат/смерть могли прервать залп между стрелами — не стреляем
		# дальше, если is_attacking уже сбросили за нас
		if not is_attacking:
			return
		shoot_audio.stream = SHOOT_SOUND
		shoot_audio.play()
		_fire_arrow(dir)
		if i < quick_shot_count - 1:
			await get_tree().create_timer(quick_shot_interval).timeout

	is_attacking = false
	play_movement_animation()
