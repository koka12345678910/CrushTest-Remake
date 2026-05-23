# res://systems/ability/abilities/honey_mead_ability.gd
class_name HoneyMeadAbility
extends Ability

@export var heal_per_tick: float = 8.0
@export var tick_interval: float = 0.5
@export var total_ticks: int = 6  # лечит 6 раз = 48 HP суммарно

func _init() -> void:
	ability_name = "Мёд Поэзии"
	cooldown_duration = 12.0
	description = "Постепенно восстанавливает здоровье"
	icon = load("res://Shop/icons/jar_honey.png")

func _execute(player: Node) -> void:
	player.start_heal_over_time(heal_per_tick, tick_interval, total_ticks)
