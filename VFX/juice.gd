extends Node
## juice.gd — автозагрузка "Juice": "сочность" боя, общая для всех героев.
##
## Сюда стекается каждое попадание по врагу (enemy.gd::take_damage зовёт
## Juice.hit) — любым героем, любым оружием, — и здесь решается, каким по весу
## был удар и чем на него ответить:
##   лёгкий     — короткий стоп-кадр, толчок камеры по направлению удара;
##   тяжёлый    — дольше стоп-кадр, ударная волна в воздухе, трещина на земле,
##                расслоение цвета на миг;
##   убийство   — всё сильнее, тело отлетает и проезжает по земле;
##   последнее убийство группы — замедление времени, наезд камеры, кадр уходит
##                в серость с виньеткой: каждая стычка заканчивается "кадром";
##   добивание  (execution) — после пробитой концентрации: самый тяжёлый ответ.
## Плюс остаточные изображения героя на перекатах, рывках и выпадах, вспышки
## экрана (молния, гроза) и трещины на земле — для всех героев одинаково.
##
## Время. Единственный хозяин Engine.time_scale для боевых эффектов: заявки
## (стоп-кадр, замедление) копятся, действует самая медленная. Иначе стоп-кадр,
## закончившись, вернул бы время в 1.0 посреди замедления последнего убийства.
## Всё считается в реальном времени — при time_scale 0 таймеры игры стоят.
##
## Камера. Толчок и наезд — через position/zoom камеры героя: offset каждый
## кадр пишет сам рыцарь (тряска, покачивание на бегу), его не трогаем.

const DISTORT_SHADER := preload("res://Shaders/magic_distort.gdshader")
const OVERLAY_SHADER := preload("res://Shaders/juice_overlay.gdshader")
const MageFx := preload("res://Player_scene/mage_fx.gd")
const BloodFx := preload("res://VFX/VFX_scene/blood_fx.gd")
const HIT_SOUND := preload("res://Sound/melee_sound/hit.mp3")
const BREAK_SOUND := preload("res://Sound/posture_break.mp3")

enum Weight { LIGHT, HEAVY, KILL, LAST_KILL }

## Радиус, в котором другие живые враги ещё "в бою" — если таких нет, убийство
## было последним в группе
@export var last_kill_radius := 340.0
## Остаточные изображения: как часто (с игрового времени), сколько живут и
## насколько видны. Еле заметные (2026-10-21) — лёгкий след, а не раскадровка
@export var ghost_interval := 0.05
@export var ghost_life := 0.2
@export_range(0.0, 1.0) var ghost_alpha := 0.12

# --- время: [минимум, начало_мкс, длительность_мкс, доля удержания] ---
var _time_reqs := []
var _time_owned := false

# --- камера ---
var _cam: Camera2D
var _cam_base_pos := Vector2.ZERO
var _cam_base_zoom := Vector2.ONE
var _kick := Vector2.ZERO
var _shake := 0.0
var _zoom_punch := 0.0
var _zoom_hold_until := 0
var _cam_dirty := false

# --- экранный слой: канал -> [значение, держать_до_мкс, затухание/с] ---
var _layer: CanvasLayer
var _overlay: ColorRect
var _ov_mat: ShaderMaterial
var _channels := {
	"flash": [0.0, 0, 6.0],
	"vignette": [0.0, 0, 1.5],
	"desat": [0.0, 0, 1.5],
	"aberration": [0.0, 0, 4.0],
}

var _ghost_timer := 0.0
var _ghost_mat: CanvasItemMaterial
var _last_us := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_us = Time.get_ticks_usec()
	_layer = CanvasLayer.new()
	_layer.layer = 1
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov_mat = ShaderMaterial.new()
	_ov_mat.shader = OVERLAY_SHADER
	_overlay.material = _ov_mat
	_overlay.visible = false
	_layer.add_child(_overlay)
	_ghost_mat = CanvasItemMaterial.new()
	_ghost_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ghost_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	_update_time(now)
	_update_camera(now, real_dt)
	_update_overlay(now, real_dt)
	_update_ghosts(delta)


