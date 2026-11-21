extends SceneTree
## Невидимые упоры reference_map: прямоугольники коллизии, над которыми
## ничего не нарисовано (остатки деревьев и предметов, убранных при
## прореживании леса и чистке деревни — герой упирался в пустую траву).
##
##   godot --headless --path . -s res://tools/collision_audit.gd
##
## Пишет reference_map_level/invisible_collision.json — список [x, y, w, h,
## тело] (центр и размер в мире). Его применяет
## reference_map_level/scripts/invisible_collision.gd: в игре (Immersion) и
## при запекании навмеша (tools/bake_navmesh.gd).
##
## «Нарисовано» — по ПИКСЕЛЯМ (альфа > 0.5) всего, что стоит над землёй:
## Objects (спрайты и тайлы, с отражением и texture_origin), слои Town и
## Walls, мосты и настилы, пол форта, ферма, лицевые стороны обрывов и
## лестницы. Земля (трава, камень, грязь) рисунком не считается.
## Не трогаем: длинные (> MAX_SIDE — стены, границы), у края карты, у
## пропасти, оврага, воды и обрывов — там упор держит над пустотой.
## Список потом стоит проверить глазами (листы с рамками — см. отчёт).

const MAP := "res://reference_map_level/reference_map.tscn"
var OUT := "res://reference_map_level/invisible_collision.json"
## Ширина 9408: карта раздвинута tools/widen_map.gd (2026-11-18)
const WORLD := Rect2(-3520, -704, 9408, 5120)
const MAX_SIDE := 200.0
var MAX_COVER := 0.4
## Прямоугольник «чей-то», если рядом основание нарисованного предмета
## (позиция спрайта или клетка тайла с y_sort_origin, низ картинки)
const BASE_PAD := 20.0
## Проверено глазами (листы с рамками, 2026-11-17) и оставлено: основание
## стены руины и опоры арки форта, подножие башни форта, проход между двумя
## домами, у стволов берёз и вдоль границы леса, край тёмной воды на болоте
const KEEP := [Vector2(-824.0, 832.0), Vector2(-2728.0, 824.0), Vector2(1144.0, 984.0), Vector2(1672.0, 984.0), Vector2(-2936.0, 1632.0), Vector2(-1704.0, 3184.0), Vector2(-384.0, 3256.0), Vector2(-1704.0, 3888.0)]
## Мелочь (пучки травы, цветы) основанием не считается
const MIN_ITEM := 24.0
var _bases := {}
var _dbg := {}
const STEP := 4.0
const VOID_LAYERS := ["Canyon", "Chasm", "Water", "Cliffs"]
const ART_ROOTS := ["Objects", "Town", "Walls", "Bridges", "PortDecks", "BridgeDecks", "SouthBridges",
	"FortFloor", "FarmGround", "CliffFace", "CanyonFace", "CliffStairs0", "CliffStairs1"]
const RAVINE := "res://reference_map_level/textures/immersion/ravine_mask.res"
const HASH := 128.0

