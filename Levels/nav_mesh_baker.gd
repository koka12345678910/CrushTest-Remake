extends NavigationRegion2D
## nav_mesh_baker.gd — запекает навмеш уровня при старте.
##
## Проходимая зона — прямоугольник по всем тайлам земли (ground_layers),
## препятствия — всё, во что враг реально упирается: коллизии тайлов
## (стены, пропсы, деревья) и StaticBody2D (магазин и т.п.) по маске
## коллизий врага. Печём в рантайме, а не в редакторе — так навмеш не
## устаревает: дорисовал стену на карте, и враги её уже обходят.
##
## Готовый навмеш читает NavigationAgent2D врага (enemy.gd — погоня и
## блуждание идут по пути навигации, а не по прямой в стену).

## Слои земли — по их тайлам определяется граница проходимой зоны
@export var ground_layers: Array[NodePath] = []
## Отступ от препятствий. Капсула врага — радиус 14, берём с запасом,
## чтобы путь не прижимал его вплотную к углам стен и деревьев
@export var agent_radius := 18.0
## Маска коллизий, которые считаются препятствиями — как collision_mask врага
@export_flags_2d_physics var obstacle_mask := 3
## Размер ячейки навмеша (px)
@export var cell_size := 2.0

signal baked


func _ready() -> void:
	# Ждём кадр: инстансы в сцене (лестницы, спавнер и т.п.) должны успеть
	# встать на свои места, прежде чем мы соберём их коллизии
	_bake.call_deferred()


func _bake() -> void:
	var level := owner if owner else get_parent()
	# Геометрия собирается в координатах уровня — ставим регион туда же,
	# иначе навмеш уехал бы на смещение родителя
	global_transform = level.global_transform

	var bounds := _ground_bounds(level)
	if bounds.size == Vector2.ZERO:
		push_warning("[NavMeshBaker] не найдено ни одного тайла земли — навмеш не запечён")
		return

	# Размер ячейки навмеша и карты навигации обязан совпадать. При 1px
	# мелкие тайловые препятствия давали ошибку склейки рёбер при синхронизации
	NavigationServer2D.map_set_cell_size(get_world_2d().navigation_map, cell_size)

	# Синхронно: сбор — миллисекунды, запекание — доли секунды, и это
	# прячется за экраном загрузки. Асинхронный вариант растягивался на
	# секунды, всё это время враги шли бы по прямой в стены.
	# На плотных картах (лес, ряды могил) большой отступ иногда не даёт
	# разбить навмеш на выпуклые части ("Convex partition failed") — тогда
	# пробуем отступ поменьше, а не остаёмся совсем без навигации
	var source: NavigationMeshSourceGeometryData2D = null
	for radius in [agent_radius, agent_radius - 4.0, agent_radius - 8.0]:
		var poly := _make_polygon(bounds, maxf(radius, 4.0))
		if source == null:
			source = NavigationMeshSourceGeometryData2D.new()
			NavigationServer2D.parse_source_geometry_data(poly, source, level)
		NavigationServer2D.bake_from_source_geometry_data(poly, source)
		if poly.get_polygon_count() > 0:
			navigation_polygon = poly
			baked.emit()
			return
	push_warning("[NavMeshBaker] не удалось запечь навмеш — враги пойдут по прямой")


func _make_polygon(bounds: Rect2, radius: float) -> NavigationPolygon:
	var poly := NavigationPolygon.new()
	poly.agent_radius = radius
	poly.cell_size = cell_size
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.parsed_collision_mask = obstacle_mask
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	poly.add_outline(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))
	return poly


## Прямоугольник (в координатах уровня), покрывающий все тайлы земли
func _ground_bounds(level: Node) -> Rect2:
	var result := Rect2()
	var first := true
	for path in ground_layers:
		var layer := get_node_or_null(path) as TileMapLayer
		if layer == null:
			continue
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var half := Vector2(layer.tile_set.tile_size) * 0.5
		var a: Vector2 = layer.map_to_local(used.position) - half
		var b: Vector2 = layer.map_to_local(used.end - Vector2i.ONE) + half
		var ga: Vector2 = level.to_local(layer.to_global(a))
		var gb: Vector2 = level.to_local(layer.to_global(b))
		var r := Rect2(ga, Vector2.ZERO).expand(gb)
		result = r if first else result.merge(r)
		first = false
	return result
