class_name NornNeedleAbility
extends ArcherAbility
## Игла Норн — пассивный талисман: выше шанс крита по уже раненым врагам

func _init() -> void:
	ability_name = "Игла Норн"
	item_type = "Талисман  •  пассивный"
	is_passive = true
	max_count = 1
	cooldown_duration = 0.0
	description = "+20% шанса критического попадания по врагам,\nкоторых лучница уже поражала."
	icon = load("res://UI/icons_for_sigrid/norn's_needle.png")
