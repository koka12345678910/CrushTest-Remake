extends SceneTree
## Каменные стены Хольмвика, партия 4 (NEXT_SESSION_WALLS_ROADS.md, шаги B–D):
## по одному предмету на картинку GPT в textures/src/hd/props_v4/ — чётко и
## без зазоров.
##
## Шаги:
##   atlas — textures/town_walls_hd.png (+ .json): каждый предмет печётся сразу
##           в свой размер в мире при TS текселях на px мира (камера x2.2 и
##           зоны до 1.09 — при 2.0 было мыло), после уменьшения — резкость;
##           у секций стены срезаются рваные края (столбцы/строки, где кладки
##           меньше SOLID доли тела), у ворот замеряется просвет арки.
##           Потом: godot --headless --path . --import
##   walls — после holmvik_blockout.gd apply (он ставит деревянный частокол):
##           ряды частокола → каменные секции внахлёст (каждая следующая на 1 px
##           ниже — y-sort без мерцания), на каждом SEAM_EVERY-м стыке и у
##           концов — контрфорс; повреждённые секции → пролом; боковые стены →
##           wall_run; угловые башни → tower_corner; ворота-башни → gate_main
##           (проём коллизии — по просвету арки); сторожевые башни северной
##           стены (дома town_v2 watchtower) → tower_round.
## Порядок: atlas → --import → holmvik_blockout.gd apply → walls →
## holmvik_art3.gd siege (блокаут убирает осаду) → normal_bake.gd --
## town_walls_hd → --import → bake_navmesh.gd.

const AU := preload("res://tools/art_util.gd")
const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const SRC := TEX + "src/hd/props_v4/"
const ATLAS := TEX + "town_walls_hd.png"
const META := TEX + "town_walls_hd.json"
const TOWN_META := TEX + "town_props_hd.json"
const TONE_REF := TEX + "town_art3_hd.png"
const TS := 2.5
const ATLAS_W := 4096
const SHARPEN := 0.3
const TONE_MIX := 0.2
const SOLID := 0.85
const META_TAG := "art3"

## Предмет: [файл, "w"|"h", размер в мире, срез краёв: "x" | "y" | ""]
const ITEMS := {
	"wall_tile": ["wall_tile", "w", 220.0, "x"],
	# Пролом — в ту же ширину И высоту, что целая секция (у GPT он ниже и
	# шире пропорцией): иначе на стыке ступенька
	"wall_breach": ["wall_tile_breach", "wh", Vector2(220.0, 106.0), "x"],
	"wall_run": ["wall_run", "w", 66.0, "y"],
	"buttress": ["wall_buttress", "h", 128.0, ""],
	"gate_main": ["gate_main", "w", 360.0, ""],
	"tower_corner": ["tower_corner", "w", 150.0, ""],
	"tower_round": ["tower_round", "w", 170.0, ""],
}

## Раскладка стены
const OVERLAP := 0.06
const SEAM_EVERY := 3
## Шаг кусков боковой стены — доля высоты куска
const RUN_STEP := 0.9

