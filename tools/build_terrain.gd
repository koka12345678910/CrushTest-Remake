extends SceneTree
## Новая земля и обрывы reference_map из присланных наборов.
##
## Исходники лежат в reference_map_level/textures/source/ (там .gdignore):
##   ground_set.png — плитки земли и травы (3x3 квадрата слева сверху);
##   rock_set.png   — скальные куски с травой, стены, лестницы.
## Всё готовое пишется в reference_map_level/textures/terrain/ как .res
## (импорт не нужен, как у relief_shade.res).
##
## Шаги (по умолчанию все по порядку):
##   tiles  — 9 квадратов земли: выравнивание света, бесшовность, резкость,
##            один Texture2DArray (ground_layers.res);
##   masks  — маски атласов земли: где в старом рисунке «листва/грязь»,
##            которую шейдер заменяет новой землёй (камень, ямы, кровь,
##            вода остаются как были);
##   wear   — карта вытоптанности мира: у дорог, домов и лагеря меньше травы;
##   cliffs — стены плато заново из скальных кусков набора + лестницы;
##   apply  — вешает материал на слои земли, прячет старый слой Cliffs,
##            добавляет CliffFace и лестницы. Сцена правится на месте.
##
## Запуск:
##   godot --headless --path . -s res://tools/build_terrain.gd -- [шаги...]
## После правки коллизии навмеш пересобирать не нужно: коллизия не меняется.

const SRC := "res://reference_map_level/textures/source/"
const OUT := "res://reference_map_level/textures/terrain/"
const SCENE := "res://reference_map_level/reference_map.tscn"
const SHADER := "res://reference_map_level/shaders/terrain_ground.gdshader"

## Мир карты (как camera_limits): x, y, w, h
const WORLD := Rect2i(-3520, -704, 8640, 5120)

var lvl: Node
var report: Array[String] = []


func _initialize() -> void:
	var steps := Array(OS.get_cmdline_user_args())
	if steps.is_empty():
		steps = ["tiles", "masks", "wear", "cliffs", "canyon", "apply"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var need_scene := false
	for s in steps:
		if s in ["wear", "cliffs", "canyon", "apply"]:
			need_scene = true
	if need_scene:
		lvl = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	for s in steps:
		var t := Time.get_ticks_msec()
		call("_step_" + s)
		report.append("  (%s: %.1f c)" % [s, (Time.get_ticks_msec() - t) / 1000.0])
	for r in report:
		print(r)
	quit()


func _src_image(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + name))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save_tex(img: Image, name: String) -> Error:
	var tex := ImageTexture.create_from_image(img)
	return ResourceSaver.save(tex, OUT + name, ResourceSaver.FLAG_COMPRESS)


static func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ───────────────────────── плитки земли ─────────────────────────
# Квадраты на листе 1536x1024: центры и порядок слоёв в массиве.
# Слои: 0 грязь, 1 грязь с галькой, 2 грязь с камнями, 3 крупные камни,
#       4 редкая трава, 5 трава пятнами, 6 трава, 7 и 8 густая трава.
const TILE := 256
const CROP := 256
const SQ_CENTERS := [
	Vector2i(152, 160), Vector2i(419, 160), Vector2i(686, 160),
	Vector2i(152, 430), Vector2i(419, 430), Vector2i(686, 430),
	Vector2i(152, 700), Vector2i(419, 700), Vector2i(686, 700)]
const LAYER_FROM_SQ := [0, 1, 6, 2, 3, 7, 4, 5, 8]


