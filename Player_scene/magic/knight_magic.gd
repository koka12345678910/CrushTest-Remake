extends Node
## knight_magic.gd — магия рыцаря: «Благословение богов» за Одр.
##
## Одр — связь с богами (тёмно-синяя полоска между здоровьем и выносливостью,
## UI/health_stamina_bar.gd::enable_odr). Сам не растёт: боги дают его за
## доблесть — добивание, идеальное парирование, убийство. На входе в уровень
## полон.
##
## Заклинания лежат в книге (magic_inventory — такая же сумка, как у
## предметов, но ничего не тратится) и ставятся в три слота магии
## (magic_slots — такая же система, как быстрые слоты). Слот магии на HUD —
## левый верхний угол; Q — применить, X — следующий слот.
##
## Применение (begin_prayer): рыцарь возносит меч (кадры 0-6 листа Special1,
## клип Blessing_<сторона> собирается здесь же при старте). Когда меч
## наверху — бьёт молния Тора или вспыхивает клинок Сурта, только тогда
## списывается Одр и включается благословение. Сбили раньше — Одр цел.
## У огня ещё при начале молитвы вокруг вспыхивает огненное кольцо.
##
## Благословение на мече (duration сек) — on_weapon_hit (зовёт enemy.gd на
## каждый удар рыцаря):
##   молния — удары сильно бьют по концентрации, разряд перескакивает на
##            ближайшего соседа и оглушает его;
##   огонь  — удар поджигает (несколько тиков урона мимо блока).

const Spells := preload("res://Player_scene/magic/spells.gd")
const QuickSlotScript := preload("res://Inventory/ui/quick_slot_ui.gd")
const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")
const LightningBolt := preload("res://VFX/VFX_scene/lightning_bolt.gd")
const SPECIAL_SHEET := preload("res://Character/CharacterAnimationAssets/With shadows/Special1.png")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_THUNDER := preload("res://Sound/thunder.mp3")
const SOUND_FIRE := preload("res://Sound/abilities_sound/fenrir_blood.mp3")
const SOUND_PRAY := preload("res://Sound/abilities_sound/rune_sound.mp3")

@export var max_odr := 100.0
## Сколько Одра дают боги
@export var odr_on_execution := 25.0
@export var odr_on_parry := 10.0
@export var odr_on_kill := 5.0

@export_group("Молния")
## Удар по концентрации врага (по щиту — больше: молния ломает защиту)
@export var lightning_posture := 14.0
@export var lightning_posture_blocked := 28.0
@export var chain_radius := 90.0
@export var chain_damage := 1

@export_group("Огонь")
@export var burn_ticks := 3
@export var burn_interval := 0.8
@export var burn_damage := 1
@export var fire_ring_radius := 72.0
@export var fire_ring_push := 240.0

const DIRS := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]
## Кадры молитвы: меч поднимается (0-5), держится над головой, опускается.
## Держим кадр 5, а не 6: в 5-м меч уже вознесён и нарисован чёткой линией,
## в 6-м он смазан веером движения
const PRAY_FRAMES := [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 5, 4, 3, 2, 1]
const PRAY_FPS := 12.0
## Меч наверху — в этот момент бьёт молния / вспыхивает клинок
const PRAY_STRIKE := 0.55
const PRAY_LENGTH := 16.0 / 12.0
## Клинок в кадре 5 (меч вознесён) по сторонам — кончик и рукоять, пиксели
## кадра 128x128, сняты по сетке с листа Special1. По ним рисуется
## раскалённое лезвие поверх нарисованного меча
const BLADE_TIP_PX := {
	"Right": Vector2(73, 27), "Down_Right": Vector2(59, 29), "Down": Vector2(48, 22),
	"Down_Left": Vector2(46, 12), "Left": Vector2(52, 5), "Up_Left": Vector2(67, 3),
	"Up": Vector2(82, 6), "Up_Right": Vector2(81, 19),
}
const BLADE_HILT_PX := {
	"Right": Vector2(72, 47), "Down_Right": Vector2(55, 53), "Down": Vector2(42, 46),
	"Down_Left": Vector2(44, 34), "Left": Vector2(56, 26), "Up_Left": Vector2(74, 26),
	"Up": Vector2(85, 36), "Up_Right": Vector2(84, 48),
}
## Тряска камеры в момент удара молнии в меч (у импульса мага — 6.0)
const STRIKE_SHAKE := 7.5
## Меч опускается с кадра 12 — до этого клинок горит молнией
const PRAY_HOLD_END := 12.0 / 12.0
## Куда смотрит рыцарь — рука с мечом сдвинута в эту сторону от груди
const DIR_VEC := {
	"Right": Vector2(1, 0), "Down_Right": Vector2(0.7, 0.7), "Down": Vector2(0, 1),
	"Down_Left": Vector2(-0.7, 0.7), "Left": Vector2(-1, 0), "Up_Left": Vector2(-0.7, -0.7),
	"Up": Vector2(0, -1), "Up_Right": Vector2(0.7, -0.7),
}
## Цвета молнии Тора — тёплые, желтоватые
const BOLT_CORE := Color(1.0, 0.97, 0.84)
const BOLT_GLOW := Color(1.0, 0.8, 0.35)

