extends "res://Player_scene/character_base.gd"
## Лучник. Движение, направления, серия ударов и здоровье — в общей базе
## (character_base.gd), здесь только то, что отличает его от остальных:
## каждый удар серии выпускает стрелу вместо чистого рукопашного взмаха.

const ArrowScript := preload("res://Player_scene/arrow.gd")
const ArcherFx := preload("res://Player_scene/archer_fx.gd")
## Звуки кинжала и лука (накладывание стрелы, скрип тетивы, спуск, свист,
## попадания) — Player_scene/sigrid_sfx.gd, файлы в Sound/sigrid_sfx/
const Sfx := preload("res://Player_scene/sigrid_sfx.gd")

const HudScript := preload("res://Inventory/ui/hud.gd")
const QuickSlotScript := preload("res://Inventory/ui/quick_slot_ui.gd")
const InventoryUIScript := preload("res://Inventory/systems/inventory/inventory_ui.gd")

## Какой каталог показывать в магазине (Shop/shop_menu.gd). У рыцаря поля нет —
## ему достаётся каталог по умолчанию
var character_id := "archer"

@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio
@onready var kick_hitbox: Area2D = $KickHitbox

# Сумка, быстрый слот, окно инвентаря и HUD — те же скрипты, что у рыцаря
# (у него это ноды в player.tscn). Здесь собираются кодом в _setup_inventory(),
# чтобы не трогать archer.tscn
var ability_system: AbilitySystem
var inventory_system: InventorySystem
var talisman_system: TalismanSystem
var inventory_ui: CanvasLayer
var hud: CanvasLayer
var _skill_audio: AudioStreamPlayer
var _status: Node2D
var _last_gold := -1

## Метка "стрелок" для enemy.gd — попавшая стрела лучника поднимает на него
## подстреленного врага и соседей (см. enemy.gd::take_damage).
## Тем же тут заводим хитбокс пинка — та же группа/meta, что у PlayerHitbox
## рыцаря (player.gd::_ready), это единственное, что даёт enemy.gd опознать
## удар как "атака игрока" (см. enemy.gd::_is_player_attack/_get_damage_from)
func _ready() -> void:
	super._ready()
	add_to_group("ranged_player")
	# Постоянная метка лучницы (в любой стойке): её удары не отбрасывают врагов
	# (enemy.gd::_pushes)
	add_to_group("archer_player")
	kick_hitbox.add_to_group("player_attack")
	kick_hitbox.set_meta("damage", kick_damage)
	kick_hitbox.area_entered.connect(_on_blade_contact)
	_bow_combo_length = combo_length
	# В листах Сигрид StrafeLeft/StrafeRight подписаны со стороны зрителя
	strafe_names_swapped = true
	_setup_inventory()
	_load_starting_items()
	_ensure_trap_action()
	_voice = AudioStreamPlayer2D.new()
	_voice.name = "VoiceAudio"
	_voice.bus = "Combat"
	add_child(_voice)
	_tune_breath()


func _setup_inventory() -> void:
	ability_system = AbilitySystem.new()
	ability_system.name = "AbilitySystem"
	add_child(ability_system)
	inventory_system = InventorySystem.new()
	inventory_system.name = "InventorySystem"
	add_child(inventory_system)
	talisman_system = TalismanSystem.new()
	talisman_system.name = "TalismanSystem"
	add_child(talisman_system)

	# HUD: hud.gd ищет $QuickSlotUI в своём _ready — ребёнка кладём ДО
	# добавления в дерево. Координаты — как у рыцаря в player.tscn
	hud = CanvasLayer.new()
	hud.name = "HUD"
	var quick := Control.new()
	quick.name = "QuickSlotUI"
	quick.set_script(QuickSlotScript)
	quick.offset_left = 1595.0
	quick.offset_top = 797.0
	quick.offset_right = 1845.0
	quick.offset_bottom = 1047.0
	hud.add_child(quick)
	hud.set_script(HudScript)
	add_child(hud)

	inventory_ui = CanvasLayer.new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.set_script(InventoryUIScript)
	add_child(inventory_ui)

	inventory_ui.init(ability_system, inventory_system, self, talisman_system)
	hud.init(ability_system)

	_skill_audio = AudioStreamPlayer.new()
	_skill_audio.bus = "Combat"
	add_child(_skill_audio)

	_status = ArcherFx.Status.new()
	add_child(_status)


## Стартовый набор, как у рыцаря (player.gd::_load_starting_abilities):
## сумка между запусками не сохраняется, без него быстрый слот пуст
func _load_starting_items() -> void:
	var shot := ValkyrieShotAbility.new()
	var look := LastLookAbility.new()
	inventory_ui.add_item(shot)
	inventory_ui.add_item(shot)
	inventory_ui.add_item(look)
	ability_system.add_ability(shot)
	ability_system.add_ability(look)


## Esc — инвентарь, колесо — слоты, R — применить. Тот же набор, что у
## рыцаря (player.gd::_unhandled_input). Пока инвентарь открыт, дерево на
## паузе и сюда ничего не доходит — Esc там гасит сам инвентарь
func _unhandled_input(event: InputEvent) -> void:
	if is_in_shop or is_dead() or inventory_ui == null or inventory_ui.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		inventory_ui.open()
		get_viewport().set_input_as_handled()
		return
	if is_attacking or is_rolling:
		return
	if event.is_action_pressed("slot_next"):
		ability_system.next_slot()
	elif event.is_action_pressed("slot_prev"):
		ability_system.prev_slot()
	elif event.is_action_pressed("ability_use"):
		ability_system.use_current(self)
	elif event.is_action_pressed(TRAP_ACTION):
		_try_place_trap()

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

## Натяжение тетивы (ЛКМ): пока кнопка зажата, играет Tension_ и копится
## сила выстрела; отпустил — стрела вылетает сразу, играет Shot_. Чем дольше
## тянул, тем больше урон и скорость стрелы. Полное натяжение — когда клип
## Tension_ доходит до последнего кадра (11 кадров по 0.2с = 2с), дальше он
## просто стоит на нём, пока кнопку не отпустят
@export var charge_full_time := 2.0
@export var charge_min_damage := 1
@export var charge_max_damage := 3
@export var charge_min_speed_mult := 0.7
@export var charge_max_speed_mult := 1.3
## Стамина на натяжение: небольшая цена на старте + расход в секунду, пока
## тянешь (до полного натяжения). Полное натяжение = 2с * 12 = 24 + 5 на
## старте; быстрый тап обходится почти даром. Последний взор тянет вдвое
## быстрее, поэтому за то же натяжение тратится столько же
@export var charge_start_stamina_cost := 5.0
@export var charge_stamina_drain := 12.0
## Скорость клипа Shot_ (1.0 — как нарисован). Пока он играет, лучница стоит
@export var shot_anim_speed := 1.0
const COLOR_FULL_DRAW := Color(1.6, 1.45, 1.0)

var _shoot_cooldown_timer := 0.0
var _kick_cooldown_timer := 0.0
var _quick_shot_cooldown_timer := 0.0
## Сколько держать ЛКМ, чтобы это считалось удержанием (натяжение), а не
## нажатием (быстрый выстрел Attack_)
@export var tap_hold_threshold := 0.18
var _press_pending := false
var _press_time := 0.0
var _charging := false
var _charge_time := 0.0
var _charge_full_flashed := false
var _charge_aim: Node2D = null


