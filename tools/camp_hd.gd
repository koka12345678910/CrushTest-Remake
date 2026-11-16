extends SceneTree
## Разорённый лагерь (ruined_camp.tscn) в общем HD-стиле карты.
##
## Исходники (src/hd, от GPT): ground_camp_mud / ground_camp_ash — плитки
## земли; props/camp_palisade, camp_battlefield, camp_fire, camp_military —
## листы предметов.
##
## Шаги:
##   bake  — textures/camp_hd.png (+ .json): все предметы одним атласом;
##           textures/terrain/camp_mud.png, camp_ash.png — бесшовные плитки.
##           Рядом кладутся .import, потом нужен импорт.
##   apply — сцена лагеря. Каждый запуск начинается с копии лагеря до первой
##           правки (textures/src/camp_before_hd.tscn.txt), так что шаг можно
##           повторять:
##           земля — трава карты (её шейдер) + грязь и пепел своим шейдером
##             (shaders/camp_ground.gdshader, маска terrain/camp_ground_mask.res);
##           декали на земле — новые (кровь, воронки, щиты, шлемы, оружие),
##             ТРУПОВ НЕТ: старые убраны, новые не ставятся;
##           частокол — новые секции; боковые стены (3 столбца кольев) — один
##             ряд брёвен;
##           четыре шатра — сгоревшие и рухнувшие;
##           новые пропсы (костёр, жаровни, факелы, котёл, военный быт,
##             вышка, рогатки) со своим светом и коллизией у основания.
##
## Запуск:
##   godot --headless --path . -s res://tools/camp_hd.gd -- bake
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/camp_hd.gd -- apply
##   godot --headless --path . -s res://tools/bake_navmesh.gd -- res://reference_map_level/reference_map.tscn res://reference_map_level/navmesh.res

const AU := preload("res://tools/art_util.gd")
const CAMP := "res://reference_map_level/ruined_camp.tscn"
const BACKUP := "res://reference_map_level/textures/src/camp_before_hd.tscn.txt"
const HD := "res://reference_map_level/textures/src/hd/"
const TEX := "res://reference_map_level/textures/"
const ATLAS := TEX + "camp_hd.png"
const META := TEX + "camp_hd.json"
const MUD := TEX + "terrain/camp_mud.png"
const ASH := TEX + "terrain/camp_ash.png"
const MASK := TEX + "terrain/camp_ground_mask.res"
const GROUND_MAT := TEX + "terrain/ground_material.tres"
const GROUND_SHADER := "res://reference_map_level/shaders/camp_ground.gdshader"
const HD_PROPS_META := TEX + "hd_props.json"
const CAMPFIRE := "res://Levels/props/campfire.tscn"
const TPX := 2

const SHEETS := {
	"pal": "props/camp_palisade",
	"bf": "props/camp_battlefield",
	"fire": "props/camp_fire",
	"mil": "props/camp_military",
}

