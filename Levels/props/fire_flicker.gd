extends Node2D
## fire_flicker.gd — живое пламя факела/костра.
##
## Свет (PointLight2D) и светящееся ядро огня дрожат по шуму, а не по синусу:
## синус читается как "пульсирующая лампочка", а у огня ритма нет. Каждый
## огонь получает свой сид шума — соседние факелы не мигают синхронно.

@export var light_path: NodePath = ^"Light"
@export var glow_path: NodePath = ^"Glow"
## Базовая яркость света и разброс дрожания (доля от базовой)
@export var base_energy := 1.1
@export_range(0.0, 1.0) var energy_jitter := 0.28
## Насколько "дышит" радиус света (доля от исходного texture_scale)
@export_range(0.0, 0.5) var scale_jitter := 0.06
## Скорость дрожания
@export var speed := 7.0

var _noise := FastNoiseLite.new()
var _t := 0.0
var _light: PointLight2D
var _glow: CanvasItem
var _base_scale := 1.0
var _glow_base := Vector2.ONE


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_t = randf() * 100.0
	_light = get_node_or_null(light_path) as PointLight2D
	_glow = get_node_or_null(glow_path) as CanvasItem
	if _light:
		_base_scale = _light.texture_scale
	if _glow is Node2D:
		_glow_base = (_glow as Node2D).scale


func _process(delta: float) -> void:
	_t += delta * speed
	# Два слоя шума: медленное "дыхание" + быстрая дрожь языков пламени
	var n := _noise.get_noise_1d(_t) * 0.7 + _noise.get_noise_1d(_t * 3.1 + 50.0) * 0.3
	if _light:
		_light.energy = base_energy * (1.0 + n * energy_jitter)
		_light.texture_scale = _base_scale * (1.0 + n * scale_jitter)
	if _glow is Node2D:
		(_glow as Node2D).scale = _glow_base * (1.0 + n * 0.12)
