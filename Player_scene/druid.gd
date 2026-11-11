extends "res://Player_scene/character_base.gd"
## druid.gd — Сольвейг, друидесса: магия земли и природы. Дальний бой и
## контроль: связывает врагов корнями, чтобы их добили союзники (Хальвард и
## другие), лечит и укрывает корой. Вблизи — только удар посохом.
## Движение, перекат, урон и деревья навыков — в общей базе
## (character_base.gd), здесь только её собственное.
##
## Эффекты — в той же технике, что у Эйрика (шейдеры, частицы, свет), своя
## палитра — светло-зелёная (druid_fx.gd). Каждое заклинание — свой узел:
##   druid_seed.gd    — Шип-семя (снаряд)
##   druid_vine.gd    — Хлёст лозы
##   druid_thorns.gd  — Шипы из земли под целью
##   druid_roots.gd   — корни Оков на одном враге
##   druid_sprout.gd  — Росток жизни
##   druid_bark.gd    — щит Коры
## Враги, связанные корнями, стоят на месте: enemy.gd::apply_root.
##
## Вид — листы Character/Shaman_20261110_201203, клипы собирает
## tools/build_druid_anims.gd в druid_frames.tres / druid_anims.tres.
##
## РОСТ — её ресурс (зелёная шкала между здоровьем и выносливостью). Как
## Сейд мага: сам восполняется после паузы, быстрее — если не колдовать.
## Попадания заклинаниями и удар посохом добавляют сверху.
##
## Руны (панель — тот же mage_hud.gd, что у мага, без счётчика душ):
##   нижний ряд, Земля: ЛКМ — Шип-семя, ПКМ — Хлёст лозы,
##                      V — Шипы из земли, B — Оковы корней
##   верхний ряд, Жизнь: Q — Целебные споры, F — Росток жизни, X — Кора,
##                       Ctrl — Тропа мха (рывок)
##   без руны: G — удар посохом (и ЛКМ, когда на семя не хватает Роста)

const MageHudScript := preload("res://Player_scene/mage_hud.gd")
const IceFx := preload("res://Player_scene/mage_ice_fx.gd")
const DruidFx := preload("res://Player_scene/druid_fx.gd")
const SeedScript := preload("res://Player_scene/druid_seed.gd")
const VineScript := preload("res://Player_scene/druid_vine.gd")
const ThornsScript := preload("res://Player_scene/druid_thorns.gd")
const RootsScript := preload("res://Player_scene/druid_roots.gd")
const SproutScript := preload("res://Player_scene/druid_sprout.gd")
const BarkScript := preload("res://Player_scene/druid_bark.gd")
const SOUND_DENIED := preload("res://UI/ui_sounds.gd").ERROR
const HudScript := preload("res://Inventory/ui/hud.gd")
const QuickSlotScript := preload("res://Inventory/ui/quick_slot_ui.gd")
const InventoryUIScript := preload("res://Inventory/systems/inventory/inventory_ui.gd")

var character_id := "druid"
var ability_system: AbilitySystem
var inventory_system: InventorySystem
var talisman_system: TalismanSystem
var inventory_ui: CanvasLayer
var hud: CanvasLayer
var druid_hud: CanvasLayer

# ═════════════════ РОСТ ═════════════════

@export var max_growth := 100.0
@export var start_growth := 60.0
## Восполнение после паузы и в покое (не колдует growth_rest_time секунд)
@export var growth_regen := 7.0
@export var growth_regen_rested := 18.0
@export var growth_regen_delay := 0.8
@export var growth_rest_time := 2.0
## За каждое попадание заклинанием и за удар посохом
@export var growth_per_hit := 3.0
@export var growth_per_staff_hit := 8.0
const GROWTH_COLOR := Color(0.16, 0.36, 0.13)
const GROWTH_LACK_COLOR := Color(0.62, 1.0, 0.42)
const GROWTH_RUNE_FILL := Color(0.55, 0.92, 0.4)
var growth := 0.0
var _since_cast := 99.0

# ═════════════════ РУНЫ ═════════════════

enum { R_SEED, R_VINE, R_THORNS, R_BINDING, R_SPORES, R_SPROUT, R_BARK, R_MOSS }
## Руна -> действие ввода. 0-3 — из project.godot, 4-7 и посох заводит сама
const RUNE_ACTIONS := ["attack", "parry", "kick", "special",
		"druid_spores", "druid_sprout", "druid_bark", "druid_moss"]
const RUNE_KEYS := ["ЛКМ", "ПКМ", "V", "B", "Q", "F", "X", "Ctrl"]
const STAFF_ACTION := "druid_staff"
const DRUID_KEYS := [["druid_spores", KEY_Q], ["druid_sprout", KEY_F], ["druid_bark", KEY_X],
		["druid_moss", KEY_CTRL], ["druid_staff", KEY_G]]
const DRUID_BUFFERED := ["attack", "ui_accept", "parry", "kick", "special",
		"druid_spores", "druid_sprout", "druid_bark", "druid_moss", "druid_staff"]
## Руны — черты в квадрате 0..1. Земля: Ингуз (семя), Йера (лоза-завиток),
## Турисаз (шип), Наутиз (путы). Жизнь: Беркана (берёза), Лагуз (рост),
## Альгиз (защита), Эваз (путь)
const RUNE_GLYPHS := [
	[[Vector2(0.5, 0.08), Vector2(0.84, 0.5), Vector2(0.5, 0.92), Vector2(0.16, 0.5), Vector2(0.5, 0.08)]],
	[[Vector2(0.44, 0.1), Vector2(0.16, 0.36), Vector2(0.44, 0.62)],
			[Vector2(0.56, 0.38), Vector2(0.84, 0.64), Vector2(0.56, 0.9)]],
	[[Vector2(0.32, 0.06), Vector2(0.32, 0.94)], [Vector2(0.32, 0.28), Vector2(0.72, 0.5), Vector2(0.32, 0.72)]],
	[[Vector2(0.5, 0.06), Vector2(0.5, 0.94)], [Vector2(0.24, 0.34), Vector2(0.76, 0.6)]],
	[[Vector2(0.3, 0.06), Vector2(0.3, 0.94)], [Vector2(0.3, 0.06), Vector2(0.72, 0.28), Vector2(0.3, 0.5),
			Vector2(0.72, 0.72), Vector2(0.3, 0.94)]],
	[[Vector2(0.36, 0.94), Vector2(0.36, 0.06), Vector2(0.72, 0.36)]],
	[[Vector2(0.5, 0.94), Vector2(0.5, 0.06)], [Vector2(0.5, 0.46), Vector2(0.16, 0.1)],
			[Vector2(0.5, 0.46), Vector2(0.84, 0.1)]],
	[[Vector2(0.2, 0.94), Vector2(0.2, 0.06), Vector2(0.5, 0.42), Vector2(0.8, 0.06), Vector2(0.8, 0.94)]],
]