var report: Array[String] = []
var _meta: Dictionary
var _tex: Texture2D


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["atlas"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[holmvik_walls4] ", r)
	quit()


# ───────────────────────── atlas ─────────────────────────

func _step_atlas() -> void:
	var ref := (load(TONE_REF) as Texture2D).get_image()
	ref.decompress()
	ref.convert(Image.FORMAT_RGBA8)
	var target := AU.mean_color(ref)
	var items := []
	var extra := {}
	for key in ITEMS:
		var spec: Array = ITEMS[key]
		var img := AU.load_hd(SRC, spec[0])
		if img == null:
			report.append("нет %s — пропуск" % spec[0])
			continue
		img = AU.keep_main(img)
		img = AU.clean_edges(img)
		img = img.get_region(_alpha_rect(img, 0.5))
		if spec[3] == "x":
			img = _trim(img, true)
		elif spec[3] == "y":
			img = _trim(img, false)
		var w: int
		var h: int
		if spec[1] == "wh":
			var sz: Vector2 = spec[2]
			w = int(round(sz.x * TS))
			h = int(round(sz.y * TS))
		else:
			var k: float = float(spec[2]) * TS / (img.get_width() if spec[1] == "w" else img.get_height())
			w = maxi(int(round(img.get_width() * k)), 4)
			h = maxi(int(round(img.get_height() * k)), 4)
		img = AU.resize_clean(img, w, h)
		img = AU.unsharp(img, SHARPEN)
		var m := AU.mean_color(img)
		img = AU.match_tone(img, m.lerp(target, TONE_MIX))
		if key == "gate_main":
			extra["gate_pass"] = _arch_width(img) / TS
		items.append({"name": key, "img": img})
		report.append("%s: %dx%d текселей = %.0fx%.0f px мира" % [key, w, h, w / TS, h / TS])
	items.sort_custom(func(a, b): return a.img.get_height() > b.img.get_height())
	var x := 0
	var y := 0
	var shelf := 0
	var placed := {}
	for it in items:
		var im: Image = it.img
		if x + im.get_width() > ATLAS_W:
			x = 0
			y += shelf + 4
			shelf = 0
		placed[it.name] = Rect2i(x, y, im.get_width(), im.get_height())
		x += im.get_width() + 4
		shelf = maxi(shelf, im.get_height())
	var ah := 1
	while ah < y + shelf:
		ah *= 2
	var atlas := Image.create(ATLAS_W, ah, false, Image.FORMAT_RGBA8)
	for it in items:
		var r: Rect2i = placed[it.name]
		atlas.blit_rect(it.img, Rect2i(Vector2i.ZERO, r.size), r.position)
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	AU.write_import(ATLAS, false)
	var meta := {"_ts": TS}
	for nm in placed:
		var r: Rect2i = placed[nm]
		meta[nm] = [r.position.x, r.position.y, r.size.x, r.size.y]
	for k2 in extra:
		meta[k2] = extra[k2]
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	report.append("atlas: %d предметов, %dx%d (%s); просвет арки ворот %.0f px мира; дальше --import" % [
		placed.size(), ATLAS_W, ah, error_string(err), float(extra.get("gate_pass", 0.0))])


## Прямоугольник плотной альфы (лёгкая дымка по краям картинки не в счёт)
func _alpha_rect(img: Image, thr: float) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > thr:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Срезать рваные края: столбцы (horizontal) или строки, где плотных пикселей
## меньше SOLID от самого плотного
func _trim(img: Image, horizontal: bool) -> Image:
	var n := img.get_width() if horizontal else img.get_height()
	var m := img.get_height() if horizontal else img.get_width()
	var cnt := PackedInt32Array()
	cnt.resize(n)
	var best := 0
	for i in n:
		var c := 0
		for j in range(0, m, 2):
			var px := img.get_pixel(i, j) if horizontal else img.get_pixel(j, i)
			if px.a > 0.5:
				c += 1
		cnt[i] = c
		best = maxi(best, c)
	var a := 0
	while a < n - 1 and cnt[a] < best * SOLID:
		a += 1
	var b := n - 1
	while b > a and cnt[b] < best * SOLID:
		b -= 1
	if horizontal:
		return img.get_region(Rect2i(a, 0, b - a + 1, m))
	return img.get_region(Rect2i(0, a, m, b - a + 1))


## Просвет арки: в нижних 12% картинки — самый длинный прозрачный отрезок,
## пересекающий центр (тексели)
func _arch_width(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var best := 0.0
	for y in range(int(h * 0.88), h - 2, 3):
		var cx := w / 2
		if img.get_pixel(cx, y).a > 0.5:
			continue
		var l := cx
		while l > 0 and img.get_pixel(l - 1, y).a <= 0.5:
			l -= 1
		var r := cx
		while r < w - 1 and img.get_pixel(r + 1, y).a <= 0.5:
			r += 1
		best = maxf(best, float(r - l + 1))
	return best


# ───────────────────────── walls ─────────────────────────

func _step_walls() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_tex = load(ATLAS) as Texture2D
	if _tex == null:
		report.append("ОШИБКА: нет %s — atlas и --import" % ATLAS)
		return
	var town_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TOWN_META))
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var objects := lvl.get_node("Objects")
	var walls := lvl.get_node("Blockout/Walls")
	# Что поставил блокаут (деревянный частокол) — по региону атласа партии 2
	var rows := {}     # y -> [[x, damaged], ...]
	var sides := {}    # x -> [ymin, ymax]
	var towers: Array = []
	var gates: Array = []
	var kill: Array = []
	for c in objects.get_children():
		if not (c is Sprite2D):
			continue
		var s := c as Sprite2D
		var k := _town_key(s, town_meta)
		if k == "pal_front" or k == "pal_damaged":
			var y := s.position.y
			if not rows.has(y):
				rows[y] = []
			# ширина секции частокола в мире (блокаут растягивает по ряду)
			var w: float = float(town_meta[k][2]) * absf(s.scale.x)
			rows[y].append([s.position.x, k == "pal_damaged", w])
			kill.append(s)
		elif k == "pal_side":
			var x := s.position.x
			if not sides.has(x):
				sides[x] = [INF, -INF]
			sides[x][0] = minf(sides[x][0], s.position.y)
			sides[x][1] = maxf(sides[x][1], s.position.y)
			kill.append(s)
		elif k == "pal_tower":
			towers.append(s.position)
			kill.append(s)
		elif k == "pal_gatehouse":
			gates.append([s.position, String(s.name)])
			kill.append(s)
		elif str(s.get_meta("town_v2", "")) == "watchtower":
			_set_sprite(s, "tower_round")
			s.offset = Vector2(-_rect_of("tower_round").size.x * 0.5, -_rect_of("tower_round").size.y + 6.0)
			s.centered = false
	for s in kill:
		s.get_parent().remove_child(s)
		s.free()
	var st := {"sections": 0, "breach": 0, "buttress": 0, "run": 0, "tower": 0, "gate": 0}
	# 1. Ряды: непрерывные отрезки (соседние секции встык) → каменные секции
	for y in rows:
		var row: Array = rows[y]
		row.sort_custom(func(a, b): return a[0] < b[0])
		var runs: Array = []
		var cur: Array = []
		for e in row:
			if not cur.is_empty():
				var p: Array = cur[cur.size() - 1]
				if e[0] - p[0] > (float(p[2]) + float(e[2])) * 0.5 + 8.0:
					runs.append(cur)
					cur = []
			cur.append(e)
		if not cur.is_empty():
			runs.append(cur)
		for run in runs:
			var x0: float = run[0][0] - float(run[0][2]) * 0.5
			var x1: float = run[run.size() - 1][0] + float(run[run.size() - 1][2]) * 0.5
			var damaged: Array = []
			for e in run:
				if e[1]:
					damaged.append(e[0])
			_lay_row(objects, lvl, x0, x1, y, damaged, st)
	# 2. Боковые стены
	var run_h: float = _rect_of("wall_run").size.y / TS
	for x in sides:
		var y0: float = sides[x][0] - 8.0 - 60.0
		var y1: float = sides[x][1] - 8.0
		var step := run_h * RUN_STEP
		var y := y0 + step
		var i := 0
		while y <= y1 + step * 0.5:
			var s := _new_sprite(objects, lvl, "wall_run", Vector2(x, minf(y, y1) + 8.0), "W4_Run%d_%d" % [int(x), i])
			s.flip_h = _hash(int(x), int(y)) > 0.5
			st.run += 1
			i += 1
			y += step
	# 3. Угловые башни
	for p in towers:
		var t := _new_sprite(objects, lvl, "tower_corner", p + Vector2(0, 6), "W4_Tower%d_%d" % [int(p.x), int(p.y)])
		t.flip_h = _hash(int(p.x), 11) > 0.5
		_body(t, lvl, Vector2(_rect_of("tower_corner").size.x / TS * 0.7, 26))
		st.tower += 1
	# 4. Ворота: картинка и проём под просвет арки
	var pass_w := float(_meta.get("gate_pass", 84.0))
	pass_w = clampf(pass_w * 0.9, 70.0, 110.0)
	var gw: float = _rect_of("gate_main").size.x / TS
	for g in gates:
		var p: Vector2 = g[0]
		var nm: String = g[1]
		var gs := _new_sprite(objects, lvl, "gate_main", p + Vector2(0, 2), nm)
		for side in ["_L", "_R"]:
			var cs := walls.get_node_or_null(nm + side) as CollisionShape2D
			if cs == null:
				continue
			var rs := RectangleShape2D.new()
			var w := gw * 0.5 - pass_w * 0.5
			rs.size = Vector2(w, 56)
			cs.shape = rs
			cs.position = Vector2(p.x - pass_w * 0.5 - w * 0.5 if side == "_L" else p.x + pass_w * 0.5 + w * 0.5, p.y - 26 - 10)
		st.gate += 1
	report.append("walls: секций %d (проломов %d), контрфорсов %d, боковых %d, башен %d, ворот %d (проход %.0f px)" % [
		st.sections, st.breach, st.buttress, st.run, st.tower, st.gate, pass_w])
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	lvl.free()
	report.append("сцена сохранена (%s)" % error_string(err))