func _step_tiles() -> void:
	var sheet := _src_image("ground_set.png")
	var images: Array[Image] = []
	for li in LAYER_FROM_SQ.size():
		var c: Vector2i = SQ_CENTERS[LAYER_FROM_SQ[li]]
		var img := sheet.get_region(Rect2i(c - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP)))
		img = _flatten_light(img)
		img = _tileable(img, true)
		img = _tileable(img, false)
		img = _unsharp(img, 0.75)
		images.append(img)
	# Texture2DArray не сохраняется в .res с картинками, поэтому слои
	# пишутся полосой PNG и импортируются Godot как 2D-массив (9 срезов).
	# После шага нужен импорт: godot --headless --path . --import
	var strip := Image.create(TILE * images.size(), TILE, false, Image.FORMAT_RGBA8)
	for li in images.size():
		strip.blit_rect(images[li], Rect2i(0, 0, TILE, TILE), Vector2i(li * TILE, 0))
	var png := ProjectSettings.globalize_path(OUT + "ground_layers.png")
	var err := strip.save_png(png)
	var f := FileAccess.open(png + ".import", FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"2d_array_texture\"\ntype=\"CompressedTexture2DArray\"\n\n"
		+ "[params]\n\ncompress/mode=0\nmipmaps/generate=true\nmipmaps/limit=-1\n"
		+ "slices/horizontal=%d\nslices/vertical=1\n" % images.size())
	f.close()
	# Превью: каждый слой 2x2 повтором — видно, есть ли швы
	var prev_dir := OS.get_environment("TERRAIN_PREVIEW")
	if prev_dir != "":
		var sheet_out := Image.create(TILE * 2 * 3, TILE * 2 * 3, false, Image.FORMAT_RGBA8)
		for li in images.size():
			var im := images[li]
			for k in 4:
				sheet_out.blit_rect(im, Rect2i(0, 0, TILE, TILE),
					Vector2i((li % 3) * TILE * 2 + (k % 2) * TILE, (li / 3) * TILE * 2 + (k / 2) * TILE))
		sheet_out.save_png(prev_dir + "/tiles_preview.png")
	report.append("tiles: %d слоёв %dx%d (%s)" % [images.size(), TILE, TILE, error_string(err)])


## Убирает крупные перепады света внутри квадрата (виньетка, пятна):
## иначе при повторе плитка читается клеткой.
func _flatten_light(img: Image) -> Image:
	var n := img.get_width()
	var low := img.duplicate() as Image
	low.resize(6, 6, Image.INTERPOLATE_LANCZOS)
	low.resize(n, n, Image.INTERPOLATE_CUBIC)
	var mean := Color(0, 0, 0)
	for y in n:
		for x in n:
			mean += img.get_pixel(x, y)
	mean = mean / float(n * n)
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			var l := low.get_pixel(x, y)
			var k := 0.85
			out.set_pixel(x, y, Color(
				clampf(c.r + (mean.r - l.r) * k, 0.0, 1.0),
				clampf(c.g + (mean.g - l.g) * k, 0.0, 1.0),
				clampf(c.b + (mean.b - l.b) * k, 0.0, 1.0), 1.0))
	return out


## Бесшовность по одной оси: смесь с копией, сдвинутой на половину.
## У краёв берётся сдвинутая копия (её середина непрерывна через край),
## в середине — исходник (там шов сдвинутой копии). Переход идёт по
## «высоте» (яркости): травинки и камни перекрывают друг друга, а не
## просвечивают двоением.
func _tileable(img: Image, horizontal: bool) -> Image:
	var n := img.get_width()
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var half := n / 2
	for y in n:
		for x in n:
			var a := img.get_pixel(x, y)
			var b: Color
			var d: float
			if horizontal:
				b = img.get_pixel((x + half) % n, y)
				d = minf(x, n - 1 - x) / float(half)
			else:
				b = img.get_pixel(x, (y + half) % n)
				d = minf(y, n - 1 - y) / float(half)
			var base := _smooth(0.12, 0.8, d)
			var mid := 1.0 - absf(base * 2.0 - 1.0)
			var t := clampf(base + (_lum(a) - _lum(b)) * 3.0 * mid, 0.0, 1.0)
			# Почти резкий выбор: полупрозрачная смесь двух копий — это двоение
			# и мыло, а травинка поверх травинки читается чётко
			t = _smooth(0.38, 0.62, t)
			out.set_pixel(x, y, b.lerp(a, t))
	return out


