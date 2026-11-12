extends SceneTree
## Запекает навмеш уровня заранее и сохраняет его рядом со сценой, чтобы
## Levels/nav_mesh_baker.gd не пёк его при каждом старте уровня (prebaked).
## Нужно большим картам: reference_map печётся около 50 секунд.
##
## Запуск (перепечь после правки коллизии карты):
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res
## Сцену скрипт не трогает: путь к готовому файлу уже стоит в prebaked у узла
## NavigationRegion2D. Если перепечь не тот файл, на который он ссылается,
## пропиши новый путь в редакторе.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Нужно два аргумента: сцена уровня и куда сохранить навмеш (.res)")
		quit(1)
		return
	var packed := load(args[0]) as PackedScene
	if packed == null:
		push_error("Не удалось загрузить сцену " + args[0])
		quit(1)
		return
	var level := packed.instantiate()
	var region: Node = null
	for n in level.find_children("*", "NavigationRegion2D", true, false):
		if "prebaked" in n:
			region = n
			break
	if region == null:
		push_error("В сцене нет NavigationRegion2D с nav_mesh_baker.gd")
		quit(1)
		return
	# Печём по-настоящему, без готового файла
	region.prebaked = null
	var t0 := Time.get_ticks_msec()
	root.add_child(level)
	await region.baked
	var poly: NavigationPolygon = region.navigation_polygon
	var err := ResourceSaver.save(poly, args[1], ResourceSaver.FLAG_COMPRESS)
	print("[bake_navmesh] %s: %d полигонов, %.1f с, сохранено в %s (%s)" % [
		args[0], poly.get_polygon_count(), (Time.get_ticks_msec() - t0) / 1000.0, args[1], error_string(err)])
	quit(0 if err == OK else 1)