## Цены рун в Росте
@export var seed_cost := 6.0
@export var vine_cost := 14.0
@export var thorns_cost := 22.0
@export var binding_cost := 34.0
@export var spores_cost := 18.0
@export var sprout_cost := 30.0
@export var bark_cost := 22.0
@export var moss_cost := 10.0

## Какая руна колдуется сейчас (подсветка на панели), -1 — никакая
var _casting_rune := -1

## Перезарядка. Сольвейг — не боевой маг: урон у неё маленький, и бьёт она
## не очередью. После любого приёма — общая пауза cast_cooldown (нажатое в
## паузу не теряется, а срабатывает, как только она кончится), а у каждой
## руны ещё своя перезарядка (по порядку рун: семя, лоза, шипы, Оковы, споры,
## росток, кора, тропа мха). Видна на рунной панели тенью и таймером
@export var cast_cooldown := 0.6
@export var rune_cooldowns: Array[float] = [1.2, 4.0, 6.0, 12.0, 8.0, 15.0, 12.0, 2.0]
@export var staff_cooldown := 0.8
var _cd: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _global_cd := 0.0
var _staff_cd := 0.0

# ═════════════════ ЗЕМЛЯ ═════════════════

## Урон у неё маленький: она связывает и держит, добивают другие. Лоза и
## Оковы не ранят совсем — только стойкость и хватка

## ЛКМ — Шип-семя: снаряд, срывается с ладони на этом кадре клипа
@export var seed_damage := 1
@export var seed_cast_frame := 6.0
@export var seed_speed := 320.0

## G — удар посохом (без Роста)
@export var staff_damage := 1
@export var staff_hit_frame := 7.0
@export var staff_range := 46.0
@export var staff_cone_deg := 65.0
@export var staff_posture := 18.0
@export var staff_push := 160.0

## ПКМ — Хлёст лозы: досягаемость, хватка корнями после рывка
@export var vine_damage := 0
@export var vine_cast_frame := 8.0
@export var vine_reach := 150.0
@export var vine_cone_deg := 30.0
@export var vine_posture := 25.0
@export var vine_pull := 210.0
@export var vine_root_time := 1.0

## V — Шипы из земли под ближайшими целями
@export var thorns_damage := 1
@export var thorns_posture := 15.0
@export var thorns_radius := 220.0
@export var thorns_max_targets := 3
@export var thorns_mark_frame := 2.0
@export var thorns_erupt_frame := 8.5

## B — Оковы корней: все враги вокруг (до max) стоят hold секунд
@export var binding_radius := 180.0
@export var binding_max_targets := 6
@export var binding_hold := 3.0
@export var binding_damage := 0
@export var binding_posture := 20.0
## Кадры листа Special1: 2 — проступают круги, 8.5 — посох бьёт в землю и
## корни вырываются, 11 — руки ввысь, свет
@export var binding_mark_frame := 2.0
@export var binding_erupt_frame := 8.5
@export var binding_hands_frame := 11.0
## Корни вырываются волной от ближних к дальним
@export var binding_stagger := 0.06

# ═════════════════ ЖИЗНЬ ═════════════════

## Q — Целебные споры: лечение (в соло — себя; союзника — когда будет кооп)
@export var spores_frame := 7.0
@export var spores_heal_percent := 15.0

## F — Росток жизни
@export var sprout_frame := 7.0
@export var sprout_time := 8.0
@export var sprout_radius := 70.0
@export var sprout_heal_percent := 3.0

## X — Кора: щит, поглощающий урон
@export var bark_frame := 5.0
@export var bark_absorb := 25.0
@export var bark_time := 10.0

## Ctrl — Тропа мха: рывок скольжением, короткая неуязвимость
@export var moss_speed := 420.0
@export var moss_time := 0.32
@export var moss_iframes := 0.28

var _bark := 0.0
var _bark_max := 1.0
var _bark_left := 0.0
var _bark_fx: Node2D
var _moss_left := 0.0
var _moss_dir := Vector2.ZERO
var _moss_trail_t := 0.0
## Пока Сольвейг поднимает руки для Оков — удар её не сбивает
var _binding_armor := false


func _ready() -> void:
	super()
	add_to_group("caster_player")
	growth = start_growth
	if is_instance_valid(health_bar):
		health_bar.enable_odr(GROWTH_COLOR, GROWTH_LACK_COLOR)
	# Рунная панель — раньше инвентаря: открытый инвентарь ляжет поверх
	druid_hud = MageHudScript.new()
	druid_hud.name = "DruidHUD"
	druid_hud.show_souls = false
	druid_hud.rune_fill_color = GROWTH_RUNE_FILL
	add_child(druid_hud)
	_setup_inventory()
	_ensure_druid_actions()
	var runes := []
	for i in RUNE_GLYPHS.size():
		runes.append({"key": RUNE_KEYS[i], "cost": rune_cost(i), "glyph": RUNE_GLYPHS[i]})
	# Правее — быстрый слот предметов (как у мага, mage.gd::RUNES_RIGHT)
	druid_hud.build_runes(runes, 75.0 + 124.0 + 28.0, 4)