# ═════════════════════════════════════════════════════════════════════
# ПОПАДАНИЕ — точка входа из enemy.gd
# ═════════════════════════════════════════════════════════════════════

## victim — враг (или разбиваемый предмет), source — кто ударил, amount —
## урон, killed — удар добил, blocked — пришёлся в щит
func hit(victim: Node2D, source: Node2D, amount: int, killed: bool, blocked := false) -> void:
	if not is_instance_valid(victim):
		return
	var dir := _dir(source, victim)
	var at := victim.global_position + Vector2(0, -10)
	# У рыцаря свой стоп-кадр и тряска на каждое попадание (player.gd) — их не
	# удваиваем, добавляем только то, чего у него нет
	var own_feel := is_instance_valid(source) and source.has_method("do_hitstop")
	if blocked:
		kick(dir, 1.8)
		if not own_feel:
			freeze(0.025)
			shake(1.4)
		return

	var w := Weight.LIGHT
	if killed:
		w = Weight.LAST_KILL if _is_last_kill(victim) else Weight.KILL
	elif amount >= 2:
		w = Weight.HEAVY

	match w:
		Weight.LIGHT:
			kick(dir, 2.2)
			if not own_feel:
				freeze(0.032)
				shake(1.6)
		Weight.HEAVY:
			kick(dir, 4.0)
			pulse("aberration", 0.3, 0.0)
			shockwave(at, 38.0, 0.3, 0.011)
			ground_crack(_feet(victim), 0.6)
			if not own_feel:
				freeze(0.065)
				shake(3.2)
		Weight.KILL, Weight.LAST_KILL:
			kick(dir, 5.0)
			freeze(0.08 if not own_feel else 0.03)
			shake(3.8)
			pulse("aberration", 0.4, 0.0)
			shockwave(at, 52.0, 0.34, 0.014)
			ground_crack(_feet(victim), 0.9)
			corpse_slide(victim, dir, 18.0)
			if w == Weight.LAST_KILL:
				_last_kill_moment(victim, at)


## Последний враг группы упал: время на миг почти встаёт и плавно отпускает,
## камера наезжает, мир сереет и стягивается виньеткой — "кадр" победы
func _last_kill_moment(victim: Node2D, at: Vector2) -> void:
	slow(0.22, 0.85, 0.5)
	zoom_punch(0.1, 0.5)
	pulse("desat", 0.55, 0.45)
	pulse("vignette", 0.45, 0.45)
	shockwave(at, 96.0, 0.55, 0.02)
	_play(HIT_SOUND, victim.global_position, 0.62, -2.0)


## Добивание врага с пробитой концентрацией — enemy.gd зовёт перед
## execute_kill(). Самый тяжёлый ответ во всей игре — но тёмный, без вспышек,
## света и искр: ничего не взрывается, это удар клинком. Вес дают остановка
## времени, наезд камеры, кровь, звук и то, как кадр темнеет и сереет
## (2026-10-21: прежняя версия со светом читалась как необъяснимый взрыв)
func execution(victim: Node2D, source: Node2D) -> void:
	if not is_instance_valid(victim):
		return
	var dir := _dir(source, victim)
	var at := victim.global_position + Vector2(0, -12)
	freeze(0.14)
	slow(0.16, 1.05, 0.55)
	zoom_punch(0.16, 0.55)
	pulse("vignette", 0.75, 0.55)
	pulse("desat", 0.5, 0.55)
	pulse("aberration", 0.3, 0.04)
	kick(dir, 8.0)
	shake(5.0)
	# Не взрыв — лишь воздух дрогнул от удара
	shockwave(at, 55.0, 0.35, 0.01)
	ground_crack(_feet(victim), 1.1)
	corpse_slide(victim, dir, 26.0)
	# Кровь веером дважды — удар и выдох
	BloodFx.hit(victim, source, 3.2)
	victim.get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(victim):
			BloodFx.hit(victim, source, 2.4))
	_play(HIT_SOUND, victim.global_position, 0.55, 2.0)
	_play(BREAK_SOUND, victim.global_position, 0.7, -4.0)


