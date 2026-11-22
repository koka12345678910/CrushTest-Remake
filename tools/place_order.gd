extends SceneTree
## place_order.gd — расставляет ОТРЯДЫ Ордена Тёмного Солнца (люди из
## enemy/humans и боевые псы enemy/beasts) на reference_map.
##
##   godot --headless --path . -s res://tools/place_order.gd           — проверить и записать
##   godot --headless --path . -s res://tools/place_order.gd -- dry    — только проверить
##
## Враги стоят отрядами (поведение — enemy/enemy_squads.gd, узел OrderSquads
## у корня карты): стражи (hold) держат проход лицом к герою, часовые-стрелки
## (sentry) стоят на посту и видят дальше, патрули (patrol) ходят строем по
## маршруту. Заметил один — поднимается весь отряд.
##
## Проверка каждой точки на загруженной карте: стоит на навмеше, круг 14 px
## свободен от коллизии мира, есть путь от спавна, не ближе 450 px к костру
## (иначе у костра нельзя отдохнуть). Точку, которая чуть задевает стену,
## инструмент сдвигает к ближайшему свободному месту (до 96 px) и пишет об
## этом; близко к костру — ошибка, ничего не записывается.
##
## Правит .tscn как текст: ссылки на сцены (ext_resource "order_*"), узлы
## Objects/Order_* и узел OrderSquads. Сохранение через PackedScene.pack()
## здесь не годится — оно переписывает инстансы чужих сцен целиком.
## Можно запускать повторно: прежнее сначала удаляется. Кулачных (громила,
## драчун) нет — по решению пользователя; рядовых крестоносцев и молотобойцев
## тоже нет (2026-11-23: крестоносец — только босс храма). Навмеш не меняется.

const SCENE := "res://reference_map_level/reference_map.tscn"
const SQUAD_SCRIPT := "res://enemy/enemy_squads.gd"
const SPAWN := Vector2(1150, 2530)
const BONFIRE_KEEP := 450.0
const BODY_RADIUS := 14.0
const NUDGE_MAX := 96.0
## Часовые видят дальше обычного стрелка своего вида
const SENTRY_VISION_BONUS := 60.0

## Отряды по маршруту героя: спавн у нижних ворот → нижняя улица → вдоль
## внутренней стены → внутренние ворота → западный проход → верхняя улица →
## завал у ворот → площадь → дорога к храму → врата храма (арена).
## Член отряда: [вид, точка, роль, куда смотрит, место в строю (патруль)]
const SQUADS := [
	{"id": "LowerStreet", "name": "Нижняя улица — первый заслон, лицом к воротам",
		"members": [
			["footsoldier", Vector2(380, 2215), "hold", Vector2(1, 0)],
			["footsoldier", Vector2(400, 2275), "hold", Vector2(1, 0)],
			["shooter", Vector2(300, 2245), "sentry", Vector2(1, 0)],
		]},
	{"id": "Kennel", "name": "Псарня — копейщик с псами ходит вдоль внутренней стены",
		"route": [Vector2(-1240, 1995), Vector2(-760, 2035)],
		"members": [
			["spearman", Vector2(-1000, 2015), "patrol", Vector2(1, 0), Vector2(0, 0)],
			["dog", Vector2(-970, 1990), "patrol", Vector2(1, 0), Vector2(30, -26)],
			["dog", Vector2(-970, 2040), "patrol", Vector2(1, 0), Vector2(30, 26)],
			["dog", Vector2(-1040, 2015), "patrol", Vector2(1, 0), Vector2(-36, 0)],
		]},
	{"id": "WestPassage", "name": "Западный проход — держат улицу на север, снайпер на перекрёстке",
		"members": [
			["spearman", Vector2(-1850, 1275), "hold", Vector2(0, 1)],
			["sniper", Vector2(-1900, 1060), "sentry", Vector2(0, 1)],
		]},
	{"id": "UpperStreet", "name": "Верхняя улица — патруль",
		"route": [Vector2(-1800, 655), Vector2(-1250, 655)],
		"members": [
			["footsoldier", Vector2(-1700, 655), "patrol", Vector2(1, 0), Vector2(0, 0)],
			["assassin", Vector2(-1736, 677), "patrol", Vector2(1, 0), Vector2(-36, 22)],
		]},
	{"id": "Barricade", "name": "Завал у ворот — проход через баррикаду, стрелки по обе стороны",
		"members": [
			["footsoldier", Vector2(-880, 640), "hold", Vector2(-1, 0)],
			["shooter", Vector2(-1120, 560), "sentry", Vector2(-0.8, 0.6)],
			["sniper", Vector2(-720, 620), "sentry", Vector2(-1, 0)],
		]},
	{"id": "Plaza", "name": "Вход на площадь — с севера, из переулка",
		"members": [
			["footsoldier", Vector2(-600, 1035), "hold", Vector2(0, -1)],
			["caster", Vector2(-700, 1070), "sentry", Vector2(0.3, -1)],
		]},
	{"id": "TempleRoad", "name": "Дорога к храму — у прохода в южной баррикаде",
		"members": [
			["spearman", Vector2(250, 1600), "hold", Vector2(-1, 0)],
			["footsoldier", Vector2(300, 1640), "hold", Vector2(-1, 0)],
			["shooter", Vector2(330, 1590), "sentry", Vector2(-1, -0.3)],
		]},
	{"id": "TempleGate", "name": "Врата храма — последний заслон перед ареной, маги на страже",
		"members": [
			["commander", Vector2(1300, 1330), "sentry", Vector2(-1, 0)],
			["caster", Vector2(1350, 1450), "sentry", Vector2(-1, -0.2)],
			["arcane", Vector2(1420, 1290), "sentry", Vector2(-1, 0)],
		]},
]


