extends RefCounted
## invisible_collision.gd — убрать невидимые упоры reference_map.
##
## Список (reference_map_level/invisible_collision.json) печёт
## tools/collision_audit.gd: мелкие прямоугольники коллизии, над которыми
## ничего не нарисовано и у которых рядом нет основания ни одного предмета —
## остатки деревьев и предметов, убранных при прореживании леса и чистке
## деревни. Список проверен глазами (что оставлено — KEEP в инструменте).
##
## Применяется дважды, одинаково:
##   - в игре: Immersion -> breakables.gd (после _ready коллизии — с физикой);
##   - при запекании навмеша: tools/bake_navmesh.gd (до _ready — только список),
##     чтобы враги не обходили пустые места.
## Сцена на диске не меняется.

const LIST := "res://reference_map_level/invisible_collision.json"


## Возвращает, сколько прямоугольников убрано
static func apply(map: Node) -> int:
	if not FileAccess.file_exists(LIST):
		return 0
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	if not list is Array:
		return 0
	var by_body := {}
	for e in list:
		var path := str(e[4])
		if not by_body.has(path):
			by_body[path] = []
		by_body[path].append(Rect2(Vector2(e[0], e[1]), Vector2(e[2], e[3])))
	var n := 0
	for path in by_body:
		var body := map.get_node_or_null(NodePath(path)) as CollisionObject2D
		if body == null or not "shapes" in body:
			continue
		n += _remove(body, by_body[path])
	return n


## rects: центр в position, размер в size (мировые координаты)
static func _remove(body: CollisionObject2D, rects: Array) -> int:
	var shapes: Array = body.get("shapes")
	var trs: Array = body.get("shape_transforms")
	# Тело может быть ещё не в дереве (запекание навмеша): трансформ — цепочкой
	# от корня карты (лагерь сдвинут внутри Objects)
	var gt := Transform2D.IDENTITY
	if body.is_inside_tree():
		gt = body.global_transform
	else:
		var n: Node = body
		while n != null:
			if n is Node2D:
				gt = (n as Node2D).transform * gt
			n = n.get_parent()
	var kill: Array[int] = []
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		if s == null:
			continue
		var t: Transform2D = gt * (trs[i] as Transform2D)
		var size := s.size * t.get_scale().abs()
		for r in rects:
			if t.origin.distance_to((r as Rect2).position) < 1.0 and size.distance_to((r as Rect2).size) < 1.0:
				kill.append(i)
				break
	kill.reverse()
	for i in kill:
		# Владелец фигуры в физике — по самой фигуре и трансформу (номера
		# заняты ещё и полигонами воды; до _ready владельцев нет вовсе)
		for id in body.get_shape_owners():
			if body.shape_owner_get_owner(id) != body or body.shape_owner_get_shape_count(id) == 0:
				continue
			if body.shape_owner_get_shape(id, 0) == shapes[i] and body.shape_owner_get_transform(id).is_equal_approx(trs[i]):
				body.remove_shape_owner(id)
				break
		shapes.remove_at(i)
		trs.remove_at(i)
	body.set("shapes", shapes)
	body.set("shape_transforms", trs)
	return kill.size()