## {rect, inv (мир -> тексель), img, region, flip}
var _items: Array = []
var _hash := {}
var _imgs := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() >= 2:
		MAX_COVER = float(ua[0])
		OUT = ua[1]
	var t0 := Time.get_ticks_msec()
	var map: Node = (load(MAP) as PackedScene).instantiate()
	for nm in ["Immersion", "PlayerSpawn", "Objects/PlayerSpawn", "MusicManager", "RainSystem"]:
		var n := map.get_node_or_null(nm)
		if n:
			n.get_parent().remove_child(n)
			n.free()
	root.add_child(map)
	await process_frame
	for nm in ART_ROOTS:
		var n := map.get_node_or_null(nm)
		if n:
			_collect(n)
	print("art items: ", _items.size(), ", images: ", _imgs.size())
	var voids: Array[TileMapLayer] = []
	for nm in VOID_LAYERS:
		var l := map.get_node_or_null(nm) as TileMapLayer
		if l:
			voids.append(l)
	var ravine: Image = null
	var ravine_area := Rect2()
	if ResourceLoader.exists(RAVINE):
		var rt: Texture2D = load(RAVINE)
		ravine = rt.get_image()
		ravine_area = rt.get_meta("area", Rect2()) if rt.has_meta("area") else Rect2()
	var out := []
	var stats := {"rects": 0, "small": 0, "void": 0, "covered": 0, "invisible": 0}
	var inner := WORLD.grow(-64.0)
	for path in ["Collision", "Objects/RuinedCamp/Collision"]:
		var body := map.get_node_or_null(path) as Node2D
		if body == null:
			continue
		var shapes: Array = body.get("shapes")
		var trs: Array = body.get("shape_transforms")
		for i in shapes.size():
			var sh := shapes[i] as RectangleShape2D
			if sh == null:
				continue
			stats["rects"] += 1
			var t: Transform2D = body.global_transform * (trs[i] as Transform2D)
			var size := sh.size * t.get_scale().abs()
			var r := Rect2(t.origin - size * 0.5, size)
			if maxf(size.x, size.y) > MAX_SIDE or not inner.encloses(r):
				continue
			stats["small"] += 1
			if _near_void(r, voids) or _near_ravine(r, ravine, ravine_area):
				stats["void"] += 1
				continue
			var kept := false
			for k in KEEP:
				if (k as Vector2).distance_to(t.origin) < 1.0:
					kept = true
			if kept:
				stats["covered"] += 1
				continue
			var who := _owner(r.grow(BASE_PAD))
			var cov := _cover(r)
			if who != "":
				stats["covered"] += 1
				if cov < 0.15:
					_dbg[who.get_slice(" ", 0)] = _dbg.get(who.get_slice(" ", 0), 0) + 1
				continue
			if cov > MAX_COVER:
				stats["covered"] += 1
				continue
			stats["invisible"] += 1
			out.append([snappedf(t.origin.x, 0.01), snappedf(t.origin.y, 0.01), snappedf(size.x, 0.01), snappedf(size.y, 0.01), path, snappedf(cov, 0.001)])
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("stats: ", stats, ", ", Time.get_ticks_msec() - t0, " ms -> ", OUT)
	var keys := _dbg.keys()
	keys.sort_custom(func(a, b): return _dbg[a] > _dbg[b])
	for k in keys.slice(0, 25): print("  owned low-cover by ", k, ": ", _dbg[k])
	quit()