## Нерезкая маска с малым радиусом (~1 px): возвращает мелкую резкость,
## не трогая крупный свет. Альфа не меняется.
static func _unsharp(img: Image, amount: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var blur := img.duplicate() as Image
	blur.resize(maxi(w / 2, 1), maxi(h / 2, 1), Image.INTERPOLATE_BILINEAR)
	blur.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var a := img.get_data()
	var b := blur.get_data()
	for i in range(0, a.size(), 4):
		for ch in 3:
			a[i + ch] = clampi(int(a[i + ch] + (a[i + ch] - b[i + ch]) * amount), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, a)


## Кусок листа вдвое крупнее (Lanczos) и с резкостью: стены и лестницы
## на экране увеличены ~в 1.8 раза, билинейное растяжение исходника мылит
static func _hi_res(img: Image, rect: Rect2i) -> Image:
	var r := img.get_region(rect)
	r.resize(rect.size.x * 2, rect.size.y * 2, Image.INTERPOLATE_LANCZOS)
	return _unsharp(r, 0.9)


# ───────────────────────── маски атласов ─────────────────────────
# Шейдер узнаёт атлас по размеру текстуры и берёт его маску.
# Маска вдвое меньше атласа (клетка 32 px → 16 текселей).
const ATLASES := {
	"medieval_ground.png": "mask_medieval.res",
	"reskin_tiles.png": "mask_reskin.res",
	"canyon.png": "mask_canyon.res",
}


func _step_masks() -> void:
	for atlas in ATLASES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(
			"res://reference_map_level/textures/" + atlas))
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width() / 2
		var h := img.get_height() / 2
		var src := img.get_data()
		var sw := img.get_width()
		var raw := PackedFloat32Array()
		raw.resize(w * h)
		var cnt := 0
		for y in h:
			for x in w:
				var r := 0.0
				var g := 0.0
				var b := 0.0
				var a := 0.0
				for k in 4:
					var i := ((y * 2 + k / 2) * sw + x * 2 + k % 2) * 4
					r += src[i]
					g += src[i + 1]
					b += src[i + 2]
					a += src[i + 3]
				var v := _ground_key(r / 1020.0, g / 1020.0, b / 1020.0) if a > 500.0 else 0.0
				raw[y * w + x] = v
		# Сглаживание 3x3 и контраст: края мягкие, но без серой каши
		var out := PackedByteArray()
		out.resize(w * h)
		for y in h:
			for x in w:
				var s := 0.0
				var n := 0
				for dy in range(-1, 2):
					var yy := y + dy
					if yy < 0 or yy >= h:
						continue
					for dx in range(-1, 2):
						var xx := x + dx
						if xx < 0 or xx >= w:
							continue
						s += raw[yy * w + xx]
						n += 1
				var v := _smooth(0.25, 0.75, s / n)
				if atlas == "medieval_ground.png" and y < 512:
					v = 1.0            # верхний квадрат 1024x1024 — сама «листва»
				out[y * w + x] = int(v * 255.0)
				if v > 0.5:
					cnt += 1
		var mimg := Image.create_from_data(w, h, false, Image.FORMAT_L8, out)
		var err := _save_tex(mimg, ATLASES[atlas])
		var prev_dir := OS.get_environment("TERRAIN_PREVIEW")
		if prev_dir != "":
			mimg.save_png(prev_dir + "/" + ATLASES[atlas].get_basename() + ".png")
		report.append("mask %s: %dx%d, земля %.0f%% (%s)" % [
			atlas, w, h, 100.0 * cnt / (w * h), error_string(err)])


## «Это старая земля?» по цвету тексела: тёплая бурая листва и грязь,
## тёмный зелёный мох. Серый камень, чёрные ямы, кровь, бирюзовая вода — нет.
static func _ground_key(r: float, g: float, b: float) -> float:
	var mx := maxf(r, maxf(g, b))
	var mn := minf(r, minf(g, b))
	var sat := mx - mn
	var lum := r * 0.3 + g * 0.59 + b * 0.11
	if lum < 0.03:
		return 0.0
	if r > g * 2.6 + 0.06:
		return 0.0                     # кровь
	var warm := _smooth(0.03, 0.08, r - b) * _smooth(0.02, 0.05, g - b * 0.9)
	var moss := _smooth(0.0, 0.035, g - b) * _smooth(-0.04, 0.0, g - r) * _smooth(0.9, 0.7, b / maxf(g, 0.001))
	var v := maxf(warm, moss)
	v *= _smooth(0.025, 0.06, sat)    # серое — камень
	v *= _smooth(0.62, 0.45, lum)     # яркое — доски, кость, металл
	return v


# ───────────────────────── вытоптанность ─────────────────────────
## Тексель — 8 мировых px. R — насколько земля вытоптана (0 — трава).
const WEAR_PX := 8