var odr := 100.0
var magic_inventory: InventorySystem
var magic_slots: AbilitySystem
var knight

var is_praying := false
var _prayer_spell
var _prayer_t := 0.0
var _struck := false

## Активное благословение на мече: "lightning", "fire" или ""
var active_element := ""
var _blessing_left := 0.0
var _blessing_color := Color.WHITE
var _aura_light: PointLight2D
var _aura_fx: GPUParticles2D
var _crackle_t := 0.0
var _chaining := false

var _slot_ui
var _health_bar
var _audio: AudioStreamPlayer2D


func setup(k) -> void:
	knight = k
	odr = max_odr
	magic_inventory = InventorySystem.new()
	magic_inventory.name = "MagicBook"
	add_child(magic_inventory)
	magic_slots = AbilitySystem.new()
	magic_slots.name = "MagicSlots"
	add_child(magic_slots)
	_audio = AudioStreamPlayer2D.new()
	_audio.max_distance = 900.0
	k.add_child.call_deferred(_audio)
	_ensure_actions()
	_build_prayer_clips()


## HUD: полоска Одра и слот магии в левом верхнем углу (под медальоном)
func build_hud(hud_layer: CanvasLayer, health_bar: Node) -> void:
	_health_bar = health_bar
	health_bar.enable_odr()
	health_bar.set_odr(odr, max_odr)
	_slot_ui = Control.new()
	_slot_ui.set_script(QuickSlotScript)
	_slot_ui.name = "MagicSlotUI"
	_slot_ui.magic_mode = true
	_slot_ui.hud_scale = 0.78
	_slot_ui.glow_color = Color(0.35, 0.45, 0.85)
	_slot_ui.offset_left = 26.0
	_slot_ui.offset_top = 150.0
	_slot_ui.offset_right = 26.0 + 180.0
	_slot_ui.offset_bottom = 150.0 + 220.0
	hud_layer.add_child(_slot_ui)
	_slot_ui.init(magic_slots)


# ===================== КНИГА ЗАКЛИНАНИЙ =====================

func knows(spell_name: String) -> bool:
	return magic_inventory.get_count(spell_name) > 0


## Выучить заклинание (находка, загрузка сейва). Пока есть место — сразу
## в слот магии, чтобы найденным можно было пользоваться сразу
func learn(spell_name: String) -> bool:
	if knows(spell_name) or not Spells.exists(spell_name):
		return false
	var s := Spells.make(spell_name)
	magic_inventory.add_item(s)
	if not magic_slots.is_full():
		magic_slots.add_ability(s)
	return true


func known_spell_names() -> Array:
	var out := []
	for it in magic_inventory.get_all():
		out.append((it as Ability).ability_name)
	return out


# ===================== ОДР =====================

func add_odr(amount: float) -> void:
	odr = minf(odr + amount, max_odr)


func on_kill(_enemy: Node) -> void:
	add_odr(odr_on_kill)


func on_execution() -> void:
	add_odr(odr_on_execution)


func on_parry() -> void:
	add_odr(odr_on_parry)


# ===================== ВВОД =====================

## Клавиши магии — свои действия, заводятся при старте, если их нет в
## настройках проекта: Q — применить, X — следующий слот
func _ensure_actions() -> void:
	for pair in [["magic_use", KEY_Q], ["magic_next", KEY_X]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev)


func _unhandled_input(event: InputEvent) -> void:
	if knight == null or knight.inventory_ui.visible or knight.is_in_shop:
		return
	if event.is_action_pressed("magic_next"):
		if not is_praying:
			magic_slots.next_slot()
	elif event.is_action_pressed("magic_use"):
		try_cast()


func _can_start_prayer() -> bool:
	return not (is_praying or knight.is_attacking or knight.is_run_attacking or knight.is_dodging
			or knight.is_rolling or knight.is_parrying or knight.is_blocking or knight.is_stunned
			or knight.is_taking_damage or knight.is_starting or knight.is_in_shop)


