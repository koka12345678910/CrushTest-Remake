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
const MageHudScript := preload("res://Player_scene/mage_hud.gd")
const SOUND_DENIED := preload("res://UI/ui_sounds.gd").ERROR
const HudScript := preload("res://Inventory/ui/hud.gd")
const QuickSlotScript := preload("res://Inventory/ui/quick_slot_ui.gd")
const InventoryUIScript := preload("res://Inventory/systems/inventory/inventory_ui.gd")

## Каталог магазина (Shop/shop_menu.gd::_build_items_for): у мага — зелья за
## души
var character_id := "mage"
## Сумка и быстрый слот — как у лучницы (archer.gd::_setup_inventory): R —
## выпить, колесо — слоты, Esc — инвентарь
var ability_system: AbilitySystem
var inventory_system: InventorySystem
var talisman_system: TalismanSystem
var inventory_ui: CanvasLayer
var hud: CanvasLayer

## Сейд — колдовская сила мага (шкала между здоровьем и выносливостью,
## светлее Одра рыцаря). Заклинания тратят Сейд, стамина остаётся на бег и
## уклонение. Восполняется сам: после паузы медленно, а если не колдовать
## seid_rest_time секунд — быстро
@export var max_seid := 100.0
@export var seid_regen := 9.0
@export var seid_regen_rested := 24.0
@export var seid_regen_delay := 0.8
@export var seid_rest_time := 2.0
const SEID_COLOR := Color(0.1, 0.24, 0.38)
const SEID_LACK_COLOR := Color(0.4, 0.66, 0.92)
var seid := 100.0
var _since_cast := 99.0
## Какая руна колдуется сейчас (подсветка на панели), -1 — никакая
var _casting_rune := -1
var mage_hud: CanvasLayer
## Рунная панель — левее быстрого слота предметов (его клетка прижата к
## правому нижнему углу: правый край 1845 в макете, ширина 124), правее
## полоски концентрации по центру
const RUNES_RIGHT := 75.0 + 124.0 + 28.0


func _ready() -> void:
	super()
	# По этой группе кровь от его заклинаний брызжет "магическим" видом —
	# во все стороны и темнее, обожжённая (VFX/VFX_scene/blood_fx.gd::kind_from)
	add_to_group("caster_player")
	seid = max_seid
	if is_instance_valid(health_bar):
		health_bar.enable_odr(SEID_COLOR, SEID_LACK_COLOR)
	# HUD мага — раньше инвентаря: слои одного уровня рисуются в порядке
	# дерева, и открытый инвентарь должен лечь поверх рун и счётчика душ
	mage_hud = MageHudScript.new()
	mage_hud.name = "MageHUD"
	add_child(mage_hud)
	_setup_inventory()
	_ensure_life_exchange_action()
	mage_hud.build_runes([
		{"key": "ЛКМ", "cost": fireball_seid_cost, "glyph": [[Vector2(0.72, 0.08), Vector2(0.28, 0.5), Vector2(0.72, 0.92)]]},
		{"key": "ПКМ", "cost": sweep_seid_cost, "glyph": [[Vector2(0.68, 0.06), Vector2(0.3, 0.38), Vector2(0.7, 0.62), Vector2(0.32, 0.94)]]},
		{"key": "V", "cost": pulse_seid_cost, "glyph": [[Vector2(0.25, 0.06), Vector2(0.25, 0.94)], [Vector2(0.75, 0.06), Vector2(0.75, 0.94)],
				[Vector2(0.25, 0.36), Vector2(0.75, 0.64)]]},
		{"key": "B", "cost": special_seid_cost, "glyph": [[Vector2(0.5, 0.94), Vector2(0.5, 0.06)], [Vector2(0.5, 0.46), Vector2(0.16, 0.1)],
				[Vector2(0.5, 0.46), Vector2(0.84, 0.1)]]},
	], RUNES_RIGHT)


