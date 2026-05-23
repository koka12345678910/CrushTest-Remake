# res://systems/ability/abilities/fenrir_blood_ability.gd
class_name FenrirBloodAbility
extends Ability

@export var duration: float = 5.0
@export var speed_bonus: float = 100.0
@export var damage_multiplier: float = 1.75

func _init() -> void:
	ability_name = "Кровь Фенрира"
	cooldown_duration = 60.0
	description = "Неуязвимость, скорость и сила на 5 секунд"
	icon = load("res://Shop/icons/demon_flask.png")

func _execute(player: Node) -> void:
	# Неуязвимость через существующую систему i-frames
	player.is_invulnerable = true

	# Применяем бафф
	if player.has_method("apply_buff"):
		player.apply_buff({
			"speed_bonus": speed_bonus,
			"damage_multiplier": damage_multiplier,
			"duration": duration,
			"name": "fenrir_blood",
			"invulnerable": true
		})

	# Снимаем неуязвимость через duration секунд
	player.get_tree().create_timer(duration).timeout.connect(
		func():
			player.is_invulnerable = false
			print("[КровьФенрира] Эффект закончился")
	)

	# TODO: активировать VFX когда будет готов
	print("[КровьФенрира] Активирована! Неуязвимость на ", duration, " сек")
