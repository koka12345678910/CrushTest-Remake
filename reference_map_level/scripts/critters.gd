extends Node2D
## critters.gd — живность, которая боится героя (reference_map).
##   kind = "crows": вороны сидят на виселице, на коньках сгоревших крыш, клюют
##                   землю у пугала; герой ближе flee_radius — с карканьем и
##                   хлопаньем крыльев взлетают и улетают;
##   kind = "rats":  крысы шуршат у мешков и бочек лагеря; герой рядом —
##                   с писком разбегаются зигзагом и пропадают под пропсами.
## Рисуются процедурно (_draw), арта не нужно: птица ~16 px, крыса ~12 px.
## Улетевшие/убежавшие возвращаются, когда герой далеко и места не видно.
## Точки даёт immersion.gd (_build_critters) через add_spot.

const SoundBank := preload("res://Levels/sound_bank.gd")

@export_enum("crows", "rats") var kind := "crows"
@export var flee_radius := 130.0
@export var respawn_time := 25.0

## {"home", "pos", "vel", "state" (0 сидит, 1 бежит/летит, 2 нет), "face",
##  "t" (время в состоянии), "delay", "ground" (ворона на земле), "ph"}
var _spots: Array[Dictionary] = []
var _time := 0.0
var _sound_cd := 0.0
## Узел может стоять не в начале координат (крысы — внутри лагеря): рисуем со сдвигом
var _o := Vector2.ZERO


func add_spot(at: Vector2, on_ground := false) -> void:
	_spots.append({"home": at, "pos": at, "vel": Vector2.ZERO, "state": 0,
		"face": -1.0 if randf() < 0.5 else 1.0, "t": randf() * 5.0, "delay": 0.0,
		"ground": on_ground, "ph": randf() * TAU})


func spot_count() -> int:
	return _spots.size()


func _heroes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h in get_tree().get_nodes_in_group("player"):
		if h is Node2D and is_instance_valid(h):
			out.append((h as Node2D).global_position)
	return out


func _cam() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)


func _process(delta: float) -> void:
	_time += delta
	_sound_cd -= delta
	var heroes := _heroes()
	var cam := _cam()
	var spooked: Array[Vector2] = []
	for s in _spots:
		s["t"] += delta
		match int(s["state"]):
			0:
				var hp := _nearest(heroes, s["pos"])
				if hp.x < INF and hp.distance_to(s["pos"]) < flee_radius:
					_scare(s, hp)
					spooked.append(s["pos"])
				elif kind == "rats" and s["t"] > 3.0 and randf() < delta * 0.25:
					# Перебежка на пару шагов
					s["t"] = 0.0
					s["vel"] = Vector2.from_angle(randf() * TAU) * 40.0
					s["face"] = signf(s["vel"].x)
			1:
				_move(s, delta)
			2:
				var far := true
				for h in heroes:
					if h.distance_to(s["home"]) < 520.0:
						far = false
				if s["t"] > respawn_time and far and cam.distance_to(s["home"]) > 560.0:
					s["state"] = 0
					s["pos"] = s["home"]
					s["vel"] = Vector2.ZERO
					s["t"] = 0.0
		if int(s["state"]) == 0 and kind == "rats" and s["vel"] != Vector2.ZERO:
			s["pos"] += s["vel"] * delta
			s["vel"] = s["vel"].move_toward(Vector2.ZERO, 120.0 * delta)
	if not spooked.is_empty() and _sound_cd <= 0.0:
		_sound_cd = 2.5
		_play_flee(spooked[0])
	queue_redraw()


