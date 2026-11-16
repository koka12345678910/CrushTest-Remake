extends Node
## light_shadows.gd — факелы reference_map больше не светят сквозь стены.
##
## Окклюдеры: прямоугольники коллизии карты и лагеря (дома, стены форта,
## частокол, обрывы, стволы деревьев) — напрямую в RenderingServer, без
## тысячи узлов LightOccluder2D. Вода окклюдером не становится (её полигоны —
## отдельные узлы, не в списке фигур).
##
## Тень только на земле. В Godot 4.7 shadow_item_cull_mask источника отбирает
## и окклюдеры, и то, на что тень ложится (проверено: предмет без этого бита
## за окклюдером остаётся освещён). Окклюдер дома лежит у его основания, а
## рисунок дома — выше, «за» ним: с тенью на всём стена, обращённая к факелу,
## почернела бы. Поэтому:
##   земля (слои под Objects, земля лагеря) получает бит GROUND_BIT;
##   огни карты: тень включена, shadow_item_cull_mask = GROUND_BIT | OCCLUDER_BIT;
##   окклюдеры — бит OCCLUDER_BIT;
##   дома, пропсы, герой, враги — без GROUND_BIT: освещены как раньше, без тени.
## Биты 8 и 16 уже заняты (тело героя и его тень, Levels/player_spawner.gd).

const GROUND_BIT := 64
const OCCLUDER_BIT := 128
## Имена огней из узла Night, которым нужна тень. Без тени: огоньки топи,
## фонтан, свечение босса (магия) и мелкие фонари со свечами — их много у
## причала, а каждый свет с тенью — отдельный проход (у причала было +2,4 мс)
const FIRE_PREFIXES := ["Torch", "Fire", "Camp", "Brazier", "Beacon"]

@export var shadow_smooth := 5.0
## Сколько огня всё же попадает в тень (отражённый свет от стен и земли)
@export_range(0.0, 1.0) var shadow_fill := 0.22
## Большие сплошные блоки (шатёр, глухой массив) дают уродливые прямоугольные
## тени на полкадра — окклюдер ставится, только если узкая сторона меньше этого
@export var max_thickness := 120.0
## Окклюдер ближе этого к огню — часть того же предмета, тени не даёт
@export var fire_margin := 32.0
## Окклюдер ставится, только если над такой долей его площади что-то нарисовано
@export_range(0.0, 1.0) var min_art_cover := 0.4
const ART_CELL := 32.0
var _art := {}

## Сколько ближайших к камере огней одновременно отбрасывают тень (каждый —
## отдельный проход по земле; у причала факелов больше десятка в кадре)
@export var max_shadow_lights := 3

var _fires: Array[PointLight2D] = []
var _check := 0.0
var _occluders: Array[RID] = []
var _polys: Array[RID] = []
var stats := {}


func setup(map: Node) -> void:
	var fires: Array[PointLight2D] = []
	var night := map.get_node_or_null("Night")
	if night:
		for l in night.get_children():
			if l is PointLight2D and _is_fire(str(l.name)):
				fires.append(l)
	var camp := map.get_node_or_null("Objects/RuinedCamp")
	if camp:
		var cn := camp.get_node_or_null("Night")
		if cn:
			for l in cn.get_children():
				if l is PointLight2D:
					fires.append(l)
		var co := camp.get_node_or_null("Objects")
		if co:
			for p in co.get_children():
				var f := p.get_node_or_null("Fire")
				if f and f.get_node_or_null("Light") is PointLight2D:
					fires.append(f.get_node("Light"))
	_fires = fires
	for l in fires:
		l.shadow_enabled = false
		l.shadow_item_cull_mask |= GROUND_BIT | OCCLUDER_BIT
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = shadow_smooth
		l.shadow_color = Color(l.color.r * shadow_fill, l.color.g * shadow_fill, l.color.b * shadow_fill, 1.0)
	# Земля принимает тени
	var ground := 0
	for c in map.get_children():
		if str(c.name) == "Objects":
			break
		ground += _to_ground(c)
	if camp:
		for nm in ["Ground", "Paving", "PavingEdge", "MudGround", "FloorDecals"]:
			var g := camp.get_node_or_null(nm)
			if g:
				ground += _to_ground(g)
	# Окклюдеры
	var lights := PackedVector2Array()
	for l in fires:
		lights.append(l.global_position)
	var canvas := (map as Node2D).get_world_2d().canvas
	_mark_art(map)
	var n := 0
	var skipped := 0
	var no_art := 0
	for path in ["Collision", "Objects/RuinedCamp/Collision"]:
		var body := map.get_node_or_null(path)
		if body == null or not "shapes" in body:
			continue
		var shapes: Array = body.get("shapes")
		var trs: Array = body.get("shape_transforms")
		var gt: Transform2D = (body as Node2D).global_transform
		for i in shapes.size():
			var s := shapes[i] as RectangleShape2D
			if s == null:
				continue
			var t: Transform2D = gt * (trs[i] as Transform2D)
			if minf(s.size.x, s.size.y) > max_thickness:
				skipped += 1
				continue
			var h := s.size * 0.5
			var pts := PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])
			# Огонь внутри окклюдера погас бы целиком, а вплотную к нему (фонарь
			# часовни, факел на столбе) — бросал бы от своего же предмета
			# огромную прямоугольную тень на полплощади: такой не ставим
			var bb := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				bb = bb.expand(p)
			var inside := false
			for lp in lights:
				if bb.grow(fire_margin).has_point(lp):
					inside = true
					break
			if inside:
				skipped += 1
				continue
			# Невидимая коллизия (над ней ничего не нарисовано) тень не бросает:
			# иначе на пустой траве появляется тёмный прямоугольник
			if _art_cover(bb) < min_art_cover:
				no_art += 1
				continue
			_add_occluder(canvas, pts)
			n += 1
	stats = {"fires": fires.size(), "ground_items": ground, "occluders": n, "skipped": skipped, "no_art": no_art}
	_art.clear()