## Полностью переопределяет базовую версию (а не зовёт super + добавляет
## проверки сверху): у Input.is_action_just_pressed внутри super всё равно
## пришлось бы читать заново, а так гейты стамины/кулдауна встают ровно перед
## start_attack, не трогая саму механику комбо — ей по-прежнему пользуется
## рукопашный маг. Здесь же тикает кулдаун: handle_attack_input дёргается из
## базового _physics_process каждый кадр независимо от того, нажата ли кнопка
func handle_attack_input() -> void:
	var dt := get_physics_process_delta_time()
	if _shoot_cooldown_timer > 0.0:
		_shoot_cooldown_timer -= dt
	if _kick_cooldown_timer > 0.0:
		_kick_cooldown_timer -= dt
	if _quick_shot_cooldown_timer > 0.0:
		_quick_shot_cooldown_timer -= dt
	_spin_cooldown_timer = maxf(_spin_cooldown_timer - dt, 0.0)
	_lunge_cooldown_timer = maxf(_lunge_cooldown_timer - dt, 0.0)

	# Прошлый приём уже отыгран (стрела ушла, клинок прошёл) — новое нажатие
	# обрывает его хвост и начинается сразу. Кроме удара мечом посреди серии:
	# его подхватит очередь серии (character_base, _attack_recovery)
	if is_attacking and _attack_recovery and (_pressed("attack") or _pressed("parry") or _pressed("kick")):
		var chains := weapon == Weapon.SWORD and _pressed("attack") and combo_step >= 1 and combo_step < combo_length
		if not chains:
			_cancel_attack()

	# 1 — лук, 2 — меч. Меняется только в свободной стойке (не посреди удара,
	# переката или натяжения)
	if _try_switch_weapon():
		return
	if weapon == Weapon.SWORD:
		_handle_sword_input()
		return

	# Пинок и быстрый выстрел проверяем первыми и отдельно от серии обычных
	# выстрелов — свои кнопки, не участвуют в комбо/is_attacking-очереди лука
	# Нажатия — из буфера ввода базы (_pressed/_consume): нажатое чуть раньше,
	# чем кончился прошлый приём или кулдаун, сработает, как только станет можно
	if _pressed("kick") and not is_attacking and _kick_cooldown_timer <= 0.0:
		_consume("kick")
		_start_kick()
		return
	if _pressed("parry") and not is_attacking and _quick_shot_cooldown_timer <= 0.0:
		_consume("parry")
		_start_quick_shot()
		return

	if _charging:
		_update_charge(get_physics_process_delta_time())
		return
	# Нажатие или удержание? Первые tap_hold_threshold секунд решаем:
	# отпустили раньше — обычный быстрый выстрел (Attack_), держат дольше —
	# натяжение тетивы (Tension_ -> Shot_)
	if _press_pending:
		# Пока решали, успели начать другое действие (пинок, залп) — отмена
		if is_attacking:
			_press_pending = false
			return
		_press_time += get_physics_process_delta_time()
		if not Input.is_action_pressed("attack"):
			_press_pending = false
			_tap_shot()
		elif _press_time >= tap_hold_threshold:
			_press_pending = false
			# На старте натяжения — небольшая цена, остальное тратится, пока
			# тетива натягивается (см. _update_charge). Без стамины не начать
			if is_instance_valid(health_bar) and not health_bar.use_stamina(charge_start_stamina_cost):
				return
			_start_charge()
		return
	if not _pressed("attack"):
		return
	if is_attacking:
		return
	if _shoot_cooldown_timer > 0.0:
		return
	_consume("attack")
	# Выстрел на бегу — быстрый, без натяжения (как раньше): полная цена
	# сразу, другая анимация и рывок вместо остановки. Логика рывка и отката на
	# Attack_, если Run_Attack_ ещё не нарисована — в базе (character_base.gd)
	if is_running and input_vector != Vector2.ZERO:
		if is_instance_valid(health_bar) and not health_bar.use_stamina(shoot_stamina_cost):
			return
		_shoot_cooldown_timer = _current_cooldown()
		start_run_attack()
		return
	# Стоя: ждём, нажатие это или удержание (решается выше, в _press_pending)
	_press_pending = true
	_press_time = 0.0


## Быстрый выстрел по нажатию ЛКМ (без удержания) — как было до натяжения:
## Attack_, стрела вылетает через shoot_delay с базовым уроном
func _tap_shot() -> void:
	if is_instance_valid(health_bar) and not health_bar.use_stamina(shoot_stamina_cost):
		return
	_shoot_cooldown_timer = _current_cooldown()
	start_attack(1)


func _current_cooldown() -> float:
	# Последний взор — стрельба вдвое чаще
	return shoot_cooldown * (LAST_LOOK_RATE if _last_look_time > 0.0 else 1.0)


# ─────────────────────────────────────────────
# НАТЯЖЕНИЕ ТЕТИВЫ
# ─────────────────────────────────────────────

func _start_charge() -> void:
	is_attacking = true
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	_charging = true
	_charge_time = 0.0
	_charge_full_flashed = false
	_aim_charge(true)
	# Стрела из колчана на тетиву, лук начинает скрипеть
	Sfx.play_on(self, "arrow_grab")
	_creak_stage = 0
	_creak(1.0, 0.0)


## Скрип натягиваемой тетивы — по нарастающей: на старте, на середине и на
## полном натяжении (ниже и тяжелее). Прошлый скрип обрывается
var _creak_player: AudioStreamPlayer2D
var _creak_stage := 0

func _creak(pitch: float, db: float) -> void:
	_stop_creak()
	_creak_player = Sfx.play_on(self, "bow_draw", db, pitch, 0.03)


func _stop_creak() -> void:
	if is_instance_valid(_creak_player):
		_creak_player.stop()
		_creak_player.queue_free()
	_creak_player = null


## Последний взор — тетива натягивается вдвое быстрее. Навыки (Ровный выдох,
## Верный выстрел) укорачивают время полного натяжения
func _charge_rate() -> float:
	var rate := 1.0 / LAST_LOOK_RATE if _last_look_time > 0.0 else 1.0
	return rate / maxf(1.0 + skill("charge_time_percent") / 100.0, 0.3)


## 0..1 — насколько натянута тетива. Выстрел Валькирии всегда в полную силу
func _charge_power() -> float:
	if _valkyrie_shot_ready:
		return 1.0
	return clampf(_charge_time / charge_full_time, 0.0, 1.0)


## Направление натяжения: фокус > ближайший враг > WASD > куда смотрели.
## Зовётся каждый кадр, пока тетива натянута — цель может сместиться, а без
## цели лук можно повернуть клавишами. При смене направления клип Tension_
## переключается на нужную сторону с того же места, а не с начала
func _aim_charge(restart := false) -> void:
	var aim: Node2D = _pick_aim()
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	elif _aim_dir() != Vector2.ZERO:
		dir = _aim_dir()
	else:
		dir = facing_dir
	var dir_name := get_direction(dir)
	if dir_name == "":
		return
	_charge_aim = aim
	facing_dir = dir
	var clip := "Tension_" + dir_name
	if anim.assigned_animation == clip and not restart:
		return
	if not anim.has_animation(clip):
		return
	last_direction = dir_name
	var rate := _charge_rate()
	anim.play(clip, -1, rate)
	# Позиция в клипе = сколько уже натянули. Дошли до конца — клип сразу
	# доигрывается и замирает на последнем кадре
	anim.seek(minf(_charge_power() * charge_full_time, anim.current_animation_length), true)


func _update_charge(delta: float) -> void:
	# Натяжение перебили: перекат, удар (Take_Damage_ заменил клип), смерть
	if is_rolling or is_dead() or not String(anim.assigned_animation).begins_with("Tension_"):
		_charging = false
		_stop_creak()
		if not is_rolling:
			is_attacking = false
		return
	# Натяжение стоит стамины: пока тянем — она уходит. Кончилась — тетива
	# дальше не натягивается (держать уже набранное можно, но сила не растёт).
	# Полностью натянутую тетиву держать бесплатно — это уже не "тянуть"
	if _charge_time < charge_full_time:
		var drain := charge_stamina_drain * delta * _charge_rate()
		if not is_instance_valid(health_bar) or health_bar.use_stamina(drain):
			_charge_time += delta * _charge_rate()
	if _creak_stage == 0 and _charge_power() >= 0.5:
		_creak_stage = 1
		_creak(0.93, 1.0)
	if not _charge_full_flashed and _charge_power() >= 1.0:
		_charge_full_flashed = true
		_flash_skill(COLOR_FULL_DRAW)
		_creak(0.85, 2.0)
	_aim_charge()
	if not Input.is_action_pressed("attack"):
		_release_shot()


func _release_shot() -> void:
	var power := _charge_power()
	_charging = false
	_shoot_cooldown_timer = _current_cooldown()
	_stop_creak()
	# Тетива натянута как следует — выдох-выкрик на выстреле
	if power >= 0.6:
		_say("attack")
	var dir := facing_dir
	if is_instance_valid(_charge_aim):
		dir = (_charge_aim.global_position - global_position).normalized()
	_fire_arrow(dir, _charge_aim, power)
	# Стрела ушла — доводка лука (Shot_) обрывается движением или новым выстрелом
	_attack_recovery = true
	var clip := "Shot_" + last_direction
	if anim.has_animation(clip):
		anim.play(clip, -1, shot_anim_speed)
	else:
		is_attacking = false
		play_movement_animation()


## Дёргается из базы (start_attack) сразу после того, как отыграна анимация
## удара — aim это та же цель, на которую только что развернулось наведение
## (фокус > ближайший враг > null). Не await'ится вызывающим (start_attack) —
## отрабатывает как fire-and-forget, комбо продолжается независимо
func _on_attack_started(_step: int, aim: Node2D) -> void:
	if weapon == Weapon.SWORD:
		_sword_strike(_step)
		return
	# Стрела ложится на тетиву — ДО паузы; щелчок спуска — уже в _fire_arrow,
	# в момент вылета
	Sfx.play_on(self, "bow_nock")
	var clip := anim.current_animation
	await get_tree().create_timer(_current_shoot_delay()).timeout
	# Пока стрела натягивалась, лучник мог умереть — стрелять уже некому.
	# aim/цель отдельно проверять не нужно: _shoot_arrow сам откатывается на
	# выстрел по направлению взгляда, если aim за это время протух
	if is_dead():
		return
	_shoot_arrow(aim)
	# Стрела ушла — хвост клипа больше не держит (character_base._attack_recovery)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


