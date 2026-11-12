extends Node
## Далёкие враги спят.
##
## Каждый скелет каждый кадр думает, ищет путь и двигается сквозь сотни
## препятствий — на reference_map 28 врагов съедали ~4.5 мс физики на
## каждом тике, даже на другом краю карты. Здесь враг дальше sleep_distance
## от всех героев (свой и кооп-куклы на хосте) замирает целиком
## (PROCESS_MODE_DISABLED: ни логики, ни физики, ни анимации) и просыпается,
## когда герой подходит ближе wake_distance. С экрана (~440 px от героя до
## края) спящего не видно: будится он заранее, за пару экранов.
##
## Копии врагов у клиента (net_replica) не трогаются — их ведёт хост.
## Мёртвые тоже: им надо доиграть смерть.

@export var sleep_distance := 1500.0
@export var wake_distance := 1250.0
## Как часто проверять, с
@export var interval := 0.25

var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = interval
	var tree := get_tree()
	var heroes: Array[Vector2] = []
	for g in ["player", "net_puppet"]:
		for h in tree.get_nodes_in_group(g):
			if h is Node2D and is_instance_valid(h):
				heroes.append((h as Node2D).global_position)
	if heroes.is_empty():
		return
	var sleep2 := sleep_distance * sleep_distance
	var wake2 := wake_distance * wake_distance
	for e in tree.get_nodes_in_group("enemy"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		if e.get("net_replica") == true:
			continue
		var asleep: bool = e.process_mode == Node.PROCESS_MODE_DISABLED
		if e.get("is_dead") == true:
			if asleep:
				e.process_mode = Node.PROCESS_MODE_INHERIT
			continue
		var d2 := INF
		var p: Vector2 = (e as Node2D).global_position
		for h in heroes:
			d2 = minf(d2, p.distance_squared_to(h))
		if asleep and d2 < wake2:
			e.process_mode = Node.PROCESS_MODE_INHERIT
		elif not asleep and d2 > sleep2:
			e.process_mode = Node.PROCESS_MODE_DISABLED
