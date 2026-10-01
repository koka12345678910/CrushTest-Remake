class_name TalismanSystem
extends Node
## talisman_system.gd — до 4 пассивных талисманов, экипированных героем.
##
## В отличие от AbilitySystem (быстрый слот): тут нет кулдаунов и расхода
## зарядов — слот либо занят талисманом (его эффект действует), либо пуст.
## Талисман не покидает сумку и не тратится (Ability.is_passive == true,
## InventorySystem его не consume()'ит) — здесь просто ссылка на тот же
## Ability-ресурс, что лежит в сумке, отмечающая "этот экипирован".
##
## Владелец эффекта (archer.gd, в будущем player.gd) спрашивает
## has_talisman(name), а не считает предмет в сумке — если игрок снимет
## талисман, эффект обязан пропасть, даже если сам предмет остался лежать.

signal slot_changed(index: int, talisman: Ability)

const MAX_SLOTS := 4

var slots: Array = [null, null, null, null]


func equip(index: int, talisman: Ability) -> bool:
	if index < 0 or index >= MAX_SLOTS or talisman == null:
		return false
	slots[index] = talisman
	slot_changed.emit(index, talisman)
	return true


func unequip(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS or slots[index] == null:
		return
	slots[index] = null
	slot_changed.emit(index, null)


## Убирает талисман по имени, в каком бы слоте он ни лежал — используется,
## когда сам предмет пропадает из сумки (на будущее, если талисманы станут
## расходоваться) и переключателем в UI
func unequip_by_name(talisman_name: String) -> void:
	var idx := find_slot(talisman_name)
	if idx != -1:
		unequip(idx)


func find_slot(talisman_name: String) -> int:
	for i in slots.size():
		var t: Ability = slots[i]
		if t != null and t.ability_name == talisman_name:
			return i
	return -1


func has_talisman(talisman_name: String) -> bool:
	return find_slot(talisman_name) != -1


func find_empty_slot() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


func is_full() -> bool:
	return find_empty_slot() == -1


func get_equipped() -> Array[Ability]:
	var out: Array[Ability] = []
	for t in slots:
		if t != null:
			out.append(t)
	return out