func _nearest(heroes: Array[Vector2], p: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	for h in heroes:
		if h.distance_to(p) < best.distance_to(p):
			best = h
	return best


func _scare(s: Dictionary, hero: Vector2) -> void:
	# Соседи срываются следом: в радиусе ещё полтора
	for o in _spots:
		if int(o["state"]) == 0 and o["pos"].distance_to(s["pos"]) < flee_radius * 1.5:
			var away: Vector2 = (o["pos"] - hero)
			if away.length() < 1.0:
				away = Vector2.RIGHT
			away = away.normalized()
			o["state"] = 1
			o["t"] = 0.0
			o["delay"] = randf_range(0.0, 0.35)
			if kind == "crows":
				o["vel"] = Vector2(away.x * randf_range(40, 80) + randf_range(-20, 20), randf_range(-90, -60))
			else:
				o["vel"] = away.rotated(randf_range(-0.6, 0.6)) * randf_range(150, 190)
			o["face"] = signf(o["vel"].x) if absf(o["vel"].x) > 1.0 else o["face"]


func _move(s: Dictionary, delta: float) -> void:
	if s["delay"] > 0.0:
		s["delay"] -= delta
		s["t"] = 0.0
		return
	var t: float = s["t"]
	if kind == "crows":
		# Разгон и набор высоты
		s["vel"] = s["vel"] * (1.0 + 0.6 * delta) + Vector2(0, -30.0 * delta)
		s["pos"] += s["vel"] * delta
		if t > 3.2:
			_gone(s)
	else:
		# Зигзаг
		var v: Vector2 = s["vel"]
		var side := Vector2(-v.y, v.x).normalized() * sin(t * 18.0 + s["ph"]) * 60.0
		s["pos"] += (v + side) * delta
		if t > 1.0:
			_gone(s)


func _gone(s: Dictionary) -> void:
	s["state"] = 2
	s["t"] = 0.0


func _alpha(s: Dictionary) -> float:
	if int(s["state"]) == 2:
		return 0.0
	if int(s["state"]) == 1 and s["delay"] <= 0.0:
		var t: float = s["t"]
		var end := 3.2 if kind == "crows" else 1.0
		return clampf((end - t) / (0.9 if kind == "crows" else 0.3), 0.0, 1.0)
	return 1.0


func _play_flee(at: Vector2) -> void:
	if kind == "crows":
		var st := SoundBank.load_sound("res://Sound/ambient_sound/crows.mp3")
		if st:
			var p := AudioStreamPlayer2D.new()
			p.stream = st
			p.volume_db = -6.0
			p.max_distance = 700.0
			add_child(p)
			p.global_position = at
			p.play(randf() * maxf(st.get_length() - 3.0, 0.0))
			var tw := p.create_tween()
			tw.tween_interval(1.6)
			tw.tween_property(p, "volume_db", -40.0, 0.8)
			tw.tween_callback(p.queue_free)
		_once(at, "ambience/wings_%d.wav" % randi_range(1, 2), -4.0)
	else:
		if randf() < 0.75:
			_once(at, "ambience/squeak_%d.wav" % randi_range(1, 3), -12.0)


func _once(at: Vector2, rel: String, db: float) -> void:
	var st := SoundBank.load_sound(SoundBank.DIR + rel)
	if st == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = st
	p.volume_db = db
	p.max_distance = 600.0
	p.pitch_scale = randf_range(0.9, 1.12)
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _draw() -> void:
	_o = global_position
	var cam := _cam()
	for s in _spots:
		var a := _alpha(s)
		if a <= 0.0:
			continue
		var pos: Vector2 = s["pos"]
		if pos.distance_to(cam) > 1100.0:
			continue
		if kind == "crows":
			_draw_crow(s, a)
		else:
			_draw_rat(s, a)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)


func _oval(c: Vector2, r: Vector2, col: Color, n := 10) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var an := TAU * i / n
		pts.append(c + Vector2(cos(an) * r.x, sin(an) * r.y))
	draw_colored_polygon(pts, col)


