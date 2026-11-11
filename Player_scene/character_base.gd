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
const DepthComponentScript := preload("res://Player_scene/depth_component.gd")
const MotionFeelScript := preload("res://Player_scene/motion_feel.gd")
## Пыль из-под ног на резком развороте, остановке и старте — один общий
## процедурный эффект на всех героев (и рыцаря: player.gd, motion_feel.gd)
const SkidDust := preload("res://VFX/VFX_scene/skid_dust.gd")
const BloodFx := preload("res://VFX/VFX_scene/blood_fx.gd")

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
## Шаг вперёд на ударе стоя — как микро-рывок рыцаря (player.gd::play_attack,
## attack_velocity). Наследник задаёт скорость шага через attack_step(), здесь
## она только гаснет трением: путь шага ≈ скорость / attack_step_friction.
## Никто не позвал attack_step() — удар стоя на месте, как раньше (маг)
@export var attack_step_friction := 6.0
var _attack_step_velocity := Vector2.ZERO

## Перекат — та же механика, что у рыцаря (player.gd::start_roll/handle_roll):
## синусоидальный разгон-торможение, неуязвимость на всю длительность и
## временное прохождение сквозь врагов (collision_mask layer 3). Разница
## только в вводе: у рыцаря на пробел завязаны ДВА действия через окно
## двойного тапа (один тап — короткий додж, два — перекат), лучнику додж не
## нужен, поэтому один тап сразу запускает перекат
## Длина переката ≈ roll_speed * roll_duration * 2/π: 190 → ~110 px. У рыцаря
## 150 (~85 px) — он в доспехе, лёгкие классы катятся чуть дальше
@export var roll_speed := 190.0
@export var roll_duration := 0.9
@export var roll_stamina_cost := 22.0
## Неуязвимость переката — только первые roll_iframes_end секунд (клип
## ~0.9-1 с), а не весь перекат: на хвосте удар уже достаёт и обрывает его
@export var roll_iframes_end := 0.45
## С какого места переката (с) его обрывает любое действие (удар, приём,
## заклинание, новый перекат) — сразу после конца неуязвимости
@export var roll_cancel_time := 0.55

## Дэш — короткий быстрый рывок-уклон по той же логике, что перекат
## (выносливость, неуязвимость, сквозь врагов), но вдвое короче и резче.
## Включён — пробел работает в два действия: одно нажатие — дэш (сразу, без
## задержки), второе нажатие в пределах double_tap_window — перекат (рывок
## обрывается, перекат идёт с места). Выключен — пробел, как раньше, сразу
## перекат. Сейчас включён у Сигрид (archer.tscn)
@export var dash_enabled := false
## Путь дэша ≈ dash_speed * dash_duration * ~0.8 (гасится к концу): 560 → ~75 px
@export var dash_speed := 560.0
@export var dash_duration := 0.17
@export var dash_stamina_cost := 12.0
## Окно второго нажатия для переката, с — с запасом, чтобы успевать без спешки
@export var double_tap_window := 0.35
## Двойники за рывком: свой цвет героя (прозрачный — светлая сталь)
@export var dash_ghost_tint := Color(0, 0, 0, 0)
var _dash_left := 0.0
var _dash_dir := Vector2.ZERO
var _dash_ghost_t := 0.0
var _dash_tap_ms := -100000
## Наведение: при зажатом направлении удар/выстрел/заклинание идёт туда, а к
## врагу доворачивает, только если он в этом конусе (полуугол, градусы).
## Без направления — к ближайшему в радиусе, в фокусе — всегда к цели
@export var aim_assist_cone_deg := 40.0
## Удар «отыгран» (клинок прошёл, стрела/заклинание вылетели): наследник
## ставит _attack_recovery = true, и хвост клипа больше не держит — следующий
## удар серии начинается сразу, а движение обрывает отмах
var _attack_recovery := false

## Бег тратит стамину, как у рыцаря (player.gd::run_stamina_drain). На нуле —
## бежать нельзя, ходьба медленнее (тот же штраф истощения, что у рыцаря)
@export var run_stamina_drain := 10.0
@export var exhausted_speed_multiplier := 0.5
## Разгон/торможение — те же резкие коэффициенты, что у рыцаря
## (player.gd: accel/friction_run 30): до полной скорости и до остановки ≈0.1 с
@export var move_accel := 30.0
@export var move_friction := 30.0
## Реакция на удар: столько секунд нельзя ни идти, ни бить — только
## перекатиться (вырваться перекатом можно всегда)
@export var hurt_lock_time := 0.3
var _hurt_timer := 0.0

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

## Резкий разворот на бегу (Turn_) — та же механика, что у рыцаря
## (player.gd::check_for_turn/start_turn): вместо того чтобы скользить
## корпусом назад, персонаж играет короткий рывок-разворот с пылью под
## ногами. turn_lock держит взгляд зафиксированным на время анимации —
## как turn_lock у рыцаря
var is_turning := false
var turn_lock := false
var turn_velocity := Vector2.ZERO
@export var turn_friction := 6.0

var gold := 0
## Копит ли класс золото. У мага валюта другая — души, монеты ему не нужны:
## при игре за него они не выпадают ни из врагов, ни из разбитых ящиков
## (enemy.gd / breakable_prop.gd спрашивают это поле), а подобранные (если
## вдруг) в золото не идут
@export var collects_gold := true
## Души — валюта мага (collects_souls в mage.tscn). Из врагов вместо золотых
## выпадают души (gold_wisp.gd в режиме души), сами летят к герою; хранятся
## в сейве, как золото
var souls := 0
@export var collects_souls := false
## Копится на прокачку выбранного класса (см. UI/skill_points_bar.gd и
## SaveManager.gd), тот же контракт, что у gold. Растёт НЕ за каждое убийство —
## только когда skill_progress долился до skill_progress_per_point (см. ниже)
var skill_points := 0
## Сырой прогресс убийств к следующему очку — это и есть заливка полоски в
## UI/skill_points_bar.gd. Копится за убийство (add_skill_points), а по
## достижении skill_progress_per_point обнуляется (с переносом остатка) и
## конвертируется в +1 skill_points
var skill_progress := 0
@export var skill_progress_per_point := 10

# --- Деревья навыков (Save/skill_trees.gd: у каждого героя свои три) ---
## id открытых узлов. Персистится через SaveManager (apply_to/capture_from),
## бонусы считает recompute_skill_modifiers() — сам список ничего не применяет
var unlocked_skills: Array[String] = []
## Сумма эффектов открытых узлов: ключ -> число (SkillTrees.sum_effects).
## Читать через skill(key); пересчитывается целиком, никогда не правится
var skill_fx: Dictionary = {}
## Базовые максимумы ДО бонусов дерева — от них пересчёт, а не от текущих,
## иначе повторная загрузка задваивала бы бонус
const BASE_MAX_STAMINA := 100.0
var _base_max_health := -1.0
var _base_stamina_regen := -1.0
## Перекат: окно «следующий перекат дешевле» и ускоренный реген выносливости
## после переката (Закон дикого леса)
var _chain_roll_left := 0.0
var _roll_regen_left := 0.0