## Предметы: [лист, прямоугольник на листе, "w"|"h", размер на карте в px мира]
const PIECES := {
	"pal_front": ["pal", Rect2i(122, 138, 404, 248), "w", 126.0],
	"pal_broken_l": ["pal", Rect2i(862, 486, 282, 236), "w", 100.0],
	"pal_broken_r": ["pal", Rect2i(1146, 488, 332, 238), "w", 100.0],
	"log_a": ["pal", Rect2i(124, 138, 50, 248), "h", 72.0],
	"log_b": ["pal", Rect2i(274, 138, 50, 248), "h", 72.0],
	"tower": ["pal", Rect2i(440, 434, 314, 556), "h", 150.0],
	"cheval": ["pal", Rect2i(850, 800, 610, 198), "w", 110.0],
	"blood_a": ["bf", Rect2i(100, 306, 316, 110), "w", 64.0],
	"blood_b": ["bf", Rect2i(588, 284, 324, 138), "w", 64.0],
	"blood_c": ["bf", Rect2i(1074, 306, 336, 112), "w", 64.0],
	"crater_a": ["bf", Rect2i(24, 456, 360, 230), "w", 120.0],
	"crater_b": ["bf", Rect2i(402, 432, 406, 276), "w", 140.0],
	"shield": ["bf", Rect2i(838, 460, 212, 202), "w", 34.0],
	"shield_split": ["bf", Rect2i(1082, 464, 216, 200), "w", 34.0],
	"helmet": ["bf", Rect2i(1360, 500, 120, 128), "w", 20.0],
	"sword": ["bf", Rect2i(28, 706, 132, 270), "h", 46.0],
	"banner_ground": ["bf", Rect2i(1148, 698, 366, 294), "w", 76.0],
	"spear": ["bf", Rect2i(206, 792, 404, 174), "w", 78.0],
	"arrows": ["bf", Rect2i(602, 748, 200, 220), "h", 34.0],
	"bow": ["bf", Rect2i(804, 790, 394, 190), "w", 64.0],
	"torch": ["fire", Rect2i(930, 28, 110, 464), "h", 92.0],
	"cauldron": ["fire", Rect2i(1084, 26, 424, 474), "h", 72.0],
	"bonfire": ["fire", Rect2i(62, 124, 468, 380), "w", 104.0],
	"brazier": ["fire", Rect2i(620, 168, 220, 284), "h", 48.0],
	"tent_burnt": ["fire", Rect2i(18, 522, 708, 470), "w", 150.0],
	"tent_collapsed": ["fire", Rect2i(744, 546, 768, 456), "w", 160.0],
	"rack": ["mil", Rect2i(22, 18, 360, 420), "w", 68.0],
	"drum": ["mil", Rect2i(758, 40, 292, 392), "h", 60.0],
	"table": ["mil", Rect2i(1088, 96, 416, 332), "w", 72.0],
	"shields": ["mil", Rect2i(410, 136, 320, 282), "w", 54.0],
	"standard": ["mil", Rect2i(544, 414, 238, 582), "h", 132.0],
	"supply": ["mil", Rect2i(20, 522, 502, 450), "w", 96.0],
	"pikes": ["mil", Rect2i(1154, 526, 328, 440), "h", 76.0],
	"target": ["mil", Rect2i(768, 628, 328, 344), "h", 60.0],
}

## Старые декали (кусок camp_sprites.png "x,y,w,h") -> новые, [] — убрать.
## Убираются трупы и старая кучка угля
const DECALS := {
	"0,1438,156,134": [], "1222,1438,174,128": [], "160,1438,134,134": [],
	"1898,1438,188,120": [], "2286,1224,168,156": [], "2458,1224,184,148": [],
	"298,1438,164,132": [], "466,1438,214,132": [], "260,1576,160,94": [],
	"0,1576,116,96": ["blood_a", "blood_b", "blood_c"],
	"1038,1438,180,128": ["blood_b", "blood_c", "blood_a"],
	"120,1576,136,94": ["blood_c", "blood_a"],
	"1734,1438,160,122": ["blood_a", "blood_b"],
	"1024,1576,56,54": ["helmet"], "1084,1576,54,52": ["helmet"], "1142,1576,54,50": ["helmet"],
	"1200,1576,168,30": ["spear"],
	"1048,918,436,244": ["crater_a"], "836,0,766,572": ["crater_b"],
	"2740,1438,222,100": ["bow", "spear"],
	"616,1576,70,72": ["shield", "shield_split"], "690,1576,68,72": ["shield_split", "shield"],
	"762,1576,78,64": ["arrows"], "844,1576,74,58": ["sword"],
}
## Во сколько раз новая декаль шире старой (кровь у старых — с брызгами)
const DECAL_K := {"blood_a": 0.85, "blood_b": 0.85, "blood_c": 0.85, "crater_a": 0.75, "crater_b": 0.6}

## Сгоревшие и рухнувшие шатры: позиция старого шатра -> новый
const BURNT := {
	Vector2(1640, 1000): "tent_burnt",
	Vector2(2580, 1030): "tent_burnt",
	Vector2(290, 1040): "tent_collapsed",
	Vector2(930, 1330): "tent_collapsed",
}
## Боковые стены: x средней колонки кольев (две крайние убираются)
const SIDE_COLUMNS := [440.0, 2440.0]

