extends CanvasLayer
## Постоянная виньетка на весь экран — в отличие от damage_vignette (короткая
## вспышка на удар) эта плавно НАРАСТАЕТ и ДЕРЖИТСЯ, пока состояние активно,
## затем плавно гаснет. Используется для истощения (голубой экран при нулевой
## стамине). Отдельный слой, чтобы не конфликтовать с красной вспышкой урона —
## они могут накладываться друг на друга.

@export var fade_in_time := 0.35
@export var fade_out_time := 0.6
@export var max_strength := 0.75

@onready var rect: ColorRect = $ColorRect

var _active := false
var _tween: Tween


func set_active(active: bool) -> void:
	# реагируем только на смену состояния — иначе твин пересоздавался бы
	# каждый кадр и виньетка залипала бы в начале анимации
	if active == _active:
		return
	_active = active

	var mat := rect.material as ShaderMaterial
	var target := max_strength if active else 0.0
	var duration := fade_in_time if active else fade_out_time

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(
		_set_strength.bind(mat),
		float(mat.get_shader_parameter("strength")),
		target,
		duration
	)


func _set_strength(value: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("strength", value)
