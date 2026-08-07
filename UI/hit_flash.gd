extends CanvasLayer
## Короткая белая вспышка на весь экран при получении урона — быстрый "удар
## по глазам" в дополнение к красной виньетке (та мягче и держится дольше,
## эта — резкая и почти мгновенная, добавляет "хруст" удару).

@export var flash_in_time := 0.02
@export var fade_out_time := 0.12
@export var max_alpha := 0.55

@onready var rect: ColorRect = $ColorRect

var _tween: Tween


func flash() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(rect, "color:a", max_alpha, flash_in_time)
	_tween.tween_property(rect, "color:a", 0.0, fade_out_time)
