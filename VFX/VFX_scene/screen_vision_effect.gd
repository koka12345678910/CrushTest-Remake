extends ColorRect

var _tween: Tween

func activate(fade_in_time: float = 0.4) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(material, "shader_parameter/flash", 1.0, 0.05)
	_tween.tween_property(material, "shader_parameter/flash", 0.0, 0.35)
	_tween.tween_property(material, "shader_parameter/intensity", 1.0, fade_in_time)

func deactivate(fade_out_time: float = 0.6) -> void:
	_fade_to(0.0, fade_out_time)

func _fade_to(target: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(material, "shader_parameter/intensity", target, time)
