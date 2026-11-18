extends Node
## breakables.gd — бочки и ящики reference_map разбиваются и не стоят стеной.
##
## Раньше это были картинки (спрайты карты и лагеря, тайлы hd_props) с
## твёрдым прямоугольником в общей коллизии: герой упирался в невидимый
## край, ломать их было нельзя. Здесь при старте каждая бочка/ящик
## становится разбиваемым предметом (Levels/props/breakable_prop.gd, как на
## кладбище), а её прямоугольник из коллизии карты убирается:
##   - удар любого героя (меч, стрела, заклинание) — трещит и ломается;
##   - Хальвард влетает в предмет — разлом сразу (touch_break);
##   - упора нет: тело героя в предмет не упирается.
## Сцена на диске не меняется. Навмеш запечён с этими препятствиями — враги
## по-прежнему их обходят (ямки в навмеше маленькие, это не мешает).
##
## Узлы получают одинаковые имена у всех игроков (порядок обхода один), так
## что в коопе разлом передаётся (Net.world_event "break").
## Строится ДО теней (light_shadows.gd читает коллизию) и до нормалей.

const BREAKABLE := preload("res://Levels/props/breakable_prop.gd")
const INVISIBLE := preload("res://reference_map_level/scripts/invisible_collision.gd")
## Имя hd_prop -> [прочность, шанс монет] (как на кладбище)
const KINDS := {
	"barrel": [2, 0.35], "barrels2": [3, 0.4], "crate": [2, 0.4],
	"crates_stack": [3, 0.5], "port_crates_tarp": [3, 0.4],
}
## Разбивает касанием только Хальвард (рыцарь)
const TOUCH_SCENES := ["res://Player_scene/player.tscn"]
const CHIP_BARREL := Color(0.4, 0.27, 0.16)
const CHIP_CRATE := Color(0.47, 0.35, 0.23)

var stats := {}
var _n := 0
var _fade: Material


func setup(map: Node) -> void:
	var of := map.get_node_or_null("OcclusionFade")
	_fade = of.get("_material") if of else null
	var feet: Array[Rect2] = []
	for path in ["Objects", "Objects/RuinedCamp/Objects"]:
		var root := map.get_node_or_null(path)
		if root == null:
			continue
		for c in root.get_children():
			if c is Sprite2D and c.has_meta("hd_prop"):
				var meta := str(c.get_meta("hd_prop"))
				if KINDS.has(meta.get_slice("@", 0)):
					feet.append(_from_sprite(c as Sprite2D, meta))
			elif c is TileMapLayer:
				feet.append_array(_from_tiles(c as TileMapLayer))
	var removed := 0
	for path in ["Collision", "Objects/RuinedCamp/Collision"]:
		removed += _remove_shapes(map.get_node_or_null(path), feet)
	# Заодно — невидимые упоры на пустой траве и тропах (список проверен)
	var invisible := INVISIBLE.apply(map)
	stats = {"props": _n, "collision_removed": removed, "invisible_removed": invisible}


## Спрайт карты переезжает внутрь разбиваемого предмета (все его свойства —
## отражение, смещение, материал — остаются как были)
func _from_sprite(s: Sprite2D, meta: String) -> Rect2:
	var parent := s.get_parent()
	var index := s.get_index()
	var base := s.global_position
	var gs := s.global_scale
	# Картинка — AtlasTexture: из неё breakable_prop.gd режет обломки
	var region := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, s.texture.get_size())
	var at := AtlasTexture.new()
	at.atlas = s.texture
	at.region = region
	if s.centered:
		s.offset -= region.size * 0.5
		s.centered = false
	s.region_enabled = false
	s.texture = at
	if s.material == null:
		s.material = _fade
	parent.remove_child(s)
	s.name = "Sprite"
	s.position = Vector2.ZERO
	s.rotation = 0.0
	s.scale = gs
	var body := _make(meta, s)
	parent.add_child(body)
	parent.move_child(body, index)
	body.global_position = base
	return _foot(_sprite_rect(s))


