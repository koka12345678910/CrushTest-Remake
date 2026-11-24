extends SceneTree
## Дома Хольмвика, партия 6 (textures/src/hd/houses_v6/<вид>[_side|_back].png,
## промпты — reference_map_level/ART_PROMPTS_HOLMVIK_6.md): тёмные, обжитые
## норвежские дома в 1–2 этажа вместо чистых «пластиковых» v2 и каменных
## трёхэтажек v3. Город НЕ пересобирается: каждый рядовой дом заменяется на
## своём месте — дворы, заборы, баррикады, враги и маршрут остаются.
##
##   godot --headless --path . -s res://tools/holmvik_houses6.gd -- atlas
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/holmvik_houses6.gd -- swap      (или dry — только отчёт)
##   godot --headless --path . -s res://tools/normal_bake.gd -- town_houses6_hd
##   потом bake_navmesh.gd (коллизия подножий меняется)
##
## Замена: ширина нового дома — между шириной старой коллизии (/0.92, чтобы
## проходы между домами не открывались) и шириной старого рисунка (+16);
## из видов с подходящим масштабом (0.86–1.2 от своего размера) берётся
## самый близкий по повороту (спереди/задом/боком) и не такой, как у соседа.
## Сгоревшие — только сгоревшими (на них огни и дым), целые — целыми.
## Ориентиры (храм, ярлов дом, рынок, медовый зал, кузня, башни) не трогаются.
## Повторный запуск берёт исходный слот из меты v6_slot.

const AU := preload("res://tools/art_util.gd")
const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const SRC := TEX + "src/hd/houses_v6/"
const ATLAS := TEX + "town_houses6_hd.png"
const META := TEX + "town_houses6_hd.json"
const TONE_REF := TEX + "town_yards_hd.png"
const TS := 2.0
const ATLAS_W := 4096
## Тон: чуть к постройкам дворов (они легли в город), контраст свой
const TONE_MIX := 0.25
const SHARPEN := 0.25
## Мусор под стеной — доля высоты картинки ниже основания (как у v2)
const DEBRIS := 0.05

## Ширина вида в мире (герой ≈ 45 px): спереди и задом — ширина дома из
## промптов, боком — торец
const NAT := {
	"cottage": 225.0, "cottage_back": 225.0,
	"gallery_house": 270.0, "gallery_house_back": 270.0,
	"stone_house": 270.0,
	"merchant_gable": 210.0, "merchant_gable_back": 210.0,
	"longhouse": 405.0, "longhouse_back": 405.0, "longhouse_side": 380.0,
	"craft_house": 292.0, "craft_house_back": 292.0,
	"storehouse": 160.0, "storehouse_back": 160.0, "storehouse_side": 170.0,
	"burnt_gallery": 270.0, "burnt_gallery_b": 270.0, "burnt_gallery_back": 270.0, "burnt_gallery_side": 235.0,
	"burnt_cottage": 225.0, "burnt_cottage_back": 225.0, "burnt_cottage_side": 210.0,
}
const INTACT := ["cottage", "cottage_back", "gallery_house", "gallery_house_back", "stone_house",
	"merchant_gable", "merchant_gable_back", "longhouse", "longhouse_back", "longhouse_side",
	"craft_house", "craft_house_back", "storehouse", "storehouse_back"]
const BURNT := ["burnt_gallery", "burnt_gallery_b", "burnt_gallery_back", "burnt_gallery_side",
	"burnt_cottage", "burnt_cottage_back", "burnt_cottage_side"]
## Что меняется (мета town_v2) и сгоревшее ли это
const REPLACE := {
	"townhouse_a": false, "townhouse_a_back": false, "townhouse_a_side": false,
	"townhouse_b": false, "townhouse_b_back": false, "townhouse_b_side": false,
	"merchant_a": false, "merchant_a_back": false, "merchant_a_side": false,
	"merchant_b": false, "merchant_b_back": false, "merchant_b_side": false,
	"longhouse_v2": false,
	"house_burnt_v2": true, "house_burnt_v2_side": true,
	"v3_townhouse_a": false, "v3_townhouse_b": false, "v3_stone_wide": false,
	"v3_tower_house": false, "v3_guildhall": false,
	"v3_burnt_shell": true, "v3_stone_longhouse": false,
	"smithy": false, "smithy_side": false,
}
## Тлеют (дым над крышей, как у сгоревших), хотя рисунок целый
const SMOULDER := ["v3_stone_longhouse"]
## Амбар — только когда ничего другого не влезает (узкие башенки v3)
const RARE := {"storehouse": 3.0, "storehouse_back": 3.0}
## Ориентир-кузня у южной улицы (стойки, доспехи) остаётся; рядовые кузни
## нижнего города меняются
const KEEP_AT := [Vector2(-1700, 1460)]
const SCALE_MIN := 0.86
const SCALE_MAX := 1.2
const SLACK := 16.0
const FOOT_COVER := 0.92
## Коллизия не глубже этой доли высоты нового рисунка
const DEPTH_MAX := 0.5

var report: Array[String] = []


func _initialize() -> void:
	for s in OS.get_cmdline_user_args():
		call("_step_" + s)
	for r in report:
		print("[houses6] ", r)
	quit()