## Открыт магазин (Shop/shop_menu.gd ставит/снимает) — персонаж стоит и не
## реагирует на ввод, как рыцарь (player.gd::is_in_shop)
var is_in_shop := false

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
	# ноды (см. enemy.gd, gold_wisp.gd, shop_trigger.gd) — без этого персонаж просто
	# не существует для всего остального мира
	add_to_group("player")

	_focus = FocusSystemScript.new()
	_focus.name = "FocusSystem"
	_focus.snap_radius = snap_radius
	_focus.break_range = focus_break_range
	_focus.marker_offset = focus_marker_offset
	add_child(_focus)

	# Этажность карты — тот же компонент, что у рыцаря (depth_component.gd):
	# лестницы уменьшают героя при спуске и увеличивают при подъёме
	var depth := DepthComponentScript.new()
	depth.name = "DepthComponent"
	add_child(depth)
	# Вес в движении: наклон на беге, сжатие и пыль на старте/остановке
	var feel := MotionFeelScript.new()
	feel.name = "MotionFeel"
	add_child(feel)

	sprite = _find_child_of_type(AnimatedSprite2D) as AnimatedSprite2D
	camera = _find_child_of_type(Camera2D) as Camera2D
	health_bar = get_node_or_null("HealthStaminaBar")
	if health_bar:
		health_bar.set_max_hp(max_health)
	# unlocked_skills сейчас пуст (SaveManager.apply_to зальёт его позже и
	# пересчитает ещё раз) — здесь только запоминаются базовые значения
	recompute_skill_modifiers()
	_build_condition_fx()

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
	_guard_finite()

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			is_invulnerable = false
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
	if not is_in_shop:
		_record_buffered_presses()

	# Хвост переката (неуязвимость кончилась) обрывается любым действием —
	# нажатым хоть заранее (буфер). Раньше нажатое ждало конца клипа
	if is_rolling and roll_control >= roll_cancel_time and _any_action_pressed():
		_end_roll()
		velocity = Vector2.ZERO

	if is_rolling:
		_handle_roll(delta)
		return

	# Дэш: пока летит, ввод — только второе нажатие пробела (перекат)
	if is_dodging:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		handle_roll_input()
		if is_rolling:
			_handle_roll(delta)
			return
		_handle_dash(delta)
		if is_dodging:
			return

	if is_in_shop:
		velocity = Vector2.ZERO
		play_movement_animation()
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
	if is_dodging:
		_handle_dash(delta)
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

	# Реакция на удар: стоим, пока не отыграла (Take_Damage_ не перебивается
	# ходьбой), только перекат выше может её прервать
	if _hurt_timer > 0.0:
		velocity = velocity.lerp(Vector2.ZERO, minf(move_friction * delta, 1.0))
		move_and_slide()
		return

	_focus.poll_input()
	check_for_turn()
	if is_turning:
		# Гасим рывок трением и держим движение только по нему — та же
		# блокирующая ветка, что у рыцаря на время анимации разворота
		turn_velocity = turn_velocity.lerp(Vector2.ZERO, turn_friction * delta)
		velocity = turn_velocity
		move_and_slide()
		return
	handle_attack_input()

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0
			combo_queued = false

	# Удар отыгран — хвост клипа не держит: в очереди следующий удар серии —
	# сразу он; жмут направление — отмах обрывается и герой идёт
	if is_attacking and _attack_recovery and not is_run_attacking:
		if combo_queued and combo_step < combo_length:
			start_attack(combo_step + 1)
		elif input_vector != Vector2.ZERO and not combo_queued:
			_cancel_attack()
			play_movement_animation()

	if is_attacking:
		if not is_run_attacking:
			_steer_attack()
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
			_attack_step_velocity = _attack_step_velocity.lerp(Vector2.ZERO, attack_step_friction * delta)
			velocity = _attack_step_velocity
		move_and_slide()
		return

	_apply_free_movement(delta)
	move_and_slide()
	_update_facing()
	play_movement_animation()
	_handle_footsteps(delta)


var _last_finite_pos := Vector2.ZERO
var _nan_reported := false

## Санитизация от NaN — та же, что у врагов (enemy.gd::_physics_process).
## Если центр героя почти совпал с центром врага (шаг удара в крупного
## топорника, нокбэк вплотную), move_and_slide при расталкивании может
## получить вырожденную нормаль, и позиция/скорость становятся NaN. Дальше NaN
## расползается сам: move_and_slide каждый кадр спамит "Vector2 cannot be
## normalized", камера улетает — игра выглядит зависшей. Здесь: вернуть на
## последнюю нормальную позицию (+полпикселя в сторону, чтобы центры снова не
## совпали) и обнулить все скорости. Подробности — один раз в лог
func _guard_finite() -> void:
	if global_position.is_finite() and velocity.is_finite() and facing_dir.is_finite() \
			and _attack_step_velocity.is_finite() and _run_dash_velocity.is_finite() \
			and knockback_velocity.is_finite() and turn_velocity.is_finite() and roll_dir.is_finite():
		_last_finite_pos = global_position
		return
	if not _nan_reported:
		_nan_reported = true
		push_warning("[%s NaN] pos=%s vel=%s step=%s dash=%s kb=%s turn=%s roll=%s facing=%s attacking=%s run_attack=%s rolling=%s last_pos=%s" % [
			name, global_position, velocity, _attack_step_velocity, _run_dash_velocity, knockback_velocity,
			turn_velocity, roll_dir, facing_dir, is_attacking, is_run_attacking, is_rolling, _last_finite_pos])
	if not global_position.is_finite():
		global_position = _last_finite_pos + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	velocity = Vector2.ZERO
	_attack_step_velocity = Vector2.ZERO
	_run_dash_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	turn_velocity = Vector2.ZERO
	if not roll_dir.is_finite():
		roll_dir = Vector2.ZERO
	if not facing_dir.is_finite():
		facing_dir = direction_to_vector(last_direction)
		if facing_dir == Vector2.ZERO:
			facing_dir = Vector2.DOWN


## Страховка от "залипшего" бега: Windows иногда съедает отпускание Shift
## (Alt+Shift — смена раскладки, Ctrl+Shift и т.п.), и Godot считает клавишу
## зажатой, пока её не нажмут снова — персонаж бежит сам. Любое событие
## клавиатуры/мыши несёт реальное состояние Shift (shift_pressed): если
## Shift отпущен, а действие "run" всё ещё висит — отпускаем его вручную
func _input(event: InputEvent) -> void:
	if not (event is InputEventWithModifiers) or event.shift_pressed:
		return
	# Событие самой клавиши Shift не в счёт — Godot на Windows отдаёт его
	# с shift_pressed = false даже при нажатии
	if event is InputEventKey and (event.physical_keycode == KEY_SHIFT or event.keycode == KEY_SHIFT):
		return
	if Input.is_action_pressed("run") and _run_bound_to_shift():
		Input.action_release("run")


## ── Буфер ввода ──
## Нажатие, пришедшееся на момент, когда действие невозможно (перекат, реакция
## на удар, отлёт, ещё идущий удар), не теряется: живёт input_buffer_time
## секунд реального времени (не игрового — под замедлением Juice окно не
## растягивается) и срабатывает, как только действие станет доступно.
## Обработчики ввода читают нажатие через _pressed() вместо
## Input.is_action_just_pressed и гасят его _consume(), когда действие
## реально началось. Блок/парирование не буферизуются — там важен точный тайминг
@export var input_buffer_time := 0.2
const BUFFERED_ACTIONS := ["attack", "ui_accept", "parry", "kick", "special"]
var _press_ms := {}


## Наследник добавляет свои действия (маг — ледяные руны и толчок посохом)
func _buffered_actions() -> Array:
	return BUFFERED_ACTIONS


func _record_buffered_presses() -> void:
	for action in _buffered_actions():
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			_press_ms[action] = Time.get_ticks_msec()


## Было ли нажатие за последние input_buffer_time секунд (и ещё не потрачено)
func _pressed(action: String) -> bool:
	if not _press_ms.has(action):
		return false
	if Time.get_ticks_msec() - int(_press_ms[action]) > int(input_buffer_time * 1000.0):
		_press_ms.erase(action)
		return false
	return true


func _consume(action: String) -> void:
	_press_ms.erase(action)


func _any_action_pressed() -> bool:
	for action in _buffered_actions():
		if _pressed(action):
			return true
	return false


func _run_bound_to_shift() -> bool:
	for e in InputMap.action_get_events("run"):
		if e is InputEventKey and (e.physical_keycode == KEY_SHIFT or e.keycode == KEY_SHIFT):
			return true
	return false


