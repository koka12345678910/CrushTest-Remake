class_name HuginnFeatherAbility
extends ArcherAbility
## Перо Хугина — пассивный талисман: попадания ненадолго метят врага, стрелы
## сами выбирают помеченных и дальше видят их

func _init() -> void:
	ability_name = "Перо Хугина"
	item_type = "Талисман  •  пассивный"
	is_passive = true
	max_count = 1
	cooldown_duration = 0.0
	description = "Каждое попадание метит врага на 5 сек. Лук\nсам наводится на помеченных, даже издалека.\nДобыча Пути охотницы под меткой копит силу вдвое быстрее."
	icon = load("res://UI/icons_for_sigrid/odin's_raven.png")
