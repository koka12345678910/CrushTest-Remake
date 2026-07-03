# res://systems/ability/abilities/fenrir_blood_ability.gd
class_name FenrirBloodAbility
extends Ability

@export var duration: float = 15.0
@export var speed_bonus: float = 100.0
@export var damage_multiplier: float = 1.75

func _init() -> void:
	ability_name = "Кровь Фенрира"
	cooldown_duration = 60.0
	description = "Неуязвимость, скорость и сила на 5 секунд"
	icon = load("res://Shop/icons/demon_flask.png")

func _execute(player: Node) -> void:
	# Неуязвимость через существующую систему i-frames
	player.is_invulnerable = true
	player.active_ability_name = "fenrir"  # ← добавь здесь

	# Применяем бафф
	if player.has_method("apply_buff"):
		player.apply_buff({
			"speed_bonus": speed_bonus,
			"damage_multiplier": damage_multiplier,
			"duration": duration,
			"name": "fenrir_blood",
			"invulnerable": true
		})

	# Подмена VFX удара на время действия способности
	if player.has_method("set") and "fenrir_hit_vfx_scene" in player:
		player.active_hit_vfx_override = player.fenrir_hit_vfx_scene

	# Вспышка с силуэтом волка при активации
	var flash_fx := player.get_node_or_null("Camera2D/CanvasLayer/FenrirFlash")
	if flash_fx:
		flash_fx.play()

	# Снимаем неуязвимость и VFX через duration секунд
	player.get_tree().create_timer(duration).timeout.connect(
		func():
			player.is_invulnerable = false
			player.active_hit_vfx_override = null
			print("[КровьФенрира] Эффект закончился")
	)

	print("[КровьФенрира] Активирована! Неуязвимость на ", duration, " сек")
