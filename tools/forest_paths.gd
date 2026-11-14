extends SceneTree
## Земляные тропинки и вдвое более редкий лес на reference_map.
##
## Шаги (по умолчанию безопасные: paths, clear, leaves):
##   paths — тропы по навмешу между важными местами (старт, костры, мосты,
##           болото, лагерь, форт, босс, выходы). Путь сглаживается и чуть
##           виляет; результат — reference_map_level/paths.json (линии) и
##           маска textures/terrain/paths.res (4 мировых px на тексель),
##           шейдер земли кладёт по ней утоптанную землю.
##   thin  — с троп убираются деревья, кусты, пни и коряги (атлас
##           forest_trees), затем лес прореживается до половины деревьев:
##           остаются деревья не ближе R друг к другу (R подбирается под
##           нужное число) — густое редеет, редкое остаётся. Ствол
##           удалённого дерева уходит и из коллизии (Collision, static_shapes).
##           То же в лагере (ruined_camp.tscn).
##   clear — как thin, но без прореживания: только расчистка троп (деревья,
##           кусты, декали листвы). Для повторных запусков после правки троп.
##   under — подлесок (кусты, папоротник, камни, пни, коряги) вдвое реже,
##           так же равномерно, как деревья.
##   pixel — атлас леса в пиксель-арт (см. _step_pixel).
##   sharp — устарел: атлас леса теперь из tools/hd_art.gd (шаг пропускается).
##   leaves — убрать кучи опавших листьев (декали) со всей карты.
##
## Запуск:
##   godot --headless --path . -s res://tools/forest_paths.gd -- [paths] [thin]
## После thin навмеш надо перепечь (коллизия поменялась):
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res

const MAP := "res://reference_map_level/reference_map.tscn"
const CAMP := "res://reference_map_level/ruined_camp.tscn"
const ATLAS := "res://reference_map_level/textures/forest_trees.png"
const META := "res://reference_map_level/textures/forest_trees.json"
const PATHS_JSON := "res://reference_map_level/paths.json"
const PATHS_TEX := "res://reference_map_level/textures/terrain/paths.res"
const MATERIAL := "res://reference_map_level/textures/terrain/ground_material.tres"

## Мир карты (как в build_terrain.gd)
const WORLD := Rect2i(-3520, -704, 8640, 5120)
const PATH_PX := 4
## Полуширина тропы (мировые px) и мягкий край
const HALF_W := 20.0
const EDGE := 8.0
## Насколько далеко от домов и городских тайлов мостовая под тропой ещё
## остаётся камнем
const TOWN_MARGIN := 160.0
## Дорожка или площадь: доля мостовой в окне (2R+1)x(2R+1) клеток вокруг
const TRAIL_R := 3
const TRAIL_FILL := 0.55

## Какие места соединить тропами
const ROUTES := [
	# старт и город → южная дорога → мосты → отшельник
	[Vector2(-288, 1224), Vector2(-250, 2070)],
	[Vector2(-250, 2070), Vector2(-680, 2400)],
	[Vector2(-680, 2400), Vector2(-978, 2402)],
	[Vector2(-680, 2400), Vector2(-800, 2790)],
	[Vector2(-800, 2790), Vector2(-1420, 3020)],
	# южная дорога → болото → святилище → выход из болота → лагерь
	[Vector2(-250, 2070), Vector2(-250, 2610)],
	[Vector2(-250, 2610), Vector2(560, 2995)],
	[Vector2(560, 2995), Vector2(1180, 3260)],
	[Vector2(1180, 3260), Vector2(2420, 2880)],
	# старт → форт → ворота; к торговцу; через пропасть к боссу
	[Vector2(-288, 1224), Vector2(800, 1088)],
	[Vector2(800, 1088), Vector2(1466, 1305)],
	[Vector2(1466, 1305), Vector2(1845, 1314)],
	[Vector2(800, 1088), Vector2(1626, 828)],
	[Vector2(1845, 1314), Vector2(2900, 1320)],
	[Vector2(2900, 1320), Vector2(2340, 654)],
	[Vector2(2340, 654), Vector2(3300, 585)],
	[Vector2(2900, 1320), Vector2(2420, 2880)],
	# выходы с карты
	[Vector2(-288, 1224), Vector2(-288, -112)],
	[Vector2(-288, 1224), Vector2(-1645, -112)],
	[Vector2(-1645, -112), Vector2(-2928, 186)],
	[Vector2(-288, 1224), Vector2(-2928, 1068)],
	[Vector2(-2928, 1068), Vector2(-2928, 2020)],
	[Vector2(-250, 2070), Vector2(-2066, 2160)],
]

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["paths", "clear", "leaves"]
	_run(steps)