func _shoot_arrow(aim: Node2D) -> void:
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	else:
		# Целей рядом нет — стреляем туда, куда смотрим (тот же вектор, что
		# приняла анимация в start_attack)
		dir = facing_dir
		if dir == Vector2.ZERO:
			dir = facing_dir
	_fire_arrow(dir, aim)


## Сам спавн стрелы, без выбора направления — общий кусок между обычным
## выстрелом (_shoot_arrow, направление берёт из aim-узла) и быстрым залпом
## (_start_quick_shot, направление фиксировано заранее на весь залп)
##
## Здесь же на стрелу навешиваются заряженные навыки — каждый заряд уходит
## ровно в одну стрелу, какой бы кнопкой она ни была выпущена
##
## power — сила натяжения 0..1 (обычный выстрел ЛКМ); -1 — без натяжения
## (залп, выстрел на бегу): базовые урон и скорость
func _fire_arrow(dir: Vector2, aim: Node2D = null, power := -1.0) -> void:
	var arrow: Area2D = ArrowScript.new()
	var dmg := arrow_damage
	var spd := arrow_speed
	if power >= 0.0:
		dmg = roundi(lerpf(charge_min_damage, charge_max_damage, power))
		spd *= lerpf(charge_min_speed_mult, charge_max_speed_mult, power)
	# Навыки лука (Верная тетива): урон, скорость полёта, полный натяг
	var pct := skill("bow_damage_percent")
	if power >= 1.0:
		arrow.tags["charged"] = true
		pct += skill("charged_shot_damage_percent")
		if velocity.length() < 5.0 and input_vector == Vector2.ZERO:
			pct += skill("still_charged_damage_percent")
	dmg = SkillTrees.scale_int(dmg, pct)
	spd *= 1.0 + skill("arrow_speed_percent") / 100.0
	var trail := Color(0, 0, 0, 0)

	if _last_look_time > 0.0:
		dmg += 1
		spd *= 1.3
		if is_instance_valid(aim):
			arrow.homing_target = aim
		trail = COLOR_LAST_LOOK
	if _pierce_shots > 0:
		_pierce_shots -= 1
		arrow.pierce = 1
		trail = COLOR_FENRIR
	if _whisper_shots > 0:
		_whisper_shots -= 1
		arrow.ignore_walls = true
		trail = COLOR_WHISPER
	if _dance_charged:
		_dance_charged = false
		arrow.tags["guaranteed_crit"] = true
		trail = COLOR_DANCE
	if _valkyrie_shot_ready:
		_valkyrie_shot_ready = false
		dmg += 1
		spd *= 1.8
		trail = COLOR_VALKYRIE

	arrow.trail_color = trail
	# Спуск тетивы: чем сильнее натянута, тем громче и ниже (тяжелее) щелчок.
	# Без натяжения (залп, на бегу, быстрый) — средний
	var pw := power if power >= 0.0 else 0.4
	Sfx.play_on(self, "bow_release", lerpf(-3.0, 2.0, pw), lerpf(1.1, 0.9, pw))
	get_tree().current_scene.add_child(arrow)
	arrow.speed = spd
	arrow.launch(global_position + dir * shoot_offset, dir, self, dmg)


## Натяжение лука. Выстрел Валькирии срывает стрелу почти сразу, Последний
## взор — вдвое быстрее обычного
func _current_shoot_delay() -> float:
	if _valkyrie_shot_ready:
		return 0.04
	if _last_look_time > 0.0:
		return shoot_delay * LAST_LOOK_RATE
	return shoot_delay


# ─────────────────────────────────────────────
# НАВЫКИ И ТАЛИСМАНЫ
# ─────────────────────────────────────────────
# Предметы из быстрого слота (Inventory/systems/ability/abilities/archer/)
# только зовут activate_archer_skill — вся механика здесь. Урон у лука
# целый (1 за стрелу, у врага 5 HP), поэтому усиления — это +1 урона и
# крит x2, а не проценты: +20% от единицы просто округлились бы в ноль

const BASE_CRIT_CHANCE := 0.1
const CRIT_MULT := 2
const LAST_LOOK_RATE := 0.5
const LAST_LOOK_CRIT_BONUS := 0.15
const NORN_CRIT_BONUS := 0.2
const HUNT_MAX_BONUS := 2
const HUGINN_MARK_TIME := 5.0
## Дальше обычного автонаведения (snap_radius) — Хугин видит помеченных издалека
const HUGINN_AIM_RANGE := 320.0
const BLEED_TICKS := 3
const BLEED_INTERVAL := 1.0

const TALISMAN_HUGINN := "Перо Хугина"
const TALISMAN_NORN := "Игла Норн"

const COLOR_VALKYRIE := Color(1.0, 0.82, 0.35)
const COLOR_FENRIR := Color(0.85, 0.25, 0.2)
const COLOR_WHISPER := Color(0.45, 0.7, 1.0)
const COLOR_DANCE := Color(0.9, 0.85, 1.0)
const COLOR_LAST_LOOK := Color(1.0, 0.7, 0.25)
const COLOR_HUNT := Color(0.95, 0.35, 0.15)
const COLOR_BLEED := Color(0.8, 0.1, 0.1)
const COLOR_HUGINN := Color(0.6, 0.8, 1.0)

var _valkyrie_shot_ready := false
var _pierce_shots := 0
var _whisper_shots := 0
var _dance_time := 0.0
var _dance_charged := false
var _bleed_time := 0.0
var _last_look_time := 0.0
var _hunt_time := 0.0
var _hunt_prey: Node2D = null
var _hunt_stacks := 0
# instance_id врага -> сколько ещё держится метка Хугина
var _marked := {}
# instance_id врагов, в которых уже попадали — для Иглы Норн
var _hit_before := {}
# skill_id -> полная длительность, для полосок-таймеров над головой
var _durations := {}


func activate_archer_skill(id: String, ability: Ability) -> void:
	var col := Color.WHITE
	match id:
		"valkyrie_shot":
			_valkyrie_shot_ready = true
			col = COLOR_VALKYRIE
		"fenrir_claw":
			_pierce_shots += ability.shots
			col = COLOR_FENRIR
		"odin_whisper":
			_whisper_shots += ability.shots
			col = COLOR_WHISPER
		"valkyrie_dance":
			_dance_time = ability.duration
			col = COLOR_DANCE
		"bloody_feather":
			_bleed_time = ability.duration
			col = COLOR_BLEED
		"last_look":
			_last_look_time = ability.duration
			col = COLOR_LAST_LOOK
		"huntress_path":
			_hunt_time = ability.duration
			_hunt_stacks = 0
			_hunt_prey = _focus.target if _focus.has_target() else null
			if is_instance_valid(_hunt_prey):
				ArcherFx.Mark.attach(_hunt_prey, "HuntMark", COLOR_HUNT, _hunt_time, -46.0)
			col = COLOR_HUNT
		_:
			push_warning("[Лучница] неизвестный навык: %s" % id)
			return
	if ability.duration > 0.0:
		_durations[id] = ability.duration
	_skill_audio.stream = ability.activation_sound
	_skill_audio.pitch_scale = randf_range(0.95, 1.05)
	_skill_audio.play()
	_flash_skill(col)


## Стрела попала во врага (arrow.gd зовёт вместо take_damage). Здесь считается
## итоговый урон: добыча Пути охотницы, криты, кровотечение, метки
func resolve_arrow_hit(enemy: Node2D, arrow: Node) -> void:
	var dmg: int = arrow.damage
	var id := enemy.get_instance_id()
	var marked := _marked.has(id)

	if _hunt_time > 0.0:
		if not is_instance_valid(_hunt_prey) or _hunt_prey.is_dead:
			_hunt_prey = enemy
			_hunt_stacks = 0
		if enemy == _hunt_prey:
			dmg += mini(_hunt_stacks, HUNT_MAX_BONUS)
			# Перо Хугина: добыча под меткой копит силу вдвое быстрее
			_hunt_stacks += 2 if (marked and _has_talisman(TALISMAN_HUGINN)) else 1
			ArcherFx.Mark.attach(enemy, "HuntMark", COLOR_HUNT, _hunt_time, -46.0)

	var chance := BASE_CRIT_CHANCE + skill("bow_crit_chance_points") / 100.0
	if _last_look_time > 0.0:
		chance += LAST_LOOK_CRIT_BONUS
	if _hit_before.has(id) and _has_talisman(TALISMAN_NORN):
		chance += NORN_CRIT_BONUS
	var unaware: bool = enemy.has_method("is_unaware_of") and enemy.is_unaware_of(self)
	var charged: bool = arrow.tags.get("charged", false)
	# Навыки на цель (След стрелы, Кровавый след) — до крита
	dmg = SkillTrees.scale_int(dmg, _target_damage_percent(enemy))
	var crit: bool = arrow.tags.get("guaranteed_crit", false) or randf() < chance
	if crit:
		var crit_pct := skill("bow_crit_damage_percent")
		if unaware:
			crit_pct += skill("unaware_crit_damage_percent")
		dmg = SkillTrees.scale_int(dmg * CRIT_MULT, crit_pct)
		ArcherFx.Burst.spawn(get_tree().current_scene, enemy.global_position + Vector2(0, -20), COLOR_VALKYRIE)
		shake_camera(2.5, 0.12)

	enemy.set_meta("last_hit_dagger", false)
	# Тяжёлое оперение: заряженная стрела в щит сильнее бьёт по стойкости
	_posture_shot_charged = charged
	enemy.take_damage(dmg, self)
	_posture_shot_charged = false
	_hit_before[id] = true
	if charged and skill("charged_mark_damage_percent") > 0.0:
		_charged_marks[id] = 3.0

	if enemy.is_dead:
		_marked.erase(id)
		return
	if (crit and _bleed_time > 0.0) or _roll_bleed():
		_apply_bleed(enemy)
	if _has_talisman(TALISMAN_HUGINN):
		_marked[id] = HUGINN_MARK_TIME
		ArcherFx.Mark.attach(enemy, "HuginnMark", COLOR_HUGINN, HUGINN_MARK_TIME)