func try_cast() -> void:
	var spell = magic_slots.get_current_ability()
	if spell == null or not _can_start_prayer():
		return
	# Боги не отвечают: Одра мало — молитва не начинается, полоска мигает
	if odr < spell.odr_cost:
		_play(SOUND_DENIED, -6.0)
		if _health_bar:
			_health_bar.blink_odr()
		return
	# Через систему слотов: кулдаун, кольцо на HUD; _execute → begin_prayer
	magic_slots.use_current(knight)


# ===================== МОЛИТВА =====================

func begin_prayer(spell) -> void:
	is_praying = true
	_prayer_spell = spell
	_prayer_t = 0.0
	_struck = false
	knight.velocity = Vector2.ZERO
	var clip: String = "Blessing_" + knight.last_direction
	if knight.anim.has_animation(clip):
		knight.anim.play(clip)
	_play(SOUND_PRAY, -8.0)
	if spell.element == "fire":
		_fire_ring()


func _process(delta: float) -> void:
	if knight == null:
		return
	if _health_bar:
		_health_bar.set_odr(odr, max_odr)
	if _slot_ui:
		var cur = magic_slots.get_current_ability()
		_slot_ui.set_affordable(cur == null or odr >= cur.odr_cost)
	if is_praying:
		_update_prayer(delta)
	if active_element != "":
		_update_blessing(delta)


func _update_prayer(delta: float) -> void:
	# Сбили посреди молитвы — она обрывается; если молния ещё не ударила,
	# Одр не потрачен
	if knight.is_taking_damage or knight.is_stunned or knight.is_rolling:
		is_praying = false
		_end_blade_fx()
		return
	var prev := _prayer_t
	_prayer_t += delta
	if _prayer_spell.element == "lightning":
		_prayer_storm(prev, _prayer_t)
	if not _struck and _prayer_t >= PRAY_STRIKE:
		_struck = true
		odr = maxf(odr - _prayer_spell.odr_cost, 0.0)
		_bless(_prayer_spell)
	if _prayer_t >= PRAY_HOLD_END and is_instance_valid(_blade_fx):
		_end_blade_fx()
	if _prayer_t >= PRAY_LENGTH:
		is_praying = false
		knight.play_idle_animation()


## Буря собирается, пока меч поднимается к небу: дрожь земли нарастает, края
## экрана темнеют, к кончику меча стягиваются искры, вдали бьют две молнии
## поменьше. После удара — земля ещё гудит, пока меч держит молнию
func _prayer_storm(prev: float, t: float) -> void:
	if t < PRAY_STRIKE:
		var k := t / PRAY_STRIKE
		Juice.shake(lerpf(0.6, 3.2, k * k))
		Juice.pulse("vignette", lerpf(0.15, 0.55, k), 0.05)
		Juice.pulse("desat", lerpf(0.0, 0.3, k), 0.05)
		# Искры со всех сторон летят в кончик меча
		if int(t / 0.04) != int(prev / 0.04):
			for i in 3:
				_converge_spark(_blade_tip())
		# Дальние молнии — буря отвечает на молитву
		for at_t in [0.16, 0.36]:
			if prev < at_t and t >= at_t:
				var a := randf() * TAU
				var p: Vector2 = knight.global_position + Vector2(cos(a), sin(a) * 0.6) * randf_range(110.0, 190.0)
				LightningBolt.strike(get_tree(), p, false, true)
				Juice.flash(0.08)
	elif t < PRAY_HOLD_END:
		# Меч держит молнию — гул затихает к моменту, когда меч опускается
		var k := (t - PRAY_STRIKE) / (PRAY_HOLD_END - PRAY_STRIKE)
		Juice.shake(lerpf(3.5, 1.0, k))
		Juice.pulse("vignette", 0.5, 0.05)


