extends SceneTree
## Городок Хольмвик (reference_map): новые скандинавские дома вместо старых
## деревенских. Источник — картинки GPT в textures/src/hd/houses_v2/ (вид
## спереди <имя>.png, боком <имя>_side.png — дверь влево, вправо = отражение,
## задом <имя>_back.png).
##
## Устройство города (вид сверху 3/4: дом рисуется ВВЕРХ от основания и
## закрывает землю за собой — улица лежит перед фасадами):
##   главная улица (y≈1000..1110) — с севера ряд фасадов R1, на площади ярлов
##     дом, торговые ряды и медовый зал;
##   северная улица (y≈550..690) перед рядом R2;
##   южная улица (y≈1460..1610): с севера фасады R4, с юга у частокола —
##     невысокие дома задом к улице (R5);
##   переулки север-юг: у южных ворот, от площади (старая южная улочка),
##     к храму; гавань — купеческие дома у причала;
##   храм Света Бальдра — в конце главной улицы у реки (арена перед ним).
## Повороты: часть домов в рядах боком (лицом к соседнему переулку) или задом.
##
## Шаги:
##   atlas  — town_houses_hd.png (+ .json, .import): обрезка по альфе, чистка
##            каймы, масштаб по ширине в ростах героя (боком/задом — тем же
##            масштабом, что вид спереди), тон — к тону старых домов карты;
##            потом: godot --headless --path . --import
##   layout — раскладка (town_layout.json): ориентиры на своих местах, ряды
##            заполняются по улицам, переулки и места маршрута свободны;
##   apply  — сцена: старые дома (спрайты, коллизия, тени) убираются, новые
##            ставятся (метки house / village_v2 / town_v2, коллизия подножия
##            в Collision, контактная тень); под домами — чистка деревьев,
##            пропсов, мелкой коллизии, огней; улицы рисуются в маске троп
##            (paths.res); фонари вдоль улиц.
##   props  — инфраструктура: кучки у домов, рынок, кузня, дворы, телеги,
##            знамёна, святилища, следы боя на улицах (см. блок props ниже).
## Порядок: layout apply → tools/holmvik_blockout.gd -- apply (баррикады
## замыкаются по новым домам) → props → cull_hidden_ground.gd (если стиралась
## мостовая) → bake_navmesh.gd; после atlas — normal_bake.gd -- town_houses_hd.

const AU := preload("res://tools/art_util.gd")
const SCENE := "res://reference_map_level/reference_map.tscn"
const TEX := "res://reference_map_level/textures/"
const SRC := TEX + "src/hd/houses_v2/"
const ATLAS := TEX + "town_houses_hd.png"
const META := TEX + "town_houses_hd.json"
const OLD_ATLAS := TEX + "village_houses_hd.png"
const LAYOUT := "res://reference_map_level/town_layout.json"
const PATHS := TEX + "terrain/paths.res"
const HD := TEX + "hd_props.png"
const HD_META := TEX + "hd_props.json"
const WORLD := Rect2(-3520, -704, 9408, 5120)
const META_TAG := "town_v2"
const PROP_TAG := "town_prop"

## Атлас: текстура в 2 раза плотнее мира
const TEX_SCALE := 2.0
const ATLAS_W := 4096
## Насколько тон картинки сдвигается к тону старых домов (1 — целиком)
const TONE_MIX := 0.8

## Вид спереди: ширина в мире (рост героя ~45 px), доля ширины под
## коллизией, глубина коллизии (доля высоты картинки)
const FRONT := {
	"temple_baldr": {"w": 675.0, "foot": 0.80, "depth": 0.30},
	"jarl_hall": {"w": 540.0, "foot": 0.92, "depth": 0.36},
	"mead_hall": {"w": 360.0, "foot": 0.86, "depth": 0.34},
	"market_hall": {"w": 405.0, "foot": 0.90, "depth": 0.36},
	"merchant_a": {"w": 225.0, "foot": 0.88, "depth": 0.22},
	"merchant_b": {"w": 270.0, "foot": 0.88, "depth": 0.26},
	"townhouse_a": {"w": 270.0, "foot": 0.88, "depth": 0.32},
	"townhouse_b": {"w": 315.0, "foot": 0.88, "depth": 0.33},
	"longhouse_v2": {"w": 405.0, "foot": 0.92, "depth": 0.38},
	"smithy": {"w": 315.0, "foot": 0.88, "depth": 0.34},
	"watchtower": {"w": 180.0, "foot": 0.70, "depth": 0.16},
	"house_burnt_v2": {"w": 270.0, "foot": 0.84, "depth": 0.32},
}
## Боком — дом длинной стороной вглубь: коллизия глубже
const SIDE_DEPTH := 0.40
## Мусор под стеной (доля высоты картинки ниже основания)
const DEBRIS := 0.05