## Новые пропсы: [предмет, желаемая точка основания (лагерь), коллизия w x h
## у основания (ZERO — без), огонь: "" | "big" | "brazier" | "torch"]
const PLACE := [
	["bonfire", Vector2(1330, 900), Vector2(70, 24), "big"],
	["cauldron", Vector2(1430, 870), Vector2(40, 14), ""],
	["brazier", Vector2(2120, 840), Vector2(22, 12), "brazier"],
	["brazier", Vector2(2360, 840), Vector2(22, 12), "brazier"],
	["brazier", Vector2(1330, 720), Vector2(22, 12), "brazier"],
	["torch", Vector2(275, 255), Vector2(12, 8), "torch"],
	["torch", Vector2(425, 255), Vector2(12, 8), "torch"],
	["torch", Vector2(120, 1190), Vector2(12, 8), "torch"],
	["torch", Vector2(120, 1310), Vector2(12, 8), "torch"],
	["torch", Vector2(1980, 1160), Vector2(12, 8), "torch"],
	["torch", Vector2(820, 1120), Vector2(12, 8), "torch"],
	["tower", Vector2(540, 300), Vector2(60, 22), ""],
	["standard", Vector2(2240, 790), Vector2(10, 8), ""],
	["standard", Vector2(1560, 640), Vector2(10, 8), ""],
	["rack", Vector2(1560, 760), Vector2(54, 14), ""],
	["table", Vector2(1250, 690), Vector2(56, 16), ""],
	["drum", Vector2(2390, 960), Vector2(34, 14), ""],
	["shields", Vector2(900, 1060), Vector2(40, 12), ""],
	["supply", Vector2(1770, 400), Vector2(80, 20), ""],
	["pikes", Vector2(200, 1100), Vector2(50, 10), ""],
	["target", Vector2(520, 1180), Vector2(30, 10), ""],
	["cheval", Vector2(230, 1180), Vector2(90, 16), ""],
	["cheval", Vector2(230, 1330), Vector2(90, 16), ""],
	["shields", Vector2(2100, 1000), Vector2(40, 12), ""],
]
## Россыпь новых декалей (кроме тех, что заменили старые): [предмет, сколько]
const SCATTER := [["arrows", 9], ["sword", 4], ["spear", 4], ["shield", 4], ["helmet", 4],
		["bow", 3], ["banner_ground", 3], ["blood_a", 3], ["blood_c", 3]]

## Где держать пусто: точки врагов и событий (лагерь), радиус
const KEEP_CLEAR := [
	[Vector2(1058, 524), 60.0], [Vector2(1208, 424), 60.0], [Vector2(1508, 824), 60.0],
	[Vector2(1808, 624), 60.0], [Vector2(1012, 1064), 60.0], [Vector2(2094, 1116), 60.0],
	[Vector2(1433, 624), 60.0], [Vector2(628, 704), 80.0], [Vector2(676, 724), 40.0],
	[Vector2(2240, 920), 90.0], [Vector2(352, 120), 60.0], [Vector2(40, 1248), 60.0],
	[Vector2(1420, 606), 40.0], [Vector2(1508, 616), 30.0], [Vector2(2590, 1480), 40.0],
]

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["bake"]
	for s in steps:
		await call("_step_" + s)
	for r in report:
		print("[camp_hd] ", r)
	quit()


# ───────────────────────── bake ─────────────────────────