## Концентрация врага лопнула (enemy.gd::_posture_break): короткий звонкий
## ответ — щит раскололся — и руна над головой: "его можно добить"
func guard_break(victim: Node2D) -> Node2D:
	if not is_instance_valid(victim):
		return null
	var hero := _hero()
	kick(_dir(hero, victim), 3.0)
	shake(3.0)
	freeze(0.05)
	pulse("aberration", 0.35, 0.0)
	shockwave(victim.global_position + Vector2(0, -14), 44.0, 0.3, 0.012)
	_play(BREAK_SOUND, victim.global_position, 1.0, -3.0)
	var m := BreakMarker.new()
	m.position = Vector2(0, -46)
	victim.add_child(m)
	return m


# ═════════════════════════════════════════════════════════════════════
# КИРПИЧИКИ
# ═════════════════════════════════════════════════════════════════════

## Стоп-кадр: время замирает на duration реальных секунд
func freeze(duration: float) -> void:
	slow(0.0, duration, 1.0)


## Замедление до scale на duration реальных секунд: hold — какую долю держится
## ровно, дальше плавно отпускает к 1.0
func slow(scale: float, duration: float, hold := 1.0) -> void:
	_time_reqs.append([scale, Time.get_ticks_usec(), int(duration * 1000000.0), hold])


func kick(dir: Vector2, strength: float) -> void:
	if dir.length() < 0.001:
		return
	# Мгновенный сдвиг, дальше гаснет сам (см. _update_camera). Копится, но
	# не больше ~12 px — серия ударов не уносит камеру
	_kick = (_kick + dir.normalized() * strength).limit_length(12.0)


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Наезд камеры (amount — доля зума) с удержанием hold реальных секунд
func zoom_punch(amount: float, hold := 0.0) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)
	_zoom_hold_until = maxi(_zoom_hold_until, Time.get_ticks_usec() + int(hold * 1000000.0))


## Канал экранного слоя: вспышка, виньетка, серость, расслоение цвета
func pulse(channel: String, amount: float, hold := 0.0) -> void:
	var c: Array = _channels[channel]
	c[0] = maxf(c[0], amount)
	c[1] = maxi(c[1], Time.get_ticks_usec() + int(hold * 1000000.0))


