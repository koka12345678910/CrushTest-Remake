extends RefCounted
## crusader_boss_fx.gd — эффекты босса храма, Крестоносца Тёмного Солнца
## (crusader_boss.gd). Только статические функции:
##   const BossFx := preload("res://enemy/humans/crusader/crusader_boss_fx.gd")
##
## Палитра Тёмного Солнца: кромка клинка — раскалённо-красная, свет —
## кровавый, угли — тлеющие; пыль, комья земли и трещины — обычные, земляные.
## Каждый удар должен ощущаться весом: двуручник ломает землю.
##
## Удары (клипы крестоносца):
##   attack  — широкий взмах (лист Attack2): красная дуга, вал пыли по дуге,
##             ветер срывает пыль с земли;
##   attack3 — тяжёлый разворот (лист Attack4): дуга шире, шрам на земле
##             по кромке, удар о землю в конце;
##   attack2 — прыжок с ударом сверху (лист Attack1): клинок входит в землю —
##             воронка, разлом бежит вперёд по направлению удара, кольцо,
##             волна воздуха, камни. Рывок через арену — разлом длиннее.
## Вторая фаза: всё сильнее, трещины тлеют красным, из-под ударов летят угли,
## вокруг босса — аура углей и красный свет.

const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")
const SkidDust := preload("res://VFX/VFX_scene/skid_dust.gd")
const DebrisScript := preload("res://VFX/VFX_scene/debris_spray.gd")

const EMBER_CORE := Color(1.0, 0.86, 0.6)
const EMBER := Color(1.0, 0.42, 0.14)
const BLOOD := Color(0.9, 0.1, 0.05)
const DEEP := Color(0.35, 0.02, 0.02)
## Кромка дуги клинка
const EDGE := Color(1.0, 0.28, 0.12)
## Тление трещин: в первой фазе едва, во второй — ярко
const CRACK_GLOW_1 := Color(0.85, 0.16, 0.06, 0.45)
const CRACK_GLOW_2 := Color(1.0, 0.36, 0.1, 0.95)

const DEPTH := 0.62
## Грудь и ноги босса относительно узла
const CHEST := Vector2(0, -10)
const FEET := Vector2(0, 22)
## Босс крупнее рыцаря и бьёт двуручником — дуги шире
const ARC_SCALE := 1.6


## Земля в 3/4 виде: смещение вдоль направления удара
static func _ground(dir: Vector2, dist: float) -> Vector2:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	return Vector2(d.x, d.y * 0.8) * dist


static func _feet(boss: Node2D) -> Vector2:
	return boss.global_position + FEET


# ───────────────────────── замах ─────────────────────────

## Начало удара: блик на клинке, красный всполох. Удар сверху — на земле в
## месте удара сходится красное кольцо (видно, куда упадёт клинок, — время
## для переката). t_impact — через сколько секунд удар
static func windup(boss: Node2D, anim_name: String, facing: Vector2, phase: int, t_impact: float, lunge := false) -> void:
	if not is_instance_valid(boss):
		return
	var tree := boss.get_tree()
	var h := MageFx.holder(tree, boss.global_position + CHEST + _ground(facing, 10.0) + Vector2(0, -8), 0.8, 13)
	h.reparent(boss)
	KnightFx._glint(h, 46.0 if phase == 2 else 38.0, 0.0, 0.32, EMBER_CORE)
	MageFx.light_pulse(h, 70.0, 0.9 if phase == 2 else 0.6, 0.5, BLOOD)
	if anim_name == "attack2":
		var at := _feet(boss) + _ground(facing, 70.0 if lunge else 46.0)
		var mark := MageFx.holder(tree, at, maxf(t_impact, 0.2) + 0.2, -14)
		mark.z_as_relative = false
		_converge_ring(mark, 70.0 if lunge else 56.0, 14.0, maxf(t_impact, 0.2), Color(BLOOD, 0.55 if phase == 1 else 0.8))
	if phase == 2:
		var e := MageFx.holder(tree, boss.global_position, 1.4, 12)
		_embers(e, 10, 18.0, 1.0)


