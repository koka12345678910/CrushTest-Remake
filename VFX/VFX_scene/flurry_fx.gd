extends RefCounted
## flurry_fx.gd — эффекты быстрой серии рыцаря («флёрри»): стальные двойники
## за клинком, рывок к врагу с пылью, вихрь-финишер. Только статические
## функции:
##   const FlurryFx := preload("res://VFX/VFX_scene/flurry_fx.gd")
## Дуги клинка и искры попаданий — как раньше (knight_fx.gd), здесь только то,
## что делает серию из четырёх ударов зрелищной, а не просто быстрой.

const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")
const SkidDust := preload("res://VFX/VFX_scene/skid_dust.gd")

## Холодная сталь с лёгким теплом — двойники тоньше и светлее самого рыцаря
const GHOST := Color(0.82, 0.9, 1.0)
const GHOST_HOT := Color(1.0, 0.9, 0.74)


## Двойник героя: копия текущего кадра, светлая сталь, аддитивно; расходится
## вбок по ходу взмаха и тает. Чем выше шаг серии, тем ярче и теплее.
## tint — свой цвет (у Сигрид — бледно-зелёный), прозрачный — сталь рыцаря
static func ghost(body: Node2D, gfx: AnimatedSprite2D, step: int, dir: Vector2, life := 0.2,
		tint := Color(0, 0, 0, 0)) -> void:
	if not is_instance_valid(body) or not is_instance_valid(gfx) or gfx.sprite_frames == null:
		return
	if not gfx.sprite_frames.has_animation(gfx.animation):
		return
	var root := body.get_tree().current_scene
	if root == null:
		return
	var g := Sprite2D.new()
	g.texture = gfx.sprite_frames.get_frame_texture(gfx.animation, gfx.frame)
	g.material = MageFx.add_material()
	g.texture_filter = gfx.texture_filter
	g.scale = gfx.scale
	g.flip_h = gfx.flip_h
	g.offset = gfx.offset
	g.z_index = body.z_index
	var k := clampf((step - 1) / 3.0, 0.0, 1.0)
	var col := GHOST.lerp(GHOST_HOT, k) if tint.a <= 0.0 else tint
	g.modulate = Color(col, 0.34 + 0.16 * k)
	root.add_child(g)
	g.global_position = gfx.global_position
	# Двойник отстаёт от клинка: уезжает назад по направлению удара
	var t := g.create_tween().set_parallel(true)
	t.tween_property(g, "global_position", g.global_position - dir * (8.0 + 4.0 * step), life).set_ease(Tween.EASE_OUT)
	t.tween_property(g, "modulate:a", 0.0, life)
	t.set_parallel(false)
	t.tween_callback(g.queue_free)


## Рывок к врагу: пыль из-под ног назад, пара искр и росчерк скорости.
## dir — куда рвётся рыцарь
static func lunge(body: Node2D, dir: Vector2, power := 1.0) -> void:
	if not is_instance_valid(body) or dir.length() < 0.01:
		return
	var tree := body.get_tree()
	dir = dir.normalized()
	var feet := body.global_position + Vector2(0, 14)
	SkidDust.skid(tree, feet - dir * 4.0, -dir, SkidDust.Kind.START, 0.4 * power)
	var h := MageFx.holder(tree, feet + Vector2(0, -12), 0.6, 11)
	# Две тонкие линии скорости позади — как у укола (knight_fx.gd::thrust)
	for k in 2:
		var l := Line2D.new()
		var side := Vector2(-dir.y, dir.x) * (-5.0 + 10.0 * k)
		l.points = PackedVector2Array([side, side - dir * (26.0 + 8.0 * k)])
		l.width = 1.6
		l.default_color = Color(GHOST, 0.7)
		l.material = MageFx.add_material()
		var wc := Curve.new()
		wc.add_point(Vector2(0, 1))
		wc.add_point(Vector2(1, 0))
		l.width_curve = wc
		h.add_child(l)
		l.create_tween().tween_property(l, "modulate:a", 0.0, 0.16)


