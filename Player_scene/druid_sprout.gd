extends Node2D
## druid_sprout.gd — Росток жизни Сольвейг (F, druid.gd::_start_sprout).
## Пятно травы на земле с цветком посередине: раз в tick секунд лечит всех
## героев (группа "player") в радиусе и, если открыты Цепкие лепестки,
## замедляет врагов внутри. Живёт life секунд, потом увядает.
##
## Каркас: прочности у ростка пока нет — враги его не ломают (узел дерева
## «Живучий цветок», sprout_hp_percent, ждёт этого)

## Кто посадил — его метод _heal_target лечит с бонусами дерева
var druid: Node2D
var radius := 70.0
var life := 8.0
## Лечение за тик — доля максимального здоровья цели, %
var heal_percent := 3.0
var tick := 1.0
## Замедление врагов внутри, % (0 — нет)
var slow_percent := 0.0

const GRASS := Color(0.28, 0.62, 0.22, 0.32)
const EDGE := Color(0.5, 0.9, 0.35, 0.55)
const PETAL := Color(0.95, 0.85, 0.45)
## Вид 3/4: круг на земле сплюснут по вертикали (как кольца мага)
const SQUASH := 0.8

const DruidFx := preload("res://Player_scene/druid_fx.gd")

var _t := 0.0
var _next_tick := 0.4
var _grow := 0.0
var _fade := 1.0
## Волна от цветка на каждом лечении (0..1, растёт)
var _wave := 1.0
var _circle: ShaderMaterial
var _light: PointLight2D
var _pollen: GPUParticles2D
var _top: Node2D


func _ready() -> void:
	z_as_relative = false
	z_index = -15
	_circle = DruidFx.circle(self, radius * 2.1, 0.5, -16)
	create_tween().tween_method(func(v: float): _circle.set_shader_parameter("draw", v), 0.0, 1.0, 0.4)
	# Свет и пыльца — над персонажами, у самого цветка
	_top = Node2D.new()
	_top.z_as_relative = false
	_top.z_index = 11
	add_child(_top)
	_light = DruidFx.light(_top, radius * 1.3, 0.0)
	create_tween().tween_property(_light, "energy", 1.0, 0.4)
	_pollen = _make_pollen()
	DruidFx.flash(_top, radius, 0.25)
	DruidFx.leaves(_top, 10, 80.0, 0.9)
	DruidFx.light_pulse(_top, radius * 1.6, 2.0, 0.5)


func _make_pollen() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = 22
	p.lifetime = 1.6
	p.local_coords = false
	p.texture = DruidFx.MageFx.dot()
	p.material = DruidFx.MageFx.add_material()
	p.visibility_rect = DruidFx.MageFx.VIS_RECT
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius * 0.8, radius * 0.8 * SQUASH, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(0, -8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.scale_curve = DruidFx.MageFx.size_curve(0.3)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.color_ramp = DruidFx.ramp_glow()
	p.process_material = pm
	_top.add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	_grow = minf(_grow + delta * 3.0, 1.0)
	_wave = minf(_wave + delta * 1.6, 1.0)
	if _t >= life:
		if _pollen.emitting:
			_pollen.emitting = false
		_fade = maxf(_fade - delta * 2.0, 0.0)
		_circle.set_shader_parameter("fade", _fade)
		_light.energy = _fade
		if _fade <= 0.0:
			queue_free()
			return
	else:
		_light.energy = 0.9 + 0.15 * sin(_t * 3.0) + 0.4 * (1.0 - _wave)
		_next_tick -= delta
		if _next_tick <= 0.0:
			_next_tick = tick
			_pulse()
	queue_redraw()


func _pulse() -> void:
	_wave = 0.0
	var tree := get_tree()
	for p in tree.get_nodes_in_group("player"):
		if not (p is Node2D) or not _inside((p as Node2D).global_position):
			continue
		if p.has_method("is_dead") and p.is_dead():
			continue
		var max_hp: float = float(p.get("max_health")) if p.get("max_health") != null else 100.0
		var amount := max_hp * heal_percent / 100.0
		var h := DruidFx.holder(tree, (p as Node2D).global_position + Vector2(0, -8), 1.0, 12)
		DruidFx.pollen(h, 6, 8.0, 0.9, 34.0)
		if is_instance_valid(druid) and druid.has_method("_heal_target"):
			druid._heal_target(p, amount)
		elif p.has_method("heal"):
			p.heal(amount)
	if slow_percent > 0.0:
		for e in tree.get_nodes_in_group("enemy"):
			if e is Node2D and e.has_method("apply_slow") and _inside((e as Node2D).global_position):
				e.apply_slow(slow_percent, tick + 0.2)


func _inside(pos: Vector2) -> bool:
	var to := pos - global_position
	return Vector2(to.x, to.y / SQUASH).length() <= radius


func _draw() -> void:
	var r := radius * (0.4 + 0.6 * _grow)
	var a := _fade
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, r, Color(GRASS, GRASS.a * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(EDGE, EDGE.a * a * (0.6 + 0.4 * pulse)), 2.0)
	# Волна лечения расходится от цветка к краю
	if _wave < 1.0:
		draw_arc(Vector2.ZERO, r * _wave, 0.0, TAU, 48, Color(DruidFx.CORE, 0.6 * (1.0 - _wave) * a), 2.5)
	# Травинки по кругу
	for i in 14:
		var ang := TAU * i / 14.0 + 0.3
		var p := Vector2(cos(ang), sin(ang)) * r * 0.82
		draw_line(p, p + Vector2(0, -6 - 3 * sin(_t * 2.0 + i)), Color(EDGE, a * 0.8), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Цветок посередине
	var stem := Vector2(0, -10 * _grow)
	draw_line(Vector2.ZERO, stem, Color(0.35, 0.7, 0.25, a), 2.0)
	for i in 5:
		var ang := TAU * i / 5.0 + _t * 0.4
		draw_circle(stem + Vector2(cos(ang), sin(ang)) * 3.5 * _grow, 2.6 * _grow, Color(PETAL, a))
	draw_circle(stem, 2.0 * _grow, Color(1.0, 0.95, 0.7, a))