func _process(delta: float) -> void:
	super(delta)
	_since_cast += delta
	if _since_cast > seid_regen_delay:
		var rate := seid_regen_rested if _since_cast > seid_rest_time else seid_regen
		if _has_talisman(TALISMAN_MIMIR):
			rate *= MIMIR_REGEN
		rate *= 1.0 + _seid_regen_percent() / 100.0
		seid = minf(seid + rate * delta, max_seid)
	_life_exchange_cd = maxf(_life_exchange_cd - delta, 0.0)
	if not is_attacking:
		_casting_rune = -1
	if is_instance_valid(health_bar):
		health_bar.set_odr(seid, max_seid)
	if is_instance_valid(mage_hud):
		mage_hud.update_runes(seid, _casting_rune, [_spell_cost(0), _spell_cost(1), _spell_cost(2), _spell_cost(3)])
		mage_hud.sync_souls(souls)


## ── Талисманы мага (Inventory/systems/ability/abilities/mage/) ──
## Действуют, только пока надеты во вкладке "Талисманы" (TalismanSystem),
## как у лучницы (archer.gd::_has_talisman)
const TALISMAN_MIMIR := "Глаз Мимира"
const TALISMAN_DRAUPNIR := "Кольцо Драупнир"
const TALISMAN_VOLVA := "Гандр вёльвы"
const MIMIR_REGEN := 1.5
const DRAUPNIR_SOULS := 1.3
const VOLVA_COST := 0.8


func _has_talisman(item_name: String) -> bool:
	return talisman_system != null and talisman_system.has_talisman(item_name)


## Цена руны в Сейде с учётом Гандра вёльвы и ранга заклинания в Гримуаре
## (0 — шар, 1 — облако, 2 — импульс, 3 — столпы)
func _spell_cost(rune: int) -> float:
	var cost: float = base_spell_cost(rune)
	if spell_ranks[rune] >= 2:
		cost *= RANK2_COST
	if _has_talisman(TALISMAN_VOLVA):
		cost *= VOLVA_COST
	# Навыки (Тихое слово, Короткое заклятие, Слово без ошибки, Вечный
	# возврат): не дешевле трети цены — заклинания не становятся бесплатными
	var pct := skill("spell_cost_percent")
	if rune == 0:
		pct += skill("fireball_cost_percent")
	elif rune == 2:
		pct += skill("pulse_cost_percent")
	elif rune == 3:
		pct += skill("pillar_cost_percent")
	cost *= maxf(1.0 + pct / 100.0, 0.3)
	return maxf(roundf(cost), 1.0)


func base_spell_cost(rune: int) -> float:
	return [fireball_seid_cost, sweep_seid_cost, pulse_seid_cost, special_seid_cost][rune]


## Цена руны для Гримуара (тот же расчёт, что при касте)
func spell_cost(rune: int) -> float:
	return _spell_cost(rune)


## ── Гримуар и Сосуд душ (Inventory/ui/mage_grimoire.gd) ──
## Души тратятся прямо в инвентаре: у каждого заклинания три ранга
## (II — дешевле на RANK2_COST, III — сильнее, см. spell_power), сосуд —
## прибавка к шкале Сейда. Сейв — SaveManager.hero_progress
const RANK2_COST := 0.8
const RANK_PRICES := [0, 0, 60, 140]
const VESSEL_PRICES := [80, 160, 260]
const VESSEL_SEID := 20.0
const MAX_RANK := 3
## Прямой урон шара (mage_fireball.gd direct_damage) — для Гримуара и ранга III
const FIREBALL_DAMAGE := 2
var spell_ranks: Array[int] = [1, 1, 1, 1]
var vessel_level := 0
## База шкалы Сейда без сосуда (max_seid пересчитывается от неё)
var _base_max_seid := -1.0


## Сколько душ стоит следующий ранг (0 — уже максимальный)
func rank_price(rune: int) -> int:
	var r: int = spell_ranks[rune]
	return 0 if r >= MAX_RANK else RANK_PRICES[r + 1]


func vessel_price() -> int:
	return 0 if vessel_level >= VESSEL_PRICES.size() else VESSEL_PRICES[vessel_level]


## Поднять ранг заклинания за души. false — не хватает душ или ранг максимальный
func upgrade_spell(rune: int) -> bool:
	var price := rank_price(rune)
	if price <= 0 or souls < price:
		return false
	souls -= price
	spell_ranks[rune] += 1
	_apply_ranks()
	SaveManager.capture_from(self)
	return true