func _step_wear() -> void:
	var w := WORLD.size.x / WEAR_PX
	var h := WORLD.size.y / WEAR_PX
	var f := PackedFloat32Array()
	f.resize(w * h)
	# Мощёные дороги и площади, городские тайлы
	for ln in ["Stone", "Town"]:
		var l := lvl.get_node(ln) as TileMapLayer
		var cell := int(l.tile_set.tile_size.x * l.scale.x)
		for c in l.get_used_cells():
			_wear_rect(f, w, h, Rect2(Vector2(c * cell), Vector2(cell, cell)), 1.0)
	# Дома (вокруг них натоптано), лагерь целиком
	var houses := 0
	for n in lvl.get_node("Objects").get_children():
		if n is Sprite2D and String(n.name).begins_with("House"):
			var r := (n as Sprite2D).get_rect()
			var xf := (n as Sprite2D).global_transform
			var rr := Rect2(xf * r.position, (xf * r.end) - (xf * r.position)).abs()
			_wear_rect(f, w, h, rr.grow(10), 1.0)
			houses += 1
	var camp := lvl.get_node_or_null("Objects/RuinedCamp")
	if camp:
		var cg := camp.get_node_or_null("Ground") as TileMapLayer
		if cg:
			var cell := cg.tile_set.tile_size.x * cg.scale.x
			var ur := cg.get_used_rect()
			var p := (camp as Node2D).position + Vector2(ur.position) * cell
			_wear_rect(f, w, h, Rect2(p, Vector2(ur.size) * cell), 1.0)
	# Размытие: трава редеет к дороге плавно (~60 px)
	for i in 4:
		f = _box_blur(f, w, h, 3)
	# Шумы для шейдера запекаются сюда же (дешевле одной выборкой, чем
	# считать на каждый пиксель): G — крупные пятна травы, B — смена
	# вариантов земли, A — неровность света и каменистые места.
	var noises: Array[FastNoiseLite] = []
	for spec in [[560.0, 11], [210.0, 23], [360.0, 37]]:
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		nz.seed = spec[1]
		nz.frequency = 1.0 / spec[0]
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
		nz.fractal_octaves = 3
		noises.append(nz)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for y in h:
		for x in w:
			var i := y * w + x
			var wx := WORLD.position.x + (x + 0.5) * WEAR_PX
			var wy := WORLD.position.y + (y + 0.5) * WEAR_PX
			out[i * 4] = int(clampf(f[i] * 1.5, 0.0, 1.0) * 255.0)
			for k in 3:
				var v := clampf(noises[k].get_noise_2d(wx, wy) * 0.85 + 0.5, 0.0, 1.0)
				out[i * 4 + 1 + k] = int(v * 255.0)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
	var err := _save_tex(img, "wear.res")
	var prev_dir := OS.get_environment("TERRAIN_PREVIEW")
	if prev_dir != "":
		img.save_png(prev_dir + "/wear.png")
	report.append("wear: %dx%d, домов %d (%s)" % [w, h, houses, error_string(err)])


func _wear_rect(f: PackedFloat32Array, w: int, h: int, r: Rect2, v: float) -> void:
	var x0 := clampi(int((r.position.x - WORLD.position.x) / WEAR_PX), 0, w - 1)
	var y0 := clampi(int((r.position.y - WORLD.position.y) / WEAR_PX), 0, h - 1)
	var x1 := clampi(int(ceil((r.end.x - WORLD.position.x) / WEAR_PX)), 0, w)
	var y1 := clampi(int(ceil((r.end.y - WORLD.position.y) / WEAR_PX)), 0, h)
	for y in range(y0, y1):
		for x in range(x0, x1):
			f[y * w + x] = maxf(f[y * w + x], v)


