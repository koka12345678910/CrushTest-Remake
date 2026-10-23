extends Node2D
# Спавнер врагов: поддерживает нужное количество врагов на карте.
# Новых врагов подсаживает ТОЛЬКО в точках, которые сейчас вне камеры,
# чтобы игрок не видел момент спавна.

@export var enemy_scene: PackedScene
## Смешанный состав (локации со своими врагами, напр. скелеты кладбища).
## Если список не пуст, enemy_scene не используется: каждый враг пачки
## выбирается случайно по весу enemy_weights, а enemy_pack_limits ограничивает,
## сколько таких может быть в одной пачке (0 — без ограничения)
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: Array[float] = []
@export var enemy_pack_limits: Array[int] = []
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
	var in_pack := {}
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
		var scene := _pick_scene(in_pack)
		if scene == null:
			continue
		in_pack[scene] = in_pack.get(scene, 0) + 1
		var enemy := scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = _walkable(chosen.global_position + offset)

## Точка разброса могла попасть в надгробие, ящик или стену — притягиваем её
## к ближайшему месту на навмеше (он запечён с отступом от препятствий).
## Навмеш ещё не готов — оставляем как есть: враг сам выйдет из предмета
## (enemy.gd::_free_from_obstacles)
func _walkable(p: Vector2) -> Vector2:
	var nav_map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(nav_map) == 0:
		return p
	var snapped := NavigationServer2D.map_get_closest_point(nav_map, p)
	if not snapped.is_finite() or snapped == Vector2.ZERO or snapped.distance_to(p) > 200.0:
		return p
	return snapped

## Враг для пачки: по весу из enemy_scenes с учётом лимитов на пачку
## (пустой список — просто enemy_scene)
func _pick_scene(in_pack: Dictionary) -> PackedScene:
	if enemy_scenes.is_empty():
		return enemy_scene
	var total := 0.0
	var options: Array[int] = []
	for i in enemy_scenes.size():
		var limit: int = enemy_pack_limits[i] if i < enemy_pack_limits.size() else 0
		if enemy_scenes[i] == null or (limit > 0 and in_pack.get(enemy_scenes[i], 0) >= limit):
			continue
		options.append(i)
		total += enemy_weights[i] if i < enemy_weights.size() else 1.0
	var r := randf() * total
	for i in options:
		r -= enemy_weights[i] if i < enemy_weights.size() else 1.0
		if r <= 0.0:
			return enemy_scenes[i]
	return enemy_scenes[options.back()] if not options.is_empty() else enemy_scene

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
