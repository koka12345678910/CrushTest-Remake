# res://systems/inventory/inventory_system.gd
class_name InventorySystem
extends Node

signal item_added(item: Resource)
signal item_removed(item: Resource)

var _items: Array[Resource] = []


func add_item(item: Resource) -> void:
	_items.append(item)
	emit_signal("item_added", item)


func remove_item(item: Resource) -> bool:
	var idx := _items.find(item)
	if idx == -1:
		return false
	_items.remove_at(idx)
	emit_signal("item_removed", item)
	return true


func has_item(item: Resource) -> bool:
	return _items.has(item)


func get_all() -> Array[Resource]:
	return _items.duplicate()
