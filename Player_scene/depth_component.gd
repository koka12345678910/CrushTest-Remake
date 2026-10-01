extends Node
## depth_component.gd — "этажность" карты в 2D: чем ниже герой спустился,
## тем он меньше (дальше от камеры), чем выше поднялся — тем крупнее.
##
## Вешается кодом на персонажа (player.gd / character_base.gd), имя узла —
## "DepthComponent": по нему зона лестницы (Levels/stairs_zone.gd) находит,
## кого масштабировать. Нет компонента — лестница тело просто игнорирует,
## так что враги без него ведут себя как раньше.
##
## height — дробный "этаж": 0 основной, 1 этажом выше, -1 ниже, 0.5 — середина
## лестницы. Масштабируется ТОЛЬКО картинка (первый AnimatedSprite2D
## персонажа): камера и коллизия не трогаются, иначе поехал бы зум и
## физика. Скорость ходьбы/бега/переката чуть уменьшается вместе с размером —
## далёкий персонаж и по экрану двигается медленнее, без этого иллюзия
## глубины ломается.

## Во сколько меняется размер за один этаж (0.18 = +18% вверх, −18% вниз)
@export var scale_per_level := 0.18
## Насколько скорость следует за размером (0 — не меняется, 1 — ровно как размер)
@export var speed_follow := 0.6
## Скорость, с которой картинка догоняет целевой размер — сглаживает резкие
## скачки высоты (например, при выходе из зоны лестницы сбоку)
@export var smoothing := 10.0
## Сдвиг z_index за этаж. 0 — не трогать. Пригодится, когда у верхних этажей
## будут свои тайл-слои поверх нижних
@export var z_per_level := 0

var height := 0.0

var _body: Node2D
var _sprite: Node2D
var _base_sprite_scale := Vector2.ONE
var _base_z := 0
var _base_speeds := {}
var _shown_factor := 1.0


func _ready() -> void:
	_body = get_parent() as Node2D
	if _body == null:
		push_error("[DepthComponent] родитель должен быть Node2D")
		return
	for c in _body.get_children():
		if c is AnimatedSprite2D or c is Sprite2D:
			_sprite = c
			break
	if _sprite:
		_base_sprite_scale = _sprite.scale
	_base_z = _body.z_index
	for prop in ["walk_speed", "run_speed", "roll_speed"]:
		if prop in _body:
			_base_speeds[prop] = _body.get(prop)


## Множитель размера для текущей высоты (1.0 на основном этаже)
func size_factor(h := height) -> float:
	return maxf(0.3, 1.0 + h * scale_per_level)


func set_height(h: float) -> void:
	height = h


func _process(delta: float) -> void:
	if _body == null:
		return
	var target := size_factor()
	_shown_factor = lerpf(_shown_factor, target, minf(1.0, smoothing * delta))
	if absf(_shown_factor - target) < 0.001:
		_shown_factor = target

	if _sprite:
		_sprite.scale = _base_sprite_scale * _shown_factor

	var speed_k := 1.0 + (_shown_factor - 1.0) * speed_follow
	for prop in _base_speeds:
		_body.set(prop, _base_speeds[prop] * speed_k)

	if z_per_level != 0:
		_body.z_index = _base_z + int(round(height)) * z_per_level
