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
	# Сначала сверяем ВСЕ слои по исходным данным, потом уже стираем: стирание
	# одной пары меняет хеш слоя, который в другой паре служит верхним
	var hashes: Dictionary = data.get_meta("hashes", {})
	for layer_name in hashes:
		var layer := level.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if layer == null or hash(layer.tile_map_data) != hashes[layer_name]:
			print_verbose("[HiddenGroundCull] слой %s изменился — перезапусти tools/cull_hidden_ground.gd" % layer_name)
			return
	for e in data.get_meta("entries", []):
		var under := level.get_node(NodePath(e["under"])) as TileMapLayer
		for c in e["cells"]:
			under.erase_cell(Vector2i(c))
