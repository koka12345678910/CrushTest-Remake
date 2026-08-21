extends Node
## Вспышка с руной при активации Руны Жертвы — по образцу
## fenrir_flash_effect.gd / odin_eye_flash_effect.gd. Один кровавый пульс:
## это мгновенная жертва, а не тянущийся эффект, поэтому короче и резче,
## чем у остальных двух — без второго "повторного" импульса.

@onready var flash: ColorRect = $Flash
@onready var rune: TextureRect = $Rune

var _tween: Tween


func play() -> void:
	if _tween:
		_tween.kill()
	flash.color.a = 0.0
	rune.modulate.a = 0.0
	_tween = create_tween()

	# Короткое мерцание — руна "разгорается"
	_add_flicker(2)

	# Резкий пик и медленный спад — руна прогорает и гаснет
	_tween.tween_property(flash, "color:a", 0.55, 0.04)
	_tween.parallel().tween_property(rune, "modulate:a", 1.0, 0.1)
	_tween.tween_property(flash, "color:a", 0.0, 0.3)
	_tween.parallel().tween_property(rune, "modulate:a", 0.0, 0.5)


func _add_flicker(count: int) -> void:
	for i in count:
		_tween.tween_property(flash, "color:a", randf_range(0.15, 0.35), 0.03)
		_tween.tween_property(flash, "color:a", 0.05, 0.03)
