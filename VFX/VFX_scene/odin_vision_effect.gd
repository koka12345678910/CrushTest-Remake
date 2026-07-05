extends ColorRect
# Экранный эффект Глаза Одина: короткая вспышка при активации,
# затем лёгкий голубоватый тон на время замедления, и возврат к норме в конце.

var _tween: Tween

func activate() -> void:
	if _tween:
		_tween.kill()
	color.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.5, 0.06)   # вспышка
	_tween.tween_property(self, "color:a", 0.16, 0.3)   # оседает в лёгкий голубой тон

func deactivate() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.0, 0.4)    # картинка возвращается в норму