## Дуга клинка — к моменту удара (из crusader_boss.gd по таймеру)
static func swing(boss: Node2D, anim_name: String, facing: Vector2, phase: int) -> void:
	if not is_instance_valid(boss):
		return
	var p2 := phase == 2
	match anim_name:
		"attack2":
			KnightFx.chop(boss, facing, 30.0 * ARC_SCALE, 0.14, 1.7 if p2 else 1.5, CHEST, EDGE)
		"attack3":
			var p := KnightFx.preset(KnightFx.Swing.HEAVY, facing)
			KnightFx.arc(boss, p.from, p.to, p.radius * ARC_SCALE, p.width * 1.15, p.dur * 1.1, 1.6 if p2 else 1.4,
					CHEST, false, true, EDGE)
			if p2:
				KnightFx.arc(boss, p.from, p.to, p.radius * ARC_SCALE * 1.3, p.width * 0.7, p.dur * 1.25, 0.45,
						CHEST, false, false, EMBER)
		_:
			var p := KnightFx.preset(KnightFx.Swing.SWEEP, facing)
			KnightFx.arc(boss, p.from, p.to, p.radius * ARC_SCALE, p.width * 1.1, p.dur * 1.1, 1.5 if p2 else 1.3,
					CHEST, false, true, EDGE)
			if p2:
				KnightFx.arc(boss, p.from, p.to, p.radius * ARC_SCALE * 1.3, p.width * 0.7, p.dur * 1.25, 0.45,
						CHEST, false, false, EMBER)


# ───────────────────────── удар ─────────────────────────

## Момент удара (хитбокс включился)
static func impact(boss: Node2D, anim_name: String, facing: Vector2, phase: int, lunge := false) -> void:
	if not is_instance_valid(boss):
		return
	match anim_name:
		"attack2":
			_slam(boss, facing, phase, lunge)
		"attack3":
			_heavy(boss, facing, phase)
		_:
			_sweep(boss, facing, phase)


## Удар сверху: клинок входит в землю
static func _slam(boss: Node2D, facing: Vector2, phase: int, lunge: bool) -> void:
	var tree := boss.get_tree()
	var fwd := facing.normalized() if facing.length() > 0.01 else Vector2.DOWN
	var p := 1.0 + (0.35 if lunge else 0.0) + (0.25 if phase == 2 else 0.0)
	var at := _feet(boss) + _ground(fwd, 70.0 if lunge else 46.0)
	var glow := CRACK_GLOW_2 if phase == 2 else CRACK_GLOW_1
	# Земля, а не магия: воронка, крупные комья, пыль стеной; свет — короткий
	# всполох от клинка, без светящегося шара
	_crater(tree, at, 34.0 * p)
	SkidDust.slam(tree, at, 64.0 * p, 1.3 * p)
	Juice.ground_crack(at, 2.2 * p, glow)
	Juice.ground_crack(at + Vector2(randf_range(-8, 8), randf_range(-4, 4)), 1.4 * p, glow)
	Juice.shockwave(at + Vector2(0, -6), 110.0 * p, 0.5, 0.016)
	Juice.shake(7.0 * p)
	Juice.kick(fwd, 5.0 * p)
	_rocks(tree, at, int(14 * p), 2.2, 5.0)
	var h := MageFx.holder(tree, at, 1.8, 12)
	MageFx.flash(h, 34.0, 0.12, EMBER_CORE)
	MageFx.light_pulse(h, 130.0 * p, 1.1, 0.6, BLOOD)
	KnightFx._ring(h, 12.0, 96.0 * p, 2.5, 0.45, Color(EMBER, 0.6))
	KnightFx._sparks(tree, at + Vector2(0, -12), Vector2.UP, 16, 2.6, 120.0, 300.0, 0.65)
	_embers(h, 26 if phase == 2 else 10, 26.0 * p, 1.6)
	# Разлом бежит вперёд от места удара
	_fissure(tree, at, fwd, (3 if phase == 1 else 4) + (2 if lunge else 0), 1.5 * p, glow)


