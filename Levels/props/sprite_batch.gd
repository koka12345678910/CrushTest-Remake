@tool
extends Node2D
## sprite_batch.gd — много статичных спрайтов из одного атласа одним узлом.
##
## Раньше каждый росток, камешек, секция ограды и куст на кладбище были
## отдельным Sprite2D (сотни узлов). Генератор (tools/graveyard_generator.gd,
## batch_static_nodes) собирает их сюда: каждый спрайт — свой canvas item
## RenderingServer внутри этого узла, рисуется тем же прямоугольником, что и
## у Sprite2D, и так же отсекается за краем экрана. Узлов при этом нет.
##
## items — по ITEM_STRIDE чисел на спрайт: позиция x, y; масштаб x, y;
## offset x, y (левый верх картинки от точки спрайта, как у Sprite2D с
## centered = false); регион атласа x, y, w, h; flip_h (0 или 1).
##
## y_sorted = true — узел y_sort_enabled, и вложенная сортировка Godot ставит
## элементы в общий порядок по глубине с героем и врагами — по их позиции,
## как раньше отдельные Sprite2D. false — рисуются по порядку в items на
## z_index узла (плоский декор под ногами). Материал, light_mask и фильтр
## текстуры узла достаются каждому элементу.

const ITEM_STRIDE := 11

@export var atlas: Texture2D:
	set(v):
		atlas = v
		_rebuild()
@export var y_sorted := false:
	set(v):
		y_sorted = v
		y_sort_enabled = v
@export var items := PackedFloat32Array():
	set(v):
		items = v
		_rebuild()

var _cis: Array[RID] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_items()


func _ready() -> void:
	_rebuild()


func count() -> int:
	return items.size() / ITEM_STRIDE


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_free_items()
	if atlas == null:
		return
	var tex := atlas.get_rid()
	var mat := material.get_rid() if material else RID()
	for i in range(0, items.size() - ITEM_STRIDE + 1, ITEM_STRIDE):
		var ci := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(ci, get_canvas_item())
		RenderingServer.canvas_item_set_transform(ci, _xform(i))
		RenderingServer.canvas_item_set_light_mask(ci, light_mask)
		RenderingServer.canvas_item_set_visibility_layer(ci, visibility_layer)
		RenderingServer.canvas_item_set_default_texture_filter(ci, texture_filter as RenderingServer.CanvasItemTextureFilter)
		if mat.is_valid():
			RenderingServer.canvas_item_set_material(ci, mat)
		RenderingServer.canvas_item_add_texture_rect_region(ci, _rect(i), tex, _region(i))
		_cis.append(ci)


func _xform(i: int) -> Transform2D:
	return Transform2D(0.0, Vector2(items[i + 2], items[i + 3]), 0.0, Vector2(items[i], items[i + 1]))


func _region(i: int) -> Rect2:
	return Rect2(items[i + 6], items[i + 7], items[i + 8], items[i + 9])


## Как Sprite2D: прямоугольник от offset размером с регион; flip_h —
## отрицательная ширина (картинка зеркалится внутри того же прямоугольника)
func _rect(i: int) -> Rect2:
	var r := Rect2(items[i + 4], items[i + 5], items[i + 8], items[i + 9])
	if items[i + 10] > 0.5:
		r.size.x = -r.size.x
	return r


func _free_items() -> void:
	for ci in _cis:
		RenderingServer.free_rid(ci)
	_cis.clear()
