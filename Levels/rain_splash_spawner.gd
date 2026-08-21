extends Node2D
## Спавнит всплески капель (rain_splash_vfx.tscn) в случайных точках
## ВИДИМОЙ ОБЛАСТИ КАМЕРЫ, но в мировых координатах — в отличие от самих
## капель дождя (Rain, GPUParticles2D под Camera2D), которые камера-локальные
## для простоты. Если бы всплеск был ребёнком камеры, он "уезжал" бы вместе
## с ней, пока доигрывает свои 5 кадров — получалось бы скольжение по земле,
## а не "шлёпнулся на месте и исчез". Поэтому здесь мы только СПРАШИВАЕМ у
## камеры её текущую видимую область в мире, а сам всплеск кладём в сцену
## уровня, независимо от дальнейшего движения камеры.

const SPLASH_VFX := preload("res://VFX/VFX_scene/rain_splash_vfx.tscn")

# Умеренная частота — заметно, но не отвлекает от боя (лёгкий дождь, не ливень)
@export var spawn_interval_min := 0.08
@export var spawn_interval_max := 0.22
# Небольшой отступ от края экрана — иначе всплески заметно "рождаются"
# ровно на границе видимости
@export var margin_fraction := 0.08

var _camera: Camera2D
var _timer := 0.0


func _ready() -> void:
	_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		# Спавнер стоит в дереве раньше игрока, поэтому в _ready() игрок ещё
		# не успевает попасть в группу "player" (та добавляется в ЕГО
		# _ready()) — ищем камеру лениво, пока не найдётся, а не один раз
		var player := get_tree().get_first_node_in_group("player")
		if player:
			_camera = player.get_node_or_null("Camera2D")
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(spawn_interval_min, spawn_interval_max)
	_spawn_splash()


func _spawn_splash() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var half_extent: Vector2 = (viewport_size / _camera.zoom) / 2.0
	# Сжимаем область спавна отступом с каждой стороны
	half_extent *= (1.0 - margin_fraction)

	var center: Vector2 = _camera.global_position
	var pos := Vector2(
		center.x + randf_range(-half_extent.x, half_extent.x),
		center.y + randf_range(-half_extent.y, half_extent.y)
	)

	var splash := SPLASH_VFX.instantiate()
	splash.global_position = pos
	get_tree().current_scene.add_child(splash)