## Широкий взмах: ветер клинка срывает пыль с земли по дуге
static func _sweep(boss: Node2D, facing: Vector2, phase: int) -> void:
	var tree := boss.get_tree()
	var fwd := facing.normalized() if facing.length() > 0.01 else Vector2.DOWN
	var feet := _feet(boss)
	var pr := KnightFx.preset(KnightFx.Swing.SWEEP, fwd)
	var r := 44.0
	for i in 5:
		var a := lerpf(pr.from, pr.to, (i + 0.5) / 5.0)
		var pt := feet + Vector2(cos(a), sin(a) * DEPTH) * r
		var tangent := Vector2(-sin(a), cos(a) * DEPTH).normalized() * signf(pr.to - pr.from)
		SkidDust.skid(tree, pt, tangent, SkidDust.Kind.STOP, 1.1 if phase == 1 else 1.4)
	var tip := feet + _ground(fwd, 40.0)
	Juice.ground_crack(tip, 0.9, CRACK_GLOW_2 if phase == 2 else Color(0, 0, 0, 0))
	Juice.shake(3.5 if phase == 1 else 4.5)
	Juice.shockwave(boss.global_position + CHEST + _ground(fwd, 24.0), 70.0, 0.35, 0.01)
	var h := MageFx.holder(tree, tip, 1.5, 12)
	MageFx.light_pulse(h, 90.0, 0.9, 0.4, BLOOD)
	if phase == 2:
		_embers(h, 14, 30.0, 1.2)


## Тяжёлый разворот: клинок чертит землю — шрам по кромке и удар в конце
static func _heavy(boss: Node2D, facing: Vector2, phase: int) -> void:
	var tree := boss.get_tree()
	var fwd := facing.normalized() if facing.length() > 0.01 else Vector2.DOWN
	var feet := _feet(boss)
	var pr := KnightFx.preset(KnightFx.Swing.HEAVY, fwd)
	var glow := CRACK_GLOW_2 if phase == 2 else CRACK_GLOW_1
	# Шрам — вторая половина дуги, где клинок идёт у самой земли
	var from: float = lerpf(pr.from, pr.to, 0.35)
	_scar(tree, feet, from, pr.to, 46.0, glow)
	var end := feet + Vector2(cos(pr.to), sin(pr.to) * DEPTH) * 46.0
	var at := feet + _ground(fwd, 44.0)
	SkidDust.slam(tree, at, 40.0, 0.8 if phase == 1 else 1.0)
	Juice.ground_crack(at, 1.4, glow)
	Juice.shockwave(at + Vector2(0, -6), 90.0, 0.45, 0.012)
	Juice.shake(5.0 if phase == 1 else 6.0)
	Juice.kick(fwd, 3.5)
	KnightFx._sparks(tree, end + Vector2(0, -8), (end - feet).normalized(), 10, 1.6, 90.0, 220.0, 0.5)
	var h := MageFx.holder(tree, at, 1.6, 12)
	MageFx.light_pulse(h, 110.0, 1.2, 0.5, BLOOD)
	KnightFx._ring(h, 8.0, 64.0, 2.5, 0.35, Color(EMBER, 0.7))
	if phase == 2:
		_embers(h, 18, 30.0, 1.3)


# ───────────────────────── движение ─────────────────────────

## Тяжёлый шаг бегом: пыль из-под сапог (во второй фазе — угли)
static func step(boss: Node2D, dir: Vector2, phase: int, power := 1.0) -> void:
	if not is_instance_valid(boss):
		return
	var tree := boss.get_tree()
	SkidDust.skid(tree, _feet(boss) - dir * 4.0, dir, SkidDust.Kind.START, 0.75 * power)
	if phase == 2:
		var h := MageFx.holder(tree, _feet(boss), 1.0, 12)
		_embers(h, 3, 8.0, 0.8)


## Силуэт-шлейф на рывке через арену: копия кадра, тёмно-красная, гаснет
static func ghost(boss: Node2D) -> void:
	if not is_instance_valid(boss) or not boss.is_inside_tree():
		return
	var sp: AnimatedSprite2D = boss.get_node_or_null("AnimatedSprite2D")
	if sp == null or sp.sprite_frames == null or not sp.sprite_frames.has_animation(sp.animation):
		return
	var g := Sprite2D.new()
	g.texture = sp.sprite_frames.get_frame_texture(sp.animation, sp.frame)
	g.material = MageFx.add_material()
	g.texture_filter = sp.texture_filter
	g.scale = sp.scale
	g.flip_h = sp.flip_h
	g.modulate = Color(BLOOD, 0.4)
	boss.get_parent().add_child(g)
	g.global_position = sp.global_position
	g.z_index = boss.z_index - 1
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.28)
	t.tween_callback(g.queue_free)


