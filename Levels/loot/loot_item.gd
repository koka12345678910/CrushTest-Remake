extends Node2D
## loot_item.gd — находка на земле, как в Dark Souls: белое свечение у самой
## земли (ядро, мягкий ореол, медленно всплывающие искры, бледный свет на
## траву). Подойти и нажать E (действие "interact") — в окне "Получено"
## появится, что это было.
##
## Что внутри — решается в момент подбора, под того героя, кто поднял:
##   - способность из каталога магазина его класса (Shop/shop_menu.gd —
##     loot_catalog / make_ability): лут выдаёт ровно то, что продаётся,
##     и не даёт лишнего сверх лимита сумки;
##   - или золото.
## Маг пока не может получить ничего (ни сумки, ни золота) — для него находка
## не появляется, охрана остаётся.
##
## Подобранная находка запоминается в слоте сохранения (SaveManager.taken_loot)
## и после перезапуска уровня больше не появляется.
##
## Охрана: сцены врагов в guards встают вокруг находки, когда готов навмеш, и
## бродят на коротком поводке вокруг неё — к луту приходится пробиваться.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const LootUI := preload("res://Levels/loot/loot_ui.gd")
const ABILITY_SOUND := preload("res://Sound/UI_button/accept.wav")
const COIN_SOUND := preload("res://Sound/coin_picking.mp3")

## SPELL — заклинание рыцаря (благословение, Player_scene/magic/spells.gd);
## поднял не рыцарь или уже знает — внутри золото
enum Reward { RANDOM, GOLD, ABILITY, SPELL }
@export var reward := Reward.RANDOM
## SPELL: какое заклинание (имя из Player_scene/magic/spells.gd)
@export var spell_name := ""
## RANDOM: шанс, что внутри способность, а не золото
@export_range(0.0, 1.0) var ability_chance := 0.6
## ABILITY: конкретная способность по имени товара; пусто — случайная
@export var ability_name := ""
@export var gold_min := 40
@export var gold_max := 90
## С какого расстояния (от ног героя) можно подобрать
@export var pickup_radius := 28.0

@export_group("Охрана")
@export var guards: Array[PackedScene] = []
## На каком расстоянии от находки встают охранники
@export var guard_radius := 70.0
## Поводок охраны: дальше этого от находки не забредают, пока не увидят героя
@export var guard_leash := 120.0

## Свечение — белое с едва тёплым оттенком, как у находок в Dark Souls
const GLOW_CORE := Color(1.0, 1.0, 0.98)
const GLOW_MID := Color(0.95, 0.93, 0.86)
## Насколько поднята светящаяся точка над землёй (px)
const HOVER := 7.0

var _taken := false
var _placed := false
var _near := false
var _t := 0.0
var _seed := 0.0
var _wait := 0.0

var _ground: Sprite2D
var _halo: Sprite2D
var _core: Sprite2D
var _spark: Sprite2D
var _beam: Sprite2D
var _motes: GPUParticles2D
var _light: PointLight2D

static var _gold_icon: Texture2D


func _ready() -> void:
	add_to_group("loot")
	_seed = randf() * TAU
	_build_visuals()
	_compensate_for_ambient_tint()
	# Уже подобрана — не мелькает, пока ждём навмеш (охрану всё равно ставим)
	if SaveManager.is_loot_taken(loot_id()):
		_taken = true
		visible = false


