# res://systems/ability/ability_system.gd
class_name AbilitySystem
extends Node

signal slot_changed(index: int, ability: Ability)
signal ability_used(ability: Ability)
signal cooldown_updated(index: int, progress: float)

var abilities: Array[Ability] = []
var current_index: int = 0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	for i in abilities.size():
		abilities[i].tick(delta)
		emit_signal("cooldown_updated", i, abilities[i].get_cooldown_progress())


func add_ability(ability: Ability) -> void:
	# Duplicate so each player has its own cooldown state
	var a := ability.duplicate() as Ability
	abilities.append(a)
	emit_signal("slot_changed", abilities.size() - 1, a)


func remove_ability(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	abilities.remove_at(index)
	current_index = clamp(current_index, 0, max(abilities.size() - 1, 0))
	emit_signal("slot_changed", current_index, get_current_ability())


func next_slot() -> void:
	if abilities.is_empty():
		return
	current_index = (current_index + 1) % abilities.size()
	emit_signal("slot_changed", current_index, get_current_ability())


func prev_slot() -> void:
	if abilities.is_empty():
		return
	current_index = (current_index - 1 + abilities.size()) % abilities.size()
	emit_signal("slot_changed", current_index, get_current_ability())


func use_current(player: Node) -> void:
	var ability := get_current_ability()
	if ability == null:
		return
	if ability.use(player):
		emit_signal("ability_used", ability)


func get_current_ability() -> Ability:
	if abilities.is_empty() or current_index >= abilities.size():
		return null
	return abilities[current_index]