## Танец Валькирии: доигранный перекат заряжает следующий выстрел
func _on_roll_finished() -> void:
	if _dance_time > 0.0:
		_dance_charged = true


## Фокус игрока главнее всего. Дальше — добыча Пути охотницы, потом (с Пером
## Хугина) ближайший помеченный, даже если он дальше обычного автонаведения
func _pick_aim() -> Node2D:
	if _focus.has_target():
		return _focus.target
	if _hunt_time > 0.0 and is_instance_valid(_hunt_prey) and not _hunt_prey.is_dead \
			and global_position.distance_to(_hunt_prey.global_position) <= HUGINN_AIM_RANGE:
		return _hunt_prey
	if _has_talisman(TALISMAN_HUGINN):
		var best: Node2D = null
		var best_d := HUGINN_AIM_RANGE
		for id in _marked:
			var e := instance_from_id(id) as Node2D
			if not is_instance_valid(e) or e.is_dead:
				continue
			var d := global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best:
			return best
	# Иначе — ближайший в конусе направления (или просто ближайший без
	# направления), character_base._assist_target
	return _assist_target()


## Эффект талисмана действует только пока тот экипирован в одну из четырёх
## секций (вкладка "Талисманы", Inventory/ui/talisman_panel.gd) — лежать в
## сумке недостаточно, в отличие от старой механики "просто владею"
func _has_talisman(item_name: String) -> bool:
	return talisman_system != null and talisman_system.has_talisman(item_name)


func _process(delta: float) -> void:
	# Камера (тряска, покачивание на бегу, дрожь истощения) — в базе
	super(delta)
	_last_look_time = maxf(_last_look_time - delta, 0.0)
	_bleed_time = maxf(_bleed_time - delta, 0.0)
	_hunt_time = maxf(_hunt_time - delta, 0.0)
	_dance_time = maxf(_dance_time - delta, 0.0)
	if _dance_time <= 0.0:
		_dance_charged = false
	if _hunt_time <= 0.0:
		_hunt_prey = null
		_hunt_stacks = 0

	for id in _marked.keys():
		_marked[id] -= delta
		if _marked[id] <= 0.0 or not is_instance_valid(instance_from_id(id)):
			_marked.erase(id)
	for id in _charged_marks.keys():
		_charged_marks[id] -= delta
		if _charged_marks[id] <= 0.0 or not is_instance_valid(instance_from_id(id)):
			_charged_marks.erase(id)
	_switch_bonus_left = maxf(_switch_bonus_left - delta, 0.0)
	_trap_cooldown = maxf(_trap_cooldown - delta, 0.0)

	# Золото меняют монеты, магазин и сейв (SaveManager.apply_to) — проще
	# сверять раз в кадр, чем ловить каждое место
	if gold != _last_gold and hud:
		_last_gold = gold
		hud.update_gold(gold)

	_update_status_visual()


## Руны над головой лучницы: что заряжено в следующие стрелы и какие
## временные навыки сейчас действуют (archer_fx.gd::Status)
func _update_status_visual() -> void:
	if not is_instance_valid(_status):
		return
	var charges: Array[Color] = []
	if _valkyrie_shot_ready:
		charges.append(COLOR_VALKYRIE)
	if _dance_charged:
		charges.append(COLOR_DANCE)
	for i in _pierce_shots:
		charges.append(COLOR_FENRIR)
	for i in _whisper_shots:
		charges.append(COLOR_WHISPER)
	_status.charges = charges
	var timers: Array[Vector2] = []
	var colors: Array[Color] = []
	for entry in [["last_look", _last_look_time, COLOR_LAST_LOOK], ["huntress_path", _hunt_time, COLOR_HUNT],
			["valkyrie_dance", _dance_time, COLOR_DANCE], ["bloody_feather", _bleed_time, COLOR_BLEED]]:
		if entry[1] > 0.0:
			timers.append(Vector2(entry[1], _durations.get(entry[0], entry[1])))
			colors.append(entry[2])
	_status.timers = timers
	_status.timer_colors = colors
	# Последний взор — лучница светится тёплым, пока состояние держится
	if is_instance_valid(sprite):
		var glow := 0.0
		if _last_look_time > 0.0:
			glow = 0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.008)
		sprite.self_modulate = Color.WHITE.lerp(Color(1.5, 1.2, 0.7), glow)


func _flash_skill(col: Color) -> void:
	if not is_instance_valid(sprite):
		return
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(col.r * 2.0, col.g * 2.0, col.b * 2.0), 0.08)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.3)


# ─────────────────────────────────────────────
# ПИНОК
# ─────────────────────────────────────────────

## Тайминг по коду (await), а не method-track в анимации — тот же приём, что
## и у выстрела (_on_attack_started/shoot_delay): не нужно лезть в keyframe'ы
## Kick_-клипов, чтобы воткнуть туда enable/disable_hitbox
func _start_kick() -> void:
	var aim: Node2D = _pick_aim()
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	elif _aim_dir() != Vector2.ZERO:
		dir = _aim_dir()
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
	# Хитбокс общий с мечом — урон и размер задаём заново
	kick_hitbox.set_meta("damage", kick_damage)
	kick_hitbox.scale = Vector2.ONE

	await get_tree().create_timer(kick_windup).timeout
	# Перекат/смерть могли прервать пинок, пока он натягивался (is_attacking
	# сбрасывается и start_roll(), и _die()) — тогда хитбокс включать некому
	if not is_attacking:
		return
	_enable_kick_hitbox(dir)

	await get_tree().create_timer(kick_active_time).timeout
	if is_instance_valid(kick_hitbox):
		_disable_kick_hitbox()
	if is_attacking and String(anim.current_animation).begins_with("Kick_"):
		_attack_recovery = true


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
	# Мечевые клипы: свои приёмы (разворот, выпад) заканчиваются здесь, а
	# серия, перекат и прочее — как обычные, база узнаёт их без приставки
	if finished_anim.begins_with(SWORD_PREFIX):
		var plain := finished_anim.substr(SWORD_PREFIX.length())
		if plain.begins_with("Spin_") or plain.begins_with("Lunge_"):
			is_attacking = false
			play_movement_animation()
			return
		finished_anim = plain
	if finished_anim.begins_with("Kick_"):
		is_attacking = false
		play_movement_animation()
		return
	# Tension_ доиграл до последнего кадра — так и стоим на нём, пока не
	# отпустят ЛКМ (выстрел и сброс — в _update_charge/_release_shot)
	if finished_anim.begins_with("Tension_"):
		return
	if finished_anim.begins_with("Shot_"):
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
	var aim: Node2D = _pick_aim()
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	elif _aim_dir() != Vector2.ZERO:
		dir = _aim_dir()
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
	_say("attack", 0.8)
	# Горсть стрел из колчана — залп
	Sfx.play_on(self, "arrow_grab", 2.0, 1.1)

	await get_tree().create_timer(quick_shot_windup).timeout
	for i in quick_shot_count:
		# Перекат/смерть могли прервать залп между стрелами — не стреляем
		# дальше, если is_attacking уже сбросили за нас
		if not is_attacking:
			return
		_fire_arrow(dir, aim)
		if i < quick_shot_count - 1:
			await get_tree().create_timer(quick_shot_interval).timeout

	is_attacking = false
	play_movement_animation()


# ─────────────────────────────────────────────
# ЛУК / МЕЧ
# ─────────────────────────────────────────────
## Две стойки Сигрид: 1 — лук (выстрел, натяжение, залп на ПКМ), 2 — меч
## (серия из трёх ударов на ЛКМ, удар с разворотом на ПКМ, выпад на V, удар
## на бегу). Анимации меча — те же имена с приставкой "Sword_"
## (Player_scene/sigrid_anims.tres, собирает tools/build_sigrid_anims.gd); если
## мечевого клипа нет — играет обычный (см. _play)
enum Weapon { BOW, SWORD }
var weapon: int = Weapon.BOW

const SWORD_PREFIX := "Sword_"
const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")

