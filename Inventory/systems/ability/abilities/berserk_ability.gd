# res://systems/ability/abilities/berserk_ability.gd
class_name BerserkAbility
extends Ability

@export var duration: float = 10.0
@export var damage_multiplier: float = 2.0
@export var speed_bonus: float = 80.0

func _init() -> void:
	ability_name = "Безумие Берсерка"
	cooldown_duration = 30.0
	description = "HP пополам, сила x2, скорость, дальнобойные удары"
	icon = load("res://Shop/icons/blood_pouch.png")

func _execute(player: Node) -> void:
	# Срезаем HP пополам
	if player.has_method("take_damage"):
		var half_hp = player.health * 0.5
		player.take_damage(int(half_hp))

	# Применяем бафф
	if player.has_method("apply_buff"):
		player.apply_buff({
			"damage_multiplier": damage_multiplier,
			"speed_bonus": speed_bonus,
			"duration": duration,
			"name": "berserk",
			"ranged_attacks": true  # флаг для VFX дальнобойных ударов
		})

	# TODO: активировать VFX дальнобойных ударов
	# TODO: подключить к системе атак когда будет готова
	print("[БезумиеБерсерка] Активировано! HP срезано, сила x2 на ", duration, " сек")
