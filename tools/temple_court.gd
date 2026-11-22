extends SceneTree
## temple_court.gd — двор храма Бальдра, арена босса (reference_map):
## достраивает то, что после блокаута стояло наспех.
##
##   * боковые стены — каменные секции городской стены (wall_run) по всей
##     длине двора, от южной ограды до самого храма (раньше — по одному куску,
##     у храма двор был открыт); на южных углах — контрфорсы;
##   * четыре жаровни по углам двора — живой огонь (свет Night/BrazierTemple*,
##     пламя строит fire_fx.gd): арену видно ночью;
##   * штандарты Ордена у подножия лестницы храма, павшие стражи Бальдра
##     (последний рубеж у лестницы и у ворот), обломки и брошенные щиты вдоль
##     стен; середина двора свободна — там бой;
##   * знак Тёмного Солнца кровью на плитах (scripts/dark_sigil.gd, узел
##     TempleSigil у корня, под Objects).
## Плиты двора — tools/cobble_road.gd -- streets (TEMPLE_COURT в PLAZAS).
##
##   godot --headless --path . -s res://tools/temple_court.gd [-- apply]
##
## Можно запускать повторно (прежнее с метой temple_court убирается).
## Потом — tools/bake_navmesh.gd. Если перезапускался holmvik_walls4.gd walls
## или holmvik_blockout.gd apply — этот инструмент после них.

const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const META := "temple_court"
const SIGIL_SCRIPT := "res://reference_map_level/scripts/dark_sigil.gd"

## Двор: от подножия храма до южной ограды
const COURT := Rect2(770, 870, 650, 392)
## Основания секций боковой стены (сверху вниз перекрывают друг друга)
const SIDE_BASES := [1105.0, 1258.0]
const SIDE_X := [770.0, 1420.0]

## Атласы: [png, json, текселей на px мира]
const SHEETS := {
	"walls": ["town_walls_hd", 2.5],
	"town": ["town_props_hd", 2.0],
	"art3": ["town_art3_hd", 2.0],
	"route": ["town_route_hd", 2.5],
}

## Предметы двора: [лист, ключ, основание, масштаб, отражение, коллизия (w, h) | Vector2.ZERO]
const PROPS := [
	# Контрфорсы на южных углах — там, где стена встречает ограду
	["walls", "buttress", Vector2(782, 1266), 0.9, false, Vector2(30, 12)],
	["walls", "buttress", Vector2(1408, 1266), 0.9, true, Vector2(30, 12)],
	# Штандарты Ордена у лестницы храма
	["town", "ds_standard", Vector2(972, 906), 1.0, false, Vector2(10, 6)],
	["town", "ds_standard", Vector2(1208, 906), 1.0, true, Vector2(10, 6)],
	# Обломки у стен
	["art3", "wall_rubble", Vector2(814, 1120), 0.42, false, Vector2(56, 14)],
	["art3", "wall_rubble", Vector2(1376, 1180), 0.4, true, Vector2(52, 14)],
	["art3", "siege_stones", Vector2(1372, 958), 0.45, false, Vector2(40, 12)],
	["art3", "siege_stones", Vector2(820, 1236), 0.38, true, Vector2(34, 10)],
	# Брошенное оружие стражи — плоско, без коллизии
	["route", "tr_shield", Vector2(1004, 1158), 1.0, false, Vector2.ZERO],
	["route", "tr_spear", Vector2(1186, 1012), 1.0, true, Vector2.ZERO],
	["route", "tr_shield", Vector2(872, 990), 0.9, true, Vector2.ZERO],
	["route", "tr_spear", Vector2(1262, 1226), 0.9, false, Vector2.ZERO],
]
## Жаровни по углам (основание чаши на земле)
const BRAZIERS := [Vector2(846, 930), Vector2(1334, 930), Vector2(846, 1214), Vector2(1334, 1214),
		Vector2(808, 1046), Vector2(1382, 1046)]
const BRAZIER_SCALE := 1.15
## Павшие стражи Бальдра: [центр тела, отражение]
const FALLEN := [
	[Vector2(1022, 936), false], [Vector2(1150, 924), true], [Vector2(1246, 1172), false],
	[Vector2(928, 1186), true], [Vector2(1352, 1062), false],
]
const FALLEN_SCALE := 0.78
## Знак на плитах — там, где стоит босс (южнее его закрыли бы врата)
const SIGIL_AT := Vector2(1090, 990)

var report: Array[String] = []
var _sheets := {}


