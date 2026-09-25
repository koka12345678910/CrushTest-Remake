class_name OdinWhisperAbility
extends ArcherAbility
## Шёпот Одина — следующие стрелы проходят сквозь стены и препятствия

func _init() -> void:
	ability_name = "Шёпот Одина"
	item_type = "Боевой навык"
	skill_id = "odin_whisper"
	cooldown_duration = 8.0
	max_count = 3
	shots = 3
	activation_sound = SOUND_EYE
	description = "Следующие 3 стрелы проходят сквозь препятствия\nи поражают врага за ними."
	icon = load("res://UI/icons_for_sigrid/odin's_whisper.png")