func _process(delta: float) -> void:
	super(delta)
	_since_cast += delta
	if _since_cast > growth_regen_delay:
		var rate := growth_regen_rested if _since_cast > growth_rest_time else growth_regen
		growth = minf(growth + rate * delta, max_growth)
	if _bark_left > 0.0:
		_bark_left -= delta
		if _bark_left <= 0.0:
			_bark = 0.0
			_end_bark_fx(false)
	if is_instance_valid(_bark_fx):
		_bark_fx.strength = clampf(_bark / maxf(_bark_max, 0.01), 0.0, 1.0)
	_global_cd = maxf(_global_cd - delta, 0.0)
	_staff_cd = maxf(_staff_cd - delta, 0.0)
	for i in _cd.size():
		_cd[i] = maxf(_cd[i] - delta, 0.0)
	if _revive_left > 0.0:
		_revive_step(delta)
	if not is_attacking:
		_casting_rune = -1
		_binding_armor = false
	if is_instance_valid(health_bar):
		health_bar.set_odr(growth, max_growth)
	if is_instance_valid(druid_hud):
		druid_hud.update_runes(growth, _casting_rune, _all_costs(), _all_cooldowns())


func _physics_process(delta: float) -> void:
	# Тропа мха перехватывает движение целиком, пока длится рывок
	if _moss_left > 0.0 and not is_dead():
		_moss_left -= delta
		var k := clampf(_moss_left / maxf(_moss_time_total(), 0.01), 0.0, 1.0)
		velocity = _moss_dir * moss_speed * (0.35 + 0.65 * k)
		move_and_slide()
		_moss_trail_t -= delta
		if _moss_trail_t <= 0.0:
			_moss_trail_t = 0.035
			_moss_trail_puff()
		if _moss_left <= 0.0:
			_attack_recovery = true
		return
	super(delta)


# ═════════════════ СУМКА И ВВОД ═════════════════

## Сумка, быстрый слот и инвентарь — как у лучницы и мага. Валюта — золото
## (общий счётчик HUD остаётся видимым)
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
	var mead := HoneyMeadAbility.new()
	inventory_ui.add_item(mead)
	ability_system.add_ability(mead)


## Esc — инвентарь, колесо — слоты, R — выпить (как у лучницы и мага)
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


func _ensure_druid_actions() -> void:
	for pair in DRUID_KEYS:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev)


func _buffered_actions() -> Array:
	return DRUID_BUFFERED


## Руны — отдельные кнопки, как у мага (mage.gd::handle_attack_input): каждая
## стоит Роста, повторное нажатие во время каста в очередь не ставится.
## Нажато несколько разом — верхний ряд первым
func handle_attack_input() -> void:
	var rune := -1
	for r in [R_MOSS, R_BARK, R_SPROUT, R_SPORES, R_BINDING, R_THORNS, R_VINE, R_SEED]:
		if _pressed(RUNE_ACTIONS[r]):
			rune = r
			break
	var staff := _pressed(STAFF_ACTION)
	if rune < 0 and not staff:
		return
	# Прошлый приём уже «отыгран» — новый можно начинать, не дожидаясь конца клипа
	if is_attacking and not _attack_recovery:
		return
	# Общая пауза между приёмами: нажатие не съедаем — оно в буфере ввода и
	# сработает, как только пауза кончится
	if _global_cd > 0.0:
		return
	if rune < 0:
		if _staff_cd > 0.0:
			return
		_consume(STAFF_ACTION)
		_start_staff()
		return
	_consume(RUNE_ACTIONS[rune])
	# Своя перезарядка руны ещё идёт — отказ
	if _cd[rune] > 0.0:
		if is_instance_valid(druid_hud):
			druid_hud.rune_denied(rune)
		_play_denied()
		return
	var cost := rune_cost(rune)
	if growth < cost:
		if is_instance_valid(health_bar):
			health_bar.blink_odr()
		if is_instance_valid(druid_hud):
			druid_hud.rune_denied(rune)
		# Не хватило на семя — не стоит столбом, а бьёт посохом
		if rune == R_SEED and _staff_cd <= 0.0:
			_start_staff()
		else:
			_play_denied()
		return
	if is_attacking:
		_cancel_attack()
	growth -= cost
	_since_cast = 0.0
	_cd[rune] = rune_cooldowns[rune] if rune < rune_cooldowns.size() else 0.0
	_global_cd = cast_cooldown
	_casting_rune = rune
	if is_instance_valid(druid_hud):
		druid_hud.rune_cast(rune)
	match rune:
		R_SEED:
			if is_running and input_vector != Vector2.ZERO:
				start_run_attack()
			else:
				start_attack(1)
		R_VINE: _start_vine()
		R_THORNS: _start_thorns()
		R_BINDING: _start_binding()
		R_SPORES: _start_spores()
		R_SPROUT: _start_sprout()
		R_BARK: _start_bark()
		R_MOSS: _start_moss()


## Цена руны в Росте с навыками (Лёгкие споры, Живучий цветок, Корни пьют).
## Не дешевле трети — заклинания не становятся бесплатными
func rune_cost(rune: int) -> float:
	var base: float = [seed_cost, vine_cost, thorns_cost, binding_cost, spores_cost,
			sprout_cost, bark_cost, moss_cost][rune]
	var pct := 0.0
	match rune:
		R_SPORES: pct += skill("spores_cost_percent")
		R_SPROUT: pct += skill("sprout_cost_percent")
		R_BINDING: pct += skill("binding_cost_percent")
	return maxf(roundf(base * maxf(1.0 + pct / 100.0, 0.3)), 1.0)


func _all_costs() -> Array:
	var out := []
	for i in RUNE_ACTIONS.size():
		out.append(rune_cost(i))
	return out


## Для рунной панели: [осталось, всего] у каждой руны. Общая пауза тоже
## видна — на рунах, чья своя перезарядка уже прошла
func _all_cooldowns() -> Array:
	var out := []
	for i in _cd.size():
		var total: float = rune_cooldowns[i] if i < rune_cooldowns.size() else 0.0
		if _cd[i] >= _global_cd:
			out.append([_cd[i], total])
		else:
			out.append([_global_cd, cast_cooldown])
	return out


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


func _add_growth(amount: float) -> void:
	growth = minf(growth + amount * (1.0 + skill("growth_gain_percent") / 100.0), max_growth)


## Семя попало (druid_seed.gd зовёт)
func _on_seed_hit(_enemy: Node2D) -> void:
	_add_growth(growth_per_hit)


func _earth_damage(base: int, extra_pct := 0.0) -> int:
	return SkillTrees.scale_int(base, skill("earth_damage_percent") + extra_pct)


# ═════════════════ ШИП-СЕМЯ (ЛКМ) ═════════════════

