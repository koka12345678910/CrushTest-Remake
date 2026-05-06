# res://systems/ability/abilities/odin_eye_ability.gd
class_name OdinEyeAbility
extends Ability

@export var slow_duration: float = 2.0
@export var slow_factor: float = 0.15      # время замедляется до 15%
@export var max_targets: int = 3           # максимум целей для пометки

func _init() -> void:
	ability_name = "Глаз Одина"
	cooldown_duration = 40.0
	description = "Замедляет время — пометь врагов для мгновенной казни"
	icon = load("res://Shop/icons/eye_amulet.png")

func _execute(player: Node) -> void:
	if player.has_method("activate_odin_eye"):
		player.activate_odin_eye(slow_duration, slow_factor, max_targets)
	else:
		_slow_time_stub(player)

func _slow_time_stub(player: Node) -> void:
	# Заглушка — замедляем Engine.time_scale
	Engine.time_scale = slow_factor
	print("[ГлазОдина] Время замедлено до ", slow_factor * 100, "%")

	# Восстанавливаем через slow_duration реального времени
	# (используем SceneTree timer который НЕ зависит от time_scale)
	player.get_tree().create_timer(slow_duration, true, false, true).timeout.connect(
		func():
			Engine.time_scale = 1.0
			print("[ГлазОдина] Время восстановлено")
	)

	# TODO: когда появятся враги:
	# 1. Показать UI для выбора целей (подсветка врагов в радиусе)
	# 2. По нажатию attack — помечать врага (до max_targets штук)
	# 3. При окончании замедления — мгновенно убить всех помеченных
