extends "res://Inventory/systems/ability/abilities/mage/mage_talisman.gd"
## Кольцо Драупнир — каждая душа приносит на 30% больше (mage.gd::add_souls)

const NAME := "Кольцо Драупнир"


func _init() -> void:
	_setup(NAME, "Каждая собранная душа приносит\nна 30% больше.",
			"res://UI/icons_for_mage/draupnir_ring.png", Color(0.95, 0.75, 0.35))