## Ориентиры: [картинка, основание, отражение]
const FIXED := [
	["temple_baldr", Vector2(1090, 880), false],
	["jarl_hall", Vector2(-290, 905), false],
	["market_hall", Vector2(230, 990), false],
	["mead_hall", Vector2(-800, 990), false],
	["smithy", Vector2(-1700, 1460), false],
	["watchtower", Vector2(-2200, -545), false],
	["watchtower", Vector2(-880, -545), false],
	["watchtower", Vector2(380, -545), false],
	["watchtower", Vector2(1620, -545), false],
]
## Ряды: [основание y, x от, x до, пул видов спереди, доля боком, доля задом,
##        только задом (пул задних видов)]
## Улица — два ряда лицом друг к другу: с севера фасады (основание у края
## улицы), с юга дома задом (дверь на дальней, северной стороне — на улицу)
const ROWS := [
	# Верх города (за старой северной стеной): верхняя улица y-320, высокая y150
	[-385.0, -2240.0, 1900.0, ["longhouse_v2", "townhouse_b", "townhouse_a", "house_burnt_v2", "townhouse_b"], 0.25, 0.0, false],
	[-180.0, -2240.0, 1900.0, ["townhouse_a", "townhouse_b", "merchant_b", "merchant_a"], 0.2, 1.0, true],
	[90.0, -2240.0, 1640.0, ["townhouse_a", "townhouse_b", "merchant_b", "merchant_a", "longhouse_v2", "house_burnt_v2"], 0.25, 0.0, false],
	[300.0, -2240.0, 1640.0, ["townhouse_a", "townhouse_b", "merchant_b", "merchant_a"], 0.2, 1.0, true],
	# Северная улица y622, главная y1060, южная y1538
	[550.0, -2240.0, 760.0, ["townhouse_a", "townhouse_b", "longhouse_v2", "merchant_a", "merchant_b", "house_burnt_v2"], 0.2, 0.0, false],
	[990.0, -2240.0, 560.0, ["townhouse_a", "townhouse_b", "merchant_b", "merchant_a", "house_burnt_v2"], 0.25, 0.0, false],
	[1460.0, -2240.0, 560.0, ["townhouse_a", "townhouse_b", "longhouse_v2", "merchant_b", "house_burnt_v2"], 0.2, 0.0, false],
	[1460.0, 780.0, 1600.0, ["merchant_b", "townhouse_b", "longhouse_v2", "house_burnt_v2"], 0.0, 0.0, false],
	[1850.0, -1580.0, 1600.0, ["townhouse_a", "townhouse_b"], 0.25, 1.0, true],
	# Нижний город: нижняя улица y2240
	[2170.0, -2900.0, 1900.0, ["townhouse_b", "longhouse_v2", "merchant_b", "townhouse_a", "house_burnt_v2", "smithy"], 0.25, 0.0, false],
	[2420.0, -2900.0, 1900.0, ["townhouse_a", "townhouse_b", "merchant_b", "merchant_a"], 0.3, 1.0, true],
]
## Разброс основания по y в ряду; переулок каждые 3–5 домов (ширина) и
## зазор между соседними домами — город, а не хутора
const ROW_JITTER := 12.0
const ALLEY := Vector2(56, 84)
const HOUSE_GAP := Vector2(6, 26)
const GROUP := Vector2i(3, 5)
## Мостовая, которая остаётся (остальная в городе стирается): главная улица
## до реки, площадь, южная улочка, причал
const KEEP_STONE := [
	Rect2(-2460, 1000, 3900, 134), Rect2(-600, 900, 1020, 400),
	Rect2(-385, 1110, 200, 780), Rect2(1328, 860, 760, 1060),
]
const STONE_CLEAR := Rect2(-2460, -640, 3790, 3240)
## Где старые тропинки (маска троп R, B) стираются перед рисованием улиц;
## [прямоугольник, стереть и B (в нижнем городе B — старые каменные дорожки, шейдер делает их землёй: не трогать)]
const PATHS_CLEAR := [
	[Rect2(-2270, -640, 4200, 2510), true],
	[Rect2(-2950, 1890, 4920, 710), false],
]
## Подножия домов сюда не заходят: площадь, улицы, переулки, арена, ферма,
## причал, проход у частокола
const FREE_RECTS := [
	Rect2(-570, 915, 560, 370),     # площадь
	Rect2(-2300, 1000, 3100, 120),  # главная улица
	Rect2(-2300, 555, 3900, 130),   # северная улица
	Rect2(-2300, 1465, 3950, 150),  # южная улица
	Rect2(-1510, 1110, 120, 360),   # переулок у южных ворот
	Rect2(-385, 1110, 200, 780),    # южная улочка от площади
	Rect2(560, 1110, 220, 360),     # переулок к храму
	Rect2(-645, 690, 100, 230),     # проход с северной улицы на площадь
	Rect2(770, 860, 650, 540),      # двор-арена храма
	Rect2(-2960, 0, 690, 1900),     # ферма и запад
	Rect2(1600, 1040, 500, 900),    # причал
	Rect2(-2960, -640, 4990, 70),   # частокол север
	Rect2(1940, -640, 100, 600),    # восточная стена верха
	Rect2(-2300, -375, 4200, 110),  # верхняя улица
	Rect2(-2300, 95, 4200, 110),    # высокая улица
	Rect2(-1510, -265, 120, 820),   # переулок верх — северная улица (запад)
	Rect2(340, -265, 120, 820),     # переулок верх — северная улица (восток)
	Rect2(-2960, 1855, 4700, 40),   # частокол юг (внутренняя стена)
	# Нижний город
	Rect2(-2960, 2180, 4900, 120),  # нижняя улица
	Rect2(-1990, 1880, 160, 420),   # переулок к внутренним воротам
	Rect2(1040, 2280, 220, 330),    # переулок от внешних ворот
	Rect2(-2960, 2585, 4950, 40),   # внешний частокол
	Rect2(1930, 1880, 60, 740),     # восточная стена
]
## Круги без домов: старт, костры
const FREE_CIRCLES := [
	[Vector2(-1900, 1800), 150.0], [Vector2(-1700, 1770), 160.0], [Vector2(-169, 1298), 160.0],
	[Vector2(700, 1300), 150.0], [Vector2(-1910, 1880), 170.0],
	[Vector2(1150, 2530), 160.0], [Vector2(960, 2470), 160.0], [Vector2(-250, 2070), 170.0],
]
## Улицы в маске троп: [точки, ширина]
const STREETS := [
	[[Vector2(-2250, -320), Vector2(1900, -320)], 110.0],
	[[Vector2(-2250, 150), Vector2(1650, 150)], 110.0],
	[[Vector2(-1450, -265), Vector2(-1450, 560)], 90.0],
	[[Vector2(400, -265), Vector2(400, 560)], 90.0],
	[[Vector2(-2250, 622), Vector2(1500, 622)], 116.0],
	[[Vector2(-2250, 1538), Vector2(1610, 1538)], 128.0],
	[[Vector2(-1450, 1110), Vector2(-1450, 1470)], 90.0],
	[[Vector2(670, 1110), Vector2(670, 1470)], 96.0],
	[[Vector2(-595, 690), Vector2(-595, 920)], 74.0],
	[[Vector2(-1910, 1900), Vector2(-1880, 1700), Vector2(-1760, 1560)], 84.0],
	# Нижний город: улица (оврага больше нет — прямая), переулки к воротам
	[[Vector2(1900, 2240), Vector2(-2900, 2240)], 120.0],
	[[Vector2(1150, 2580), Vector2(1150, 2240)], 96.0],
	[[Vector2(-1910, 2240), Vector2(-1910, 1880)], 90.0],
]
const LANTERN_STEP := 420.0

var report: Array[String] = []
var _meta: Dictionary


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["layout"]
	for s in steps:
		call("_step_" + s)
	for r in report:
		print("[holmvik_town] ", r)
	quit()


# ───────────────────────── atlas ─────────────────────────

func _step_atlas() -> void:
	var old := (load(OLD_ATLAS) as Texture2D).get_image()
	old.decompress()
	old.convert(Image.FORMAT_RGBA8)
	var target := AU.mean_color(old)
	var names: Array[String] = []
	for f in DirAccess.get_files_at(SRC):
		if f.ends_with(".png"):
			names.append(f.get_basename())
	names.sort()
	var px_k := {}  # мир на пиксель исходника — по виду спереди
	var items := []
	# Сначала виды спереди (их масштаб нужен боковым и задним)
	names.sort_custom(func(a, b): return int(a.contains("_side") or a.contains("_back")) < int(b.contains("_side") or b.contains("_back")))
	for nm in names:
		var kind := _kind_of(nm)
		if not FRONT.has(kind):
			report.append("пропуск %s: нет вида %s в FRONT" % [nm, kind])
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + nm + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		img = AU.clean_edges(img)
		img = img.get_region(_alpha_bbox(img, 0.04))
		var world_w: float
		if nm == kind:
			world_w = FRONT[kind].w
			px_k[kind] = world_w / img.get_width()
		else:
			world_w = img.get_width() * float(px_k.get(kind, FRONT[kind].w / img.get_width()))
		var tw := int(round(world_w * TEX_SCALE))
		var th := int(round(float(img.get_height()) * tw / img.get_width()))
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		var m := AU.mean_color(img)
		img = AU.match_tone(img, m.lerp(target, TONE_MIX))
		items.append({"name": nm, "img": img})
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
	var meta := {}
	for nm in placed:
		var r: Rect2i = placed[nm]
		meta[nm] = {"rect": [r.position.x, r.position.y, r.size.x, r.size.y]}
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	# Импорт как у атласа старых домов: BPTC, без мипмапов
	var imp := FileAccess.open(ProjectSettings.globalize_path(ATLAS) + ".import", FileAccess.WRITE)
	imp.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\n"
		+ "compress/mode=2\ncompress/high_quality=true\ncompress/lossy_quality=0.7\n"
		+ "compress/uastc_level=0\ncompress/rdo_quality_loss=0.0\ncompress/hdr_compression=1\n"
		+ "compress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=false\nmipmaps/limit=-1\n"
		+ "roughness/mode=0\nroughness/src_normal=\"\"\nprocess/channel_remap/red=0\n"
		+ "process/channel_remap/green=1\nprocess/channel_remap/blue=2\nprocess/channel_remap/alpha=3\n"
		+ "process/fix_alpha_border=true\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\n"
		+ "process/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\n"
		+ "detect_3d/compress_to=1\n")
	imp.close()
	report.append("atlas: %d картинок, %dx%d (%s); тон к %s; дальше --import" % [placed.size(), ATLAS_W, ah, error_string(err), target])


func _alpha_bbox(img: Image, thr: float) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > thr:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	x0 = maxi(x0 - 2, 0)
	y0 = maxi(y0 - 2, 0)
	x1 = mini(x1 + 2, w - 1)
	y1 = mini(y1 + 2, h - 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


static func _kind_of(nm: String) -> String:
	return nm.trim_suffix("_side").trim_suffix("_back")


# ───────────────────────── геометрия ─────────────────────────

func _load_meta() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))


func _size(nm: String) -> Vector2:
	var r: Array = _meta[nm].rect
	return Vector2(r[2], r[3]) / TEX_SCALE


## Подножие (коллизия) над основанием
func _foot(nm: String, base: Vector2) -> Rect2:
	var sz := _size(nm)
	var kind := _kind_of(nm)
	var fw: float = sz.x * FRONT[kind].foot
	var fd: float = sz.y * (SIDE_DEPTH if nm.ends_with("_side") else FRONT[kind].depth)
	return Rect2(base.x - fw * 0.5, base.y - fd, fw, fd)


func _sprite_rect(nm: String, base: Vector2) -> Rect2:
	var sz := _size(nm)
	return Rect2(base.x - sz.x * 0.5, base.y + sz.y * DEBRIS - sz.y, sz.x, sz.y)


# ───────────────────────── layout ─────────────────────────