func upgrade_vessel() -> bool:
	var price := vessel_price()
	if price <= 0 or souls < price:
		return false
	souls -= price
	vessel_level += 1
	_apply_ranks()
	# Сосуд расширился — он тут же полон
	seid = max_seid
	SaveManager.capture_from(self)
	return true


## Ранг III: шар и облако бьют на +1, импульс на +1, столпы — по двум целям
## больше. Возвращает [урон, доп. цели] для руны
func spell_power(rune: int) -> Array:
	var r3 := spell_ranks[rune] >= 3
	match rune:
		0: return [FIREBALL_DAMAGE + (1 if r3 else 0), 0]
		1: return [sweep_damage + (1 if r3 else 0), 0]
		2: return [pulse_damage + (1 if r3 else 0), 0]
		_: return [0, special_max_targets + (2 if r3 else 0)]


func _apply_ranks() -> void:
	if _base_max_seid < 0.0:
		_base_max_seid = max_seid
	# Тихий исток, Глубокий родник, Вечный возврат — поверх Сосуда душ
	max_seid = (_base_max_seid + VESSEL_SEID * vessel_level) * (1.0 + skill("max_seid_percent") / 100.0)
	if is_instance_valid(mage_hud):
		mage_hud.update_runes(seid, _casting_rune, [_spell_cost(0), _spell_cost(1), _spell_cost(2), _spell_cost(3)])


func get_hero_progress() -> Dictionary:
	return {"spell_ranks": Array(spell_ranks), "vessel": vessel_level}


func set_hero_progress(data: Dictionary) -> void:
	var ranks: Array = data.get("spell_ranks", [1, 1, 1, 1])
	for i in mini(ranks.size(), spell_ranks.size()):
		spell_ranks[i] = clampi(int(ranks[i]), 1, MAX_RANK)
	vessel_level = clampi(int(data.get("vessel", 0)), 0, VESSEL_PRICES.size())
	_apply_ranks()
	seid = max_seid


## Сумка, быстрый слот (справа внизу, как у всех) и инвентарь — по образцу
## лучницы. Счётчик золота общего HUD магу не нужен — у него души (mage_hud)
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
	# hud.gd ищет $QuickSlotUI в своём _ready — ребёнка кладём ДО добавления
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
	if hud.gold_label:
		hud.gold_label.visible = false
	# Стартовый набор: один Мёд Поэзии (сумка без сейва была бы пуста)
	var mead := HoneyMeadAbility.new()
	inventory_ui.add_item(mead)
	ability_system.add_ability(mead)


## Esc — инвентарь, колесо — слоты, R — выпить. Как у лучницы
## (archer.gd::_unhandled_input); пока инвентарь открыт, дерево на паузе
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
	elif event.is_action_pressed(LIFE_EXCHANGE_ACTION):
		_try_life_exchange()


## Душа впиталась — счёт растёт, а на HUD от мага к счётчику летит огонёк
func add_souls(amount: int, at := Vector2.ZERO) -> void:
	# Кольцо Драупнир: душа приносит больше (округление вверх — +1 и с мелкой)
	if _has_talisman(TALISMAN_DRAUPNIR):
		amount = ceili(amount * DRAUPNIR_SOULS)
	# След ушедших
	amount = SkillTrees.scale_int(amount, skill("soul_gain_percent"))
	super(amount, at)
	if is_instance_valid(mage_hud):
		mage_hud.soul_collected(at if at != Vector2.ZERO else global_position + Vector2(0, -10), amount)

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
	await get_tree().create_timer(fireball_cast_delay * maxf(1.0 + skill("fireball_cast_time_percent") / 100.0, 0.3)).timeout
	# Пока маг замахивался, его могли перебить (перекат, удар) или убить —
	# тогда клип удара уже сменился и шар не выпускаем
	if is_dead() or not _same_attack(clip):
		return
	var dir: Vector2
	if is_instance_valid(aim) and not aim.is_dead:
		dir = (aim.global_position - global_position).normalized()
	else:
		dir = facing_dir
		if dir == Vector2.ZERO:
			dir = facing_dir
	var ball: Area2D = FireballScript.new()
	get_tree().current_scene.add_child(ball)
	ball.direct_damage = SkillTrees.scale_int(spell_power(0)[0], _spell_damage_percent(0))
	ball.splash_damage = SkillTrees.scale_int(ball.splash_damage, _spell_damage_percent(0))
	ball.launch(global_position + dir * fireball_offset, dir, self)
	# Шар ушёл — хвост клипа не держит (character_base._attack_recovery)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


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
	await get_tree().create_timer(sweep_start_delay).timeout
	if is_dead() or not _same_attack(clip):
		return
	# Направление — на момент поджига: каст могли довернуть в начале
	var facing := facing_dir
	var scorch: Node2D = ScorchScript.new()
	# В мире, а не на маге: выжженная земля остаётся на месте, если он отойдёт
	scorch.setup(self, facing, global_position + _body_anchor()[1],
			SkillTrees.scale_int(spell_power(1)[0], _spell_damage_percent(1) + skill("spell_burn_damage_percent")), sweep_knockback)
	# Долгий жар, Негаснущий жар: облако горит дольше
	scorch.hold_time *= 1.0 + skill("cloud_duration_percent") / 100.0
	get_tree().current_scene.add_child(scorch)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