func _step_bake() -> void:
	var tone := AU.mean_color(AU.load_hd(HD, "props/camp"))
	var sheets := {}
	for k in SHEETS:
		var im := AU.clean_edges(AU.load_hd(HD, SHEETS[k]))
		# Наполовину к тону HD-шатров лагеря: листы разных генераций разного тона
		sheets[k] = AU.match_tone(im, AU.mean_color(im).lerp(tone, 0.5), 1.0)
	var pieces := {}
	for name in PIECES:
		var spec: Array = PIECES[name]
		var im := AU.keep_main((sheets[spec[0]] as Image).get_region(spec[1]), 0.12)
		var k: float = spec[3] / float(im.get_width() if spec[2] == "w" else im.get_height())
		var w := maxi(roundi(im.get_width() * k * TPX), 1)
		var h := maxi(roundi(im.get_height() * k * TPX), 1)
		pieces[name] = AU.unsharp(AU.resize_clean(im, w, h), 0.3)

	# Упаковка рядами по высоте
	var names := pieces.keys()
	names.sort_custom(func(a, b): return (pieces[a] as Image).get_height() > (pieces[b] as Image).get_height())
	const W := 2048
	const PAD := 4
	var x := PAD
	var y0 := PAD
	var row_h := 0
	var rects := {}
	for n in names:
		var im: Image = pieces[n]
		if x + im.get_width() + PAD > W:
			x = PAD
			y0 += row_h + PAD
			row_h = 0
		rects[n] = Rect2i(x, y0, im.get_width(), im.get_height())
		x += im.get_width() + PAD
		row_h = maxi(row_h, im.get_height())
	var atlas := Image.create(W, y0 + row_h + PAD, false, Image.FORMAT_RGBA8)
	var meta := {}
	for n in names:
		var r: Rect2i = rects[n]
		atlas.blit_rect(pieces[n], Rect2i(Vector2i.ZERO, r.size), r.position)
		meta[n] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	var f := FileAccess.open(ProjectSettings.globalize_path(META), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	AU.write_import(ATLAS, false)
	report.append("атлас: %d предметов, %dx%d (%s)" % [names.size(), atlas.get_width(), atlas.get_height(), error_string(err)])

	for pair in [["ground_camp_mud", MUD], ["ground_camp_ash", ASH]]:
		var g := AU.load_hd(HD, pair[0])
		g = AU.make_tileable(g, 0.16)
		g = AU.resize_clean(g, 1024, 1024)
		var e2 := g.save_png(ProjectSettings.globalize_path(pair[1]))
		AU.write_import(pair[1], true)
		report.append("плитка %s (%s)" % [String(pair[1]).get_file(), error_string(e2)])
	report.append("дальше: godot --headless --path . --import, затем apply")


# ───────────────────────── apply ─────────────────────────

var _meta := {}
var _atlas: Texture2D
var _footprints: Array[Rect2] = []
var _paving := {}
var _space: PhysicsDirectSpaceState2D


func _step_apply() -> void:
	# Всегда от лагеря до первой правки
	# (DirAccess.copy_absolute поверх существующей сцены молча не срабатывал —
	# читаем и пишем сами и сверяем)
	var bk := ProjectSettings.globalize_path(BACKUP)
	var camp_path := ProjectSettings.globalize_path(CAMP)
	if not FileAccess.file_exists(bk):
		var orig := FileAccess.get_file_as_bytes(camp_path)
		var fb := FileAccess.open(bk, FileAccess.WRITE)
		fb.store_buffer(orig)
		fb.close()
		report.append("копия лагеря до правок: %s" % BACKUP)
	var src := FileAccess.get_file_as_bytes(bk)
	var fw := FileAccess.open(camp_path, FileAccess.WRITE)
	if fw == null:
		report.append("ОШИБКА: не открыть %s на запись (%s)" % [CAMP, error_string(FileAccess.get_open_error())])
		return
	fw.store_buffer(src)
	fw.close()
	if FileAccess.get_file_as_bytes(camp_path) != src:
		report.append("ОШИБКА: лагерь не восстановлен из копии")
		return

	_meta = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(META)))
	_atlas = load(ATLAS) as Texture2D
	var mud := load(MUD) as Texture2D
	var ash := load(ASH) as Texture2D
	if _atlas == null or mud == null or ash == null:
		report.append("ОШИБКА: текстуры не импортированы — сначала bake и --import")
		return
	var packed := ResourceLoader.load(CAMP, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var camp := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	# Вторая копия — только для проверок коллизии (в дереве, с физикой)
	var probe := packed.instantiate()
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(probe)
	for i in 4:
		await physics_frame
	_space = (probe as Node2D).get_world_2d().direct_space_state

	var objects := camp.get_node("Objects")
	for c in (camp.get_node("Paving") as TileMapLayer).get_used_cells():
		_paving[c] = true

	_replace_objects(objects)
	for n in objects.get_children():
		if n is Sprite2D and n.visible:
			_footprints.append(_footprint(n as Sprite2D))
	var ash_spots: Array = []
	var placed := _place_props(camp, objects, ash_spots)
	var decals := _redo_decals(camp, ash_spots)
	_ground(camp, mud, ash, ash_spots)

	root.remove_child(probe)
	probe.free()
	var ps := PackedScene.new()
	var err := ps.pack(camp)
	if err == OK:
		err = ResourceSaver.save(ps, CAMP)
	report.append("apply: пропсов %d, %s, сцена (%s)" % [placed, decals, error_string(err)])
	report.append("дальше — перепечь навмеш карты (tools/bake_navmesh.gd)")


## Кусок атласа -> [Rect2, размер в px мира]
func _piece(name: String) -> Array:
	var r: Array = _meta[name]
	return [Rect2(r[0], r[1], r[2], r[3]), Vector2(r[2], r[3]) / TPX]


func _old_key_map() -> Dictionary:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(HD_PROPS_META)))
	var out := {}
	for k in meta:
		var r: Array = meta[k]
		out["%d,%d,%d,%d" % [r[0], r[1], r[2], r[3]]] = String(k).split("@")[0]
	return out


