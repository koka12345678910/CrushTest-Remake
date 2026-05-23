extends Node2D
## BirdsEffect.gd
## Птицы медленно пролетают по горизонту — рисуются процедурно через _draw().
## Никаких спрайтов не нужно, только код.

const BIRD_COUNT := 7
const SCREEN_WIDTH := 1152.0
const FLY_Y_MIN := 130.0
const FLY_Y_MAX := 230.0
const SPEED_MIN := 28.0
const SPEED_MAX := 55.0
const WING_FREQ_MIN := 1.8
const WING_FREQ_MAX := 3.2

var _birds: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	for i in BIRD_COUNT:
		_birds.append(_new_bird(true))


func _process(delta: float) -> void:
	_time += delta
	for bird in _birds:
		bird["x"] += bird["speed"] * delta
		if bird["x"] > SCREEN_WIDTH + 40:
			_reset_bird(bird)
	queue_redraw()


func _draw() -> void:
	for bird in _birds:
		_draw_bird(bird)


func _draw_bird(bird: Dictionary) -> void:
	var x: float = bird["x"]
	var y: float = bird["y"]
	var size: float = bird["size"]
	var freq: float = bird["wing_freq"]
	var phase: float = bird["phase"]

	# Взмах крыльев: sin волна
	var flap := sin(_time * freq + phase) * size * 1.6

	# Цвет: тёмно-серый силуэт с небольшой прозрачностью
	var col := Color(0.25, 0.28, 0.32, bird["alpha"])

	# Левое крыло
	var pts_left := PackedVector2Array([
		Vector2(x - size * 2.2, y + flap * 0.4),
		Vector2(x - size * 0.5, y + flap),
		Vector2(x, y)
	])
	draw_polyline(pts_left, col, 1.2, true)

	# Правое крыло
	var pts_right := PackedVector2Array([
		Vector2(x, y),
		Vector2(x + size * 0.5, y + flap),
		Vector2(x + size * 2.2, y + flap * 0.4)
	])
	draw_polyline(pts_right, col, 1.2, true)

	# Тело (маленький овал)
	draw_arc(Vector2(x, y), size * 0.35, 0, TAU, 8, col, 1.0)


func _new_bird(random_x: bool) -> Dictionary:
	return {
		"x": randf_range(0, SCREEN_WIDTH) if random_x else -40.0,
		"y": randf_range(FLY_Y_MIN, FLY_Y_MAX),
		"speed": randf_range(SPEED_MIN, SPEED_MAX),
		"size": randf_range(2.5, 5.0),
		"wing_freq": randf_range(WING_FREQ_MIN, WING_FREQ_MAX),
		"phase": randf() * TAU,
		"alpha": randf_range(0.4, 0.75)
	}


func _reset_bird(bird: Dictionary) -> void:
	bird["x"] = -40.0
	bird["y"] = randf_range(FLY_Y_MIN, FLY_Y_MAX)
	bird["speed"] = randf_range(SPEED_MIN, SPEED_MAX)
	bird["size"] = randf_range(2.5, 5.0)
	bird["wing_freq"] = randf_range(WING_FREQ_MIN, WING_FREQ_MAX)
	bird["phase"] = randf() * TAU
	bird["alpha"] = randf_range(0.4, 0.75)
