extends Node
## focus_system.gd — фокус (лок-он) на враге. Общий для всех персонажей.
##
## Вешается кодом как ребёнок персонажа: FocusSystemScript.new() + add_child().
## Отдельных нод в .tscn заводить не надо, поэтому подключить фокус новому
## герою — две строки в его _ready().
##
## Родитель обязан быть Node2D — от него берётся позиция для поиска врагов.
##
## Компонент отвечает ТОЛЬКО за саму цель и метку на экране. Куда персонаж
## при этом смотрит и какую анимацию играет — дело самого персонажа: у рыцаря
## взгляд завязан на turn_lock и анимации разворота, у лучника с магом нет ни
## того, ни другого, и тащить это в общий код было бы враньём.

const FocusMarkerScript := preload("res://VFX/VFX_scene/focus_marker.gd")

## Радиус, в котором ищется цель при взятии в фокус
@export var snap_radius := 80.0
## Дальше этого расстояния фокус слетает сам
@export var break_range := 260.0
## Метку приподнимаем к центру врага, а не к его ногам
@export var marker_offset := Vector2(0, -24)
## Действие из Input Map, переключающее фокус
@export var action_name := "focus_target"

## Текущая цель. Только чтение — менять через set_target()/clear()
var target: Node2D = null

var _body: Node2D
var _marker: Node2D


func _ready() -> void:
	_body = get_parent() as Node2D
	if _body == null:
		push_error("[FocusSystem] Родитель должен быть Node2D, а не %s" % get_parent())


# Слежение живёт в _process, а не в ветке движения персонажа: та пропускается
# ранними return во время атаки/доджа/блока — а именно тогда враг чаще всего и
# отлетает от удара, так что метка замирала бы ровно в нужный момент
func _process(_delta: float) -> void:
	if _body == null:
		return

	if is_instance_valid(target) and target.is_dead:
		# Игрок сам фокус не снимал — раз держал его на этом враге, скорее
		# всего бой продолжается, поэтому цель перескакивает на ближайшего
		# живого рядом, а не просто гаснет
		set_target(get_nearest_enemy())

	if not is_instance_valid(target):
		return

	if _body.global_position.distance_to(target.global_position) > break_range:
		clear()
		return

	if is_instance_valid(_marker):
		_marker.global_position = target.global_position + marker_offset


## Персонаж зовёт это там, где ему удобно — обычно из _physics_process ПОСЛЕ
## своих проверок (магазин, стан, открытый инвентарь). Специально не читаем
## ввод сами в _process: тогда фокус переключался бы и при открытом инвентаре
func poll_input() -> void:
	if not Input.is_action_just_pressed(action_name):
		return
	# Держим кого-то живого — отпускаем; иначе берём ближайшего
	if is_instance_valid(target) and not target.is_dead:
		clear()
		return
	set_target(get_nearest_enemy())


## Единственное место, которое создаёт/убирает метку — так она не может
## разъехаться с реальной целью ни в одном из путей снятия фокуса
func set_target(enemy: Node2D) -> void:
	target = enemy
	if is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null
	if enemy == null:
		return
	_marker = FocusMarkerScript.new()
	# Метка живёт в сцене уровня, а не на самом враге: враг после смерти
	# доигрывает fade и удаляется, метка не должна уезжать вместе с ним
	get_tree().current_scene.add_child(_marker)
	_marker.global_position = enemy.global_position + marker_offset


func clear() -> void:
	set_target(null)


func has_target() -> bool:
	return is_instance_valid(target)


func get_nearest_enemy() -> Node2D:
	if _body == null:
		return null
	var nearest: Node2D = null
	var nearest_dist := snap_radius
	for enemy in get_tree().get_nodes_in_group("enemy"):
		# Враг доигрывает fade ещё death_fade_time секунд после смерти, всё ещё
		# числясь в группе — без этой проверки фокус цепляется за труп вместо
		# переключения на живого
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dist: float = _body.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


## Единичный вектор от персонажа к цели. ZERO — цели нет или она вплотную
func direction_to_target() -> Vector2:
	if not has_target() or _body == null:
		return Vector2.ZERO
	var to_target: Vector2 = target.global_position - _body.global_position
	if to_target.length() < 0.01:
		return Vector2.ZERO
	return to_target.normalized()


## Бег НАПРЯМУЮ от цели — особый случай: убегать с намертво повёрнутой на
## врага головой выглядит нелепо, а не как побег. Персонаж на этот кадр
## отпускает взгляд и ведёт себя как обычно. Ходьбы назад это не касается:
## там взгляд держит фокус, а корпус идёт спиной вперёд
func is_fleeing(input_vector: Vector2, running: bool) -> bool:
	if not has_target() or not running or input_vector == Vector2.ZERO:
		return false
	var to_target := direction_to_target()
	if to_target == Vector2.ZERO:
		return false
	return input_vector.normalized().dot(to_target) < -0.5