## Мировой прямоугольник картинки спрайта (в координатах лагеря)
func _sprite_rect(s: Sprite2D) -> Rect2:
	var size := s.region_rect.size if s.region_enabled else s.texture.get_size()
	var ofs := s.offset - (size * 0.5 if s.centered else Vector2.ZERO)
	return Rect2(s.position + ofs * s.scale, size * s.scale)


## То, на чём предмет стоит: нижняя треть картинки
func _footprint(s: Sprite2D) -> Rect2:
	var r := _sprite_rect(s)
	return Rect2(r.position.x + r.size.x * 0.12, r.end.y - r.size.y * 0.32, r.size.x * 0.76, r.size.y * 0.32)


## Новая картинка вместо старой: та же ширина (или высота) и та же точка опоры
func _swap(s: Sprite2D, name: String, by_height: bool, k: float = 1.0) -> void:
	var old := _sprite_rect(s)
	var p := _piece(name)
	var sz: Vector2 = p[1]
	var sc: float = (old.size.y * k / sz.y) if by_height else (old.size.x * k / sz.x)
	var base := Vector2(old.get_center().x, old.end.y) - s.position
	var tex_px := sc / TPX            # масштаб узла (атлас — TPX текселей на px)
	var nsz: Vector2 = (p[0] as Rect2).size
	s.texture = _atlas
	s.region_enabled = true
	s.region_rect = p[0]
	s.centered = false
	s.scale = Vector2(tex_px, tex_px)
	s.offset = Vector2(base.x / tex_px - nsz.x * 0.5, base.y / tex_px - nsz.y)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _replace_objects(objects: Node) -> void:
	var keys := _old_key_map()
	var fence := 0
	var logs := 0
	var removed := 0
	var burnt := 0
	for n in objects.get_children():
		if not (n is Sprite2D):
			continue
		var s := n as Sprite2D
		if s.texture == null or not s.texture.resource_path.ends_with("hd_props.png"):
			continue
		var rr := s.region_rect
		var key: String = keys.get("%d,%d,%d,%d" % [rr.position.x, rr.position.y, rr.size.x, rr.size.y], "")
		match key:
			"palisade":
				_swap(s, "pal_front", false)
				fence += 1
			"palisade_broken":
				_swap(s, "pal_broken_l", false)
				fence += 1
			"palisade_gap":
				_swap(s, "pal_broken_r", false)
				fence += 1
			"stake_a", "stake_b":
				var keep := false
				for cx in SIDE_COLUMNS:
					if absf(s.position.x - cx) < 4.0:
						keep = true
				if keep:
					var v := "log_a" if int(s.position.y / 13.0) % 3 != 0 else "log_b"
					_swap(s, v, true)
					# Стена вдоль взгляда: видны в основном светлые острия, без
					# затемнения она читается как светлый столб. Брёвна чуть
					# гуляют вбок — ряд неровный, как вбитый руками
					var j := (_hash(int(s.position.y), 31) - 0.5) * 5.0
					s.position.x += j
					var dk := 0.6 + 0.12 * _hash(int(s.position.y), 77)
					s.modulate = Color(dk, dk * 0.95, dk * 0.9)
					logs += 1
				else:
					objects.remove_child(s)
					s.free()
					removed += 1
			"tent_cone", "tent_ridge", "tent_cone_red", "tent_ridge_red":
				for bp in BURNT:
					if s.position.distance_to(bp) < 3.0:
						_swap(s, BURNT[bp], false)
						s.set_meta("burnt", true)
						burnt += 1
	report.append("частокол: %d секций, %d брёвен боковых стен (убрано %d лишних кольев), шатров сожжено %d" % [fence, logs, removed, burnt])