## Обычное свободное движение по input_vector — вынесено отдельно, чтобы тем
## же кодом мог пользоваться выстрел на бегу (run_attack_keeps_moving): там
## нужна ровно та же скорость и тот же разгон/торможение, что и без атаки
func _apply_free_movement(delta: float) -> void:
	var target_speed := walk_speed
	if is_exhausted():
		target_speed = walk_speed * exhausted_speed_multiplier
	elif is_running and input_vector != Vector2.ZERO:
		if is_instance_valid(health_bar):
			health_bar.use_stamina(run_stamina_drain * delta)
		target_speed = run_speed
	var target_velocity := input_vector.normalized() * target_speed

	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(target_velocity, minf(move_accel * delta, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, minf(move_friction * delta, 1.0))


## Стамина на нуле — то же условие, что у рыцаря (player.gd::is_exhausted).
## Без HUD стамины нет — и истощения тоже
func is_exhausted() -> bool:
	return is_instance_valid(health_bar) and health_bar.current_stamina <= 0.0


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
	if speed < 10.0:
		_play_loco("Idle_" + last_direction)
		return
	# Темп шага — по реальной скорости: разгоняется/тормозит тело — так же
	# ноги, без скольжения по земле
	var cadence := clampf(speed / walk_speed, 0.6, 1.9)
	match _locomotion_mode():
		LOCO_SIDE:
			var strafe := _strafe_clip()
			if strafe != "":
				_play_loco(strafe, cadence)
				return
		LOCO_BACK:
			# Ходьба спиной вперёд — лицом к врагу. У лучницы и мага клипы
			# собраны из строк листа один в один (build_*_anims.gd), а строка
			# листа RunBackwards — направление ЛИЦА (сверено по кадрам), поэтому
			# суффикс — направление взгляда. (У рыцаря клипы Backwards_ в
			# player.tres подписаны по движению — у него в player.gd своё.) Имена у
			# классов разные: у лучника Backward_, у мага Backwards_
			for prefix in ["Backward_", "Backwards_"]:
				if _has_clip(prefix + last_direction):
					_play_loco(prefix + last_direction, cadence)
					return
	if speed >= 120.0:
		_play_loco("Run_" + last_direction)
	else:
		_play_loco("Walk_" + last_direction, minf(cadence, 1.2))


## Направления по кругу по часовой стрелке на экране — в этом же порядке идут
## строки листов анимаций (Right, Down_Right, Down, ...)
const DIR_RING := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]
## Left/Right в листах стрейфа подписаны со стороны зрителя, а не персонажа
## (так у Сигрид — сверено по кадрам; у рыцаря — со стороны персонажа)
@export var strafe_names_swapped := false
## Под фокусом: куда идёт корпус относительно взгляда на врага. Пороги — cos
## угла между движением и взглядом, с запасом (гистерезис): в стрейф входим
## при |cos| < strafe_enter (~63..117°), выходим только при |cos| >
## strafe_exit (~41°/139°) — иначе, кружа вокруг врага, анимация дёргалась
## бы между ходьбой, стрейфом и ходьбой назад на каждом пересечении порога
@export var strafe_enter := 0.45
@export var strafe_exit := 0.75
const LOCO_FORWARD := 0
const LOCO_SIDE := 1
const LOCO_BACK := 2
var _loco_mode := LOCO_FORWARD


func _locomotion_mode() -> int:
	if input_vector == Vector2.ZERO or not _focus.has_target() or _focus.is_fleeing(input_vector, is_running):
		_loco_mode = LOCO_FORWARD
		return _loco_mode
	var d := input_vector.normalized().dot(facing_dir)
	match _loco_mode:
		LOCO_SIDE:
			if d > strafe_exit:
				_loco_mode = LOCO_FORWARD
			elif d < -strafe_exit:
				_loco_mode = LOCO_BACK
		_:
			if absf(d) < strafe_enter:
				_loco_mode = LOCO_SIDE
			elif d < -strafe_enter:
				_loco_mode = LOCO_BACK
			else:
				_loco_mode = LOCO_FORWARD
	return _loco_mode


## Стрейф под фокусом: лицо на враге, ноги идут вбок. Строка листа
## StrafeLeft/StrafeRight — направление ДВИЖЕНИЯ, лицо в ней повёрнуто на 90°
## (сверено по кадрам). Поэтому строку берём от направления ВЗГЛЯДА со
## сдвигом на четверть круга — тогда в выбранном клипе лицо смотрит ровно туда
## же, куда и до стрейфа: на врага. Влево или вправо — по знаку поворота от
## взгляда к движению. Имена Left/Right у части листов — со стороны зрителя
## (strafe_names_swapped: Сигрид, Frost-маг)
func _strafe_clip() -> String:
	if input_vector == Vector2.ZERO or not _focus.has_target():
		return ""
	var move := input_vector.normalized()
	var i := DIR_RING.find(last_direction)
	if i < 0:
		return ""
	var right := "StrafeLeft_" if strafe_names_swapped else "StrafeRight_"
	var left := "StrafeRight_" if strafe_names_swapped else "StrafeLeft_"
	var clip: String
	if facing_dir.cross(move) > 0.0:
		clip = right + DIR_RING[(i + 2) % 8]
	else:
		clip = left + DIR_RING[(i + 6) % 8]
	return clip if _has_clip(clip) else ""


## Взгляд держит фокус на враге, а WASD ведёт корпус в противоположную
## сторону — тот же признак, что у рыцаря (player.gd::_is_moving_backward)
func _is_moving_backward() -> bool:
	return _locomotion_mode() == LOCO_BACK


## Имя клипа с учётом стойки (лучница подставляет мечевые Sword_-версии,
## archer.gd). База имён не меняет
func _clip_name(anim_name: String) -> String:
	return anim_name


func _has_clip(anim_name: String) -> bool:
	return anim.has_animation(_clip_name(anim_name))


## Клипы шагов (стойка, ходьба, бег, стрейф, спиной) при смене направления или
## вида шага продолжаются с той же фазы шага, а не с первого кадра — как у
## рыцаря (player.gd::_play_keep_phase): под фокусом направление меняется на
## ходу, и перезапуск каждый раз давал бы спотыкание. speed — темп шага
const LOCO_PREFIXES := ["Walk_", "Run_", "StrafeLeft_", "StrafeRight_", "Backward_", "Backwards_"]
var _loco_speed := 1.0

func _play_loco(anim_name: String, speed := 1.0) -> void:
	var clip := _clip_name(anim_name)
	if not anim.has_animation(clip):
		return
	speed = snappedf(speed, 0.1)
	var prev := String(anim.current_animation)
	if prev == clip and is_equal_approx(speed, _loco_speed):
		return
	var phase := -1.0
	if prev != "" and _is_loco(prev) and _is_loco(clip) and anim.current_animation_length > 0.0:
		phase = anim.current_animation_position / anim.current_animation_length
	_loco_speed = speed
	anim.play(clip, -1, speed)
	if phase >= 0.0:
		anim.seek(phase * anim.current_animation_length, true)


func _is_loco(clip: String) -> bool:
	var c := clip.trim_prefix("Sword_")
	for p in LOCO_PREFIXES:
		if c.begins_with(p):
			return true
	return false

# ─────────────────────────────────────────────
# РАЗВОРОТ НА МЕСТЕ (Turn_)
# ─────────────────────────────────────────────
# Та же механика, что у рыцаря (player.gd::check_for_turn/start_turn): на
# бегу резко зажали противоположное направление — вместо скольжения корпусом
# назад проигрывается рывок-разворот. Направление в имени клипа
# (Turn_Right/Turn_Left/...) — КУДА персонаж разворачивается, а не откуда,
# ровно как у рыцаря (см. new_last_direction ниже)