func _run(steps: Array) -> void:
	if "paths" in steps:
		await _step_paths()
	if "thin" in steps:
		_step_thin(true)
	elif "clear" in steps:
		_step_thin(false)
	if "under" in steps:
		_step_thin(true, true)
	if "pixel" in steps:
		_step_pixel()
	if "sharp" in steps:
		_step_sharp()
	if "leaves" in steps:
		_step_leaves()
	for r in report:
		print(r)
	quit()


# ───────────────────────── пиксель-арт деревьев ─────────────────────────
## Атлас леса на сетку пиксель-арта, как земля и скалы: 1 арт-пиксель =
## 1 px мира. Слой деревьев масштабирован 0.5, поэтому каждый спрайт
## уменьшается вдвое, сводится к общей палитре с жёсткой альфой и снова
## увеличивается вдвое без сглаживания (блоки 2x2 текселя). Размеры и
## места спрайтов в атласе те же — сцену трогать не нужно. Исходник
## атласа один раз копируется в textures/src/forest_trees_smooth.png и
## дальше берётся оттуда (повторный запуск не портит картинку).
## После шага: godot --headless --path . --import
const BT := preload("res://tools/build_terrain.gd")
const SMOOTH := "res://reference_map_level/textures/src/forest_trees_smooth.png"
const TREE_COLORS := 64


func _step_pixel() -> void:
	if _hd_atlas():
		return
	var atlas_path := ProjectSettings.globalize_path(ATLAS)
	var smooth_path := ProjectSettings.globalize_path(SMOOTH)
	if not FileAccess.file_exists(smooth_path):
		DirAccess.copy_absolute(atlas_path, smooth_path)
	var src := Image.load_from_file(smooth_path)
	src.convert(Image.FORMAT_RGBA8)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	var smalls := {}
	for name in meta:
		var r: Array = meta[name]["rect"]
		var rect := Rect2i(r[0], r[1], r[2], r[3])
		var im := src.get_region(rect)
		im.resize(maxi(1, int(ceil(rect.size.x / 2.0))), maxi(1, int(ceil(rect.size.y / 2.0))), Image.INTERPOLATE_LANCZOS)
		smalls[name] = BT._unsharp(im, 0.5)
	var pal: PackedColorArray = BT._palette(smalls.values(), TREE_COLORS)
	var out := src.duplicate() as Image
	for name in meta:
		var r: Array = meta[name]["rect"]
		var rect := Rect2i(r[0], r[1], r[2], r[3])
		var q: Image = BT._quantize(smalls[name], pal)
		q.resize(q.get_width() * 2, q.get_height() * 2, Image.INTERPOLATE_NEAREST)
		# Старое содержимое региона стирается, новое кладётся в тот же угол
		out.fill_rect(rect, Color(0, 0, 0, 0))
		out.blit_rect(q, Rect2i(Vector2i.ZERO, rect.size), rect.position)
	var err := out.save_png(atlas_path)
	report.append("pixel: %d спрайтов леса → пиксель-арт, %d цветов (%s)" % [meta.size(), TREE_COLORS, error_string(err)])


# ───────────────────────── тропы ─────────────────────────