# ───────────────────────── atlas ─────────────────────────

func _step_atlas() -> void:
	var ref := (load(TONE_REF) as Texture2D).get_image()
	ref.decompress()
	ref.convert(Image.FORMAT_RGBA8)
	var target := AU.mean_color(ref)
	var items := []
	for nm in NAT:
		var img := AU.load_hd(SRC, nm)
		if img == null:
			report.append("нет картинки %s" % nm)
			continue
		img = AU.clean_edges(img)
		img = img.get_region(img.get_used_rect())
		# Сначала в полтора раза крупнее итога — чистка отдельных кусков
		# (доска у амбара) дешевле, и итоговое уменьшение одно
		var tw := int(round(float(NAT[nm]) * TS))
		var k := tw * 1.5 / img.get_width()
		img = AU.resize_clean(img, int(img.get_width() * k), int(img.get_height() * k))
		img = AU.keep_main(img, 0.04)
		var k2 := float(tw) / img.get_width()
		img = AU.resize_clean(img, tw, int(round(img.get_height() * k2)))
		img = AU.unsharp(img, SHARPEN)
		var m := AU.mean_color(img)
		img = AU.match_tone(img, m.lerp(target, TONE_MIX))
		items.append({"name": nm, "img": img, "mean": m})
	items.sort_custom(func(a, b): return a.img.get_height() > b.img.get_height())
	var x := 0
	var y := 0
	var shelf := 0
	var pad := 4
	var placed := {}
	for it in items:
		var im: Image = it.img
		if x + im.get_width() > ATLAS_W:
			x = 0
			y += shelf + pad
			shelf = 0
		placed[it.name] = Rect2i(x, y, im.get_width(), im.get_height())
		x += im.get_width() + pad
		shelf = maxi(shelf, im.get_height())
	var ah := 1
	while ah < y + shelf:
		ah *= 2
	var atlas := Image.create(ATLAS_W, ah, false, Image.FORMAT_RGBA8)
	for it in items:
		var r: Rect2i = placed[it.name]
		atlas.blit_rect(it.img, Rect2i(Vector2i.ZERO, r.size), r.position)
	var err := atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	var meta := {"_ts": TS}
	for nm in placed:
		var r: Rect2i = placed[nm]
		meta[nm] = [r.position.x, r.position.y, r.size.x, r.size.y]
		report.append("  %s: %.0fx%.0f px мира" % [nm, r.size.x / TS, r.size.y / TS])
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	AU.write_import(ATLAS, false)
	report.append("atlas: %d видов, %dx%d (%s); тон: исходник %s → к %s на %d%%; дальше --import"
		% [placed.size(), ATLAS_W, ah, error_string(err), items[0].mean if items.size() else "", target, int(TONE_MIX * 100)])


# ───────────────────────── swap ─────────────────────────

var _meta: Dictionary
var _tex: Texture2D


func _step_dry() -> void:
	_swap(false)


func _step_swap() -> void:
	_swap(true)


static func _view(nm: String) -> String:
	if nm.ends_with("_side"):
		return "side"
	if nm.ends_with("_back"):
		return "back"
	return "front"


func _size(nm: String) -> Vector2:
	var r: Array = _meta[nm]
	return Vector2(r[2], r[3]) / TS


