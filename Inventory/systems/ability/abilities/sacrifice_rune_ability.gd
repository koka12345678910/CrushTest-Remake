# res://systems/ability/abilities/sacrifice_rune_ability.gd
class_name SacrificeRuneAbility
extends Ability

# Кровавый договор: жертвуешь часть текущего HP — и мгновенно сбрасываешь
# кулдауны всех остальных способностей. Комбо-энаблер: позволяет сцеплять
# абилки в цепочки ценой собственной крови.
@export var hp_cost_percent: float = 0.3   # доля ТЕКУЩЕГО HP в жертву (не убивает)
@export var blood_count: int = 3           # сколько брызг крови на игроке

const BLOOD_VFX := preload("res://VFX/VFX_scene/blood_vfx.tscn")

func _init() -> void:
	ability_name = "Руна Жертвы"
	cooldown_duration = 25.0
	description = "Жертвуешь часть HP и сбрасываешь кулдауны всех остальных способностей"
	icon = load("res://Shop/icons/potion_blood.png")

func _execute(player: Node) -> void:
	# Кровавая жертва — часть текущего HP (никогда не добивает игрока).
	# take_damage проигрывает анимацию Take_Damage_ и даёт красный флеш.
	var cost := int(player.health * hp_cost_percent)
	if cost > 0 and player.has_method("take_damage"):
		player.take_damage(cost)

	# Брызги крови на игроке
	_spawn_blood(player)

	# Сброс кулдаунов всех остальных способностей (кроме самой Руны)
	var ab_system = player.get("ability_system")
	if ab_system and ab_system.has_method("reset_all_cooldowns"):
		ab_system.reset_all_cooldowns(self)

	print("[РунаЖертвы] Пожертвовано ", cost, " HP — кулдауны сброшены")

func _spawn_blood(player: Node) -> void:
	for i in blood_count:
		var blood := BLOOD_VFX.instantiate()
		player.add_child(blood)
		# разброс по телу игрока (локальные координаты)
		blood.position = Vector2(randf_range(-14.0, 14.0), randf_range(-20.0, 6.0))