@export var sword_damage := 1
## Последний удар серии (Attack4, восходящий взмах) — тяжелее
@export var sword_finisher_damage := 2
## Насколько далеко вперёд бьёт клинок и какой ширины зона удара (хитбокс
## 20x22 растягивается на sword_hit_scale)
@export var sword_reach := 30.0
@export var sword_hit_scale := Vector2(1.9, 1.7)
@export var sword_stamina_cost := 10.0
@export var sword_combo_length := 3
@export var spin_damage := 1
@export var spin_stamina_cost := 22.0
@export var spin_cooldown := 1.2
@export var lunge_damage := 2
## Скорость рывка вперёд на выпаде (гаснет так же, как отбрасывание)
@export var lunge_speed := 260.0
@export var lunge_stamina_cost := 18.0
@export var lunge_cooldown := 1.0
## Шаг вперёд на каждом ударе серии мечом — скорость рывка (путь ≈ скорость /
## attack_step_friction из character_base). Укол и финиш шагают шире
@export var sword_step_speed := 110.0
@export var sword_thrust_step_speed := 150.0
@export var sword_finisher_step_speed := 170.0
## За сколько секунд до удара клинка начинается шаг — нога ставится на
## замахе, и к моменту попадания Сигрид уже идёт вперёд всем весом
@export var sword_step_lead := 0.12
## Враги перед Сигрид в этом радиусе едут вместе с её шагом/рывком — иначе
## она упиралась бы в того, кого бьёт, и шаг гас бы о его тело
@export var sword_carry_reach := 52.0
## Насколько враг уезжает быстрее самой Сигрид (>1 — зазор не схлопывается
## из-за того, что враги и игрок обрабатывают физику в разном порядке)
@export var sword_carry_factor := 1.15
## На каком расстоянии до врага гаснет разбег удара на бегу мечом
@export var run_attack_stop_distance := 38.0

## Взмахи меча сняты с кадров спрайтов (tools/build_sigrid_swings.gd ->
## sigrid_swing_data.gd): когда в каждом из 8 направлений идёт след клинка,
## откуда и куда он ведёт. По ним идут и дуга, и окно удара
const SwingData := preload("res://Player_scene/sigrid_swing_data.gd")
## Грудь Сигрид относительно её узла — центр дуг (точка (64, 62) кадра 128)
const SIGRID_CHEST := Vector2(0, -2)
## В кадре со следом взмах уже прошёл — дуга стартует на кадр раньше
const SWING_LEAD := 0.04
## Шаг серии -> [лист, заготовка дуги на случай, если взмах по кадрам не
## измерился]. Серия: Attack1 -> Attack6 (укол, потом взмах) -> Attack4 (финиш);
## 0 — удар на бегу
const STEP_SWING := {
	1: ["Attack1", KnightFx.Swing.RISING],
	2: ["Attack6", KnightFx.Swing.SWEEP],
	3: ["Attack4", KnightFx.Swing.HEAVY],
	0: ["AttackRun", KnightFx.Swing.RUN],
}
## Время взмаха, если для направления в таблице ничего нет (с от старта клипа)
const SWING_DEFAULT_TIME := {
	"Attack1": [0.24, 0.40], "Attack6": [0.5, 0.7], "Attack4": [0.24, 0.40],
	"Attack2": [0.24, 0.40], "AttackRun": [0.24, 0.40],
}
## Укол Attack6 — выпад с вытянутым клинком, кадры 5-8 при 20 к/с
const ATTACK6_STAB := [0.25, 0.45]
## Рубящий удар Attack4 — клинок идёт от головы вниз на кадрах 7-9 при 25 к/с
## (во всех направлениях одинаково, по кадрам листа)
const ATTACK4_CHOP := [0.26, 0.40]
const LUNGE_HIT := [0.1, 0.28]
## Задержка закрытия хитбокса после конца взмаха — кончик клинка ещё летит
const SWING_TAIL_HIT := 0.03

var _bow_combo_length := 1
var _spin_cooldown_timer := 0.0
var _lunge_cooldown_timer := 0.0


func _try_switch_weapon() -> bool:
	var want := -1
	if Input.is_action_just_pressed("weapon_bow"):
		want = Weapon.BOW
	elif Input.is_action_just_pressed("weapon_sword"):
		want = Weapon.SWORD
	if want < 0 or want == weapon:
		return false
	if is_attacking or is_rolling or _charging or _press_pending:
		return false
	_set_weapon(want)
	return true


func _set_weapon(w: int) -> void:
	weapon = w
	combo_step = 0
	combo_queued = false
	combo_length = sword_combo_length if w == Weapon.SWORD else _bow_combo_length
	# Метка стрелка нужна врагам и крови только для лука: с мечом Сигрид —
	# обычный боец ближнего боя (разрез и искры клинка, кровь веером)
	if w == Weapon.BOW:
		add_to_group("ranged_player")
	else:
		remove_from_group("ranged_player")
	# Кинжал из ножен — или обратно в ножны, а лук снимается со спины (колчан)
	if w == Weapon.SWORD:
		Sfx.play_on(self, "dagger_draw")
		# Быстрая рука: с лука на кинжал — 3 с кинжал бьёт сильнее
		if skill("switch_dagger_damage_percent") > 0.0:
			_switch_bonus_left = 3.0
	else:
		Sfx.play_on(self, "dagger_sheathe")
		get_tree().create_timer(0.18).timeout.connect(func():
			if is_instance_valid(self) and weapon == Weapon.BOW:
				Sfx.play_on(self, "quiver"))
	_flash_skill(Color(0.85, 0.88, 1.0))
	play_movement_animation()


## В стойке меча подставляем мечевую версию клипа, если она нарисована
func _play(anim_name: String) -> bool:
	return super._play(_clip_name(anim_name))


## Та же подмена — для шагов, которые база играет мимо _play (_play_loco)
func _clip_name(anim_name: String) -> String:
	if weapon == Weapon.SWORD and not anim_name.begins_with(SWORD_PREFIX) \
			and anim.has_animation(SWORD_PREFIX + anim_name):
		return SWORD_PREFIX + anim_name
	return anim_name


func _handle_sword_input() -> void:
	# Окно серии в базе (combo_window) короче мечевого удара — пока удар идёт,
	# держим его открытым, иначе шаг серии сбросился бы посреди замаха
	if is_attacking and combo_step > 0:
		combo_timer = maxf(combo_timer, 0.2)
	if _pressed("attack"):
		if is_attacking:
			# Следующий удар серии в очередь — база начнёт его, когда этот доиграет.
			# Не встало в очередь (последний удар серии, выпад) — нажатие ждёт в
			# буфере и начнёт новую серию сразу после
			if combo_step >= 1 and combo_step < combo_length and not combo_queued and _pay(sword_stamina_cost):
				combo_queued = true
				_consume("attack")
			return
		_consume("attack")
		if not _pay(sword_stamina_cost):
			return
		if is_running and input_vector != Vector2.ZERO:
			start_run_attack()
		else:
			start_attack(1)
		return
	if is_attacking:
		return
	if _pressed("parry") and _spin_cooldown_timer <= 0.0:
		_consume("parry")
		_start_sword_move("Spin")
	elif _pressed("kick") and _lunge_cooldown_timer <= 0.0:
		_consume("kick")
		_start_sword_move("Lunge")


## Удар/перекат оборвал приём: натяжение сгорает, клинок гаснет
func _cancel_attack() -> void:
	super()
	_charging = false
	_disable_kick_hitbox()


## Финиш серии мечом (рубящий Attack4) и выпад — тяжёлые приёмы, попадание их
## не сбивает (урон проходит)
func _has_hyper_armor() -> bool:
	if weapon != Weapon.SWORD or not is_attacking:
		return false
	return combo_step == 3 or String(anim.current_animation).begins_with(SWORD_PREFIX + "Lunge")


func _pay(cost: float) -> bool:
	return not is_instance_valid(health_bar) or health_bar.use_stamina(cost)


## Взмах листа sheet в направлении dir_name: время (t0..t1, с от старта клипа)
## и дуга. Время — по кадрам спрайта всегда, когда направление измерилось;
## геометрия — только если измерение надёжное (охват 60..220°), иначе
## заготовка swing относительно взгляда, уменьшенная под рост Сигрид
func _swing(sheet: String, dir_name: String, swing: int, dir: Vector2) -> Dictionary:
	var e: Dictionary = SwingData.DATA.get(sheet, {}).get(dir_name, {})
	var tt: Array = SWING_DEFAULT_TIME.get(sheet, [0.24, 0.4])
	var p := KnightFx.preset(swing, dir)
	var res := {"t0": tt[0], "t1": tt[1], "from": p.from, "to": p.to,
			"radius": p.radius * 0.85, "width": p.width, "power": p.power}
	if e.has("t0"):
		res.t0 = e.t0
		res.t1 = maxf(e.t1, e.t0 + 0.08)
		var span := absf(e.to - e.from)
		if span > deg_to_rad(60.0) and span < deg_to_rad(220.0):
			res.from = e.from
			res.to = e.to
			res.radius = clampf(e.radius, 22.0, 34.0)
	return res


