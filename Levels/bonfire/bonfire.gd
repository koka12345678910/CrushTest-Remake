extends Node2D
## bonfire.gd — костёр как в Dark Souls 3.
##
## Незажжённый: каменное кольцо с золой и воткнутый в неё меч, едва тлеет.
## Подойти и нажать E (действие "interact"):
##   - первый раз — «Зажечь костёр»: вспышка, надпись «КОСТЁР ЗАЖЖЁН»,
##     костёр запоминается в сейве;
##   - дальше — «Отдохнуть у костра»: здоровье, выносливость, Одр/Сейд и
##     концентрация полные, все враги уровня возрождаются на исходных местах
##     (bonfire_world.gd), костёр становится точкой появления, игра
##     сохраняется, открывается панель костра (bonfire_ui.gd): перемещение
##     между зажжёнными кострами, сумка, «Покинуть костёр».
## Как в DS3, отдыхать нельзя, пока рядом враг тебя видит.
##
## Костры находят друг друга по группе "bonfire"; id в сейве — сцена уровня +
## путь узла (как у лута, loot_item.gd::loot_id): переименуешь узел — для
## сейва это новый костёр.

const BonfireWorld := preload("res://Levels/bonfire/bonfire_world.gd")
const BonfireUI := preload("res://Levels/bonfire/bonfire_ui.gd")
const LootUI := preload("res://Levels/loot/loot_ui.gd")
const CampfireScene := preload("res://Levels/props/campfire.tscn")
const GP_SHEET := preload("res://TileMap/ground/ground_&_props.png")
## Каменное кольцо с поленьями из листа ground_&_props (то же, что у
## костров лагеря в генераторе, graveyard_generator.gd GP_SPR "campfire_ring")
const RING_RECT := Rect2(471, 767, 68, 65)
const KINDLE_SOUND := preload("res://Sound/pulse.mp3")
const REST_SOUND := preload("res://Sound/ambient_sound/recover_breath.mp3")

## Имя в панели и в списке перемещения
@export var bonfire_name := "Костёр"
## Где встаёт герой, отдыхая и появляясь у костра (от центра костра)
@export var rest_offset := Vector2(30, 16)
## С какого расстояния (от ног героя) можно взаимодействовать
@export var interact_radius := 46.0
## Враг, который видит героя ближе этого, не даёт отдохнуть
@export var enemy_block_radius := 420.0
@export var ring_scale := 0.6
## Слой кольца камней. -17 — сразу над землёй кладбища (её слои на -19..-18).
## У карт, где земля лежит на z 0 (reference_map), кольцо с -17 ушло бы под
## тайлы — там ставится 0
@export var ring_z_index := -17

var lit := false
var _near := false
var _flame: Node2D
var _ember_light: PointLight2D
var _smolder: CPUParticles2D
var _sword: Node2D
var _t := 0.0


func _ready() -> void:
	add_to_group("bonfire")
	_build_visuals()
	var level := owner if owner else get_parent()
	BonfireWorld.of(get_tree(), level)
	lit = SaveManager.is_bonfire_lit(bonfire_id())
	_apply_lit(lit, false)


## Постоянный id костра в сохранении (см. шапку)
func bonfire_id() -> String:
	var level := owner if owner else get_tree().current_scene
	if level == null:
		return String(get_path())
	return "%s#%s" % [level.scene_file_path, level.get_path_to(self)]


func rest_position() -> Vector2:
	return global_position + rest_offset


static func find(tree: SceneTree, id: String) -> Node2D:
	for b in tree.get_nodes_in_group("bonfire"):
		if b.bonfire_id() == id:
			return b
	return null


# ===================== ВИД =====================