func _is_free(p: Vector2, fp: Rect2, radius: float) -> bool:
	if not _paving.has(Vector2i(int(floor(p.x / 64.0)), int(floor(p.y / 64.0)))):
		return false
	for f in _footprints:
		if f.grow(6.0).intersects(fp):
			return false
	for kc in KEEP_CLEAR:
		if p.distance_to(kc[0]) < float(kc[1]):
			return false
	var circ := CircleShape2D.new()
	circ.radius = radius
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = circ
	q.transform = Transform2D(0, p)
	q.collision_mask = 1
	return _space.intersect_shape(q, 1).is_empty()


func _find_spot(want: Vector2, size: Vector2) -> Vector2:
	for ring in range(0, 26):
		var steps := maxi(1, ring * 8)
		for i in steps:
			var p := (want + Vector2.from_angle(TAU * i / steps) * ring * 8.0).round()
			var fp := Rect2(p.x - size.x * 0.4, p.y - size.y * 0.3, size.x * 0.8, size.y * 0.3)
			if _is_free(p, fp, maxf(minf(size.x, size.y) * 0.22, 10.0)):
				_footprints.append(fp)
				return p
	return Vector2.INF


func _place_props(camp: Node, objects: Node, ash_spots: Array) -> int:
	var campfire := load(CAMPFIRE) as PackedScene
	var n := 0
	for spec in PLACE:
		var name: String = spec[0]
		var p := _piece(name)
		var size: Vector2 = p[1]
		var at := _find_spot(spec[1], size)
		if at == Vector2.INF:
			report.append("  нет места для %s у %s" % [name, spec[1]])
			continue
		var spr := Sprite2D.new()
		spr.name = "HD_%s_%d" % [name, n]
		spr.texture = _atlas
		spr.region_enabled = true
		spr.region_rect = p[0]
		spr.centered = false
		spr.scale = Vector2.ONE / TPX
		spr.position = at
		var nsz: Vector2 = (p[0] as Rect2).size
		spr.offset = Vector2(-nsz.x * 0.5, -nsz.y + 4.0)
		spr.flip_h = (n % 2) == 1 and name in ["cheval", "supply", "shields", "rack"]
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		objects.add_child(spr)
		spr.owner = camp
		var col: Vector2 = spec[2]
		if col != Vector2.ZERO:
			var body := StaticBody2D.new()
			body.name = "Body"
			var cs := CollisionShape2D.new()
			cs.name = "Shape"
			var shape := RectangleShape2D.new()
			shape.size = col * TPX
			cs.shape = shape
			cs.position = Vector2(0, -col.y * 0.5 * TPX)
			spr.add_child(body)
			body.owner = camp
			body.add_child(cs)
			cs.owner = camp
		var fire: String = spec[3]
		if fire != "":
			_add_fire(camp, spr, campfire, fire, nsz)
			if fire == "big":
				ash_spots.append([at, 110.0, 0.95])
			elif fire == "brazier":
				ash_spots.append([at, 40.0, 0.5])
		n += 1
	# Пепел под сгоревшими шатрами
	for c in objects.get_children():
		if c.has_meta("burnt"):
			var r := _sprite_rect(c as Sprite2D)
			ash_spots.append([Vector2(r.get_center().x, r.end.y - r.size.y * 0.3), r.size.x * 0.75, 1.0 if (c as Sprite2D).region_rect == (_piece("tent_burnt")[0] as Rect2) else 0.35])
	return n