## ЛКМ — дальняя атака (Attack_, огненный шар), ПКМ ("parry", у мага парирования
## нет) — ближняя (Attack_2_, пелена с отбросом), V ("kick", пинка у мага нет) —
## двойной импульс вокруг себя (Attack_3_), B ("special") — столпы огня под
## врагами (SpecialAttack_). Это отдельные кнопки, а не серия:
## повторное нажатие во время удара в очередь не ставится, как это делала база.
## Бег на Attack_ работает как раньше (Run_Attack_, если нарисована)
func handle_attack_input() -> void:
	# Нажатия — из буфера ввода базы: руна, нажатая под конец прошлого
	# заклинания или переката, сработает сразу, как маг освободится
	var fireball := _pressed("attack")
	var sweep := _pressed("parry")
	var pulse := _pressed("kick")
	var special := _pressed("special")
	if not fireball and not sweep and not pulse and not special:
		return
	# Прошлое заклинание уже сорвалось с руки (_attack_recovery) — новое
	# можно начинать, не дожидаясь конца клипа
	if is_attacking and not _attack_recovery:
		return
	# Заклинание стоит Сейда. Не хватает — не колдуем: шкала мигает, руна
	# вздрагивает, глухой звук отказа
	var rune := 3 if special else (2 if pulse else (1 if sweep else 0))
	_consume(["attack", "parry", "kick", "special"][rune])
	var cost := _spell_cost(rune)
	if seid < cost:
		if is_instance_valid(health_bar):
			health_bar.blink_odr()
		if is_instance_valid(mage_hud):
			mage_hud.rune_denied(rune)
		_play_denied()
		return
	if is_attacking:
		_cancel_attack()
	seid -= cost
	_since_cast = 0.0
	_casting_rune = rune
	_register_cast(rune)
	_last_cast_cost = cost
	if is_instance_valid(mage_hud):
		mage_hud.rune_cast(rune)
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


## Цена заклинаний в Сейде (шкала — HealthStaminaBar.enable_odr, руны — mage_hud.gd)
@export var fireball_seid_cost := 12.0
@export var sweep_seid_cost := 16.0
@export var pulse_seid_cost := 28.0
@export var special_seid_cost := 40.0


## Глухой отказ — не хватило Сейда. Не чаще раза в 0.25 с: зажатая кнопка
## не должна трещать
var _denied_at := -1000
func _play_denied() -> void:
	var now := Time.get_ticks_msec()
	if now - _denied_at < 250:
		return
	_denied_at = now
	var p := AudioStreamPlayer.new()
	p.stream = SOUND_DENIED
	p.volume_db = -10.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


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
	if is_dead() or not _same_attack(clip):
		return
	var small: Node2D = PulseScript.new()
	var body := _body_anchor()
	# Рунический круг под магом (circle = true) убран — к новому виду мага не
	# подошёл. Сам круг в mage_pulse.gd остался, включается этим флагом
	small.setup(self, pulse_small_radius, pulse_small_expand_frames * frame, 0.0, _pulse_damage(), pulse_small_knockback * _pulse_push(), 0.45, false, body[0], body[1], frame)
	add_child(small)
	shake_camera(pulse_small_shake, pulse_small_shake_time)

	await get_tree().create_timer(maxf(pulse_big_frame - pulse_small_frame, 0.0) * frame).timeout
	if is_dead() or not _same_attack(clip):
		return
	var big: Node2D = PulseScript.new()
	big.setup(self, pulse_big_radius, pulse_big_expand_frames * frame, 1.0, _pulse_damage(), pulse_big_knockback * _pulse_push(), 1.0, false, body[0], body[1], frame)
	add_child(big)
	_spawn_roots(global_position + body[1])
	shake_camera(pulse_big_shake, pulse_big_shake_time)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


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
	if not _play_restart("SpecialAttack_" + last_direction):
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
	# Глубокая резь: на цель больше
	return found.slice(0, spell_power(3)[1] + int(skill("pillar_extra_targets")))


