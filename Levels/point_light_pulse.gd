extends PointLight2D

@export var pulse_speed: float = 2.0        # скорость пульсации
@export var pulse_min_energy: float = 2  # минимальная яркость
@export var pulse_max_energy: float = 3.0   # максимальная яркость
@export var randomize_offset: bool = true   # чтоб все не мигали синхронно

var _time: float = 0.0

func _ready() -> void:
	if randomize_offset:
		_time = randf() * TAU  # случайный сдвиг фазы

func _process(delta: float) -> void:
	_time += delta * pulse_speed
	var t = (sin(_time) + 1.0) / 2.0  # 0.0 → 1.0
	energy = lerp(pulse_min_energy, pulse_max_energy, t)