func check_for_turn() -> void:
	if is_attacking or is_run_attacking or is_rolling:
		return
	# Пока враг в фокусе, взгляд держит _update_facing, а не этот рывок — то
	# же исключение, что у рыцаря: прямой побег бегом уже сам снял лок там
	if _focus.has_target() and not _focus.is_fleeing(input_vector, is_running):
		return
	if input_vector == Vector2.ZERO or turn_lock:
		return
	if velocity.length() < run_speed * 0.6:
		return

	var input_dir := input_vector.normalized()
	# Почти противоположное текущему взгляду направление — разворот, а не
	# обычный поворот на несколько градусов
	if input_dir.dot(facing_dir) < -0.7:
		start_turn(input_dir)


func start_turn(new_dir: Vector2) -> void:
	var new_facing := new_dir.normalized()
	var new_last_direction := get_direction(new_facing)
	# У лучника клипы разворота — Turn_, у мага — Turn_Around_
	var anim_name := "Turn_" + new_last_direction
	if not anim.has_animation(anim_name):
		anim_name = "Turn_Around_" + new_last_direction

	# Клипа под это направление может не быть (пока не у всех классов
	# нарисованы все 8) — тогда просто меняем взгляд без рывка и блокировки,
	# как и везде в этом файле (has_animation-паттерн)
	if not anim.has_animation(anim_name):
		facing_dir = new_facing
		last_direction = new_last_direction
		return

	turn_lock = true
	is_turning = true
	facing_dir = new_facing
	last_direction = new_last_direction
	# Гасим набранную скорость, а не обнуляем — рывок продолжает нести тело
	# по инерции, как у рыцаря (turn_velocity = velocity * 0.4)
	turn_velocity = velocity * 0.4

	_play(anim_name)
	_play_turn_dust()


## Пыль под ногами на развороте (VFX/VFX_scene/skid_dust.gd): направление и
## позиция берутся из текущей скорости, а не из FootPoint-маркера — его нет
## ни у лучника, ни у мага; ноги — чуть ниже опорной точки тела
func _play_turn_dust() -> void:
	var dir := velocity.normalized()
	if dir == Vector2.ZERO:
		dir = direction_to_vector(last_direction)
	var power := clampf(velocity.length() / maxf(run_speed, 1.0), 0.6, 1.2) if "run_speed" in self else 0.9
	SkidDust.skid(get_tree(), global_position + Vector2(0, 14) - dir * 4.0, dir, SkidDust.Kind.TURN, power)


# ─────────────────────────────────────────────
# ПЕРЕКАТ
# ─────────────────────────────────────────────

## У рыцаря пробел копится в окне dodge_tap_window и решает додж/перекат по
## числу тапов. Лучнику додж не нужен — один тап сразу перекат
func handle_roll_input() -> void:
	if is_rolling:
		return
	if not _pressed("ui_accept"):
		return
	_consume("ui_accept")
	if not dash_enabled:
		start_roll()
		return
	# Второе нажатие в окне после дэша — перекат (дэш обрывается)
	var now := Time.get_ticks_msec()
	if now - _dash_tap_ms <= int(double_tap_window * 1000.0):
		_dash_tap_ms = -100000
		_end_dash()
		start_roll()
		return
	_dash_tap_ms = now
	start_dash()


# ─────────────────────────────────────────────
# ДЭШ
# ─────────────────────────────────────────────

## Свои имена констант: у наследников уже есть FlurryFx/MageFx (archer.gd,
## mage.gd), а повторное имя в наследнике — ошибка разбора
const DashFlurryFx := preload("res://VFX/VFX_scene/flurry_fx.gd")
const MageFxBase := preload("res://Player_scene/mage_fx.gd")

## Куда: зажатое направление; без него — шаг назад от взгляда (отскок).
## Под фокусом взгляд остаётся на враге — дэш вбок идёт стрейфом
func start_dash() -> void:
	if is_dodging or is_rolling:
		return
	var dir := input_vector.normalized() if input_vector != Vector2.ZERO else -facing_dir
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	if is_instance_valid(health_bar) and not health_bar.use_stamina(dash_stamina_cost):
		return
	_cancel_attack()
	knockback_velocity = Vector2.ZERO
	_hurt_timer = 0.0
	is_dodging = true
	_dash_left = dash_duration
	_dash_dir = dir
	_dash_ghost_t = 0.0
	set_collision_mask_value(3, false)
	dodge_velocity = dir * dash_speed
	velocity = dodge_velocity
	input_vector = dir
	_update_facing()
	play_movement_animation()
	_dash_fx_start(dir)


func _handle_dash(delta: float) -> void:
	_dash_left -= delta
	var k := clampf(_dash_left / maxf(dash_duration, 0.01), 0.0, 1.0)
	# Почти полная скорость до последней трети — резко, потом гасится
	dodge_velocity = _dash_dir * dash_speed * clampf(k * 1.6, 0.25, 1.0)
	velocity = dodge_velocity
	move_and_slide()
	_dash_ghost_t -= delta
	if _dash_ghost_t <= 0.0:
		_dash_ghost_t = 0.03
		DashFlurryFx.ghost(self, sprite, 1, _dash_dir, 0.24, dash_ghost_tint)
	if _dash_left <= 0.0:
		_end_dash()
		SkidDust.skid(get_tree(), global_position + Vector2(0, 14), _dash_dir, SkidDust.Kind.STOP, 0.7)
		play_movement_animation()


func _end_dash() -> void:
	if not is_dodging:
		return
	is_dodging = false
	_dash_left = 0.0
	dodge_velocity = Vector2.ZERO
	set_collision_mask_value(3, true)


## Старт рывка: пыль и линии скорости из-под ног (как рывок рыцаря), вспышка
## и звёздочки воздуха, свист, лёгкий толчок камеры
func _dash_fx_start(dir: Vector2) -> void:
	DashFlurryFx.lunge(self, dir, 1.3)
	var col := dash_ghost_tint if dash_ghost_tint.a > 0.0 else DashFlurryFx.GHOST
	var h := MageFxBase.holder(get_tree(), global_position + Vector2(0, -4), 0.6, 12)
	MageFxBase.flash(h, 22.0, 0.12, col)
	MageFxBase.burst(h, 10, 0.3, MageFxBase.streak(), func(pm: ParticleProcessMaterial):
		pm.particle_flag_align_y = true
		pm.direction = Vector3(-dir.x, -dir.y, 0)
		pm.spread = 22.0
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 8.0
		pm.initial_velocity_min = 90.0
		pm.initial_velocity_max = 200.0
		pm.damping_min = 300.0
		pm.damping_max = 500.0
		pm.scale_min = 0.25
		pm.scale_max = 0.5
		pm.color_ramp = MageFxBase.ramp([Color(1, 1, 1, 0.9), Color(col, 0.6), Color(col, 0.0)]))
	SoundBank.play_at(get_tree(), "knight_swing", global_position, -9.0, 1.6)
	shake_camera(1.5, 0.08)


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
	if is_instance_valid(health_bar) and not health_bar.use_stamina(_roll_cost()):
		return
	# Без следа: следующий перекат в окне дешевле; Звериный выдох — реген
	if skill("chain_roll_cost_percent") != 0.0:
		_chain_roll_left = 3.0
	if skill("after_roll_stamina_regen_percent") > 0.0:
		_roll_regen_left = 3.0

	roll_control = 0.0
	is_rolling = true
	# Перекат прерывает начатую атаку — как двойной тап у рыцаря
	# (interrupt_all_actions): иначе можно застрять между Attack_ и Rolling_
	_cancel_attack()
	knockback_velocity = Vector2.ZERO
	_hurt_timer = 0.0
	# Слой 3 = "enemy" (project.godot/layer_names) — на время переката
	# проходим сквозь врагов физически, как и рыцарь
	set_collision_mask_value(3, false)

	roll_dir = dir
	facing_dir = dir
	last_direction = dir_name
	# Перекат, оборванный новым в ту же сторону, — клип с начала, а не с середины
	var roll_clip := _clip_name("Rolling_" + dir_name)
	var same_clip := String(anim.current_animation) == roll_clip
	_play("Rolling_" + dir_name)
	if same_clip:
		anim.seek(0.0, true)
	dodge_velocity = roll_dir * roll_speed