func _build_visuals() -> void:
	# Светлое пятно на земле — находка "лежит", а не висит в воздухе
	_ground = _layer(30.0, Color(GLOW_MID, 0.22))
	_ground.scale.y *= 0.42

	_motes = GPUParticles2D.new()
	_motes.amount = 14
	_motes.lifetime = 1.8
	_motes.local_coords = false
	_motes.texture = MageFx.dot()
	_motes.material = MageFx.add_material()
	_motes.visibility_rect = MageFx.VIS_RECT
	_motes.position = Vector2(0, -HOVER)
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.gravity = Vector3(0, -16, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 5.0
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 8.0
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_min = 0.25
	pm.scale_max = 0.6
	pm.scale_curve = MageFx.size_curve(0.25)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.0
	pm.color_ramp = MageFx.ramp([Color(GLOW_CORE, 0.9), Color(GLOW_MID, 0.5), Color(GLOW_MID, 0.0)])
	_motes.process_material = pm
	add_child(_motes)

	# Едва заметный столбик над находкой — видно издалека, где она лежит
	_beam = Sprite2D.new()
	_beam.texture = MageFx.streak()
	_beam.material = MageFx.add_material()
	_beam.modulate = Color(GLOW_MID, 0.16)
	_beam.scale = Vector2(0.45, 0.9)
	_beam.offset = Vector2(0, -24)
	add_child(_beam)

	_halo = _layer(34.0, Color(GLOW_MID, 0.38))
	_core = _layer(12.0, Color(GLOW_CORE, 0.85))
	_spark = _layer(4.0, Color(1.4, 1.4, 1.35, 1.0))
	_spark.texture = MageFx.dot()
	_spark.scale = Vector2.ONE * 4.0 / 8.0
	for s in [_halo, _core, _spark]:
		s.position = Vector2(0, -HOVER)

	_light = PointLight2D.new()
	_light.texture = MageFx.radial()
	_light.texture_scale = 70.0 / 128.0
	_light.color = Color(0.92, 0.94, 1.0)
	_light.energy = 0.45
	_light.position = Vector2(0, -HOVER)
	add_child(_light)


func _layer(size: float, col: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = MageFx.soft()
	s.material = MageFx.add_material()
	s.modulate = col
	s.scale = Vector2.ONE * size / 64.0
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	if not _placed:
		_try_place(delta)
	if _taken:
		return
	_animate()

	var hero := get_tree().get_first_node_in_group("player") as Node2D
	# Расстояние — от ног героя (его точка — в середине фигуры)
	var near := hero != null and (hero.global_position + Vector2(0, 14)).distance_to(global_position) <= pickup_radius
	if near != _near:
		_near = near
		LootUI.of(get_tree()).show_prompt(near)
	if near and Input.is_action_just_pressed("interact"):
		_pick_up(hero)


## Дыхание свечения: ядро мерцает, ореол чуть плывёт, точка покачивается
func _animate() -> void:
	var bob := sin(_t * 2.1 + _seed) * 1.5
	var flick := 0.88 + 0.12 * sin(_t * 13.0 + _seed) + 0.06 * sin(_t * 23.0 + _seed * 2.0)
	for s in [_halo, _core, _spark]:
		s.position.y = -HOVER + bob
	_spark.self_modulate.a = flick
	_core.self_modulate.a = 0.82 + 0.18 * sin(_t * 3.2 + _seed)
	_halo.scale = Vector2.ONE * (34.0 / 64.0) * (1.0 + 0.12 * sin(_t * 1.7 + _seed))
	_beam.self_modulate.a = 0.75 + 0.25 * sin(_t * 1.3 + _seed)
	_light.energy = 0.38 + 0.08 * flick


# ===================== ПОСТАНОВКА И ОХРАНА =====================

## Ждём навмеш (он печётся при старте уровня): находку — на ближайшее
## проходимое место (не в надгробие), охрану — вокруг. Навмеша нет больше
## 3 с (уровень без него) — ставим как есть
func _try_place(delta: float) -> void:
	_wait += delta
	var nav_map := get_world_2d().navigation_map
	var nav_ready := NavigationServer2D.map_get_iteration_id(nav_map) > 0
	if not nav_ready and _wait < 3.0:
		return
	_placed = true
	if nav_ready:
		global_position = _walkable(nav_map, global_position)
	_spawn_guards(nav_map if nav_ready else RID())
	# Уже подобрана в этом сохранении — не появляется. Герою нечего отсюда
	# взять (маг) — тоже не показываем. Охрана стоит в любом случае
	var hero := get_tree().get_first_node_in_group("player")
	if SaveManager.is_loot_taken(loot_id()) or (hero and not _can_reward(hero)):
		_taken = true
		visible = false
		set_process(false)


func _walkable(nav_map: RID, p: Vector2) -> Vector2:
	var s := NavigationServer2D.map_get_closest_point(nav_map, p)
	if not s.is_finite() or s == Vector2.ZERO or s.distance_to(p) > 120.0:
		return p
	return s


func _spawn_guards(nav_map: RID) -> void:
	var n := guards.size()
	for i in n:
		if guards[i] == null:
			continue
		var a := TAU * float(i) / float(n) + _seed
		var p := global_position + Vector2.from_angle(a) * guard_radius * randf_range(0.75, 1.0)
		if nav_map.is_valid():
			p = _walkable(nav_map, p)
		var e: Node2D = guards[i].instantiate()
		# Дом — сама находка, поводок короткий: охрана бродит вокруг неё и
		# подолгу стоит, а не уходит патрулировать карту
		e.set("home_position", global_position)
		e.set("_home_set", true)
		e.set("wander_target", p)
		e.set("wander_pause_timer", randf_range(0.5, 3.0))
		e.set("patrol_leash_radius", guard_leash)
		e.set("wander_step_min", 30.0)
		e.set("wander_step_max", 90.0)
		e.set("wander_pause_min", 1.5)
		e.set("wander_pause_max", 4.0)
		get_parent().add_child(e)
		e.global_position = p


# ===================== ПОДБОР =====================

func _can_reward(hero: Node) -> bool:
	var magic = hero.get("magic")
	if reward == Reward.SPELL and magic and not magic.knows(spell_name):
		return true
	var shop := get_tree().get_first_node_in_group("shop_menu")
	if shop and not shop.loot_catalog(hero).is_empty():
		return true
	return hero.has_method("add_gold") and hero.get("collects_gold") != false


func _pick_up(hero: Node2D) -> void:
	_taken = true
	_near = false
	var ui := LootUI.of(get_tree())
	var shop := get_tree().get_first_node_in_group("shop_menu")
	var catalog: Array = shop.loot_catalog(hero) if shop else []
	var want_ability := reward == Reward.ABILITY or (reward == Reward.RANDOM and randf() < ability_chance)

	# Заклинание рыцаря — в его книгу (и сразу в слот магии, если есть место)
	var magic = hero.get("magic")
	if reward == Reward.SPELL and magic and magic.learn(spell_name):
		var spell: Ability = magic.magic_inventory.get_all().filter(
				func(s): return s.ability_name == spell_name).front()
		ui.show_pickup(spell.icon, spell_name, "Магия  •  Благословение")
		_play(ABILITY_SOUND, -6.0, hero)
		SaveManager.mark_loot_taken(loot_id(), hero)
		_vanish(hero)
		return

	var item: Dictionary = {}
	if want_ability and not catalog.is_empty():
		for it in catalog:
			if it["name"] == ability_name:
				item = it
		if item.is_empty():
			item = catalog.pick_random()

	if not item.is_empty():
		var ab: Ability = shop.make_ability(item["name"])
		hero.inventory_ui.add_item(ab)
		var icon: Texture2D = load(item["icon"]) if ResourceLoader.exists(item["icon"]) else null
		ui.show_pickup(icon, item["name"], item.get("subtitle", "Способность"))
		_play(ABILITY_SOUND, -6.0, hero)
	else:
		var amount := randi_range(gold_min, gold_max)
		hero.add_gold(amount)
		ui.show_pickup(_coin_icon(), "%d золота" % amount, "")
		_play(COIN_SOUND, -10.0, hero)
	# Больше не появится — и сразу на диск вместе с полученным
	SaveManager.mark_loot_taken(loot_id(), hero)
	_vanish(hero)


## Постоянный id находки в сохранении: сцена уровня + путь узла в ней
## (переименуешь узел в редакторе — для сейва это новая находка)
## Через owner (корень уровня), а не current_scene: при загрузке уровня _ready
## находок идёт раньше, чем движок делает уровень текущей сценой
func loot_id() -> String:
	var level := owner if owner else get_tree().current_scene
	if level == null:
		return String(get_path())
	return "%s#%s" % [level.scene_file_path, level.get_path_to(self)]


## Свечение втягивается в героя: короткая вспышка, искры, и всё гаснет
func _vanish(hero: Node2D) -> void:
	_motes.emitting = false
	var h := MageFx.holder(get_tree(), global_position + Vector2(0, -HOVER), 0.7, 13)
	h.modulate = modulate
	MageFx.flash(h, 26.0, 0.2, GLOW_CORE)
	MageFx.burst(h, 10, 0.6, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.spread = 180.0
		pm.initial_velocity_min = 20.0
		pm.initial_velocity_max = 55.0
		pm.damping_min = 50.0
		pm.damping_max = 90.0
		pm.gravity = Vector3(0, -40, 0)
		pm.scale_min = 0.3
		pm.scale_max = 0.7
		pm.color_ramp = MageFx.ramp([Color(GLOW_CORE, 1.0), Color(GLOW_MID, 0.7), Color(GLOW_MID, 0.0)]))
	var t := create_tween().set_parallel()
	for s in [_halo, _core, _spark, _beam, _ground]:
		t.tween_property(s, "modulate:a", 0.0, 0.3)
	t.tween_property(_light, "energy", 0.0, 0.3)
	get_tree().create_timer(_motes.lifetime + 0.3).timeout.connect(queue_free)


func _play(stream: AudioStream, db: float, hero: Node2D) -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db
	hero.get_parent().add_child(p)
	p.global_position = hero.global_position
	p.finished.connect(p.queue_free)
	p.play()


## Иконка золота для окна "Получено" — золотой кружок (своей картинки монет нет)
static func _coin_icon() -> Texture2D:
	if _gold_icon == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.93, 0.6), Color(0.9, 0.68, 0.28), Color(0.62, 0.42, 0.15),
				Color(0.95, 0.78, 0.4), Color(0.95, 0.78, 0.4, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_gold_icon = t
	return _gold_icon


# Ночь красит весь мир через CanvasModulate — без компенсации белое свечение
# ушло бы в зелень. Тот же приём, что у золотых душ (gold_wisp.gd)
func _compensate_for_ambient_tint() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for child in scene.get_children():
		if child is CanvasModulate and child.visible:
			var c: Color = child.color
			modulate = Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)
			return