func _step_layout() -> void:
	_load_meta()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	var houses: Array = []
	var feet: Array[Rect2] = []
	for f in FIXED:
		houses.append({"name": f[0], "x": f[1].x, "y": f[1].y, "flip": f[2]})
		feet.append(_foot(f[0], f[1]).grow(30))
	var counts := {}
	for row in ROWS:
		var y: float = row[0]
		var x: float = row[1] + rng.randf_range(0, 40)
		var x_end: float = row[2]
		var pool: Array = row[3]
		var p_side: float = row[4]
		var p_back: float = row[5]
		var prev := ""
		var tries := 0
		var group := 0
		var group_len := rng.randi_range(GROUP.x, GROUP.y)
		while x < x_end and tries < 400:
			tries += 1
			# Переулок: дома группами, между группами проход
			if group >= group_len:
				x += rng.randf_range(ALLEY.x, ALLEY.y)
				group = 0
				group_len = rng.randi_range(GROUP.x, GROUP.y)
			var kind: String = pool[rng.randi() % pool.size()]
			if kind == prev and pool.size() > 1:
				kind = pool[(pool.find(kind) + 1) % pool.size()]
			var nm := kind
			var roll := rng.randf()
			if roll < p_back and _meta.has(kind + "_back"):
				nm = kind + "_back"
			elif roll < p_back + p_side and _meta.has(kind + "_side"):
				nm = kind + "_side"
			if not _meta.has(nm):
				x += 40.0
				continue
			var w := _size(nm).x
			if x + w > x_end:
				break
			var base := Vector2(x + w * 0.5, y + rng.randf_range(-ROW_JITTER, ROW_JITTER * 0.3))
			var fp := _foot(nm, base)
			if not _free(fp, feet):
				x += 32.0
				continue
			# Боком — дверью к переулку: первый в группе смотрит влево (на
			# прошлый переулок), остальные — вправо (на следующий)
			var flip := rng.randf() < 0.5
			if nm.ends_with("_side"):
				flip = group != 0
			group += 1
			houses.append({"name": nm, "x": base.x, "y": base.y, "flip": flip})
			feet.append(fp.grow(18))
			counts[nm] = counts.get(nm, 0) + 1
			prev = kind
			x += w + rng.randf_range(HOUSE_GAP.x, HOUSE_GAP.y)
	var data := {"houses": houses}
	var f := FileAccess.open(LAYOUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	report.append("layout: %d зданий (%d ориентиров); виды: %s" % [houses.size(), FIXED.size(), counts])


func _free(fp: Rect2, feet: Array[Rect2]) -> bool:
	for r in FREE_RECTS:
		if fp.intersects(r):
			return false
	for c in FREE_CIRCLES:
		if _rect_dist(fp, c[0]) < c[1]:
			return false
	for r in feet:
		if fp.intersects(r):
			return false
	return true


func _rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func _in_any(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


# ───────────────────────── apply ─────────────────────────

func _step_apply() -> void:
	_load_meta()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var tex := load(ATLAS) as Texture2D
	if tex == null:
		report.append("ОШИБКА: атлас не импортирован — atlas, потом --import")
		return
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	if lvl.get_node("Ground").get("material") == null:
		report.append("ОШИБКА: материал земли не загрузился — сначала --import")
		lvl.free()
		return
	var objects := lvl.get_node("Objects")
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xf: Array = col.get("shape_transforms")
	var shadows := lvl.get_node("ContactShadows")
	var sdata: PackedFloat32Array = shadows.get("data")

	# 1. Старые дома (и прошлая раскладка городка): спрайты, коллизия, тени
	var old: Array[Rect2] = []
	var removed_old := 0
	for n in objects.get_children():
		if n is Sprite2D and (n.has_meta("village_v2") or n.has_meta(META_TAG)):
			var s := n as Sprite2D
			var r := s.get_rect()
			var bb := Rect2(s.transform * r.position, Vector2.ZERO).expand(s.transform * r.end).abs()
			old.append(Rect2(bb.position.x - 6, bb.end.y - bb.size.y * 0.5, bb.size.x + 12, bb.size.y * 0.5 + 14))
			objects.remove_child(n)
			n.free()
			removed_old += 1
	for n in objects.get_children():
		if n.has_meta(META_TAG) or n.has_meta(PROP_TAG):
			objects.remove_child(n)
			n.free()
	for n in lvl.get_node("Night").get_children():
		if n.has_meta(META_TAG):
			n.get_parent().remove_child(n)
			n.free()
	var keep_s: Array[Shape2D] = []
	var keep_x: Array[Transform2D] = []
	var old_shapes := 0
	for i in shapes.size():
		var s: Shape2D = shapes[i]
		var o: Vector2 = (xf[i] as Transform2D).origin
		if s is RectangleShape2D and maxf(s.size.x, s.size.y) >= 50.0 and _in_any(o, old):
			old_shapes += 1
			continue
		keep_s.append(s)
		keep_x.append(xf[i])
	var nd := PackedFloat32Array()
	for i in range(0, sdata.size(), 5):
		if sdata[i + 2] >= 50.0 and _in_any(Vector2(sdata[i], sdata[i + 1]), old):
			continue
		nd.append_array(sdata.slice(i, i + 5))

	# 2. Новые дома
	var clear_zones: Array[Rect2] = []
	var new_shapes := 0
	var n_h := 0
	for h in layout.houses:
		var nm: String = h.name
		var base := Vector2(h.x, h.y)
		var r: Array = _meta[nm].rect
		var size := Vector2(r[2], r[3])
		var spr := Sprite2D.new()
		spr.name = "Town%d" % n_h
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = Rect2(r[0], r[1], r[2], r[3])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.scale = Vector2.ONE / TEX_SCALE
		spr.flip_h = h.flip
		spr.position = base
		spr.offset = Vector2(0, -size.y * 0.5 + size.y * DEBRIS)
		spr.set_meta("house", true)
		var kind := _kind_of(nm)
		spr.set_meta("village_v2", "hut_burnt" if kind == "house_burnt_v2" else kind)
		spr.set_meta(META_TAG, nm)
		objects.add_child(spr)
		spr.owner = lvl
		var fp := _foot(nm, base)
		var rs := RectangleShape2D.new()
		rs.size = fp.size
		keep_s.append(rs)
		keep_x.append(Transform2D(0.0, fp.get_center()))
		new_shapes += 1
		nd.append_array(PackedFloat32Array([base.x, base.y - fp.size.y * 0.35, fp.size.x * 0.62, fp.size.y * 0.75, 0.45]))
		var sr := _sprite_rect(nm, base)
		clear_zones.append(Rect2(sr.position.x + 4, sr.position.y + sr.size.y * 0.33, sr.size.x - 8, sr.size.y * 0.67 + 10))
		n_h += 1

	# 3. Под домами: деревья, декор, пропсы, мелкая коллизия, огни, тени
	var erased := 0
	for layer_path in ["Objects/Decor", "Objects/Wilds", "Objects/Ruins", "Objects/PurpleForest", "Grime", "SouthMarks"]:
		var tl := lvl.get_node_or_null(layer_path) as TileMapLayer
		if tl == null:
			continue
		for c in tl.get_used_cells():
			var p := tl.transform * tl.map_to_local(c)
			if layer_path.begins_with("Objects/"):
				p = (tl.get_parent() as Node2D).transform * p
			if _in_any(p, clear_zones):
				tl.erase_cell(c)
				erased += 1
	var props := 0
	for n in objects.get_children():
		if n is Sprite2D and n.has_meta("hd_prop") and not n.has_meta("blockout") and _in_any((n as Node2D).position, clear_zones):
			objects.remove_child(n)
			n.free()
			props += 1
	var fs: Array[Shape2D] = []
	var fx: Array[Transform2D] = []
	var small := 0
	var new_from := keep_s.size() - new_shapes
	for i in keep_s.size():
		var s := keep_s[i]
		if i < new_from and s is RectangleShape2D and maxf(s.size.x, s.size.y) < 130.0 and _in_any(keep_x[i].origin, clear_zones):
			small += 1
			continue
		fs.append(s)
		fx.append(keep_x[i])
	col.set("shapes", fs)
	col.set("shape_transforms", fx)
	var lights := 0
	for t in lvl.get_node("Night").get_children():
		if t is Node2D and not t.has_meta("blockout") and _in_any((t as Node2D).position, clear_zones):
			t.get_parent().remove_child(t)
			t.free()
			lights += 1
	var nd2 := PackedFloat32Array()
	var house_from := nd.size() - n_h * 5
	for i in range(0, nd.size(), 5):
		if i < house_from and _in_any(Vector2(nd[i], nd[i + 1]), clear_zones):
			continue
		nd2.append_array(nd.slice(i, i + 5))
	shadows.set("data", nd2)

	# 4. Фонари вдоль улиц (перед фасадами, где нет домов)
	var lamps := _lanterns(lvl, objects, fs, fx)

	# 5. Старая мостовая деревни (переулки к старым домам) — стереть
	var stone := lvl.get_node("Stone") as TileMapLayer
	var stone_cut := 0
	for c in stone.get_used_cells():
		var p := stone.transform * stone.map_to_local(c)
		if STONE_CLEAR.has_point(p) and not _in_any(p, KEEP_STONE):
			stone.erase_cell(c)
			stone_cut += 1
	report.append("мостовой стёрто %d клеток" % stone_cut)

	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	lvl.free()
	report.append("apply: старых домов %d (коллизий %d); новых %d; под домами убрано тайлов %d, пропсов %d, мелкой коллизии %d, огней %d; фонарей %d; сцена (%s)"
		% [removed_old, old_shapes, n_h, erased, props, small, lights, lamps, error_string(err)])
	if err == OK:
		_paint_streets()


## Фонари: вдоль главной, северной и южной улиц шагом LANTERN_STEP, у края
## улицы со стороны фасадов; не в коллизии
func _lanterns(lvl: Node, objects: Node, fs: Array[Shape2D], fx: Array[Transform2D]) -> int:
	var hd_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HD_META))
	var hd := load(HD) as Texture2D
	var src := lvl.get_node_or_null("Night/Lantern28") as PointLight2D
	var lines := [[1004.0, -2150.0, 600.0], [566.0, -2150.0, 1450.0], [1470.0, -2150.0, 1550.0], [2186.0, -2800.0, 1850.0], [-375.0, -2150.0, 1850.0], [95.0, -2150.0, 1600.0]]
	var n := 0
	for ln in lines:
		var x: float = ln[1]
		while x <= ln[2]:
			var p := Vector2(x, ln[0])
			if not _blocked(p, fs, fx) and not _in_any(p, [Rect2(-570, 915, 560, 370), Rect2(770, 860, 650, 540)]):
				var r: Array = hd_meta["port_lantern@81x144"]
				var s := Sprite2D.new()
				s.name = "TownLantern%d" % n
				s.texture = hd
				s.region_enabled = true
				s.region_rect = Rect2(r[0], r[1], r[2], r[3])
				s.centered = false
				s.scale = Vector2(0.5, 0.5)
				s.offset = Vector2(-r[2] * 0.5, -r[3] + 4.0)
				s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				s.position = p
				s.set_meta(META_TAG, "lantern")
				objects.add_child(s)
				s.owner = lvl
				var body := StaticBody2D.new()
				body.name = "Body"
				var cs := CollisionShape2D.new()
				var sh := RectangleShape2D.new()
				sh.size = Vector2(20, 12)
				cs.shape = sh
				cs.position = Vector2(0, -6)
				s.add_child(body)
				body.owner = lvl
				body.add_child(cs)
				cs.owner = lvl
				if src:
					var light := src.duplicate() as PointLight2D
					light.name = "LanternTown%d" % n
					light.position = p + Vector2(11, -54)
					light.set_meta(META_TAG, "lantern")
					lvl.get_node("Night").add_child(light)
					light.owner = lvl
				n += 1
			x += LANTERN_STEP
	return n