func _build_visuals() -> void:
	# Кольцо камней с золой — плоско на земле, под всем
	var ring := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = GP_SHEET
	at.region = RING_RECT
	ring.texture = at
	ring.scale = Vector2.ONE * ring_scale
	ring.position = Vector2(0, 2)
	ring.z_index = ring_z_index
	add_child(ring)

	# Меч, воткнутый в золу — сортируется с героем по точке костра
	_sword = _make_sword()
	add_child(_sword)

	# Тление: пара искр и слабый жар, пока костёр не зажжён
	_ember_light = PointLight2D.new()
	_ember_light.texture = _radial(64)
	_ember_light.color = Color(1.0, 0.45, 0.18)
	_ember_light.energy = 0.35
	_ember_light.texture_scale = 0.9
	_ember_light.position = Vector2(0, -2)
	add_child(_ember_light)
	_smolder = CPUParticles2D.new()
	_smolder.amount = 6
	_smolder.lifetime = 1.6
	_smolder.position = Vector2(0, -2)
	_smolder.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smolder.emission_sphere_radius = 6.0
	_smolder.direction = Vector2(0, -1)
	_smolder.spread = 25.0
	_smolder.gravity = Vector2(0, -8)
	_smolder.initial_velocity_min = 4.0
	_smolder.initial_velocity_max = 10.0
	_smolder.scale_amount_min = 0.8
	_smolder.scale_amount_max = 1.4
	_smolder.color_ramp = _ramp([Color(1, 0.6, 0.25, 0.9), Color(1, 0.3, 0.1, 0.0)])
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_smolder.material = mat
	add_child(_smolder)


## Меч в золе: клинок под небольшим наклоном, гарда, рукоять в обмотке и
## навершие. Рисуется полигонами, чтобы не зависеть от спрайта
func _make_sword() -> Node2D:
	var s := Node2D.new()
	s.position = Vector2(1, -1)
	s.rotation = deg_to_rad(-6)
	var steel_dark := Color(0.32, 0.31, 0.3)
	var steel := Color(0.56, 0.55, 0.52)
	var edge := Color(0.78, 0.76, 0.7)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(1.4, -15), Vector2(-1.4, -15)])
	blade.color = steel
	s.add_child(blade)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(0.6, -1), Vector2(0.6, -15)])
	line.width = 0.8
	line.default_color = edge
	s.add_child(line)
	var guard := Polygon2D.new()
	guard.polygon = PackedVector2Array([Vector2(-5, -15), Vector2(5, -15), Vector2(4.5, -17), Vector2(-4.5, -17)])
	guard.color = steel_dark
	s.add_child(guard)
	var grip := Polygon2D.new()
	grip.polygon = PackedVector2Array([Vector2(-1.1, -17), Vector2(1.1, -17), Vector2(1.1, -24), Vector2(-1.1, -24)])
	grip.color = Color(0.22, 0.14, 0.09)
	s.add_child(grip)
	# Обмотка — витой спиралью, как у меча в костре Dark Souls
	var coil := Line2D.new()
	coil.points = PackedVector2Array([Vector2(-1.4, -3), Vector2(1.6, -5), Vector2(-1.4, -7), Vector2(1.6, -9), Vector2(-1.4, -11)])
	coil.width = 0.9
	coil.default_color = Color(0.2, 0.17, 0.15)
	s.add_child(coil)
	var pommel := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(Vector2.from_angle(TAU * i / 8.0) * 1.8 + Vector2(0, -25.5))
	pommel.polygon = pts
	pommel.color = steel_dark
	s.add_child(pommel)
	return s


func _apply_lit(on: bool, animate: bool) -> void:
	lit = on
	_smolder.emitting = not on
	_ember_light.visible = not on
	if on and _flame == null:
		_flame = CampfireScene.instantiate()
		_flame.position = Vector2(0, -1)
		add_child(_flame)
		move_child(_flame, _sword.get_index())
		if animate:
			_flame.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_property(_flame, "scale", Vector2.ONE * 1.45, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_flame, "scale", Vector2.ONE * 1.15, 0.6)
		else:
			_flame.scale = Vector2.ONE * 1.15


# ===================== ВЗАИМОДЕЙСТВИЕ =====================

func _process(delta: float) -> void:
	_t += delta
	if not lit:
		_ember_light.energy = 0.3 + 0.08 * sin(_t * 3.1) + 0.05 * sin(_t * 7.3)
	var ui := BonfireUI.of(get_tree())
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	var near: bool = hero != null and not ui.is_busy() and not bool(hero.get("is_in_shop")) \
			and (hero.global_position + Vector2(0, 14)).distance_to(global_position) <= interact_radius
	if near != _near:
		_near = near
		LootUI.of(get_tree()).show_prompt(near, "Отдохнуть у костра" if lit else "Зажечь костёр")
	if near and Input.is_action_just_pressed("interact"):
		_interact(hero)