## Искра, стягивающаяся к точке: появляется в стороне и летит в кончик меча
func _converge_spark(to: Vector2) -> void:
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var a := randf() * TAU
	var s := Sprite2D.new()
	s.texture = MageFx.dot()
	s.material = MageFx.add_material()
	s.modulate = Color(BOLT_CORE * _ambient_comp(), 0.0)
	s.scale = Vector2.ONE * randf_range(0.25, 0.5)
	s.z_as_relative = false
	s.z_index = 92
	root.add_child(s)
	s.global_position = to + Vector2(cos(a), sin(a) * 0.8) * randf_range(28.0, 60.0)
	var t := s.create_tween().set_parallel()
	t.tween_property(s, "global_position", to, randf_range(0.18, 0.3)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(s, "modulate:a", 1.0, 0.12)
	t.chain().tween_callback(s.queue_free)


## Мировая точка кончика клинка, когда меч вознесён (кадр 6 молитвы)
func _blade_tip() -> Vector2:
	var px: Vector2 = BLADE_TIP_PX.get(String(knight.last_direction), Vector2(60, 15))
	var gfx: Node2D = knight.gfx
	return gfx.global_position + (px - Vector2(64, 64)) * gfx.global_scale


## Рука с мечом в бою (для свечения и искр благословения): от груди в
## сторону взгляда
func _hand_offset() -> Vector2:
	var v: Vector2 = DIR_VEC.get(String(knight.last_direction), Vector2.DOWN)
	return Vector2(0, -6) + Vector2(v.x * 10.0, v.y * 6.0)


## Меч наверху: стихия входит в клинок
func _bless(spell) -> void:
	var tip: Vector2 = _blade_tip()
	if spell.element == "lightning":
		# Желтоватая молния Тора бьёт точно в кончик поднятого меча — самый
		# тяжёлый момент: мир на миг замирает, камеру бьёт вниз и приближает,
		# экран вспыхивает и расслаивается, под ногами трескается земля
		LightningBolt.strike(knight.get_tree(), tip, true, true)
		var feet: Vector2 = knight.global_position + Vector2(0, 26)
		Juice.freeze(0.07)
		Juice.slow(0.35, 0.45, 0.35)
		Juice.zoom_punch(0.14, 0.35)
		Juice.kick(Vector2.DOWN, 7.0)
		# Тряска как у большого импульса мага (mage.gd pulse_big_shake 6.0 через
		# shake_camera — та же затухающая тряска героя с множителем из
		# настроек), только чуть сильнее
		knight.shake_camera(STRIKE_SHAKE)
		Juice.flash(0.55)
		Juice.pulse("aberration", 0.45, 0.1)
		Juice.shockwave(feet, 90.0, 0.45, 0.016)
		Juice.ground_crack(feet, 1.5, Color(1.0, 0.82, 0.35, 0.9))
		_ground_burst(feet)
		_play(SOUND_THUNDER, -2.0)
		_charge_blade(tip)
	else:
		var h := MageFx.holder(knight.get_tree(), tip, 0.9, 13)
		MageFx.flash(h, 36.0, 0.25, Color(1.0, 0.75, 0.4))
		MageFx.light_pulse(h, 110.0, 2.0, 0.5, spell.color)
		MageFx.embers(h, 14, 10.0, 0.9)
		Juice.shake(3.0)
		_play(SOUND_FIRE, -6.0)
	_start_blessing(spell)


## Удар молнии о землю под ногами: золотое кольцо, пыль, искры веером
func _ground_burst(at: Vector2) -> void:
	var h := MageFx.holder(get_tree(), at, 1.2, 6)
	KnightFx._ring(h, 8.0, 70.0, 2.5, 0.4, Color(BOLT_GLOW, 0.9))
	KnightFx._ring(h, 6.0, 46.0, 1.6, 0.3, Color(BOLT_CORE, 0.8))
	MageFx.light_pulse(h, 150.0, 2.2, 0.5, BOLT_GLOW)
	MageFx.smoke(h, 8, 14.0, 20.0, 0.8)
	for i in 6:
		var a := randf() * TAU
		_bolt_line(at, at + Vector2(cos(a), sin(a) * 0.6) * randf_range(22.0, 44.0), 0.2, 1.6)
	KnightFx._sparks(get_tree(), at, Vector2.UP, 16, 3.1, 80.0, 220.0, 0.45)


# ===================== СВЕЧЕНИЕ КЛИНКА =====================

## Раскалённый клинок рисуется поверх нарисованного меча: в кадре 5 листа
## Special1 меч — прямая от рукояти до кончика (BLADE_HILT_PX → BLADE_TIP_PX).
## Слои вдоль неё: широкий мягкий ореол, жёлтое свечение, тонкое бело-жёлтое
## ядро, сужающееся к кончику; по стали бегут разряды, от кончика к рукояти
## стекают световые импульсы. Узел — ребёнок спрайта рыцаря: та же точка, тот
## же масштаб, кадр в кадр (вырезать сталь из картинки нельзя — доспех такой
## же светлый, как клинок)
var _blade_fx: Node2D
var _blade_a := Vector2.ZERO
var _blade_b := Vector2.ZERO


## Клинок принял молнию: пока меч поднят — раскалённое лезвие с ореолом,
## звезда на кончике, по стали бегут разряды, сыплются искры
func _charge_blade(tip: Vector2) -> void:
	_end_blade_fx()
	var tree := get_tree()
	var gfx: AnimatedSprite2D = knight.gfx
	var row := DIRS.find(String(knight.last_direction))
	var hold := maxf(PRAY_HOLD_END - _prayer_t, 0.2)

	# Звезда на кончике и свет — сдержанно: сильнее — и раскалённый клинок
	# тонет в белом сиянии, прорисовки стали не видно
	var h := MageFx.holder(tree, tip, hold + 0.5, 14)
	var star := KnightFx._glint(h, 48.0, 0.0, 0.24, BOLT_CORE)
	star.rotation = randf() * PI
	var star2 := KnightFx._glint(h, 28.0, 0.0, 0.2, BOLT_GLOW)
	star2.rotation = star.rotation + PI * 0.25
	MageFx.flash(h, 16.0, 0.15, BOLT_CORE)
	MageFx.light_pulse(h, 70.0, 1.1, hold, BOLT_GLOW)

	if row < 0:
		return
	# Концы клинка в координатах спрайта (центр кадра — его точка)
	_blade_a = BLADE_HILT_PX[DIRS[row]] - Vector2(64, 64)
	_blade_b = BLADE_TIP_PX[DIRS[row]] - Vector2(64, 64)
	_blade_fx = Node2D.new()
	_blade_fx.z_index = 1
	gfx.add_child(_blade_fx)
	# Яркость — с поправкой на ночь (CanvasModulate гасит весь мир): после
	# затемнения ядро прибавляет почти белое, свечение — тёплое золото
	var comp := _ambient_comp()
	var halo := _blade_line(7.0, Color(BOLT_GLOW.r * comp.r * 0.3, BOLT_GLOW.g * comp.g * 0.24, BOLT_GLOW.b * comp.b * 0.12, 1.0), 0.75)
	var mid := _blade_line(3.2, Color(BOLT_GLOW.r * comp.r * 0.6, BOLT_GLOW.g * comp.g * 0.5, BOLT_GLOW.b * comp.b * 0.3, 1.0), 0.5)
	var core := _blade_line(1.3, Color(BOLT_CORE.r * comp.r * 1.0, BOLT_CORE.g * comp.g * 0.95, BOLT_CORE.b * comp.b * 0.8, 1.0), 0.25)
	# Раскал вспыхивает в момент удара и дальше живо мерцает, а ореол дышит
	for layer in [halo, mid, core]:
		var base: Color = layer.modulate
		var w: float = layer.width
		layer.modulate = base * 1.7
		var tw: Tween = layer.create_tween()
		tw.tween_property(layer, "modulate", base, 0.15)
		for i in int(hold / 0.05):
			tw.tween_property(layer, "modulate", base * randf_range(0.8, 1.2), 0.025)
			tw.parallel().tween_property(layer, "width", w * randf_range(0.85, 1.15), 0.025)
	# Разряды по стали, искры с лезвия, импульсы от кончика к рукояти
	var fx := _blade_fx
	for i in int(hold / 0.04):
		tree.create_timer(i * 0.04).timeout.connect(_blade_arc.bind(fx))
	for i in 4:
		tree.create_timer(i * hold / 4.0).timeout.connect(_blade_pulse.bind(fx))


## Слой раскалённого лезвия: от рукояти к кончику, сужается к острию
func _blade_line(width: float, col: Color, tip_width: float) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([_blade_a, _blade_a.lerp(_blade_b, 0.5), _blade_b])
	l.width = width
	var wc := Curve.new()
	wc.add_point(Vector2(0, 1))
	wc.add_point(Vector2(0.7, 0.8))
	wc.add_point(Vector2(1, tip_width))
	l.width_curve = wc
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.default_color = Color.WHITE
	l.modulate = col
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	l.material = m
	_blade_fx.add_child(l)
	return l


## Короткий разряд по стали (между двумя точками лезвия, чуть в стороне от
## него) + искры с клинка
func _blade_arc(fx: Node2D) -> void:
	if not is_instance_valid(fx) or fx != _blade_fx:
		return
	var gfx: Node2D = knight.gfx
	var perp := (_blade_b - _blade_a).orthogonal().normalized()
	var t0 := randf_range(0.05, 0.85)
	var a := gfx.to_global(_blade_a.lerp(_blade_b, t0) + perp * randf_range(-1.5, 1.5))
	var b := gfx.to_global(_blade_a.lerp(_blade_b, minf(t0 + randf_range(0.15, 0.4), 1.0)) + perp * randf_range(-2.5, 2.5))
	_bolt_line(a, b, 0.06, 0.9)
	if randf() < 0.55:
		KnightFx._sparks(get_tree(), a, Vector2.from_angle(randf_range(0.3, PI - 0.3)), 2, 1.0, 40.0, 120.0, 0.3)


## Сгусток света стекает по клинку от кончика к рукояти — меч "пьёт" молнию
func _blade_pulse(fx: Node2D) -> void:
	if not is_instance_valid(fx) or fx != _blade_fx:
		return
	var s := Sprite2D.new()
	s.texture = MageFx.soft()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	var comp := _ambient_comp()
	s.modulate = Color(BOLT_CORE.r * comp.r * 0.9, BOLT_CORE.g * comp.g * 0.85, BOLT_CORE.b * comp.b * 0.6, 1.0)
	s.scale = Vector2.ONE * 7.0 / 64.0
	s.position = _blade_b
	fx.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "position", _blade_a, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.22).set_delay(0.12)
	t.tween_callback(s.queue_free)