func _box_blur(f: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		var s := 0.0
		for x in range(-r, r + 1):
			s += f[y * w + clampi(x, 0, w - 1)]
		for x in w:
			tmp[y * w + x] = s / (2 * r + 1)
			s += f[y * w + clampi(x + r + 1, 0, w - 1)] - f[y * w + clampi(x - r, 0, w - 1)]
	var out := PackedFloat32Array()
	out.resize(w * h)
	for x in w:
		var s := 0.0
		for y in range(-r, r + 1):
			s += tmp[clampi(y, 0, h - 1) * w + x]
		for y in h:
			out[y * w + x] = s / (2 * r + 1)
			s += tmp[clampi(y + r + 1, 0, h - 1) * w + x] - tmp[clampi(y - r, 0, h - 1) * w + x]
	return out


# ───────────────────────── обрывы ─────────────────────────
# Стены плато (слой Cliffs) запекаются заново: по каждому столбцу стены
# (верх y0 — низ y1, как в relief_shade) кладётся столбец скалы из прямых
# кусков набора с травой поверху. Верх скального фаса куска совпадает с
# верхом стены, низ — с подножием, лёгкая бахрома травы свисает над кромкой.
# Куски сшиваются по тёмным расщелинам между колоннами — шов не виден.
# Затенение (ReliefShade) остаётся поверх, коллизия не меняется.

const CLIFF_TEX := "cliff_face.res"
## Текселей запечённой стены на мировой px
const CF := 2
## Прямые куски с травой на rock_set.png (без торцов)
const CLIFF_PIECES := [Rect2i(26, 23, 181, 182), Rect2i(246, 22, 186, 181)]
## Лестница на rock_set.png
const STAIRS_RECT := Rect2i(11, 905, 168, 158)

var _rock: Image
## Те же куски вдвое крупнее и резче — из них берётся цвет стены
var _rock_hi: Image


## Масштаб куска к миру (src px на мировой px), считается по стенам плато
var _face_k := 0.0


func _step_cliffs() -> void:
	report.append(_bake_faces(["Cliffs"], false, 14, true, CLIFF_TEX, "terrain_cliff_origin"))
	var st := _hi_res(_rock, STAIRS_RECT)
	report.append("лестница: %s" % error_string(_save_tex(st, "stairs.res")))


# Кромка пропасти (слои Canyon и Chasm): серые скальные полосы старого
# рисунка — тоже стены, только низ уходит в темноту провала. Скала кладётся
# в том же масштабе, что и стены плато, без растяжения, и гаснет к низу.
func _step_canyon() -> void:
	report.append(_bake_faces(["Canyon", "Chasm"], true, 5, false, "canyon_face.res", "terrain_canyon_origin"))


## Серый камень старого рисунка (кромка провала), не земля и не чернота
static func _rock_key(c: Color) -> bool:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var l := _lum(c)
	return c.a > 0.5 and mx - mn < 0.075 and l > 0.13 and l < 0.62


func _bake_faces(layer_names: Array, rock_only: bool, min_run: int, stretch: bool,
		tex_name: String, meta: String) -> String:
	if _rock == null:
		_rock = _src_image("rock_set.png")
		_rock_hi = _hi_res(_rock, Rect2i(0, 0, 460, 215))
	var cell := 16
	var rect := Rect2i()
	var first := true
	for ln in layer_names:
		for c in (lvl.get_node(ln) as TileMapLayer).get_used_cells():
			var r := Rect2i(c * cell, Vector2i(cell, cell))
			rect = r if first else rect.merge(r)
			first = false
	rect = rect.grow(16)
	var ww := rect.size.x
	var wh := rect.size.y
	# Контур скал по тайлам, 1 тексель = 1 мировой px
	var solid := PackedByteArray()
	solid.resize(ww * wh)
	var imgs := {}
	for ln in layer_names:
		var layer := lvl.get_node(ln) as TileMapLayer
		for c in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null:
				continue
			if not imgs.has(src.texture.resource_path):
				var im := src.texture.get_image()
				if im.is_compressed():
					im.decompress()
				imgs[src.texture.resource_path] = im
			var img: Image = imgs[src.texture.resource_path]
			var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(c))
			var alt := layer.get_cell_alternative_tile(c)
			var fh := (alt & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
			var fv := (alt & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
			var step: int = region.size.x / cell
			var bx: int = c.x * cell - rect.position.x
			var by: int = c.y * cell - rect.position.y
			for ty in cell:
				for tx in cell:
					var sx: int = (cell - 1 - tx) if fh else tx
					var sy: int = (cell - 1 - ty) if fv else ty
					var px := img.get_pixel(region.position.x + sx * step + step / 2,
							region.position.y + sy * step + step / 2)
					if (_rock_key(px) if rock_only else px.a > 0.5):
						solid[(by + ty) * ww + bx + tx] = 1
	# Столбцы стены
	var runs := []          # [x, y0, y1]
	var hs: Array[int] = []
	for x in ww:
		var y := 0
		while y < wh:
			if solid[y * ww + x] == 0:
				y += 1
				continue
			var y0 := y
			var y1 := y
			var gap := 0
			var yy := y + 1
			while yy < wh and gap <= 8:
				if solid[yy * ww + x] == 1:
					y1 = yy
					gap = 0
				else:
					gap += 1
				yy += 1
			y = y1 + 1
			if y1 - y0 + 1 >= min_run:
				runs.append([x, y0, y1])
				hs.append(y1 - y0 + 1)
	if not stretch:
		runs = _smooth_runs(runs, ww, 46)
	hs.sort()
	var hp_med: int = hs[hs.size() / 2] if hs.size() > 0 else 80

	# Куски: кромка травы и подножие по каждому столбцу, расщелины
	var pieces := []
	var face_hs: Array[float] = []
	for pr: Rect2i in CLIFF_PIECES:
		var lip := PackedFloat32Array()
		var foot := PackedFloat32Array()
		var lum := PackedFloat32Array()
		for cx in range(pr.position.x, pr.end.x):
			var top := -1
			var bot := -1
			for cy in range(pr.position.y, pr.end.y):
				if _rock.get_pixel(cx, cy).a > 0.6:
					if top < 0:
						top = cy
					bot = cy
			var lp := top
			var run := 0
			for cy in range(top, bot):
				var p := _rock.get_pixel(cx, cy)
				if p.g - (p.r + p.b) * 0.5 < 0.03:
					run += 1
					if run >= 3:
						lp = cy - 2
						break
				else:
					run = 0
			lip.append(lp)
			foot.append(bot)
			face_hs.append(bot - lp)
			var s := 0.0
			for cy in range(lp, bot):
				s += _lum(_rock.get_pixel(cx, cy))
			lum.append(s / maxf(bot - lp, 1))
		# Расщелины — локальные минимумы яркости столбца
		var crev: Array[int] = []
		for i in range(3, lum.size() - 3):
			var v := lum[i]
			if v <= lum[i - 1] and v <= lum[i + 1] and v <= lum[i - 2] and v <= lum[i + 2] \
					and v < (lum[i - 3] + lum[i + 3]) * 0.5 - 0.01:
				crev.append(i)
		pieces.append({"x": pr.position.x, "lip": lip, "foot": foot, "crev": crev, "w": pr.size.x})
	face_hs.sort()
	var face_med: float = face_hs[face_hs.size() / 2]
	# Масштаб: высота фаса куска ~ типичная высота стены
	if stretch or _face_k <= 0.0:
		_face_k = face_med / float(hp_med if stretch else 90)
	var k: float = _face_k

	# Раскладка кусков вдоль x (одна на всю карту стен — соседние столбцы
	# любой стены непрерывны)
	var bw := ww * CF
	var bh := wh * CF
	var col_piece := PackedInt32Array()
	var col_src := PackedFloat32Array()
	col_piece.resize(bw)
	col_src.resize(bw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	var pi := 0
	var sc: float = pieces[0]["crev"][0]
	var stop := _next_stop(pieces[0], sc, rng)
	for bx in bw:
		col_piece[bx] = pi
		col_src[bx] = sc
		sc += k / CF
		if sc >= stop:
			pi = rng.randi() % pieces.size()
			var cr: Array[int] = pieces[pi]["crev"]
			sc = cr[rng.randi() % maxi(cr.size() - 2, 1)]
			stop = _next_stop(pieces[pi], sc, rng)

	# Запекание
	var out := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var fringe := 7.0
	for r in runs:
		var x: int = r[0]
		var y0: int = r[1]
		var y1: int = r[2]
		var hp := float(y1 - y0 + 1)
		for sub in CF:
			var bx: int = x * CF + sub
			var p: Dictionary = pieces[col_piece[bx]]
			var ci := clampi(int(col_src[bx]), 0, p["w"] - 1)
			var sx: float = p["x"] + col_src[bx]
			var lp: float = p["lip"][ci]
			var ft: float = p["foot"][ci]
			for byy in range(int((y0 - fringe) * CF), (y1 + 1) * CF):
				if byy < 0 or byy >= bh:
					continue
				var wy := float(byy) / CF
				var sy: float
				var fade := 1.0
				if wy < y0:
					sy = lp - (y0 - wy) * k
					fade = pow(1.0 - (y0 - wy) / fringe, 1.5)
				elif stretch:
					sy = lp + (wy - y0) / hp * (ft - lp + 1.0)
				else:
					# Без растяжения: верх куска у кромки, к низу гаснет в провал
					sy = lp + fmod((wy - y0) * k, maxf(ft - lp - 6.0, 8.0))
					fade = _smooth(0.0, 1.0, (y1 + 1 - wy) / 16.0)
				var c := _bilinear(_rock_hi, sx * 2.0 + 0.5, sy * 2.0 + 0.5)
				var a := _smooth(0.55, 0.9, c.a) * fade
				if a <= 0.0:
					continue
				var prev := out.get_pixel(bx, byy)
				if prev.a > a:
					continue
				out.set_pixel(bx, byy, Color(c.r, c.g, c.b, a))
	var err := _save_tex(out, tex_name)
	lvl.set_meta(meta, rect.position)
	var prev_dir := OS.get_environment("TERRAIN_PREVIEW")
	if prev_dir != "":
		out.save_png(prev_dir + "/" + tex_name.get_basename() + ".png")
	return "%s: %d столбцов, стена ~%d px, фас куска ~%.0f px, масштаб %.2f, %dx%d (%s)" % [
		tex_name, runs.size(), hp_med, face_med, k, bw, bh, error_string(err)]


## Кромка провала нарисована ступеньками пикселей: верх и низ каждого
## столбца усредняются с соседними столбцами (той же кромки), глубина
## скалы ограничена — ниже она уходит в темноту, а не висит полосами.
func _smooth_runs(runs: Array, ww: int, max_depth: int) -> Array:
	var by_x := []
	by_x.resize(ww)
	for i in ww:
		by_x[i] = []
	for r in runs:
		by_x[r[0]].append(r)
	var out := []
	var rad := 7
	for r in runs:
		var x: int = r[0]
		var s0 := 0.0
		var s1 := 0.0
		var n := 0.0
		for dx in range(-rad, rad + 1):
			var xx := x + dx
			if xx < 0 or xx >= ww:
				continue
			for q in by_x[xx]:
				if q[2] >= r[1] - 12 and q[1] <= r[2] + 12:
					var wgt := 1.0 - absf(dx) / (rad + 1.0)
					s0 += q[1] * wgt
					s1 += mini(q[2], q[1] + max_depth) * wgt
					n += wgt
		# Одиночные столбики (серые крапинки в провале) — не стена
		if n < 4.5:
			continue
		var y0 := int(round(s0 / n))
		var y1 := int(round(s1 / n))
		if y1 - y0 >= 4:
			out.append([x, y0, y1])
	return out


func _next_stop(p: Dictionary, from: float, rng: RandomNumberGenerator) -> float:
	var crev: Array[int] = p["crev"]
	var min_len := 34.0 + rng.randf() * 50.0
	for c in crev:
		if c >= from + min_len:
			return c
	return crev[crev.size() - 1] if crev[crev.size() - 1] > from + 4 else from + 8


static func _bilinear(img: Image, x: float, y: float) -> Color:
	var x0 := clampi(int(floor(x)), 0, img.get_width() - 2)
	var y0 := clampi(int(floor(y)), 0, img.get_height() - 2)
	var fx := clampf(x - x0, 0.0, 1.0)
	var fy := clampf(y - y0, 0.0, 1.0)
	var a := img.get_pixel(x0, y0).lerp(img.get_pixel(x0 + 1, y0), fx)
	var b := img.get_pixel(x0, y0 + 1).lerp(img.get_pixel(x0 + 1, y0 + 1), fx)
	return a.lerp(b, fy)


# ───────────────────────── сцена ─────────────────────────
## Слои, у которых в атласах есть старая земля
const GROUND_LAYERS := ["FrameGround", "Ground", "GroundDetail", "PurpleGround", "Stone",
	"South", "Canyon", "Chasm", "Water"]
const MATERIAL := OUT + "ground_material.tres"


func _step_apply() -> void:
	# Материал — отдельным файлом: параметры земли правятся в одном месте
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("ground_layers", load(OUT + "ground_layers.png"))
	mat.set_shader_parameter("mask_medieval", load(OUT + "mask_medieval.res"))
	mat.set_shader_parameter("mask_reskin", load(OUT + "mask_reskin.res"))
	mat.set_shader_parameter("mask_canyon", load(OUT + "mask_canyon.res"))
	mat.set_shader_parameter("wear_map", load(OUT + "wear.res"))
	mat.set_shader_parameter("wear_rect", Vector4(WORLD.position.x, WORLD.position.y, WORLD.size.x, WORLD.size.y))
	if ResourceLoader.exists(MATERIAL):
		# Подобранные вручную параметры не затираются
		var old := load(MATERIAL) as ShaderMaterial
		for p in ["tile_world", "brightness", "tint", "grass_bias"]:
			var v = old.get_shader_parameter(p)
			if v != null:
				mat.set_shader_parameter(p, v)
	var err := ResourceSaver.save(mat, MATERIAL)
	mat = ResourceLoader.load(MATERIAL, "", ResourceLoader.CACHE_MODE_REPLACE)
	for ln in GROUND_LAYERS:
		(lvl.get_node(ln) as CanvasItem).material = mat

	# Стены: старый слой прячется (он только картинка, коллизия отдельно)
	var cliffs := lvl.get_node("Cliffs") as TileMapLayer
	cliffs.visible = false
	for n in ["CliffFace", "CanyonFace", "CliffStairs0", "CliffStairs1"]:
		var old := lvl.get_node_or_null(n)
		if old:
			lvl.remove_child(old)
			old.free()
	var face := Sprite2D.new()
	face.name = "CliffFace"
	face.texture = ResourceLoader.load(OUT + CLIFF_TEX, "", ResourceLoader.CACHE_MODE_REPLACE)
	face.centered = false
	var origin: Vector2i = lvl.get_meta("terrain_cliff_origin", Vector2i.ZERO)
	face.position = Vector2(origin)
	face.scale = Vector2(1.0 / CF, 1.0 / CF)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lvl.add_child(face)
	face.owner = lvl
	lvl.move_child(face, cliffs.get_index() + 1)
	# Кромка пропасти — сразу над слоем провала (под водой и стенами плато)
	if lvl.has_meta("terrain_canyon_origin"):
		var cf := Sprite2D.new()
		cf.name = "CanyonFace"
		cf.texture = ResourceLoader.load(OUT + "canyon_face.res", "", ResourceLoader.CACHE_MODE_REPLACE)
		cf.centered = false
		cf.position = Vector2(lvl.get_meta("terrain_canyon_origin") as Vector2i)
		cf.scale = Vector2(1.0 / CF, 1.0 / CF)
		cf.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		lvl.add_child(cf)
		cf.owner = lvl
		lvl.move_child(cf, lvl.get_node("Chasm").get_index() + 1)

	# Лестницы в проходах стены — поверх затенения со старыми ступенями
	var shade := lvl.get_node("ReliefShade")
	var stairs_tex: Texture2D = ResourceLoader.load(OUT + "stairs.res", "", ResourceLoader.CACHE_MODE_REPLACE)
	var i := 0
	for r: Rect2 in lvl.get_meta("relief_stairs", []):
		var s := Sprite2D.new()
		s.name = "CliffStairs%d" % i
		s.texture = stairs_tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# Боковые бортики заходят на торцы стены, низ — чуть на нижнюю землю
		var w := r.size.x * 1.34
		var h := r.size.y + 14.0
		s.scale = Vector2(w / stairs_tex.get_width(), h / stairs_tex.get_height())
		s.position = Vector2(r.position.x + r.size.x * 0.5 - w * 0.5, r.position.y - 8.0)
		lvl.add_child(s)
		s.owner = lvl
		lvl.move_child(s, shade.get_index() + 1 + i)
		i += 1
	lvl.set_meta("terrain_v1", true)

	var ps := PackedScene.new()
	var err2 := ps.pack(lvl)
	if err2 == OK:
		err2 = ResourceSaver.save(ps, SCENE)
	report.append("apply: материал на %d слоёв (%s), стены и %d лестницы, сцена (%s)" % [
		GROUND_LAYERS.size(), error_string(err), i, error_string(err2)])