# ───────────────────────── рёв, фаза, смерть ─────────────────────────

## Рёв: земля под ним трескается, пыль кольцом
static func roar(boss: Node2D, phase: int) -> void:
	if not is_instance_valid(boss):
		return
	var tree := boss.get_tree()
	var feet := _feet(boss)
	SkidDust.slam(tree, feet, 80.0, 0.9)
	Juice.ground_crack(feet, 2.0, CRACK_GLOW_2 if phase == 2 else CRACK_GLOW_1)
	var h := MageFx.holder(tree, feet, 2.0, 12)
	MageFx.light_pulse(h, 160.0, 1.4 if phase == 2 else 0.9, 1.0, BLOOD)
	KnightFx._ring(h, 10.0, 130.0, 3.0, 0.6, Color(BLOOD, 0.8))
	if phase == 2:
		_embers(h, 40, 34.0, 2.0)
		KnightFx._ring(h, 20.0, 180.0, 2.0, 0.8, Color(EMBER, 0.6))


## Аура второй фазы: угли поднимаются от плеч, красный свет дышит. Узел —
## ребёнок босса; убрать — queue_free (crusader_boss.gd::_set_aura)
static func aura(boss: Node2D) -> Node2D:
	var n := Node2D.new()
	n.name = "BossAura"
	n.z_index = 1
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 1.4
	p.position = Vector2(0, 6)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 16)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 34.0
	p.gravity = Vector2(0, -20)
	p.damping_min = 4.0
	p.damping_max = 10.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.texture = MageFx.dot()
	p.material = MageFx.add_material()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(EMBER_CORE, 1.0), Color(EMBER, 0.9), Color(DEEP, 0.0)])
	p.color_ramp = g
	n.add_child(p)
	var l := PointLight2D.new()
	l.texture = MageFx.radial()
	l.texture_scale = 110.0 * 2.0 / 128.0
	l.color = BLOOD
	l.energy = 0.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	n.add_child(l)
	var t := l.create_tween().set_loops()
	t.tween_property(l, "energy", 0.85, 0.55).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "energy", 0.45, 0.65).set_trans(Tween.TRANS_SINE)
	boss.add_child(n)
	return n


## Гибель: земля проваливается под ним, столп углей и пыли
static func death(boss: Node2D) -> void:
	if not is_instance_valid(boss):
		return
	var tree := boss.get_tree()
	var feet := _feet(boss)
	SkidDust.slam(tree, feet, 110.0, 1.6)
	Juice.ground_crack(feet, 2.8, CRACK_GLOW_2)
	Juice.shockwave(feet + Vector2(0, -10), 220.0, 0.8, 0.04)
	Juice.shake(9.0)
	var h := MageFx.holder(tree, feet, 3.5, 12)
	MageFx.flash(h, 50.0, 0.2, EMBER_CORE)
	MageFx.light_pulse(h, 260.0, 2.2, 2.4, BLOOD)
	KnightFx._ring(h, 16.0, 200.0, 3.0, 0.7, Color(EMBER, 0.6))
	KnightFx._ring(h, 8.0, 120.0, 2.5, 0.5, Color(EMBER_CORE, 0.8))
	_embers(h, 70, 30.0, 2.8)
	for i in 6:
		var dir := Vector2.from_angle(TAU * i / 6.0 + randf_range(-0.3, 0.3))
		_fissure(tree, feet, dir, 3, 1.2, CRACK_GLOW_2)


# ───────────────────────── кирпичики ─────────────────────────

## Воронка: тёмное вдавленное пятно под ударом, лежит и медленно тает
static func _crater(tree: SceneTree, at: Vector2, r: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var s := Sprite2D.new()
	s.texture = MageFx.soft()
	s.z_as_relative = false
	s.z_index = -16
	s.modulate = Color(0.02, 0.015, 0.015, 0.0)
	s.scale = Vector2(r, r * DEPTH) * 2.0 / 64.0
	root.add_child(s)
	s.global_position = at
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.7, 0.08)
	t.tween_interval(5.5)
	t.tween_property(s, "modulate:a", 0.0, 2.5)
	t.tween_callback(s.queue_free)


