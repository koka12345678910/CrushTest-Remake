extends RefCounted
## knight_fx.gd — эффекты рыцаря: дуги клинка, попадание по телу, удар по
## щиту, парирование. Заменили старые спрайтовые вспышки (melee_hit.tscn и
## т.п.). Только статические функции —
## const KnightFx := preload("res://VFX/VFX_scene/knight_fx.gd")
##
## Палитра: клинок — холодная сталь (белое ядро, голубоватый край), металл о
## металл — горячие искры (бело-жёлтое → оранжевое → тёмно-красное).
## У спрайтов рыцаря уже нарисован размытый след меча — дуга его не повторяет,
## а добавляет яркую кромку, штрихи движения и вторую, отстающую дугу.

const SlashScript := preload("res://VFX/VFX_scene/knight_slash.gd")
const SparkSpray := preload("res://VFX/VFX_scene/spark_spray.gd")
const GLINT_SHADER := preload("res://Shaders/impact_glint.gdshader")
const MageFx := preload("res://Player_scene/mage_fx.gd")

## RISING — первый удар серии, SWEEP — второй, широкий в обратную сторону,
## HEAVY — третий, тяжёлый, RUN — удар с разбега
## SPIN — полный круг вокруг себя (удар с разворотом)
enum Swing { RISING, SWEEP, HEAVY, RUN, SPIN }

const DEPTH := 0.62
## Грудь рыцаря относительно его узла — центр дуг
const CHEST := Vector2(0, -6)

const STEEL := Color(1.0, 0.98, 0.93)
const SPARK_HOT := Color(1.0, 0.93, 0.72)
const SPARK_WARM := Color(1.0, 0.62, 0.22)
const PARRY_TINT := Color(0.9, 0.95, 1.0)


## Дуга клинка вокруг рыцаря по заготовке. facing — куда он бьёт
static func slash(knight: Node2D, swing: int, facing: Vector2) -> void:
	var p := preset(swing, facing)
	arc(knight, p.from, p.to, p.radius, p.width, p.dur, p.power, CHEST, false, swing == Swing.HEAVY or swing == Swing.RUN)


## Заготовка дуги для вида взмаха: откуда/куда (углы в "круглом" пространстве
## дуги — по вертикали узел сплюснут), радиус, ширина, длительность, сила
static func preset(swing: int, facing: Vector2) -> Dictionary:
	var f := Vector2(facing.x, facing.y / DEPTH).angle()
	match swing:
		Swing.RISING:
			return {"from": f - deg_to_rad(75.0), "to": f + deg_to_rad(65.0), "radius": 30.0, "width": 0.27, "dur": 0.16, "power": 1.0}
		Swing.SWEEP:
			return {"from": f + deg_to_rad(88.0), "to": f - deg_to_rad(88.0), "radius": 34.0, "width": 0.28, "dur": 0.17, "power": 1.0}
		Swing.HEAVY:
			return {"from": f - deg_to_rad(130.0), "to": f + deg_to_rad(95.0), "radius": 38.0, "width": 0.34, "dur": 0.2, "power": 1.25}
		Swing.RUN:
			return {"from": f + deg_to_rad(120.0), "to": f - deg_to_rad(110.0), "radius": 40.0, "width": 0.34, "dur": 0.19, "power": 1.25}
		_:
			return {"from": f, "to": f + TAU * 0.97, "radius": 36.0, "width": 0.3, "dur": 0.22, "power": 1.15}


## Дуга с заданной геометрией и временем — для взмахов, снятых с кадров
## спрайта (Сигрид, sigrid_swing_data.gd). center — грудь относительно узла,
## linear — голова идёт равномерно (успевает ровно за dur, как след на
## спрайте), sparks — искры с кончика в конце (тяжёлый удар)
static func arc(owner: Node2D, from: float, to: float, radius: float, width: float, dur: float, power := 1.0,
		center := CHEST, linear := false, sparks := false, edge := Color(0, 0, 0, 0)) -> void:
	if not is_instance_valid(owner):
		return
	_arc(owner, from, to, radius, width, dur, power, 0.0, center, linear, edge)
	# Вторая дуга — тоньше, внутри и чуть отстаёт: след не плоский, а слоистый
	_arc(owner, from, to, radius * 0.8, width * 0.55, dur * 1.08, power * 0.45, minf(0.028, dur * 0.15), center, linear, edge)
	if sparks:
		# Тяжёлый удар срывает с кончика клинка несколько искр — по касательной
		var end := Vector2(cos(to), sin(to) * DEPTH) * radius
		var tangent := Vector2(-sin(to), cos(to) * DEPTH).normalized() * signf(to - from)
		owner.get_tree().create_timer(dur * 0.8).timeout.connect(func():
			if is_instance_valid(owner):
				_sparks(owner.get_tree(), owner.global_position + center + end, tangent, 6, 0.6, 80.0, 190.0, 0.35))