## База зовёт после запуска клипа: step 1 — стоя (Attack_), 0 — на бегу
func _on_attack_started(_step: int, aim: Node2D) -> void:
	var clip := String(anim.current_animation)
	await get_tree().create_timer(seed_cast_frame * _clip_frame_time(clip)).timeout
	if is_dead() or not is_attacking or not _same_attack(clip):
		return
	var dir: Vector2
	if is_instance_valid(aim) and aim.get("is_dead") != true:
		dir = (aim.global_position + Vector2(0, -10) - _hand_point()).normalized()
	else:
		dir = facing_dir if facing_dir != Vector2.ZERO else Vector2.DOWN
	var s: Area2D = SeedScript.new()
	s.speed = seed_speed
	s.damage = _earth_damage(seed_damage, skill("seed_damage_percent"))
	_scene_root().add_child(s)
	s.launch(_hand_point(), dir, self)
	# Кооп: у остальных летит такое же семя, без урона (Net.echo)
	Net.echo(s, "launch", [_hand_point(), dir, self], {"speed": seed_speed})
	SoundBank.play_at(get_tree(), "knight_swing", global_position, -14.0, 1.4)
	_recover_at(clip, 2.5)


# ═════════════════ УДАР ПОСОХОМ (G) ═════════════════

func _start_staff() -> void:
	if is_attacking:
		_cancel_attack()
	var clip := _start_move("Staff_")
	if clip == "":
		return
	_casting_rune = -1
	_staff_cd = staff_cooldown
	_global_cd = cast_cooldown
	attack_step(facing_dir * 110.0)
	SoundBank.play_at(get_tree(), "knight_swing", global_position, -10.0, 1.15)
	await get_tree().create_timer(staff_hit_frame * _clip_frame_time(clip)).timeout
	if is_dead() or not is_attacking or not _same_attack(clip):
		return
	var dmg := SkillTrees.scale_int(staff_damage, skill("staff_damage_percent"))
	var hits := _melee_hit(staff_range, staff_cone_deg, dmg, staff_posture, staff_push)
	var tip := global_position + _feet() + facing_dir * 26.0
	SkidDust.skid(get_tree(), tip, facing_dir, SkidDust.Kind.STOP, 0.7)
	var h := DruidFx.holder(get_tree(), tip + Vector2(0, -12), 0.8, 11)
	DruidFx.sparks(h, 6, 90.0, 0.3, facing_dir, 50.0)
	DruidFx.leaves(h, 3, 60.0, 0.6, facing_dir, 60.0)
	if hits > 0:
		_add_growth(growth_per_staff_hit * hits)
		SoundBank.play_at(get_tree(), "knight_hit_light", tip, -6.0, 1.1)
	_recover_at(clip, 3.0)


## Удар вблизи конусом перед собой: урон (0 — без урона), стойкость, отброс.
## Возвращает, скольких задело
func _melee_hit(reach: float, cone_deg: float, dmg: int, posture: float, push: float) -> int:
	var origin := global_position + _feet()
	var min_dot := cos(deg_to_rad(cone_deg))
	var hits := 0
	for e in IceFx.targets(get_tree()):
		var f := IceFx.feet(e)
		var to := f - origin
		var d := IceFx.ground_dist(origin, f, 0.8)
		if d > reach:
			continue
		if d > 10.0 and to.normalized().dot(facing_dir) < min_dot:
			continue
		hits += 1
		var dir := to.normalized() if to.length() > 0.5 else facing_dir
		if "player" in e and e.player == null:
			e.player = self
		if dmg > 0:
			e.take_damage(dmg, self)
		if is_instance_valid(e) and e.has_method("take_posture_damage"):
			e.take_posture_damage(posture)
		if is_instance_valid(e) and "knockback_velocity" in e and e.get("is_dead") != true:
			e.knockback_velocity = dir * push
		if is_instance_valid(e):
			DruidFx.hit_burst(get_tree(), e.global_position, dir)
	return hits


# ═════════════════ ХЛЁСТ ЛОЗЫ (ПКМ) ═════════════════

func _start_vine() -> void:
	var target := _vine_target()
	_turn_to_aim(target)
	var clip := _start_move("Vine_", false)
	if clip == "":
		return
	await get_tree().create_timer(vine_cast_frame * _clip_frame_time(clip)).timeout
	if is_dead() or not is_attacking or not _same_attack(clip):
		return
	if is_instance_valid(target) and (target.get("is_dead") == true or _too_far(target, vine_reach)):
		target = null
	var v: Node2D = VineScript.new()
	v.reach = vine_reach
	v.damage = _earth_damage(vine_damage)
	v.posture = vine_posture * (1.0 + skill("vine_posture_percent") / 100.0)
	v.pull = vine_pull
	v.root_time = vine_root_time + skill("vine_root_seconds")
	v.setup(self, _hand_point(), facing_dir, target)
	_scene_root().add_child(v)
	Net.echo(v, "setup", [self, _hand_point(), facing_dir, target], {"reach": vine_reach})
	if is_instance_valid(target):
		_add_growth(growth_per_hit)
	SoundBank.play_at(get_tree(), "roots", global_position, -8.0, 1.25)
	_recover_at(clip, 3.0)


## Цель лозы: фокус или ближайший враг в узком конусе по взгляду/прицелу
func _vine_target() -> Node2D:
	if _focus.has_target() and not _too_far(_focus.target, vine_reach):
		return _focus.target
	var dir := _aim_dir()
	if dir == Vector2.ZERO:
		dir = facing_dir
	var min_dot := cos(deg_to_rad(vine_cone_deg))
	var best: Node2D = null
	var best_d := vine_reach
	for e in IceFx.targets(get_tree()):
		if not e.is_in_group("enemy"):
			continue
		var to: Vector2 = e.global_position - global_position
		var d := to.length()
		if d > best_d or d < 1.0 or to.normalized().dot(dir) < min_dot:
			continue
		best_d = d
		best = e
	return best


func _too_far(e: Node2D, reach: float) -> bool:
	return not is_instance_valid(e) or global_position.distance_to(e.global_position) > reach + 10.0


# ═════════════════ ШИПЫ ИЗ ЗЕМЛИ (V) ═════════════════

