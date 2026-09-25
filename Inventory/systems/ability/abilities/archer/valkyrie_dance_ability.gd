class_name ValkyrieDanceAbility
extends ArcherAbility
## Танец Валькирии — на время действия каждый перекат заряжает следующий
## выстрел: он гарантированно критический

func _init() -> void:
	ability_name = "Танец Валькирии"
	item_type = "Боевой навык"
	skill_id = "valkyrie_dance"
	cooldown_duration = 15.0
	max_count = 3
	duration = 12.0
	description = "12 сек: после каждого переката следующий выстрел\nусилен — он всегда критический."
	icon = load("res://UI/icons_for_sigrid/valkyrie_dance.png")
