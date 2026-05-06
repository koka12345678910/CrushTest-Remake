# res://systems/ability/abilities/valhalla_elixir_ability.gd
class_name ValhallaElixirAbility
extends Ability

@export var heal_amount: float = 60.0  # не 100% — как по описанию

func _init() -> void:
	ability_name = "Эликсир Вальгаллы"
	cooldown_duration = 8.0
	description = "Моментально восстанавливает здоровье"
	icon = load("res://Shop/icons/flask_red.png")

func _execute(player: Node) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	print("[ЭликсирВальгаллы] Мгновенное лечение на ", heal_amount)