func _interact(hero: Node2D) -> void:
	if not lit:
		_kindle(hero)
		return
	if _enemy_nearby():
		LootUI.of(get_tree()).show_pickup(null, "Нельзя отдохнуть", "Рядом враги")
		return
	_near = false
	LootUI.of(get_tree()).show_prompt(false)
	BonfireUI.of(get_tree()).open_rest(self, hero)


func _kindle(hero: Node2D) -> void:
	_apply_lit(true, true)
	SaveManager.mark_bonfire_lit(bonfire_id(), hero)
	_play(KINDLE_SOUND, -2.0, 0.55)
	_burst()
	Juice.shake(3.0)
	Juice.flash(0.18)
	BonfireUI.of(get_tree()).show_banner("КОСТЁР ЗАЖЖЁН")
	# Подсказка сменится на «Отдохнуть» на следующем кадре
	_near = false
	LootUI.of(get_tree()).show_prompt(false)


## Видит ли героя кто-то из живых врагов поблизости
func _enemy_nearby() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if e.get("see_player") == true and global_position.distance_to(e.global_position) <= enemy_block_radius:
			return true
	return false


## Отдых: всё восполняется, мир возрождается, костёр — точка появления, сейв.
## Зовёт панель (bonfire_ui.gd) под затемнением экрана
func rest(hero: Node2D) -> void:
	var world := get_parent().get_node_or_null("BonfireWorld")
	if world == null and owner:
		world = owner.get_node_or_null("BonfireWorld")
	# Мир возрождается от отдыха одного или хоста коопа. Враги в коопе у хоста:
	# его сброс сам разойдётся всем (Net: список врагов), а сброс у клиента
	# выкинул бы копии врагов и поставил своих, которых нет у хоста
	if world and not Net.is_client():
		world.reset()
	restore_hero(hero)
	SaveManager.set_last_bonfire(bonfire_id(), hero)
	_play(REST_SOUND, -6.0, 1.0)


## Восполнить героя: здоровье, выносливость, Одр/Сейд, концентрацию, кулдауны
static func restore_hero(hero: Node) -> void:
	var bar = hero.get("health_bar")
	if bar:
		bar.heal(bar.max_hp)
		bar.current_stamina = bar.max_stamina
		bar.set_posture(0.0)
	if "health" in hero and "max_health" in hero:
		hero.health = hero.max_health
	if "current_posture" in hero:
		hero.current_posture = 0.0
	var magic = hero.get("magic")
	if magic and "odr" in magic and "max_odr" in magic:
		magic.odr = magic.max_odr
	if "seid" in hero and "max_seid" in hero:
		hero.seid = hero.max_seid
	# Рост Сольвейг (druid.gd) и её Второе дыхание — снова готово
	if "growth" in hero and "max_growth" in hero:
		hero.growth = hero.max_growth
	if "second_breath_used" in hero:
		hero.second_breath_used = false
	var slots = hero.get("ability_system")
	if slots and "abilities" in slots:
		for ab in slots.abilities:
			if ab and "_cooldown_timer" in ab:
				ab._cooldown_timer = 0.0
	if hero.has_method("clear_negative_effects"):
		hero.clear_negative_effects()


# ===================== ЭФФЕКТЫ =====================

func _burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 36
	p.lifetime = 0.9
	p.position = Vector2(0, -6)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 30)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color_ramp = _ramp([Color(1, 0.85, 0.5, 1), Color(1, 0.45, 0.12, 0.9), Color(0.8, 0.2, 0.05, 0)])
	p.material = _smolder.material
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var light := PointLight2D.new()
	light.texture = _radial(64)
	light.color = Color(1.0, 0.6, 0.3)
	light.energy = 2.2
	light.texture_scale = 3.0
	light.position = Vector2(0, -6)
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "energy", 0.0, 0.7)
	tw.tween_callback(light.queue_free)


func _play(stream: AudioStream, db: float, pitch: float) -> void:
	var a := AudioStreamPlayer2D.new()
	a.stream = stream
	a.volume_db = db
	a.pitch_scale = pitch
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g


static func _radial(size: int) -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.gradient = _ramp([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	return t
