extends SceneTree
## Находит клетки слоёв земли, которые целиком закрыты непрозрачными тайлами
## слоя, лежащего выше, и сохраняет их список. В игре их убирает
## Levels/hidden_ground_cull.gd — картинка та же пиксель в пиксель, а видеокарта
## не рисует землю по два раза (на reference_map слои земли с тяжёлым
## terrain_ground.gdshader и под светом лежат друг на друге: FrameGround под
## Ground по всей карте, Ground под Stone во всём городе и т.д.).
##
## Запуск (перезапустить после правки любого из перечисленных слоёв — иначе в
## игре отсечение само отключится, см. хеши в hidden_ground_cull.gd):
##   godot --headless --path . -s res://tools/cull_hidden_ground.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/hidden_ground_cells.res FrameGround:Ground Ground:Stone Ground:PurpleGround Ground:Chasm Ground:Canyon Ground:Water Ground:South
##
## Пара «Нижний:Верхний». Клетка нижнего считается закрытой, только если ВСЕ
## клетки верхнего над её нарисованным прямоугольником заняты тайлами без
## единого прозрачного пикселя, без смещения texture_origin, без анимации, без
## своего материала и с modulate.a = 1. Пары считаются по исходной сцене
## независимо: если нижний слой одной пары — верхний для другой (Ground), это
## безопасно — убираем клетку Ground только там, где её закрывает слой ещё
## выше, а значит, закрыто и всё, что под ней.

var _img_cache := {}
var _opaque_cache := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Аргументы: сцена, файл .res, пары Нижний:Верхний ...")
		quit(1)
		return
	var level := (load(args[0]) as PackedScene).instantiate()
	var entries: Array = []
	var hashes := {}
	for pair in args.slice(2):
		var names: PackedStringArray = pair.split(":")
		var under := level.get_node_or_null(names[0]) as TileMapLayer
		var cover := level.get_node_or_null(names[1]) as TileMapLayer
		if under == null or cover == null:
			push_error("Не найдены слои %s" % pair)
			quit(1)
			return
		var err_text := _check_pair(under, cover)
		if err_text != "":
			push_error("%s: %s" % [pair, err_text])
			quit(1)
			return
		var cells := _hidden_cells(under, cover)
		print("[cull_hidden_ground] %s: скрыто %d из %d клеток" % [pair, cells.size(), under.get_used_cells().size()])
		entries.append({"under": names[0], "cells": cells})
		for n in names:
			hashes[n] = hash((level.get_node(n) as TileMapLayer).tile_map_data)

	var data := Resource.new()
	data.set_meta("entries", entries)
	data.set_meta("hashes", hashes)
	var err := ResourceSaver.save(data, args[1], ResourceSaver.FLAG_COMPRESS)
	print("[cull_hidden_ground] сохранено в %s (%s)" % [args[1], error_string(err)])
	level.free()
	quit(0 if err == OK else 1)


func _check_pair(under: TileMapLayer, cover: TileMapLayer) -> String:
	if under.transform != cover.transform or under.get_parent() != cover.get_parent():
		return "слои должны лежать в одном родителе с одинаковым transform"
	if under.get_index() > cover.get_index() or under.z_index != cover.z_index \
			or under.y_sort_enabled or cover.y_sort_enabled:
		return "нижний слой должен рисоваться раньше верхнего (без y-sort, тот же z)"
	if not cover.visible or cover.modulate.a < 0.999 or cover.self_modulate.a < 0.999:
		return "верхний слой скрыт или полупрозрачен"
	return ""


func _hidden_cells(under: TileMapLayer, cover: TileMapLayer) -> PackedVector2Array:
	var cells := PackedVector2Array()
	for c in under.get_used_cells():
		var rect := _drawn_rect(under, c)
		if rect.size == Vector2.ZERO:
			continue
		var g0 := cover.local_to_map(rect.position + Vector2(0.01, 0.01))
		var g1 := cover.local_to_map(rect.end - Vector2(0.01, 0.01))
		var hidden := true
		for gy in range(g0.y, g1.y + 1):
			for gx in range(g0.x, g1.x + 1):
				if not _is_opaque(cover, Vector2i(gx, gy)):
					hidden = false
					break
			if not hidden:
				break
		if hidden:
			cells.append(Vector2(c))
	return cells


## Прямоугольник, который тайл клетки реально закрашивает (в координатах слоя)
func _drawn_rect(layer: TileMapLayer, c: Vector2i) -> Rect2:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
	if src == null:
		return Rect2()
	var coords := layer.get_cell_atlas_coords(c)
	var td := src.get_tile_data(coords, layer.get_cell_alternative_tile(c))
	var size := Vector2(src.get_tile_texture_region(coords).size)
	if td and td.transpose:
		size = Vector2(size.y, size.x)
	var origin := Vector2(td.texture_origin) if td else Vector2.ZERO
	return Rect2(layer.map_to_local(c) - size * 0.5 - origin, size)


func _is_opaque(layer: TileMapLayer, c: Vector2i) -> bool:
	var sid := layer.get_cell_source_id(c)
	if sid < 0:
		return false
	var coords := layer.get_cell_atlas_coords(c)
	var alt := layer.get_cell_alternative_tile(c)
	var key := "%d:%d:%d:%d:%d" % [layer.get_instance_id(), sid, coords.x, coords.y, alt]
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	var ok := _check_tile(layer, sid, coords, alt)
	_opaque_cache[key] = ok
	return ok


func _check_tile(layer: TileMapLayer, sid: int, coords: Vector2i, alt: int) -> bool:
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null or src.texture == null:
		return false
	if src.get_tile_animation_frames_count(coords) > 1:
		return false
	var td := src.get_tile_data(coords, alt)
	if td == null or td.material != null or td.modulate.a < 0.999 or td.texture_origin != Vector2i.ZERO:
		return false
	var region := src.get_tile_texture_region(coords)
	# Тайл должен закрывать свою клетку целиком: регион не меньше клетки
	if region.size.x < layer.tile_set.tile_size.x or region.size.y < layer.tile_set.tile_size.y:
		return false
	var img := _image(src.texture)
	if img == null:
		return false
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if img.get_pixel(x, y).a < 0.999:
				return false
	return true


func _image(tex: Texture2D) -> Image:
	if _img_cache.has(tex):
		return _img_cache[tex]
	var img := tex.get_image()
	if img and img.is_compressed():
		img.decompress()
	_img_cache[tex] = img
	return img
