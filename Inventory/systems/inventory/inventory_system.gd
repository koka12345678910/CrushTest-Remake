# res://systems/inventory/inventory_system.gd
class_name InventorySystem
extends Node

## Хранилище предметов игрока и ЕДИНСТВЕННЫЙ источник правды по их количеству.
##
## Раньше счётчики жили в inventory_ui (_item_counts) и были чисто визуальными:
## UI рисовал "x3", а способность из быстрого слота можно было жать бесконечно —
## никто не списывал заряды. Теперь количество хранится здесь, а быстрый слот
## (AbilitySystem) списывает заряд при каждом применении. Когда заряды кончились,
## предмет исчезает и из сумки, и из быстрого доступа.

signal item_added(item: Resource)
signal item_removed(item: Resource)
# Отдельный сигнал на изменение количества: item_added/item_removed бьют только
# на появление/исчезновение самого предмета, а HUD должен обновлять цифру
# зарядов и когда предмет остался, но его стало меньше
signal count_changed(item_name: String, count: int)

var _items: Array[Resource] = []
# ability_name -> сколько штук осталось
var _counts: Dictionary = {}


func add_item(item: Resource, amount: int = 1) -> void:
	var key := _key_of(item)
	# Повторная покупка того же предмета не плодит новый слот в сетке —
	# увеличивается счётчик уже лежащего там стака
	if _counts.has(key):
		_counts[key] += amount
		emit_signal("count_changed", key, _counts[key])
		return
	_items.append(item)
	_counts[key] = amount
	emit_signal("item_added", item)
	emit_signal("count_changed", key, amount)


func remove_item(item: Resource) -> bool:
	var idx := _items.find(item)
	if idx == -1:
		return false
	var key := _key_of(item)
	_items.remove_at(idx)
	_counts.erase(key)
	emit_signal("count_changed", key, 0)
	emit_signal("item_removed", item)
	return true


## Списать заряд(ы). Возвращает false, если списывать нечего — вызывающая
## сторона по этому ответу решает, давать применить способность или нет
func consume(item_name: String, amount: int = 1) -> bool:
	var left: int = _counts.get(item_name, 0)
	if left < amount:
		return false
	left -= amount
	_counts[item_name] = left
	emit_signal("count_changed", item_name, left)
	if left <= 0:
		_remove_by_name(item_name)
	return true


func get_count(item_name: String) -> int:
	return _counts.get(item_name, 0)


func has_charges(item_name: String) -> bool:
	return get_count(item_name) > 0


func has_item(item: Resource) -> bool:
	return _items.has(item)


func get_all() -> Array[Resource]:
	return _items.duplicate()


func _remove_by_name(item_name: String) -> void:
	for i in _items.size():
		if _key_of(_items[i]) == item_name:
			var item := _items[i]
			_items.remove_at(i)
			_counts.erase(item_name)
			emit_signal("item_removed", item)
			return


# Ключ стака — имя способности, а не сам ресурс: AbilitySystem кладёт в слот
# duplicate() способности, и по ссылке предмет из сумки с ним уже не совпадёт
func _key_of(item: Resource) -> String:
	var ab := item as Ability
	if ab:
		return ab.ability_name
	return item.resource_path
