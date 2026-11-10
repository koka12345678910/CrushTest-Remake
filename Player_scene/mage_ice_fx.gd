extends RefCounted
## mage_ice_fx.gd — общие кусочки ЛЕДЯНЫХ заклинаний мага (Нифльхейм):
## кольцо инея, вихрь, луч, ледяной шаг. Пара к mage_fx.gd (голубое пламя
## Муспельхейма) — оттуда берутся частицы, свет и вспышки, здесь своё:
## кристаллы-шипы, иней на земле, осколки, морозная дымка и «озноб» врагов.
##   const IceFx := preload("res://Player_scene/mage_ice_fx.gd")
##
## Палитра отличается от огня: огонь мага — глубокий синий с белым ядром,
## лёд — бледный, почти белый циан с голубыми гранями. На тёмной земле
## кладбища лёд читается светлым, огонь — насыщенным.
##
## Сортировка: шипы и прочее «стоячее» кладётся прямо в y-sort уровня. У героев
## и врагов узел — на SORT_LIFT выше ног (картинки 128x128, ноги в 27 px от
## центра кадра, см. mage.gd::FEET_PX), поэтому стоячий объект тоже держит узел
## на SORT_LIFT выше своего основания — иначе шип позади мага рисовался бы
## поверх него.

const MageFx := preload("res://Player_scene/mage_fx.gd")

const CORE := Color(0.93, 0.98, 1.0)
const MID := Color(0.6, 0.88, 1.0)
const EDGE := Color(0.24, 0.55, 0.95)
## Тело кристалла: основание темнее, к острию светлее
const BODY_DARK := Color(0.1, 0.24, 0.42)
const BODY_LIGHT := Color(0.62, 0.86, 1.0)
const MIST := Color(0.72, 0.86, 0.96)
const SORT_LIFT := 24.0
## Озноб: оттенок спрайта врага, пока он замедлен льдом
const CHILL_TINT := Color(0.74, 0.9, 1.18)

static var _shard: ImageTexture
static var _frost: ImageTexture
static var _unshaded: CanvasItemMaterial


## Материал без освещения сцены: лёд виден и ночью, но не светится сам
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Осколок: узкий ромб с ярким ребром посередине. Частица с align_y тянется
## по полёту, без него — кувыркается обломком
static func shard_tex() -> ImageTexture:
	if _shard == null:
		var w := 12
		var h := 40
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var dx := absf(x - (w - 1) * 0.5) / (w * 0.5)
				var dy := absf(y - (h - 1) * 0.5) / (h * 0.5)
				var d := dx + dy
				if d >= 1.0:
					img.set_pixel(x, y, Color(1, 1, 1, 0))
					continue
				# Ребро по центру ярче, грани — прозрачнее
				var a := (1.0 - d) * 1.4 * (1.0 - dx * 0.55)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_shard = ImageTexture.create_from_image(img)
	return _shard