## Удар серии мечом (зовётся из _on_attack_started): дуга идёт вместе со
## следом клинка на спрайте, хитбокс открыт ровно на время взмаха
func _sword_strike(step: int) -> void:
	var clip := anim.current_animation
	var dir := facing_dir if facing_dir != Vector2.ZERO else direction_to_vector(last_direction)
	var info: Array = STEP_SWING.get(step, STEP_SWING[1])
	var events := []
	match step:
		# Второй удар (Attack6) — только укол: выпад с вытянутым клинком на
		# кадрах 5-8. Вихрь клинка после него — прокрут, а не удар
		2: events.append({"t0": ATTACK6_STAB[0], "t1": ATTACK6_STAB[1], "thrust": true})
		# Финиш (Attack4) — рубящий сверху: клинок от головы вниз и вперёд
		3: events.append({"t0": ATTACK4_CHOP[0], "t1": ATTACK4_CHOP[1], "chop": true})
		_: events.append(_swing(info[0], last_direction, info[1], dir))
	# Удар на бегу (step 0) уже несёт свой рывок (_run_dash_velocity)
	if step > 0:
		var step_speed: float = [sword_step_speed, sword_thrust_step_speed, sword_finisher_step_speed][clampi(step, 1, 3) - 1]
		_step_into_swing(clip, maxf(events[0].t0 - sword_step_lead, 0.0), step_speed)
	var t := 0.0
	for ev in events:
		var vfx_at := maxf(ev.t0 - SWING_LEAD, t)
		await get_tree().create_timer(vfx_at - t).timeout
		t = vfx_at
		# Перекат, удар по Сигрид или смерть оборвали замах
		if not is_attacking or not _same_attack(clip):
			_disable_kick_hitbox()
			return
		# Удар могли довернуть в начале замаха (character_base._steer_attack) —
		# дуга и хитбокс идут туда, куда Сигрид смотрит сейчас
		if facing_dir != Vector2.ZERO and not facing_dir.is_equal_approx(dir):
			dir = facing_dir
			if not ev.has("thrust") and not ev.has("chop"):
				var cur := _swing(info[0], last_direction, info[1], dir)
				for k in ["from", "to", "radius", "width", "power"]:
					ev[k] = cur[k]
		if ev.has("thrust"):
			KnightFx.thrust(self, dir, 36.0, SIGRID_CHEST)
		elif ev.has("chop"):
			KnightFx.chop(self, dir, 28.0, ev.t1 - ev.t0 + SWING_LEAD, 1.25, SIGRID_CHEST)
		else:
			KnightFx.arc(self, ev.from, ev.to, ev.radius, ev.width, ev.t1 - ev.t0 + SWING_LEAD, ev.power,
					SIGRID_CHEST, true, false)
		# Свист сакса: финиш серии — ниже и громче (рубящий, всем весом)
		Sfx.play_on(self, "dagger_swing", 2.0 if step == 3 else 0.0, 0.9 if step == 3 else 1.0)
		# Финиш серии — всегда с выкриком, остальные удары — через раз
		_say("attack", 1.0 if step == 3 else attack_voice_chance)
		await get_tree().create_timer(maxf(ev.t0 - t, 0.0)).timeout
		t = maxf(ev.t0, t)
		if not is_attacking or not _same_attack(clip):
			return
		var dmg := sword_finisher_damage if step == 3 else sword_damage
		_open_sword_hitbox(dir * sword_reach, sword_hit_scale, dmg)
		var close_at: float = ev.t1 + SWING_TAIL_HIT
		await get_tree().create_timer(maxf(close_at - t, 0.01)).timeout
		t = close_at
		_disable_kick_hitbox()
	# Клинок прошёл — отмах больше не держит: следующий удар серии сразу,
	# движение обрывает хвост (character_base._attack_recovery)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