func _start_thorns() -> void:
	var targets := _targets_around(thorns_radius, thorns_max_targets)
	_turn_to_aim(targets[0] if not targets.is_empty() else _pick_aim())
	var clip := _start_move("Spikes_", false)
	if clip == "":
		return
	var frame := _clip_frame_time(clip)
	await get_tree().create_timer(thorns_mark_frame * frame).timeout
	if is_dead() or not _same_attack(clip):
		return
	var delay := maxf(thorns_erupt_frame - thorns_mark_frame, 0.0) * frame
	var dmg := _earth_damage(thorns_damage, skill("spikes_damage_percent"))
	var spawned := 0
	for e in targets:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		_spawn_thorns(e, _ground_offset(e), Vector2.ZERO, delay + spawned * 0.08, dmg)
		spawned += 1
	if spawned == 0:
		var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.DOWN
		_spawn_thorns(null, Vector2.ZERO, global_position + _feet() + dir * 70.0, delay, dmg)
	await get_tree().create_timer(delay).timeout
	if is_dead():
		return
	shake_camera(3.0, 0.2)
	SoundBank.play_at(get_tree(), "roots", global_position, -4.0, 0.9)
	_add_growth(growth_per_hit * spawned)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


func _spawn_thorns(target: Node2D, offset: Vector2, at: Vector2, delay: float, dmg: int) -> void:
	var t: Node2D = ThornsScript.new()
	t.damage = dmg
	t.posture = thorns_posture
	t.bleed_chance = skill("spikes_bleed_chance_percent")
	t.setup(self, target, offset, at, delay)
	_scene_root().add_child(t)
	Net.echo(t, "setup", [self, target, offset, at, delay])


# ═════════════════ ОКОВЫ КОРНЕЙ (B) ═════════════════

## Поднимает посох, бьёт им в землю — и из-под всех врагов вокруг вырываются
## корни, держат их на месте (enemy.apply_root). Руки ввысь — вспышка света
func _start_binding() -> void:
	var targets := _targets_around(binding_radius, binding_max_targets)
	var clip := _start_move("Binding_", false)
	if clip == "":
		return
	_binding_armor = true
	var frame := _clip_frame_time(clip)
	var feet := global_position + _feet()
	# Под ней самой — большой круг, пока она собирает силу
	var self_fx := DruidFx.holder(get_tree(), feet, binding_hands_frame * frame + 1.6, 11)
	var circle := DruidFx.circle(self_fx, 110.0, 0.9)
	var ct := self_fx.create_tween()
	ct.tween_method(func(v: float): circle.set_shader_parameter("draw", v), 0.0, 1.0, binding_erupt_frame * frame)
	ct.tween_interval(0.5)
	ct.tween_method(func(v: float): circle.set_shader_parameter("fade", v), 1.0, 0.0, 0.8)
	var glow := DruidFx.light(self_fx, 60.0, 0.0)
	self_fx.create_tween().tween_property(glow, "energy", 1.2, binding_erupt_frame * frame)

	await get_tree().create_timer(binding_mark_frame * frame).timeout
	if is_dead() or not _same_attack(clip):
		return
	var hold := binding_hold * (1.0 + skill("binding_duration_percent") / 100.0)
	var delay := maxf(binding_erupt_frame - binding_mark_frame, 0.0) * frame
	var bound := 0
	for e in targets:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var r: Node2D = RootsScript.new()
		r.hold_time = hold
		r.damage = _earth_damage(binding_damage)
		r.posture = binding_posture
		r.setup(self, e, _ground_offset(e), delay + bound * binding_stagger)
		_scene_root().add_child(r)
		Net.echo(r, "setup", [self, e, _ground_offset(e), delay + bound * binding_stagger], {"hold_time": hold})
		bound += 1

	await get_tree().create_timer(delay).timeout
	if is_dead():
		return
	# Посох в землю: волна по земле, комья, листья, тряска
	# Вспышка — зелёная и у земли, не белая на всё тело: героиню не засвечивает
	DruidFx.flash(self_fx, 46.0, 0.2, DruidFx.MID)
	DruidFx.dirt(self_fx, 16, 160.0, 0.6)
	DruidFx.leaves(self_fx, 12, 140.0, 1.0)
	DruidFx.haze(self_fx, 8, 30.0, 60.0, 1.0)
	DruidFx.light_pulse(self_fx, 140.0, 1.6, 0.7)
	glow.create_tween().tween_property(glow, "energy", 0.0, 0.9)
	shake_camera(4.0, 0.3)
	SoundBank.play_at(get_tree(), "roots", global_position, -2.0, 0.85)
	_add_growth(skill("binding_growth_per_target") * bound)
	_binding_armor = false

	await get_tree().create_timer(maxf(binding_hands_frame - binding_erupt_frame, 0.0) * frame).timeout
	if is_dead() or not _same_attack(clip):
		return
	# Руки ввысь — над головой вспыхивает свет и поднимается пыльца
	var hands := DruidFx.holder(get_tree(), global_position + _body() + Vector2(0, -22), 2.0, 12)
	DruidFx.flash(hands, 30.0, 0.25, DruidFx.MID)
	DruidFx.light_pulse(hands, 110.0, 2.0, 0.8)
	DruidFx.pollen(hands, 26, 14.0, 1.6, 46.0)
	DruidFx.sparks(hands, 12, 160.0, 0.5, Vector2.UP, 70.0)
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


func _has_hyper_armor() -> bool:
	return _binding_armor and is_attacking


# ═════════════════ ЖИЗНЬ ═════════════════

## Q — Целебные споры. Пока лечат саму Сольвейг; союзника (кооп) — потом
func _start_spores() -> void:
	# Рядом павший союзник (кооп) — споры поднимают его, а не лечат
	var fallen := _fallen_ally_near()
	if fallen != null:
		_start_revive(fallen)
		return
	var clip := _start_move("Spores_", false)
	if clip == "":
		return
	var hand := DruidFx.holder(get_tree(), _hand_point(), 1.0, 12)
	DruidFx.pollen(hand, 10, 6.0, 0.6, 20.0)
	DruidFx.light_pulse(hand, 40.0, 1.0, 0.5)
	await get_tree().create_timer(spores_frame * _clip_frame_time(clip)).timeout
	if is_dead() or not is_attacking or not _same_attack(clip):
		return
	# Самый раненый рядом — она сама или союзник (кооп)
	var target: Node2D = _most_wounded_near()
	_spores_fx(target)
	_heal_target(target, max_health * spores_heal_percent / 100.0)
	# Чистая роса
	if skill("spores_cleanse") > 0.0:
		if target == self:
			clear_negative_effects()
		else:
			Net.to_owner(target.peer_id, "clear_negative_effects", [])
	# Долгое цветение — регенерация после спор
	var regen_pct := skill("spores_regen_percent")
	if regen_pct > 0.0:
		_regen(target, regen_pct, skill("spores_regen_seconds"))
	_recover_at(clip, 3.0)


