# res://systems/ability/abilities/dash_ability.gd
class_name DashAbility
extends Ability

@export var dash_force: float = 400.0
@export var dash_duration: float = 0.15


func _init() -> void:
	ability_name = "Shadowrush"
	cooldown_duration = 1.5
	description = "Dash forward"


func _execute(player: Node) -> void:
	if player.has_method("dash"):
		player.dash(dash_force, dash_duration)
	print("[DashAbility] Dash!")
