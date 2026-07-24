extends Node2D
# Спавнер врагов: поддерживает нужное количество врагов на карте.
# Новых врагов подсаживает ТОЛЬКО в точках, которые сейчас вне камеры,
# чтобы игрок не видел момент спавна.

@export var enemy_scene: PackedScene
@export var max_enemies: int = 12
@export var check_interval: float = 1.5
# запас за краем экрана — точка считается «вне камеры», если дальше этого отступа
@export var offscreen_margin: float = 140.0
# спавнить ли начальную волну при старте (если враги уже расставлены вручную — false)
@export var spawn_on_ready: bool = false
# сколько врагов появляется за один спавн в точке (пачкой)
@export var pack_min: int = 4
@export var pack_max: int = 7
# радиус разброса врагов вокруг точки спавна
@export var pack_spread: float = 60.0

var _timer := 0.0

func _ready() -> void:
	if spawn_on_ready:
		for i in max_enemies:
			_try_spawn()

func _process(delta: float) -> void:
	_timer += delta
	if _timer < check_interval:
		return
	_timer = 0.0
	if _alive_enemy_count() < max_enemies:
		_try_spawn()

func _alive_enemy_count() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead:
			n += 1
	return n

func _try_spawn() -> void:
	var points := _get_spawn_points()
	if points.is_empty():
		return

	# только точки вне поля зрения игрока
	var hidden := points.filter(_is_offscreen)
	if hidden.is_empty():
		return  # все точки на экране — ждём, чтобы спавн остался незаметным

	var chosen: Marker2D = hidden.pick_random()
	var pack_size := randi_range(pack_min, pack_max)
	# минимальная дистанция между врагами одной пачки — иначе независимые
	# случайные офсеты иногда кладут двух врагов друг на друга (коллизии
	# точно совпадают), и физика Godot спотыкается на normalize(0,0)
	# ("Vector2 cannot be normalized") пытаясь их раздвинуть
	var min_spacing := 40.0
	var placed: Array[Vector2] = []
	for i in pack_size:
		var offset := Vector2.ZERO
		for attempt in 8:
			offset = Vector2(randf_range(-pack_spread, pack_spread), randf_range(-pack_spread, pack_spread))
			var far_enough := true
			for p in placed:
				if offset.distance_to(p) < min_spacing:
					far_enough = false
					break
			if far_enough:
				break
		placed.append(offset)
		var enemy := enemy_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = chosen.global_position + offset

func _get_spawn_points() -> Array:
	var pts := []
	for c in get_children():
		if c is Marker2D:
			pts.append(c)
	return pts

func _is_offscreen(point: Marker2D) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var view_size := get_viewport_rect().size / cam.zoom
	var center := cam.get_screen_center_position()
	var rect := Rect2(center - view_size * 0.5, view_size).grow(offscreen_margin)
	return not rect.has_point(point.global_position)
