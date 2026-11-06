extends "res://Inventory/systems/ability/abilities/mage/mage_talisman.gd"
## Глаз Мимира — Сейд восполняется на 50% быстрее (mage.gd::MIMIR_REGEN)

const NAME := "Глаз Мимира"


func _init() -> void:
	_setup(NAME, "Сейд восполняется на 50% быстрее —\nи в бою, и в передышке.",
			"res://UI/icons_for_mage/mimir_eye.png", Color(0.45, 0.7, 1.0))