## Иней на земле: ячеистый узор (клетки шума Вороного) — как морозные
## кристаллы на стекле, тает к краю неровно
static func frost_tex() -> ImageTexture:
	if _frost == null:
		var cell := FastNoiseLite.new()
		cell.noise_type = FastNoiseLite.TYPE_CELLULAR
		cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		cell.frequency = 0.09
		cell.seed = 77
		var edge := FastNoiseLite.new()
		edge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		edge.frequency = 0.05
		edge.seed = 5
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := (size - 1) * 0.5
		for y in size:
			for x in size:
				var v := Vector2(x - c, y - c)
				var d := v.length() / (size * 0.5)
				# Неровный край пятна
				var rim := 0.78 + edge.get_noise_2d(x, y) * 0.22
				var fall := 1.0 - smoothstep(rim - 0.35, rim, d)
				# Прожилки — тёмные границы ячеек светлые, середины прозрачнее
				var cv := clampf(cell.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
				var veins := pow(cv, 2.2)
				var a := fall * (0.18 + 0.82 * veins)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_frost = ImageTexture.create_from_image(img)
	return _frost


# ===================== ЦЕЛИ И УДАР =====================

## Живые враги и разбиваемые предметы, которых можно ранить. Мини-босс в
## группе "enemy" без take_damage пропускается (как в mage.gd::_special_targets)
static func targets(tree: SceneTree) -> Array:
	var out := []
	for e in tree.get_nodes_in_group("enemy") + tree.get_nodes_in_group("breakable"):
		if not is_instance_valid(e) or not (e is Node2D) or not "is_dead" in e or e.is_dead:
			continue
		if not e.has_method("take_damage"):
			continue
		out.append(e)
	return out


## Точка под ногами врага: узел у героев и врагов — на SORT_LIFT выше ног
static func feet(e: Node2D) -> Vector2:
	return e.global_position + Vector2(0, SORT_LIFT)


## Расстояние на земле с той же сплюснутостью, что у колец (по вертикали
## круг на земле короче — вид 3/4)
static func ground_dist(a: Vector2, b: Vector2, squash := 0.8) -> float:
	var to := b - a
	return Vector2(to.x, to.y / squash).length()


## Удар льдом: урон (0 — без урона), отброс от точки from, озноб и осколки
## на враге. Удар засчитывается магу (caster) — от этого зависят души, навыки
## и «Дар ушедших»
static func hit(caster: Node2D, e: Node2D, dmg: int, from: Vector2, push: float,
		slow_pct := 0.0, slow_sec := 0.0) -> void:
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	var to := e.global_position - from
	var dir := to.normalized() if to.length() > 0.001 else Vector2.DOWN
	if dmg > 0:
		# Стихия удара — для реакций мага (mage_reactions.gd::strike, тот же
		# приём; здесь своими руками, чтобы файлы не ссылались друг на друга)
		if is_instance_valid(caster):
			caster.set_meta("hit_element", "ice")
		e.take_damage(dmg, caster)
		if is_instance_valid(caster):
			caster.set_meta("hit_element", "")
	if is_instance_valid(e) and e.get("is_dead") != true:
		if push > 0.0 and "knockback_velocity" in e:
			e.knockback_velocity = dir * push
		if slow_sec > 0.0:
			chill(e, slow_pct, slow_sec)
	var h := MageFx.holder(e.get_tree(), e.global_position + Vector2(0, -8), 0.8, 12)
	MageFx.flash(h, 20.0, 0.12, CORE)
	shards(h, 7, 120.0, 0.45, dir, 70.0)


## Озноб: замедление (enemy.gd::apply_slow) + метка до какого времени враг
## охлаждён (её прочтут стихийные реакции), бледно-голубой оттенок спрайта и
## снежинки, осыпающиеся с врага
static func chill(e: Node2D, pct: float, sec: float) -> void:
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	# Реакция только что «сожгла» метки (пар) — тот же удар не охлаждает заново
	if Time.get_ticks_msec() / 1000.0 < float(e.get_meta("status_lock_until", 0.0)):
		return
	if e.has_method("apply_slow"):
		e.apply_slow(pct, sec)
	var until := Time.get_ticks_msec() / 1000.0 + sec
	var prev: float = e.get_meta("chilled_until", 0.0)
	e.set_meta("chilled_until", maxf(until, prev))
	var sp := e.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sp:
		sp.self_modulate = CHILL_TINT
	var fx := e.get_node_or_null("ChillFx") as Node2D
	if fx == null:
		fx = Node2D.new()
		fx.name = "ChillFx"
		fx.z_index = 1
		e.add_child(fx)
		var p := GPUParticles2D.new()
		p.amount = 7
		p.lifetime = 0.9
		p.local_coords = false
		p.texture = MageFx.dot()
		p.visibility_rect = MageFx.VIS_RECT
		p.material = MageFx.add_material()
		var pm := ParticleProcessMaterial.new()
		pm.particle_flag_disable_z = true
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(9, 14, 0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 25.0
		pm.initial_velocity_min = 6.0
		pm.initial_velocity_max = 16.0
		pm.gravity = Vector3(0, 12, 0)
		pm.scale_min = 0.35
		pm.scale_max = 0.7
		pm.color_ramp = MageFx.ramp([Color(CORE, 0.0), Color(MID, 0.85), Color(EDGE, 0.0)], [0.0, 0.25, 1.0])
		p.process_material = pm
		p.position = Vector2(0, -6)
		fx.add_child(p)
	# Снять озноб, когда истечёт — если за это время не охладили заново.
	# Враг может исчезнуть раньше — держим слабую ссылку, а не сам узел
	var wr: WeakRef = weakref(e)
	e.get_tree().create_timer(sec + 0.05).timeout.connect(func():
		var en := wr.get_ref() as Node2D
		if en == null:
			return
		if Time.get_ticks_msec() / 1000.0 + 0.01 < float(en.get_meta("chilled_until", 0.0)):
			return
		var s := en.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if s:
			s.self_modulate = Color.WHITE
		var f := en.get_node_or_null("ChillFx")
		if f:
			f.queue_free())


static func is_chilled(e: Node) -> bool:
	return is_instance_valid(e) and Time.get_ticks_msec() / 1000.0 < float(e.get_meta("chilled_until", 0.0))


# ===================== КУСОЧКИ ЭФФЕКТОВ =====================

## Осколки льда: аддитивные обломки, кувыркаются и падают
static func shards(parent: Node, amount: int, speed: float, life: float, dir := Vector2.ZERO,
		spread := 180.0, gravity := 260.0) -> void:
	MageFx.burst(parent, amount, life, shard_tex(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(dir.x, dir.y, 0) if dir != Vector2.ZERO else Vector3(0, -1, 0)
		pm.spread = spread
		pm.initial_velocity_min = speed * 0.4
		pm.initial_velocity_max = speed
		pm.damping_min = speed * 0.4
		pm.damping_max = speed * 0.9
		pm.gravity = Vector3(0, gravity, 0)
		pm.scale_min = 0.22
		pm.scale_max = 0.5
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -540.0
		pm.angular_velocity_max = 540.0
		pm.color_ramp = MageFx.ramp([Color(CORE, 1.0), Color(MID, 0.9), Color(EDGE, 0.0)], [0.0, 0.5, 1.0]))


## Морозная дымка: бледные клубы стелются и тают (не светится — туманит)
static func mist(parent: Node, amount: int, area: float, size: float, life := 1.0, alpha := 0.26) -> void:
	var p := MageFx.burst(parent, amount, life, MageFx.soft(), func(pm: ParticleProcessMaterial):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = area
		pm.direction = Vector3(1, 0, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 6.0
		pm.initial_velocity_max = 22.0
		pm.damping_min = 6.0
		pm.damping_max = 14.0
		pm.gravity = Vector3(0, -6, 0)
		pm.scale_min = size * 0.6 / 64.0
		pm.scale_max = size / 64.0
		pm.scale_curve = MageFx.size_curve(0.4)
		pm.angle_max = 360.0
		pm.color_ramp = MageFx.ramp([Color(MIST, 0.0), Color(MIST, alpha), Color(MIST, 0.0)], [0.0, 0.25, 1.0]), false)
	p.explosiveness = 0.75
	p.scale = Vector2(1.0, 0.7)


## Иней на земле: пятно проступает, держится hold секунд и тает. Под героями
## (как трещина в juice.gd::ground_crack)
static func frost_decal(tree: SceneTree, at: Vector2, radius: float, hold := 2.5, alpha := 0.55) -> Node2D:
	var root := tree.current_scene
	if root == null:
		return null
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = -15
	root.add_child(n)
	n.global_position = at
	var s := Sprite2D.new()
	s.texture = frost_tex()
	s.material = unshaded()
	s.rotation = randf() * TAU
	# Поворот — у самой текстуры, сплющивание — у узла (иначе повёрнутый
	# эллипс лёг бы на землю наискось)
	n.scale = Vector2(1.0, 0.62)
	s.scale = Vector2.ONE * radius * 2.0 / 128.0 * 0.6
	s.modulate = Color(0.8, 0.93, 1.0, 0.0)
	n.add_child(s)
	var t := n.create_tween()
	t.set_parallel(true)
	t.tween_property(s, "modulate:a", alpha, 0.14)
	t.tween_property(s, "scale", Vector2.ONE * radius * 2.0 / 128.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.set_parallel(false)
	t.tween_interval(hold)
	t.tween_property(s, "modulate:a", 0.0, 1.2)
	t.tween_callback(n.queue_free)
	return n


## Ледяной шип: кристалл вырастает из земли (с перехлёстом), стоит life
## секунд и разлетается осколками. base — точка основания в мире, lean —
## наклон в радианах (наружу от центра заклинания). Кладётся в y-sort уровня
static func spike(tree: SceneTree, base: Vector2, height: float, width: float, delay: float,
		life: float, lean := 0.0) -> Node2D:
	var root := tree.current_scene
	if root == null:
		return null
	var n := Node2D.new()
	n.z_index = 1
	root.add_child(n)
	n.global_position = base - Vector2(0, SORT_LIFT)
	var pivot := Node2D.new()
	pivot.position = Vector2(0, SORT_LIFT)
	pivot.rotation = lean
	pivot.scale = Vector2(1.0, 0.0)
	n.add_child(pivot)

	var hw := width * 0.5
	var tip := Vector2(randf_range(-0.12, 0.12) * width, -height)
	var left_sh := Vector2(-hw * 0.62, -height * randf_range(0.42, 0.58))
	var right_sh := Vector2(hw * 0.55, -height * randf_range(0.36, 0.52))
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-hw, 0), left_sh, tip, right_sh, Vector2(hw, 0)])
	body.vertex_colors = PackedColorArray([
		Color(BODY_DARK, 0.92), Color(BODY_LIGHT.darkened(0.25), 0.9), Color(CORE, 0.95),
		Color(BODY_LIGHT.darkened(0.45), 0.9), Color(BODY_DARK.darkened(0.2), 0.92)])
	body.material = unshaded()
	pivot.add_child(body)
	# Светлая грань слева (свет мага) — аддитивно, даёт «стеклянность»
	var facet := Polygon2D.new()
	facet.polygon = PackedVector2Array([Vector2(-hw * 0.7, 0), left_sh, tip, Vector2(-hw * 0.05, -height * 0.2)])
	facet.vertex_colors = PackedColorArray([Color(MID, 0.05), Color(MID, 0.35), Color(CORE, 0.75), Color(MID, 0.15)])
	facet.material = MageFx.add_material()
	pivot.add_child(facet)
	var rim := Line2D.new()
	rim.points = PackedVector2Array([Vector2(-hw, 0), left_sh, tip, right_sh, Vector2(hw, 0)])
	rim.width = 1.0
	rim.default_color = Color(CORE, 0.55)
	rim.material = MageFx.add_material()
	pivot.add_child(rim)

	var t := n.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(pivot, "scale", Vector2(1.0, 1.14), 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(pivot, "scale", Vector2.ONE, 0.09).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(life)
	# Перед тем как лопнуть — вспыхивает
	t.tween_property(n, "modulate", Color(1.8, 1.9, 2.0, 1.0), 0.05)
	t.tween_callback(func():
		var h := MageFx.holder(tree, base + Vector2(0, -height * 0.45), 0.9, 12)
		shards(h, 4 + int(height / 12.0), 70.0 + height, 0.5, Vector2.UP, 80.0, 300.0))
	t.set_parallel(true)
	t.tween_property(pivot, "scale", Vector2(0.6, 0.15), 0.16).set_ease(Tween.EASE_IN)
	t.tween_property(n, "modulate:a", 0.0, 0.16)
	t.set_parallel(false)
	t.tween_callback(n.queue_free)
	return n


## Ледяной след-двойник: копия текущего кадра мага бледно-голубая,
## прибавляет свет и тает (как призрак ловкача, duelist_fx.gd::ghost)
static func ghost(body: Node2D, sp: AnimatedSprite2D, alpha := 0.45, life := 0.3) -> void:
	if not is_instance_valid(body) or not is_instance_valid(sp) or sp.sprite_frames == null:
		return
	if not sp.sprite_frames.has_animation(sp.animation):
		return
	var root := body.get_tree().current_scene
	if root == null:
		return
	var g := Sprite2D.new()
	g.texture = sp.sprite_frames.get_frame_texture(sp.animation, sp.frame)
	g.material = MageFx.add_material()
	g.texture_filter = sp.texture_filter
	g.scale = sp.scale
	g.flip_h = sp.flip_h
	g.modulate = Color(MID, alpha)
	g.z_index = body.z_index
	root.add_child(g)
	g.global_position = sp.global_position
	var t := g.create_tween()
	t.set_parallel(true)
	t.tween_property(g, "modulate:a", 0.0, life)
	t.tween_property(g, "scale", g.scale * 1.06, life)
	t.set_parallel(false)
	t.tween_callback(g.queue_free)