## Неуязвимость уклона: начало переката или весь дэш
func _roll_invulnerable() -> bool:
	return (is_rolling and roll_control <= roll_iframes_end) or is_dodging


func _end_roll() -> void:
	is_rolling = false
	set_collision_mask_value(3, true)
	dodge_velocity = Vector2.ZERO
	roll_control = 0.0


## Перекат доигран до конца. Для наследников — Танец Валькирии у лучницы
## заряжает здесь следующий выстрел
func _on_roll_finished() -> void:
	pass


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
	if not _pressed("attack"):
		return
	if is_attacking:
		if combo_step < combo_length:
			combo_queued = true
			_consume("attack")
		return
	_consume("attack")
	if is_running and input_vector != Vector2.ZERO:
		start_run_attack()
		return
	start_attack(1)


## Атака на бегу — отдельное действие, а не шаг серии: не входит в комбо
## (combo_step/combo_queued тут не участвуют), запускается и заканчивается
## сама по себе, как рывок мечом у рыцаря
func start_run_attack() -> void:
	_attack_recovery = false
	is_attacking = true
	combo_step = 0
	combo_queued = false

	facing_dir = input_vector.normalized()
	last_direction = get_direction(facing_dir)

	# Анимации ещё может не быть (has_animation-паттерн, как и везде в этом
	# файле) — тогда тихо откатываемся на обычный удар стоя, а не на пустое
	# нажатие без всякой реакции
	if not _play_restart("Run_Attack_" + last_direction):
		is_attacking = false
		start_attack(1)
		return

	is_run_attacking = true
	_run_dash_velocity = facing_dir * run_attack_dash_speed

	var aim: Node2D = _pick_aim()
	_on_attack_started(0, aim)


func start_attack(step: int) -> void:
	_attack_recovery = false
	is_attacking = true
	is_run_attacking = false
	combo_step = step
	combo_queued = false
	combo_timer = combo_window
	# Хвост шага прошлого удара серии не тащит в новый
	_attack_step_velocity = Vector2.ZERO

	# Приоритет наведения: взятая в фокус цель > ближайший враг > направление
	# ввода. Тот же порядок, что у рыцаря (player.gd::try_snap_to_enemy):
	# если игрок явно выбрал врага, бить надо именно его, а не того, кто
	# случайно оказался ближе в толпе
	var aim: Node2D = _pick_aim()
	_turn_to_aim(aim)

	# Первый удар — Attack_, дальше Attack_2_, Attack_3_ и т.д. Клипа под шаг
	# может не быть — тогда переигрываем первый, а не обрываем всю серию (тот
	# же подход, что у рыцаря в player.gd: комбо не должно молча ломаться)
	var prefix := "Attack_" if step == 1 else "Attack_%d_" % step
	if not _play_restart(prefix + last_direction):
		if not _play_restart("Attack_" + last_direction):
			is_attacking = false
			return

	_on_attack_started(step, aim)


## Развернуться к цели удара, а без цели — туда, куда жмут стрелки
func _turn_to_aim(aim: Node2D) -> void:
	if is_instance_valid(aim):
		var to_aim := (aim.global_position - global_position).normalized()
		var aim_dir := get_direction(to_aim)
		if aim_dir != "":
			facing_dir = to_aim
			last_direction = aim_dir
	elif _aim_dir() != Vector2.ZERO:
		facing_dir = _aim_dir()
		last_direction = get_direction(facing_dir)


## Кого бить/в кого стрелять. Приоритет: взятая в фокус цель > ближайший
## враг. Наследник может переопределить — лучница с Пером Хугина сначала
## ищет помеченных врагов (archer.gd)
func _pick_aim() -> Node2D:
	return _focus.target if _focus.has_target() else _assist_target()


## Цель без фокуса. Зажато направление — ближайший враг в конусе
## aim_assist_cone_deg вокруг него (иначе бьём/стреляем туда, куда жмут).
## Направления нет — ближайший в радиусе snap_radius
## Куда целится игрок: с «Прицелом мышью» (GameSettings.mouse_aim) — на курсор,
## иначе — по стрелкам. ZERO — направления нет
func _aim_dir() -> Vector2:
	if GameSettings.mouse_aim:
		var to := get_global_mouse_position() - global_position
		return to.normalized() if to.length() > 4.0 else Vector2.ZERO
	return input_vector.normalized() if input_vector != Vector2.ZERO else Vector2.ZERO


func _assist_target() -> Node2D:
	var dir := _aim_dir()
	var min_dot := cos(deg_to_rad(aim_assist_cone_deg))
	var best: Node2D = null
	var best_d := snap_radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var to: Vector2 = (e as Node2D).global_position - global_position
		var d := to.length()
		if d > best_d or d < 0.001:
			continue
		if dir != Vector2.ZERO and to.normalized().dot(dir) < min_dot:
			continue
		best_d = d
		best = e
	return best


## Шаг вперёд на ударе: скорость velocity гаснет attack_step_friction (см. там же)
func attack_step(velocity_: Vector2) -> void:
	if is_attacking and not is_run_attacking:
		_attack_step_velocity = velocity_


## Переопределяют наследники — сюда вешается конкретный эффект удара: выстрел
## стрелой у лучника, заклинание у мага. В базе пусто: сама анимация уже
## отыграна к этому моменту, aim — та же цель, на которую только что
## развернулось наведение (null, если целей рядом не было)
func _on_attack_started(_step: int, _aim: Node2D) -> void:
	pass


func _on_animation_finished(finished_anim: String) -> void:
	if finished_anim.begins_with("Turn_"):
		is_turning = false
		turn_lock = false
		velocity = Vector2.ZERO
		play_movement_animation()
		return
	if finished_anim.begins_with("Rolling_"):
		_end_roll()
		velocity = Vector2.ZERO
		play_movement_animation()
		_on_roll_finished()
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
	if is_dead() or is_invulnerable or _roll_invulnerable():
		return false
	# Удар на хвосте переката: Rolling_ заменится реакцией и не доиграет
	if is_rolling:
		_end_roll()
	var amount: float = float(attack_data.get("damage", 0)) * _incoming_damage_mult(attack_data)
	# Кора от союзника (кооп, Net/ally_shield.gd) принимает удар первой.
	# Поглотила целиком — ни урона, ни реакции, только вспышка
	amount = preload("res://Net/ally_shield.gd").absorb(self, amount)
	if amount <= 0.0:
		_flash_hit()
		is_invulnerable = true
		_invuln_timer = post_hit_invulnerability
		return true
	health = maxf(health - amount, 0.0)
	if is_instance_valid(health_bar):
		health_bar.take_damage(amount)
	# Тяжёлый приём (суперброня, _has_hyper_armor) удар не обрывает: урон
	# проходит, но ни отлёта, ни реакции. Иначе удар обрывает начатую атаку —
	# Take_Damage_ заменяет её клип, и без сброса is_attacking персонаж так и
	# стоял бы в атаке, которая уже никогда не доиграет
	if not _has_hyper_armor():
		_cancel_attack()
		play_take_damage()
		_apply_knockback(attack_data.get("source", null))
		_hurt_timer = hurt_lock_time
	_flash_hit()
	BloodFx.hit(self, attack_data.get("source", null) as Node2D, BloodFx.power_for(amount, max_health, is_dead()))
	shake_camera(4.0)
	_flash_damage_screen()
	is_invulnerable = true
	_invuln_timer = post_hit_invulnerability
	if is_dead():
		_die()
	return true


