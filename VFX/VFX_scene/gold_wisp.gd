extends Node2D
## gold_wisp.gd — золото, выпавшее из врага или разбитого ящика: не монета на
## земле, а полупрозрачная золотая "душа", которая сама взлетает и летит к
## игроку. Подбирать ничего не нужно — долетела, золото засчитано, звенят
## монетки, игрока коротко подсвечивает золотом.
##
## Создаётся только кодом:
##   const GoldWisp := preload("res://VFX/VFX_scene/gold_wisp.gd")
##   GoldWisp.spawn(get_tree(), global_position, value)
##
## Сама душа — несколько аддитивных слоёв (MageFx): широкий тусклый ореол,
## плотное ядро, мерцающая искра в центре, шлейф угасающих золотых пылинок
## и слабый тёплый свет на землю. Полёт: сначала вспархивает от места
## выпадения и зависает, потом разгоняется к игроку по изгибу, покачиваясь —
## как душа, а не как пуля.

const MageFx := preload("res://Player_scene/mage_fx.gd")
const COIN_SOUND := preload("res://Sound/coin_picking.mp3")

const GOLD_CORE := Color(1.0, 0.95, 0.72)
const GOLD_MID := Color(1.0, 0.76, 0.28)
const GOLD_EDGE := Color(0.85, 0.42, 0.08)
## Общая яркость души: гасит разом все слои, шлейф, вспышку на подлёте и
## свет на землю (1.0 — исходная, ярче смотрелось слишком кричаще)
const GLOW := 0.7

## Сколько золота несёт душа
var value := 5
## Душа крупного номинала — крупнее и ярче
var is_big := false

var _velocity := Vector2.ZERO
var _t := 0.0
## Сколько секунд душа вспархивает и висит, прежде чем полететь к игроку —
## у каждой своё, чтобы стайка долетала по одной, а не единым щелчком
var _rise_time := 0.5
var _seed := 0.0
var _collected := false

var _halo: Sprite2D
var _core: Sprite2D
var _spark: Sprite2D
var _tail: Sprite2D
var _trail: GPUParticles2D
var _light: PointLight2D

## Звон нескольких душ подряд не должен сливаться в треск
static var _last_sound_ms := 0


static func spawn(tree: SceneTree, at: Vector2, amount: int, big := false) -> Node2D:
	# Свой же скрипт — через load: в статической функции unqualified new() нет
	var w: Node2D = load("res://VFX/VFX_scene/gold_wisp.gd").new()
	w.value = amount
	w.is_big = big
	var root := tree.current_scene if tree.current_scene else tree.root
	# Позиция — до добавления (корень уровня в нуле), а само добавление —
	# отложенное: выпадение случается посреди физики (смерть врага от удара)
	w.position = at
	root.add_child.call_deferred(w)
	return w


