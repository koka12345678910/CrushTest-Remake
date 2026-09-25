# res://systems/ability/ability.gd
class_name Ability
extends Resource

@export var ability_name: String = "Unnamed"
@export var icon: Texture2D
@export var cooldown_duration: float = 1.0
@export var description: String = ""
## Строка типа в карточке инвентаря ("Боевой навык", "Талисман" ...). Пусто —
## по-старому "Расходуемое" (все предметы рыцаря)
@export var item_type: String = ""
## Сколько штук можно держать в сумке. 0 — берётся из старой таблицы
## inventory_ui._get_max_count (предметы рыцаря)
@export var max_count: int = 0
## Пассивный предмет (талисманы лучницы): действует, пока лежит в сумке, в
## быстрый слот не кладётся и не тратится
@export var is_passive: bool = false

var _cooldown_timer: float = 0.0


func is_ready() -> bool:
	return _cooldown_timer <= 0.0


func get_cooldown_progress() -> float:
	if cooldown_duration <= 0.0:
		return 1.0
	return 1.0 - (_cooldown_timer / cooldown_duration)


func use(player: Node) -> bool:
	if not is_ready():
		return false
	_cooldown_timer = cooldown_duration
	_execute(player)
	return true


# Override in subclasses
func _execute(_player: Node) -> void:
	pass


func tick(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func reset_cooldown() -> void:
	_cooldown_timer = 0.0
