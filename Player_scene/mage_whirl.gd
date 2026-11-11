extends Node2D
## mage_whirl.gd — «Вихрь» (руна Йера, F): маг крутится, вокруг него
## поднимается ледяная метель. Висит на маге (следует за ним). По кадрам клипа
## Whirl_ (лист Attack2, 15 к/с: 2-5 подъём, 6-12 вращение, 13-15 выход):
##   spin_from — вихрь набирает силу и начинает ТЯНУТЬ врагов к магу (по
##               спирали, не прямо — их закручивает);
##   tick_frames — удары льдом по всем внутри (урон + озноб);
##   blast_frame — вихрь срывается наружу: осколки, отброс, иней на земле.
## Дуги вращения разделены на две половины: задняя — за магом, передняя —
## перед ним (вид 3/4), иначе кольцо лежало бы целиком поверх героя.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const IceFx := preload("res://Player_scene/mage_ice_fx.gd")
const SoundBank := preload("res://Levels/sound_bank.gd")

var caster: Node2D
var damage := 1
var radius := 70.0
var pull_radius := 120.0
var pull_speed := 150.0
var blast_push := 280.0
var slow_pct := 40.0
var slow_sec := 1.6
var frame := 1.0 / 15.0
var spin_from := 4.5
var tick_frames := [7.0, 10.0]
var blast_frame := 11.5
var alive_check: Callable
## Где ноги мага относительно этого узла (узел — в центре тела)
var feet_offset := Vector2(0, 20)

## 0..1 — сила вихря (видимость дуг, частиц, тяга)
var _power := 0.0
var _t := 0.0
var _pulling := false
var _done := false
var _back: Node2D
var _front: Node2D
var _orbit: GPUParticles2D
var _light: PointLight2D
## Сплющивание кольца по вертикали (вид 3/4)
const SQUASH := 0.55
## [радиус, скорость рад/с, длина дуги рад, толщина, сдвиг фазы]
const ARCS := [
	[30.0, 11.0, 2.4, 5.5, 0.0],
	[40.0, 10.0, 2.0, 3.0, 3.3],
	[48.0, 9.0, 2.8, 4.5, 2.1],
	[60.0, 7.5, 2.2, 3.5, 4.2],
	[66.0, 6.5, 1.4, 2.0, 0.9],
	[52.0, -6.0, 1.3, 2.0, 1.0],
]


func setup(caster_: Node2D, dmg: int, frame_: float, feet: Vector2) -> void:
	caster = caster_
	damage = dmg
	frame = frame_
	feet_offset = feet


func _ready() -> void:
	_back = Node2D.new()
	_back.z_index = -1
	_back.material = MageFx.add_material()
	_back.draw.connect(_draw_arcs.bind(_back, false))
	add_child(_back)
	_front = Node2D.new()
	_front.z_index = 1
	_front.material = MageFx.add_material()
	_front.draw.connect(_draw_arcs.bind(_front, true))
	add_child(_front)

	_light = PointLight2D.new()
	_light.texture = MageFx.radial()
	_light.texture_scale = 220.0 / 128.0
	_light.color = IceFx.MID
	_light.energy = 0.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)
	_run()


func _run() -> void:
	await get_tree().create_timer(spin_from * frame).timeout
	if not _ok():
		_fade_out()
		return
	_start_spin()
	var last := spin_from
	for tf in tick_frames:
		await get_tree().create_timer(maxf(float(tf) - last, 0.0) * frame).timeout
		last = float(tf)
		if not _ok():
			_fade_out()
			return
		_tick()
	await get_tree().create_timer(maxf(blast_frame - last, 0.0) * frame).timeout
	if not _ok():
		_fade_out()
		return
	_blast()
	_fade_out()


func _ok() -> bool:
	return not _done and is_instance_valid(caster) and (not alive_check.is_valid() or alive_check.call())


func _start_spin() -> void:
	_pulling = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_power", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(_light, "energy", 1.2, 0.2)
	# Снег и осколки по орбите — локальные координаты: кружат вокруг мага и
	# идут за ним
	_orbit = GPUParticles2D.new()
	_orbit.amount = 46
	_orbit.lifetime = 0.7
	_orbit.local_coords = true
	_orbit.texture = IceFx.shard_tex()
	_orbit.material = MageFx.add_material()
	_orbit.visibility_rect = MageFx.VIS_RECT
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = 52.0
	pm.emission_ring_inner_radius = 22.0
	pm.emission_ring_height = 0.0
	pm.orbit_velocity_min = 1.4
	pm.orbit_velocity_max = 2.2
	pm.radial_velocity_min = -10.0
	pm.radial_velocity_max = 20.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.18
	pm.scale_max = 0.38
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.color_ramp = MageFx.ramp([Color(IceFx.CORE, 0.0), Color(IceFx.CORE, 0.95), Color(IceFx.EDGE, 0.0)], [0.0, 0.2, 1.0])
	_orbit.process_material = pm
	_orbit.scale = Vector2(1.0, SQUASH)
	add_child(_orbit)
	_orbit.emitting = true
	IceFx.mist(self, 8, 30.0, 34.0, 0.9, 0.16)
	SoundBank.play_at(get_tree(), "roots", global_position, -8.0, 1.25)


