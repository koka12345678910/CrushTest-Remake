# res://systems/ability/abilities/baldur_blessing_ability.gd
class_name BaldurBlessingAbility
extends Ability

@export var duration: float = 12.0
@export var damage_reduction: float = 0.6  # получаем только 40% урона

func _init() -> void:
	ability_name = "Благословение Бальдра"
	cooldown_duration = 40.0
	description = "Снижает урон и один раз воскрешает при гибели"
	icon = load("res://Shop/icons/light_orb.png")

func _execute(player: Node) -> void:
	if player.has_method("apply_buff"):
		player.apply_buff({
			"damage_reduction": damage_reduction,
			"duration": duration,
			"name": "baldur_blessing"
		})

	# Одноразовое воскрешение на время действия благословения
	player.baldur_revive_ready = true
	player.get_tree().create_timer(duration).timeout.connect(
		func():
			if is_instance_valid(player):
				player.baldur_revive_ready = false
	)

	print("[БлагословениеБальдра] Защита на ", duration, " сек: урон x", 1.0 - damage_reduction, " + воскрешение")