func _img(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _imgs.has(key):
		return _imgs[key]
	var img: Image = null
	if tex.resource_path.ends_with(".png"):
		img = Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
	else:
		img = tex.get_image()
	if img and img.is_compressed():
		img.decompress()
	if img:
		img.convert(Image.FORMAT_RGBA8)
	_imgs[key] = img
	return img


func _add(rect: Rect2, inv: Transform2D, img: Image, region: Rect2, flip: bool) -> void:
	if img == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var it := [rect, inv, img, region, flip]
	_items.append(it)
	var a := Vector2i((rect.position / HASH).floor())
	var b := Vector2i((rect.end / HASH).floor())
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var k := Vector2i(x, y)
			if not _hash.has(k):
				_hash[k] = []
			_hash[k].append(it)


func _base(p: Vector2, size: Vector2 = Vector2.ZERO, who: String = "") -> void:
	var k := Vector2i((p / 64.0).floor())
	if not _bases.has(k):
		_bases[k] = []
	_bases[k].append([p, size, who])


## Чей это прямоугольник: описание ближайшего основания или ""
func _owner(r: Rect2) -> String:
	var a := Vector2i((r.position / 64.0).floor())
	var b := Vector2i((r.end / 64.0).floor())
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var k := Vector2i(x, y)
			if _bases.has(k):
				for e in _bases[k]:
					if r.has_point(e[0]):
						return "%s %dx%d" % [e[2], int(e[1].x), int(e[1].y)]
	return ""


func _has_base(r: Rect2) -> bool:
	return _owner(r) != ""


func _collect(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Sprite2D and (n as Sprite2D).texture:
		var s := n as Sprite2D
		var img := _img(s.texture)
		var region := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, s.texture.get_size())
		var lr := s.get_rect()
		var gt := s.global_transform
		var bb := Rect2(gt * lr.position, Vector2.ZERO)
		for p in [lr.position + Vector2(lr.size.x, 0), lr.end, lr.position + Vector2(0, lr.size.y)]:
			bb = bb.expand(gt * p)
		# Мир -> локальные координаты спрайта -> доля прямоугольника
		var to_uv := Transform2D(Vector2(1.0 / lr.size.x, 0), Vector2(0, 1.0 / lr.size.y), -lr.position / lr.size) * gt.affine_inverse()
		_add(bb, to_uv, img, region, s.flip_h)
		if bb.size.x >= MIN_ITEM and bb.size.y >= MIN_ITEM:
			_base(s.global_position, bb.size, str(s.name))
			_base(Vector2(bb.get_center().x, bb.end.y), bb.size, str(s.name))
	elif n is TileMapLayer and (n as TileMapLayer).tile_set:
		var l := n as TileMapLayer
		var sc := l.global_scale.abs()
		var flags := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE
		for cell in l.get_used_cells():
			var src := l.tile_set.get_source(l.get_cell_source_id(cell)) as TileSetAtlasSource
			if src == null:
				continue
			var img := _img(src.texture)
			var coords := l.get_cell_atlas_coords(cell)
			var alt := l.get_cell_alternative_tile(cell)
			var region := Rect2(src.get_tile_texture_region(coords))
			var td := src.get_tile_data(coords, alt & ~flags)
			var origin := Vector2(td.texture_origin) if td else Vector2.ZERO
			var center := l.to_global(l.map_to_local(cell))
			var rect := Rect2(center + (-region.size * 0.5 - origin) * sc, region.size * sc)
			var to_uv := Transform2D(Vector2(1.0 / rect.size.x, 0), Vector2(0, 1.0 / rect.size.y), -rect.position / rect.size)
			_add(rect, to_uv, img, region, (alt & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0)
			if rect.size.x >= MIN_ITEM and rect.size.y >= MIN_ITEM:
				var ys := float(td.y_sort_origin) if td else 0.0
				_base(center + Vector2(0.0, ys) * sc, rect.size, str(l.name) + ":" + str(src.get_meta("forest_variant", src.get_meta("hd_prop", "src" + str(l.get_cell_source_id(cell))))))
				_base(Vector2(rect.get_center().x, rect.end.y), rect.size, str(l.name) + ":" + str(src.get_meta("forest_variant", src.get_meta("hd_prop", "src" + str(l.get_cell_source_id(cell))))))
	for c in n.get_children():
		# Чужие сцены (враги, лут, костры) — не рисунок карты
		if c.scene_file_path != "" and not c.scene_file_path.begins_with("res://reference_map_level/"):
			continue
		_collect(c)


func _opaque(p: Vector2) -> bool:
	var k := Vector2i((p / HASH).floor())
	if not _hash.has(k):
		return false
	for it in _hash[k]:
		var rect: Rect2 = it[0]
		if not rect.has_point(p):
			continue
		var uv: Vector2 = (it[1] as Transform2D) * p
		if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
			continue
		if it[4]:
			uv.x = 1.0 - uv.x
		var reg: Rect2 = it[3]
		var img: Image = it[2]
		var px := clampi(int(reg.position.x + uv.x * reg.size.x), 0, img.get_width() - 1)
		var py := clampi(int(reg.position.y + uv.y * reg.size.y), 0, img.get_height() - 1)
		if img.get_pixel(px, py).a > 0.5:
			return true
	return false


func _cover(r: Rect2) -> float:
	var hit := 0
	var all := 0
	var y := r.position.y + STEP * 0.5
	while y < r.end.y:
		var x := r.position.x + STEP * 0.5
		while x < r.end.x:
			all += 1
			if _opaque(Vector2(x, y)):
				hit += 1
			x += STEP
		y += STEP
	return 1.0 if all == 0 else float(hit) / float(all)


func _near_void(r: Rect2, voids: Array[TileMapLayer]) -> bool:
	var g := r.grow(48.0)
	for l in voids:
		var y := g.position.y
		while y <= g.end.y:
			var x := g.position.x
			while x <= g.end.x:
				if l.get_cell_source_id(l.local_to_map(l.to_local(Vector2(x, y)))) != -1:
					return true
				x += 16.0
			y += 16.0
	return false


func _near_ravine(r: Rect2, img: Image, area: Rect2) -> bool:
	if img == null or area.size == Vector2.ZERO:
		return false
	var g := r.grow(64.0)
	var y := g.position.y
	while y <= g.end.y:
		var x := g.position.x
		while x <= g.end.x:
			var uv := (Vector2(x, y) - area.position) / area.size
			if uv.x >= 0.0 and uv.y >= 0.0 and uv.x < 1.0 and uv.y < 1.0:
				if img.get_pixel(int(uv.x * img.get_width()), int(uv.y * img.get_height())).r > 0.3:
					return true
			x += 16.0
		y += 16.0
	return false