func _cast_pillars(targets: Array) -> void:
	var clip := anim.current_animation
	var frame := _clip_frame_time(clip)
	await get_tree().create_timer(special_mark_frame * frame).timeout
	if is_dead() or not _same_attack(clip):
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
		if is_attacking and _same_attack(clip):
			_attack_recovery = true


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


# ═════════════════ НАВЫКИ ЭЙРИКА (Save/skill_trees.gd) ═════════════════

## Сейд и максимум — свои поля мага: пересчёт дерева доходит и до них
func _on_skills_changed() -> void:
	_apply_ranks()
	seid = max_seid


## Восстановление Сейда: Обратный поток, Вечный возврат; в передышке —
## Тихое дыхание; у края смерти — Равная доля
func _seid_regen_percent() -> float:
	var pct := skill("seid_regen_percent")
	if _since_cast > seid_rest_time:
		pct += skill("idle_seid_regen_percent")
	if max_health > 0.0 and health / max_health < 0.3:
		pct += skill("low_hp_seid_regen_percent")
	return pct


# ── Связанный знак: два РАЗНЫХ заклинания подряд в окне — второе сильнее ──
var _seq_rune := -1
var _seq_time := -1000.0
## Бонус последовательности для каждого из четырёх заклинаний — ставится в
## момент каста и действует на то, что это заклинание выпустит
var _cast_combo := [false, false, false, false]


func _register_cast(rune: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var window := skill("combo_window_seconds")
	_cast_combo[rune] = false
	if window > 0.0 and _seq_rune >= 0 and _seq_rune != rune and now - _seq_time <= window:
		_cast_combo[rune] = true
		# Второе заклинание сработало — последовательность начинается заново
		_seq_rune = -1
		return
	_seq_rune = rune
	_seq_time = now


## Процент к урону заклинания rune (0 шар, 1 облако, 2 импульс, 3 столпы).
## Все четыре — стихийные (огонь и сила земли)
func _spell_damage_percent(rune: int) -> float:
	var pct := skill("spell_damage_percent") + skill("elemental_damage_percent")
	match rune:
		0: pct += skill("fireball_damage_percent")
		2: pct += skill("pulse_damage_percent")
	if _cast_combo[rune]:
		pct += skill("combo_damage_percent")
	return pct


func _pulse_damage() -> int:
	return SkillTrees.scale_int(spell_power(2)[0], _spell_damage_percent(2))


## Вольный ветер: импульс отталкивает сильнее
func _pulse_push() -> float:
	return 1.0 + skill("pulse_knockback_percent") / 100.0


## Урон по стойкости врага в щит: волна импульса (Каменный ответ, Тяжёлая
## земля, Воля древней земли). mage_pulse.gd помечает удар волны
func posture_mult_vs(_enemy: Node) -> float:
	if get_meta("pulse_hit", false):
		return 1.0 + skill("pulse_posture_percent") / 100.0
	return 1.0


## Входящий урон: Память камня и (пока идёт импульс) Тяжёлая земля
func _incoming_damage_mult(_attack_data: Dictionary) -> float:
	var pct := skill("physical_damage_taken_percent")
	if is_attacking and _casting_rune == 2:
		pct += skill("casting_pulse_damage_taken_percent")
	return maxf(1.0 + pct / 100.0, 0.1)


# ── Цепь корней: после импульса — зона, замедляющая врагов внутри ──
func _spawn_roots(at: Vector2) -> void:
	if skill("roots_enabled") <= 0.0:
		return
	var z := RootZone.new()
	z.radius = skill("roots_radius")
	z.lifetime = skill("roots_seconds")
	z.slow_percent = skill("roots_slow_percent")
	get_tree().current_scene.add_child(z)
	SoundBank.play_at(get_tree(), "roots", at, -6.0)
	z.global_position = at


## Корни из земли: каждый кадр замедляет врагов внутри коротким замедлением
## (вышел — через миг отпустило). Несколько зон не складываются — у врага
## действует самое сильное замедление (enemy.gd::apply_slow)
class RootZone extends Node2D:
	var radius := 64.0
	var lifetime := 3.0
	var slow_percent := 25.0
	var _t := 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = -14

	func _process(delta: float) -> void:
		_t += delta
		if _t >= lifetime:
			queue_free()
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
				continue
			var to: Vector2 = (e as Node2D).global_position - global_position
			if Vector2(to.x, to.y / 0.8).length() <= radius and e.has_method("apply_slow"):
				e.apply_slow(slow_percent, 0.15)
		queue_redraw()

	func _draw() -> void:
		# Тёмные корни лучами из центра, к концу жизни тают
		var a := 0.75 * clampf((lifetime - _t) / 0.6, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
		var col := Color(0.28, 0.24, 0.18, a)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.8))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(col, a * 0.5), 1.5, true)
		for i in 9:
			var ang := TAU * i / 9.0 + 0.3
			var d := Vector2.from_angle(ang)
			var bend := Vector2.from_angle(ang + 0.5) * radius * 0.12
			draw_polyline(PackedVector2Array([d * radius * 0.15, d * radius * 0.55 + bend, d * radius * 0.92]), col, 2.0, true)


