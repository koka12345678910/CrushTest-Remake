extends Node

@onready var flash: ColorRect = $Flash
@onready var wolf: TextureRect = $Wolf

var _tween: Tween

func play() -> void:
	if _tween:
		_tween.kill()
	flash.color.a = 0.0
	wolf.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(flash, "color:a", 0.9, 0.05)
	_tween.parallel().tween_property(wolf, "modulate:a", 1.0, 0.15)
	_tween.tween_property(flash, "color:a", 0.0, 0.35)
	_tween.parallel().tween_property(wolf, "modulate:a", 0.0, 0.55)
