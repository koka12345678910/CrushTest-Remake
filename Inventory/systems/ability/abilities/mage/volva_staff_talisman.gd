extends "res://Inventory/systems/ability/abilities/mage/mage_talisman.gd"
## Гандр вёльвы — заклинания стоят на 20% меньше Сейда (mage.gd::_spell_cost)

const NAME := "Гандр вёльвы"


func _init() -> void:
	_setup(NAME, "Все заклинания стоят на 20% меньше Сейда.",
			"res://UI/icons_for_mage/volva_staff.png", Color(0.7, 0.55, 1.0))