## Огонь: свет, искры и треск (Levels/props/campfire.tscn). Угли нарисованы в
## картинке, поэтому пиксельное пламя (Glow) остаётся только у факелов
func _add_fire(camp: Node, spr: Sprite2D, scene: PackedScene, kind: String, nsz: Vector2) -> void:
	var f := scene.instantiate() as Node2D
	f.name = "Fire"
	f.scale = Vector2.ONE * TPX          # спрайт уменьшен в TPX раз
	var glow := f.get_node_or_null("Glow") as Node2D
	var light := f.get_node_or_null("Light") as PointLight2D
	var body := f.get_node_or_null("BodyLight") as PointLight2D
	var top := -nsz.y + 4.0               # верх картинки в текселях
	match kind:
		"big":
			f.position = Vector2(0, top + nsz.y * 0.62)
			f.set("base_energy", 1.25)
			if light: light.texture_scale = 1.7
			if glow: glow.visible = false
		"brazier":
			f.position = Vector2(0, top + nsz.y * 0.2)
			f.set("base_energy", 0.85)
			if light: light.texture_scale = 1.0
			if glow: glow.visible = false
		"torch":
			f.position = Vector2(0, top + nsz.y * 0.07)
			f.set("base_energy", 0.8)
			if light: light.texture_scale = 0.9
			if glow:
				glow.scale *= 0.55
	if body and light:
		body.texture_scale = light.texture_scale
	# Узел огня увеличен в TPX раз (спрайт уменьшен) — искры возвращаем к
	# обычному размеру, иначе над углями висит светящийся шар
	var embers := f.get_node_or_null("Embers") as Node2D
	if embers:
		embers.scale = Vector2.ONE / TPX
	spr.add_child(f)
	f.owner = camp


func _redo_decals(camp: Node, ash_spots: Array) -> String:
	var fd := camp.get_node("FloorDecals")
	var old: PackedFloat32Array = fd.get("data")
	var out := PackedFloat32Array()
	var removed := 0
	var replaced := 0
	for i in old.size() / 12:
		var b := i * 12
		var key := "%d,%d,%d,%d" % [old[b + 7], old[b + 8], old[b + 9], old[b + 10]]
		if not DECALS.has(key):
			continue
		var choices: Array = DECALS[key]
		if choices.is_empty():
			removed += 1
			continue
		var pos := Vector2(old[b + 1], old[b + 2])
		var sc := Vector2(old[b + 3], old[b + 4])
		var size := Vector2(old[b + 9], old[b + 10])
		var ofs := Vector2(old[b + 5], old[b + 6])
		if int(old[b + 11]) & 1:
			ofs -= size * 0.5
		var center := pos + (ofs + size * 0.5) * sc
		var name: String = choices[i % choices.size()]
		var w_world: float = size.x * absf(sc.x) * DECAL_K.get(name, 1.0)
		_add_decal(out, name, center, w_world)
		if name.begins_with("crater"):
			ash_spots.append([center, w_world * 0.6, 0.6])
		replaced += 1
	# Россыпь: оружие, щиты, шлемы, кровь — у шатров и на тропах
	var added := 0
	var salt := 0
	for sp in SCATTER:
		for k in int(sp[1]):
			for attempt in 40:
				salt += 1
				var p := Vector2(180 + _hash(salt, 3) * 2400, 280 + _hash(salt, 9) * 1150).round()
				var ok := _paving.has(Vector2i(int(p.x / 64.0), int(p.y / 64.0)))
				for f in _footprints:
					if f.grow(4.0).has_point(p):
						ok = false
						break
				if ok:
					var pc := _piece(sp[0])
					_add_decal(out, sp[0], p, (pc[1] as Vector2).x * (0.85 + 0.3 * _hash(salt, 17)))
					added += 1
					break
	fd.set("textures", [_atlas] as Array[Texture2D])
	fd.set("data", out)
	return "декали: %d заменено, %d трупов и мусора убрано, %d добавлено" % [replaced, removed, added]


