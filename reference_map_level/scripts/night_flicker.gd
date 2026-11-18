extends Node2D
## Живой огонь: факелы и костры карты дрожат по шуму, каждый в своём ритме
## (тот же приём, что Levels/props/fire_flicker.gd, но для готовых источников
## света, лежащих прямо в узле Night). Свет без огня (фонтан, огоньки топи)
## не трогается — только узлы, чьё имя начинается с одного из fire_prefixes.

@export var fire_prefixes: PackedStringArray = ["Torch", "Camp", "Fire", "Brazier", "Beacon"]
@export_range(0.0, 1.0) var energy_jitter := 0.2
@export_range(0.0, 0.5) var scale_jitter := 0.045
@export var speed := 6.0

## Огонь без мерцания (свечи, фонари): днём тоже гаснет, как факелы.
## Магия (фонтан, огоньки топи, свечение босса) от времени суток не зависит
@export var calm_fire_prefixes: PackedStringArray = ["Candle", "Lantern"]

var _noise := FastNoiseLite.new()
var _fires: Array = []   # [light, base_energy, base_scale, phase]
var _calm: Array = []    # [light, base_energy]
var _t := 0.0


func _ready() -> void:
	_noise.frequency = 1.0
	for l in find_children("*", "PointLight2D", true, false):
		var found := false
		for p in fire_prefixes:
			if String(l.name).begins_with(p):
				_fires.append([l, l.energy, l.texture_scale, randf() * 1000.0])
				found = true
				break
		if found:
			continue
		for p in calm_fire_prefixes:
			if String(l.name).begins_with(p):
				_calm.append([l, l.energy])
				break


func _process(delta: float) -> void:
	_t += delta * speed
	# Днём огонь слабее (время суток и тучи — Levels/weather.gd), как костры
	# fire_flicker.gd на кладбище; без погоды — в полную силу
	var weather := get_node_or_null("/root/Weather")
	var day_k: float = weather.get("fire_scale") if weather and weather.call("is_active") else 1.0
	for f in _fires:
		var l: PointLight2D = f[0]
		var t: float = _t + f[3]
		var n := _noise.get_noise_1d(t) * 0.7 + _noise.get_noise_1d(t * 3.1 + 50.0) * 0.3
		l.energy = f[1] * day_k * (1.0 + n * energy_jitter)
		l.texture_scale = f[2] * (1.0 + n * scale_jitter)
	for c in _calm:
		(c[0] as PointLight2D).energy = float(c[1]) * day_k
