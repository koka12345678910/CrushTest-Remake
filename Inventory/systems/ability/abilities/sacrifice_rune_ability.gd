# res://systems/ability/abilities/sacrifice_rune_ability.gd
class_name SacrificeRuneAbility
extends Ability

@export var duration: float = 8.0
@export var damage_bonus: float = 1.5   # множитель урона x1.5
@export var speed_bonus: float = 50.0   # +50 к скорости
@export var hp_drain_per_sec: float = 5.0  # HP в секунду

func _init() -> void:
	ability_name = "Руна Жертвы"
	cooldown_duration = 20.0
	description = "Урон и скорость растут, но HP убывает"
	icon = load("res://Shop/icons/potion_blood.png")

func _execute(player: Node) -> void:
	if player.has_method("apply_buff"):
		player.apply_buff({
			"damage_multiplier": damage_bonus,
			"speed_bonus": speed_bonus,
			"hp_drain_per_sec": hp_drain_per_sec,
			"duration": duration,
			"name": "sacrifice_rune"
		})
	# TODO: когда появится система баффов — подключить apply_buff
	print("[РунаЖертвы] Активирована на ", duration, " сек")