## Ударная волна: воздух вокруг точки выпирает кольцом (тот же шейдер, что у
## импульса мага)
func shockwave(at: Vector2, radius: float, time: float, strength: float) -> void:
	var tree := get_tree()
	if tree.current_scene == null:
		return
	var s := Sprite2D.new()
	s.texture = _white()
	s.scale = Vector2.ONE * radius * 2.0 / 4.0
	s.z_as_relative = false
	s.z_index = 90
	var m := ShaderMaterial.new()
	m.shader = DISTORT_SHADER
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("width", clampf(12.0 / radius, 0.08, 0.22))
	m.set_shader_parameter("progress", 0.0)
	s.material = m
	tree.current_scene.add_child(s)
	s.global_position = at
	var t := s.create_tween()
	t.tween_method(func(v: float):
		m.set_shader_parameter("progress", v)
		m.set_shader_parameter("fade", 1.0 - v * v), 0.0, 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(s.queue_free)


## Трещина в земле под ударом: тёмные рваные лучи от центра, пыль и крошка.
## glow — цвет тлеющих краёв (молния), прозрачный — без свечения
func ground_crack(at: Vector2, size := 1.0, glow := Color(0, 0, 0, 0)) -> void:
	var tree := get_tree()
	if tree.current_scene == null:
		return
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = -15
	tree.current_scene.add_child(n)
	n.global_position = at
	var rays := randi_range(5, 8)
	var lines := []
	for i in rays:
		var a := TAU * (float(i) + randf_range(-0.3, 0.3)) / rays
		var length := randf_range(10.0, 24.0) * size
		var pts := PackedVector2Array([Vector2.ZERO])
		var p := Vector2.ZERO
		var segs := 4
		for k in segs:
			a += randf_range(-0.45, 0.45)
			p += Vector2(cos(a), sin(a) * 0.62) * length / segs
			pts.append(p)
		var l := Line2D.new()
		l.points = pts
		l.width = randf_range(1.4, 2.4) * clampf(size, 0.7, 1.4)
		var wc := Curve.new()
		wc.add_point(Vector2(0, 1))
		wc.add_point(Vector2(1, 0.1))
		l.width_curve = wc
		l.default_color = Color(0.03, 0.025, 0.03, 0.85)
		l.antialiased = false
		n.add_child(l)
		lines.append(l)
		# Короткая боковая ветка у части лучей
		if randf() < 0.5 and pts.size() > 2:
			var b := Line2D.new()
			var from: Vector2 = pts[2]
			var ba := a + randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0)
			b.points = PackedVector2Array([from, from + Vector2(cos(ba), sin(ba) * 0.62) * length * 0.35])
			b.width = l.width * 0.6
			b.width_curve = wc
			b.default_color = l.default_color
			n.add_child(b)
	if glow.a > 0.0:
		for l in lines:
			var g := Line2D.new()
			g.points = (l as Line2D).points
			g.width = (l as Line2D).width * 0.5
			g.width_curve = (l as Line2D).width_curve
			g.default_color = Color(glow.r, glow.g, glow.b, glow.a)
			g.material = _ghost_mat
			n.add_child(g)
			g.create_tween().tween_property(g, "modulate:a", 0.0, 1.6).set_delay(0.3)
	# Пыль и крошка из трещины
	var h := MageFx.holder(tree, at, 1.2, 12)
	MageFx.smoke(h, int(3 + 3 * size), 5.0 * size, 18.0 * size, 0.7)
	MageFx.burst(h, int(4 + 4 * size), 0.45, MageFx.dot(), func(pm: ParticleProcessMaterial):
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 75.0
		pm.initial_velocity_min = 40.0 * size
		pm.initial_velocity_max = 90.0 * size
		pm.gravity = Vector3(0, 380, 0)
		pm.scale_min = 0.35
		pm.scale_max = 0.6
		pm.color = Color(0.32, 0.28, 0.24, 1.0), false)
	# Лежит, потом медленно тает
	var t := n.create_tween()
	t.tween_interval(5.0)
	t.tween_property(n, "modulate:a", 0.0, 2.5)
	t.tween_callback(n.queue_free)


## Тело после добивающего удара отлетает и проезжает по земле — не дальше
## стены (пробуем сдвиг через test_move)
func corpse_slide(victim: Node2D, dir: Vector2, dist: float) -> void:
	if not is_instance_valid(victim) or dir.length() < 0.001:
		return
	var motion := dir.normalized() * dist
	if victim is PhysicsBody2D:
		var body := victim as PhysicsBody2D
		var step := motion / 6.0
		var allowed := Vector2.ZERO
		for i in 6:
			if body.test_move(body.global_transform.translated(allowed), step):
				break
			allowed += step
		motion = allowed
	if motion.length() < 1.0:
		return
	var t := victim.create_tween()
	t.tween_property(victim, "global_position", victim.global_position + motion, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func():
		if is_instance_valid(victim):
			var h := MageFx.holder(victim.get_tree(), _feet(victim), 1.0, 11)
			MageFx.smoke(h, 4, 6.0, 16.0, 0.6))


func flash(amount: float) -> void:
	pulse("flash", amount, 0.0)


# ═════════════════════════════════════════════════════════════════════
# ОСТАТОЧНЫЕ ИЗОБРАЖЕНИЯ
# ═════════════════════════════════════════════════════════════════════

