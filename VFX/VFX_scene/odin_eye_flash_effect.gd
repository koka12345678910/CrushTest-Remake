extends Node
## Вспышка с амулетом Глаза Одина при активации способности — по образцу
## fenrir_flash_effect.gd. У Фенрира два кадра волка (голова поворачивается),
## у амулета один кадр, поэтому вместо смены картинки дважды пульсируем ОДНИМ
## изображением — тот же двойной ритм мерцание+вспышка, что и у Фенрира.

@onready var flash: ColorRect = $Flash
@onready var eye: TextureRect = $Eye

var _tween: Tween


func play() -> void:
	if _tween:
		_tween.kill()
	flash.color.a = 0.0
	eye.modulate.a = 0.0
	_tween = create_tween()

	# Мерцание перед первой вспышкой
	_add_flicker(3)

	# Кадр 1
	_tween.tween_property(flash, "color:a", 0.6, 0.05)
	_tween.parallel().tween_property(eye, "modulate:a", 1.0, 0.15)
	_tween.tween_property(flash, "color:a", 0.0, 0.35)
	_tween.parallel().tween_property(eye, "modulate:a", 0.0, 0.55)

	# Мерцание перед вторым импульсом
	_add_flicker(2)

	# Кадр 2 — тот же амулет, второй пульс (эффект "моргания" ока)
	_tween.tween_property(flash, "color:a", 0.6, 0.05)
	_tween.parallel().tween_property(eye, "modulate:a", 1.0, 0.15)
	_tween.tween_property(flash, "color:a", 0.0, 0.35)
	_tween.parallel().tween_property(eye, "modulate:a", 0.0, 0.55)


func _add_flicker(count: int) -> void:
	for i in count:
		_tween.tween_property(flash, "color:a", randf_range(0.15, 0.4), 0.03)
		_tween.tween_property(flash, "color:a", 0.05, 0.03)
