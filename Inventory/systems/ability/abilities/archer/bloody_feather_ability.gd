class_name BloodyFeatherAbility
extends ArcherAbility
## Кровавое Перо — на время действия криты вешают кровотечение

func _init() -> void:
	ability_name = "Кровавое Перо"
	item_type = "Боевой навык"
	skill_id = "bloody_feather"
	cooldown_duration = 20.0
	max_count = 3
	duration = 20.0
	description = "20 сек: критическое попадание накладывает\nкровотечение — 3 урона за 3 секунды."
	icon = load("res://UI/icons_for_sigrid/bloody_feather.png")
