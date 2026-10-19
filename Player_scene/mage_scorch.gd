extends Node2D
## mage_scorch.gd — ближняя атака мага (ПКМ, Attack_2_): выжигание земли
## перед магом. Не поток от руки, а облако голубого огня, которое вспыхивает
## у ног и размеренно, с постоянной скоростью, катится вперёд конусом:
## сначала горит маленький пятачок перед магом, потом клубящийся фронт уходит
## всё дальше. Враг получает урон и отброс
## ровно тогда, когда до него докатился фронт, — не весь сектор разом.
## Позади фронта огонь опадает и остаётся обугленная земля, которая медленно
## гаснет.
##
## Живёт в мире, а не на маге: выжженная земля остаётся на месте, даже если
## маг отошёл. Собрана целиком кодом:
##   - конус на земле с шейдером Shaders/magic_scorch.gdshader — свечение под
##     огнём, раскалённая кромка фронта, обугленная земля;
##   - сам огонь — облако из клубов (Shaders/magic_fire_cloud.gdshader):
##     клубы непрерывно рождаются на фронте по всей его ширине, растут,
##     перекатываются вперёд и вверх, остывают и уходят тёмным дымом — так
##     облако клубится и катится, а позади него огонь опадает;
##   - дым позади фронта, голубой свет вместе с фронтом, вспышка поджига.

const SHADER := preload("res://Shaders/magic_scorch.gdshader")
const CLOUD_SHADER := preload("res://Shaders/magic_fire_cloud.gdshader")
const MageFx := preload("res://Player_scene/mage_fx.gd")
## Сплющенность земли по вертикали (3/4 вид), как у дуг клинка
const DEPTH := 0.62
const SEG_ACROSS := 18
const SEG_ALONG := 26

## Конус: откуда начинается (от ног), докуда доходит, половина угла
@export var start_dist := 6.0
@export var reach := 158.0
@export var half_angle_deg := 38.0
## Поджиг (огонь у ног до ignite_progress), рост до конца, горение, угасание
@export var ignite_time := 0.08
@export var ignite_progress := 0.14
@export var grow_time := 0.5
@export var hold_time := 0.18
@export var fire_fade_time := 0.5
@export var char_fade_time := 2.4
## Клубы облака: сколько рождается в секунду на всю ширину фронта, размер у
## ног и у дальнего края, сколько живёт клуб и насколько его уносит вперёд
@export var puff_rate := 48.0
@export var puff_size_near := 42.0
@export var puff_size_far := 76.0
@export var puff_life := 0.85
@export var puff_drift := 40.0

var damage := 1
var knockback := 180.0

var _caster: Node2D
var _facing := Vector2.DOWN
var _round_angle := 0.0
var _mat: ShaderMaterial
var _progress := 0.0
var _hit := {}
var _emitting := true
var _spawn_acc := 0.0
## Куда катится облако на экране (единичный вектор вдоль конуса)
var _fwd := Vector2.DOWN
var _smoke: GPUParticles2D
var _smoke_pm: ParticleProcessMaterial
var _light: PointLight2D
var _fx: Node2D
static var _white: ImageTexture


## at — точка у ног мага (координаты мира), facing — куда он смотрит
func setup(caster: Node2D, facing: Vector2, at: Vector2, dmg: int, push: float) -> void:
	_caster = caster
	_facing = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	damage = dmg
	knockback = push
	position = at