## Вихрь-финишер четвёртого удара — массивный удар о землю: вспышка экрана,
## наезд камеры, волна искажения воздуха, два ударных кольца, росчерки по
## земле, стена пыли с обломками (skid_dust.gd::slam), трещина, искры
static func finisher(knight: Node2D, radius: float) -> void:
	if not is_instance_valid(knight):
		return
	var tree := knight.get_tree()
	var at := knight.global_position + KnightFx.CHEST
	var feet := knight.global_position + Vector2(0, 14)
	var h := MageFx.holder(tree, at, 1.6, 12)
	var f: Vector2 = knight.get("facing_dir") if knight.get("facing_dir") != null else Vector2.DOWN
	KnightFx.slash(knight, KnightFx.Swing.SPIN, f)
	# Второй круг клинка — шире и бледнее, чуть позже: вихрь «двойной»
	tree.create_timer(0.05).timeout.connect(func():
		if is_instance_valid(knight):
			var p := KnightFx.preset(KnightFx.Swing.SPIN, f)
			KnightFx.arc(knight, p.from + 0.6, p.to + 0.6, p.radius * 1.35, p.width * 0.6, p.dur * 1.15, 0.45))
	MageFx.flash(h, 64.0, 0.12, Color(1.0, 0.97, 0.9))
	MageFx.light_pulse(h, radius * 1.3, 1.1, 0.32, Color(1.0, 0.86, 0.6))
	KnightFx._ring(h, 8.0, radius * 1.1, 4.0, 0.32, Color(GHOST, 0.9))
	var tw := h.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func(): KnightFx._ring(h, 6.0, radius * 0.8, 2.4, 0.28, Color(GHOST_HOT, 0.75)))
	tw.tween_interval(0.07)
	tw.tween_callback(func(): KnightFx._ring(h, 4.0, radius * 1.4, 1.4, 0.4, Color(GHOST, 0.4)))
	_ground_streaks(tree, feet, radius)
	# Стена пыли с камнями и трещина — вес удара: земля действительно приняла его
	SkidDust.slam(tree, feet, radius, 1.0)
	var juice := tree.root.get_node_or_null("Juice")
	if juice:
		juice.ground_crack(feet, 1.7)
		# Воздух выпирает кольцом, камера наезжает и вздрагивает, экран вспыхивает
		juice.shockwave(feet + Vector2(0, -6), radius * 1.5, 0.5, 0.02)
		juice.zoom_punch(0.11, 0.1)
		juice.flash(0.22)
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		KnightFx._sparks(tree, at, Vector2.from_angle(a), 7, 1.0, 130.0, 280.0, 0.5)
	if knight.has_method("shake_camera"):
		knight.shake_camera(12.0)