## Облако спор у ног (druid_fx.gd::spores_burst) — и у других игроков (кооп)
func _spores_fx(target: Node2D) -> void:
	var feet := target.global_position + (_feet() if target == self else Vector2(0, 24))
	DruidFx.spores_burst(get_tree(), feet)
	Net.echo_static("res://Player_scene/druid_fx.gd", "spores_burst", [get_tree(), feet])


## F — Росток жизни под ногами
func _start_sprout() -> void:
	var clip := _start_move("Sprout_", false)
	if clip == "":
		return
	await get_tree().create_timer(sprout_frame * _clip_frame_time(clip)).timeout
	if is_dead() or not is_attacking or not _same_attack(clip):
		return
	var s: Node2D = SproutScript.new()
	s.druid = self
	s.radius = sprout_radius
	s.life = sprout_time * (1.0 + skill("sprout_duration_percent") / 100.0)
	s.heal_percent = sprout_heal_percent
	s.slow_percent = skill("sprout_slow_percent")
	_scene_root().add_child(s)
	s.global_position = global_position + _feet()
	Net.echo(s, "", [], {"radius": s.radius, "life": s.life, "position": s.global_position})
	SoundBank.play_at(get_tree(), "roots", global_position, -10.0, 1.3)
	_recover_at(clip, 3.0)


## X — Кора. Пока на себя; на союзника — когда будет кооп
func _start_bark() -> void:
	var clip := _start_move("Bark_", false)
	if clip == "":
		return
	await get_tree().create_timer(bark_frame * _clip_frame_time(clip)).timeout
	if is_dead() or not is_attacking or not _same_attack(clip):
		return
	var absorb := bark_absorb * (1.0 + skill("bark_absorb_percent") / 100.0)
	# Кооп: союзник под прицелом — кора на него (щит у его героя,
	# Net/ally_shield.gd), иначе — на себя
	var ally := _bark_ally()
	if ally != null:
		Net.to_owner(ally.peer_id, "apply_ally_shield", [absorb, bark_time])
		var h := DruidFx.holder(get_tree(), ally.global_position + Vector2(0, -6), 0.8, 12)
		DruidFx.flash(h, 30.0, 0.18, DruidFx.BARK)
		DruidFx.leaves(h, 6, 60.0, 0.7)
		DruidFx.light_pulse(h, 50.0, 1.4, 0.35)
		SoundBank.play_at(get_tree(), "knight_armor", ally.global_position, -8.0, 1.2)
		_recover_at(clip, 4.0)
		return
	_bark_max = absorb
	_bark = _bark_max
	_bark_left = bark_time
	_ensure_bark_fx()
	SoundBank.play_at(get_tree(), "knight_armor", global_position, -8.0, 1.2)
	_recover_at(clip, 4.0)


func _ensure_bark_fx() -> void:
	if is_instance_valid(_bark_fx):
		return
	_bark_fx = BarkScript.new()
	_bark_fx.center = _body()
	add_child(_bark_fx)
	# Кооп: у других игроков вокруг куклы — такой же щит, тает по времени
	Net.echo(_bark_fx, "", [], {"center": _body(), "auto_fade": maxf(_bark_left, 1.0)}, true)


func _end_bark_fx(broken: bool) -> void:
	if not is_instance_valid(_bark_fx):
		return
	if broken:
		_bark_fx.shatter()
	else:
		_bark_fx.fade()
	_bark_fx = null


## Ctrl — Тропа мха: рывок туда, куда жмут (или куда смотрит)
func _start_moss() -> void:
	var dir := _aim_dir()
	if dir == Vector2.ZERO:
		dir = facing_dir if facing_dir != Vector2.ZERO else Vector2.DOWN
	facing_dir = dir
	last_direction = get_direction(dir)
	var clip := _start_move("Slide_", false)
	if clip == "":
		return
	_moss_dir = dir
	_moss_left = _moss_time_total()
	_moss_trail_t = 0.0
	is_invulnerable = true
	_invuln_timer = maxf(_invuln_timer, moss_iframes)
	SkidDust.skid(get_tree(), global_position + _feet(), dir, SkidDust.Kind.START, 1.0)
	var h := DruidFx.holder(get_tree(), global_position + _body(), 0.8, 12)
	DruidFx.flash(h, 24.0, 0.14)
	DruidFx.light_pulse(h, 50.0, 1.2, 0.3)


## След рывка: клочья светящегося мха и листья под ногами
func _moss_trail_puff() -> void:
	var h := DruidFx.holder(get_tree(), global_position + _feet(), 1.2, 11)
	DruidFx.pollen(h, 3, 4.0, 0.8, 14.0)
	if randf() < 0.5:
		DruidFx.leaves(h, 1, 30.0, 0.8)


## Лесная поступь удлиняет рывок
func _moss_time_total() -> float:
	return moss_time * (1.0 + skill("moss_trail_length_percent") / 100.0)


## Лечение заклинанием (не зельем — consumable_heal_percent тут не при чём).
## Цель — сама Сольвейг или союзник (Росток жизни лечит всех в группе
## "player"). Лишнее над максимумом у неё самой — щит Избытка сока
func _heal_target(target: Node, amount: float) -> void:
	if not is_instance_valid(target):
		return
	var pct := skill("heal_power_percent")
	if target == self:
		pct += skill("self_heal_percent")
	amount *= 1.0 + pct / 100.0
	if target != self:
		if target.has_method("heal"):
			target.heal(amount)
		return
	if is_dead():
		return
	var over := health + amount - max_health
	health = minf(health + amount, max_health)
	if is_instance_valid(health_bar):
		health_bar.heal(amount)
	flash_tint(Color(0.75, 1.5, 0.7, 1.0))
	if over > 0.0 and skill("overheal_shield_enabled") > 0.0:
		var cap := max_health * skill("overheal_shield_max_percent") / 100.0
		_bark = minf(_bark + over, maxf(cap, _bark))
		_bark_max = maxf(_bark_max, _bark)
		_bark_left = maxf(_bark_left, skill("overheal_shield_seconds"))
		_ensure_bark_fx()