## Перекат, уворот, рывок удара на бегу, выпад — за героем тянутся 2-3
## светящихся силуэта (последний кадр анимации в той же позе)
func _update_ghosts(delta: float) -> void:
	var hero := _hero()
	if hero == null or get_tree().paused:
		return
	var fast := false
	for flag in ["is_rolling", "is_dodging", "is_run_attacking"]:
		if hero.get(flag) == true:
			fast = true
	var run_speed = hero.get("run_speed")
	if not fast and run_speed is float and hero is CharacterBody2D:
		# Выпад и прочие рывки — по скорости, но не отлёт от вражеского удара
		var kb = hero.get("knockback_velocity")
		var attacking: bool = hero.get("is_attacking") == true
		if (hero as CharacterBody2D).velocity.length() > run_speed * 1.08 and (attacking or not (kb is Vector2 and kb != Vector2.ZERO)):
			fast = true
	if not fast:
		_ghost_timer = 0.0
		return
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = ghost_interval
	var spr := _hero_sprite(hero)
	if spr == null or spr.sprite_frames == null:
		return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = spr.centered
	g.offset = spr.offset
	g.flip_h = spr.flip_h
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.material = _ghost_mat
	# Позади героя и предметов, но над землёй
	g.z_index = -1
	var tint := Color(0.7, 0.82, 1.0)
	if hero.is_in_group("caster_player"):
		tint = Color(0.4, 0.62, 1.0)
	elif hero.is_in_group("archer_player"):
		tint = Color(0.78, 0.9, 0.82)
	var comp := _ambient_comp()
	g.modulate = Color(tint.r * comp.r, tint.g * comp.g, tint.b * comp.b, ghost_alpha)
	get_tree().current_scene.add_child(g)
	g.global_transform = spr.global_transform
	var t := g.create_tween().set_parallel(true)
	t.tween_property(g, "modulate:a", 0.0, ghost_life).set_ease(Tween.EASE_IN)
	t.tween_property(g, "scale", g.scale * 1.06, ghost_life)
	t.chain().tween_callback(g.queue_free)


func _hero_sprite(hero: Node) -> AnimatedSprite2D:
	var s = hero.get("sprite")
	if s is AnimatedSprite2D:
		return s
	var n := hero.get_node_or_null("PlayerAnim")
	if n is AnimatedSprite2D:
		return n
	return hero.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


# ═════════════════════════════════════════════════════════════════════
# ВНУТРЕННЕЕ
# ═════════════════════════════════════════════════════════════════════

func _update_time(now: int) -> void:
	if _time_reqs.is_empty():
		if _time_owned:
			Engine.time_scale = 1.0
			_time_owned = false
		return
	var s := 1.0
	var keep := []
	for r in _time_reqs:
		var t := float(now - r[1]) / maxf(r[2], 1.0)
		if t >= 1.0:
			continue
		keep.append(r)
		var v: float = r[0]
		if t > r[3]:
			v = lerpf(r[0], 1.0, smoothstep(r[3], 1.0, t))
		s = minf(s, v)
	_time_reqs = keep
	Engine.time_scale = s
	_time_owned = true