func _draw_crow(s: Dictionary, a: float) -> void:
	var col := Color(0.06, 0.06, 0.075, a)
	var face: float = s["face"]
	draw_set_transform(s["pos"] - _o, 0.0, Vector2(face, 1.0))
	var t := _time + float(s["ph"])
	if int(s["state"]) == 1 and s["delay"] <= 0.0:
		# Полёт: тело, крылья машут
		var flap := sin(t * 15.0)
		_oval(Vector2(0, -6), Vector2(5.0, 2.2), col)
		_oval(Vector2(5.2, -6.6), Vector2(2.0, 1.8), col)
		_poly([Vector2(7, -7), Vector2(9.4, -6.4), Vector2(7, -5.9)], col)
		_poly([Vector2(-4, -6), Vector2(-9, -4.5), Vector2(-8.5, -7.2)], col)
		var tip := Vector2(-3.0, -6.0 - 9.0 * flap)
		_poly([Vector2(-2, -6.5), Vector2(3, -6.5), tip + Vector2(2, 0), tip], col)
		_poly([Vector2(-2, -5.5), Vector2(3, -5.5), Vector2(-1, -5.5 + 4.0 * flap)], col)
		return
	# Сидит: на земле клюёт, на брусе вертит головой
	var peck := 0.0
	if s["ground"]:
		peck = maxf(sin(t * 1.7) * sin(t * 4.3), 0.0)
	var bob := sin(t * 2.3) * 0.5
	_poly([Vector2(-3.5, -4.5), Vector2(-9.5, -2.0), Vector2(-9.0, -0.8), Vector2(-3.0, -2.6)], col)
	_oval(Vector2(0, -4.5), Vector2(5.0, 3.0), col)
	var head := Vector2(4.6, -7.4 + bob) + Vector2(1.2, 4.5) * peck
	_oval(head, Vector2(2.3, 2.1), col)
	_poly([head + Vector2(1.6, -0.6), head + Vector2(4.4, 0.2 + peck), head + Vector2(1.6, 0.8)], Color(0.1, 0.1, 0.1, a))
	draw_line(Vector2(-0.5, -1.6), Vector2(-0.8, 0), col, 0.8)
	draw_line(Vector2(1.5, -1.6), Vector2(1.8, 0), col, 0.8)
	# Блик глаза — ловит свет факела
	draw_rect(Rect2(head + Vector2(0.6, -0.8), Vector2(0.7, 0.7)), Color(0.55, 0.55, 0.5, a))


func _draw_rat(s: Dictionary, a: float) -> void:
	var col := Color(0.46, 0.4, 0.34, a)
	var dark := Color(0.26, 0.22, 0.19, a)
	var v: Vector2 = s["vel"]
	var face: float = s["face"]
	var running: bool = int(s["state"]) == 1 and float(s["delay"]) <= 0.0
	if running and v.length() > 1.0:
		face = signf(v.x) if absf(v.x) > 1.0 else face
	var t := _time * (3.0 if running else 1.0) + float(s["ph"])
	draw_set_transform_matrix(Transform2D(0.0, s["pos"] - _o) * Transform2D(0.0, Vector2(face * 1.3, 1.05), 0.0, Vector2.ZERO))
	var sniff := sin(t * 9.0) * 0.4 if not running else 0.0
	var pts := PackedVector2Array()
	for i in 6:
		var x := -4.0 - i * 1.5
		pts.append(Vector2(x, 0.8 + sin(t * 6.0 + i * 0.9) * 0.6 * i / 5.0))
	draw_polyline(pts, Color(0.32, 0.24, 0.22, a), 0.7, true)
	_oval(Vector2(0, 0), Vector2(4.6, 2.5), col)
	_oval(Vector2(4.3 + sniff, -0.4), Vector2(2.5, 1.7), col)
	_poly([Vector2(5.8 + sniff, -1.0), Vector2(8.0 + sniff, 0.0), Vector2(5.8 + sniff, 0.8)], col)
	_oval(Vector2(3.4 + sniff, -2.0), Vector2(1.0, 0.9), dark, 6)
	draw_rect(Rect2(Vector2(5.4 + sniff, -1.0), Vector2(0.6, 0.6)), Color(0.9, 0.85, 0.75, a))