func is_dead() -> bool:
	return health <= 0.0


## Оборвать текущий удар (урон, перекат). Наследники дочищают своё: натяжение
## и хитбокс клинка у лучницы
func _cancel_attack() -> void:
	_attack_recovery = false
	is_attacking = false
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	_attack_step_velocity = Vector2.ZERO
	_run_dash_velocity = Vector2.ZERO
	# Turn_ тоже заменяется клипом урона/переката и уже не доиграет
	is_turning = false
	turn_lock = false


## Тяжёлый приём, который не сбивается попаданием (у Сигрид — финиш серии
## мечом и выпад). В базе — никакой
func _has_hyper_armor() -> bool:
	return false


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


# ─────────────────────────────────────────────
# КАМЕРА: ТРЯСКА, ПОКАЧИВАНИЕ НА БЕГУ, ДРОЖЬ ИСТОЩЕНИЯ — как у рыцаря
# ─────────────────────────────────────────────
# Та же система, что в player.gd (_process): тряска — затухающая "травма",
# а не твин на удар, поэтому повторные удары накладываются без рывков; на
# беге камера плавно качается восьмёркой; при истощённой стамине — дрожь
# уставших рук. Числа — рыцарские. Множитель тряски из настроек
# (GameSettings.shake_multiplier) накрывает тряску и дрожь, но не походку

## Сила тряски на своё попадание по врагу (её дёргает Juice.hit) и на урон
@export var hit_shake_strength := 3.0
@export var shake_decay := 6.0   # чем больше — тем быстрее гаснет
@export var run_bob_amplitude_x := 5.0
@export var run_bob_amplitude_y := 3.5
@export var run_bob_cycle_distance := 90.0  # больше = медленнее и спокойнее качает
@export var run_bob_fade_speed := 7.5
@export var run_bob_smoothing := 11.0
@export var exhaust_shake_strength := 2.0
@export var exhaust_shake_update_rate := 0.09  # как часто меняется цель дрожи
@export var exhaust_shake_smoothing := 18.0
## Истощение: начинается на нулевой стамине, кончается, когда она
## восстановилась до этого (гистерезис, иначе дрожь моргала бы у нуля)
@export var exhaust_recover_threshold := 50.0

var _shake_strength := 0.0
var _bob_phase := 0.0
var _bob_intensity := 0.0
var _bob_smoothed := Vector2.ZERO
var _exhausted := false
var _exhaust_timer := 0.0
var _exhaust_target := Vector2.ZERO
var _exhaust_current := Vector2.ZERO


## Тряска камеры. duration оставлен для совместимости со старыми вызовами —
## длительность теперь задаёт сама сила (травма гаснет со скоростью shake_decay)
func shake_camera(strength: float, _duration := 0.18) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func _process(delta: float) -> void:
	_update_condition_fx(delta)
	_update_camera_feel(delta)
	_update_skill_timers(delta)


## Таймеры навыков переката: окно дешёвого переката и ускоренный реген
## выносливости (реген живёт в полоске — множитель ставится туда же)
func _update_skill_timers(delta: float) -> void:
	_chain_roll_left = maxf(_chain_roll_left - delta, 0.0)
	_roll_regen_left = maxf(_roll_regen_left - delta, 0.0)
	if is_instance_valid(health_bar) and _base_stamina_regen >= 0.0:
		var bonus := skill("after_roll_stamina_regen_percent") if _roll_regen_left > 0.0 else 0.0
		health_bar.stamina_regen = _base_stamina_regen * (1.0 + bonus / 100.0)


# ─────────────────────────────────────────────
# СОСТОЯНИЕ НА ГРАНИ — как у рыцаря (player.gd::_update_condition_fx)
# ─────────────────────────────────────────────
# Красная виньетка + белая вспышка на урон, голубая виньетка и одышка при
# истощении, сердцебиение на низком HP и при истощении. У рыцаря это ноды в
# player.tscn — здесь те же скрипты/шейдер/звуки собираются кодом, чтобы не
# трогать archer.tscn/mage.tscn. Шаги — те же семплы, что у рыцаря

const DamageVignetteScript := preload("res://UI/damage_vignette.gd")
const SustainedVignetteScript := preload("res://UI/sustained_vignette.gd")
const HitFlashScript := preload("res://UI/hit_flash.gd")
const VIGNETTE_SHADER := preload("res://UI/damage_vignette.gdshader")
const HEARTBEAT_SOUND := preload("res://Sound/pulse.mp3")
const DYSPNEA_SOUND := preload("res://Sound/ambient_sound/dyspnea.mp3")
const SoundBank := preload("res://Levels/sound_bank.gd")
const FOOTSTEP_LEFT := preload("res://Sound/Run/left-leg.wav")
const FOOTSTEP_RIGHT := preload("res://Sound/Run/right-leg.wav")
const HEARTBEAT_SILENT_DB := -40.0

@export var low_health_threshold := 20.0
## Пульс и одышка — тише, чем было (-18 / +3 / -3): в долгой игре давили на
## уши. Те же числа — у рыцаря (player.gd)
@export var heartbeat_volume_low_hp := -26.0
@export var heartbeat_volume_exhausted := -6.0
@export var heartbeat_fade_speed := 25.0
@export var dyspnea_volume := -12.0
@export var footstep_step_distance := 42.0

var _damage_vignette: CanvasLayer
var _hit_flash: CanvasLayer
var _exhaust_vignette: CanvasLayer
var _heartbeat: AudioStreamPlayer
var _dyspnea: AudioStreamPlayer
var _footstep: AudioStreamPlayer2D
var _footstep_distance := 0.0
var _footstep_left_next := true


func _build_condition_fx() -> void:
	_damage_vignette = _make_screen_layer("DamageVignette", DamageVignetteScript,
			_vignette_material(Color(0.75, 0, 0, 1), 0.55, 0.55))
	_exhaust_vignette = _make_exhaust_layer()
	_hit_flash = _make_screen_layer("HitFlash", HitFlashScript, null)
	_heartbeat = _make_loop_player("HeartbeatAudio", HEARTBEAT_SOUND)
	_dyspnea = _make_loop_player("DyspneaAudio", _dyspnea_stream())
	_footstep = AudioStreamPlayer2D.new()
	_footstep.name = "FootstepAudio"
	add_child(_footstep)


## Эффект истощения на экране. По умолчанию — голубая виньетка, как у рыцаря;
## наследник может дать свой слой с тем же set_active(on) (Сигрид — вены в
## такт сердцу, UI/sigrid_exhaust.gd)
func _make_exhaust_layer() -> CanvasLayer:
	return _make_screen_layer("ExhaustVignette", SustainedVignetteScript,
			_vignette_material(Color(0.15, 0.45, 0.85, 1), 0.5, 0.6))


## Одышка при истощении. По умолчанию — общая (мужская, как у рыцаря);
## наследник может вернуть свою или null — тогда без одышки
func _dyspnea_stream() -> AudioStream:
	return DYSPNEA_SOUND