## Отрезок стены x0..x1 по основанию y: секции внахлёст, контрфорсы на стыках
func _lay_row(objects: Node, lvl: Node, x0: float, x1: float, y: float, damaged: Array, st: Dictionary) -> void:
	var w: float = _rect_of("wall_tile").size.x / TS
	var stride := w * (1.0 - OVERLAP)
	var n := maxi(1, roundi((x1 - x0 - w * OVERLAP) / stride))
	# Подогнать шаг, чтобы отрезок закрывался ровно (секция чуть шире/уже)
	var k := (x1 - x0) / (n * stride + w * OVERLAP)
	var cx := x0
	for i in n:
		var c := cx + w * k * 0.5
		var breach := false
		for d in damaged:
			if absf(float(d) - c) < stride * k * 0.5:
				breach = true
		var key := "wall_breach" if breach else "wall_tile"
		var s := _new_sprite(objects, lvl, key, Vector2(c, y + (i % 2)), "W4_Wall%d_%d" % [int(y), i + int(x0)])
		s.scale.x *= k
		st.sections += 1
		if breach:
			st.breach += 1
		cx += stride * k
		# Контрфорс на стыке (каждый SEAM_EVERY-й) — перед стеной, закрывает шов
		if i < n - 1 and (i + 1) % SEAM_EVERY == 0:
			_buttress(objects, lvl, Vector2(cx + w * k * OVERLAP * 0.5, y + 6.0), st)
	# И у концов отрезка
	_buttress(objects, lvl, Vector2(x0 + 6.0, y + 6.0), st)
	_buttress(objects, lvl, Vector2(x1 - 6.0, y + 6.0), st)