func _ready() -> void:
	# Земля: над кровью (blood_decals.gd, -16), под персонажами
	z_as_relative = false
	z_index = -15
	_round_angle = Vector2(_facing.x, _facing.y / DEPTH).angle()

	var mesh := MeshInstance2D.new()
	mesh.mesh = _build_cone()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise_tex", MageFx.noise_tex())
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("seed", randf() * 10.0)
	mesh.material = _mat
	add_child(mesh)

	# Огонь и дым — над землёй. y-sort: нижние (ближние к камере) языки пламени
	# перекрывают верхние, как и положено в 3/4 виде
	_fx = Node2D.new()
	_fx.z_as_relative = false
	_fx.z_index = 11
	_fx.y_sort_enabled = true
	add_child(_fx)
	_build_smoke()
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	_fwd = (_ground_point(1.0, 0.0) - _ground_point(0.0, 0.0)).normalized()

	_light = PointLight2D.new()
	_light.texture = MageFx.radial()
	_light.color = MageFx.MID
	_light.energy = 0.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	_fx.add_child(_light)

	# Поджиг у ног — короткая вспышка, с неё начинается выжигание
	var ig := MageFx.holder(get_tree(), global_position + _ground_point(0.1, 0.0), 0.6, 11)
	MageFx.flash(ig, 34.0, 0.16)

	_set_progress(0.0)
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, ignite_progress, ignite_time).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_light, "energy", 0.8, ignite_time)
	# Облако катится вперёд размеренно — с постоянной скоростью
	t.tween_method(_set_progress, ignite_progress, 1.0, grow_time)
	t.parallel().tween_property(_light, "energy", 1.0, grow_time)
	t.tween_interval(hold_time)
	t.tween_callback(func():
		_smoke.emitting = false
		_emitting = false)
	t.tween_method(_set_fire, 1.0, 0.0, fire_fade_time).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_light, "energy", 0.0, fire_fade_time)
	t.tween_method(_set_char, 1.0, 0.0, char_fade_time).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


## Точка на земле конуса: along — 0..1 от ног к краю, across — -1..1 поперёк
func _ground_point(along: float, across: float) -> Vector2:
	var r := lerpf(start_dist, reach, along)
	var a := _round_angle + deg_to_rad(half_angle_deg) * across
	var p := Vector2.from_angle(a) * r
	return Vector2(p.x, p.y * DEPTH)


func _build_cone() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in SEG_ALONG + 1:
		var v := float(j) / SEG_ALONG
		for i in SEG_ACROSS + 1:
			var u := float(i) / SEG_ACROSS
			verts.append(_ground_point(v, u * 2.0 - 1.0))
			uvs.append(Vector2(u, v))
	var row := SEG_ACROSS + 1
	for j in SEG_ALONG:
		for i in SEG_ACROSS:
			var a := j * row + i
			idx.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Пока облако катится (и чуть после, пока фронт стоит у края) — на фронте
## непрерывно рождаются клубы. Чем шире конус на этой дальности, тем их больше
func _process(delta: float) -> void:
	if not _emitting:
		return
	_spawn_acc += delta * puff_rate * lerpf(0.35, 1.0, _progress)
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		_spawn_puff()