func _blocked(p: Vector2, fs: Array[Shape2D], fx: Array[Transform2D]) -> bool:
	for i in fs.size():
		var s := fs[i] as RectangleShape2D
		if s and Rect2(fx[i].origin - s.size * 0.5, s.size).grow(14).has_point(p):
			return true
	return false


## Улицы — в маске троп (R): мягкая кисть вдоль ломаных
func _paint_streets() -> void:
	var img := (load(PATHS) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var k := img.get_width() / WORLD.size.x
	# Старые тропинки к домам деревни (R) и «тропинки из мостовой» (B)
	for pc in PATHS_CLEAR:
		var pr: Rect2 = pc[0]
		var cx0 := int((pr.position.x - WORLD.position.x) * k)
		var cx1 := int((pr.end.x - WORLD.position.x) * k)
		var cy0 := int((pr.position.y - WORLD.position.y) * k)
		var cy1 := int((pr.end.y - WORLD.position.y) * k)
		for ty in range(cy0, cy1):
			for tx in range(cx0, cx1):
				var c0 := img.get_pixel(tx, ty)
				c0.r = 0.0
				if pc[1]:
					c0.b = 0.0
				img.set_pixel(tx, ty, c0)
	var painted := 0
	for st in STREETS:
		var pts: Array = st[0]
		var half: float = st[1] * 0.5
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var bb := Rect2(a, Vector2.ZERO).expand(b).grow(half + 8)
			var tx0 := int((bb.position.x - WORLD.position.x) * k)
			var tx1 := int((bb.end.x - WORLD.position.x) * k)
			var ty0 := int((bb.position.y - WORLD.position.y) * k)
			var ty1 := int((bb.end.y - WORLD.position.y) * k)
			for ty in range(maxi(ty0, 0), mini(ty1, img.get_height() - 1) + 1):
				for tx in range(maxi(tx0, 0), mini(tx1, img.get_width() - 1) + 1):
					var p := WORLD.position + Vector2(tx + 0.5, ty + 0.5) / k
					var d := _seg_dist(p, a, b)
					# Неровный край: шум по точке
					var edge := half * (0.85 + 0.3 * _hash(tx, ty))
					var v := 1.0 - smoothstep(edge - 14.0, edge, d)
					if v <= 0.0:
						continue
					var c := img.get_pixel(tx, ty)
					if v > c.r:
						c.r = v
						img.set_pixel(tx, ty, c)
						painted += 1
	var tex := ImageTexture.create_from_image(img)
	var err := ResourceSaver.save(tex, PATHS)
	report.append("улицы в маске троп: %d текселей (%s)" % [painted, error_string(err)])


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0


# ───────────────────────── props (инфраструктура) ─────────────────────────
## Шаг props — после holmvik_blockout.gd apply (завалы уже стоят), потом
## навмеш. Повторять можно: всё своё (мета town_prop) удаляется и ставится
## заново. Бочки и ящики (hd barrel/barrels2/crate/crates_stack) — без упора:
## в игре их делает разбиваемыми scripts/breakables.gd.
##
## Сцены:
##   у домов     — у угла подножия кучка: бочки, ящики, мешки, ведро, тачка;
##   рынок       — на южной половине площади прилавки, столы, товар;
##   медовый зал — столы, бочки, котёл;
##   кузня       — стойки с оружием, доспех, щиты, бочка;
##   дворы       — в широких переулках: стог, тюки, корыто, плуг;
##   телеги      — у края улиц;
##   святилища и знамёна — у площади и ворот;
##   следы боя   — на улицах маршрута: щиты, шлемы, мечи, стрелы, копья.

const TOWN_PROPS := TEX + "town_props_hd.png"
const TOWN_PROPS_META := TEX + "town_props_hd.json"
const FARM := TEX + "farm_props.png"
const FARM_META := TEX + "farm_props.json"
const CAMP := TEX + "camp_hd.png"
const CAMP_META := TEX + "camp_hd.json"
## Упор у основания (px мира); нет в списке — без упора
const BODY := {
	"sacks@96x76": Vector2(36, 10), "sacks@136x107": Vector2(52, 12),
	"cart_broken@188x133": Vector2(80, 22), "wagon@250x190": Vector2(110, 30),
	"weapon_rack@112x158": Vector2(46, 12), "armor_stand@77x170": Vector2(22, 10),
	"shrine@50x86": Vector2(18, 8),
	"rack": Vector2(56, 12), "table": Vector2(60, 16), "supply": Vector2(84, 22),
	"cauldron": Vector2(40, 14), "drum": Vector2(30, 12), "shields": Vector2(40, 12),
	"standard": Vector2(10, 8), "target": Vector2(30, 10),
	"haystack": Vector2(70, 26), "bale_a": Vector2(48, 16), "bale_b": Vector2(48, 16),
	"trough": Vector2(66, 14), "wheelbarrow": Vector2(56, 14), "plough": Vector2(60, 14),
	# Арт партии 2 (town_props_hd)
	"yard_well": Vector2(62, 26), "yard_woodpile": Vector2(116, 22), "yard_garden": Vector2(112, 30),
	"yard_fishrack": Vector2(72, 12), "yard_rainbarrel": Vector2(28, 12), "yard_pen": Vector2(92, 40),
	"ds_standard": Vector2(12, 8), "ds_shield_post": Vector2(16, 8), "ds_brazier": Vector2(20, 10),
	"ds_altar": Vector2(56, 22),
}
const HOUSE_JUNK := [
	["hd", "barrel@52x77"], ["hd", "barrels2@112x113"], ["hd", "crate@86x108"],
	["hd", "crates_stack@102x138"], ["hd", "sacks@96x76"], ["town", "yard_rainbarrel"],
	["farm", "wheelbarrow"], ["town", "yard_chopblock"], ["town", "yard_woodpile"], ["farm", "tools"],
	["hd", "bucket@62x85"], ["town", "yard_rainbarrel"],
]
const BATTLE_DEBRIS := [["camp", "sword"], ["camp", "shield"], ["camp", "helmet"], ["camp", "arrows"],
	["camp", "spear"], ["camp", "bow"], ["camp", "shield_split"], ["camp", "banner_ground"], ["town", "ds_spear"]]
## Неподвижные сцены: [лист, ключ, основание, отражение]
const FIXED_PROPS := [
	# Рынок — южная половина площади
	["camp", "supply", Vector2(-520, 1215), false], ["camp", "supply", Vector2(-400, 1268), true],
	["camp", "table", Vector2(-120, 1210), false], ["camp", "supply", Vector2(-60, 1268), false],
	["hd", "sacks@136x107", Vector2(-250, 1275), false], ["hd", "crates_stack@102x138", Vector2(-590, 1270), false],
	["hd", "barrels2@112x113", Vector2(20, 1205), true],
	# Торговые ряды — бока
	["camp", "table", Vector2(470, 975), true], ["hd", "sacks@96x76", Vector2(500, 1000), false],
	["hd", "crates_stack@102x138", Vector2(-10, 985), false],
	# Медовый зал
	["camp", "table", Vector2(-1020, 985), false], ["hd", "barrels2@112x113", Vector2(-590, 985), true],
	["camp", "cauldron", Vector2(-1080, 960), false],
	# Кузня
	["hd", "weapon_rack@112x158", Vector2(-1900, 1455), false], ["camp", "rack", Vector2(-1500, 1455), true],
	["hd", "armor_stand@77x170", Vector2(-1960, 1440), false], ["camp", "shields", Vector2(-1530, 1420), false],
	["hd", "barrel@52x77", Vector2(-1450, 1445), false],
	# Орден Тёмного Солнца: штандарты у ярлова дома и у ворот, щиты на столбах,
	# жаровни; святилища Бальдра
	["town", "ds_standard", Vector2(-600, 925), false], ["town", "ds_standard", Vector2(20, 925), true],
	["town", "ds_standard", Vector2(-2130, 1830), false], ["town", "ds_brazier", Vector2(-380, 1030), false],
	["town", "ds_brazier", Vector2(-200, 1030), true], ["town", "ds_shield_post", Vector2(-1080, 700), false],
	["town", "ds_shield_post", Vector2(300, 1620), true], ["town", "ds_standard", Vector2(1330, 2470), false],
	["town", "ds_altar", Vector2(-400, 1120), false],
	["hd", "shrine@50x86", Vector2(-660, 1290), false], ["hd", "shrine@50x86", Vector2(560, 1130), false],
	["hd", "shrine@50x86", Vector2(-2000, 2290), false], ["hd", "shrine@50x86", Vector2(700, 2290), false],
	# Колодцы (что не встанет — пропускается)
	["town", "yard_well", Vector2(-1700, 760), false], ["town", "yard_well", Vector2(-150, 770), false],
	["town", "yard_well", Vector2(480, 760), true], ["town", "yard_well", Vector2(-1250, 1690), false],
	["town", "yard_well", Vector2(-2250, 2380), false], ["town", "yard_well", Vector2(-250, 2380), true],
	["town", "yard_well", Vector2(1450, 2380), false],
	# Вешала с рыбой — у причала
	["town", "yard_fishrack", Vector2(1450, 1700), false], ["town", "yard_fishrack", Vector2(1560, 1760), true],
]
## Знамёна Ордена на частоколе: [x, y основания стены]
const WALL_BANNERS := [[-2500.0, 20.0], [-1200.0, 20.0], [100.0, 20.0], [1200.0, 20.0],
	[-2300.0, 1880.0], [-1200.0, 1880.0], [-200.0, 1880.0], [800.0, 1880.0],
	[-2500.0, 2600.0], [-1400.0, 2600.0], [-300.0, 2600.0], [1600.0, 2600.0]]
const YARD := [["town", "yard_woodpile"], ["town", "yard_laundry"], ["town", "yard_garden"],
	["farm", "haystack"], ["town", "yard_pen"], ["farm", "trough"], ["town", "yard_chopblock"],
	["town", "yard_laundry"], ["farm", "bale_a"]]
const CARTS := 9
const DEBRIS_STEP := 130.0
const DEBRIS_CHANCE := 0.45

var _sheets := {}
var _blockers: Array[Rect2] = []
var _keep_circles: Array = []
var _prng := RandomNumberGenerator.new()


func _step_props() -> void:
	_load_meta()
	_prng.seed = 18112026
	_sheets["hd"] = [load(HD), JSON.parse_string(FileAccess.get_file_as_string(HD_META))]
	_sheets["farm"] = [load(FARM), JSON.parse_string(FileAccess.get_file_as_string(FARM_META))]
	_sheets["camp"] = [load(CAMP), JSON.parse_string(FileAccess.get_file_as_string(CAMP_META))]
	_sheets["town"] = [load(TOWN_PROPS), JSON.parse_string(FileAccess.get_file_as_string(TOWN_PROPS_META))]
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	var objects := lvl.get_node("Objects")
	var removed := 0
	for n in objects.get_children():
		if n.has_meta(PROP_TAG):
			objects.remove_child(n)
			n.free()
			removed += 1
	_collect_blockers(lvl)
	_keep_circles = [
		[Vector2(-950, 625), 180.0], [Vector2(150, 1540), 180.0],
		[Vector2(-1910, 1880), 150.0], [Vector2(1150, 2590), 150.0],
		[Vector2(1150, 2530), 120.0],
	]
	for b in objects.get_children():
		var bn := String(b.name)
		if bn.begins_with("Bonfire"):
			_keep_circles.append([(b as Node2D).position, 120.0])
		elif bn.begins_with("Enemy_"):
			_keep_circles.append([(b as Node2D).position, 60.0])
	var counts := {}
	# 1. Неподвижные сцены
	for f in FIXED_PROPS:
		if _place(objects, lvl, f[0], f[1], f[2], f[3], true):
			counts["fixed"] = counts.get("fixed", 0) + 1
	# 2. Кучки у домов
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var by_row := {}
	for h in layout.houses:
		var nm: String = h.name
		var kind := _kind_of(nm)
		if kind in ["temple_baldr", "jarl_hall", "watchtower"]:
			continue
		var base := Vector2(h.x, h.y)
		var fp := _foot(nm, base)
		var row := int(round(base.y / 40.0))
		if not by_row.has(row):
			by_row[row] = []
		by_row[row].append(fp)
		if _prng.randf() > 0.7:
			continue
		var side := 1.0 if _prng.randf() < 0.5 else -1.0
		var x := fp.end.x + 10.0 if side > 0.0 else fp.position.x - 10.0
		var y := base.y + _prng.randf_range(-4, 16)
		for i in _prng.randi_range(1, 3):
			var j: Array = HOUSE_JUNK[_prng.randi() % HOUSE_JUNK.size()]
			var w := _world_w(j[0], j[1])
			var at := Vector2(x + side * w * 0.5, y + _prng.randf_range(-6, 6))
			if _place(objects, lvl, j[0], j[1], at, _prng.randf() < 0.5, false):
				counts["house"] = counts.get("house", 0) + 1
				x += side * (w + 2.0)
	# 3. Дворы в широких переулках (между соседними подножиями ряда)
	for row in by_row:
		var feet: Array = by_row[row]
		feet.sort_custom(func(a, b): return a.position.x < b.position.x)
		for i in range(1, feet.size()):
			var a: Rect2 = feet[i - 1]
			var b: Rect2 = feet[i]
			var gap := b.position.x - a.end.x
			if gap < 60.0 or gap > 420.0 or _prng.randf() > 0.9:
				continue
			var cx := (a.end.x + b.position.x) * 0.5
			# Два яруса: у фасадов и глубже во дворе; по 4 попытки на ярус
			for dy in [-24.0, -80.0]:
				for attempt in 4:
					var item: Array = YARD[_prng.randi() % YARD.size()]
					var at := Vector2(cx + _prng.randf_range(-12, 12), maxf(a.end.y, b.end.y) + dy)
					if _place(objects, lvl, item[0], item[1], at, _prng.randf() < 0.5, false):
						counts["yard"] = counts.get("yard", 0) + 1
						break
	# 3б. Знамёна Ордена на частоколе (прибиты к стене со стороны города)
	for wb in WALL_BANNERS:
		if _place(objects, lvl, "town", "ds_banner", Vector2(wb[0], wb[1] + 6.0), _prng.randf() < 0.5, true, true):
			counts["wall_banner"] = counts.get("wall_banner", 0) + 1
	# 4. Телеги у края улиц
	var carts := 0
	var tries := 0
	while carts < CARTS and tries < 400:
		tries += 1
		var st: Array = STREETS[_prng.randi() % STREETS.size()]
		var pts: Array = st[0]
		var half: float = st[1] * 0.5
		var i := _prng.randi_range(1, pts.size() - 1)
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		if absf(a.y - b.y) > 4.0:
			continue
		var p := a.lerp(b, _prng.randf())
		var key := "wagon@250x190" if _prng.randf() < 0.4 else "cart_broken@188x133"
		var off := half + 26.0 if _prng.randf() < 0.5 else -half + 4.0
		if _place(objects, lvl, "hd", key, p + Vector2(0, off), _prng.randf() < 0.5, false):
			carts += 1
	counts["carts"] = carts
	# 5. Следы боя на улицах (без упора, можно на улице)
	var debris := 0
	for st in STREETS:
		var pts: Array = st[0]
		var half: float = st[1] * 0.5
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var t := 0.0
			var seg_len := a.distance_to(b)
			while t < seg_len:
				t += DEBRIS_STEP * _prng.randf_range(0.6, 1.4)
				if _prng.randf() > DEBRIS_CHANCE:
					continue
				var p := a.lerp(b, minf(t / seg_len, 1.0))
				var nrm := (b - a).normalized().orthogonal()
				p += nrm * _prng.randf_range(-half * 0.8, half * 0.8)
				var d: Array = BATTLE_DEBRIS[_prng.randi() % BATTLE_DEBRIS.size()]
				if _place(objects, lvl, d[0], d[1], p, _prng.randf() < 0.5, true):
					debris += 1
	counts["debris"] = debris
	# 6. Город ещё горит: огонь на пепелищах (сгоревшие дома — дым над ними
	# рисует immersion.gd) и у части завалов
	var fire_scene := load(CAMPFIRE) as PackedScene
	var fires := 0
	for h in layout.houses:
		if not String(h.name).begins_with("house_burnt"):
			continue
		var w := _size(h.name).x
		for dx in [-0.22, 0.18]:
			_fire(objects, lvl, fire_scene, Vector2(h.x + w * dx, h.y - 26.0 + _prng.randf_range(-8, 8)), _prng.randf_range(1.2, 1.6))
			fires += 1
	var junk_i := 0
	for n in objects.get_children():
		if String(n.name).begins_with("BO_Junk"):
			junk_i += 1
			if junk_i % 9 == 4:
				_fire(objects, lvl, fire_scene, (n as Node2D).position + Vector2(_prng.randf_range(-10, 10), 6.0), _prng.randf_range(1.0, 1.3))
				fires += 1
	counts["fires"] = fires
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	lvl.free()
	report.append("props: убрано старых %d; поставлено %s; сцена (%s). Дальше — bake_navmesh.gd" % [removed, counts, error_string(err)])


## Всё, во что нельзя ставить: коллизия карты, стены блокаута, упоры
## спрайтов (фонари, пропсы фермы и т. п.), хлам баррикад
func _collect_blockers(lvl: Node) -> void:
	_blockers.clear()
	for path in ["Collision", "Blockout/Walls"]:
		var body := lvl.get_node_or_null(path)
		if body == null:
			continue
		if "shapes" in body:
			var shapes: Array = body.get("shapes")
			var xfs: Array = body.get("shape_transforms")
			for i in shapes.size():
				var s := shapes[i] as RectangleShape2D
				if s:
					_blockers.append(Rect2((xfs[i] as Transform2D).origin - s.size * 0.5, s.size))
		for c in body.get_children():
			if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
				var sz: Vector2 = ((c as CollisionShape2D).shape as RectangleShape2D).size
				_blockers.append(Rect2((c as Node2D).position - sz * 0.5, sz))
	for s in lvl.get_node("Objects").get_children():
		if not (s is Node2D):
			continue
		if s.has_meta("blockout") and s is Sprite2D:
			_blockers.append(Rect2((s as Node2D).position - Vector2(30, 24), Vector2(60, 30)))
		var b := s.get_node_or_null("Body")
		if b == null:
			continue
		for c in b.get_children():
			if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
				var sc: Vector2 = (s as Node2D).scale
				var sz: Vector2 = ((c as CollisionShape2D).shape as RectangleShape2D).size * sc
				var o: Vector2 = (s as Node2D).position + (c as Node2D).position * sc
				_blockers.append(Rect2(o - sz * 0.5, sz))


func _rect_of(sheet: String, key: String) -> Rect2:
	var meta: Dictionary = _sheets[sheet][1]
	var r: Variant = meta[key]
	if r is Dictionary:
		r = (r as Dictionary).get("rect", [])
	var a: Array = r
	return Rect2(a[0], a[1], a[2], a[3])


func _world_w(sheet: String, key: String) -> float:
	return _rect_of(sheet, key).size.x * 0.5


## Поставить предмет основанием в at. on_street — можно на улице (следы боя,
## рынок на площади); иначе только вне улиц
func _place(objects: Node, lvl: Node, sheet: String, key: String, at: Vector2, flip: bool, on_street: bool, force := false) -> bool:
	var meta: Dictionary = _sheets[sheet][1]
	if not meta.has(key):
		return false
	var r := _rect_of(sheet, key)
	var body: Vector2 = BODY.get(key, Vector2.ZERO)
	var fw := maxf(body.x, r.size.x * 0.5 * 0.6)
	var fh := maxf(body.y, 10.0)
	var fp := Rect2(at.x - fw * 0.5, at.y - fh, fw, fh)
	# В пределах города (верх/низ), не в арене
	# force — без проверок (знамя, прибитое к стене)
	if not force:
		if not Rect2(-2900, 40, 4850, 2540).has_point(at) or Rect2(760, 860, 670, 540).has_point(at):
			return false
		for c in _keep_circles:
			if _rect_dist(fp, c[0]) < c[1]:
				return false
		for bl in _blockers:
			if fp.grow(4.0).intersects(bl):
				return false
	if not on_street and not force:
		for st in STREETS:
			var pts: Array = st[0]
			for i in range(1, pts.size()):
				if _seg_dist(at, pts[i - 1], pts[i]) < float(st[1]) * 0.5 + 4.0:
					return false
		for k in KEEP_STONE:
			var kr: Rect2 = k
			if kr.intersects(fp) and kr.position.x < 1300.0:
				return false
	var s := Sprite2D.new()
	s.name = "TownProp_%s_%d" % [key.get_slice("@", 0), objects.get_child_count()]
	s.texture = _sheets[sheet][0]
	s.region_enabled = true
	s.region_rect = r
	s.centered = false
	s.scale = Vector2(0.5, 0.5)
	s.offset = Vector2(-r.size.x * 0.5, -r.size.y + 4.0)
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = at
	s.set_meta(PROP_TAG, key)
	if sheet == "hd":
		s.set_meta("hd_prop", key)
	objects.add_child(s)
	s.owner = lvl
	if body != Vector2.ZERO:
		var b := StaticBody2D.new()
		b.name = "Body"
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = body * 2.0
		cs.shape = sh
		cs.position = Vector2(0, -body.y)
		s.add_child(b)
		b.owner = lvl
		b.add_child(cs)
		cs.owner = lvl
	_blockers.append(fp)
	return true


# ───────────────────────── fallen (павшие) ─────────────────────────
## Павшие — персонажи, значит пиксельные, как герои и враги. Тела — последние
## кадры анимаций смерти (Die.png: 15 кадров × 8 направлений по 128 px) с
## перекраской одежды: горожане из лучника, мага и шаманки (их лица и наряды
## не узнаются), стража ордена Бальдра — рыцарь Knight_Character в белых латах.
## Не берутся: Хальвард (двойник героя) и тёмный рыцарь (фиолетовое свечение).
##   fallen_bake — textures/town_fallen.png (+ .json), потом --import;
##   fallen      — тела на улицах (мета town_fallen; повторять можно). Лужи
##                 крови под ними рисует в игре scripts/fallen_blood.gd (узел
##                 FallenBlood) теми же текстурами, что кровь на кладбище.
const FALLEN_TEX := TEX + "town_fallen.png"
const FALLEN_META := TEX + "town_fallen.json"
const FALLEN_TAG := "town_fallen"
## [лист, вид, сдвиг тона одежды (доля круга), насыщенность ×, яркость ×]
const FALLEN_SRC := [
	["res://Character/Archer/Die.png", "folk", 0.0, 0.55, 0.9],
	["res://Character/Archer/Die.png", "folk", 0.5, 0.35, 0.8],
	["res://Character/Mage/Die.png", "folk", -0.52, 0.5, 0.95],
	["res://Character/Mage/Die.png", "folk", -0.6, 0.25, 1.05],
	["res://Character/Shaman_20261110_201203/Die.png", "folk", 0.0, 0.8, 0.72],
	["res://Character/CharacterAnimationAssets/Knight_Character/DIE/Die.png", "guard", 0.0, 1.0, 1.0],
]
const FALLEN_SCALE := 0.78
## Сколько тел и где: [точки улицы, ширина] — те же STREETS; плюс стража у
## храма, площади и ворот
const FALLEN_STREET := 50
const FALLEN_GUARDS := [Vector2(-1960, 1960), Vector2(-1830, 1930), Vector2(-300, 1040),
	Vector2(-240, 1090), Vector2(640, 1250), Vector2(860, 1330), Vector2(1250, 1320),
	Vector2(1100, 2470), Vector2(1220, 2420)]


func _step_fallen_bake() -> void:
	var frames := []
	for src in FALLEN_SRC:
		var img := Image.load_from_file(ProjectSettings.globalize_path(src[0]))
		img.convert(Image.FORMAT_RGBA8)
		var cols := img.get_width() / 128
		var rows := img.get_height() / 128
		for r in rows:
			var f := img.get_region(Rect2i((cols - 1) * 128, r * 128, 128, 128))
			if src[1] == "folk":
				_recolor(f, src[2], src[3], src[4])
			var bb := f.get_used_rect()
			if bb.size.x < 4:
				continue
			frames.append({"kind": src[1], "img": f.get_region(bb)})
	# Упаковка рядами
	var x := 0
	var y := 0
	var shelf := 0
	var meta := []
	var w := 1024
	for fr in frames:
		var im: Image = fr.img
		if x + im.get_width() > w:
			x = 0
			y += shelf + 2
			shelf = 0
		meta.append({"kind": fr.kind, "rect": [x, y, im.get_width(), im.get_height()]})
		x += im.get_width() + 2
		shelf = maxi(shelf, im.get_height())
	var h := 1
	while h < y + shelf:
		h *= 2
	var atlas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var r: Array = meta[i].rect
		atlas.blit_rect(frames[i].img, Rect2i(0, 0, r[2], r[3]), Vector2i(r[0], r[1]))
	var err := atlas.save_png(ProjectSettings.globalize_path(FALLEN_TEX))
	AU.write_import(FALLEN_TEX, false)
	var f2 := FileAccess.open(FALLEN_META, FileAccess.WRITE)
	f2.store_string(JSON.stringify(meta, "\t"))
	f2.close()
	report.append("fallen_bake: %d тел, %dx%d (%s); дальше --import" % [frames.size(), w, h, error_string(err)])


## Перекраска одежды: тон сдвигается, насыщенность и яркость — по множителям;
## кожа (тёплый средний тон) и почти серые пиксели не трогаются
func _recolor(img: Image, hue: float, sat_k: float, val_k: float) -> void:
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			if c.a < 0.05:
				continue
			var skin := c.h > 0.02 and c.h < 0.11 and c.s > 0.2 and c.s < 0.62 and c.v > 0.5
			if skin or c.s < 0.12:
				c = Color.from_hsv(c.h, c.s, c.v * val_k, c.a)
			else:
				c = Color.from_hsv(fposmod(c.h + hue, 1.0), clampf(c.s * sat_k, 0.0, 1.0), clampf(c.v * val_k, 0.0, 1.0), c.a)
			img.set_pixel(xx, yy, c)


func _step_fallen() -> void:
	var tex := load(FALLEN_TEX) as Texture2D
	if tex == null:
		report.append("ОШИБКА: нет %s — fallen_bake и --import" % FALLEN_TEX)
		return
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(FALLEN_META))
	var folk := []
	var guards := []
	for m in meta:
		(guards if m.kind == "guard" else folk).append(m.rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	var objects := lvl.get_node("Objects")
	for n in objects.get_children():
		if n.has_meta(FALLEN_TAG):
			objects.remove_child(n)
			n.free()
	var avoid: Array = []
	for b in objects.get_children():
		var bn := String(b.name)
		if bn.begins_with("Bonfire") or bn == "PlayerSpawn":
			avoid.append((b as Node2D).position)
	var placed: Array[Vector2] = []
	var n_f := 0
	var tries := 0
	# Горожане — вдоль улиц
	while n_f < FALLEN_STREET and tries < 2000:
		tries += 1
		var st: Array = STREETS[rng.randi() % STREETS.size()]
		var pts: Array = st[0]
		var i := rng.randi_range(1, pts.size() - 1)
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var p := a.lerp(b, rng.randf()) + (b - a).normalized().orthogonal() * rng.randf_range(-st[1] * 0.42, st[1] * 0.42)
		if _fallen_ok(p, placed, avoid):
			_add_body(objects, lvl, tex, folk[rng.randi() % folk.size()], p, rng.randf() < 0.5)
			placed.append(p)
			n_f += 1
	# Стража Бальдра — у ворот, площади, храма
	var n_g := 0
	for p in FALLEN_GUARDS:
		if _fallen_ok(p, placed, avoid):
			_add_body(objects, lvl, tex, guards[rng.randi() % guards.size()], p, rng.randf() < 0.5)
			placed.append(p)
			n_g += 1
	# Узел луж крови (рантайм) — перед Objects: над землёй, под всем остальным
	var fb := lvl.get_node_or_null("FallenBlood")
	if fb == null:
		fb = Node2D.new()
		fb.name = "FallenBlood"
		fb.set_script(load("res://reference_map_level/scripts/fallen_blood.gd"))
		lvl.add_child(fb)
		fb.owner = lvl
	lvl.move_child(fb, objects.get_index())
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	lvl.free()
	report.append("fallen: горожан %d, стражи %d; сцена (%s)" % [n_f, n_g, error_string(err)])


func _fallen_ok(p: Vector2, placed: Array[Vector2], avoid: Array) -> bool:
	if not Rect2(-2900, 60, 4800, 2500).has_point(p) or Rect2(760, 860, 670, 420).has_point(p):
		return false
	for q in placed:
		if q.distance_to(p) < 150.0:
			return false
	for q in avoid:
		if (q as Vector2).distance_to(p) < 110.0:
			return false
	return true


func _add_body(objects: Node, lvl: Node, tex: Texture2D, r: Array, p: Vector2, flip: bool) -> void:
	var s := Sprite2D.new()
	s.name = "Fallen%d" % objects.get_child_count()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.centered = true
	s.scale = Vector2.ONE * FALLEN_SCALE
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Узел — у верхнего края тела: лежащий сортируется под всеми, кто рядом
	s.offset = Vector2(0, r[3] * 0.5 - 4.0)
	s.position = p - Vector2(0, r[3] * 0.5 * FALLEN_SCALE)
	s.set_meta(FALLEN_TAG, true)
	s.set_meta("blood_at", p)
	objects.add_child(s)
	s.owner = lvl


# ───────────────────────── prune (невидимые упоры в городе) ─────────────────
## Общая коллизия карты (Collision) хранит упоры исходной карты: стволы
## вырубленных деревьев, убранные пропсы и дома. Аудит по пикселям
## (collision_audit.gd) их не видит, если сверху нарисован большой дом или
## ворота. Здесь в черте города упор (≤ PRUNE_MAX px) остаётся, только если
## это подножие дома городка или рядом основание того, что сейчас стоит:
## спрайт или тайл Objects (с y_sort_origin). Остальное — убирается.
## Повторять можно. После — bake_navmesh.gd.
const PRUNE_AREA := Rect2(-2290, 40, 4250, 2560)
const PRUNE_MAX := 200.0
const PRUNE_NEAR := 36.0
const PRUNE_NOT_OWNERS := ["barrel", "barrels2", "crate", "crates_stack", "port_crates_tarp"]
## Зоны у ворот-башен: тайлы-пропсы здесь прячутся за картинкой ворот
const PRUNE_ERASE := [Rect2(-2090, 1690, 360, 290), Rect2(970, 2410, 360, 290)]


func _step_prune() -> void:
	_load_meta()
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	var objects := lvl.get_node("Objects")
	var bases: Array[Vector2] = []
	for c in objects.get_children():
		if c is TileMapLayer:
			var l := c as TileMapLayer
			var ts := l.tile_set
			for cell in l.get_used_cells():
				var src := ts.get_source(l.get_cell_source_id(cell)) as TileSetAtlasSource
				var p := l.transform * l.map_to_local(cell)
				if src:
					var td := src.get_tile_data(l.get_cell_atlas_coords(cell), l.get_cell_alternative_tile(cell) & 0xFFF)
					if td:
						p.y += td.y_sort_origin * absf(l.scale.y)
				var kind := str(src.get_meta("hd_prop", "")).get_slice("@", 0) if src else ""
				# Хлам, спрятанный за воротами-башнями, — стереть
				if kind != "" and not src.has_meta("forest_variant") and _in_any(p, PRUNE_ERASE):
					l.erase_cell(cell)
					continue
				# Бочки и ящики в игре разбиваемые, без упора — не хозяева
				if kind in PRUNE_NOT_OWNERS:
					continue
				bases.append(p)
		elif c is Node2D and not c.has_meta(META_TAG) and not c.has_meta("town_fallen"):
			bases.append((c as Node2D).position)
	var feet: Array[Rect2] = []
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	for h in layout.houses:
		feet.append(_foot(h.name, Vector2(h.x, h.y)))
	var col := lvl.get_node("Collision")
	var shapes: Array = col.get("shapes")
	var xfs: Array = col.get("shape_transforms")
	var ns: Array[Shape2D] = []
	var nx: Array[Transform2D] = []
	var removed := []
	for i in shapes.size():
		var s := shapes[i] as RectangleShape2D
		var t: Transform2D = xfs[i]
		var keep := true
		if s and PRUNE_AREA.has_point(t.origin) and maxf(s.size.x, s.size.y) <= PRUNE_MAX:
			keep = false
			var r := Rect2(t.origin - s.size * 0.5, s.size)
			for f in feet:
				if f.grow(2.0).encloses(r) or (f.get_center().distance_to(r.get_center()) < 4.0):
					keep = true
					break
			if not keep:
				for b in bases:
					if _rect_dist(r, b) < PRUNE_NEAR:
						keep = true
						break
		if keep:
			ns.append(shapes[i])
			nx.append(t)
		else:
			removed.append(Vector2i(t.origin))
	col.set("shapes", ns)
	col.set("shape_transforms", nx)
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	lvl.free()
	report.append("prune: убрано упоров %d: %s; сцена (%s)" % [removed.size(), removed, error_string(err)])


const CAMPFIRE := "res://Levels/props/campfire.tscn"

## Огонь (Levels/props/campfire.tscn: пламя, искры, свет, треск) без упора
func _fire(objects: Node, lvl: Node, scene: PackedScene, at: Vector2, sc: float) -> void:
	var f := scene.instantiate() as Node2D
	f.name = "TownFire%d" % objects.get_child_count()
	f.position = at
	f.scale = Vector2.ONE * sc
	f.set_meta(PROP_TAG, "fire")
	objects.add_child(f)
	f.owner = lvl


# ───────────────────────── decals (декали улиц) ─────────────────────────
## Лист textures/src/hd/roads_v2/street_decals.png (8 штук сеткой 4×2:
## лужа, сажа, выбитые камни, черепица, солома, след огненной стрелы, камни,
## трещина) → textures/street_decals.png; на улицах ~DECAL_SHARE длины —
## спрайты в узле StreetDecals прямо перед Objects (земля: под кровью,
## павшими и героями). Не у ворот и костров. Повторять можно.
const DECAL_SRC := "res://reference_map_level/textures/src/hd/roads_v2/street_decals.png"
const DECAL_TEX := TEX + "street_decals.png"
const DECAL_META := TEX + "street_decals.json"
const DECAL_GRID := Vector2i(4, 2)
const DECAL_SHARE := 0.1
const DECAL_W := Vector2(56, 84)
const DECAL_KEEP := [Vector2(-1910, 1880), Vector2(1150, 2600), Vector2(-950, 625), Vector2(150, 1540)]


func _step_decals_bake() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DECAL_SRC))
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var cw := used.size.x / DECAL_GRID.x
	var ch := used.size.y / DECAL_GRID.y
	var parts := []
	for gy in DECAL_GRID.y:
		for gx in DECAL_GRID.x:
			var cell := img.get_region(Rect2i(used.position.x + gx * cw, used.position.y + gy * ch, cw, ch))
			var r := cell.get_used_rect()
			if r.size.x < 8:
				continue
			var p := cell.get_region(r)
			# 2 текселя на px мира при ширине ~DECAL_W.y
			var k := DECAL_W.y * 2.0 / p.get_width()
			p.resize(int(p.get_width() * k), int(p.get_height() * k), Image.INTERPOLATE_LANCZOS)
			parts.append(p)
	var x := 0
	var hmax := 0
	for p in parts:
		x += p.get_width() + 4
		hmax = maxi(hmax, p.get_height())
	var atlas := Image.create(x, hmax, false, Image.FORMAT_RGBA8)
	var meta := []
	x = 0
	for p in parts:
		atlas.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(x, 0))
		meta.append([x, 0, p.get_width(), p.get_height()])
		x += p.get_width() + 4
	var err := atlas.save_png(ProjectSettings.globalize_path(DECAL_TEX))
	AU.write_import(DECAL_TEX, true)
	var f := FileAccess.open(DECAL_META, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	report.append("decals_bake: %d декалей (%s); дальше --import" % [parts.size(), error_string(err)])


func _step_decals() -> void:
	var tex := load(DECAL_TEX) as Texture2D
	if tex == null:
		report.append("ОШИБКА: нет %s — decals_bake и --import" % DECAL_TEX)
		return
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(DECAL_META))
	var lvl := (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
	var objects := lvl.get_node("Objects")
	var holder := lvl.get_node_or_null("StreetDecals") as Node2D
	if holder:
		lvl.remove_child(holder)
		holder.free()
	holder = Node2D.new()
	holder.name = "StreetDecals"
	lvl.add_child(holder)
	holder.owner = lvl
	lvl.move_child(holder, objects.get_index())
	var keep: Array = DECAL_KEEP.duplicate()
	for b in objects.get_children():
		if String(b.name).begins_with("Bonfire") or b.name == "PlayerSpawn":
			keep.append((b as Node2D).position)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := 0
	for st in STREETS:
		var pts: Array = st[0]
		var half: float = float(st[1]) * 0.5
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var seg := a.distance_to(b)
			var count := int(seg * DECAL_SHARE / ((DECAL_W.x + DECAL_W.y) * 0.5))
			for j in count:
				var p := a.lerp(b, rng.randf()) + (b - a).normalized().orthogonal() * rng.randf_range(-half * 0.6, half * 0.6)
				var ok := true
				for q in keep:
					if (q as Vector2).distance_to(p) < 130.0:
						ok = false
				if not ok:
					continue
				var r: Array = meta[rng.randi() % meta.size()]
				var s := Sprite2D.new()
				s.name = "Decal%d" % n
				s.texture = tex
				s.region_enabled = true
				s.region_rect = Rect2(r[0], r[1], r[2], r[3])
				var wv := rng.randf_range(DECAL_W.x, DECAL_W.y)
				s.scale = Vector2.ONE * (wv / (float(r[2]) / 2.0)) * 0.5
				s.rotation = rng.randf() * TAU
				s.position = p
				s.modulate = Color(0.85, 0.85, 0.85, 0.92)
				holder.add_child(s)
				s.owner = lvl
				n += 1
	var ps := PackedScene.new()
	var err := ps.pack(lvl)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	lvl.free()
	report.append("decals: %d на улицах; сцена (%s)" % [n, error_string(err)])
