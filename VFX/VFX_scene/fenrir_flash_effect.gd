extends Node

@onready var flash: ColorRect = $Flash
@onready var wolf: TextureRect = $Wolf
@onready var wolf2: TextureRect = $Wolf2

var _tween: Tween

func play() -> void:
	if _tween:
		_tween.kill()
	flash.color.a = 0.0
	wolf.modulate.a = 0.0
	wolf2.modulate.a = 0.0
	_tween = create_tween()

	# Мерцание перед вспышкой
	_add_flicker(3)

	# Кадр 1
	_tween.tween_property(flash, "color:a", 0.6, 0.05)
	_tween.parallel().tween_property(wolf, "modulate:a", 1.0, 0.15)
	_tween.tween_property(flash, "color:a", 0.0, 0.35)
	_tween.parallel().tween_property(wolf, "modulate:a", 0.0, 0.55)

	# Мерцание перед вторым кадром
	_add_flicker(2)

	# Кадр 2 — волк поворачивает голову
	_tween.tween_property(flash, "color:a", 0.6, 0.05)
	_tween.parallel().tween_property(wolf2, "modulate:a", 1.0, 0.15)
	_tween.tween_property(flash, "color:a", 0.0, 0.35)
	_tween.parallel().tween_property(wolf2, "modulate:a", 0.0, 0.55)

func _add_flicker(count: int) -> void:
	for i in count:
		_tween.tween_property(flash, "color:a", randf_range(0.15, 0.4), 0.03)
		_tween.tween_property(flash, "color:a", 0.05, 0.03)