func _update_camera(now: int, dt: float) -> void:
	var hero := _hero()
	var cam: Camera2D = hero.get_node_or_null("Camera2D") as Camera2D if hero else null
	if cam != _cam:
		if is_instance_valid(_cam) and _cam_dirty:
			_cam.position = _cam_base_pos
			_cam.zoom = _cam_base_zoom
		_cam = cam
		_cam_dirty = false
		_kick = Vector2.ZERO
		_shake = 0.0
		_zoom_punch = 0.0
		if is_instance_valid(_cam):
			_cam_base_pos = _cam.position
			_cam_base_zoom = _cam.zoom
	if not is_instance_valid(_cam):
		return
	# Толчок: резко отъехала по направлению удара — мягко возвращается.
	# Экспонента, а не пружина: устойчива при любом шаге кадра (явная пружина
	# на длинном кадре раскачивалась и улетала)
	_kick *= exp(-14.0 * dt)
	var off := _kick
	if _shake > 0.05:
		off += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, (_shake * 9.0 + 2.0) * dt)
	else:
		_shake = 0.0
	if now > _zoom_hold_until:
		_zoom_punch = move_toward(_zoom_punch, 0.0, (_zoom_punch * 4.0 + 0.02) * dt)
	var active := off.length() > 0.05 or _zoom_punch > 0.0005
	if active:
		_cam.position = _cam_base_pos + off
		_cam.zoom = _cam_base_zoom * (1.0 + _zoom_punch)
		_cam_dirty = true
	elif _cam_dirty:
		_cam.position = _cam_base_pos
		_cam.zoom = _cam_base_zoom
		_cam_dirty = false


func _update_overlay(now: int, dt: float) -> void:
	var any := false
	for k in _channels:
		var c: Array = _channels[k]
		if now > c[1]:
			c[0] = move_toward(c[0], 0.0, c[2] * dt)
		_ov_mat.set_shader_parameter(k, c[0])
		if c[0] > 0.001:
			any = true
	_overlay.visible = any


func _is_last_kill(victim: Node2D) -> bool:
	var hero := _hero()
	var center: Vector2 = hero.global_position if hero else victim.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == victim or not is_instance_valid(e) or e.is_dead:
			continue
		if center.distance_to(e.global_position) < last_kill_radius:
			return false
	return true


func _hero() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _dir(source: Node2D, victim: Node2D) -> Vector2:
	if is_instance_valid(source) and is_instance_valid(victim):
		var d := victim.global_position - source.global_position
		if d.length() > 0.001:
			return d.normalized()
	return Vector2.DOWN


## Точка под ногами врага (как у мага: ноги на 27 px от центра кадра)
func _feet(victim: Node2D) -> Vector2:
	var spr := victim.get_node_or_null("AnimatedSprite2D") as Node2D
	if spr:
		return victim.global_position + spr.position + Vector2(0, 27) * spr.scale
	return victim.global_position + Vector2(0, 16)


## Обратный множитель ночного CanvasModulate — светящееся не должно тонуть в
## ночном тоне (тот же приём, что у золотых душ)
func _ambient_comp() -> Color:
	var scene := get_tree().current_scene
	if scene:
		for ch in scene.get_children():
			if ch is CanvasModulate and ch.visible:
				var c: Color = ch.color
				return Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)
	return Color.WHITE


func _play(stream: AudioStream, at: Vector2, pitch: float, volume_db: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = volume_db
	scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


static var _white_tex: ImageTexture

func _white() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


## Руна над врагом с пробитой концентрацией: "добей". Кольцо и знак Тейваз
## (стрела вверх), пульсирует, светится кроваво-золотым
class BreakMarker extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = 60
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		scale = Vector2.ZERO
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.75 + 0.25 * sin(_t * 9.0)
		var gold := Color(1.0, 0.72, 0.3, 0.9 * pulse)
		var red := Color(1.0, 0.25, 0.15, 0.55 * pulse)
		# Мягкий ореол
		for i in 4:
			draw_circle(Vector2.ZERO, 11.0 + i * 2.5, Color(red.r, red.g, red.b, red.a * 0.12))
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, gold, 1.2, true)
		draw_arc(Vector2.ZERO, 11.5 + sin(_t * 4.0), _t * 2.0, _t * 2.0 + PI * 1.4, 24, red, 1.0, true)
		# Тейваз: древко и наконечник-стрела
		draw_line(Vector2(0, 6), Vector2(0, -6), gold, 1.4, true)
		draw_line(Vector2(0, -6), Vector2(-4, -2), gold, 1.4, true)
		draw_line(Vector2(0, -6), Vector2(4, -2), gold, 1.4, true)
