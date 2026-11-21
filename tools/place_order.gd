extends SceneTree
## place_order.gd — расставляет врагов Ордена Тёмного Солнца (люди из
## enemy/humans и боевые псы enemy/beasts) на reference_map.
##
##   godot --headless --path . -s res://tools/place_order.gd
##
## Правит .tscn как текст: дописывает ссылки на сцены врагов и узлы
## Objects/Order_*. Сохранение через PackedScene.pack() здесь не годится —
## оно заодно переписывает инстансы скелетов (type, script, все поля).
## Можно запускать повторно: прежние ext_resource "order_*" и узлы Order_*
## сначала удаляются. Кулачных (громила, драчун) нет — по решению пользователя.
##
## Точки проверены по навмешу (враг стоит на нём, до него есть путь от
## спавна), по коллизии мира (круг 14 px свободен) и по кострам: каждый не
## ближе 450 px к любому костру (иначе у костра нельзя отдохнуть). Маршрут
## героя спавн → ворота арены — около 7.9 тыс. px:
##   нижний город → проход у внутренних ворот → верхняя улица → площадь →
##   дорога к храму → арена. Мечники — по городу, маги — у входа на арену.
## Навмеш не меняется (враги — не препятствия).

const SCENE := "res://reference_map_level/reference_map.tscn"

const ENEMIES := [
	# Нижний город, сразу за спавном: пара пехотинцев
	["Order_Footsoldier1", "footsoldier", Vector2(430, 2190)],
	["Order_Footsoldier2", "footsoldier", Vector2(460, 2260)],
	# Овраг у нижней улицы: стая псов
	["Order_Dog1", "dog", Vector2(-850, 2010)],
	["Order_Dog2", "dog", Vector2(-800, 2000)],
	["Order_Dog3", "dog", Vector2(-900, 2080)],
	# Проход вдоль западной стены к верхнему городу
	["Order_Spearman1", "spearman", Vector2(-1880, 1210)],
	["Order_Footsoldier3", "footsoldier", Vector2(-1910, 1020)],
	# Верхняя улица
	["Order_Shooter1", "shooter", Vector2(-1700, 640)],
	["Order_Assassin1", "assassin", Vector2(-1500, 640)],
	["Order_Crusader1", "crusader", Vector2(-1300, 665)],
	["Order_Sniper1", "sniper", Vector2(-1060, 600)],
	["Order_Shooter2", "shooter", Vector2(-1100, 520)],
	["Order_Hammer1", "hammer", Vector2(-750, 800)],
	# Спуск к площади
	["Order_Crusader2", "crusader", Vector2(-640, 1010)],
	# Дорога к храму
	["Order_Spearman2", "spearman", Vector2(265, 1480)],
	["Order_Assassin2", "assassin", Vector2(300, 1580)],
	# У входа на арену (южные ворота храма, x 1090) — маги
	["Order_Commander1", "commander", Vector2(1200, 1380)],
	["Order_Caster1", "caster", Vector2(1330, 1450)],
	["Order_Arcane1", "arcane", Vector2(1460, 1370)],
]


func _path(id: String) -> String:
	if id == "dog":
		return "res://enemy/beasts/dog/dog.tscn"
	return "res://enemy/humans/%s/%s.tscn" % [id, id]


func _initialize() -> void:
	var f := FileAccess.open(SCENE, FileAccess.READ)
	if f == null:
		push_error("place_order: can't read scene")
		quit(1)
		return
	var lines := f.get_as_text().split("\n")
	f.close()
	# 1. Убрать прежнее: ext_resource order_* и блоки узлов Order_* в Objects
	var out: PackedStringArray = []
	var skip := false
	var removed := 0
	for l in lines:
		if l.begins_with("[ext_resource") and l.contains('id="order_'):
			continue
		if l.begins_with("["):
			skip = l.begins_with('[node name="Order_') and l.contains('parent="Objects"')
			if skip:
				removed += 1
		if not skip:
			out.append(l)
	# 2. Ссылки на сцены — после последнего ext_resource
	var ids := {}
	for e in ENEMIES:
		ids[e[1]] = true
	var ext: PackedStringArray = []
	for id in ids:
		if not ResourceLoader.exists(_path(id)):
			push_error("place_order: no scene " + _path(id))
			quit(1)
			return
		ext.append('[ext_resource type="PackedScene" path="%s" id="order_%s"]' % [_path(id), id])
	var last_ext := -1
	for i in out.size():
		if out[i].begins_with("[ext_resource"):
			last_ext = i
	if last_ext < 0:
		push_error("place_order: no ext_resource block")
		quit(1)
		return
	var res: PackedStringArray = []
	res.append_array(out.slice(0, last_ext + 1))
	res.append_array(ext)
	res.append_array(out.slice(last_ext + 1))
	# 3. Узлы — в конец файла (родитель Objects описан раньше)
	while res.size() > 0 and res[res.size() - 1].strip_edges() == "":
		res.remove_at(res.size() - 1)
	for e in ENEMIES:
		var p: Vector2 = e[2]
		res.append("")
		res.append('[node name="%s" parent="Objects" instance=ExtResource("order_%s")]' % [e[0], e[1]])
		# Пиксельные персонажи — как герои (PlayerAnim: Nearest)
		res.append("texture_filter = 1")
		res.append("position = Vector2(%s, %s)" % [p.x, p.y])
		res.append('metadata/order_enemy = "%s"' % e[1])
	res.append("")
	var w := FileAccess.open(ProjectSettings.globalize_path(SCENE), FileAccess.WRITE)
	if w == null:
		push_error("place_order: can't write scene (%s) — editor lock? rerun" % error_string(FileAccess.get_open_error()))
		quit(1)
		return
	w.store_string("\n".join(res))
	w.close()
	print("place_order: removed %d, added %d" % [removed, ENEMIES.size()])
	quit(0)
