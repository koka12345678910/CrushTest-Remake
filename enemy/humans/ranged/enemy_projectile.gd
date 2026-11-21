extends Node2D
## enemy_projectile.gd — снаряд стрелка (пуля, магический сгусток).
##
## Летит по прямой, рисуется сам (светящийся след с аддитивным смешиванием),
## на стене или герое — короткая вспышка искр и исчезает.
##
## Попадание в героя идёт через hero.receive_attack(), как удар врага в
## ближнем бою — значит, работают блок щитом, идеальное парирование,
## уворот перекатом и неуязвимость. Источник удара — сам снаряд, а не стрелок:
##   * блок и отбрасывание считаются от направления, откуда прилетела пуля;
##   * парирование не бьёт по концентрации стрелка на другом конце арены
##     (on_perfect_parry зовёт take_posture_damage у источника — у снаряда
##     такого метода нет).
## Уворот (receive_attack вернул false) — снаряд пролетает дальше насквозь.

var shooter: Node = null
var velocity := Vector2.ZERO
var damage := 10
var max_range := 400.0
var hit_radius := 9.0
var length := 18.0
var width := 2.0
var core_color := Color(1, 1, 1)
var glow_color := Color(1, 0.5, 0.2)
var sound_flesh: AudioStream
var sound_block: AudioStream
var sound_wall: AudioStream

var _travelled := 0.0
var _passed := []          # герои, увернувшиеся от этого снаряда
var _dying := 0.0          # >0 — играет вспышка попадания
var _burst_color := Color.WHITE
## Режим "кольцо взрыва" (магический взрыв по области, ranged_enemy.gd
## bursts): не летит, сразу рисует расходящееся кольцо радиуса ring_radius
var ring_radius := 0.0
var _burst_time := BURST_TIME

const BURST_TIME := 0.18
const RING_TIME := 0.35


## Взрыв по области: только картинка, урон считает стрелок
func start_ring(radius: float, color: Color) -> void:
	ring_radius = radius
	_burst_color = color
	velocity = Vector2.ZERO
	_burst_time = RING_TIME
	_dying = RING_TIME
	queue_redraw()
const FLESH := [
	preload("res://Sound/sigrid_sfx/arrow_hit_flesh_1.ogg"),
	preload("res://Sound/sigrid_sfx/arrow_hit_flesh_2.ogg"),
]
const SHIELD := [
	preload("res://Sound/sigrid_sfx/arrow_hit_shield_1.ogg"),
	preload("res://Sound/sigrid_sfx/arrow_hit_shield_2.ogg"),
]
const STONE := preload("res://Sound/sigrid_sfx/arrow_hit_stone_1.ogg")


func _ready() -> void:
	z_index = 10
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if _dying > 0.0:
		_dying -= delta
		queue_redraw()
		if _dying <= 0.0:
			queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	# Стена (слой "world") между прошлой и новой точкой
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(q)
	var wall_t := 2.0
	if not wall.is_empty():
		wall_t = from.distance_to(wall["position"]) / maxf(from.distance_to(to), 0.001)
	# Герои: расстояние от героя до отрезка полёта
	for hero in get_tree().get_nodes_in_group("player"):
		if not (hero is Node2D) or hero in _passed or not is_instance_valid(hero):
			continue
		if hero.has_method("is_dead") and hero.is_dead():
			continue
		var t := _segment_t(from, to, (hero as Node2D).global_position)
		if t > wall_t:
			continue
		var p := from.lerp(to, t)
		if p.distance_to((hero as Node2D).global_position) > hit_radius:
			continue
		global_position = p
		_hit_hero(hero)
		return
	if wall_t <= 1.0:
		global_position = wall["position"]
		_burst(glow_color, STONE if sound_wall == null else sound_wall, -6.0)
		return
	global_position = to
	_travelled += from.distance_to(to)
	if _travelled >= max_range:
		# Предел дальности — гаснет без вспышки
		queue_free()
		return
	queue_redraw()


func _segment_t(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return 0.0
	return clampf((p - a).dot(ab) / l2, 0.0, 1.0)


func _hit_hero(hero: Node) -> void:
	var blocking: bool = hero.get("is_blocking") == true or hero.get("is_parrying") == true
	var landed := true
	if hero.has_method("receive_attack"):
		landed = hero.receive_attack({"damage": damage, "source": self})
	elif hero.has_method("take_damage"):
		hero.take_damage(damage, self)
	if not landed:
		# Увернулся — летим дальше, этого героя больше не проверяем
		_passed.append(hero)
		return
	if blocking:
		_burst(Color(1, 0.9, 0.6), SHIELD.pick_random() if sound_block == null else sound_block, -4.0)
	else:
		_burst(glow_color, FLESH.pick_random() if sound_flesh == null else sound_flesh, -4.0)


func _burst(color: Color, sound: AudioStream, db: float) -> void:
	_dying = BURST_TIME
	_burst_color = color
	velocity = Vector2.ZERO
	if sound:
		var a := AudioStreamPlayer2D.new()
		a.stream = sound
		a.volume_db = db
		a.pitch_scale = randf_range(0.92, 1.08)
		a.max_distance = 700.0
		if AudioServer.get_bus_index(&"Combat") >= 0:
			a.bus = &"Combat"
		add_child(a)
		a.play()
	queue_redraw()


func _draw() -> void:
	if ring_radius > 0.0:
		# Кольцо взрыва: растёт до радиуса поражения и гаснет. Под ним —
		# слабая заливка, чтобы читалась именно область, а не только край
		var kr := 1.0 - _dying / _burst_time
		var r := ring_radius * (0.35 + 0.65 * ease(kr, 0.4))
		var c := _burst_color
		c.a = 0.85 * (1.0 - kr)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 2.0)
		c.a = 0.18 * (1.0 - kr)
		draw_circle(Vector2.ZERO, r, c)
		return
	if _dying > 0.0:
		# Вспышка: расходящееся кольцо и короткие искры
		var k := 1.0 - _dying / BURST_TIME
		var c := _burst_color
		c.a = 1.0 - k
		draw_arc(Vector2.ZERO, 2.0 + 7.0 * k, 0.0, TAU, 16, c, 1.5)
		for i in 6:
			var ang := TAU * i / 6.0 + 0.4
			var d := Vector2.from_angle(ang)
			draw_line(d * (2.0 + 4.0 * k), d * (4.0 + 9.0 * k), c, 1.0)
		var core := core_color
		core.a = (1.0 - k) * 0.9
		draw_circle(Vector2.ZERO, 2.5 * (1.0 - k) + 0.5, core)
		return
	# След растёт от дула до полной длины — не торчит назад из ружья
	var l := minf(length, _travelled + 4.0)
	var g := glow_color
	g.a = 0.28
	draw_line(Vector2(-l, 0), Vector2.ZERO, g, width * 3.0)
	g.a = 0.75
	draw_line(Vector2(-l * 0.7, 0), Vector2.ZERO, g, width * 1.6)
	draw_line(Vector2(-l * 0.45, 0), Vector2.ZERO, core_color, width * 0.7)
	draw_circle(Vector2.ZERO, width * 1.1, core_color)