func _swap(write: bool) -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_tex = load(ATLAS) as Texture2D
	if _tex == null:
		report.append("ОШИБКА: нет %s — сначала atlas и --import" % ATLAS)
		return
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if lvl.get_node("Ground").get("material") == null:
		report.append("ОШИБКА: материал земли не загрузился — сначала --import")
		lvl.free()
		return
	var objects := lvl.get_node("Objects")
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	var shadows := lvl.get_node("ContactShadows")
	var sd: PackedFloat32Array = shadows.get("data")

	# Огни-пожары (campfire.tscn) внутри дома у основания: дом горит —
	# на его месте только сгоревший (иначе огонь в целом доме)
	var fires: Array[Vector2] = []
	for c in objects.get_children():
		if c is Node2D and String(c.scene_file_path).ends_with("campfire.tscn"):
			fires.append((c as Node2D).position)
	# Слоты: дом, его исходный вид, ширина рисунка, коллизия подножия
	var slots := []
	for c in objects.get_children():
		if not (c is Sprite2D):
			continue
		var s := c as Sprite2D
		var slot: Dictionary = s.get_meta("v6_slot", {})
		if slot.is_empty():
			var from := str(s.get_meta("town_v2", ""))
			if not REPLACE.has(from) or KEEP_AT.any(func(p): return s.position.distance_to(p) < 8.0):
				continue
			slot = {"from": from, "w": s.region_rect.size.x * absf(s.scale.x),
				"h": s.region_rect.size.y * absf(s.scale.y)}
		if not slot.has("burnt"):
			var on_fire := false
			for p in fires:
				if absf(p.x - s.position.x) < float(slot.w) * 0.45 and p.y < s.position.y + 10.0 and p.y > s.position.y - 45.0:
					on_fire = true
			slot["burnt"] = REPLACE[slot.from] or on_fire
		slots.append({"spr": s, "slot": slot})
	slots.sort_custom(func(a, b): return a.spr.position.y * 10000.0 + a.spr.position.x < b.spr.position.y * 10000.0 + b.spr.position.x)

	var used := {}
	var placed: Array = []  # [позиция, вид] — соседи не одинаковые
	var counts := {}
	var bad := 0
	var depth_cut := 0
	for e in slots:
		var s: Sprite2D = e.spr
		var slot: Dictionary = e.slot
		var base := s.position
		# Коллизия подножия (как в holmvik_art3: фигура у основания)
		var shape_i := -1
		for i in shapes.size():
			var rs := shapes[i] as RectangleShape2D
			if rs == null or rs.size.x <= 80.0 or rs.size.x > float(slot.w) + 12.0:
				continue
			var o: Vector2 = (xf[i] as Transform2D).origin
			if Rect2(o - rs.size * 0.5, rs.size).grow(4.0).has_point(base + Vector2(0, -6)):
				shape_i = i
				break
		var foot_w: float = slot.w * 0.86
		if shape_i >= 0:
			foot_w = (shapes[shape_i] as RectangleShape2D).size.x
			if not slot.has("foot_w"):
				slot["foot_w"] = foot_w
		if slot.has("foot_w"):
			foot_w = slot.foot_w
		var lo: float = foot_w / FOOT_COVER
		var hi: float = slot.w + SLACK
		var want := _view(slot.from)
		var pool: Array = BURNT if slot.burnt else INTACT
		var best := ""
		var best_score := INF
		var best_w := 0.0
		for nm in pool:
			if not _meta.has(nm):
				continue
			var nat: float = NAT[nm]
			var w := clampf(nat, lo, maxf(hi, lo))
			var k := w / nat
			var score := absf(log(k)) * 4.0
			if k < SCALE_MIN or k > SCALE_MAX:
				score += 20.0 + absf(log(k)) * 10.0
			var v := _view(nm)
			if v != want:
				score += 1.2 if want == "side" else 2.5
			for p in placed:
				if p[1] == nm and (p[0] as Vector2).distance_to(base) < 700.0:
					score += 1.5
			score += float(used.get(nm, 0)) * 0.08 + float(RARE.get(nm, 0.0))
			# Ровные «ничьи» разбиваются положением — не одним видом подряд
			score += fposmod(sin(base.x * 0.0131 + base.y * 0.0071 + nm.length() * 1.7) * 43758.5, 1.0) * 0.6
			if score < best_score:
				best_score = score
				best = nm
				best_w = w
		if best_score >= 20.0:
			bad += 1
			report.append("  ! %s у %s: подходящего по ширине нет, взят %s ×%.2f" % [slot.from, base.round(), best, best_w / NAT[best]])
		used[best] = used.get(best, 0) + 1
		placed.append([base, best])
		counts[best] = counts.get(best, 0) + 1
		var sz := _size(best)
		var k := best_w / sz.x
		var new_h := sz.y * k
		if not write:
			report.append("  %s %s → %s ×%.2f (%.0fx%.0f, было %.0fx%.0f)" % [slot.from, base.round(), best, best_w / NAT[best], best_w, new_h, slot.w, slot.h])
			continue
		var r: Array = _meta[best]
		s.texture = _tex
		s.region_enabled = true
		s.region_rect = Rect2(r[0], r[1], r[2], r[3])
		s.scale = Vector2(k, k) / TS
		s.offset = Vector2(0, -float(r[3]) * 0.5 + float(r[3]) * DEBRIS)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.set_meta("v6_slot", slot)
		s.set_meta("town_v2", best)
		s.set_meta("village_v2", "hut_burnt" if slot.burnt or slot.from in SMOULDER else best)
		# Коллизия: ширина та же (рисунок её закрывает); глубина — не выше
		# нижней половины нового рисунка, южный край на месте
		if shape_i >= 0:
			var rs := shapes[shape_i] as RectangleShape2D
			var o: Vector2 = (xf[shape_i] as Transform2D).origin
			var lim := (new_h - new_h * DEBRIS) * DEPTH_MAX
			if rs.size.y > lim:
				var south := o.y + rs.size.y * 0.5
				var ns := rs.duplicate() as RectangleShape2D
				ns.size.y = lim
				shapes[shape_i] = ns
				xf[shape_i] = Transform2D(0.0, Vector2(o.x, south - lim * 0.5))
				depth_cut += 1
		for i in range(0, sd.size(), 5):
			if absf(sd[i] - base.x) < 4.0 and sd[i + 1] < base.y and sd[i + 1] > base.y - 140.0 and sd[i + 2] >= 50.0:
				sd[i + 2] = best_w * 0.86 * 0.62
	report.append("%s: домов %d; виды %s; без подходящей ширины %d; коллизий мельче %d"
		% ["swap" if write else "dry", slots.size(), counts, bad, depth_cut])
	if not write:
		lvl.free()
		return
	col.set("shapes", shapes)
	col.set("shape_transforms", xf)
	shadows.set("data", sd)
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	report.append("сцена сохранена (%s)" % error_string(err))
	lvl.free()