## Регенерация: pct% максимального здоровья цели в секунду, seconds секунд
func _regen(target: Node, pct: float, seconds: float) -> void:
	var ticks := int(ceilf(seconds))
	for i in ticks:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(target) or not is_instance_valid(self) or is_dead():
			return
		var max_hp: float = float(target.get("max_health")) if target.get("max_health") != null else 100.0
		_heal_target(target, max_hp * pct / 100.0)


# ═════════════════ УРОН ПО НЕЙ ═════════════════

## Кора принимает удар первой: съедает урон, пока не кончится. Целиком
## поглощённый удар — без реакции и отлёта
func receive_attack(attack_data: Dictionary) -> bool:
	if is_dead() or is_invulnerable or _roll_invulnerable():
		return false
	if _bark > 0.0:
		var mult := maxf(_incoming_damage_mult(attack_data), 0.01)
		var amount: float = float(attack_data.get("damage", 0)) * mult
		var absorbed := minf(_bark, amount)
		_bark -= absorbed
		if _bark <= 0.0:
			_on_bark_broken()
		elif is_instance_valid(_bark_fx):
			var h := DruidFx.holder(get_tree(), global_position + _body(), 0.8, 12)
			DruidFx.leaves(h, 3, 60.0, 0.6)
		if amount - absorbed <= 0.01:
			_flash_hit()
			shake_camera(2.0)
			is_invulnerable = true
			_invuln_timer = post_hit_invulnerability
			return true
		var rest := attack_data.duplicate()
		rest["damage"] = (amount - absorbed) / mult
		var got_rest := super(rest)
		_try_second_breath()
		return got_rest
	var got := super(attack_data)
	_try_second_breath()
	return got


## Кора сломана ударом. Весна под снегом — немного лечит
func _on_bark_broken() -> void:
	_bark = 0.0
	_bark_left = 0.0
	_end_bark_fx(true)
	var heal_pct := skill("bark_break_heal_percent")
	if heal_pct > 0.0:
		_heal_target(self, max_health * heal_pct / 100.0)


func _cancel_attack() -> void:
	super()
	_moss_left = 0.0
	_binding_armor = false


func _die() -> void:
	_moss_left = 0.0
	_bark = 0.0
	_end_bark_fx(false)
	super()


# ═════════════════ СОЮЗНИКИ (КООП) ═════════════════
# Другие игроки на её экране — куклы (Net/net_puppet.gd). Лечение и кора
# уходят их хозяевам (Net.to_owner), там их настоящий герой лечится или
# получает щит (Net/ally_shield.gd). Павшего союзника она поднимает на месте.

## Споры лечат самого раненого в этом радиусе — её или союзника
@export var ally_spores_range := 180.0
## Кора ложится на союзника, на которого она смотрит (конус), в этом радиусе
@export var ally_bark_range := 200.0
@export var ally_bark_cone_deg := 40.0
## Подъём павшего: стоять рядом, Q — она на колене revive_time секунд
@export var revive_range := 60.0
@export var revive_time := 4.0
@export var revive_hp_percent := 20.0

var _revive_target: Node2D
var _revive_left := 0.0
var _revive_total := 1.0
var _revive_fx: Node2D
var _revive_circle: ShaderMaterial
var _revive_light: PointLight2D
## Второе дыхание (финал «Зелёного сердца») уже спасло её — до отдыха у
## костра больше не спасёт (bonfire.gd::restore_hero сбрасывает)
var second_breath_used := false


func _allies() -> Array:
	return get_tree().get_nodes_in_group("net_puppet") if Net.is_online() else []


func _fallen_ally_near() -> Node2D:
	var best: Node2D = null
	var bd := revive_range
	for p in _allies():
		if not p.is_dead():
			continue
		var d: float = p.global_position.distance_to(global_position)
		if d <= bd:
			bd = d
			best = p
	return best


## Самый раненый (по доле здоровья) рядом — она сама или союзник
func _most_wounded_near() -> Node2D:
	var best: Node2D = self
	var best_frac := health / maxf(max_health, 1.0)
	for p in _allies():
		if p.is_dead() or p.global_position.distance_to(global_position) > ally_spores_range:
			continue
		if float(p.hp_frac) < best_frac - 0.01:
			best_frac = float(p.hp_frac)
			best = p
	return best


## Союзник, на которого она смотрит (или в фокусе), для Коры; нет — null
func _bark_ally() -> Node2D:
	var dir := _aim_dir()
	if dir == Vector2.ZERO:
		dir = facing_dir
	var min_dot := cos(deg_to_rad(ally_bark_cone_deg))
	var best: Node2D = null
	var bd := ally_bark_range
	for p in _allies():
		if p.is_dead():
			continue
		var to: Vector2 = p.global_position - global_position
		var d := to.length()
		if d > bd or d < 1.0 or to.normalized().dot(dir) < min_dot:
			continue
		bd = d
		best = p
	return best


## Подъём павшего: на колене рядом с ним, под ним растёт круг и свет. Удар по
## ней, перекат или смерть союзника по другой причине — подъём срывается
func _start_revive(ally: Node2D) -> void:
	_turn_to_aim(ally)
	var clip := _start_move("Bark_", false)
	if clip == "":
		return
	_revive_target = ally
	_revive_total = revive_time * maxf(1.0 + skill("revive_time_percent") / 100.0, 0.2)
	_revive_left = _revive_total
	_revive_fx = DruidFx.holder(get_tree(), ally.global_position + Vector2(0, 24), _revive_total + 2.0, 11)
	_revive_circle = DruidFx.circle(_revive_fx, 64.0, 1.4)
	_revive_light = DruidFx.light(_revive_fx, 60.0, 0.0)
	DruidFx.pollen(_revive_fx, 12, 10.0, 1.0, 20.0)
	SoundBank.play_at(get_tree(), "roots", global_position, -10.0, 1.4)


