extends CanvasLayer
## Красная виньетка на весь экран — вспыхивает при получении урона игроком
## и плавно затухает. Вызывается из Player.take_damage() -> flash().

@export var flash_in_time := 0.05
@export var hold_time := 0.05
@export var fade_out_time := 0.45
@export var max_strength := 1.0

@onready var rect: ColorRect = $ColorRect

var _tween: Tween


func flash(intensity: float = 1.0) -> void:
	var target := clampf(max_strength * intensity, 0.0, 1.0)
	var mat := rect.material as ShaderMaterial
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_strength.bind(mat), mat.get_shader_parameter("strength"), target, flash_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_strength.bind(mat), target, 0.0, fade_out_time)


func _set_strength(value: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("strength", value)
