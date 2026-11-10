extends Node2D
## druid_roots.gd — корни Оков (B, druid.gd::_start_binding): связывают ОДНОГО
## врага. Живут в мире, у его ног (враг стоит — корни не отстают).
##
## Порядок: под целью проступает светло-зелёный рунный круг, пока Сольвейг
## поднимает руки -> через delay из круга с комьями земли и листьями
## вырываются корни, обвивают ноги и держат (enemy.apply_root) -> всё время
## держания по жилкам корней бежит свет, поднимается пыльца -> корни
## темнеют, уходят обратно в землю и пропадают.
##
## Корни рисуются кодом (_draw): каждая — изогнутая ломаная, сужается к
## кончику; кора тёмная, по ней — светящаяся жилка. Передние корни (перед
## ногами) — над врагом, задние — под ним (_back рисует их отдельно).

const DruidFx := preload("res://Player_scene/druid_fx.gd")

## Сколько держат, урон и стойкость в момент хватки
var hold_time := 3.0
var damage := 1
var posture := 20.0
## Ширина «обхвата» вокруг ног и высота корней
var girth := 15.0
var height := 30.0

var _caster: Node2D
var _target: Node2D
var _offset := Vector2.ZERO
var _delay := 0.4
var _erupted := false
var _grow := 0.0
var _wither := 0.0
var _t := 0.0
var _roots: Array = []
var _back: Node2D
var _circle: ShaderMaterial
var _light: PointLight2D
var _pollen: GPUParticles2D

const ROOT_COUNT := 9
## Кора корней — не аддитивная, поэтому темнее фона только чуть: ночью иначе
## корень терялся бы и оставалась одна светящаяся жилка
const BARK_DARK := Color(0.3, 0.22, 0.12)
const BARK_LIT := Color(0.5, 0.4, 0.22)


## target — враг, offset — точка под его ногами относительно узла, delay —
## через сколько секунд корни вырвутся
func setup(caster: Node2D, target: Node2D, offset: Vector2, delay: float) -> void:
	_caster = caster
	_target = target
	_offset = offset
	_delay = delay


func _ready() -> void:
	z_index = 11
	_follow()
	# Задний слой корней — под персонажами, над землёй
	_back = Node2D.new()
	_back.z_as_relative = false
	_back.z_index = -14
	_back.draw.connect(_draw_layer.bind(_back, false))
	add_child(_back)
	_build_roots()
	_circle = DruidFx.circle(self, girth * 3.4, 1.6)
	create_tween().tween_method(func(v: float): _circle.set_shader_parameter("draw", v), 0.0, 1.0, maxf(_delay * 0.8, 0.12))
	# Слабый свет с первого мига — видно, куда ударит
	_light = DruidFx.light(self, 46.0, 0.0)
	create_tween().tween_property(_light, "energy", 0.7, _delay)
	get_tree().create_timer(_delay).timeout.connect(_erupt)


## Корни: угол вокруг ног (сплюснутый круг), наклон к центру, длина, изгиб.
## Углы вперемешку, чтобы и спереди, и сзади было поровну
func _build_roots() -> void:
	for i in ROOT_COUNT:
		var ang := TAU * (i + randf_range(-0.25, 0.25)) / ROOT_COUNT
		_roots.append({
			"base": Vector2(cos(ang) * girth, sin(ang) * girth * 0.55),
			"front": sin(ang) > -0.1,
			"len": height * randf_range(0.65, 1.1),
			"curl": randf_range(-1.0, 1.0),
			"width": randf_range(3.6, 5.4),
			"phase": randf() * TAU,
			"lag": randf_range(0.0, 0.25),
		})


func _process(delta: float) -> void:
	_t += delta
	_follow()
	if _light and _erupted and _wither <= 0.0:
		_light.energy = 1.25 + 0.2 * sin(_t * 4.0) + 0.1 * sin(_t * 9.0)
	queue_redraw()
	_back.queue_redraw()


func _follow() -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position + _offset


func _erupt() -> void:
	if not is_instance_valid(_target) or _target.get("is_dead") == true:
		_finish_fast()
		return
	_erupted = true
	# Хватка: стоит, получает урон и удар по стойкости
	if _target.has_method("apply_root"):
		_target.apply_root(hold_time)
	elif _target.has_method("apply_slow"):
		_target.apply_slow(90.0, hold_time)
	if "player" in _target and _target.player == null and is_instance_valid(_caster):
		_target.player = _caster
	if damage > 0 and _target.has_method("take_damage"):
		_target.take_damage(damage, _caster)
	if is_instance_valid(_target) and _target.has_method("take_posture_damage"):
		_target.take_posture_damage(posture)

	# Вырывание: вспышка у земли, комья, листья, искры вверх, свет
	DruidFx.flash(self, girth * 3.2, 0.2)
	DruidFx.dirt(self, 14, 150.0, 0.6)
	DruidFx.leaves(self, 8, 110.0, 0.9, Vector2.UP, 60.0)
	DruidFx.sparks(self, 10, 200.0, 0.4, Vector2.UP, 35.0)
	DruidFx.light_pulse(self, 80.0, 2.0, 0.4)
	_pollen = _make_pollen()
	if is_instance_valid(_caster) and _caster.has_method("shake_camera"):
		_caster.shake_camera(2.0, 0.12)

	var t := create_tween()
	t.tween_property(self, "_grow", 1.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_interval(maxf(hold_time - 0.28 - 0.45, 0.1))
	t.tween_callback(_start_wither)
	t.tween_property(self, "_wither", 1.0, 0.45).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_light, "energy", 0.0, 0.45)
	t.parallel().tween_method(func(v: float): _circle.set_shader_parameter("fade", v), 1.0, 0.0, 0.45)
	t.tween_interval(1.0)
	t.tween_callback(queue_free)


