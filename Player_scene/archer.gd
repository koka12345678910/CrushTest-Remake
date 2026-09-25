extends "res://Player_scene/character_base.gd"
## Лучник. Движение, направления, серия ударов и здоровье — в общей базе
## (character_base.gd), здесь только то, что отличает его от остальных:
## каждый удар серии выпускает стрелу вместо чистого рукопашного взмаха.

const ArrowScript := preload("res://Player_scene/arrow.gd")
const ArcherFx := preload("res://Player_scene/archer_fx.gd")
const SHOOT_SOUND := preload("res://Sound/archer_sound/arrow.mp3")

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
var inventory_ui: CanvasLayer
var hud: CanvasLayer
var _skill_audio: AudioStreamPlayer
var _status: Node2D
var _last_gold := -1

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
	_setup_inventory()
	_load_starting_items()


func _setup_inventory() -> void:
	ability_system = AbilitySystem.new()
	ability_system.name = "AbilitySystem"
	add_child(ability_system)
	inventory_system = InventorySystem.new()
	inventory_system.name = "InventorySystem"
	add_child(inventory_system)

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

	inventory_ui.init(ability_system, inventory_system, self)
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
	# Последний взор — стрельба вдвое чаще
	_shoot_cooldown_timer = shoot_cooldown * (LAST_LOOK_RATE if _last_look_time > 0.0 else 1.0)
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
	await get_tree().create_timer(_current_shoot_delay()).timeout
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
	_fire_arrow(dir, aim)


## Сам спавн стрелы, без выбора направления — общий кусок между обычным
## выстрелом (_shoot_arrow, направление берёт из aim-узла) и быстрым залпом
## (_start_quick_shot, направление фиксировано заранее на весь залп)
##
## Здесь же на стрелу навешиваются заряженные навыки — каждый заряд уходит
## ровно в одну стрелу, какой бы кнопкой она ни была выпущена
func _fire_arrow(dir: Vector2, aim: Node2D = null) -> void:
	var arrow: Area2D = ArrowScript.new()
	var dmg := arrow_damage
	var spd := arrow_speed
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

	var chance := BASE_CRIT_CHANCE
	if _last_look_time > 0.0:
		chance += LAST_LOOK_CRIT_BONUS
	if _hit_before.has(id) and _has_talisman(TALISMAN_NORN):
		chance += NORN_CRIT_BONUS
	var crit: bool = arrow.tags.get("guaranteed_crit", false) or randf() < chance
	if crit:
		dmg *= CRIT_MULT
		ArcherFx.Burst.spawn(get_tree().current_scene, enemy.global_position + Vector2(0, -20), COLOR_VALKYRIE)
		shake_camera(2.5, 0.12)

	enemy.take_damage(dmg, self)
	_hit_before[id] = true

	if enemy.is_dead:
		_marked.erase(id)
		return
	if crit and _bleed_time > 0.0:
		ArcherFx.Bleed.apply(enemy, BLEED_TICKS, 1, BLEED_INTERVAL, self)
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
	return _focus.get_nearest_enemy()


func _has_talisman(item_name: String) -> bool:
	return inventory_system != null and inventory_system.get_count(item_name) > 0


func _process(delta: float) -> void:
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
	var aim: Node2D = _pick_aim()
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
		_fire_arrow(dir, aim)
		if i < quick_shot_count - 1:
			await get_tree().create_timer(quick_shot_interval).timeout

	is_attacking = false
	play_movement_animation()