func _step_paths() -> void:
	var level := (load(MAP) as PackedScene).instantiate()
	var spawn := level.find_child("PlayerSpawn", true, false)
	if spawn:
		spawn.free()
	root.add_child(level)
	# Навмеш берётся отложенно, карта навигации синхронизируется на кадрах физики
	for i in 30:
		await physics_frame
	var nav_map: RID = (level as Node2D).get_world_2d().navigation_map
	var lines: Array = []
	var total := 0.0
	var wob := FastNoiseLite.new()
	wob.seed = 5
	wob.frequency = 1.0 / 260.0
	for r in ROUTES:
		var raw := NavigationServer2D.map_get_path(nav_map, r[0], r[1], true)
		if raw.size() < 2:
			report.append("  тропа %s → %s не найдена" % [r[0], r[1]])
			continue
		var pts := _resample(raw, 8.0)
		pts = _chaikin(pts, 3)
		# Лёгкое виляние поперёк пути, концы на месте
		var out := PackedVector2Array()
		for i in pts.size():
			var p := pts[i]
			var t := 1.0 if pts.size() < 3 else clampf(minf(i, pts.size() - 1 - i) / 8.0, 0.0, 1.0)
			var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			out.append(p + nrm * wob.get_noise_2d(p.x, p.y) * 14.0 * t)
		lines.append(out)
		for i in range(1, out.size()):
			total += out[i].distance_to(out[i - 1])
	# Где город: там тропа идёт по мостовой и камень остаётся камнем,
	# а в лесу старые каменные дорожки под тропой становятся землёй
	var town: Array[Rect2] = []
	var tl := level.get_node("Town") as TileMapLayer
	for c in tl.get_used_cells():
		town.append(Rect2(tl.to_global(tl.map_to_local(c)) - Vector2(8, 8), Vector2(16, 16)))
	for n in level.get_node("Objects").get_children():
		if n is Sprite2D and String(n.name).begins_with("House"):
			var r := (n as Sprite2D).get_rect()
			var xf := (n as Sprite2D).global_transform
			town.append(Rect2(xf * r.position, (xf * r.end) - (xf * r.position)).abs())
	# Старые каменные дорожки: клетки мостовой (ряды 48..71 атласа reskin)
	# слоя Stone. Узкие — дорожки (их тоже делаем земляными тропами),
	# широкие — площади и дворы (остаются камнем)
	# Мостовая есть и в слое South (перерисованный юг, ряды 184+): там клетка
	# считается каменной, если в её рисунке больше трети серого камня
	var reskin := Image.load_from_file(ProjectSettings.globalize_path("res://reference_map_level/textures/reskin_tiles.png"))
	reskin.convert(Image.FORMAT_RGBA8)
	var stone := level.get_node("Stone") as TileMapLayer
	var cobble := {}
	# Клетки провала (почти чёрные) — их каменная кромка не дорожка
	var void_cells := {}
	for ln in ["Stone", "South", "Chasm"]:
		var lay := level.get_node(ln) as TileMapLayer
		for c in lay.get_used_cells():
			var ac := lay.get_cell_atlas_coords(c)
			var src := lay.tile_set.get_source(lay.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null or src.texture == null or src.texture.get_width() != 4096:
				continue
			if _dark_share(reskin, ac) > 0.3:
				void_cells[c] = true
			if ln == "Chasm" or not ((ac.y >= 48 and ac.y < 72) or ac.y >= 184):
				continue
			if _gray_share(reskin, ac) > 0.35 and _dark_share(reskin, ac) < 0.12:
				cobble[c] = true
	var trail_cells: Array[Rect2] = []
	for c in cobble:
		var near_void := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if void_cells.has(c + Vector2i(dx, dy)):
					near_void = true
		if near_void:
			continue
		var n := 0
		for dy in range(-TRAIL_R, TRAIL_R + 1):
			for dx in range(-TRAIL_R, TRAIL_R + 1):
				if cobble.has(c + Vector2i(dx, dy)):
					n += 1
		if n < TRAIL_FILL * (2 * TRAIL_R + 1) * (2 * TRAIL_R + 1):
			trail_cells.append(Rect2(stone.to_global(stone.map_to_local(c)) - Vector2(8, 8), Vector2(16, 16)))
	level.queue_free()
	await process_frame

	# Маска
	var w := WORLD.size.x / PATH_PX
	var h := WORLD.size.y / PATH_PX
	var f := PackedFloat32Array()
	f.resize(w * h)
	var width := FastNoiseLite.new()
	width.seed = 9
	width.frequency = 1.0 / 120.0
	for line in lines:
		for i in range(1, line.size()):
			var a: Vector2 = line[i - 1]
			var b: Vector2 = line[i]
			var hw := HALF_W + width.get_noise_2d(a.x, a.y) * 4.0
			var reach := hw + EDGE
			var x0 := int((minf(a.x, b.x) - reach - WORLD.position.x) / PATH_PX)
			var x1 := int((maxf(a.x, b.x) + reach - WORLD.position.x) / PATH_PX) + 1
			var y0 := int((minf(a.y, b.y) - reach - WORLD.position.y) / PATH_PX)
			var y1 := int((maxf(a.y, b.y) + reach - WORLD.position.y) / PATH_PX) + 1
			for ty in range(maxi(y0, 0), mini(y1, h)):
				for tx in range(maxi(x0, 0), mini(x1, w)):
					var p := Vector2(WORLD.position.x + (tx + 0.5) * PATH_PX, WORLD.position.y + (ty + 0.5) * PATH_PX)
					var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
					var v := clampf(1.0 - (d - hw) / EDGE, 0.0, 1.0)
					if v > f[ty * w + tx]:
						f[ty * w + tx] = v
	# R — тропа, G — «вне города» (там камень под тропой заменяется землёй)
	var wild := PackedByteArray()
	wild.resize(w * h)
	wild.fill(255)
	for r in town:
		var g := r.grow(TOWN_MARGIN)
		for ty in range(maxi(int((g.position.y - WORLD.position.y) / PATH_PX), 0), mini(int((g.end.y - WORLD.position.y) / PATH_PX) + 1, h)):
			for tx in range(maxi(int((g.position.x - WORLD.position.x) / PATH_PX), 0), mini(int((g.end.x - WORLD.position.x) / PATH_PX) + 1, w)):
				wild[ty * w + tx] = 0
	# B — узкая старая каменная дорожка вне города: тоже земляная тропа
	var trail := PackedByteArray()
	trail.resize(w * h)
	for r in trail_cells:
		for ty in range(maxi(int((r.position.y - WORLD.position.y) / PATH_PX), 0), mini(int((r.end.y - WORLD.position.y) / PATH_PX), h)):
			for tx in range(maxi(int((r.position.x - WORLD.position.x) / PATH_PX), 0), mini(int((r.end.x - WORLD.position.x) / PATH_PX), w)):
				if wild[ty * w + tx] > 0:
					trail[ty * w + tx] = 255
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for i in w * h:
		bytes[i * 4] = int(f[i] * 255.0)
		bytes[i * 4 + 1] = wild[i]
		bytes[i * 4 + 2] = trail[i]
		bytes[i * 4 + 3] = 255
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	var err := ResourceSaver.save(ImageTexture.create_from_image(img), PATHS_TEX, ResourceSaver.FLAG_COMPRESS)
	# Линии — для прореживания и на будущее
	var js: Array = []
	for line in lines:
		var arr: Array = []
		for p in line:
			arr.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
		js.append(arr)
	var fa := FileAccess.open(PATHS_JSON, FileAccess.WRITE)
	fa.store_string(JSON.stringify(js))
	fa.close()
	# Маска в материал земли
	var mat := load(MATERIAL) as ShaderMaterial
	mat.set_shader_parameter("path_map", ResourceLoader.load(PATHS_TEX, "", ResourceLoader.CACHE_MODE_REPLACE))
	mat.set_shader_parameter("path_rect", Vector4(WORLD.position.x, WORLD.position.y, WORLD.size.x, WORLD.size.y))
	ResourceSaver.save(mat, MATERIAL)
	var prev := OS.get_environment("TERRAIN_PREVIEW")
	if prev != "":
		img.save_png(prev + "/paths.png")
	report.append("paths: %d троп, %.0f px, маска %dx%d (%s)" % [lines.size(), total, w, h, error_string(err)])


func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var len := a.distance_to(b)
		var d := step - carry
		while d <= len:
			out.append(a.lerp(b, d / len))
			d += step
		carry = len - (d - step)
	out.append(pts[pts.size() - 1])
	return out


func _chaikin(pts: PackedVector2Array, iters: int) -> PackedVector2Array:
	var cur := pts
	for k in iters:
		var nxt := PackedVector2Array([cur[0]])
		for i in range(cur.size() - 1):
			nxt.append(cur[i].lerp(cur[i + 1], 0.25))
			nxt.append(cur[i].lerp(cur[i + 1], 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


# ───────────────────────── лес ─────────────────────────

func _step_thin(do_thin: bool, under := false) -> void:
	var lines: Array = []
	if FileAccess.file_exists(PATHS_JSON):
		for arr in JSON.parse_string(FileAccess.get_file_as_string(PATHS_JSON)):
			var pl := PackedVector2Array()
			for p in arr:
				pl.append(Vector2(p[0], p[1]))
			lines.append(pl)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	var atlas := load(ATLAS)
	for path in [MAP, CAMP]:
		var lvl := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var offset := Vector2.ZERO
		if path == CAMP:
			# Лагерь вставлен в карту со смещением — тропы в координатах карты
			var map := (load(MAP) as PackedScene).instantiate()
			offset = (map.get_node("Objects/RuinedCamp") as Node2D).position
			map.free()
		_thin_scene(lvl, lines, offset, atlas, meta, do_thin, under)
		if not _scene_ok(lvl):
			report.append("  %s НЕ сохранена: материал земли не загрузился — сначала godot --headless --path . --import" % path.get_file())
			lvl.free()
			continue
		var ps := PackedScene.new()
		var err := ps.pack(lvl)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		report.append("  %s сохранена: %s" % [path.get_file(), error_string(err)])
		lvl.free()


func _thin_scene(lvl: Node, lines: Array, offset: Vector2, atlas: Texture2D, meta: Dictionary, do_thin: bool, under := false) -> void:
	# Все клетки леса: [слой, клетка, позиция в мире карты, вид]
	var cells: Array = []
	for layer in lvl.find_children("*", "TileMapLayer", true, false):
		if not layer.y_sort_enabled or (layer != lvl and layer.owner != lvl):
			continue
		for c in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null or src.texture != atlas:
				continue
			var variant: String = src.get_meta("forest_variant", "")
			var kind: String = meta[variant]["kind"] if meta.has(variant) else ""
			var wp: Vector2 = lvl.to_local(layer.to_global(layer.map_to_local(c))) + offset
			cells.append([layer, c, wp, kind])
	var is_tree := func(k: String) -> bool:
		return k in ["oak_big", "maple_red", "birch_weeping", "fir_tall", "dead_big", "oak",
			"birch_autumn", "fir", "dead_broken"]
	# under — то же для подлеска: кусты, папоротник, камни, пни, коряги
	var pick := func(k: String) -> bool:
		return (k != "" and not is_tree.call(k)) if under else is_tree.call(k)
	var trees_before := 0
	for e in cells:
		if pick.call(e[3]):
			trees_before += 1
	var removed: Array = []        # позиции (в координатах сцены) убранных
	var on_path := 0
	var keep: Array = []
	for e in cells:
		if _near_path(e[2], lines, HALF_W + EDGE + 10.0):
			removed.append(e)
			on_path += 1
		elif pick.call(e[3]):
			keep.append(e)
	# Прореживание: остаются деревья не ближе R друг к другу
	# clear — без прореживания: только тропы (повторный запуск не редит лес ещё раз)
	var target := trees_before / 2 if do_thin else keep.size()
	var order := keep.duplicate()
	order.sort_custom(func(a, b): return hash(a[2]) < hash(b[2]))
	var lo := 0.0
	var hi := 200.0
	var chosen: Array = order
	for it in 18:
		var r := (lo + hi) * 0.5
		var sel := _poisson(order, r)
		if sel.size() > target:
			lo = r
		else:
			hi = r
		chosen = sel
	chosen = _poisson(order, hi) if do_thin else order
	var chosen_set := {}
	for e in chosen:
		chosen_set[e] = true
	var thinned := 0
	for e in keep:
		if not chosen_set.has(e):
			removed.append(e)
			thinned += 1
	# Декали листвы и сажи на тропах (плоские слои) — тропа должна читаться
	var decals := 0
	for dn in ["Grime", "SouthMarks"]:
		var dl := lvl.get_node_or_null(dn) as TileMapLayer
		if dl == null:
			continue
		for c in dl.get_used_cells():
			var dp: Vector2 = lvl.to_local(dl.to_global(dl.map_to_local(c))) + offset
			if _near_path(dp, lines, HALF_W + 22.0):
				dl.erase_cell(c)
				decals += 1
	# Убираем клетки и стволы
	var trunks := []
	for e in removed:
		(e[0] as TileMapLayer).erase_cell(e[1])
		trunks.append(e[2] - offset)
	var body := lvl.get_node_or_null("Collision")
	var cut := 0
	if body and body.get_script() and body.get_script().resource_path.ends_with("static_shapes.gd"):
		var shapes: Array = body.get("shapes")
		var xf: Array = body.get("shape_transforms")
		var ns: Array[Shape2D] = []
		var nx: Array[Transform2D] = []
		var bt: Transform2D = (body as Node2D).transform
		for i in shapes.size():
			var s: Shape2D = shapes[i]
			var o: Vector2 = bt * (xf[i] as Transform2D).origin
			var drop := false
			if s is RectangleShape2D and s.size.x <= 48.0 and s.size.y <= 48.0:
				for t in trunks:
					if o.distance_to(t) < 14.0:
						drop = true
						break
			if drop:
				cut += 1
			else:
				ns.append(s)
				nx.append(xf[i])
		body.set("shapes", ns)
		body.set("shape_transforms", nx)
	report.append("thin %s (%s): было %d, стало %d; с троп убрано %d клеток леса и %d декалей, прорежено %d, стволов из коллизии %d" % [
		lvl.name, "подлесок" if under else "деревья", trees_before, chosen.size(), on_path, decals, thinned, cut])


func _near_path(p: Vector2, lines: Array, dist: float) -> bool:
	for line in lines:
		for i in range(1, line.size()):
			var a: Vector2 = line[i - 1]
			var b: Vector2 = line[i]
			if p.x < minf(a.x, b.x) - dist or p.x > maxf(a.x, b.x) + dist \
					or p.y < minf(a.y, b.y) - dist or p.y > maxf(a.y, b.y) + dist:
				continue
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < dist:
				return true
	return false


## Жадный отбор: дерево остаётся, если рядом (ближе r) ещё нет оставленного
func _poisson(order: Array, r: float) -> Array:
	var grid := {}
	var cs := maxf(r, 1.0)
	var out: Array = []
	for e in order:
		var p: Vector2 = e[2]
		var gc := Vector2i(floor(p.x / cs), floor(p.y / cs))
		var ok := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for q in grid.get(gc + Vector2i(dx, dy), []):
					if (q as Vector2).distance_to(p) < r:
						ok = false
						break
				if not ok:
					break
			if not ok:
				break
		if ok:
			out.append(e)
			if not grid.has(gc):
				grid[gc] = []
			grid[gc].append(p)
	return out


## Доля серого камня (мостовой) в рисунке клетки атласа reskin (32x32)
static func _gray_share(img: Image, ac: Vector2i) -> float:
	var n := 0
	for y in range(0, 32, 2):
		for x in range(0, 32, 2):
			var c := img.get_pixel(ac.x * 32 + x, ac.y * 32 + y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			if c.a > 0.5 and mx - mn < 0.07 and l > 0.1 and l < 0.55:
				n += 1
	return n / 256.0


## Доля почти чёрных пикселей (провал) в клетке атласа reskin
static func _dark_share(img: Image, ac: Vector2i) -> float:
	var n := 0
	for y in range(0, 32, 2):
		for x in range(0, 32, 2):
			var c := img.get_pixel(ac.x * 32 + x, ac.y * 32 + y)
			if c.a > 0.5 and c.r * 0.3 + c.g * 0.59 + c.b * 0.11 < 0.035:
				n += 1
	return n / 256.0


# ───────────────────────── чёткие деревья ─────────────────────────
## Деревья без пиксельной сетки, но резче исходного атласа: каждый спрайт
## из сохранённого оригинала (textures/src/forest_trees_smooth.png) с
## нерезкой маской малого радиуса — мелкие листья и кора читаются, крупный
## свет не меняется. Альфа (контур) та же. Сцену трогать не нужно.
## После шага: godot --headless --path . --import
const SHARP_AMOUNT := 0.85


func _step_sharp() -> void:
	if _hd_atlas():
		return
	var atlas_path := ProjectSettings.globalize_path(ATLAS)
	var smooth_path := ProjectSettings.globalize_path(SMOOTH)
	if not FileAccess.file_exists(smooth_path):
		DirAccess.copy_absolute(atlas_path, smooth_path)
	var src := Image.load_from_file(smooth_path)
	src.convert(Image.FORMAT_RGBA8)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	var out := src.duplicate() as Image
	for name in meta:
		var r: Array = meta[name]["rect"]
		var rect := Rect2i(r[0], r[1], r[2], r[3])
		var im := src.get_region(rect)
		out.blit_rect(BT._unsharp(im, SHARP_AMOUNT), Rect2i(Vector2i.ZERO, rect.size), rect.position)
	var err := out.save_png(atlas_path)
	report.append("sharp: %d спрайтов леса, резкость %.2f (%s)" % [meta.size(), SHARP_AMOUNT, error_string(err)])


# ───────────────────────── листья ─────────────────────────
## Кучи опавших листьев (декали ruin_art) убираются со всей карты и из
## лагеря. Это только картинка на земле — коллизии у них нет.
const LEAF_REGIONS := [
	Rect2i(1706, 748, 256, 140), Rect2i(1332, 1068, 172, 110),
	Rect2i(364, 748, 348, 164), Rect2i(1036, 1560, 68, 44)]


func _step_leaves() -> void:
	for path in [MAP, CAMP]:
		var lvl := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var n := 0
		for layer in lvl.find_children("*", "TileMapLayer", true, false):
			if layer != lvl and layer.owner != lvl:
				continue
			for c in layer.get_used_cells():
				var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
				if src == null or src.texture == null or not src.texture.resource_path.ends_with("ruin_art.png"):
					continue
				if src.get_tile_texture_region(layer.get_cell_atlas_coords(c)) in LEAF_REGIONS:
					layer.erase_cell(c)
					n += 1
		if not _scene_ok(lvl):
			report.append("  %s НЕ сохранена: материал земли не загрузился — сначала godot --headless --path . --import" % path.get_file())
			lvl.free()
			continue
		var ps := PackedScene.new()
		var err := ps.pack(lvl)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		report.append("leaves %s: убрано %d куч листьев (%s)" % [path.get_file(), n, error_string(err)])
		lvl.free()


## Сцена загрузилась целиком? Если текстуры ещё не импортированы, у слоёв
## земли пропадает материал, и сохранять такую сцену нельзя
static func _scene_ok(lvl: Node) -> bool:
	var g := lvl.get_node_or_null("Ground") as CanvasItem
	return g == null or g.material != null


## Атлас леса теперь собирает tools/hd_art.gd из чётких картинок (src/hd);
## шаги pixel и sharp брали старый атлас и затёрли бы новый
func _hd_atlas() -> bool:
	if FileAccess.get_file_as_string(META).contains("tuft_0"):
		report.append("pixel/sharp пропущены: атлас леса из tools/hd_art.gd, старый исходник не нужен")
		return true
	return false