func _path(id: String) -> String:
	if id == "dog":
		return "res://enemy/beasts/dog/dog.tscn"
	return "res://enemy/humans/%s/%s.tscn" % [id, id]


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _fail(msg: String) -> void:
	push_error("place_order: " + msg)
	quit(1)


func _run() -> void:
	var dry := OS.get_cmdline_user_args().has("dry")
	# 1. Загрузить карту без прежних врагов Ордена и проверить точки
	var packed := load(SCENE) as PackedScene
	var map := packed.instantiate()
	var objects := map.get_node("Objects")
	for c in objects.get_children():
		if String(c.name).begins_with("Order_"):
			objects.remove_child(c)
			c.free()
	root.add_child(map)
	await _wait(30)
	var level := map as Node2D
	var nav: RID = level.get_world_2d().navigation_map
	var space := level.get_world_2d().direct_space_state
	var bonfires: Array[Vector2] = []
	for b in map.find_children("Bonfire*", "Node2D", true, false):
		bonfires.append((b as Node2D).global_position)
	var errors := 0
	var placed := []   # [squad, member, final point]
	for sq in SQUADS:
		for m in sq["members"]:
			var p: Vector2 = m[1]
			var q := _fit(p, nav, space)
			if not q.is_finite():
				print("  ОШИБКА %s %s %s: нет свободного места рядом" % [sq["id"], m[0], p])
				errors += 1
				continue
			if q.distance_to(p) > 0.5:
				print("  сдвиг %s %s: %s -> %s (%.0f px)" % [sq["id"], m[0], p, q.round(), q.distance_to(p)])
			for b in bonfires:
				if q.distance_to(b) < BONFIRE_KEEP:
					print("  ОШИБКА %s %s %s: %.0f px до костра %s" % [sq["id"], m[0], q.round(), q.distance_to(b), b])
					errors += 1
			var path := NavigationServer2D.map_get_path(nav, SPAWN, q, true)
			if path.is_empty() or path[path.size() - 1].distance_to(q) > 8.0:
				print("  ОШИБКА %s %s %s: нет пути от спавна" % [sq["id"], m[0], q.round()])
				errors += 1
			placed.append([sq, m, q.round()])
		for p in sq.get("route", []):
			var rq := NavigationServer2D.map_get_closest_point(nav, p)
			if rq.distance_to(p) > 6.0:
				print("  ОШИБКА %s: точка маршрута %s вне навмеша" % [sq["id"], p])
				errors += 1
			for b in bonfires:
				if (p as Vector2).distance_to(b) < BONFIRE_KEEP:
					print("  ОШИБКА %s: точка маршрута %s в %.0f px от костра" % [sq["id"], p, (p as Vector2).distance_to(b)])
					errors += 1
	map.queue_free()
	await _wait(2)
	print("place_order: отрядов %d, врагов %d, ошибок %d" % [SQUADS.size(), placed.size(), errors])
	if errors > 0:
		_fail("есть ошибки — сцена не тронута")
		return
	if dry:
		quit(0)
		return
	_write(placed)


## Ближайшая к p точка на навмеше, где тело врага не задевает мир
func _fit(p: Vector2, nav: RID, space: PhysicsDirectSpaceState2D) -> Vector2:
	if _free(p, nav, space):
		return p
	var r := 8.0
	while r <= NUDGE_MAX:
		var best := Vector2.INF
		for i in 24:
			var c := p + Vector2.from_angle(TAU * i / 24.0) * r
			if _free(c, nav, space) and (not best.is_finite() or c.distance_to(p) < best.distance_to(p)):
				best = c
		if best.is_finite():
			return best
		r += 8.0
	return Vector2.INF