func _start_wither() -> void:
	if _pollen:
		_pollen.emitting = false
	DruidFx.leaves(self, 6, 40.0, 1.1, Vector2.UP, 90.0)
	DruidFx.dirt(self, 6, 60.0, 0.5)


## Цель погибла или пропала до вырывания — круг просто гаснет
func _finish_fast() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float): _circle.set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	t.tween_property(_light, "energy", 0.0, 0.3)
	t.chain().tween_callback(queue_free)


## Пыльца поднимается от корней, пока держат
func _make_pollen() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = 14
	p.lifetime = 1.2
	p.local_coords = false
	p.texture = DruidFx.MageFx.dot()
	p.material = DruidFx.MageFx.add_material()
	p.visibility_rect = DruidFx.MageFx.VIS_RECT
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = girth
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.scale_curve = DruidFx.MageFx.size_curve(0.3)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.color_ramp = DruidFx.ramp_glow()
	p.process_material = pm
	p.position = Vector2(0, -6)
	add_child(p)
	return p


func _draw() -> void:
	# Свечение земли под корнями
	if _erupted:
		var a := (1.0 - _wither) * _grow
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, girth * 1.5, Color(DruidFx.EDGE, 0.16 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_layer(self, true)


## Корни одного слоя: передние (front = true) или задние
func _draw_layer(canvas: CanvasItem, front: bool) -> void:
	if not _erupted:
		return
	for r in _roots:
		if r["front"] != front:
			continue
		var g := clampf((_grow - r["lag"]) / (1.0 - r["lag"]), 0.0, 1.0)
		var reach: float = r["len"] * g * (1.0 - 0.85 * _wither)
		if reach < 1.0:
			continue
		var pts := _root_points(r, reach)
		var w: float = r["width"]
		var lit := 1.0 - _wither
		# Тёмный контур — корень читается на любом фоне
		for i in pts.size() - 1:
			var k := float(i) / (pts.size() - 1)
			canvas.draw_line(pts[i], pts[i + 1], Color(0.06, 0.05, 0.03, 0.85), maxf(w * (1.0 - k * 0.8), 0.8) + 1.6, true)
		# Кора: от толстого основания к тонкому кончику
		for i in pts.size() - 1:
			var k := float(i) / (pts.size() - 1)
			var col := BARK_DARK.lerp(BARK_LIT, k * 0.6)
			col = col.lerp(Color(0.12, 0.1, 0.07), _wither)
			canvas.draw_line(pts[i], pts[i + 1], col, maxf(w * (1.0 - k * 0.8), 0.8), true)
		# Светящаяся жилка поверх коры, по ней бежит свет
		if lit > 0.0:
			for i in pts.size() - 1:
				var k := float(i) / (pts.size() - 1)
				var wave := 0.55 + 0.45 * sin(_t * 6.0 - k * 6.0 + r["phase"])
				var c := DruidFx.MID.lerp(DruidFx.CORE, wave * 0.6)
				c.a = lit * (0.55 + 0.45 * wave) * (1.0 - k * 0.3)
				canvas.draw_line(pts[i], pts[i + 1], c, maxf(w * 0.35 * (1.0 - k * 0.6), 0.6), true)
			# Огонёк на кончике
			canvas.draw_circle(pts[pts.size() - 1], 1.4, Color(DruidFx.CORE, lit * 0.9))


## Ломаная корня: из земли вверх, к ногам, с изгибом и лёгким покачиванием
func _root_points(r: Dictionary, reach: float) -> PackedVector2Array:
	var base: Vector2 = r["base"]
	var pts := PackedVector2Array()
	var steps := 8
	var sway := sin(_t * 2.2 + r["phase"]) * 1.5 * (1.0 - _wither)
	for i in steps + 1:
		var k := float(i) / steps
		# Тянется вверх и к центру — обхватывает ноги
		var inward := -base * 0.55 * k
		var curl := Vector2(r["curl"] * sin(k * PI * 1.3) * 7.0 + sway * k, 0.0)
		pts.append(base + inward + curl + Vector2(0, -reach * k))
	return pts