## Клинок попал по телу: короткая черта-разрез, вспышка, немного искр.
## Кровь — отдельно (blood_fx.gd). dir — направление удара
static func impact(tree: SceneTree, at: Vector2, dir: Vector2, power := 1.0) -> void:
	var h := MageFx.holder(tree, at, 0.6, 12)
	# Разрез — поперёк удара, каждый раз под чуть другим углом
	var cut := _glint(h, 58.0 * power, 1.0, 0.14, Color(1.0, 0.95, 0.88))
	cut.rotation = dir.angle() + PI * 0.5 + randf_range(-0.5, 0.5)
	MageFx.flash(h, 20.0 * power, 0.1, Color(1.0, 0.93, 0.82))
	_ring(h, 4.0, 16.0 * power, 1.5, 0.14, Color(1.0, 0.95, 0.85, 0.7))
	_sparks(tree, at, dir, int(8 + 5 * power), 0.9, 90.0, 220.0, 0.36)


## Удар пришёлся в щит: звезда-блик, горячие искры обратно к бьющему,
## ударное кольцо, тёплый свет. dir — куда летят искры (к тому, кто ударил)
static func shield_hit(tree: SceneTree, at: Vector2, dir: Vector2, power := 1.0) -> void:
	var h := MageFx.holder(tree, at, 1.0, 12)
	var g := _glint(h, 64.0 * power, 0.0, 0.18, SPARK_HOT)
	g.rotation = randf_range(-0.25, 0.25)
	MageFx.flash(h, 32.0 * power, 0.12, SPARK_HOT)
	_ring(h, 5.0, 26.0 * power, 2.0, 0.2, Color(SPARK_WARM, 0.85))
	MageFx.light_pulse(h, 70.0 * power, 1.5, 0.28, SPARK_WARM)
	_sparks(tree, at, dir, int(14 + 8 * power), 1.5, 110.0, 300.0, 0.6)
	MageFx.smoke(h, 3, 4.0, 18.0, 0.5)


## Парирование: клинки скрестились — сильнее удара по щиту: большая звезда с
## длинными лучами, двойное кольцо, искры в обе стороны, яркий свет.
## dir — от парирующего к атакующему
static func parry(tree: SceneTree, at: Vector2, dir: Vector2) -> void:
	var h := MageFx.holder(tree, at, 1.2, 13)
	var big := _glint(h, 130.0, 0.0, 0.26, PARRY_TINT, 1.0)
	big.rotation = dir.angle() + PI * 0.5
	var small := _glint(h, 60.0, 0.0, 0.2, SPARK_HOT)
	small.rotation = big.rotation + PI * 0.25
	MageFx.flash(h, 32.0, 0.13, Color(1.0, 0.97, 0.9))
	_ring(h, 6.0, 46.0, 2.0, 0.28, Color(PARRY_TINT, 0.7))
	var tw := h.create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func(): _ring(h, 4.0, 30.0, 1.5, 0.22, Color(SPARK_WARM, 0.8)))
	MageFx.light_pulse(h, 85.0, 1.6, 0.35, Color(1.0, 0.9, 0.7))
	_sparks(tree, at, dir, 18, 1.2, 140.0, 340.0, 0.7)
	_sparks(tree, at, -dir, 12, 1.4, 100.0, 260.0, 0.6)


# ── Кирпичики ──────────────────────────────────────────────────────────────

static func _arc(knight: Node2D, from: float, to: float, radius: float, width: float, dur: float, power: float, delay: float,
		center := CHEST, linear := false, edge := Color(0, 0, 0, 0)) -> void:
	var spawn := func():
		if not is_instance_valid(knight):
			return
		var s: Node2D = SlashScript.new()
		s.setup(from, to, radius, width, dur, power)
		s.linear = linear
		# Свой цвет кромки (призрачная у скелета-ловкача); прозрачный — как у рыцаря
		if edge.a > 0.0:
			s.color_edge = edge
		s.position = center
		knight.add_child(s)
	if delay <= 0.0:
		spawn.call()
	else:
		knight.get_tree().create_timer(delay).timeout.connect(spawn)


## Сноп искр из точки at (точка в воздухе — узел искр ставится на землю под ней)
static func _sparks(tree: SceneTree, at: Vector2, dir: Vector2, count: int, spread: float, sp_min: float, sp_max: float, life: float) -> void:
	var height := 14.0
	var s: Node2D = SparkSpray.new()
	s.setup(count, dir, spread, sp_min, sp_max, height, life)
	s.position = at + Vector2(0, height)
	var root := tree.current_scene if tree.current_scene else tree.root
	root.add_child(s)


## Блик-звезда (cut = 1 — одна черта): вспыхивает с лёгким раздуванием и гаснет
static func _glint(parent: Node, size: float, cut: float, time: float, col: Color, ray := 1.0) -> Sprite2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = GLINT_SHADER
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("cut", cut)
	m.set_shader_parameter("ray_len", ray)
	m.set_shader_parameter("intensity", 1.3)
	s.material = m
	var full := Vector2.ONE * size / 4.0
	s.scale = full * 0.55
	parent.add_child(s)
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", full, time * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, time).set_ease(Tween.EASE_IN)
	return s