func _initialize() -> void:
	var apply := "apply" in OS.get_cmdline_user_args()
	for k in SHEETS:
		var name: String = SHEETS[k][0]
		_sheets[k] = {
			"tex": load(TEX + name + ".png"),
			"meta": JSON.parse_string(FileAccess.get_file_as_string(TEX + name + ".json")),
			"ts": float(SHEETS[k][1]),
		}
	var lvl: Node = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var objects := lvl.get_node("Objects")
	var night := lvl.get_node("Night")

	# 1. Прежнее: свои узлы, старые боковые куски стены во дворе, свет жаровен
	var removed := 0
	for c in objects.get_children():
		if c.has_meta(META) or (str(c.get_meta("art3", "")) == "wall_run" and _in_court_side(c)):
			objects.remove_child(c)
			c.free()
			removed += 1
	for c in night.get_children():
		if String(c.name).begins_with("BrazierTemple"):
			night.remove_child(c)
			c.free()
			removed += 1
	var old_sigil := lvl.get_node_or_null("TempleSigil")
	if old_sigil:
		lvl.remove_child(old_sigil)
		old_sigil.free()
		removed += 1

	# 2. Боковые стены
	var walls := 0
	for x in SIDE_X:
		for y in SIDE_BASES:
			var s := _sprite(objects, lvl, "walls", "wall_run", Vector2(x, y), 1.0, x > 1000.0, "TC_Side")
			s.set_meta("art3", "wall_run")
			walls += 1

	# 3. Предметы
	var props := 0
	for p in PROPS:
		var s := _sprite(objects, lvl, p[0], p[1], p[2], p[3], p[4], "TC_" + String(p[1]))
		if p[5] != Vector2.ZERO:
			_body(s, lvl, p[5])
		props += 1

	# 4. Жаровни с огнём
	var torch := night.get_node_or_null("Torch3") as PointLight2D
	var bi := 0
	for b in BRAZIERS:
		var s := _sprite(objects, lvl, "town", "ds_brazier", b, BRAZIER_SCALE, bi % 2 == 1, "TC_Brazier")
		_body(s, lvl, Vector2(20, 9))
		if torch:
			var l := torch.duplicate() as PointLight2D
			l.name = "BrazierTemple%d" % bi
			l.position = b + Vector2(0, -56)
			l.color = Color(1.0, 0.5, 0.22)
			l.energy = 1.45
			l.texture_scale = 2.7
			night.add_child(l)
			l.owner = lvl
		bi += 1

	# 5. Павшие стражи (лужи под ними рисует fallen_blood.gd по blood_at)
	var fallen_meta: Array = JSON.parse_string(FileAccess.get_file_as_string(TEX + "town_fallen.json"))
	var guards := []
	for f in fallen_meta:
		if str(f["kind"]) == "guard":
			guards.append(f["rect"])
	var ftex := load(TEX + "town_fallen.png")
	var fi := 0
	for f in FALLEN:
		var r: Array = guards[fi % guards.size()]
		var s := Sprite2D.new()
		s.name = "TC_Fallen%d" % fi
		s.texture = ftex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.region_enabled = true
		s.region_rect = Rect2(r[0], r[1], r[2], r[3])
		s.scale = Vector2.ONE * FALLEN_SCALE
		s.offset = Vector2(0, float(r[3]) * 0.5 - 4.0)
		s.flip_h = f[1]
		var center: Vector2 = f[0]
		s.position = center - Vector2(0, float(r[3]) * FALLEN_SCALE * 0.5)
		s.set_meta("town_fallen", true)
		s.set_meta("blood_at", center)
		s.set_meta(META, "fallen")
		objects.add_child(s)
		s.owner = lvl
		fi += 1

	# 6. Знак Тёмного Солнца — под Objects, над землёй
	var sig := Node2D.new()
	sig.name = "TempleSigil"
	sig.set_script(load(SIGIL_SCRIPT))
	sig.position = SIGIL_AT
	sig.z_as_relative = false
	sig.z_index = -17
	lvl.add_child(sig)
	lvl.move_child(sig, objects.get_index())
	sig.owner = lvl

	report.append("убрано прежнего %d; стены %d секций, предметов %d, жаровен %d, павших %d, знак" % [
		removed, walls, props, bi, fi])
	if apply:
		var ps := PackedScene.new()
		var err := ps.pack(lvl)
		if err == OK:
			err = ResourceSaver.save(ps, SCENE)
		report.append("сохранено: %s; дальше — tools/bake_navmesh.gd" % error_string(err))
	else:
		report.append("проверка (сохранить: -- apply)")
	for r in report:
		print("[temple_court] ", r)
	lvl.free()
	quit()


## Старая боковая стена двора (одна секция на сторону от walls4)
func _in_court_side(c: Node) -> bool:
	if not c is Node2D:
		return false
	var p := (c as Node2D).position
	return (absf(p.x - 770.0) < 2.0 or absf(p.x - 1420.0) < 2.0) and p.y > COURT.position.y and p.y < COURT.end.y + 20.0


## Спрайт предмета: узел в точке основания (по ней y-sort)
func _sprite(objects: Node, lvl: Node, sheet: String, key: String, base: Vector2, sc: float, flip: bool, prefix: String) -> Sprite2D:
	var sh: Dictionary = _sheets[sheet]
	var r: Array = sh["meta"][key]
	var s := Sprite2D.new()
	s.name = "%s_%d_%d" % [prefix, int(base.x), int(base.y)]
	s.texture = sh["tex"]
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.centered = false
	s.scale = Vector2.ONE * sc / float(sh["ts"])
	s.offset = Vector2(-float(r[2]) * 0.5, -float(r[3]) + 4.0)
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = base
	s.set_meta(META, key)
	objects.add_child(s)
	s.owner = lvl
	return s


## Коллизия у основания: size — в px мира
func _body(s: Sprite2D, lvl: Node, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size / s.scale
	cs.shape = shape
	cs.position = Vector2(0, -size.y * 0.5) / s.scale
	s.add_child(body)
	body.owner = lvl
	body.add_child(cs)
	cs.owner = lvl
