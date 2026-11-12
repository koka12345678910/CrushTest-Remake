extends SceneTree
## Меньше узлов на reference_map без изменения карты.
##
##   collapse — 1700+ узлов CollisionShape2D карты и лагеря → по одному телу
##              со списком фигур (Levels/static_shapes.gd); ~200 плоских
##              декалей лагеря → один узел (Levels/sprite_batch.gd);
##              добавляет на карту EnemySleep (Levels/enemy_sleep.gd).
##   expand   — обратно в отдельные узлы, чтобы поправить коллизию или
##              декали руками в редакторе; потом снова collapse.
##
## Запуск:
##   godot --headless --path . -s res://tools/optimize_map.gd -- collapse
## Физика, навмеш и картинка не меняются: те же фигуры с теми же
## трансформами, те же спрайты в том же порядке.

const MAP := "res://reference_map_level/reference_map.tscn"
const CAMP := "res://reference_map_level/ruined_camp.tscn"
const STATIC_SHAPES := preload("res://Levels/static_shapes.gd")
const SPRITE_BATCH := preload("res://Levels/sprite_batch.gd")
const ENEMY_SLEEP := preload("res://Levels/enemy_sleep.gd")

var report: Array[String] = []


func _initialize() -> void:
	var mode := "collapse"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	var ok := true
	for spec in [[MAP, ["Collision"], [], true], [CAMP, ["Collision"], ["FloorDecals"], false]]:
		var root := (load(spec[0]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		for p in spec[1]:
			if mode == "collapse":
				_collapse_shapes(root, p)
			else:
				_expand_shapes(root, p)
		for p in spec[2]:
			if mode == "collapse":
				ok = _collapse_sprites(root, p) and ok
			else:
				_expand_sprites(root, p)
		if spec[3]:
			_enemy_sleep(root, mode == "collapse")
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, spec[0])
		report.append("%s сохранена: %s" % [spec[0].get_file(), error_string(err)])
		ok = ok and err == OK
		root.free()
	for r in report:
		print(r)
	quit(0 if ok else 1)


# ───────────────────────── коллизия ─────────────────────────

func _collapse_shapes(root: Node, path: String) -> void:
	var body := root.get_node(path) as StaticBody2D
	var shapes: Array[Shape2D] = []
	var xforms: Array[Transform2D] = []
	if body.get_script() == STATIC_SHAPES:
		shapes.assign(body.get("shapes"))
		xforms.assign(body.get("shape_transforms"))
	var moved := 0
	for c in body.get_children():
		# Только простые: без отключения, без «односторонности», без детей
		if c is CollisionShape2D and c.shape != null and not c.disabled \
				and not c.one_way_collision and c.get_child_count() == 0:
			shapes.append(c.shape)
			xforms.append(c.transform)
			body.remove_child(c)
			c.free()
			moved += 1
	body.set_script(STATIC_SHAPES)
	body.set("shapes", shapes)
	body.set("shape_transforms", xforms)
	report.append("%s/%s: %d узлов коллизии → список (%d фигур), остались узлами: %d" % [
		root.name, path, moved, shapes.size(), body.get_child_count()])


func _expand_shapes(root: Node, path: String) -> void:
	var body := root.get_node(path) as StaticBody2D
	if body.get_script() != STATIC_SHAPES:
		return
	var shapes: Array = body.get("shapes")
	var xforms: Array = body.get("shape_transforms")
	for i in shapes.size():
		var cs := CollisionShape2D.new()
		cs.name = "R%d" % i
		cs.shape = shapes[i]
		cs.transform = xforms[i]
		body.add_child(cs)
		cs.owner = root
	body.set_script(null)
	report.append("%s/%s: %d фигур → узлы" % [root.name, path, shapes.size()])


# ───────────────────────── декали ─────────────────────────

func _collapse_sprites(root: Node, path: String) -> bool:
	var holder := root.get_node(path) as Node2D
	if holder.get_script() == SPRITE_BATCH:
		return true
	var textures: Array[Texture2D] = []
	var data := PackedFloat32Array()
	var sprites: Array[Sprite2D] = []
	for c in holder.get_children():
		var s := c as Sprite2D
		# Свёртываем, только если всё рисуется одинаково — иначе порядок
		# отрисовки разошёлся бы с оставшимися узлами
		if s == null or s.get_child_count() > 0 or s.material != null or not s.visible \
				or s.rotation != 0.0 or s.skew != 0.0 or s.z_index != 0 \
				or s.modulate != Color.WHITE or s.self_modulate != Color.WHITE \
				or s.hframes != 1 or s.vframes != 1 or s.texture == null \
				or s.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE \
				or s.get_script() != null:
			report.append("%s/%s: %s не простой спрайт — декали не тронуты" % [root.name, path, c.name])
			return false
		sprites.append(s)
	for s in sprites:
		var ti := textures.find(s.texture)
		if ti < 0:
			textures.append(s.texture)
			ti = textures.size() - 1
		var r := s.region_rect if s.region_enabled else Rect2()
		var flags := (1 if s.centered else 0) | (2 if s.flip_h else 0) | (4 if s.flip_v else 0)
		data.append_array(PackedFloat32Array([ti, s.position.x, s.position.y, s.scale.x, s.scale.y,
			s.offset.x, s.offset.y, r.position.x, r.position.y, r.size.x, r.size.y, flags]))
		holder.remove_child(s)
		s.free()
	holder.set_script(SPRITE_BATCH)
	holder.set("textures", textures)
	holder.set("data", data)
	report.append("%s/%s: %d спрайтов → один узел (%d текстур)" % [
		root.name, path, sprites.size(), textures.size()])
	return true


func _expand_sprites(root: Node, path: String) -> void:
	var holder := root.get_node(path) as Node2D
	if holder.get_script() != SPRITE_BATCH:
		return
	var textures: Array = holder.get("textures")
	var data: PackedFloat32Array = holder.get("data")
	var n := data.size() / 12
	holder.set_script(null)
	for i in n:
		var b := i * 12
		var s := Sprite2D.new()
		s.name = "S%d" % i
		s.texture = textures[int(data[b])]
		s.position = Vector2(data[b + 1], data[b + 2])
		s.scale = Vector2(data[b + 3], data[b + 4])
		s.offset = Vector2(data[b + 5], data[b + 6])
		if data[b + 9] > 0.0:
			s.region_enabled = true
			s.region_rect = Rect2(data[b + 7], data[b + 8], data[b + 9], data[b + 10])
		var flags := int(data[b + 11])
		s.centered = (flags & 1) != 0
		s.flip_h = (flags & 2) != 0
		s.flip_v = (flags & 4) != 0
		holder.add_child(s)
		s.owner = root
	report.append("%s/%s: %d спрайтов → узлы" % [root.name, path, n])


# ───────────────────────── враги ─────────────────────────

func _enemy_sleep(root: Node, add: bool) -> void:
	var old := root.get_node_or_null("EnemySleep")
	if add and old == null:
		var n := Node.new()
		n.name = "EnemySleep"
		n.set_script(ENEMY_SLEEP)
		root.add_child(n)
		n.owner = root
		report.append("EnemySleep добавлен")
