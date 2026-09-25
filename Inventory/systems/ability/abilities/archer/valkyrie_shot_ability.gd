class_name ValkyrieShotAbility
extends ArcherAbility
## Выстрел Валькирии — следующий выстрел без натяжения лука: вылетает сразу,
## летит почти вдвое быстрее и бьёт сильнее

func _init() -> void:
	ability_name = "Выстрел Валькирии"
	item_type = "Боевой навык"
	skill_id = "valkyrie_shot"
	cooldown_duration = 5.0
	max_count = 3
	description = "Следующий выстрел срывается с тетивы мгновенно,\nлетит почти вдвое быстрее и наносит +1 урона."
	icon = load("res://UI/icons_for_sigrid/valkyrie's_shot.png")