## Крупные камни из воронки (обычные комья земли — в SkidDust.slam)
static func _rocks(tree: SceneTree, at: Vector2, count: int, size_min: float, size_max: float) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var deb: Node2D = DebrisScript.new()
	deb.setup(count, 10.0, 50.0, 170.0, 160.0, 340.0, size_min, size_max)
	root.add_child(deb)
	deb.global_position = at




## Разлом: цепочка трещин бежит от точки по направлению, каждая чуть меньше,
## у каждой пыль и комья
static func _fissure(tree: SceneTree, from: Vector2, dir: Vector2, count: int, size: float, glow: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	for i in count:
		var k := i + 1
		var p := from + _ground(dir, 30.0 * k) + side * randf_range(-6.0, 6.0)
		var s := maxf(size * (1.0 - 0.13 * k), 0.6)
		tree.create_timer(0.045 * k).timeout.connect(func():
			Juice.ground_crack(p, s, glow)
			var deb: Node2D = DebrisScript.new()
			deb.setup(5, 6.0, 20.0, 80.0, 90.0, 200.0, 1.2, 3.0)
			var root := tree.current_scene
			if root:
				root.add_child(deb)
				deb.global_position = p
			SkidDust.skid(tree, p, dir, SkidDust.Kind.STOP, 0.7))


## Шрам на земле по дуге (тёмная борозда, во второй фазе тлеет), медленно тает
static func _scar(tree: SceneTree, center: Vector2, from: float, to: float, r: float, glow: Color) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = -15
	root.add_child(n)
	n.global_position = center
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(from, to, i / 12.0)
		pts.append(Vector2(cos(a), sin(a) * DEPTH) * (r + randf_range(-1.5, 1.5)))
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.2))
	wc.add_point(Vector2(0.5, 1.0))
	wc.add_point(Vector2(1, 0.3))
	var l := Line2D.new()
	l.points = pts
	l.width = 3.2
	l.width_curve = wc
	l.default_color = Color(0.03, 0.025, 0.03, 0.85)
	n.add_child(l)
	if glow.a > 0.0:
		var g := Line2D.new()
		g.points = pts
		g.width = 1.6
		g.width_curve = wc
		g.default_color = glow
		g.material = MageFx.add_material()
		n.add_child(g)
		g.create_tween().tween_property(g, "modulate:a", 0.0, 1.8).set_delay(0.4)
	var t := n.create_tween()
	t.tween_interval(5.0)
	t.tween_property(n, "modulate:a", 0.0, 2.5)
	t.tween_callback(n.queue_free)


## Красное кольцо на земле сходится к точке удара за time секунд
static func _converge_ring(parent: Node2D, r0: float, r1: float, time: float, col: Color) -> void:
	var n := Node2D.new()
	n.scale = Vector2(1.0, DEPTH)
	n.material = MageFx.add_material()
	n.set_meta("r", r0)
	n.set_meta("a", 0.0)
	n.draw.connect(func():
		var r: float = n.get_meta("r")
		var a: float = n.get_meta("a")
		n.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col, col.a * a), 2.2, true)
		n.draw_circle(Vector2.ZERO, r1 * 0.6, Color(col, col.a * a * 0.35)))
	parent.add_child(n)
	var t := n.create_tween()
	t.tween_method(func(v: float):
		n.set_meta("r", lerpf(r0, r1, v))
		n.set_meta("a", minf(v * 3.0, 1.0))
		n.queue_redraw(), 0.0, 1.0, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Угли Тёмного Солнца: поднимаются, мерцают, гаснут
static func _embers(parent: Node, amount: int, area: float, life := 1.2) -> void:
	MageFx.burst(parent, amount, life, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = area
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 50.0
		pm.initial_velocity_min = 20.0
		pm.initial_velocity_max = 70.0
		pm.gravity = Vector3(0, -24, 0)
		pm.damping_min = 10.0
		pm.damping_max = 24.0
		pm.scale_min = 0.6
		pm.scale_max = 1.5
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.0
		pm.turbulence_noise_scale = 3.0
		pm.color_ramp = MageFx.ramp([Color(EMBER_CORE, 1.0), Color(EMBER, 0.9), Color(DEEP, 0.0)], [0.0, 0.3, 1.0]))