## Меч опускается — раскал быстро гаснет
func _end_blade_fx() -> void:
	if not is_instance_valid(_blade_fx):
		_blade_fx = null
		return
	var fx := _blade_fx
	_blade_fx = null
	var t := fx.create_tween()
	t.tween_property(fx, "modulate:a", 0.0, 0.18)
	t.tween_callback(fx.queue_free)


## Ночной CanvasModulate гасит всё в мире — подсветка клинка и искры должны
## светить в полную силу (тот же приём, что у молнии и золотых душ)
func _ambient_comp() -> Color:
	var scene := get_tree().current_scene
	if scene:
		for ch in scene.get_children():
			if ch is CanvasModulate and ch.visible:
				var c: Color = ch.color
				return Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)
	return Color.WHITE


func _start_blessing(spell) -> void:
	active_element = spell.element
	_blessing_left = spell.duration
	_blessing_color = spell.color
	_clear_aura()
	# Свет от клинка
	_aura_light = PointLight2D.new()
	_aura_light.texture = MageFx.radial()
	_aura_light.texture_scale = 90.0 / 128.0
	_aura_light.color = spell.color
	_aura_light.energy = 0.0
	_aura_light.position = _hand_offset()
	knight.add_child(_aura_light)
	create_tween().tween_property(_aura_light, "energy", 0.7, 0.3)
	# Частицы вокруг — искры молнии / угли огня, поднимаются от рыцаря
	_aura_fx = GPUParticles2D.new()
	_aura_fx.amount = 18 if active_element == "fire" else 7
	_aura_fx.lifetime = 0.8 if active_element == "fire" else 0.3
	_aura_fx.local_coords = false
	_aura_fx.texture = MageFx.dot()
	_aura_fx.material = MageFx.add_material()
	_aura_fx.visibility_rect = MageFx.VIS_RECT
	_aura_fx.position = _hand_offset() if active_element == "lightning" else Vector2(0, -6)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	# Молния — искрит у руки с мечом, огонь — угли вокруг всего рыцаря
	pm.emission_sphere_radius = 10.0 if active_element == "fire" else 5.0
	pm.spread = 180.0
	if active_element == "fire":
		pm.gravity = Vector3(0, -40, 0)
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 14.0
		pm.color_ramp = MageFx.ramp([Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.45, 0.12, 0.6), Color(0.5, 0.1, 0.05, 0.0)])
	else:
		pm.gravity = Vector3(0, 30, 0)
		pm.initial_velocity_min = 20.0
		pm.initial_velocity_max = 55.0
		pm.damping_min = 40.0
		pm.damping_max = 80.0
		pm.color_ramp = MageFx.ramp([Color(1.0, 1.0, 0.92, 1.0), Color(1.0, 0.88, 0.5, 0.7), Color(1.0, 0.65, 0.2, 0.0)])
	pm.scale_min = 0.25
	pm.scale_max = 0.6
	_aura_fx.process_material = pm
	knight.add_child(_aura_fx)


