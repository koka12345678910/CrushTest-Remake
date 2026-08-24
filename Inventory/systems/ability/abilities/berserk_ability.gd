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
			"ranged_attacks": true,
			"free_stamina": true
		})

	# Подмена VFX ударов
	if "berserk_hit_vfx_scene" in player:
		player.active_hit_vfx_override = player.berserk_hit_vfx_scene
	player.active_ability_name = "berserk"

	# Экранный эффект "безумия" (чёрно-белый контраст с красным оттенком)
	var vision := player.get_node_or_null("Camera2D/CanvasLayer/BerserkVision")
	if vision:
		vision.activate()

	# Подсветка врагов + слом их защиты (без блока/парирования/контратаки, стаггер с первого удара)
	var enemies := player.get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("set_berserk_highlight"):
			enemy.set_berserk_highlight(true)
		if enemy.has_method("set_berserk_vulnerable"):
			enemy.set_berserk_vulnerable(true)

	# Снимаем эффект через duration секунд
	player.get_tree().create_timer(duration).timeout.connect(
		func():
			player.active_hit_vfx_override = null
			if vision:
				vision.deactivate()
			for enemy in player.get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(enemy):
					if enemy.has_method("set_berserk_highlight"):
						enemy.set_berserk_highlight(false)
					if enemy.has_method("set_berserk_vulnerable"):
						enemy.set_berserk_vulnerable(false)
			print("[БезумиеБерсерка] Эффект закончился")
	)

	print("[БезумиеБерсерка] Активировано! HP срезано, сила x2 на ", duration, " сек")
