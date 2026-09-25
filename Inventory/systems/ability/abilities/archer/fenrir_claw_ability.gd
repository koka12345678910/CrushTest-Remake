class_name FenrirClawAbility
extends ArcherAbility
## Коготь Фенрира — следующие стрелы пробивают первого врага насквозь

func _init() -> void:
	ability_name = "Коготь Фенрира"
	item_type = "Боевой навык"
	skill_id = "fenrir_claw"
	cooldown_duration = 8.0
	max_count = 3
	shots = 3
	description = "Следующие 3 стрелы пробивают первого врага\nи поражают того, кто стоит за ним."
	icon = load("res://UI/icons_for_sigrid/fenrir's_claw.png")
