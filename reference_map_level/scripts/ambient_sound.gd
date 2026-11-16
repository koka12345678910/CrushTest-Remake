extends Node2D
## ambient_sound.gd — позиционные звуки мира reference_map: река у воды, шелест
## в лесу, гул ветра из пропасти, болото, хлопающая ткань шатров (петли), скрип
## ставней в деревне и верёвки виселицы (разовые, со случайной паузой).
##
## Точки раскладывает immersion.gd (_build_sound). Плееры AudioStreamPlayer2D
## создаются только рядом с камерой и удаляются, когда она уходит, — одновременно
## звучат несколько ближайших источников, а не сотни по всей карте.

const SoundBank := preload("res://Levels/sound_bank.gd")

## Сколько петель может звучать сразу (ближайшие)
@export var max_loops := 10
## Как часто пересчитывать, кто рядом (с)
@export var check_interval := 0.35
## Громкость всего слоя (дБ поверх громкости каждого источника)
@export var master_db := 0.0

## {"pos", "stream", "db", "dist", "pitch", "player"}
var _loops: Array[Dictionary] = []
## Разовые: {"points": PackedVector2Array, "streams": Array, "db", "dist",
## "gap": Vector2 (мин/макс пауза), "timer", "pitch": Vector2}
var _oneshots: Array[Dictionary] = []
var _check := 0.0
var _streams := {}


func add_loop(pos: Vector2, rel: String, db: float, dist: float, pitch := 1.0) -> void:
	var st := _loop_stream(rel)
	if st == null:
		return
	_loops.append({"pos": pos, "stream": st, "db": db, "dist": dist, "pitch": pitch, "player": null})


func add_oneshots(points: PackedVector2Array, rels: Array, db: float, dist: float, gap: Vector2, pitch := Vector2(0.9, 1.1)) -> void:
	var streams: Array[AudioStream] = []
	for r in rels:
		var st := SoundBank.load_sound(SoundBank.DIR + str(r))
		if st:
			streams.append(st)
	if streams.is_empty() or points.is_empty():
		return
	_oneshots.append({"points": points, "streams": streams, "db": db, "dist": dist, "gap": gap,
		"timer": randf_range(gap.x * 0.3, gap.y), "pitch": pitch})


func loop_count() -> int:
	return _loops.size()


func _loop_stream(rel: String) -> AudioStream:
	if not _streams.has(rel):
		_streams[rel] = SoundBank.loop_stream(rel)
	return _streams[rel]


func _listener() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)


func _process(delta: float) -> void:
	var ear := _listener()
	_check -= delta
	if _check <= 0.0:
		_check = check_interval
		_update_loops(ear)
	for o in _oneshots:
		o["timer"] -= delta
		if o["timer"] > 0.0:
			continue
		var gap: Vector2 = o["gap"]
		o["timer"] = randf_range(gap.x, gap.y)
		var pts: PackedVector2Array = o["points"]
		var dist: float = o["dist"]
		var near := PackedVector2Array()
		for p in pts:
			if p.distance_to(ear) < dist * 0.85:
				near.append(p)
		if near.is_empty():
			continue
		var at := near[randi() % near.size()]
		var streams: Array = o["streams"]
		var pr: Vector2 = o["pitch"]
		_play_once(at, streams[randi() % streams.size()], o["db"], dist, randf_range(pr.x, pr.y))


func _update_loops(ear: Vector2) -> void:
	# Ближайшие max_loops из тех, что в радиусе слышимости
	var cand: Array = []
	for i in _loops.size():
		var l := _loops[i]
		var d := ear.distance_to(l["pos"])
		if d < float(l["dist"]) + 48.0:
			cand.append([d, i])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var keep := {}
	for j in mini(cand.size(), max_loops):
		keep[cand[j][1]] = true
	for i in _loops.size():
		var l := _loops[i]
		var p: AudioStreamPlayer2D = l["player"]
		if keep.has(i):
			if p == null or not is_instance_valid(p):
				p = AudioStreamPlayer2D.new()
				p.stream = l["stream"]
				p.volume_db = float(l["db"]) + master_db
				p.max_distance = l["dist"]
				p.attenuation = 1.6
				p.pitch_scale = l["pitch"]
				p.position = l["pos"]
				add_child(p)
				p.play(randf() * p.stream.get_length() * 0.9)
				l["player"] = p
		elif p != null and is_instance_valid(p):
			p.queue_free()
			l["player"] = null


func _play_once(at: Vector2, st: AudioStream, db: float, dist: float, pitch: float) -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = st
	p.volume_db = db + master_db
	p.max_distance = dist
	p.attenuation = 1.4
	p.pitch_scale = pitch
	p.position = at
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Разовый звук в точке (виселица скрипит в такт качанию — immersion.gd)
func play_at(at: Vector2, rel: String, db: float, dist: float, pitch := 1.0) -> void:
	if _listener().distance_to(at) > dist:
		return
	var st := SoundBank.load_sound(SoundBank.DIR + rel)
	if st:
		_play_once(at, st, db, dist, pitch)