## Клуб огня рождается на фронте (или чуть позади), раздувается, катится
## вперёд и вверх, остывает в дым и рассеивается
func _spawn_puff() -> void:
	var along := clampf(_progress + randf_range(-0.07, 0.02), 0.02, 1.0)
	var across := randf_range(-0.92, 0.92) * lerpf(0.75, 1.0, along)
	var size := lerpf(puff_size_near, puff_size_far, along) * randf_range(0.75, 1.2)
	# Посередине конуса клубы крупнее — облако "горбится", а не лежит плитой
	size *= 1.0 - absf(across) * 0.25
	var s := Sprite2D.new()
	s.texture = _white
	s.scale = Vector2(size, size * 0.9) / 4.0 * 0.55
	# Клуб висит над землёй на полвысоты: узел — точка земли (по ней y-sort)
	s.offset = Vector2(0, -1.6)
	s.position = _ground_point(along, across)
	var m := ShaderMaterial.new()
	m.shader = CLOUD_SHADER
	m.set_shader_parameter("noise_tex", MageFx.noise_tex())
	m.set_shader_parameter("seed", randf() * 10.0)
	m.set_shader_parameter("age", 0.0)
	m.set_shader_parameter("intensity", 0.3)
	s.material = m
	_fx.add_child(s)
	var life := puff_life * randf_range(0.8, 1.2)
	var drift := _fwd * puff_drift * randf_range(0.6, 1.2) + Vector2(randf_range(-6.0, 6.0), -randf_range(4.0, 12.0))
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2(size, size * 0.9) / 4.0 * randf_range(1.0, 1.2), life * 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(s, "position", s.position + drift, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_method(func(v: float): m.set_shader_parameter("age", v), 0.0, 1.0, life)
	t.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
	t.chain().tween_callback(s.queue_free)


func _build_smoke() -> void:
	# Дым позади фронта — тёмный, без освещения и не аддитивный
	_smoke = GPUParticles2D.new()
	_smoke.amount = 18
	_smoke.lifetime = 1.4
	_smoke.local_coords = false
	_smoke.texture = MageFx.soft()
	_smoke.visibility_rect = MageFx.VIS_RECT
	var sm := CanvasItemMaterial.new()
	sm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_smoke.material = sm
	_smoke_pm = ParticleProcessMaterial.new()
	_smoke_pm.particle_flag_disable_z = true
	_smoke_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_smoke_pm.emission_box_extents = Vector3(4, 4, 0)
	_smoke_pm.direction = Vector3(0, -1, 0)
	_smoke_pm.spread = 30.0
	_smoke_pm.initial_velocity_min = 6.0
	_smoke_pm.initial_velocity_max = 16.0
	_smoke_pm.gravity = Vector3(0, -9, 0)
	_smoke_pm.scale_min = 20.0 / 64.0
	_smoke_pm.scale_max = 36.0 / 64.0
	_smoke_pm.scale_curve = MageFx.size_curve(0.4)
	_smoke_pm.angle_min = 0.0
	_smoke_pm.angle_max = 360.0
	_smoke_pm.color_ramp = MageFx.ramp([Color(MageFx.SMOKE, 0.0), Color(MageFx.SMOKE, 0.38), Color(MageFx.SMOKE, 0.0)], [0.0, 0.25, 1.0])
	_smoke.process_material = _smoke_pm
	# Дым — поверх огня, не участвует в y-sort языков (лежит "выше" по экрану)
	_smoke.z_as_relative = false
	_smoke.z_index = 12
	add_child(_smoke)


func _set_progress(v: float) -> void:
	_progress = v
	_mat.set_shader_parameter("progress", v)
	# Дым — над уже выжженным, позади фронта
	var mid := maxf(v - 0.25, 0.0)
	var across := (_ground_point(mid, 1.0) - _ground_point(mid, -1.0))
	_smoke.position = _ground_point(mid, 0.0)
	_smoke.rotation = across.angle()
	var up := Vector2(0, -1).rotated(-_smoke.rotation)
	_smoke_pm.direction = Vector3(up.x, up.y, 0.0)
	_smoke_pm.emission_box_extents = Vector3(maxf(across.length() * 0.38, 3.0), 4.0, 0.0)
	_light.position = _ground_point(v, 0.0)
	_light.texture_scale = (28.0 + v * reach * 0.35) * 2.0 / 128.0
	_burn_enemies()


func _set_fire(v: float) -> void:
	_mat.set_shader_parameter("fire", v)


func _set_char(v: float) -> void:
	_mat.set_shader_parameter("char_amount", v)


## Урон тем, до кого уже докатился фронт: враг — в конусе по углу, и его ноги
## не дальше текущего фронта. Каждого — один раз за заклинание
func _burn_enemies() -> void:
	if not is_instance_valid(_caster):
		return
	var front_r := lerpf(start_dist, reach, _progress) + 8.0
	var half := deg_to_rad(half_angle_deg + 8.0)
	# Разбиваемые предметы (breakable_prop.gd) отвечают тем же, что враги
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("breakable"):
		if not is_instance_valid(e) or e.is_dead or _hit.has(e):
			continue
		var feet: Vector2 = e.global_position
		if _caster.has_method("_ground_offset"):
			feet += _caster._ground_offset(e)
		var to: Vector2 = feet - global_position
		# В "круглое" пространство земли — там конус настоящий, без сплющивания
		var round_to := Vector2(to.x, to.y / DEPTH)
		var r := round_to.length()
		if r > front_r:
			continue
		if r > 10.0 and absf(angle_difference(_round_angle, round_to.angle())) > half:
			continue
		_hit[e] = true
		var push_dir := to.normalized() if to.length() > 0.001 else _facing
		e.take_damage(damage, _caster)
		MageFx.hit_burst(get_tree(), e.global_position, push_dir)
		# Отброс — от мага, вдоль выжигания
		if not e.is_dead and "knockback_velocity" in e:
			e.knockback_velocity = push_dir * knockback