func _update_blessing(delta: float) -> void:
	_blessing_left -= delta
	if _aura_light:
		var flick := 0.08 * sin(Time.get_ticks_msec() * 0.02) + (0.1 * randf() if active_element == "lightning" else 0.0)
		# Последние 3 секунды свет тает — видно, что благословение кончается
		_aura_light.energy = (0.6 + flick) * clampf(_blessing_left / 3.0, 0.0, 1.0)
	if active_element == "lightning":
		# Свет и искры держатся у руки с мечом — она поворачивается вместе с
		# рыцарем; клинок изредка коротко искрит
		var hand := _hand_offset()
		if _aura_light:
			_aura_light.position = hand
		if _aura_fx:
			_aura_fx.position = hand
		_crackle_t -= delta
		if _crackle_t <= 0.0:
			_crackle_t = randf_range(0.35, 0.8)
			_crackle(knight.global_position + hand + Vector2(randf_range(-4, 4), randf_range(-6, 2)), 7.0)
	if _blessing_left <= 0.0:
		active_element = ""
		_clear_aura()


func _clear_aura() -> void:
	if is_instance_valid(_aura_light):
		var l := _aura_light
		var t := l.create_tween()
		t.tween_property(l, "energy", 0.0, 0.3)
		t.tween_callback(l.queue_free)
	if is_instance_valid(_aura_fx):
		var p := _aura_fx
		p.emitting = false
		get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)
	_aura_light = null
	_aura_fx = null