## Росчерки по земле от центра — ветер удара: тонкие светлые черты бегут
## наружу и гаснут (на земле, сплюснуты)
static func _ground_streaks(tree: SceneTree, feet: Vector2, radius: float) -> void:
	var h := MageFx.holder(tree, feet, 0.7, 11)
	h.scale = Vector2(1.0, 0.62)
	for i in 14:
		var a := TAU * (i + randf_range(-0.3, 0.3)) / 14.0
		var d := Vector2.from_angle(a)
		var l := Line2D.new()
		var len := randf_range(16.0, 30.0)
		var r0 := radius * randf_range(0.25, 0.4)
		l.points = PackedVector2Array([d * r0, d * (r0 + len)])
		l.width = randf_range(1.2, 2.2)
		l.default_color = Color(1.0, 0.94, 0.82, 0.7)
		l.material = MageFx.add_material()
		var wc := Curve.new()
		wc.add_point(Vector2(0, 0))
		wc.add_point(Vector2(0.3, 1))
		wc.add_point(Vector2(1, 0))
		l.width_curve = wc
		h.add_child(l)
		var t := l.create_tween().set_parallel(true)
		t.tween_property(l, "position", d * radius * 0.75, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(l, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_IN)


## Сбор силы перед вихрем (замах 4-го удара, time — до удара): ветер стягивает
## пыль к ногам рыцаря, камешки вокруг подпрыгивают, на груди разгорается свет
## и в конце вспыхивает блик — сейчас ударит
static func charge(knight: Node2D, time: float) -> void:
	if not is_instance_valid(knight):
		return
	var tree := knight.get_tree()
	var feet := knight.global_position + Vector2(0, 14)
	time = maxf(time, 0.15)
	# Пыль стягивается к ногам по спирали
	var h := MageFx.holder(tree, feet, time + 0.8, 11)
	var p := MageFx.burst(h, 18, time + 0.15, SkidDust.puff(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3(0, 0, 1)
		pm.emission_ring_radius = 62.0
		pm.emission_ring_inner_radius = 44.0
		pm.emission_ring_height = 0.0
		pm.radial_velocity_min = -95.0
		pm.radial_velocity_max = -60.0
		pm.orbit_velocity_min = 0.35
		pm.orbit_velocity_max = 0.6
		pm.scale_min = 0.22
		pm.scale_max = 0.38
		pm.angle_max = 360.0
		pm.color_ramp = MageFx.ramp([Color(SkidDust.DUST, 0.0), Color(SkidDust.DUST, 0.45), Color(SkidDust.DUST_DARK, 0.0)], [0.0, 0.4, 1.0]),
		false)
	SkidDust._atlas(p)
	p.explosiveness = 0.3
	p.local_coords = true
	p.scale = Vector2(1.0, SkidDust.GROUND_SQUASH)
	# Камешки под ногами подпрыгивают — земля дрожит
	var root := tree.current_scene
	if root:
		var deb: Node2D = SkidDust.DebrisScript.new()
		deb.setup(10, 26.0, 0.0, 18.0, 40.0, 95.0, 1.0, 2.2)
		root.add_child(deb)
		deb.global_position = feet
	# Свет на груди разгорается к удару, в конце — блик
	var c := MageFx.holder(tree, knight.global_position + KnightFx.CHEST, time + 0.5, 12)
	c.reparent(knight)
	var l := PointLight2D.new()
	l.texture = MageFx.radial()
	l.texture_scale = 70.0 / 128.0
	l.color = Color(1.0, 0.86, 0.6)
	l.energy = 0.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	c.add_child(l)
	var tw := c.create_tween()
	tw.tween_property(l, "energy", 1.3, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var g := KnightFx._glint(c, 70.0, 0.0, 0.2, Color(1.0, 0.95, 0.85))
		g.rotation = randf_range(-0.3, 0.3))
	tw.tween_property(l, "energy", 0.0, 0.25)


## Финиш серии кинжалом Сигрид: два росчерка крест-накрест в точке удара,
## вспышка, искры и мгновение замедления с лёгким наездом камеры — удар
## «зависает» на миг. at — точка удара (грудь + вылет клинка), dir — куда бьёт
static func cross_cut(body: Node2D, at: Vector2, dir: Vector2, col := Color(0.86, 1.0, 0.9)) -> void:
	if not is_instance_valid(body):
		return
	var tree := body.get_tree()
	var h := MageFx.holder(tree, at, 0.8, 13)
	var base := dir.angle() + PI * 0.5
	# Первый росчерк — сразу, второй — через миг поперёк: крест «дописывается»
	var a := KnightFx._glint(h, 74.0, 1.0, 0.24, col)
	a.rotation = base + 0.62
	var tw := h.create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func():
		var b := KnightFx._glint(h, 74.0, 1.0, 0.24, col)
		b.rotation = base - 0.62
		KnightFx._ring(h, 4.0, 26.0, 1.6, 0.2, Color(col, 0.75))
		KnightFx._sparks(tree, at, dir, 9, 1.0, 110.0, 240.0, 0.4))
	MageFx.flash(h, 26.0, 0.1, Color(col.r, col.g, col.b))
	MageFx.light_pulse(h, 50.0, 0.9, 0.22, col)
	var juice := tree.root.get_node_or_null("Juice")
	if juice:
		juice.slow(0.2, 0.09, 0.6)
		juice.zoom_punch(0.05, 0.05)


## Спуск тетивы: у лука вспыхивает свет, вперёд срываются линии скорости, по
## воздуху расходится кольцо. power 0..1: обычный выстрел — скромно, полный
## натяг — ярко, с волной искажения воздуха. at — точка у лука, dir — куда летит
static func bow_release(body: Node2D, at: Vector2, dir: Vector2, power := 0.4, col := Color(1.0, 0.95, 0.82)) -> void:
	if not is_instance_valid(body):
		return
	var tree := body.get_tree()
	dir = dir.normalized()
	var h := MageFx.holder(tree, at, 0.7, 12)
	MageFx.flash(h, 14.0 + 26.0 * power, 0.08 + 0.05 * power, col)
	MageFx.light_pulse(h, 30.0 + 40.0 * power, 0.4 + 0.6 * power, 0.18, col)
	# Линии скорости — вперёд по полёту, тают
	var lines := 2 + int(power * 3.0)
	for k in lines:
		var side := Vector2(-dir.y, dir.x) * randf_range(-5.0, 5.0)
		var l := Line2D.new()
		var len := randf_range(14.0, 26.0) * (0.7 + power)
		l.points = PackedVector2Array([side, side + dir * len])
		l.width = 1.2 + power
		l.default_color = Color(col, 0.75)
		l.material = MageFx.add_material()
		var wc := Curve.new()
		wc.add_point(Vector2(0, 0))
		wc.add_point(Vector2(0.4, 1))
		wc.add_point(Vector2(1, 0))
		l.width_curve = wc
		h.add_child(l)
		var t := l.create_tween().set_parallel(true)
		t.tween_property(l, "position", dir * (10.0 + 18.0 * power), 0.16).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "modulate:a", 0.0, 0.16)
	if power >= 0.95:
		# Полный натяг: воздух рвётся — кольцо поперёк выстрела и волна
		var r := Node2D.new()
		r.rotation = dir.angle()
		r.scale = Vector2(0.35, 1.0)
		h.add_child(r)
		KnightFx._ring(r, 3.0, 22.0, 2.2, 0.22, Color(col, 0.85))
		var juice := tree.root.get_node_or_null("Juice")
		if juice:
			juice.shockwave(at, 46.0, 0.3, 0.012)


## Попадание стрелы полного натяга: врага отбрасывает, в точке удара — блик,
## кольцо, искры назад по полёту и клочок пыли под ним
static func arrow_impact(tree: SceneTree, at: Vector2, dir: Vector2, col := Color(1.0, 0.92, 0.75)) -> void:
	var h := MageFx.holder(tree, at, 0.8, 12)
	var g := KnightFx._glint(h, 60.0, 0.0, 0.2, col)
	g.rotation = dir.angle()
	MageFx.flash(h, 30.0, 0.1, col)
	KnightFx._ring(h, 4.0, 30.0, 2.0, 0.24, Color(col, 0.8))
	KnightFx._sparks(tree, at, -dir, 10, 1.1, 110.0, 250.0, 0.45)
	SkidDust.skid(tree, at + Vector2(0, 20), dir, SkidDust.Kind.STOP, 0.9)