## Где нарисованы предметы: основания спрайтов и клетки тайлов в Objects,
## лицевые стороны обрывов и лестницы. Клетки ART_CELL px.
func _mark_art(map: Node) -> void:
	_art.clear()
	var objects := map.get_node_or_null("Objects")
	if objects:
		_mark_node(objects)
	for nm in ["CliffFace", "CanyonFace", "CliffStairs0", "CliffStairs1"]:
		var s := map.get_node_or_null(nm) as Sprite2D
		if s and s.visible:
			_mark_rect(_sprite_rect(s))


func _mark_node(n: Node) -> void:
	for c in n.get_children():
		# Чужие сцены (враги, герой, лут) — не арт карты
		if c.scene_file_path != "" and not c.scene_file_path.begins_with("res://reference_map_level/"):
			continue
		# Земля лагеря (она внутри Objects) — не предмет
		if c is CanvasItem and ((c as CanvasItem).light_mask & GROUND_BIT) != 0:
			continue
		if c is Sprite2D and (c as Sprite2D).visible and (c as Sprite2D).texture:
			var r := _sprite_rect(c)
			# Основание: нижние 45% картинки — там стоит коллизия
			_mark_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.45, r.size.x, r.size.y * 0.45))
		elif c is TileMapLayer and (c as TileMapLayer).visible and (c as TileMapLayer).tile_set:
			var l := c as TileMapLayer
			var ts := Vector2(l.tile_set.tile_size) * l.global_scale.abs()
			for cell in l.get_used_cells():
				var p := l.to_global(l.map_to_local(cell))
				_mark_rect(Rect2(p - ts * 0.5, ts))
		_mark_node(c)


func _sprite_rect(s: Sprite2D) -> Rect2:
	var r := s.get_rect()
	var gt := s.global_transform
	var bb := Rect2(gt * r.position, Vector2.ZERO)
	for p in [r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
		bb = bb.expand(gt * p)
	return bb


func _mark_rect(r: Rect2) -> void:
	var a := Vector2i((r.position / ART_CELL).floor())
	var b := Vector2i((r.end / ART_CELL).floor())
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			_art[Vector2i(x, y)] = true


## Доля точек прямоугольника (шаг 16 px), над которыми что-то нарисовано
func _art_cover(r: Rect2) -> float:
	var hit := 0
	var all := 0
	var y := r.position.y + 8.0
	while y < r.end.y:
		var x := r.position.x + 8.0
		while x < r.end.x:
			all += 1
			if _art.has(Vector2i((Vector2(x, y) / ART_CELL).floor())):
				hit += 1
			x += 16.0
		y += 16.0
	return 1.0 if all == 0 else float(hit) / float(all)


func _is_fire(nm: String) -> bool:
	for p in FIRE_PREFIXES:
		if nm.begins_with(p):
			return true
	return false


func _to_ground(n: Node) -> int:
	var count := 0
	if n is CanvasItem and not n is CanvasLayer:
		(n as CanvasItem).light_mask |= GROUND_BIT
		count += 1
	for c in n.get_children():
		count += _to_ground(c)
	return count


func _add_occluder(canvas: RID, pts: PackedVector2Array) -> void:
	var poly := RenderingServer.canvas_occluder_polygon_create()
	RenderingServer.canvas_occluder_polygon_set_shape(poly, pts, true)
	var occ := RenderingServer.canvas_light_occluder_create()
	RenderingServer.canvas_light_occluder_attach_to_canvas(occ, canvas)
	RenderingServer.canvas_light_occluder_set_polygon(occ, poly)
	RenderingServer.canvas_light_occluder_set_light_mask(occ, OCCLUDER_BIT)
	RenderingServer.canvas_light_occluder_set_enabled(occ, true)
	_polys.append(poly)
	_occluders.append(occ)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _fires.is_empty():
		return
	_check = 0.25
	var vp := get_viewport()
	var cam: Vector2 = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)
	var order: Array = []
	for i in _fires.size():
		if is_instance_valid(_fires[i]):
			order.append([_fires[i].global_position.distance_squared_to(cam), i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for j in order.size():
		var l := _fires[order[j][1]]
		var on: bool = j < max_shadow_lights and order[j][0] < 1100.0 * 1100.0
		if l.shadow_enabled != on:
			l.shadow_enabled = on


func _exit_tree() -> void:
	for o in _occluders:
		RenderingServer.free_rid(o)
	for p in _polys:
		RenderingServer.free_rid(p)
	_occluders.clear()
	_polys.clear()