# ── Цена жизни: часть текущего здоровья — в Сейд (новая механика) ──
## Действие — своё, заводится при старте (C по умолчанию, переназначается)
const LIFE_EXCHANGE_ACTION := "life_exchange"
var _life_exchange_cd := 0.0


func _ensure_life_exchange_action() -> void:
	if InputMap.has_action(LIFE_EXCHANGE_ACTION):
		return
	InputMap.add_action(LIFE_EXCHANGE_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_C
	InputMap.action_add_event(LIFE_EXCHANGE_ACTION, ev)


## Обмен: 10% ТЕКУЩЕГО здоровья (не меньше 1) на 15% МАКСИМАЛЬНОГО Сейда.
## Нельзя при полном Сейде, на кулдауне и если после траты останется < 1 HP
func _try_life_exchange() -> bool:
	if skill("life_exchange_enabled") <= 0.0 or _life_exchange_cd > 0.0 or seid >= max_seid:
		return false
	var cost := maxf(ceilf(health * skill("life_exchange_hp_percent") / 100.0), 1.0)
	if health - cost < 1.0:
		_play_denied()
		return false
	health -= cost
	if is_instance_valid(health_bar):
		health_bar.take_damage(cost)
	seid = minf(seid + max_seid * skill("life_exchange_seid_percent") / 100.0, max_seid)
	_life_exchange_cd = skill("life_exchange_cooldown_seconds")
	flash_tint(Color(0.7, 1.0, 1.7, 1.0), 0.06, 0.3)
	SoundBank.play_at(get_tree(), "life_exchange", global_position, -8.0)
	return true


# ── Дар ушедших: убийство заклинанием возвращает часть его цены ──
## Цена последнего сорвавшегося заклинания — урон мага всегда от заклинаний,
## поэтому убийство засчитывается последнему из них
var _last_cast_cost := 0.0


## Враг погиб от мага (enemy.gd::_award_skill_points)
func on_enemy_killed(_enemy: Node) -> void:
	var pct := skill("seid_on_kill_percent")
	if pct > 0.0 and _last_cast_cost > 0.0:
		seid = minf(seid + _last_cast_cost * pct / 100.0, max_seid)


# ── Голос Эйрика (Levels/sound_bank.gd): боль и смерть ──
func receive_attack(attack_data: Dictionary) -> bool:
	var got: bool = super(attack_data)
	if got and not is_dead():
		SoundBank.play_at(get_tree(), "mage_hurt", global_position, -9.0)
	return got


func _die() -> void:
	super()
	SoundBank.play_at(get_tree(), "mage_death", global_position, -8.0)