func _revive_step(delta: float) -> void:
	if is_dead() or not is_attacking or not is_instance_valid(_revive_target) or not _revive_target.is_dead():
		_revive_stop(false)
		return
	_revive_left -= delta
	var k := 1.0 - clampf(_revive_left / maxf(_revive_total, 0.01), 0.0, 1.0)
	if _revive_circle:
		_revive_circle.set_shader_parameter("draw", k)
	if is_instance_valid(_revive_light):
		_revive_light.energy = 0.4 + 1.6 * k
	if _revive_left > 0.0:
		return
	var pct := (revive_hp_percent + skill("revive_hp_percent")) / 100.0
	Net.to_owner(_revive_target.peer_id, "net_revive", [pct])
	var feet := _revive_target.global_position + Vector2(0, 24)
	DruidFx.spores_burst(get_tree(), feet)
	Net.echo_static("res://Player_scene/druid_fx.gd", "spores_burst", [get_tree(), feet])
	_revive_stop(true)
	is_attacking = false
	play_movement_animation()


func _revive_stop(done: bool) -> void:
	_revive_left = 0.0
	_revive_target = null
	if is_instance_valid(_revive_fx):
		if not done and _revive_circle:
			_revive_circle.set_shader_parameter("fade", 0.0)
		_revive_fx.queue_free()
	_revive_fx = null
	_revive_circle = null
	_revive_light = null


## Второе дыхание: смертельный удар оставляет её с долей здоровья — раз до
## отдыха у костра
func _try_second_breath() -> void:
	if not is_dead() or second_breath_used or skill("second_breath_enabled") <= 0.0:
		return
	second_breath_used = true
	health = max_health * skill("second_breath_hp_percent") / 100.0
	if is_instance_valid(health_bar):
		health_bar.current_hp = health
	is_invulnerable = true
	_invuln_timer = 1.5
	play_movement_animation()
	_spores_fx(self)
	flash_tint(Color(0.8, 1.6, 0.8, 1.0))


# ═════════════════ УТИЛИТЫ ═════════════════

## Свои клипы (не «Attack*») база не завершает — без этого героиня так и
## осталась бы в is_attacking
const OWN_CLIPS := ["Staff_", "Vine_", "Spikes_", "Binding_", "Spores_", "Sprout_", "Bark_", "Slide_", "Special_"]

func _on_animation_finished(finished_anim: String) -> void:
	# Подъём союзника длится дольше клипа — она остаётся на колене
	if _revive_left > 0.0 and finished_anim.begins_with("Bark_"):
		_play_restart(finished_anim)
		return
	for p in OWN_CLIPS:
		if finished_anim.begins_with(p):
			_moss_left = 0.0
			_binding_armor = false
			is_attacking = false
			combo_step = 0
			combo_queued = false
			play_movement_animation()
			return
	super(finished_anim)


## Запустить клип приёма (не серии) — без комбо; turn — развернуться к цели
func _start_move(prefix: String, turn := true) -> String:
	_attack_recovery = false
	is_attacking = true
	is_run_attacking = false
	combo_step = 0
	combo_queued = false
	_attack_step_velocity = Vector2.ZERO
	if turn:
		_turn_to_aim(_pick_aim())
	if not _play_restart(prefix + last_direction):
		is_attacking = false
		return ""
	return String(anim.current_animation)


## Через frames кадров приём «отыгран»: хвост клипа больше не держит
func _recover_at(clip: String, frames: float) -> void:
	await get_tree().create_timer(frames * _clip_frame_time(clip)).timeout
	if is_attacking and _same_attack(clip):
		_attack_recovery = true


func _clip_frame_time(clip: String) -> float:
	if anim.has_animation(clip):
		var a := anim.get_animation(clip)
		if a.get_track_count() > 0 and a.track_get_key_count(0) > 1:
			var step := a.track_get_key_time(0, 1) - a.track_get_key_time(0, 0)
			if step > 0.0:
				return step
	return 1.0 / 15.0


## До max живых врагов в радиусе, ближние первыми; взятая в фокус цель —
## первой (как mage.gd::_special_targets)
func _targets_around(radius: float, max_count: int) -> Array:
	var found := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not "is_dead" in e or e.is_dead or not e.has_method("take_damage"):
			continue
		if global_position.distance_to(e.global_position) <= radius:
			found.append(e)
	found.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var focus: Node2D = _focus.target if is_instance_valid(_focus) and _focus.has_target() else null
	if is_instance_valid(focus) and found.has(focus):
		found.erase(focus)
		found.push_front(focus)
	return found.slice(0, max_count)


## Точка под ногами врага относительно его узла (как mage.gd::_ground_offset)
func _ground_offset(e: Node2D) -> Vector2:
	var spr := e.get_node_or_null("AnimatedSprite2D") as Node2D
	if spr == null:
		return Vector2.ZERO
	return spr.position + FEET_PX * spr.scale


func _scene_root() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root


## Точки на теле: те же 3D-рендеры 128x128, что у мага (mage.gd::FEET_PX)
const BODY_CENTER_PX := Vector2(0, 3)
const FEET_PX := Vector2(0, 27)

func _feet() -> Vector2:
	if not is_instance_valid(sprite):
		return Vector2.ZERO
	return sprite.position + FEET_PX * sprite.scale


func _body() -> Vector2:
	if not is_instance_valid(sprite):
		return Vector2(0, -4)
	return sprite.position + BODY_CENTER_PX * sprite.scale


## Откуда срываются заклинания из руки — чуть впереди груди, по взгляду
func _hand_point() -> Vector2:
	var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.DOWN
	return global_position + _body() + dir * 12.0 + Vector2(0, -4)


# ═════════════════ ЕЩЁ НЕ СДЕЛАНО ═════════════════
# Механики узлов дерева (Save/skill_trees.gd), которые пока никто не читает:
#   kill_sprout_*        — Падаль кормит лес (росток на месте убитого)
#   swarm_*              — Жучиный рой после шипов
#   forest_wrath_*       — Гнев леса (ульта на C, клип Special_)
#   bark_thorns_percent  — Терновая кора (отражение урона)
#   binding_wall_*       — Корневая стена при Оковах
#   sprout_hp_percent    — у ростка пока нет прочности (враги его не ломают)
#   wolf_*               — Зов стаи (волк)
# Споры, Кора и подъём павшего работают и на союзников (кооп, блок «Союзники»).
# Свой голос (боль, смерть) и портрет на HUD — тоже позже.
