extends Node2D
## druid_thorns.gd — Шипы из земли (V, druid.gd::_start_thorns) под ОДНИМ
## врагом. Как столп Эйрика (mage_pillar.gd): сначала под целью проступает
## круг и идёт за ней, потом из земли вырывается пучок шипов с зелёным
## всполохом (шейдер magic_pillar, перекрашенный и короткий), бьёт, держится
## миг и уходит обратно в землю.

const DruidFx := preload("res://Player_scene/druid_fx.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")
const PILLAR_SHADER := preload("res://Shaders/magic_pillar.gdshader")

var damage := 2
var posture := 15.0
## Шанс кровотечения (Кровь на шипах), %
var bleed_chance := 0.0

var _caster: Node2D
var _target: Node2D
var _offset := Vector2.ZERO
var _at := Vector2.ZERO
var _delay := 0.3
var _erupted := false
var _rise := 0.0
var _sink := 0.0
var _spikes: Array = []
var _circle: ShaderMaterial
var _glow: ShaderMaterial

const WIDTH := 34.0
const HEIGHT := 70.0
const THORN_DARK := Color(0.12, 0.26, 0.09)
const THORN_MID := Color(0.24, 0.46, 0.16)


## target — враг или null (тогда шипы встают в at, координаты мира)
func setup(caster: Node2D, target: Node2D, offset: Vector2, at: Vector2, delay: float) -> void:
	_caster = caster
	_target = target
	_offset = offset
	_at = at
	_delay = delay


func _ready() -> void:
	z_index = 11
	global_position = _at
	_follow()
	_circle = DruidFx.circle(self, WIDTH * 1.4, 1.2)
	create_tween().tween_method(func(v: float): _circle.set_shader_parameter("draw", v), 0.0, 1.0, maxf(_delay, 0.1))
	for i in 7:
		var ang := randf_range(-0.55, 0.55)
		_spikes.append({
			"x": randf_range(-WIDTH * 0.42, WIDTH * 0.42),
			"y": randf_range(-4.0, 4.0),
			"h": randf_range(16.0, 34.0) * (1.25 if absf(ang) < 0.2 else 1.0),
			"w": randf_range(3.5, 6.0),
			"lean": ang,
			"lag": randf_range(0.0, 0.3),
		})
	# Задние шипы рисуются раньше передних
	_spikes.sort_custom(func(a, b): return a["y"] < b["y"])
	get_tree().create_timer(_delay).timeout.connect(_erupt)


func _process(_delta: float) -> void:
	if not _erupted:
		_follow()
	queue_redraw()


func _follow() -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position + _offset


func _erupt() -> void:
	_erupted = true
	# Зелёный всполох — короткий столп из шейдера мага
	var flame := Sprite2D.new()
	flame.texture = DruidFx.white()
	flame.scale = Vector2(WIDTH, HEIGHT) / 4.0
	flame.position = Vector2(0, -HEIGHT * 0.5 + 6.0)
	_glow = ShaderMaterial.new()
	_glow.shader = PILLAR_SHADER
	_glow.set_shader_parameter("noise_tex", MageFx.noise_tex())
	_glow.set_shader_parameter("seed", randf() * 10.0)
	_glow.set_shader_parameter("aspect", HEIGHT / WIDTH)
	_glow.set_shader_parameter("rise", 0.0)
	_glow.set_shader_parameter("intensity", 0.6)
	_glow.set_shader_parameter("color_core", DruidFx.CORE)
	_glow.set_shader_parameter("color_mid", DruidFx.MID)
	_glow.set_shader_parameter("color_edge", DruidFx.EDGE)
	flame.material = _glow
	add_child(flame)
	# Шипы — над всполохом
	flame.z_index = -1

	DruidFx.flash(self, WIDTH * 1.4, 0.16)
	DruidFx.dirt(self, 12, 170.0, 0.55)
	DruidFx.sparks(self, 10, 240.0, 0.4, Vector2.UP, 25.0)
	DruidFx.leaves(self, 5, 90.0, 0.8, Vector2.UP, 50.0)
	var lit := Node2D.new()
	lit.position = Vector2(0, -HEIGHT * 0.3)
	add_child(lit)
	DruidFx.light_pulse(lit, 70.0, 1.9, 0.7)
	_hit()

	var t := create_tween()
	t.tween_property(self, "_rise", 1.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_method(func(v: float): _glow.set_shader_parameter("rise", v), 0.0, 1.0, 0.14)
	t.tween_interval(0.35)
	t.tween_method(func(v: float): _glow.set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	t.parallel().tween_method(func(v: float): _circle.set_shader_parameter("fade", v), 1.0, 0.0, 0.4)
	t.parallel().tween_property(self, "_sink", 1.0, 0.4).set_ease(Tween.EASE_IN)
	t.tween_interval(0.6)
	t.tween_callback(queue_free)


func _hit() -> void:
	if not is_instance_valid(_target) or _target.get("is_dead") == true:
		return
	if "player" in _target and _target.player == null and is_instance_valid(_caster):
		_target.player = _caster
	_target.take_damage(damage, _caster)
	if is_instance_valid(_target) and _target.has_method("take_posture_damage"):
		_target.take_posture_damage(posture)
	if bleed_chance > 0.0 and randf() * 100.0 < bleed_chance and is_instance_valid(_target) \
			and _target.has_method("take_bleed_damage"):
		_target.take_bleed_damage(1, _caster)
	DruidFx.hit_burst(get_tree(), global_position + Vector2(0, -14), Vector2.UP)


func _draw() -> void:
	if not _erupted:
		return
	for s in _spikes:
		var g := clampf((_rise - s["lag"] * 0.5) / (1.0 - s["lag"] * 0.5), 0.0, 1.2)
		var h: float = s["h"] * g * (1.0 - _sink)
		if h < 1.0:
			continue
		var base := Vector2(s["x"], s["y"])
		var tip := base + Vector2(sin(s["lean"]) * h, -cos(s["lean"]) * h)
		var side := Vector2(s["w"] * 0.5, 0)
		var pts := PackedVector2Array([base - side, tip, base + side])
		draw_colored_polygon(pts, THORN_DARK)
		# Светлая грань с одной стороны — объём
		draw_colored_polygon(PackedVector2Array([base, tip, base + side]), THORN_MID)
		# Светящаяся кромка и кончик
		var a := 1.0 - _sink
		draw_line(base - side, tip, Color(DruidFx.MID, 0.75 * a), 1.0, true)
		draw_circle(tip, 1.3, Color(DruidFx.CORE, 0.9 * a))
