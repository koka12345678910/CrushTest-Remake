# res://systems/ability/abilities/valkyrie_song_ability.gd
class_name ValkyrieSongAbility
extends Ability

@export var heal_per_tick: float = 6.0
@export var tick_interval: float = 0.5
@export var total_ticks: int = 6

func _init() -> void:
	ability_name = "Песнь Валькирии"
	cooldown_duration = 15.0
	description = "Постепенно лечит и снимает все негативные эффекты"
	icon = load("res://Shop/icons/flask_gold.png")

func _execute(player: Node) -> void:
	# Снимаем негативные эффекты
	if player.has_method("clear_negative_effects"):
		player.clear_negative_effects()
	# TODO: когда появятся статусы — раскомментировать:
	# player.remove_status("poison")
	# player.remove_status("bleed")
	# player.remove_status("slow")

	# Постепенное лечение
	player.start_heal_over_time(heal_per_tick, tick_interval, total_ticks)
	print("[ВалькирияСонг] Снял негативные эффекты и начал лечение")
