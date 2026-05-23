# res://systems/ability/abilities/baldur_blessing_ability.gd
class_name BaldurBlessingAbility
extends Ability

@export var duration: float = 12.0
@export var damage_reduction: float = 0.6  # получаем только 40% урона

func _init() -> void:
	ability_name = "Благословение Бальдра"
	cooldown_duration = 25.0
	description = "Значительно снижает получаемый урон"
	icon = load("res://Shop/icons/light_orb.png")

func _execute(player: Node) -> void:
	if player.has_method("apply_buff"):
		player.apply_buff({
			"damage_reduction": damage_reduction,
			"duration": duration,
			"name": "baldur_blessing"
		})
	# TODO: когда появится система урона от врагов:
	# в take_damage() умножать на (1.0 - damage_reduction) если бафф активен
	print("[БлагословениеБальдра] Защита активна на ", duration, " сек, урон x", 1.0 - damage_reduction)
