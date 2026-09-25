class_name HuntressPathAbility
extends ArcherAbility
## Путь охотницы — одна цель становится добычей, каждое следующее попадание
## по ней бьёт сильнее

func _init() -> void:
	ability_name = "Путь охотницы"
	item_type = "Временная способность"
	skill_id = "huntress_path"
	cooldown_duration = 30.0
	max_count = 2
	duration = 12.0
	description = "12 сек: цель в фокусе (или первая поражённая)\nстановится добычей. Каждое попадание по ней\nусиливает следующее — до +2 урона."
	icon = load("res://UI/icons_for_sigrid/path_of_the_huntress.png")
