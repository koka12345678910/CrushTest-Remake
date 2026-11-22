extends Node
## hidden_ground_cull.gd — убирает клетки слоёв земли, которые целиком закрыты
## непрозрачным слоем выше (список готовит tools/cull_hidden_ground.gd).
##
## Зачем: на reference_map слои земли лежат друг на друге (FrameGround под
## Ground по всей карте, Ground под Stone во всём городе...), все с тяжёлым
## шейдером земли и под светом. Закрытые клетки не видны, но видеокарта всё
## равно их рисует — на слабом ноутбуке это ~5-8 мс на кадр. Картинка после
## отсечения та же пиксель в пиксель.
##
## Безопасность: в данных лежат хеши всех задействованных слоёв на момент
## расчёта. Если хоть один слой перерисовали (руками или tools/build_terrain.gd),
## хеш не совпадёт — отсечение не делается вообще, пока не перезапустят
## tools/cull_hidden_ground.gd. Узлы ищутся у родителя этого узла.

@export var data: Resource


func _ready() -> void:
	if data == null:
		return
	var level := get_parent()
	# Сначала сверяем слои по исходным данным, потом уже стираем: стирание
	# одной пары меняет хеш слоя, который в другой паре служит верхним.
	# Пара применяется, только если не менялись ОБА её слоя: правка одного слоя
	# (новая мостовая, вода) больше не выключает отсечение для всей карты —
	# раньше так земля молча рисовалась дважды после любой правки карты
	var hashes: Dictionary = data.get_meta("hashes", {})
	var ok := {}
	for layer_name in hashes:
		var layer := level.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		ok[layer_name] = layer != null and hash(layer.tile_map_data) == hashes[layer_name]
		if not ok[layer_name]:
			push_warning("[HiddenGroundCull] слой %s изменился — его пары не отсекаются; перезапусти tools/cull_hidden_ground.gd" % layer_name)
	for e in data.get_meta("entries", []):
		var under_name: String = e["under"]
		# Старый формат без "over" — только если совпали все слои
		var over_ok: bool = ok.get(e["over"], false) if e.has("over") else not ok.values().has(false)
		if not ok.get(under_name, false) or not over_ok:
			continue
		var under := level.get_node(NodePath(under_name)) as TileMapLayer
		for c in e["cells"]:
			under.erase_cell(Vector2i(c))
