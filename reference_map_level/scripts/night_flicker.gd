extends Node2D
## Живой огонь: факелы и костры карты дрожат по шуму, каждый в своём ритме
## (тот же приём, что Levels/props/fire_flicker.gd, но для готовых источников
## света, лежащих прямо в узле Night). Свет без огня (фонтан, огоньки топи)
## не трогается — только узлы, чьё имя начинается с одного из fire_prefixes.

@export var fire_prefixes: PackedStringArray = ["Torch", "Camp", "Fire", "Brazier", "Beacon"]
@export_range(0.0, 1.0) var energy_jitter := 0.2
@export_range(0.0, 0.5) var scale_jitter := 0.045
@export var speed := 6.0

var _noise := FastNoiseLite.new()
var _fires: Array = []   # [light, base_energy, base_scale, phase]
var _t := 0.0


func _ready() -> void:
	_noise.frequency = 1.0
	for l in find_children("*", "PointLight2D", true, false):
		for p in fire_prefixes:
			if String(l.name).begins_with(p):
				_fires.append([l, l.energy, l.texture_scale, randf() * 1000.0])
				break


func _process(delta: float) -> void:
	_t += delta * speed
	for f in _fires:
		var l: PointLight2D = f[0]
		var t: float = _t + f[3]
		var n := _noise.get_noise_1d(t) * 0.7 + _noise.get_noise_1d(t * 3.1 + 50.0) * 0.3
		l.energy = f[1] * (1.0 + n * energy_jitter)
		l.texture_scale = f[2] * (1.0 + n * scale_jitter)
