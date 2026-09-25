class_name LastLookAbility
extends ArcherAbility
## Последний взор — временное состояние "опасной охотницы": стрельба быстрее,
## стрелы доворачивают в цель, урон и шанс крита выше

func _init() -> void:
	ability_name = "Последний взор"
	item_type = "Временная способность"
	skill_id = "last_look"
	cooldown_duration = 35.0
	max_count = 2
	duration = 8.0
	activation_sound = SOUND_EYE
	description = "8 сек: стрельба вдвое быстрее, стрелы доворачивают\nв цель, +1 урона и +15% шанса крита."
	icon = load("res://UI/icons_for_sigrid/last_look.png")