func _free(p: Vector2, nav: RID, space: PhysicsDirectSpaceState2D) -> bool:
	if NavigationServer2D.map_get_closest_point(nav, p).distance_to(p) > 4.0:
		return false
	var sh := CircleShape2D.new()
	sh.radius = BODY_RADIUS
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = sh
	q.transform = Transform2D(0.0, p)
	q.collision_mask = 1
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


func _write(placed: Array) -> void:
	var f := FileAccess.open(SCENE, FileAccess.READ)
	if f == null:
		_fail("can't read scene")
		return
	var lines := f.get_as_text().split("\n")
	f.close()
	# Убрать прежнее: ext_resource order_*, узлы Objects/Order_* и OrderSquads
	var out: PackedStringArray = []
	var skip := false
	var removed := 0
	for l in lines:
		if l.begins_with("[ext_resource") and l.contains('id="order_'):
			continue
		if l.begins_with("["):
			skip = (l.begins_with('[node name="Order_') and l.contains('parent="Objects"')) \
				or (l.begins_with('[node name="OrderSquads"') and l.contains('parent="."'))
			if skip:
				removed += 1
		if not skip:
			out.append(l)
	# Ссылки на сцены и скрипт отрядов — после последнего ext_resource
	var kinds := {}
	for pm in placed:
		kinds[pm[1][0]] = true
	var ext: PackedStringArray = []
	for id in kinds:
		if not ResourceLoader.exists(_path(id)):
			_fail("no scene " + _path(id))
			return
		ext.append('[ext_resource type="PackedScene" path="%s" id="order_%s"]' % [_path(id), id])
	ext.append('[ext_resource type="Script" path="%s" id="order_squads_script"]' % SQUAD_SCRIPT)
	var last_ext := -1
	for i in out.size():
		if out[i].begins_with("[ext_resource"):
			last_ext = i
	if last_ext < 0:
		_fail("no ext_resource block")
		return
	var res: PackedStringArray = []
	res.append_array(out.slice(0, last_ext + 1))
	res.append_array(ext)
	res.append_array(out.slice(last_ext + 1))
	while res.size() > 0 and res[res.size() - 1].strip_edges() == "":
		res.remove_at(res.size() - 1)
	# Узлы врагов — в конец файла (родитель Objects описан раньше)
	var count := {}
	for pm in placed:
		var sq: Dictionary = pm[0]
		var m: Array = pm[1]
		var p: Vector2 = pm[2]
		var kind: String = m[0]
		var key: String = sq["id"] + kind
		count[key] = int(count.get(key, 0)) + 1
		var role: String = m[2]
		var facing: Vector2 = (m[3] as Vector2).normalized()
		res.append("")
		res.append('[node name="Order_%s_%s%d" parent="Objects" instance=ExtResource("order_%s")]' % [
			sq["id"], kind.capitalize(), count[key], kind])
		# Пиксельные персонажи — как герои (PlayerAnim: Nearest)
		res.append("texture_filter = 1")
		res.append("position = Vector2(%s, %s)" % [p.x, p.y])
		if role == "sentry":
			var base_vision := float((load(_path(kind)) as PackedScene).instantiate().get("vision_range"))
			res.append("vision_range = %s" % (base_vision + SENTRY_VISION_BONUS))
		res.append('metadata/order_enemy = "%s"' % kind)
		res.append('metadata/squad = "%s"' % sq["id"])
		res.append('metadata/squad_role = "%s"' % role)
		res.append("metadata/facing = Vector2(%s, %s)" % [snappedf(facing.x, 0.001), snappedf(facing.y, 0.001)])
		if m.size() > 4:
			res.append("metadata/formation = Vector2(%s, %s)" % [m[4].x, m[4].y])
	# Узел отрядов: маршруты патрулей
	res.append("")
	res.append('[node name="OrderSquads" type="Node" parent="."]')
	res.append('script = ExtResource("order_squads_script")')
	var routes: PackedStringArray = []
	for sq in SQUADS:
		if sq.has("route"):
			var nums: PackedStringArray = []
			for p in sq["route"]:
				nums.append("%s, %s" % [p.x, p.y])
			routes.append('"%s": PackedVector2Array(%s)' % [sq["id"], ", ".join(nums)])
	res.append("metadata/routes = {\n%s\n}" % ",\n".join(routes))
	res.append("")
	var w := FileAccess.open(ProjectSettings.globalize_path(SCENE), FileAccess.WRITE)
	if w == null:
		_fail("can't write scene (%s) — editor lock? rerun" % error_string(FileAccess.get_open_error()))
		return
	w.store_string("\n".join(res))
	w.close()
	print("place_order: удалено узлов %d, записано врагов %d" % [removed, placed.size()])
	quit(0)