# ===================== УДАРЫ С БЛАГОСЛОВЕНИЕМ =====================

## Зовёт enemy.gd::take_damage на каждый удар рыцаря (через player.gd)
func on_weapon_hit(enemy, blocked: bool) -> void:
	if active_element == "" or _chaining or not is_instance_valid(enemy):
		return
	match active_element:
		"lightning":
			_add_posture(enemy, lightning_posture_blocked if blocked else lightning_posture)
			var at: Vector2 = enemy.global_position + Vector2(0, -8)
			_lightning_impact(at, (at - knight.global_position).normalized(), blocked)
			_chain_from(enemy)
		"fire":
			if not blocked:
				_ignite(enemy)
			var h := MageFx.holder(get_tree(), enemy.global_position + Vector2(0, -6), 0.6, 12)
			MageFx.flash(h, 16.0, 0.14, Color(1.0, 0.65, 0.3))
			MageFx.embers(h, 6, 6.0, 0.6)


## Концентрацию врага — напрямую, без принудительного стаггера (его даёт
## enemy.take_posture_damage на каждый вызов); полная — щит раскалывается
func _add_posture(enemy, amount: float) -> void:
	if enemy.get("is_dead") or enemy.get("is_posture_broken") or not ("posture" in enemy):
		return
	enemy.posture = minf(enemy.posture + amount, enemy.max_posture)
	enemy.posture_regen_timer = 0.0
	if enemy.posture_bar:
		enemy.posture_bar.visible = true
		enemy.posture_bar.value = enemy.posture
	if enemy.posture >= enemy.max_posture and enemy.has_method("_posture_break"):
		enemy._posture_break()


## Разряд перескакивает на ближайшего соседа: короткий удар и оглушение
func _chain_from(enemy) -> void:
	var best = null
	var best_d := chain_radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == enemy or not is_instance_valid(e) or e.is_dead:
			continue
		var d: float = e.global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	_bolt_line(enemy.global_position + Vector2(0, -8), best.global_position + Vector2(0, -8))
	_chaining = true
	best.take_damage(chain_damage, knight, true)
	_chaining = false


func _ignite(enemy) -> void:
	# Повторный удар продлевает горение (заново полный счёт тиков), а не
	# плодит параллельные. Счёт — в тиках, а не по часам: часы реального
	# времени расходились с игровыми таймерами при слоу-мо от ударов
	var burning: bool = enemy.get_meta("burn_left", 0) > 0
	enemy.set_meta("burn_left", burn_ticks)
	if not burning:
		_burn_tick(enemy)


func _burn_tick(enemy) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.get_meta("burn_left", 0) <= 0:
		return
	get_tree().create_timer(burn_interval).timeout.connect(func():
		if not is_instance_valid(enemy) or enemy.is_dead:
			return
		enemy.set_meta("burn_left", enemy.get_meta("burn_left", 1) - 1)
		var h := MageFx.holder(get_tree(), enemy.global_position + Vector2(0, -4), 0.8, 12)
		MageFx.embers(h, 5, 8.0, 0.7)
		MageFx.light_pulse(h, 40.0, 0.8, 0.3, Color(1.0, 0.5, 0.15))
		enemy.take_bleed_damage(burn_damage, knight)
		_burn_tick(enemy))


