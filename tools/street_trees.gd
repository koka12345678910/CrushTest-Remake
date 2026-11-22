extends SceneTree
## street_trees.gd — убирает деревья, выросшие на улицах Хольмвика.
##
## Дерево — клетка тайлового слоя (Objects/*) из источника атласа с меткой
## forest_variant (textures/forest_trees.png). Улица — мостовая по маске
## textures/terrain/cobble_map.res (R — «тут дорога», 4 мировых px на тексель).
## Дерево убирается, если его основание (центр клетки + y_sort_origin) стоит
## на мостовой: R в точке основания или в кольце STEM_R вокруг ≥ ROAD_MIN.
##
##   -- dry   (по умолчанию) — только список и картинка street_trees.png
##            в user:// с отметками;
##   -- apply — стирает клетки, сохраняет сцену. Потом: tools/bake_navmesh.gd
##            (у деревьев есть коллизия ствола).

const SCENE := "res://reference_map_level/reference_map.tscn"
const MASK := "res://reference_map_level/textures/terrain/cobble_map.res"
const WORLD := Rect2(-3520, -704, 9408, 5120)
const PX := 4.0
## Порог «тут мостовая» (R, 0..1) и радиус проверки у ствола, px
const ROAD_MIN := 0.2
const STEM_R := 40.0
## Коллизия ствола: прямоугольник не больше TRUNK_MAX, центр ближе TRUNK_NEAR
## к основанию убранного дерева
const TRUNK_MAX := 64.0
const TRUNK_NEAR := 28.0
## Контактная тень дерева — центр ближе этого к основанию
const SHADOW_NEAR := 14.0
## Только город (лес за стенами не трогаем даже на старых дорогах)
const TOWN := Rect2(-2400, 300, 4500, 2350)


func _initialize() -> void:
	var apply := "apply" in OS.get_cmdline_user_args()
	var packed := load(SCENE) as PackedScene
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var tex := load(MASK) as Texture2D
	var mask := tex.get_image()
	if mask.is_compressed():
		mask.decompress()
	var found := []
	var by_variant := {}
	for layer: TileMapLayer in _layers(root):
		var ts := layer.tile_set
		if ts == null:
			continue
		for cell in layer.get_used_cells():
			var sid := layer.get_cell_source_id(cell)
			var src := ts.get_source(sid) as TileSetAtlasSource
			if src == null or not src.has_meta("forest_variant"):
				continue
			var data := layer.get_cell_tile_data(cell)
			var base := layer.to_global(layer.map_to_local(cell)) + Vector2(0, data.y_sort_origin if data else 0)
			if not TOWN.has_point(base):
				continue
			if not _on_road(mask, base):
				continue
			var v := String(src.get_meta("forest_variant"))
			found.append([layer, cell, base, v])
			by_variant[v] = by_variant.get(v, 0) + 1
	print("[street_trees] деревьев на мостовой: ", found.size(), "  ", by_variant)
	for f in found:
		print("  ", f[0].name, " ", f[1], " основание ", (f[2] as Vector2).round(), " ", f[3])
	_debug_image(mask, found)
	# Коллизия ствола в Collision (массивы shapes / shape_transforms) — мелкий
	# прямоугольник у основания; без дерева он стал бы невидимой стеной
	var col := root.get_node_or_null("Collision")
	var drop := []
	if col and "shapes" in col:
		var shapes: Array = col.shapes
		var xf: Array = col.shape_transforms
		for i in shapes.size():
			var r := shapes[i] as RectangleShape2D
			if r == null or maxf(r.size.x, r.size.y) > TRUNK_MAX:
				continue
			var c: Vector2 = (xf[i] as Transform2D).origin
			for f in found:
				if c.distance_to(f[2]) <= TRUNK_NEAR:
					drop.append(i)
					print("  ствол: прямоугольник ", r.size, " у ", c, " (", f[3], ")")
					break
	print("[street_trees] коллизий стволов: ", drop.size())
	# Контактная тень под деревом (ContactShadows.data: x, y, полуширины, альфа)
	var cs := root.get_node_or_null("ContactShadows")
	var keep_sh := PackedFloat32Array()
	var sh_drop := 0
	if cs and "data" in cs:
		var d: PackedFloat32Array = cs.data
		for o in range(0, d.size(), 5):
			var p := Vector2(d[o], d[o + 1])
			var hit := false
			for f in found:
				if p.distance_to(f[2]) <= SHADOW_NEAR:
					hit = true
					break
			if hit:
				sh_drop += 1
				continue
			for k in 5:
				keep_sh.append(d[o + k])
	print("[street_trees] теней под деревьями: ", sh_drop)
	if apply and cs and sh_drop > 0:
		cs.data = keep_sh
	if apply and not found.is_empty():
		for f in found:
			(f[0] as TileMapLayer).erase_cell(f[1])
		if not drop.is_empty():
			var shapes: Array = col.shapes.duplicate()
			var xf: Array = col.shape_transforms.duplicate()
			drop.reverse()
			for i in drop:
				shapes.remove_at(i)
				xf.remove_at(i)
			col.shapes = shapes
			col.shape_transforms = xf
		var out := PackedScene.new()
		var err := out.pack(root)
		if err == OK:
			err = ResourceSaver.save(out, SCENE)
		print("[street_trees] сохранено: ", error_string(err))
	quit()


func _layers(root: Node) -> Array:
	var out := []
	var stack := [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TileMapLayer:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _r(mask: Image, p: Vector2) -> float:
	var x := int((p.x - WORLD.position.x) / PX)
	var y := int((p.y - WORLD.position.y) / PX)
	if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height():
		return 0.0
	return mask.get_pixel(x, y).r


func _on_road(mask: Image, base: Vector2) -> bool:
	if _r(mask, base) >= ROAD_MIN:
		return true
	for i in 16:
		var a := TAU * (i % 8) / 8.0
		var rr := STEM_R * (0.5 if i < 8 else 1.0)
		if _r(mask, base + Vector2(cos(a), sin(a) * 0.6) * rr) >= ROAD_MIN:
			return true
	return false


## Картинка города: мостовая серым, найденные деревья красным
func _debug_image(mask: Image, found: Array) -> void:
	var k := 4.0  # мировых px на пиксель картинки
	var w := int(TOWN.size.x / k)
	var h := int(TOWN.size.y / k)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var p := TOWN.position + Vector2(x + 0.5, y + 0.5) * k
			var r := _r(mask, p)
			img.set_pixel(x, y, Color(0.12, 0.16, 0.1).lerp(Color(0.55, 0.55, 0.55), r))
	for f in found:
		var c: Vector2 = ((f[2] as Vector2) - TOWN.position) / k
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2i(int(c.x) + dx, int(c.y) + dy)
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
					img.set_pixelv(q, Color(1, 0.1, 0.1))
	img.save_png(OS.get_user_data_dir() + "/street_trees.png")
	print("[street_trees] картинка: ", OS.get_user_data_dir() + "/street_trees.png")