func _buttress(objects: Node, lvl: Node, at: Vector2, st: Dictionary) -> void:
	var b := _new_sprite(objects, lvl, "buttress", at, "W4_Buttress%d_%d" % [int(at.x), int(at.y)])
	b.flip_h = _hash(int(at.x), 7) > 0.5
	st.buttress += 1


func _town_key(s: Sprite2D, tm: Dictionary) -> String:
	if s.texture == null or not s.texture.resource_path.ends_with("town_props_hd.png"):
		return ""
	for k in ["pal_front", "pal_damaged", "pal_side", "pal_tower", "pal_gatehouse"]:
		var r: Array = tm[k]
		if s.region_rect == Rect2(r[0], r[1], r[2], r[3]):
			return k
	return ""


func _rect_of(key: String) -> Rect2:
	var r: Array = _meta[key]
	return Rect2(r[0], r[1], r[2], r[3])


func _set_sprite(s: Sprite2D, key: String) -> void:
	var r := _rect_of(key)
	s.texture = _tex
	s.region_enabled = true
	s.region_rect = r
	s.centered = false
	s.scale = Vector2.ONE / TS
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y + 4.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.set_meta(META_TAG, key)


func _new_sprite(objects: Node, lvl: Node, key: String, base: Vector2, node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	_set_sprite(s, key)
	s.position = base
	s.set_meta("blockout", true)
	objects.add_child(s)
	s.owner = lvl
	return s


## Упор у основания спрайта (size — px мира)
func _body(s: Sprite2D, lvl: Node, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size / s.scale
	cs.shape = shape
	cs.position = Vector2(0, -size.y * 0.5 / s.scale.y)
	s.add_child(body)
	body.owner = lvl
	body.add_child(cs)
	cs.owner = lvl


func _hash(a: int, b: int) -> float:
	var h := hash(Vector2i(a, b))
	return float(h % 10007) / 10007.0