## Огонь Сурта: при начале молитвы вокруг вспыхивает кольцо — отталкивает и
## поджигает тех, кто вплотную
func _fire_ring() -> void:
	var c: Vector2 = knight.global_position + Vector2(0, 14)
	var h := MageFx.holder(get_tree(), c, 1.2, 6)
	KnightFx._ring(h, 10.0, fire_ring_radius, 3.0, 0.45, Color(1.0, 0.55, 0.15, 0.95))
	KnightFx._ring(h, 6.0, fire_ring_radius * 0.75, 2.0, 0.35, Color(1.0, 0.85, 0.45, 0.8))
	MageFx.light_pulse(h, fire_ring_radius * 1.8, 1.8, 0.6, Color(1.0, 0.5, 0.15))
	MageFx.embers(h, 22, fire_ring_radius * 0.8, 1.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		var off: Vector2 = e.global_position - knight.global_position
		if off.length() > fire_ring_radius:
			continue
		if "knockback_velocity" in e:
			e.knockback_velocity = off.normalized() * fire_ring_push if off.length() > 0.1 else Vector2.DOWN * fire_ring_push
		_ignite(e)


# ===================== ЭФФЕКТЫ МОЛНИИ =====================

## Удар мечом с молнией: вспышка и звезда в точке удара, короткие разряды
## во все стороны, жёлтые искры по направлению удара, всплеск света.
## В щит — сильнее (молния ломает защиту)
func _lightning_impact(at: Vector2, dir: Vector2, strong: bool) -> void:
	var tree := get_tree()
	var h := MageFx.holder(tree, at, 0.6, 13)
	var star := KnightFx._glint(h, 66.0 if strong else 50.0, 0.0, 0.16, BOLT_CORE)
	star.rotation = randf() * PI
	MageFx.flash(h, 24.0 if strong else 18.0, 0.12, BOLT_CORE)
	MageFx.light_pulse(h, 70.0, 1.4, 0.25, BOLT_GLOW)
	KnightFx._ring(h, 4.0, 22.0 if strong else 16.0, 1.4, 0.16, Color(BOLT_GLOW, 0.8))
	for i in (5 if strong else 3):
		var a := randf() * TAU
		var tip := at + Vector2(cos(a), sin(a) * 0.75) * randf_range(12.0, 24.0)
		_bolt_line(at, tip, 0.13, 1.3)
	KnightFx._sparks(tree, at, dir, 10 if strong else 7, 1.2, 90.0, 230.0, 0.32)
	Juice.shake(2.5 if strong else 1.5)


## Короткий зигзаг-разряд в точке
func _crackle(at: Vector2, size: float) -> void:
	var a := at + Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * size * 0.5
	var b := at - (a - at)
	_bolt_line(a, b, 0.12, 1.4)


## Ломаная белая линия разряда с голубым ореолом — гаснет за life
func _bolt_line(a: Vector2, b: Vector2, life := 0.16, width := 2.0) -> void:
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var pts := PackedVector2Array([a])
	var n := 5
	var perp := (b - a).orthogonal().normalized()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + perp * randf_range(-5.0, 5.0))
	pts.append(b)
	for layer in [[width * 3.0, Color(BOLT_GLOW, 0.45)], [width, Color(BOLT_CORE, 1.0)]]:
		var l := Line2D.new()
		l.points = pts
		l.width = layer[0]
		l.default_color = layer[1]
		l.material = MageFx.add_material()
		l.z_as_relative = false
		l.z_index = 90
		root.add_child(l)
		var t := l.create_tween()
		t.tween_property(l, "modulate:a", 0.0, life)
		t.tween_callback(l.queue_free)


func _play(stream: AudioStream, db: float) -> void:
	if not is_instance_valid(_audio) or not _audio.is_inside_tree():
		return
	_audio.stream = stream
	_audio.volume_db = db
	_audio.play()


# ===================== КЛИП МОЛИТВЫ =====================

## Blessing_<сторона>: кадры листа Special1 (меч вознесён), собираются в
## SpriteFrames рыцаря и в его AnimationPlayer при старте — исходные файлы
## анимаций (player.tres / player.tscn) не меняются
func _build_prayer_clips() -> void:
	var gfx: AnimatedSprite2D = knight.gfx
	var anim: AnimationPlayer = knight.anim
	if gfx == null or anim == null or gfx.sprite_frames == null:
		return
	# Кадры — в SpriteFrames всегда; клип AnimationPlayer — если есть библиотека
	var lib: AnimationLibrary = anim.get_animation_library("") if anim.has_animation_library("") else null
	var sf := gfx.sprite_frames
	for row in DIRS.size():
		var clip := StringName("Blessing_" + DIRS[row])
		if not sf.has_animation(clip):
			sf.add_animation(clip)
			sf.set_animation_loop(clip, false)
			sf.set_animation_speed(clip, PRAY_FPS)
			var cache := {}
			for f in PRAY_FRAMES:
				if not cache.has(f):
					var at := AtlasTexture.new()
					at.atlas = SPECIAL_SHEET
					at.region = Rect2(f * 128, row * 128, 128, 128)
					cache[f] = at
				sf.add_frame(clip, cache[f])
		if lib == null or lib.has_animation(clip):
			continue
		var a := Animation.new()
		a.length = PRAY_FRAMES.size() / PRAY_FPS
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath("PlayerAnim:frame"))
		a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		for i in PRAY_FRAMES.size():
			a.track_insert_key(t, i / PRAY_FPS, i)
		var t2 := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t2, NodePath("PlayerAnim:animation"))
		a.value_track_set_update_mode(t2, Animation.UPDATE_DISCRETE)
		a.track_insert_key(t2, 0.0, clip)
		lib.add_animation(clip, a)