## Тайлы бочек/ящиков слоя -> предметы; клетки стираются
func _from_tiles(l: TileMapLayer) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var ts := l.tile_set
	if ts == null:
		return out
	for si in ts.get_source_count():
		var sid := ts.get_source_id(si)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null or not src.has_meta("hd_prop"):
			continue
		var meta := str(src.get_meta("hd_prop"))
		if not KINDS.has(meta.get_slice("@", 0)):
			continue
		for cell in l.get_used_cells_by_id(sid):
			var coords := l.get_cell_atlas_coords(cell)
			var alt := l.get_cell_alternative_tile(cell)
			var flags := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE
			var td := src.get_tile_data(coords, alt & ~flags)
			var region := Rect2(src.get_tile_texture_region(coords))
			var origin := Vector2(td.texture_origin) if td else Vector2.ZERO
			var ysort := float(td.y_sort_origin) if td else 0.0
			var sc := l.global_scale
			var center := l.to_global(l.map_to_local(cell))
			var base := center + Vector2(0.0, ysort) * sc
			# Тайл рисуется по центру клетки со сдвигом -texture_origin
			var top_left := center + (-region.size * 0.5 - origin) * sc
			var at := AtlasTexture.new()
			at.atlas = src.texture
			at.region = region
			var s := Sprite2D.new()
			s.name = "Sprite"
			s.texture = at
			s.centered = false
			s.offset = (top_left - base) / sc
			s.scale = sc
			s.flip_h = (alt & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
			s.texture_filter = l.texture_filter
			var mat: Material = td.material if td and td.material else l.material
			s.material = mat if mat else _fade
			var body := _make(meta, s)
			var parent := l.get_parent()
			parent.add_child(body)
			parent.move_child(body, l.get_index() + 1)
			body.global_position = base
			out.append(_foot(_sprite_rect(s)))
			l.erase_cell(cell)
	return out


## Разбиваемый предмет: тело без упора, картинка, Hurtbox (удары) и Touch
## (тело героя у основания). Все дети — до входа в дерево, чтобы _ready
## breakable_prop.gd их нашёл
func _make(meta: String, s: Sprite2D) -> StaticBody2D:
	var kind := meta.get_slice("@", 0)
	var b := StaticBody2D.new()
	_n += 1
	b.name = "Breakable_%s_%d" % [kind, _n]
	b.collision_layer = 0
	b.collision_mask = 0
	b.set_meta("hd_prop", meta)
	b.set_script(BREAKABLE)
	var k: Array = KINDS[kind]
	b.set("hits", k[0])
	b.set("loot_chance", k[1])
	b.set("chip_color", CHIP_BARREL if kind.begins_with("barrel") else CHIP_CRATE)
	b.set("touch_break", true)
	b.set("touch_scenes", PackedStringArray(TOUCH_SCENES))
	b.add_child(s)
	# Прямоугольник картинки в координатах тела
	var r := s.get_rect()
	r = Rect2(r.position * s.scale, r.size * s.scale).abs()
	b.set("pieces", Vector2i(clampi(roundi(r.size.x / 28.0), 2, 4), clampi(roundi(r.size.y / 28.0), 2, 3)))
	var hb := Area2D.new()
	hb.name = "Hurtbox"
	hb.collision_layer = 0
	hb.collision_mask = 1
	b.add_child(hb)
	var hcs := CollisionShape2D.new()
	var hsh := RectangleShape2D.new()
	hsh.size = r.size * 0.88
	hcs.shape = hsh
	hcs.position = r.get_center()
	hb.add_child(hcs)
	var touch := Area2D.new()
	touch.name = "Touch"
	touch.collision_layer = 0
	touch.collision_mask = 2
	b.add_child(touch)
	var tcs := CollisionShape2D.new()
	var tsh := RectangleShape2D.new()
	tsh.size = Vector2(r.size.x * 0.7, maxf(r.size.y * 0.22, 10.0))
	tcs.shape = tsh
	tcs.position = Vector2(r.get_center().x, r.end.y - tsh.size.y * 0.5)
	touch.add_child(tcs)
	return b


func _sprite_rect(s: Sprite2D) -> Rect2:
	var r := s.get_rect()
	var gt := s.global_transform
	var bb := Rect2(gt * r.position, Vector2.ZERO)
	for p in [r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
		bb = bb.expand(gt * p)
	return bb


## Основание предмета: нижние 45% картинки и чуть ниже — там стоял его
## твёрдый прямоугольник
func _foot(r: Rect2) -> Rect2:
	return Rect2(r.position.x - 8.0, r.end.y - r.size.y * 0.45, r.size.x + 16.0, r.size.y * 0.45 + 12.0)


## Убрать из коллизии прямоугольники, чей центр в основании предмета и
## которые не больше его (стена рядом не заденется)
func _remove_shapes(body: Node, feet: Array[Rect2]) -> int:
	if body == null or not "shapes" in body:
		return 0
	var shapes: Array = body.get("shapes")
	var trs: Array = body.get("shape_transforms")
	var gt: Transform2D = (body as Node2D).global_transform
	var kill: Array[int] = []
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		if s == null:
			continue
		var t: Transform2D = gt * (trs[i] as Transform2D)
		var size := s.size * t.get_scale().abs()
		for f in feet:
			if not f.has_point(t.origin):
				continue
			# До 1.8 ширины: бывает общий прямоугольник на два ящика или чуть
			# шире картинки (мелкие ящики форта, 48 при 30). Тонкая полоса
			# (до 16 px) под основанием — до 2.2 ширины: остаток ряда старых
			# ящиков у брезента. Стена рядом (длинная) и шатёр — больше
			var wide := size.x <= maxf(f.size.x * 1.8, f.size.x + 24.0)
			var strip := size.y <= 16.0 and size.x <= f.size.x * 2.2
			if (wide or strip) and size.y <= maxf(f.size.y * 1.5, 48.0):
				kill.append(i)
				break
	# Владельца фигуры в физике ищем по самой фигуре и её трансформу, НЕ по
	# номеру: полигоны воды (дочерние CollisionPolygon2D) регистрируются
	# раньше и занимают первые номера — по номеру удалилась бы вода
	var co := body as CollisionObject2D
	kill.reverse()
	for i in kill:
		for id in co.get_shape_owners():
			if co.shape_owner_get_owner(id) != body or co.shape_owner_get_shape_count(id) == 0:
				continue
			if co.shape_owner_get_shape(id, 0) == shapes[i] and co.shape_owner_get_transform(id).is_equal_approx(trs[i]):
				co.remove_shape_owner(id)
				break
		shapes.remove_at(i)
		trs.remove_at(i)
	body.set("shapes", shapes)
	body.set("shape_transforms", trs)
	return kill.size()