## Шаг на ударе серии — отложенный до замаха (см. sword_step_lead). Если
## удар успели оборвать (перекат, урон), шагать уже некуда
func _step_into_swing(clip: String, delay: float, step_speed: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_attacking or not _same_attack(clip):
		return
	# Куда смотрит сейчас — удар могли довернуть в начале замаха
	attack_step(facing_dir * step_speed)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_carry_enemies()


## Куда Сигрид сейчас движется самим ударом: шаг серии или выпад (он идёт
## через knockback_velocity). Рывок удара на бегу сюда не входит — он слишком
## быстрый, и враг улетал от него далеко; вместо этого разбег гасится о цель
## (см. _brake_run_attack). Не в стойке меча или не в ударе — ноль
func _sword_motion() -> Vector2:
	if weapon != Weapon.SWORD or not is_attacking or is_rolling or is_run_attacking:
		return Vector2.ZERO
	if knockback_velocity != Vector2.ZERO:
		# Тот же knockback_velocity несёт и отброс от вражеского удара — его
		# врагам не передаём, только рывок выпада
		if anim.current_animation.begins_with(SWORD_PREFIX + "Lunge"):
			return knockback_velocity
		return Vector2.ZERO
	return _attack_step_velocity


## Враги прямо перед Сигрид едут вместе с её шагом — удар «вдавливает» их
## назад, а не упирается в тело. Скорость задаём каждый кадр заново через
## knockback_velocity врага (enemy.gd гасит его сам, когда шаг кончится)
func _carry_enemies() -> void:
	_brake_run_attack()
	var motion := _sword_motion()
	if motion.length() < 20.0:
		return
	var motion_dir := motion.normalized()
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead or not ("knockback_velocity" in e):
			continue
		var offset: Vector2 = e.global_position - global_position
		var dist := offset.length()
		if dist > sword_carry_reach or dist < 0.001:
			continue
		if motion_dir.dot(offset / dist) < 0.35:
			continue
		var carry := motion * sword_carry_factor
		if e.knockback_velocity.length() < carry.length():
			e.knockback_velocity = carry


## Удар с разбега мечом: добежала до врага — разбег гаснет о него, Сигрид
## останавливается у цели, а не проезжает дальше и не таранит её
func _brake_run_attack() -> void:
	if weapon != Weapon.SWORD or not is_run_attacking or _run_dash_velocity.length() < 20.0:
		return
	var dash_dir := _run_dash_velocity.normalized()
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		var offset: Vector2 = e.global_position - global_position
		var dist := offset.length()
		if dist < run_attack_stop_distance and dist > 0.001 and dash_dir.dot(offset / dist) > 0.35:
			_run_dash_velocity = Vector2.ZERO
			return


## Удар с разворотом (ПКМ) — бьёт всех вокруг, и выпад (V) — рывок вперёд с
## уколом. Отдельные приёмы, не шаги серии
func _start_sword_move(kind: String) -> void:
	var aim: Node2D = _pick_aim()
	var dir: Vector2
	if is_instance_valid(aim):
		dir = (aim.global_position - global_position).normalized()
	elif _aim_dir() != Vector2.ZERO:
		dir = _aim_dir()
	else:
		dir = facing_dir
	var dir_name := get_direction(dir)
	var clip := SWORD_PREFIX + kind + "_" + dir_name
	if dir_name == "" or not anim.has_animation(clip):
		return
	var spin := kind == "Spin"
	if not _pay(spin_stamina_cost if spin else lunge_stamina_cost):
		return
	if spin:
		_spin_cooldown_timer = spin_cooldown
	else:
		_lunge_cooldown_timer = lunge_cooldown
	is_attacking = true
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	_attack_step_velocity = Vector2.ZERO
	facing_dir = dir
	last_direction = dir_name
	anim.play(clip)

	if spin:
		# Время — по следу клинка на спрайте (Attack2), дуга — полный круг
		var sw := _swing("Attack2", dir_name, KnightFx.Swing.SPIN, dir)
		var p := KnightFx.preset(KnightFx.Swing.SPIN, dir)
		await get_tree().create_timer(maxf(sw.t0 - SWING_LEAD, 0.0)).timeout
		if not is_attacking or not _same_attack(clip):
			return
		KnightFx.arc(self, p.from, p.to, p.radius * 0.85, p.width, sw.t1 - sw.t0 + SWING_LEAD, p.power, SIGRID_CHEST, true)
		# Разворот — длинный свист по кругу: два замаха внахлёст
		Sfx.play_on(self, "dagger_swing", 1.0, 0.88)
		get_tree().create_timer(0.09).timeout.connect(func():
			if is_instance_valid(self):
				Sfx.play_on(self, "dagger_swing", -1.0, 0.95))
		_say("attack")
		await get_tree().create_timer(SWING_LEAD).timeout
		if not is_attacking or not _same_attack(clip):
			return
		_open_sword_hitbox(Vector2.ZERO, Vector2(3.4, 3.0), spin_damage)
		await get_tree().create_timer(sw.t1 - sw.t0 + SWING_TAIL_HIT).timeout
		_disable_kick_hitbox()
		if is_attacking and _same_attack(clip):
			_attack_recovery = true
		return

	await get_tree().create_timer(LUNGE_HIT[0]).timeout
	if not is_attacking or not _same_attack(clip):
		return
	# Выпад — короткий резкий свист укола
	Sfx.play_on(self, "dagger_swing", 1.0, 1.08)
	_say("attack")
	knockback_velocity = dir * lunge_speed
	KnightFx.thrust(self, dir, 40.0, SIGRID_CHEST)
	_open_sword_hitbox(dir * (sword_reach + 8.0), sword_hit_scale * Vector2(1.2, 0.9), lunge_damage)
	await get_tree().create_timer(LUNGE_HIT[1] - LUNGE_HIT[0]).timeout
	_disable_kick_hitbox()
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


# ─────────────────────────────────────────────
# ГОЛОС
# ─────────────────────────────────────────────
## Женский голос Сигрид (Sound/sigrid_voice/, авторы и лицензии — там же в
## CREDITS.txt): выкрик на тяжёлых ударах и натянутом выстреле, выдох на
## перекате, стон от урона (от сильного — глухой сдержанный, сквозь зубы), предсмертный стон. Один
## голосовой канал: важное (урон, смерть) перебивает выкрик, но не наоборот.
## Файлы грузятся лениво — если какого-то нет, Сигрид просто промолчит
const VOICE_DIR := "res://Sound/sigrid_voice/"
const VOICE_POOLS := {
	"attack": ["attack1.wav", "attack2.wav", "attack3.wav"],
	"roll": ["roll1.wav", "roll2.wav", "roll3.wav"],
	"hurt": ["hurt1.wav", "hurt2.wav", "hurt3.wav"],
	# Сильный удар — сдержанный стон сквозь зубы (крик убран по просьбе)
	"hurt_heavy": ["hurt_heavy_1.wav", "hurt_heavy_2.wav", "hurt_heavy_3.wav", "hurt_heavy_4.wav",
			"hurt_heavy_5.wav", "hurt_heavy_6.wav", "hurt_heavy_7.wav"],
	"death": ["death.ogg"],
}
const VOICE_PRIO := {"roll": 0, "attack": 1, "hurt": 2, "hurt_heavy": 3, "death": 4}
@export var voice_volume_db := -8.0
@export var hurt_volume_db := -5.0
## Выкрик не на каждом ударе — иначе приедается. Финиш серии, разворот,
## выпад и полностью натянутый лук — всегда
@export var attack_voice_chance := 0.5
@export var roll_voice_chance := 0.6
## Удар, снявший больше этой доли здоровья, — тяжёлый сдержанный стон, а не короткий
@export var heavy_hurt_fraction := 0.25
var _voice: AudioStreamPlayer2D
var _voice_prio := -1
var _voice_last := {}
static var _voice_cache := {}


func _voice_pick(key: String) -> AudioStream:
	var files: Array = VOICE_POOLS[key]
	var idx := randi() % files.size()
	if files.size() > 1 and idx == _voice_last.get(key, -1):
		idx = (idx + 1 + randi() % (files.size() - 1)) % files.size()
	_voice_last[key] = idx
	var path: String = VOICE_DIR + files[idx]
	if not _voice_cache.has(path):
		_voice_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _voice_cache[path]


func _say(key: String, chance := 1.0) -> void:
	if not is_instance_valid(_voice) or randf() > chance:
		return
	var prio: int = VOICE_PRIO[key]
	if _voice.playing and prio < _voice_prio:
		return
	var stream := _voice_pick(key)
	if stream == null:
		return
	var pain: bool = prio >= int(VOICE_PRIO["hurt"])
	_voice.stream = stream
	_voice.volume_db = hurt_volume_db if pain else voice_volume_db
	# Стон — через то же эхо, что у рыцаря (шина HurtEcho), если она есть
	_voice.bus = "HurtEcho" if pain and AudioServer.get_bus_index("HurtEcho") >= 0 else "Combat"
	_voice.pitch_scale = randf_range(0.95, 1.05)
	_voice.play()
	_voice_prio = prio


## Истощение у Сигрид своё: багровая рамка с венами, бьющаяся в такт сердцу
## (UI/sigrid_exhaust.gd), а не общая голубая виньетка
const SigridExhaust := preload("res://UI/sigrid_exhaust.gd")

func _make_exhaust_layer() -> CanvasLayer:
	var l: CanvasLayer = SigridExhaust.new()
	l.name = "ExhaustVeins"
	add_child(l)
	# Слои одного номера рисуются в порядке детей: первым ребёнком — ПОД
	# полосками здоровья и прочим интерфейсом героя (иначе их бы стягивало
	# и затемняло вместе с миром)
	move_child(l, 0)
	return l


## Женская одышка (Sound/sigrid_voice/breath_exhausted.*). Файла нет —
## Сигрид дышит молча, но не мужским голосом из общей одышки
const BREATH_FILES := ["breath_exhausted.ogg", "breath_exhausted.wav"]

func _dyspnea_stream() -> AudioStream:
	for f in BREATH_FILES:
		var path: String = VOICE_DIR + f
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Скачанная одышка звучала «мужской»: шум дыхания низкий и грудной. Поэтому
## она идёт выше тоном (pitch_scale — заодно чуть чаще, как у запыхавшейся)
## и через свою шину с обрезкой низов: без «груди» дыхание звучит легче,
## по-женски. Обе ручки — в инспекторе
## Темп и тон разделены: breath_tempo — скорость дыхания (1.0 — как в файле;
## меньше — реже и спокойнее), breath_tone — итоговая высота (выше — легче,
## женственнее). Тон держит эффект PitchShift на шине, поэтому замедление не
## делает голос ниже. Обе ручки — в инспекторе
@export_range(0.6, 1.8, 0.01) var breath_tempo := 1.1
@export_range(0.8, 1.8, 0.01) var breath_tone := 1.28
@export_range(50.0, 1500.0, 10.0) var breath_low_cut_hz := 380.0
## Громкость одышки (дБ). Было -3 — на слух слишком громко
@export_range(-30.0, 6.0, 0.5) var breath_volume_db := -10.0
const BREATH_BUS := "SigridBreath"


func _tune_breath() -> void:
	dyspnea_volume = breath_volume_db
	if not is_instance_valid(_dyspnea) or _dyspnea.stream == null:
		return
	var idx := AudioServer.get_bus_index(BREATH_BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BREATH_BUS)
		AudioServer.set_bus_send(idx, "Master")
	var cut: AudioEffectHighPassFilter = null
	var shift: AudioEffectPitchShift = null
	for i in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectHighPassFilter:
			cut = fx
		elif fx is AudioEffectPitchShift:
			shift = fx
	if cut == null:
		cut = AudioEffectHighPassFilter.new()
		AudioServer.add_bus_effect(idx, cut)
	if shift == null:
		shift = AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(idx, shift)
	cut.cutoff_hz = breath_low_cut_hz
	# Плеер играет в темпе breath_tempo (это заодно сдвигает тон), а сдвиг на
	# шине доводит тон до breath_tone
	shift.pitch_scale = breath_tone / maxf(breath_tempo, 0.01)
	_dyspnea.bus = BREATH_BUS
	_dyspnea.pitch_scale = breath_tempo


func receive_attack(attack_data: Dictionary) -> bool:
	var hp_before: float = health
	var got: bool = super(attack_data)
	if got and not is_dead():
		_say("hurt_heavy" if hp_before - health >= max_health * heavy_hurt_fraction else "hurt")
	return got


func _die() -> void:
	super()
	_say("death")


func start_roll() -> void:
	var was := is_rolling
	super()
	if is_rolling and not was:
		_say("roll", roll_voice_chance)
		Sfx.play_on(self, "roll")


## Хитбокс клинка — тот же узел, что у пинка (KickHitbox): enemy.gd узнаёт
## удар по группе player_attack и берёт урон из meta "damage"
func _open_sword_hitbox(pos: Vector2, scl: Vector2, dmg: int) -> void:
	kick_hitbox.set_meta("damage", dmg)
	kick_hitbox.scale = scl
	kick_hitbox.position = pos
	kick_hitbox.set_deferred("monitoring", true)
	kick_hitbox.get_child(0).set_deferred("disabled", false)


## Клинок задел врага — лёгкая тряска камеры, как у рыцаря
func _on_blade_contact(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	if weapon == Weapon.SWORD:
		shake_camera(2.5, 0.12)
	# Звук попадания: сталь о щит (враг закрылся и смотрит на Сигрид) или
	# клинок в тело. Состояние врага читаем ДО того, как он сам обработает удар
	var e := area.get_parent()
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	var guarded: bool = (e.get("is_blocking") == true or e.get("is_parrying") == true) \
			and (not e.has_method("_is_guarding_against") or bool(e.call("_is_guarding_against", self)))
	var at := area.global_position
	if guarded:
		Sfx.play_at(get_tree(), "dagger_block", at)
		return
	# Сочный удар — три слоя разом: рез, шлепок по плоти, глухой удар по
	# телу. Финиш серии и выпад тяжелее — слой тела громче и ниже
	var heavy := combo_step == 3 or String(anim.current_animation).begins_with(SWORD_PREFIX + "Lunge")
	Sfx.play_at(get_tree(), "dagger_hit", at)
	Sfx.play_at(get_tree(), "dagger_flesh", at, 2.0 if heavy else 0.0, 0.92)
	Sfx.play_at(get_tree(), "dagger_body", at, 4.0 if heavy else 0.0, 0.5 if heavy else 0.6, 0.05)


# ═════════════════ НАВЫКИ СИГРИД (Save/skill_trees.gd) ═════════════════
# Верная тетива — в _fire_arrow/_charge_rate/resolve_arrow_hit; кинжал,
# скрытность, кража и ловушка — здесь. Враг спрашивает лучницу сам
# (enemy.gd: melee_damage_to, posture_mult_vs, gold_mult_for, detection_mult)

## Заряженная стрела попала: instance_id врага -> сколько ещё держится
## «След стрелы» (атаки по нему сильнее)
var _charged_marks := {}
## Сейчас в take_damage летит заряженная стрела (для удара в щит)
var _posture_shot_charged := false
## Быстрая рука: секунды усиленного кинжала после смены лука на кинжал
var _switch_bonus_left := 0.0
## Враги, по которым кинжал уже бил (Первый порез) и у которых уже пробовали
## украсть (Ловкие пальцы — одна попытка на врага, даже неудачная)
var _dagger_hit := {}
var _steal_tried := {}


## Бонус ко ВСЕМ атакам Сигрид по этой цели: След стрелы, Кровавый след
func _target_damage_percent(enemy: Node) -> float:
	var pct := 0.0
	if _charged_marks.has(enemy.get_instance_id()):
		pct += skill("charged_mark_damage_percent")
	var bleed := enemy.get_node_or_null("ArcherBleed")
	if bleed and int(bleed.get("ticks_left")) > 0:
		pct += skill("vs_bleeding_damage_percent")
	return pct


## Свежая рана, Та, что выжила: шанс открыть кровотечение любым попаданием
func _roll_bleed() -> bool:
	var chance := skill("bleed_chance_percent")
	return chance > 0.0 and randf() < chance / 100.0


func _bleed_after_hit(enemy: Node) -> void:
	if is_instance_valid(enemy) and not enemy.get("is_dead"):
		_apply_bleed(enemy)


## Кровотечение Кровавого Пера, дольше с Долгой охотой
func _apply_bleed(enemy: Node) -> void:
	var ticks := SkillTrees.scale_int(BLEED_TICKS, skill("bleed_duration_percent"))
	ArcherFx.Bleed.apply(enemy, ticks, 1, BLEED_INTERVAL, self)


## Удар ближнего боя дошёл (enemy.gd::_hero_melee_damage): кинжал или пинок.
## Враг ещё не обработал удар — «не заметил» и «со спины» честные
func melee_damage_to(enemy: Node, dmg: int) -> int:
	var pct := _target_damage_percent(enemy)
	# Свежая рана: кровотечение — после самого удара (враг мог и умереть)
	if _roll_bleed():
		_bleed_after_hit.call_deferred(enemy)
	if weapon != Weapon.SWORD:
		enemy.set_meta("last_hit_dagger", false)
		return SkillTrees.scale_int(dmg, pct)
	var id := enemy.get_instance_id()
	var unaware: bool = enemy.has_method("is_unaware_of") and enemy.is_unaware_of(self)
	var behind: bool = enemy.has_method("is_behind") and enemy.is_behind(self)
	pct += skill("dagger_damage_percent")
	if behind:
		pct += skill("backstab_dagger_damage_percent")
	if unaware:
		pct += skill("unaware_dagger_damage_percent")
		if not _dagger_hit.has(id):
			pct += skill("first_unaware_dagger_damage_percent")
	if _switch_bonus_left > 0.0:
		pct += skill("switch_dagger_damage_percent")
	dmg = SkillTrees.scale_int(dmg, pct)
	# Крит кинжала есть только в спину (Слепой угол)
	var crit_chance := skill("backstab_dagger_crit_points") / 100.0 if behind else 0.0
	if crit_chance > 0.0 and randf() < crit_chance:
		var crit_pct := skill("backstab_dagger_crit_damage_percent")
		if unaware:
			crit_pct += skill("unaware_crit_damage_percent")
		dmg = SkillTrees.scale_int(dmg * CRIT_MULT, crit_pct)
		ArcherFx.Burst.spawn(get_tree().current_scene, (enemy as Node2D).global_position + Vector2(0, -20), COLOR_VALKYRIE)
	if behind and unaware:
		_try_steal(enemy)
	_dagger_hit[id] = true
	enemy.set_meta("last_hit_dagger", true)
	return dmg


## Ловкие пальцы: незаметный удар кинжалом в спину — одна попытка на врага
func _try_steal(enemy: Node) -> void:
	var id := enemy.get_instance_id()
	if skill("steal_chance_percent") <= 0.0 or _steal_tried.has(id):
		return
	_steal_tried[id] = true
	if randf() >= skill("steal_chance_percent") / 100.0:
		return
	var base: float = enemy.base_gold_value() if enemy.has_method("base_gold_value") else 10.0
	var amount := maxi(int(skill("steal_min_gold")), roundi(base * skill("steal_gold_percent") / 100.0))
	add_gold(amount)
	Sfx.play_on(self, "quiver")
	load("res://Levels/loot/loot_ui.gd").of(get_tree()).show_pickup(null, tr("Украдено: %d золота") % amount, "")


## Урон по стойкости врага в щит: Тяжёлое оперение для заряженной стрелы
func posture_mult_vs(_enemy: Node) -> float:
	return 1.0 + (skill("charged_posture_percent") if _posture_shot_charged else 0.0) / 100.0


## Тихий шаг, Без свидетелей: зона зрения врагов меньше
func detection_mult() -> float:
	return maxf(1.0 + skill("detection_radius_percent") / 100.0, 0.2)


## Чужая добыча: враг, добитый кинжалом, даёт больше золота
func gold_mult_for(enemy: Node) -> float:
	if enemy.get_meta("last_hit_dagger", false):
		return 1.0 + skill("dagger_kill_gold_percent") / 100.0
	return 1.0


# ─────────── Узел ловчего: ловушка (новая механика) ───────────

## Действие ловушки — своё, заводится при старте, если его нет в настройках
## проекта (G по умолчанию, переназначается как любое другое)
const TRAP_ACTION := "trap_place"
var _trap_cooldown := 0.0
var _trap: Node2D


func _ensure_trap_action() -> void:
	if InputMap.has_action(TRAP_ACTION):
		return
	InputMap.add_action(TRAP_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	InputMap.action_add_event(TRAP_ACTION, ev)


func _try_place_trap() -> void:
	if skill("trap_enabled") <= 0.0 or _trap_cooldown > 0.0:
		return
	if is_instance_valid(health_bar) and not health_bar.use_stamina(skill("trap_stamina_cost")):
		return
	# Не больше одной: новая заменяет старую
	if is_instance_valid(_trap):
		_trap.queue_free()
	_trap = SnareTrap.new()
	_trap.radius = skill("trap_radius")
	_trap.slow_percent = skill("trap_slow_percent")
	_trap.slow_seconds = skill("trap_slow_seconds")
	_trap.lifetime = skill("trap_lifetime_seconds")
	get_tree().current_scene.add_child(_trap)
	_trap.global_position = global_position + Vector2(0, 14)
	_trap_cooldown = skill("trap_cooldown_seconds")
	SoundBank.play_at(get_tree(), "trap_place", global_position, -8.0)


## Силок на земле: первый враг в радиусе замедляется и силок исчезает.
## Нарисован линиями в тусклых тонах — тёмное железо и верёвка
class SnareTrap extends Node2D:
	var radius := 24.0
	var slow_percent := 30.0
	var slow_seconds := 3.0
	var lifetime := 30.0
	var _t := 0.0
	var _sprung := false

	func _process(delta: float) -> void:
		_t += delta
		if _sprung:
			return
		if _t >= lifetime:
			_vanish()
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
				continue
			if (e as Node2D).global_position.distance_to(global_position) <= radius:
				if e.has_method("apply_slow"):
					e.apply_slow(slow_percent, slow_seconds)
				preload("res://Levels/sound_bank.gd").play_at(get_tree(), "trap_snap", global_position, -4.0)
				_sprung = true
				_vanish()
				return
		queue_redraw()

	func _vanish() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		# Последние 3 с мигает — силок вот-вот рассыплется
		var a := 0.85
		if lifetime - _t < 3.0:
			a *= 0.5 + 0.5 * absf(sin(_t * 6.0))
		var iron := Color(0.42, 0.4, 0.37, a)
		var rope := Color(0.55, 0.45, 0.3, a * 0.8)
		draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 32, rope, 1.5, true)
		for i in 8:
			var ang := TAU * i / 8.0
			var d := Vector2.from_angle(ang)
			draw_line(d * radius * 0.35, d * radius * 0.7, iron, 1.5, true)
		draw_circle(Vector2.ZERO, 2.0, iron)