func _ready() -> void:
	z_index = 12
	_seed = randf() * TAU
	_rise_time = randf_range(0.35, 0.75)
	# Вспархивает в случайную сторону, но скорее вверх
	var a := randf_range(-PI, 0.0)
	_velocity = Vector2.from_angle(a) * randf_range(50.0, 110.0) + Vector2(0, -40)
	var sz := 1.35 if is_big else 1.0

	_trail = GPUParticles2D.new()
	_trail.amount = 44 if is_big else 32
	_trail.lifetime = 0.75
	_trail.local_coords = false
	_trail.texture = MageFx.dot()
	_trail.material = MageFx.add_material()
	_trail.visibility_rect = MageFx.VIS_RECT
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.gravity = Vector3(0, -18, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.5 * sz
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 12.0
	pm.scale_min = 0.35 * sz
	pm.scale_max = 0.8 * sz
	pm.scale_curve = MageFx.size_curve(0.1)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.color_ramp = MageFx.ramp([Color(GOLD_CORE, 0.8), Color(GOLD_MID, 0.45), Color(GOLD_EDGE, 0.0)])
	_trail.process_material = pm
	add_child(_trail)

	# Хвост — мягкий вытянутый след позади души, тянется по скорости полёта
	_tail = Sprite2D.new()
	_tail.texture = MageFx.streak()
	_tail.material = MageFx.add_material()
	_tail.modulate = Color(1.25, 0.72, 0.22, 0.0)
	_tail.centered = true
	_tail.offset = Vector2(0, 20)
	add_child(_tail)
	_halo = _layer(34.0 * sz, Color(GOLD_EDGE.r * 1.15, GOLD_EDGE.g * 1.1, GOLD_EDGE.b, 0.4))
	_core = _layer(14.0 * sz, Color(GOLD_MID.r * 1.35, GOLD_MID.g * 1.25, GOLD_MID.b, 0.7))
	_spark = _layer(4.5 * sz, Color(GOLD_CORE.r * 1.6, GOLD_CORE.g * 1.6, GOLD_CORE.b * 1.4, 0.9))
	_spark.texture = MageFx.dot()
	_spark.scale = Vector2.ONE * 4.5 * sz / 8.0

	_light = PointLight2D.new()
	_light.texture = MageFx.radial()
	_light.texture_scale = 40.0 * sz / 128.0
	_light.color = GOLD_MID
	_light.energy = 0.55 * GLOW
	add_child(_light)

	_compensate_for_ambient_tint()
	modulate.a = GLOW
	# Появление — короткая вспышка на месте выпадения, а не "щелчок" из ничего
	scale = Vector2.ONE * 0.2
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _layer(size: float, col: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = MageFx.soft()
	s.material = MageFx.add_material()
	s.modulate = col
	s.scale = Vector2.ONE * size / 64.0
	add_child(s)
	return s


func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	# Мерцание: ядро и искра дышат, ореол чуть плывёт
	var flick := 0.85 + 0.15 * sin(_t * 17.0 + _seed) + 0.08 * sin(_t * 31.0 + _seed * 2.0)
	_spark.self_modulate.a = flick
	_core.self_modulate.a = 0.8 + 0.2 * sin(_t * 9.0 + _seed)
	_halo.scale = Vector2.ONE * (34.0 * (1.35 if is_big else 1.0) / 64.0) * (1.0 + 0.1 * sin(_t * 5.0 + _seed))
	_light.energy = (0.45 + 0.15 * flick) * GLOW
	_update_tail()

	var hero := _hero()
	if _t < _rise_time or hero == null:
		# Вспорхнула и зависла, покачиваясь
		_velocity = _velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		position += (_velocity + Vector2(0, sin(_t * 6.0 + _seed) * 8.0)) * delta
		# Героя нет (умер, сцена меняется) — не висеть вечно
		if hero == null and _t > 6.0:
			_fade_out()
		return

	# Полёт к игроку: скорость растёт, руль крепчает — путь выгибается дугой,
	# а под конец душа уверенно "втягивается" в героя
	var target := hero.global_position + Vector2(0, -10)
	var to := target - global_position
	var dist := to.length()
	if dist < 9.0:
		_collect(hero)
		return
	var seek := _t - _rise_time
	var speed := minf(70.0 + seek * 420.0, 380.0)
	var steer := 3.0 + seek * 10.0
	var desired := to / dist * speed
	# Покачивание поперёк полёта — сильнее вдали, гаснет у самого героя
	var side := Vector2(-to.y, to.x) / dist * sin(_t * 7.0 + _seed) * 40.0 * clampf(dist / 120.0, 0.0, 1.0)
	_velocity = _velocity.lerp(desired + side, clampf(steer * delta, 0.0, 1.0))
	position += _velocity * delta
	# Не проскочить героя на большой скорости
	if global_position.distance_to(target) < 9.0 or _velocity.length() * delta > dist:
		_collect(hero)


## Хвост смотрит против полёта и вытягивается со скоростью: на зависании —
## почти невидимая капля, в разгоне к герою — длинная золотая полоса
func _update_tail() -> void:
	var v := _velocity.length()
	if v < 1.0:
		_tail.modulate.a = 0.0
		return
	# Текстура streak вытянута вдоль своей оси y — разворачиваем её "назад"
	_tail.rotation = _velocity.angle() + PI * 0.5
	var k := clampf(v / 320.0, 0.0, 1.0)
	var sz := 1.3 if is_big else 1.0
	_tail.scale = Vector2(0.55 * sz, (0.35 + 0.9 * k) * sz)
	_tail.offset = Vector2(0, 20)
	_tail.modulate.a = 0.15 + 0.4 * k


func _hero() -> Node2D:
	var h := get_tree().get_first_node_in_group("player") as Node2D
	if h == null or not is_instance_valid(h):
		return null
	if h.has_method("is_dead") and h.is_dead():
		return null
	return h


func _collect(hero: Node2D) -> void:
	_collected = true
	if hero.has_method("add_gold"):
		hero.add_gold(value)
	if hero.has_method("_trigger_coin_glow"):
		hero._trigger_coin_glow()
	_play_coin_sound(hero)
	# Короткая золотая вспышка с искрами на герое — душа "впиталась"
	var h := MageFx.holder(get_tree(), hero.global_position + Vector2(0, -10), 0.6, 13)
	h.modulate = modulate
	MageFx.flash(h, 22.0 if is_big else 16.0, 0.16, GOLD_CORE)
	MageFx.burst(h, 8 if is_big else 5, 0.4, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.spread = 180.0
		pm.initial_velocity_min = 25.0
		pm.initial_velocity_max = 60.0
		pm.damping_min = 60.0
		pm.damping_max = 110.0
		pm.gravity = Vector3(0, -30, 0)
		pm.scale_min = 0.4
		pm.scale_max = 0.8
		pm.color_ramp = MageFx.ramp([Color(GOLD_CORE, 1.0), Color(GOLD_MID, 0.8), Color(GOLD_EDGE, 0.0)]))
	_fade_out()


## Звон монеток — свой плеер в месте героя, чтобы звучало у любого героя (у
## лучницы и мага нет своего coin_audio, как у рыцаря)
func _play_coin_sound(hero: Node2D) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound_ms < 60:
		return
	_last_sound_ms = now
	var p := AudioStreamPlayer2D.new()
	p.stream = COIN_SOUND
	p.pitch_scale = randf_range(0.92, 1.12) * (0.9 if is_big else 1.0)
	# Та же шина и громкость, что у монет рыцаря (CoinAudio в player.tscn) —
	# звон с эхом
	p.volume_db = -10.0
	p.bus = &"CoinEcho"
	hero.get_parent().add_child(p)
	p.global_position = hero.global_position
	p.finished.connect(p.queue_free)
	p.play()


## Тело души гаснет, а шлейф ещё долетает в мире (local_coords = false)
func _fade_out() -> void:
	_collected = true
	_trail.emitting = false
	var t := create_tween().set_parallel(true)
	t.tween_property(_halo, "modulate:a", 0.0, 0.12)
	t.tween_property(_core, "modulate:a", 0.0, 0.12)
	t.tween_property(_spark, "modulate:a", 0.0, 0.12)
	t.tween_property(_tail, "modulate:a", 0.0, 0.12)
	t.tween_property(_light, "energy", 0.0, 0.12)
	get_tree().create_timer(_trail.lifetime + 0.15).timeout.connect(queue_free)


# Уровень красит весь мир через CanvasModulate (холодный ночной тон), и душа
# живёт в мире — без компенсации золото съехало бы в зелень/голубизну. Тот же
# приём, что был у монеты: обратный множитель на modulate узла, от реального
# цвета CanvasModulate на сцене
func _compensate_for_ambient_tint() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for child in scene.get_children():
		if child is CanvasModulate and child.visible:
			var c: Color = child.color
			modulate = Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)
			return