func _add_decal(out: PackedFloat32Array, name: String, center: Vector2, w_world: float) -> void:
	var p := _piece(name)
	var r: Rect2 = p[0]
	var s := w_world / r.size.x
	out.append_array([0, center.x, center.y, s, s, -r.size.x * 0.5, -r.size.y * 0.5,
			r.position.x, r.position.y, r.size.x, r.size.y, 0])


## Земля: трава карты на слое Ground (тот же материал, что у земли карты —
## стыка нет), грязь и пепел — отдельным спрайтом с маской
func _ground(camp: Node, mud: Texture2D, ash: Texture2D, ash_spots: Array) -> void:
	var ground := camp.get_node("Ground") as TileMapLayer
	ground.material = load(GROUND_MAT)
	camp.get_node("Paving").visible = false
	camp.get_node("PavingEdge").visible = false
	const PX := 4                         # px мира на тексель маски
	var used := ground.get_used_rect()
	var area := Vector2i(used.end * 64)
	var w := area.x / PX
	var h := area.y / PX
	var inside := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Vector2i(x * PX / 64, y * PX / 64)
			if _paving.has(c):
				inside.set_pixel(x, y, Color(1, 1, 1, 1))
	var soft := inside.duplicate() as Image
	soft.resize(w / 6, h / 6, Image.INTERPOLATE_BILINEAR)
	soft.resize(w, h, Image.INTERPOLATE_CUBIC)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	noise.seed = 5
	var macro := FastNoiseLite.new()
	macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro.frequency = 0.012
	macro.seed = 9
	var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var s := soft.get_pixel(x, y).r
			var n := noise.get_noise_2d(x, y)
			# Рваный край: шум сдвигает границу; в глубине лагеря — проплешины травы
			var r := clampf((s - 0.5) * 3.2 + 0.5 + n * 0.55, 0.0, 1.0)
			r = r * r * (3.0 - 2.0 * r)
			if s > 0.95 and n > 0.42:
				r *= 0.55
			var g := 0.0
			var wp := Vector2(x * PX, y * PX)
			for a in ash_spots:
				var d: float = wp.distance_to(a[0]) / float(a[1])
				if d < 1.0:
					g = maxf(g, float(a[2]) * (1.0 - d * d) * clampf(0.75 + n * 0.6, 0.0, 1.0))
			var bb := clampf(macro.get_noise_2d(x, y) * 1.6 + 0.5, 0.0, 1.0)
			mask.set_pixel(x, y, Color(r, clampf(g, 0.0, 1.0), bb, 1.0))
	var tex := ImageTexture.create_from_image(mask)
	ResourceSaver.save(tex, MASK, ResourceSaver.FLAG_COMPRESS)

	var spr := Sprite2D.new()
	spr.name = "MudGround"
	spr.texture = ResourceLoader.load(MASK, "", ResourceLoader.CACHE_MODE_REPLACE)
	spr.centered = false
	spr.scale = Vector2(PX, PX)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load(GROUND_SHADER)
	mat.set_shader_parameter("mud_tex", mud)
	mat.set_shader_parameter("ash_tex", ash)
	mat.set_shader_parameter("tile_px", 380.0)
	mat.set_shader_parameter("area_px", Vector2(area))
	spr.material = mat
	camp.add_child(spr)
	spr.owner = camp
	camp.move_child(spr, camp.get_node("PavingEdge").get_index() + 1)
	report.append("земля: маска %dx%d, пятен пепла %d" % [w, h, ash_spots.size()])


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10000) / 10000.0
