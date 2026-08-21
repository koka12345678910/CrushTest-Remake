# res://systems/ability/ability_system.gd
class_name AbilitySystem
extends Node

signal slot_changed(index: int, ability: Ability)
signal ability_used(ability: Ability)
signal cooldown_updated(index: int, progress: float)
# Отдельный сигнал именно для МАССОВОГО сброса (Руна Жертвы и подобное) — в
# отличие от cooldown_updated, который стреляет каждый кадр на каждую
# способность, этот бьёт один раз на само событие. UI подписывается на него,
# чтобы дать заметную отдачу ("кулдауны сброшены!"), не путаясь в потоке
# обычных обновлений прогресс-бара
signal cooldowns_reset
# Предмет кончился прямо в руках — заряды на нуле, слот освобождается. UI ловит
# это, чтобы показать игроку, почему способность вдруг пропала из быстрого слота
signal ability_depleted(ability: Ability)
# Попытка положить в быстрый доступ четвёртый предмет
signal slots_full

# Быстрый доступ ограничен тремя предметами: колесо переключения слотов должно
# оставаться быстрым, а не превращаться в прокрутку всей сумки
const MAX_SLOTS := 3

var abilities: Array[Ability] = []
var current_index: int = 0

# Способности — Resource (RefCounted), не Node. Держим здесь ссылку, пока их
# (возможно асинхронный) _execute() не доиграет — см. use_current()
var _pending_execution: Array[Ability] = []

# Сумка, из которой списываются заряды. Проставляется снаружи (player.gd) —
# система способностей сама её не ищет, чтобы оставаться пригодной для любого
# владельца (игрок, будущие NPC), у кого своя сумка
var inventory: InventorySystem = null


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	for i in abilities.size():
		abilities[i].tick(delta)
		emit_signal("cooldown_updated", i, abilities[i].get_cooldown_progress())


func add_ability(ability: Ability) -> bool:
	if abilities.size() >= MAX_SLOTS:
		emit_signal("slots_full")
		return false
	# Duplicate so each player has its own cooldown state
	var a := ability.duplicate() as Ability
	abilities.append(a)
	emit_signal("slot_changed", abilities.size() - 1, a)
	return true


func has_ability(ability_name: String) -> bool:
	return find_slot(ability_name) != -1


func find_slot(ability_name: String) -> int:
	for i in abilities.size():
		if abilities[i].ability_name == ability_name:
			return i
	return -1


func is_full() -> bool:
	return abilities.size() >= MAX_SLOTS


## Сколько применений осталось у способности в слоте. Без сумки — считаем
## предмет "не отслеживаемым" и возвращаем 0
func get_charges(ability: Ability) -> int:
	if ability == null or inventory == null:
		return 0
	return inventory.get_count(ability.ability_name)


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
	# Проверяем заряды ДО ability.use(): иначе применение уже запустило бы
	# эффект и повесило кулдаун, а списывать было бы нечего
	if inventory != null and not inventory.has_charges(ability.ability_name):
		_drop_depleted(current_index, ability)
		return
	if ability.use(player):
		emit_signal("ability_used", ability)
		# Способность — Resource, а не Node. Многие _execute() асинхронные
		# (например, ждут окончания звука питья) — если это последний заряд,
		# ниже она тут же уйдёт и из сумки, и из abilities[], и единственная
		# оставшаяся ссылка (эта локальная переменная) исчезнет сразу же, как
		# только use_current() вернёт управление. В этот момент Godot волен
		# освободить объект ПРЯМО ПОСРЕДИ его corutine — без единой ошибки в
		# консоли эффект просто обрывается на полуслове, ещё не успев дойти
		# до heal()/start_heal_over_time(). Именно это и превращало Мёд
		# Поэзии и Эликсир Вальгаллы в "не лечит" на последнем заряде — заряд
		# списывается честно, а сам эффект никогда не наступает
		_keep_alive_during_execution(ability)
		if inventory != null:
			inventory.consume(ability.ability_name)
			if not inventory.has_charges(ability.ability_name):
				_drop_depleted(current_index, ability)


# Держит Resource способности живым до тех пор, пока её _execute() не успеет
# гарантированно доиграть, даже если сама способность уже ушла и из сумки, и
# из быстрого слота (см. комментарий в use_current). 5 секунд — с большим
# запасом больше самого долгого _execute() в игре (звук питья ~1-2 сек)
func _keep_alive_during_execution(ability: Ability) -> void:
	_pending_execution.append(ability)
	await get_tree().create_timer(5.0, true, false, true).timeout
	_pending_execution.erase(ability)


# Предмет израсходован — освобождаем слот. Сначала сигнал, потом удаление:
# подписчику нужна сама способность, чтобы показать её иконку/имя в сообщении
func _drop_depleted(index: int, ability: Ability) -> void:
	emit_signal("ability_depleted", ability)
	remove_ability(index)


func get_current_ability() -> Ability:
	if abilities.is_empty() or current_index >= abilities.size():
		return null
	return abilities[current_index]


func reset_all_cooldowns(except: Ability = null) -> void:
	for i in abilities.size():
		if abilities[i] == except:
			continue
		abilities[i].reset_cooldown()
		emit_signal("cooldown_updated", i, abilities[i].get_cooldown_progress())
	emit_signal("cooldowns_reset")