func _vignette_material(col: Color, radius: float, softness: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("vignette_color", col)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("softness", softness)
	return mat


## Слой на весь экран со своим ColorRect — скрипты слоёв берут $ColorRect в
## @onready, поэтому ребёнок кладётся ДО добавления слоя в дерево
func _make_screen_layer(layer_name: String, script: Script, mat: ShaderMaterial) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	var rect := ColorRect.new()
	rect.name = "ColorRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mat:
		rect.material = mat
	else:
		rect.color = Color(1, 1, 1, 0)
	layer.add_child(rect)
	layer.set_script(script)
	add_child(layer)
	return layer


func _make_loop_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.stream = stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream != null:
		# WAV зацикливаем перезапуском, а не loop_mode на лету: с неверным
		# loop_end поток замолкает (см. память проекта про дождь уровня)
		p.finished.connect(func():
			if p.volume_db > HEARTBEAT_SILENT_DB + 0.01:
				p.play())
	p.volume_db = HEARTBEAT_SILENT_DB
	add_child(p)
	return p


func _flash_damage_screen() -> void:
	if is_instance_valid(_damage_vignette):
		_damage_vignette.flash()
	if is_instance_valid(_hit_flash):
		_hit_flash.flash()


## Сердцебиение тихо на низком HP и громко при истощении, одышка и голубая
## виньетка — только при истощении (_exhausted — с гистерезисом, см. ниже)
func _update_condition_fx(delta: float) -> void:
	if not is_instance_valid(_heartbeat):
		return
	if is_instance_valid(_exhaust_vignette):
		_exhaust_vignette.set_active(_exhausted and not is_dead())
	var low_hp := health > 0.0 and health <= low_health_threshold
	var exhausted := _exhausted and not is_dead()
	var heart_db := HEARTBEAT_SILENT_DB
	if exhausted:
		heart_db = heartbeat_volume_exhausted
	elif low_hp:
		heart_db = heartbeat_volume_low_hp
	_fade_loop(_heartbeat, exhausted or low_hp, heart_db, delta)
	_fade_loop(_dyspnea, exhausted, dyspnea_volume, delta)


## Плавно ведёт громкость к цели, стартуя с тишины — без щелчков на входе
func _fade_loop(p: AudioStreamPlayer, want: bool, target_db: float, delta: float) -> void:
	if p.stream == null:
		return
	if want and not p.playing:
		p.volume_db = HEARTBEAT_SILENT_DB
		p.play()
	if not p.playing:
		return
	p.volume_db = move_toward(p.volume_db, target_db if want else HEARTBEAT_SILENT_DB, heartbeat_fade_speed * delta)
	if not want and p.volume_db <= HEARTBEAT_SILENT_DB + 0.01:
		p.stop()


## Шаги по пройденному пути — тот же приём, что у рыцаря (player.gd::handle_footsteps)
func _handle_footsteps(delta: float) -> void:
	if not is_instance_valid(_footstep) or velocity.length() < 10.0:
		_footstep_distance = 0.0
		return
	_footstep_distance += velocity.length() * delta
	if _footstep_distance >= footstep_step_distance:
		_footstep_distance = 0.0
		var step_stream := SoundBank.step(get_tree(), global_position)
		_footstep.stream = step_stream if step_stream else (FOOTSTEP_LEFT if _footstep_left_next else FOOTSTEP_RIGHT)
		_footstep.pitch_scale = randf_range(0.88, 1.12)
		_footstep.volume_db = randf_range(-1.8, 1.8)
		_footstep.play()
		_footstep_left_next = not _footstep_left_next


func _update_camera_feel(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var shake_offset := Vector2.ZERO
	if _shake_strength > 0.01:
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, shake_decay * _shake_strength * delta + 1.0 * delta)
	else:
		_shake_strength = 0.0

	# Покачивание на беге — петля: X на одинарной частоте, Y на двойной;
	# амплитуда плавно нарастает/гаснет, позиция догоняет цель сглаженно
	var sprinting := velocity.length() >= 120.0
	_bob_intensity = move_toward(_bob_intensity, 1.0 if sprinting else 0.0, run_bob_fade_speed * delta)
	var bob_target := Vector2.ZERO
	if _bob_intensity > 0.001:
		_bob_phase += velocity.length() * delta
		var t := _bob_phase / run_bob_cycle_distance * TAU
		bob_target = Vector2(sin(t) * run_bob_amplitude_x, sin(t * 2.0) * run_bob_amplitude_y) * _bob_intensity
	_bob_smoothed = _bob_smoothed.lerp(bob_target, minf(run_bob_smoothing * delta, 1.0))

	# Дрожь истощения: цель меняется редко, камера плавно её догоняет —
	# дрожание уставших рук, а не шум
	if is_instance_valid(health_bar):
		var stamina: float = health_bar.current_stamina
		if _exhausted and stamina >= exhaust_recover_threshold:
			_exhausted = false
		elif not _exhausted and stamina <= 0.0:
			_exhausted = true
	_exhaust_timer -= delta
	if _exhausted:
		if _exhaust_timer <= 0.0:
			_exhaust_timer = exhaust_shake_update_rate
			_exhaust_target = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * exhaust_shake_strength
	else:
		_exhaust_target = Vector2.ZERO
	_exhaust_current = _exhaust_current.lerp(_exhaust_target, minf(exhaust_shake_smoothing * delta, 1.0))

	var shake_scale: float = GameSettings.shake_multiplier
	camera.offset = (shake_offset + _exhaust_current) * shake_scale + _bob_smoothed \
			+ _update_look_ahead(delta)


## Камера с упреждением — как у рыцаря (player.gd::_update_look_ahead): на
## бегу чуть вперёд по ходу, с целью в фокусе — к врагу
@export var look_ahead_distance := 22.0
@export var look_ahead_focus_share := 0.3
@export var look_ahead_focus_max := 36.0
@export var look_ahead_smoothing := 2.5
var _look := Vector2.ZERO

func _update_look_ahead(delta: float) -> Vector2:
	var target := Vector2.ZERO
	if is_instance_valid(_focus) and _focus.has_target():
		target = ((_focus.target as Node2D).global_position - global_position) * look_ahead_focus_share
		target = target.limit_length(look_ahead_focus_max)
	elif not is_attacking and not is_rolling:
		target = (velocity / maxf(run_speed, 1.0)).limit_length(1.0) * look_ahead_distance
	_look = _look.lerp(target, minf(look_ahead_smoothing * delta, 1.0))
	return _look


## TODO: анимация смерти, game over — то же самое, что у рыцаря
## (player.gd::_on_player_dead), нигде в проекте пока не реализовано.
## is_dead() уже останавливает _physics_process персонажа (см. выше), так что
## смерть хотя бы не выглядит как зависшее управление
func _die() -> void:
	is_attacking = false
	is_run_attacking = false
	is_turning = false
	turn_lock = false
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	# Анимация смерти, если нарисована (у Сигрид — Die_). Дальше _physics_process
	# уже не работает, так что её никто не перебьёт
	_play("Die_" + last_direction)
	died.emit()


## Кооп (Net._respawn_local): павший встаёт в точке at — у костра или на
## старте уровня — со всем восполненным, как после отдыха, и на пару секунд
## неуязвим, чтобы не пасть снова тут же
func net_respawn(at: Vector2) -> void:
	global_position = at
	preload("res://Levels/bonfire/bonfire.gd").restore_hero(self)
	health = max_health
	_cancel_attack()
	if is_rolling:
		_end_roll()
	knockback_velocity = Vector2.ZERO
	_hurt_timer = 0.0
	velocity = Vector2.ZERO
	is_invulnerable = true
	_invuln_timer = 2.0
	play_movement_animation()
	if is_instance_valid(camera):
		camera.reset_smoothing()


## Игрок ударил в момент парирования врага — у рыцаря это накапливает
## концентрацию и валит в стан. Здесь заглушка: шкалы концентрации нет
func receive_parry(_posture_damage: float) -> void:
	pass


## Подбор золота (золотая душа, VFX/VFX_scene/gold_wisp.gd). Золото хранится в сейве, поэтому копить его должен
## уметь любой персонаж, даже пока у него нет HUD, чтобы это показать
func add_gold(amount: int) -> void:
	if not collects_gold:
		return
	gold += amount


## ── Зелья (Мёд Поэзии, Песнь валькирии, Эликсир Вальгаллы — их _execute
## зовёт эти методы; у рыцаря свои, в player.gd) ──

const DRINK_SOUND := preload("res://Sound/abilities_sound/drink_potion_sound.mp3")


func heal(amount: float) -> void:
	if is_dead():
		return
	# Зовут только расходники (зелья, их тики) — костёр лечит мимо, полоской
	amount *= 1.0 + skill("consumable_heal_percent") / 100.0
	health = minf(health + amount, max_health)
	if is_instance_valid(health_bar):
		health_bar.heal(amount)


## Лечение тиками с ровной паузой; tint — вспышка спрайта на каждый тик
func start_heal_over_time(amount_per_tick: float, interval: float, ticks: int,
		tint := Color(0.6, 1.5, 0.8, 1.0)) -> void:
	for i in ticks:
		if not is_instance_valid(self) or is_dead():
			return
		heal(amount_per_tick)
		flash_tint(tint)
		await get_tree().create_timer(interval).timeout


func clear_negative_effects() -> void:
	pass


func flash_tint(tint: Color, in_time := 0.08, out_time := 0.22) -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", tint, in_time)
	tween.tween_property(sprite, "modulate", Color.WHITE, out_time)


## Звук питья — и ЖДЁМ, пока доиграет: зелье действует, когда "допил"
func play_drink_sound() -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = DRINK_SOUND
	p.pitch_scale = randf_range(0.96, 1.04)
	add_child(p)
	p.play()
	await p.finished
	p.queue_free()


## Душа долетела (gold_wisp.gd). at — где она впиталась (для огонька на HUD)
func add_souls(amount: int, _at := Vector2.ZERO) -> void:
	if not collects_souls:
		return
	souls += amount


## Награда за убийство (enemy.gd::_on_dead) — без физического подбора, в
## отличие от золота. Копит именно skill_progress (заливку полоски); реальный
## skill_points растёт только когда полоска долилась целиком — while, а не if,
## на случай если amount за раз больше одного деления (перенос остатка)
func add_skill_points(amount: int) -> void:
	skill_progress += amount
	while skill_progress >= skill_progress_per_point:
		skill_progress -= skill_progress_per_point
		skill_points += 1


# ─────────────────────────────────────────────
# ДЕРЕВЬЯ НАВЫКОВ (Save/skill_trees.gd)
# ─────────────────────────────────────────────

## Сумма эффекта key по открытым узлам (0 — нет такого)
func skill(key: String) -> float:
	return float(skill_fx.get(key, 0.0))


## Полный пересчёт бонусов с нуля из unlocked_skills — идемпотентно, можно
## звать сколько угодно раз (покупка узла, загрузка сейва)
func recompute_skill_modifiers() -> void:
	skill_fx = SkillTrees.sum_effects(get("character_id"), unlocked_skills)
	if _base_max_health < 0.0:
		_base_max_health = max_health
	max_health = _base_max_health * (1.0 + skill("max_hp_percent") / 100.0)
	if is_instance_valid(health_bar):
		if _base_stamina_regen < 0.0:
			_base_stamina_regen = health_bar.stamina_regen
		# Как у рыцаря: пересчёт дерева — «новый уровень», полоски полные
		health_bar.set_max_hp(max_health)
		health_bar.set_max_stamina(BASE_MAX_STAMINA * (1.0 + skill("max_stamina_percent") / 100.0))
		health = health_bar.current_hp
	else:
		health = minf(health, max_health)
	_on_skills_changed()


## Для наследников: эффекты, которые живут в их собственных полях (Сейд мага)
func _on_skills_changed() -> void:
	pass


func can_unlock_skill(tree_id: String, node_id: String) -> bool:
	return SkillTrees.can_unlock(get("character_id"), unlocked_skills, tree_id, node_id)


## Покупка узла: проверка правил и очков здесь, а не в UI; тратит очки,
## пересчитывает бонусы и сохраняет. false — отказ, ничего не изменилось
func try_unlock_skill(tree_id: String, node_id: String) -> bool:
	if not can_unlock_skill(tree_id, node_id):
		return false
	var cost: int = SkillTrees.get_node_data(tree_id, node_id).get("cost", 1)
	if skill_points < cost:
		return false
	skill_points -= cost
	unlocked_skills.append(node_id)
	recompute_skill_modifiers()
	SaveManager.capture_from(self)
	return true


## Цена переката с навыками (Лисий шаг, Та, что выжила, Без следа)
func _roll_cost() -> float:
	var pct := skill("roll_cost_percent")
	if _chain_roll_left > 0.0:
		pct += skill("chain_roll_cost_percent")
	return roll_stamina_cost * maxf(1.0 + pct / 100.0, 0.1)


## Множитель входящего урона от навыков (маг: Память камня и т.п.).
## Не ниже 0.1 — навыки не дают бессмертия
func _incoming_damage_mult(_attack_data: Dictionary) -> float:
	return maxf(1.0 + skill("physical_damage_taken_percent") / 100.0, 0.1)


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


## Тот же ли удар сейчас играет, что начинался клипом clip — без учёта
## стороны: доворот в начале замаха (_steer_attack) меняет «Attack_2_Down» на
## «Attack_2_Left», но это всё ещё тот же удар, и его хитбокс/снаряд должны
## сработать. Сменился сам удар (другой шаг, урон, перекат) — false
func _same_attack(clip: String) -> bool:
	return _strip_dir(String(anim.current_animation)) == _strip_dir(clip)


## Имя клипа без суффикса стороны: «Sword_Attack_2_Down_Left» -> «Sword_Attack_2_»
static func _strip_dir(clip: String) -> String:
	for d in DIRS_LONGEST_FIRST:
		if clip.ends_with(d):
			return clip.substr(0, clip.length() - d.length())
	return clip


const DIRS_LONGEST_FIRST := ["Down_Right", "Down_Left", "Up_Left", "Up_Right", "Right", "Down", "Left", "Up"]

## Доворот в начале замаха: первые attack_steer_time секунд удара/каста героя
## можно повернуть стрелками (или мышью с «Прицелом мышью») — клип того же
## удара переключается на новую сторону с того же места. С целью в фокусе
## не доворачивает: удар и так идёт в неё
@export var attack_steer_time := 0.12

func _steer_attack() -> void:
	if _focus.has_target() or _attack_recovery:
		return
	var clip := String(anim.current_animation)
	if clip == "" or anim.current_animation_position > attack_steer_time:
		return
	# Только удары серии и касты: натяжение лука доворачивает себя само
	# (archer._aim_charge), а выпад/разворот уже несут своё направление
	var kind := clip.trim_prefix("Sword_")
	if not (kind.begins_with("Attack") or kind.begins_with("SpecialAttack")):
		return
	var d := _aim_dir()
	if d == Vector2.ZERO:
		return
	var nd := get_direction(d)
	if nd == "" or nd == last_direction or not clip.ends_with(last_direction):
		return
	var new_clip := clip.substr(0, clip.length() - last_direction.length()) + nd
	if not anim.has_animation(new_clip):
		return
	var pos := anim.current_animation_position
	var spd := anim.get_playing_speed()
	facing_dir = d
	last_direction = nd
	anim.play(new_clip, -1, spd)
	anim.seek(pos, true)
	if _attack_step_velocity != Vector2.ZERO:
		_attack_step_velocity = d * _attack_step_velocity.length()


## То же, но клип, который уже идёт, начинается заново: удар или заклинание,
## начатые в окне отмены прошлого (тем же клипом), идут с первого кадра —
## иначе картинка шла бы с середины и разъезжалась с вылетом снаряда/ударом
func _play_restart(anim_name: String) -> bool:
	var was := String(anim.current_animation)
	if not _play(anim_name):
		return false
	if String(anim.current_animation) == was:
		anim.seek(0.0, true)
	return true


## Общая с рыцарем таблица направлений (DirectionUtil) — имена секторов это
## суффиксы клипов, и расходиться копиям тут нельзя
func get_direction(vec: Vector2) -> String:
	return DirectionUtil.from_vector(vec)


func direction_to_vector(dir: String) -> Vector2:
	return DirectionUtil.to_vector(dir)