func _physics_process(delta: float) -> void:
	_t += delta
	_back.queue_redraw()
	_front.queue_redraw()
	if not _pulling or _done or not is_instance_valid(caster):
		return
	# Тяга: к центру вихря и вбок — врагов закручивает по спирали. Ближе
	# 26 px не тянет — вплотную к магу не прилипают
	var center := caster.global_position + position + feet_offset
	for e in IceFx.targets(get_tree()):
		# Эхо чужого вихря (кооп): тянет врагов только настоящий, у хозяина
		if not ("knockback_velocity" in e) or Net.is_echo(caster):
			continue
		var f := IceFx.feet(e)
		var d := IceFx.ground_dist(center, f, 0.7)
		if d > pull_radius or d < 26.0:
			continue
		var to_c := (center - f).normalized()
		var side := Vector2(-to_c.y, to_c.x)
		var k := (1.0 - d / pull_radius) * 0.6 + 0.4
		e.knockback_velocity = (to_c + side * 0.55).normalized() * pull_speed * k * _power


func _tick() -> void:
	var center := caster.global_position + position + feet_offset
	for e in IceFx.targets(get_tree()):
		if IceFx.ground_dist(center, IceFx.feet(e), 0.7) <= radius:
			IceFx.hit(caster, e, damage, center, 0.0, slow_pct, slow_sec)
	MageFx.flash(self, 46.0, 0.1, IceFx.CORE)
	IceFx.shards(self, 10, 150.0, 0.4, Vector2.ZERO, 180.0, 160.0)
	if caster.has_method("shake_camera"):
		caster.shake_camera(2.0, 0.12)


## Срыв вихря: всех вокруг отбрасывает, на земле — иней, осколки веером
func _blast() -> void:
	_pulling = false
	var center := caster.global_position + position + feet_offset
	var tree := get_tree()
	for e in IceFx.targets(tree):
		var d := IceFx.ground_dist(center, IceFx.feet(e), 0.7)
		if d <= pull_radius:
			IceFx.hit(caster, e, 0, center, blast_push * (1.0 - 0.4 * d / pull_radius), slow_pct, slow_sec)
	var h := MageFx.holder(tree, global_position, 1.6, 11)
	MageFx.flash(h, 90.0, 0.18, IceFx.CORE)
	MageFx.light_pulse(h, 150.0, 1.5, 0.45, IceFx.MID)
	IceFx.shards(h, 30, 240.0, 0.6, Vector2.ZERO, 180.0, 200.0)
	MageFx.sparks(h, 16, 260.0, 0.35)
	IceFx.mist(h, 10, 40.0, 40.0, 1.2, 0.22)
	IceFx.frost_decal(tree, center, 85.0, 2.2, 0.5)
	SoundBank.play_at(tree, "trap_snap", center, -7.0, 1.2)
	if caster.has_method("shake_camera"):
		caster.shake_camera(4.5, 0.22)


func _fade_out() -> void:
	if _done:
		return
	_done = true
	_pulling = false
	if is_instance_valid(_orbit):
		_orbit.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_power", 0.0, 0.25)
	tw.tween_property(_light, "energy", 0.0, 0.3)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_callback(queue_free)


## Дуги вихря: каждая — ломаная по эллипсу с хвостом, тающим к концу. Точки
## с sin(угла) > 0 — ближняя к зрителю половина (перед магом), остальные —
## задняя. front выбирает, какую половину рисовать этому слою
func _draw_arcs(layer: Node2D, front: bool) -> void:
	if _power <= 0.01:
		return
	for arc in ARCS:
		var r: float = arc[0]
		var speed: float = arc[1]
		var length: float = arc[2]
		var w: float = arc[3]
		var head := _t * speed + float(arc[4])
		var steps := 18
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in steps + 1:
			var k := float(i) / steps
			# Голова дуги — впереди по ходу вращения, хвост тает
			var a := head - signf(speed) * length * k
			var on_front := sin(a) > 0.0
			if on_front != front:
				if pts.size() > 1:
					layer.draw_polyline_colors(pts, cols, w, true)
				pts = PackedVector2Array()
				cols = PackedColorArray()
				continue
			# Радиус дышит — дуги не идеальные окружности
			var rr := r * (1.0 + 0.06 * sin(a * 3.0 + _t * 5.0))
			pts.append(Vector2(cos(a) * rr, sin(a) * rr * SQUASH))
			var c := IceFx.CORE.lerp(IceFx.EDGE, k)
			cols.append(Color(c, (1.0 - k) * 0.9 * _power))
		if pts.size() > 1:
			layer.draw_polyline_colors(pts, cols, w, true)
