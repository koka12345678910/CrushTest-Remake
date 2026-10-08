extends Area2D
## mage_fireball.gd — синий огненный шар мага (первая атака, Attack_).
## Летит по прямой; при попадании во врага, в стену или в конце полёта
## взрывается: прямая цель получает direct_damage, все остальные враги в
## splash_radius — splash_damage.
##
## Собран целиком кодом, без .tscn — тот же приём, что у стрелы (arrow.gd).
## Урон бьёт напрямую через enemy.take_damage(dmg, маг): source — сам маг,
## чтобы враг агрился на игрока, а не на снаряд.

const GLOW_FRAMES := preload("res://TileMap/Textures Of Light/32x32/animation/1.png")
const GLOW_FRAME_COUNT := 10

@export var speed := 300.0
@export var lifetime := 1.3
@export var direct_damage := 2
@export var splash_damage := 1
@export var splash_radius := 56.0
@export var color := Color(0.35, 0.65, 1.0)

var _caster: Node2D
var _direction := Vector2.RIGHT
var _age := 0.0
var _exploded := false
var _core: AnimatedSprite2D
var _trail: GPUParticles2D
var _light: PointLight2D


func launch(from: Vector2, direction: Vector2, caster: Node2D) -> void:
	global_position = from
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_caster = caster


func _ready() -> void:
	z_index = 10
	area_entered.connect(_on_area_entered)
	# Маска по умолчанию — слой 1 "world": стены тайлов и статические тела
	body_entered.connect(_on_body_entered)

	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	# Ядро — анимированное свечение, тонированное в синий
	_core = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 16.0)
	for i in GLOW_FRAME_COUNT:
		var at := AtlasTexture.new()
		at.atlas = GLOW_FRAMES
		at.region = Rect2(i * 32, 0, 32, 32)
		sf.add_frame("default", at)
	_core.sprite_frames = sf
	_core.material = add_mat
	_core.modulate = Color(color.r * 1.6, color.g * 1.6, color.b * 2.0, 1.0)
	_core.scale = Vector2(0.75, 0.75)
	_core.play("default")
	add_child(_core)

	# Хвост — искры, остающиеся в мире (local_coords = false)
	_trail = GPUParticles2D.new()
	_trail.amount = 28
	_trail.lifetime = 0.45
	_trail.local_coords = false
	_trail.material = add_mat
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 3.0
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.8
	pm.color_ramp = _ramp([Color(0.75, 0.9, 1.0, 1.0), Color(color, 0.8), Color(0.1, 0.2, 0.8, 0.0)])
	_trail.process_material = pm
	_trail.texture = _dot_texture()
	add_child(_trail)

	# Свет — подсвечивает тёмную карту вокруг шара
	_light = PointLight2D.new()
	_light.color = color
	_light.energy = 1.1
	_light.texture = _radial_texture()
	_light.texture_scale = 0.7
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)


## Движение — в физическом кадре (фиксированный шаг): при просадке FPS шар
## не "перепрыгивает" узкий хёртбокс врага за один кадр
func _physics_process(delta: float) -> void:
	if _exploded:
		return
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		_explode(null)


func _on_area_entered(area: Area2D) -> void:
	if _exploded or not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := area.get_parent()
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if "is_dead" in enemy and enemy.is_dead:
		return
	_explode(enemy)


func _on_body_entered(body: Node) -> void:
	if _exploded or body == _caster:
		return
	_explode(null)


func _explode(direct_hit: Node2D) -> void:
	_exploded = true
	set_deferred("monitoring", false)
	var center := global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if e == direct_hit:
			e.take_damage(direct_damage, _caster)
		elif center.distance_to(e.global_position) <= splash_radius:
			e.take_damage(splash_damage, _caster)
	_spawn_burst(center)
	# Шар гаснет, хвост доживает своё
	_core.visible = false
	_trail.emitting = false
	var t := create_tween()
	t.tween_property(_light, "energy", 0.0, 0.25)
	await get_tree().create_timer(_trail.lifetime + 0.1).timeout
	queue_free()


## Вспышка взрыва — отдельный узел в мире: шар уже исчезает, а взрыв должен
## доиграть на месте
func _spawn_burst(at: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var burst := Node2D.new()
	burst.global_position = at
	burst.z_index = 11
	root.add_child(burst)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var sparks := GPUParticles2D.new()
	sparks.amount = 40
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.material = add_mat
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 120.0
	pm.damping_min = 120.0
	pm.damping_max = 200.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.0
	pm.scale_max = 2.4
	pm.color_ramp = _ramp([Color(0.85, 0.95, 1.0, 1.0), Color(color, 0.9), Color(0.1, 0.2, 0.9, 0.0)])
	sparks.process_material = pm
	sparks.texture = _dot_texture()
	burst.add_child(sparks)
	sparks.emitting = true

	# Кольцо-вспышка: тот же светящийся спрайт, быстро раздувается и гаснет
	var ring := Sprite2D.new()
	var ring_tex := AtlasTexture.new()
	ring_tex.atlas = GLOW_FRAMES
	ring_tex.region = Rect2(0, 0, 32, 32)
	ring.texture = ring_tex
	ring.material = add_mat
	ring.modulate = Color(color.r * 1.5, color.g * 1.5, color.b * 2.0, 1.0)
	ring.scale = Vector2(0.6, 0.6)
	burst.add_child(ring)

	var light := PointLight2D.new()
	light.color = color
	light.energy = 1.8
	light.texture = _radial_texture()
	light.texture_scale = splash_radius * 2.4 / 128.0
	light.blend_mode = Light2D.BLEND_MODE_ADD
	burst.add_child(light)

	var full := splash_radius * 2.0 / 32.0
	var t := burst.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(full, full), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(ring, "modulate:a", 0.0, 0.3)
	t.tween_property(light, "energy", 0.0, 0.4)
	t.chain().tween_interval(0.3)
	t.chain().tween_callback(burst.queue_free)


func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 4
	t.height = 4
	return t


func _radial_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t