## Ударное кольцо, лежащее в 3/4 виде: расходится и тает
static func _ring(parent: Node, r0: float, r1: float, w: float, time: float, col: Color) -> void:
	var n := Node2D.new()
	n.scale = Vector2(1.0, DEPTH)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	n.material = m
	n.set_meta("r", r0)
	n.set_meta("a", 1.0)
	n.draw.connect(func():
		var r: float = n.get_meta("r")
		var a: float = n.get_meta("a")
		n.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col, col.a * a), w * (0.4 + 0.6 * a), true))
	parent.add_child(n)
	var t := n.create_tween()
	t.tween_method(func(v: float):
		n.set_meta("r", lerpf(r0, r1, v))
		n.set_meta("a", 1.0 - v)
		n.queue_redraw(), 0.0, 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(n.queue_free)


## Укол: клинок выстреливает вперёд. Пробивающая черта вылетает от груди за
## острие, рядом — две тонких линии скорости, на острие — звёздочка, кольцо
## сжатого воздуха поперёк укола и пара искр. В 3/4 виде укол "вглубь" экрана
## короче. dir — куда колет, center — грудь относительно узла
static func thrust(owner: Node2D, dir: Vector2, reach := 34.0, center := CHEST) -> void:
	if not is_instance_valid(owner):
		return
	var tree := owner.get_tree()
	var sd := Vector2(dir.x, dir.y * DEPTH).normalized()
	var length := reach * lerpf(DEPTH, 1.0, absf(sd.x))
	var base := owner.global_position + center
	var tip := base + sd * length
	var perp := Vector2(-sd.y, sd.x)

	var h := MageFx.holder(tree, base, 0.5, 12)
	var line := _glint(h, length * 2.2, 1.0, 0.15, STEEL)
	line.rotation = sd.angle()
	line.position = sd * length * 0.3
	line.create_tween().tween_property(line, "position", sd * length * 0.75, 0.1).set_ease(Tween.EASE_OUT)
	for side in [-1.0, 1.0]:
		var speed_line := _glint(h, length * 1.4, 1.0, 0.11, Color(0.72, 0.8, 1.0))
		speed_line.rotation = sd.angle()
		speed_line.position = sd * length * 0.25 + perp * 4.0 * side
		speed_line.create_tween().tween_property(speed_line, "position", sd * length * 0.6 + perp * 4.0 * side, 0.1)

	var th := MageFx.holder(tree, tip, 0.5, 12)
	_glint(th, 30.0, 0.0, 0.13, STEEL)
	_ring(th, 3.0, 14.0, 1.5, 0.16, Color(STEEL, 0.75))
	_sparks(tree, tip, sd, 4, 0.35, 120.0, 240.0, 0.25)


## Рубящий удар сверху: клинок идёт от головы вниз и вперёд — дуга в
## вертикальной плоскости вдоль удара (не вокруг тела), в конце — удар о
## землю перед бойцом. dur — за сколько клинок доходит донизу
static func chop(owner: Node2D, dir: Vector2, radius := 30.0, dur := 0.14, power := 1.25, center := CHEST,
		edge := Color(0, 0, 0, 0)) -> void:
	if not is_instance_valid(owner):
		return
	var fwd := Vector2(dir.x, dir.y * DEPTH)
	# Удар к камере или от неё лёг бы на экране в одну линию с "вверх" и
	# схлопнулся — даём клинку немного уйти вбок, как при рубке с плеча
	if absf(dir.x) < 0.5:
		fwd.x += 0.5 if dir.x >= 0.0 else -0.5
	var up := Vector2(0, -1)
	var from := deg_to_rad(105.0)
	var to := deg_to_rad(-35.0)
	var layers := [[radius, 0.3, power, 0.0], [radius * 0.82, 0.17, power * 0.45, minf(0.025, dur * 0.15)]]
	for l in layers:
		var spawn := func():
			if not is_instance_valid(owner):
				return
			var s: Node2D = SlashScript.new()
			s.setup(from, to, l[0], l[1], dur, l[2])
			s.linear = true
			s.basis_x = fwd
			s.basis_y = up
			if edge.a > 0.0:
				s.color_edge = edge
			s.position = center
			owner.add_child(s)
		if l[3] <= 0.0:
			spawn.call()
		else:
			owner.get_tree().create_timer(l[3]).timeout.connect(spawn)
	# Клинок дошёл донизу — удар о землю: вспышка, пыль, искры (ударное
	# кольцо здесь убрано — в конце удара оно выглядело лишним)
	var end := fwd * cos(to) * radius + up * sin(to) * radius
	owner.get_tree().create_timer(dur).timeout.connect(func():
		if not is_instance_valid(owner):
			return
		var at := owner.global_position + center + end
		var g := MageFx.holder(owner.get_tree(), at, 0.8, 11)
		MageFx.flash(g, 18.0 * power, 0.1, STEEL)
		MageFx.smoke(g, 4, 4.0, 16.0, 0.5)
		_sparks(owner.get_tree(), at, fwd.normalized(), 7, 1.3, 80.0, 200.0, 0.4))
