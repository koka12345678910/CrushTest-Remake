extends SceneTree
## Чёткая брусчатка на reference_map вместо старой мостовой атласа reskin.
##
## Исходники — картинки на весь кадр в reference_map_level/textures/src/hd/:
##   road_cobble.webp (обычная), road_cobble_moss.webp (замшелая).
## Старая мостовая — клетки слоя Stone из рядов 40..87 атласа reskin_tiles
## (там, где в клетке есть серый камень).
## Шейдер земли (terrain_ground.gdshader) рисует вместо неё новую брусчатку
## в мировых координатах, а у края дороги камни по одному тонут в земле.
##
## Шаги (по умолчанию оба по порядку):
##   textures — плитки брусчатки: выравнивание света, бесшовность, резкость,
##              в альфе «высота» (камень выше щели) → textures/terrain/
##              cobble_layers.png (2D-массив из 2 срезов, нужен импорт);
##   mask     — маска мира textures/terrain/cobble_map.res (4 мировых px на
##              тексель): R — мягкая «тут дорога», G — клетка старой мостовой,
##              которую шейдер перерисовывает целиком; вешает всё в материал.
##
## Запуск (после textures — импорт, иначе mask не найдёт текстуру):
##   godot --headless --path . -s res://tools/cobble_road.gd -- textures
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/cobble_road.gd -- mask

const BT := preload("res://tools/build_terrain.gd")
const MAP := "res://reference_map_level/reference_map.tscn"
const MATERIAL := "res://reference_map_level/textures/terrain/ground_material.tres"
const HD_DIR := "res://reference_map_level/textures/src/hd/"
const SOURCES := ["road_cobble", "road_cobble_moss"]
const LAYERS_PNG := "res://reference_map_level/textures/terrain/cobble_layers.png"
const MASK_TEX := "res://reference_map_level/textures/terrain/cobble_map.res"
const PATHS_TEX := "res://reference_map_level/textures/terrain/paths.res"
const RESKIN := "res://reference_map_level/textures/reskin_tiles.png"
## Маска атласа reskin (вдвое меньше атласа): 1 — листва/земля в рисунке
const LEAF_MASK := "res://reference_map_level/textures/terrain/mask_reskin.res"

## Сторона плитки в текселях (половина исходника 1254)
const TILE := 627
## Ряды атласа reskin со старой мостовой (шейдер проверяет те же)
const ROW_FROM := 40
const ROW_TO := 87
## Мир карты (как в build_terrain.gd / forest_paths.gd)
const WORLD := Rect2i(-3520, -704, 8640, 5120)
const PX := 4
## Размытие края дороги (текселей маски, два прохода коробкой)
const BLUR_R := 5
## Насколько край дороги виляет по шуму
const WOBBLE := 0.22

var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["textures", "mask"]
	if "textures" in steps:
		_step_textures()
	if "mask" in steps:
		await _step_mask()
	for r in report:
		print(r)
	quit()


# ───────────────────────── плитки ─────────────────────────

func _step_textures() -> void:
	var strip := Image.create(TILE * SOURCES.size(), TILE, false, Image.FORMAT_RGBA8)
	for i in SOURCES.size():
		var src := Image.load_from_file(ProjectSettings.globalize_path(HD_DIR + SOURCES[i] + ".webp"))
		src.convert(Image.FORMAT_RGBA8)
		# Квадрат из середины (картинка и так на весь кадр)
		var side := mini(src.get_width(), src.get_height())
		var img := src.get_region(Rect2i((src.get_size() - Vector2i(side, side)) / 2, Vector2i(side, side)))
		# Исходники уже бесшовные: без сшивки и выравнивания света (они
		# мылят середину плитки), только ровно вдвое меньше и резкость
		img.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
		# Камень отдельно от щели читается лучше: локальный контраст крупным
		# радиусом, потом мелкая резкость
		img = _clarity(img, 0.45)
		img = BT._unsharp(img, 0.35)
		_put_height(img)
		strip.blit_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	var path := ProjectSettings.globalize_path(LAYERS_PNG)
	var err := strip.save_png(path)
	# Импорт как 2D-массив (2 среза по горизонтали)
	var imp := path + ".import"
	if not FileAccess.file_exists(imp):
		var f := FileAccess.open(imp, FileAccess.WRITE)
		f.store_string("[remap]\n\nimporter=\"2d_array_texture\"\ntype=\"CompressedTexture2DArray\"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nmipmaps/limit=-1\nslices/horizontal=%d\nslices/vertical=1\n" % SOURCES.size())
		f.close()
	report.append("textures: %d плитки %dpx → %s (%s)" % [SOURCES.size(), TILE, LAYERS_PNG, error_string(err)])


