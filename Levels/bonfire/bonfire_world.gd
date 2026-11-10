extends Node
## bonfire_world.gd — «мир возрождается» у костра, как в Dark Souls 3.
##
## Один узел на уровень (BonfireWorld, создаёт первый костёр через of()).
## Запоминает каждого врага уровня в момент его появления — сцену, место и
## настройки охраны (дом, поводок, паузы бродилки у охраны лута) — и по
## reset() возвращает ВСЕХ: живые и мёртвые убираются, на исходных местах
## встают свежие копии. Это работает для всех источников врагов разом:
## расставленных в сцене, охраны лута (loot_item.gd) и спавнера.
##
## Запись — по сигналу node_added (новые враги) и одним проходом по уже
## стоящим. Значения читаются отложенно: спавнер и лут ставят позицию и
## поля сразу ПОСЛЕ add_child, а node_added приходит внутри него.

## Поля врага, которые его создатель мог выставить при постановке (охрана
## лута держится у находки) — их копируем новой копии
const KEEP_PROPS := ["home_position", "_home_set", "patrol_leash_radius",
	"wander_step_min", "wander_step_max", "wander_pause_min", "wander_pause_max"]

## [{scene, parent, pos, props}]
var roster: Array[Dictionary] = []
var _respawning := false


static func of(tree: SceneTree, level: Node) -> Node:
	var w := level.get_node_or_null("BonfireWorld")
	if w == null:
		w = load("res://Levels/bonfire/bonfire_world.gd").new()
		w.name = "BonfireWorld"
		level.add_child.call_deferred(w)
	return w


func _ready() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		_record.call_deferred(e)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if _respawning:
		return
	# Корень врага — всегда экземпляр сцены (есть scene_file_path); дочерние узлы,
	# частицы, снаряды и т.п. отсекаем сразу, не ставя их в очередь
	if n.scene_file_path == "" or not (n is Node2D):
		return
	# Группу "enemy" враг получает в своём _ready — к отложенной проверке она уже есть
	_record.call_deferred(n)


# Аргумент без типа: к моменту отложенного вызова узел мог быть уже освобождён,
# а освобождённый объект не приводится к Node («Cannot convert argument 1 from Object to Object»)
func _record(n) -> void:
	if not is_instance_valid(n) or not n.is_in_group("enemy") or n.has_meta("roster_id"):
		return
	# Без файла сцены воссоздать нечем (мини-босс-заглушка и т.п.)
	if n.scene_file_path == "" or not (n is Node2D) or n.get_parent() == null:
		return
	var props := {}
	for k in KEEP_PROPS:
		if k in n:
			props[k] = n.get(k)
	n.set_meta("roster_id", roster.size())
	roster.append({
		"scene": n.scene_file_path,
		"parent": get_path_to(n.get_parent()),
		"pos": (n as Node2D).global_position,
		"props": props,
	})


## Все враги уровня — на исходные места, живыми. Старые (живые и трупы)
## убираются сразу из группы "enemy", чтобы фокус, музыка боя и спавнер
## перестали их видеть ещё до queue_free
func reset() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_meta("roster_id"):
			e.remove_from_group("enemy")
			e.queue_free()
	_respawning = true
	for i in roster.size():
		var rec: Dictionary = roster[i]
		var parent := get_node_or_null(rec["parent"])
		var scene := load(rec["scene"]) as PackedScene
		if parent == null or scene == null:
			continue
		var e: Node2D = scene.instantiate()
		e.set_meta("roster_id", i)
		for k in rec["props"]:
			e.set(k, rec["props"][k])
		parent.add_child(e)
		e.global_position = rec["pos"]
	_respawning = false
