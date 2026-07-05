# res://systems/ability/abilities/odin_eye_ability.gd
class_name OdinEyeAbility
extends Ability

@export var slow_duration: float = 2.5     # длительность замедления (реальные сек)
@export var slow_factor: float = 0.2       # время замедляется до 20%
@export var max_targets: int = 3           # сколько врагов помечается на казнь
@export var mark_radius: float = 320.0     # радиус пометки вокруг игрока

func _init() -> void:
	ability_name = "Глаз Одина"
	cooldown_duration = 40.0
	description = "Замедляет время и метит ближайших врагов на мгновенную казнь"
	icon = load("res://Shop/icons/eye_amulet.png")

func _execute(player: Node) -> void:
	# Помечаем до max_targets ближайших живых врагов в радиусе
	var marked := _pick_targets(player)
	for e in marked:
		if e.has_method("set_berserk_highlight"):
			e.set_berserk_highlight(true)   # подсветка как «взгляд Одина»

	# Экранный эффект: вспышка + голубоватый тон
	var vision := player.get_node_or_null("Camera2D/CanvasLayer/OdinVision")
	if vision:
		vision.activate()

	# Замедляем время
	Engine.time_scale = slow_factor

	# Таймер в РЕАЛЬНОМ времени (ignore_time_scale = true), не зависит от замедления
	player.get_tree().create_timer(slow_duration, true, false, true).timeout.connect(
		func():
			Engine.time_scale = 1.0
			if vision:
				vision.deactivate()   # картинка возвращается в исходное состояние
			for e in marked:
				if is_instance_valid(e):
					if e.has_method("set_berserk_highlight"):
						e.set_berserk_highlight(false)
					if e.has_method("execute_kill"):
						e.execute_kill()
			print("[ГлазОдина] Казнь помеченных: ", marked.size())
	)

	print("[ГлазОдина] Время замедлено, помечено врагов: ", marked.size())

func _pick_targets(player: Node) -> Array:
	var candidates := []
	for e in player.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		if player.global_position.distance_to(e.global_position) <= mark_radius:
			candidates.append(e)
	# ближайшие первыми
	candidates.sort_custom(func(a, b):
		return player.global_position.distance_to(a.global_position) < player.global_position.distance_to(b.global_position)
	)
	return candidates.slice(0, max_targets)