## Альфа = «высота»: сглаженная яркость, растянутая на 0..1. Камни выше
## щелей, середина камня выше его края — у края дороги камень уходит
## в землю целиком, а не рассыпается на пиксели.
func _put_height(img: Image) -> void:
	var n := img.get_width()
	var lum := PackedFloat32Array()
	lum.resize(n * n)
	for y in n:
		for x in n:
			lum[y * n + x] = BT._lum(img.get_pixel(x, y))
	var near := _blur_wrap(_blur_wrap(lum, n, 3), n, 3)
	var wide := _blur_wrap(_blur_wrap(lum, n, 14), n, 14)
	var h := PackedFloat32Array()
	h.resize(n * n)
	for i in n * n:
		# Яркость относительно округи: тёмный камень всё равно выше своих щелей
		h[i] = near[i] - wide[i] * 0.85
	var sorted := h.duplicate()
	sorted.sort()
	var lo := sorted[int(n * n * 0.03)]
	var hi := sorted[int(n * n * 0.97)]
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			c.a = clampf((h[y * n + x] - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
			img.set_pixel(x, y, c)


## Локальный контраст: нерезкая маска радиусом ~ полкамня (с переносом
## через край). Альфа не меняется.
func _clarity(img: Image, amount: float) -> Image:
	var n := img.get_width()
	var a := img.get_data()
	for ch in 3:
		var src := PackedFloat32Array()
		src.resize(n * n)
		for i in n * n:
			src[i] = a[i * 4 + ch]
		var bl := _blur_wrap(_blur_wrap(src, n, 12), n, 12)
		for i in n * n:
			a[i * 4 + ch] = clampi(int(src[i] + (src[i] - bl[i]) * amount), 0, 255)
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, a)


## Коробочное размытие с переносом через край (плитка бесшовная)
func _blur_wrap(src: PackedFloat32Array, n: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	var k := 1.0 / float(2 * r + 1)
	for y in n:
		var s := 0.0
		for dx in range(-r, r + 1):
			s += src[y * n + posmod(dx, n)]
		for x in n:
			tmp[y * n + x] = s * k
			s += src[y * n + posmod(x + r + 1, n)] - src[y * n + posmod(x - r, n)]
	var out := PackedFloat32Array()
	out.resize(n * n)
	for x in n:
		var s := 0.0
		for dy in range(-r, r + 1):
			s += tmp[posmod(dy, n) * n + x]
		for y in n:
			out[y * n + x] = s * k
			s += tmp[posmod(y + r + 1, n) * n + x] - tmp[posmod(y - r, n) * n + x]
	return out


# ───────────────────────── маска ─────────────────────────

func _step_mask() -> void:
	var level := (load(MAP) as PackedScene).instantiate()
	var spawn := level.find_child("PlayerSpawn", true, false)
	if spawn:
		spawn.free()
	root.add_child(level)
	await process_frame
	var reskin := Image.load_from_file(ProjectSettings.globalize_path(RESKIN))
	reskin.convert(Image.FORMAT_RGBA8)
	var leaf_mask := (load(LEAF_MASK) as Texture2D).get_image()
	leaf_mask.decompress()
	leaf_mask.convert(Image.FORMAT_L8)
	var w := WORLD.size.x / PX
	var h := WORLD.size.y / PX
	var road := PackedFloat32Array()
	road.resize(w * h)
	var cells := PackedByteArray()
	cells.resize(w * h)
	var stone := level.get_node("Stone") as TileMapLayer
	var n_void := 0
	# repaint — клетки, которые шейдер рисует заново целиком (брусчатка или
	# земля); stony — где в старом рисунке был камень (там будет дорога)
	var repaint := {}
	var stony := {}
	var partial := {}
	for c in stone.get_used_cells():
		var ac := stone.get_cell_atlas_coords(c)
		var src := stone.tile_set.get_source(stone.get_cell_source_id(c)) as TileSetAtlasSource
		if src == null or src.texture == null or src.texture.get_width() != 4096:
			continue
		if ac.y < ROW_FROM or ac.y > ROW_TO:
			continue
		# Кромка провала (много чёрного) остаётся старым рисунком
		if _dark_share(reskin, ac) > 0.3:
			n_void += 1
			continue
		repaint[c] = true
		# Доля «листвы/земли» в рисунке клетки — по той же маске, по которой
		# шейдер раньше менял её на землю (build_terrain.gd, шаг masks).
		# Камень с мхом и пятнами — дорога; клетка-кромка (в основном
		# листва) — частично: после размытия там редкие камни в земле
		var leaf := _leaf_share(leaf_mask, ac)
		if leaf < 0.6:
			stony[c] = true
		else:
			partial[c] = clampf((1.0 - leaf) * 1.5, 0.0, 0.6)
	# Клетки «листвы» посреди мостовой (в старом рисунке там была земля
	# пятнами) — тоже дорога, иначе в брусчатке квадратные дыры
	# То же для дыр, где клетки камня не было вовсе (там земля слоя Ground)
	for it in 2:
		var cand := {}
		for c in stony:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q: Vector2i = c + Vector2i(dx, dy)
					if not stony.has(q):
						cand[q] = true
		var add: Array[Vector2i] = []
		for c in cand:
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and stony.has(c + Vector2i(dx, dy)):
						n += 1
			if n >= 5:
				add.append(c)
		for c in add:
			stony[c] = true
	var all := repaint.duplicate()
	all.merge(stony)
	for c in all:
		var p := stone.to_global(stone.map_to_local(c)) - Vector2(8, 8)
		var x0 := int((p.x - WORLD.position.x) / PX)
		var y0 := int((p.y - WORLD.position.y) / PX)
		var v: float = 1.0 if stony.has(c) else partial.get(c, 0.0)
		var g := 255 if repaint.has(c) else 0
		for ty in range(maxi(y0, 0), mini(y0 + 16 / PX, h)):
			for tx in range(maxi(x0, 0), mini(x0 + 16 / PX, w)):
				road[ty * w + tx] = v
				cells[ty * w + tx] = g
	var n_cells := stony.size()
	level.queue_free()
	# Узкие старые каменные дорожки в лесу — земляные тропы, как раньше
	# (forest_paths.gd, B). Широкая дорога под лесной тропой (R) остаётся
	# брусчаткой: грязная полоса посреди мостовой смотрелась бы чужой
	var pimg := (load(PATHS_TEX) as Texture2D).get_image()
	pimg.decompress()
	pimg.convert(Image.FORMAT_RGBA8)
	var cut := 0
	if pimg.get_width() == w and pimg.get_height() == h:
		for ty in h:
			for tx in w:
				var pc := pimg.get_pixel(tx, ty)
				if road[ty * w + tx] > 0.0 and pc.b > 0.5:
					road[ty * w + tx] = 0.0
					cut += 1
	else:
		report.append("mask: paths.res другого размера, тропы не вырезаны")
	road = _blur(_blur(road, w, h, BLUR_R), w, h, BLUR_R)
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 1.0 / 70.0
	noise.fractal_octaves = 2
	var bytes := PackedByteArray()
	bytes.resize(w * h * 2)
	for ty in h:
		for tx in w:
			var i := ty * w + tx
			var v := road[i]
			if v > 0.0 and v < 1.0:
				var wx := WORLD.position.x + (tx + 0.5) * PX
				var wy := WORLD.position.y + (ty + 0.5) * PX
				v = clampf(v + noise.get_noise_2d(wx, wy) * WOBBLE * 2.0 * (1.0 - absf(v * 2.0 - 1.0)) , 0.0, 1.0)
			bytes[i * 2] = int(v * 255.0)
			bytes[i * 2 + 1] = cells[i]
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RG8, bytes)
	var err := ResourceSaver.save(ImageTexture.create_from_image(img), MASK_TEX, ResourceSaver.FLAG_COMPRESS)
	var mat := load(MATERIAL) as ShaderMaterial
	mat.set_shader_parameter("cobble_map", ResourceLoader.load(MASK_TEX, "", ResourceLoader.CACHE_MODE_REPLACE))
	mat.set_shader_parameter("cobble_rect", Vector4(WORLD.position.x, WORLD.position.y, WORLD.size.x, WORLD.size.y))
	mat.set_shader_parameter("cobble_layers", load(LAYERS_PNG))
	var merr := ResourceSaver.save(mat, MATERIAL)
	var prev := OS.get_environment("TERRAIN_PREVIEW")
	if prev != "":
		img.save_png(prev + "/cobble_map.png")
	report.append("mask: %d клеток мостовой (%d у провала не тронуты), %d текселей ушло в тропы, %dx%d (%s, материал %s)" % [n_cells, n_void, cut, w, h, error_string(err), error_string(merr)])


func _blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var k := 1.0 / float(2 * r + 1)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += src[y * w + clampi(x + d, 0, w - 1)]
			tmp[y * w + x] = s * k
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += tmp[clampi(y + d, 0, h - 1) * w + x]
			out[y * w + x] = s * k
	return out


## Доля листвы/земли в клетке атласа reskin по его маске (16x16 текселей)
static func _leaf_share(mask: Image, ac: Vector2i) -> float:
	var s := 0.0
	for y in 16:
		for x in 16:
			s += mask.get_pixel(ac.x * 16 + x, ac.y * 16 + y).r
	return s / 256.0


## Доля почти чёрных пикселей (провал) в клетке атласа reskin
static func _dark_share(img: Image, ac: Vector2i) -> float:
	var n := 0
	for y in range(0, 32, 2):
		for x in range(0, 32, 2):
			var c := img.get_pixel(ac.x * 32 + x, ac.y * 32 + y)
			if c.a > 0.5 and c.r * 0.3 + c.g * 0.59 + c.b * 0.11 < 0.035:
				n += 1
	return n / 256.0
