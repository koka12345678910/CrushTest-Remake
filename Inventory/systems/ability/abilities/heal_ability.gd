# res://systems/ability/abilities/heal_ability.gd
class_name HealAbility
extends Ability

@export var heal_amount: float = 25.0


func _init() -> void:
	ability_name = "Healing Gourd"
	cooldown_duration = 3.0
	description = "Restore HP"


func _execute(player: Node) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	print("[HealAbility] Healed for ", heal_amount)
