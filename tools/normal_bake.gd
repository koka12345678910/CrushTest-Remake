extends SceneTree
## Карты нормалей для HD-арта reference_map (свет факелов ложится по рельефу).
##
##   godot --headless --path . -s res://tools/normal_bake.gd -- [имя ...]
##   godot --headless --path . --import
##
## Без имён — все из SOURCES. Пишет reference_map_level/textures/normals/<имя>_n.png
## (в половину размера исходника: нормаль гладкая, памяти вчетверо меньше;
## CanvasTexture берёт её по тем же UV, размер не обязан совпадать).
## В игре их подключает reference_map_level/scripts/normal_maps.gd.
##
## Рельеф из двух частей:
##   форма   — размытая альфа: к краю силуэта поверхность уходит вниз, край
##             смотрит наружу (крона — шар, бочка — цилиндр, дом — фаска);
##   детали  — яркость минус её размытие (нормированная свёртка, чтобы край
##             силуэта не давал ложного обрыва): светлое — выпуклое. На
##             живописном арте это камни, доски, черепица, пучки листвы.
## Нормаль: R — вправо, G — вверх (как ждёт Godot), B — к зрителю.

const ArtUtil := preload("res://tools/art_util.gd")
const OUT_DIR := "res://reference_map_level/textures/normals/"
const TEX := "res://reference_map_level/textures/"

## имя: [путь, масштаб, радиус формы (px исходника), вес формы, вес деталей,
##        радиус деталей (px исходника), средний наклон нормали]
## Веса задают только долю формы и деталей; итоговая крутизна подгоняется
## так, чтобы средняя длина XY нормали по непрозрачному была равна наклону
## (0.3 ≈ 17°). Яркость живописного арта у разных картинок разная — без
## подгонки одни выходили бы плоскими, другие рваными.
const SOURCES := {
	"forest_trees": [TEX + "forest_trees.png", 0.5, 24.0, 1.0, 1.6, 10.0, 0.34],
	"hd_props": [TEX + "hd_props.png", 0.5, 12.0, 1.0, 1.6, 8.0, 0.3],
	"village_houses_hd": [TEX + "village_houses_hd.png", 0.5, 8.0, 0.6, 1.6, 8.0, 0.26],
	"town_houses_hd": [TEX + "town_houses_hd.png", 0.5, 8.0, 0.6, 1.6, 8.0, 0.26],
	"medieval_houses": [TEX + "medieval_houses.png", 0.5, 8.0, 0.6, 1.6, 8.0, 0.26],
	"camp_hd": [TEX + "camp_hd.png", 0.5, 12.0, 1.0, 1.6, 8.0, 0.3],
	"farm_props": [TEX + "farm_props.png", 0.5, 12.0, 1.0, 1.6, 8.0, 0.3],
	"fort_port_art": [TEX + "fort_port_art.png", 0.5, 8.0, 0.6, 1.6, 8.0, 0.26],
	"cliff_face": [TEX + "terrain/cliff_face.res", 0.5, 8.0, 0.4, 1.6, 18.0, 0.36],
	"canyon_face": [TEX + "terrain/canyon_face.res", 0.5, 8.0, 0.4, 1.6, 18.0, 0.36],
	"stairs_0": [TEX + "terrain/stairs_0.res", 0.5, 6.0, 0.4, 1.6, 10.0, 0.32],
	"stairs_1": [TEX + "terrain/stairs_1.res", 0.5, 6.0, 0.4, 1.6, 10.0, 0.32],
}


## Бесшовные плитки земли (их собирает shaders/terrain_ground.gdshader и
## camp_ground.gdshader): каждый слой полосы печётся отдельно, с заворотом
## краёв — у нормали нет шва на стыке плиток. Непрозрачные: формы нет.
## имя: [путь, слоёв в полосе, масштаб, вес альфы как высоты, радиус деталей, наклон]
## У брусчатки в альфе высота камня (её же берёт шейдер на стыках) — рельеф
## камней из неё, щели между ними — впадины.
const TILED := {
	"ground_layers": [TEX + "terrain/ground_layers.png", 11, 1.0, 0.0, 6.0, 0.3],
	"cobble_layers": [TEX + "terrain/cobble_layers.png", 2, 0.5, 1.0, 6.0, 0.42],
	"camp_mud": [TEX + "terrain/camp_mud.png", 1, 0.5, 0.0, 8.0, 0.32],
	"camp_ash": [TEX + "terrain/camp_ash.png", 1, 0.5, 0.0, 8.0, 0.26],
}


func _initialize() -> void:
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		names = PackedStringArray(SOURCES.keys() + TILED.keys())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for nm in names:
		if TILED.has(nm):
			_bake_tiled(nm, TILED[nm])
			continue
		if not SOURCES.has(nm):
			push_error("нет такого: " + nm)
			continue
		var t0 := Time.get_ticks_msec()
		var p: Array = SOURCES[nm]
		var img := _load(p[0])
		if img == null:
			push_error("не загрузилось: " + str(p[0]))
			continue
		var n := bake(img, p[1], p[2], p[3], p[4], p[5], p[6])
		var out: String = OUT_DIR + nm + "_n.png"
		n.save_png(ProjectSettings.globalize_path(out))
		ArtUtil.write_import(out, false)
		print("%s: %dx%d -> %dx%d, %d мс" % [nm, img.get_width(), img.get_height(), n.get_width(), n.get_height(), Time.get_ticks_msec() - t0])
	quit()


func _bake_tiled(nm: String, p: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var img := _load(p[0])
	if img == null:
		push_error("не загрузилось: " + str(p[0]))
		return
	var slices: int = p[1]
	var sw := img.get_width() / slices
	var out_img: Image = null
	for si in slices:
		var part := img.get_region(Rect2i(si * sw, 0, sw, img.get_height()))
		var n := bake_tile(part, p[2], p[3], p[4], p[5])
		if out_img == null:
			out_img = Image.create(n.get_width() * slices, n.get_height(), false, Image.FORMAT_RGB8)
		out_img.blit_rect(n, Rect2i(Vector2i.ZERO, n.get_size()), Vector2i(si * n.get_width(), 0))
	var out: String = OUT_DIR + nm + "_n.png"
	out_img.save_png(ProjectSettings.globalize_path(out))
	if slices > 1:
		_write_array_import(out, slices)
	else:
		ArtUtil.write_import(out, true)
	print("%s: %d слоёв -> %dx%d, %d мс" % [nm, slices, out_img.get_width(), out_img.get_height(), Time.get_ticks_msec() - t0])


## Полоса слоёв — Texture2DArray (как ground_layers.png): без сжатия, с мипами
static func _write_array_import(res_png: String, slices: int) -> void:
	var p := ProjectSettings.globalize_path(res_png + ".import")
	if FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("""[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[deps]

source_file="%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=%d
slices/vertical=1
""" % [res_png, slices])


## Одна бесшовная плитка: высота = альфа × alpha_h (если там высота) + детали
## яркости; размытие и уклоны с заворотом краёв
static func bake_tile(src: Image, scale: float, alpha_h: float, detail_r: float, tilt: float) -> Image:
	var img := src.duplicate() as Image
	var w := maxi(int(round(img.get_width() * scale)), 1)
	var h := maxi(int(round(img.get_height() * scale)), 1)
	if w != img.get_width():
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var data := img.get_data()
	var n := w * h
	var lum := PackedFloat32Array()
	var al := PackedFloat32Array()
	lum.resize(n)
	al.resize(n)
	for i in n:
		var o := i * 4
		lum[i] = (0.3 * data[o] + 0.59 * data[o + 1] + 0.11 * data[o + 2]) / 255.0
		al[i] = data[o + 3] / 255.0
	var dr := maxi(int(round(detail_r * scale / 1.7)), 1)
	var bl := _gauss_wrap(lum, w, h, dr)
	var ls := _box_wrap(lum, w, h, 1)
	var hs := _box_wrap(al, w, h, 1) if alpha_h > 0.0 else al
	var height := PackedFloat32Array()
	height.resize(n)
	for i in n:
		height[i] = hs[i] * alpha_h * float(dr) * 2.0 + clampf(ls[i] - bl[i], -0.3, 0.3) * float(dr)
	var gx := PackedFloat32Array()
	var gy := PackedFloat32Array()
	gx.resize(n)
	gy.resize(n)
	var sum := 0.0
	for y in h:
		var ym := posmod(y - 1, h) * w
		var yp := posmod(y + 1, h) * w
		var row := y * w
		for x in w:
			var i := row + x
			gx[i] = (height[row + posmod(x + 1, w)] - height[row + posmod(x - 1, w)]) * 0.5
			gy[i] = (height[yp + x] - height[ym + x]) * 0.5
			sum += sqrt(gx[i] * gx[i] + gy[i] * gy[i])
	var k := (tilt / sqrt(1.0 - tilt * tilt)) / maxf(sum / float(n), 0.0001)
	var out := PackedByteArray()
	out.resize(n * 3)
	for i in n:
		var nv := Vector3(-gx[i] * k, -gy[i] * k, 1.0).normalized()
		out[i * 3] = clampi(int(round((nv.x * 0.5 + 0.5) * 255.0)), 0, 255)
		out[i * 3 + 1] = clampi(int(round((-nv.y * 0.5 + 0.5) * 255.0)), 0, 255)
		out[i * 3 + 2] = clampi(int(round((nv.z * 0.5 + 0.5) * 255.0)), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, out)


static func _gauss_wrap(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	return _box_wrap(_box_wrap(_box_wrap(src, w, h, r), w, h, r), w, h, r)


## Скользящее среднее с заворотом краёв (плитка повторяется)
static func _box_wrap(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var inv := 1.0 / float(2 * r + 1)
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		var row := y * w
		var s := 0.0
		for k in range(-r, r + 1):
			s += src[row + posmod(k, w)]
		for x in w:
			tmp[row + x] = s * inv
			s += src[row + posmod(x + r + 1, w)] - src[row + posmod(x - r, w)]
	var out := PackedFloat32Array()
	out.resize(w * h)
	for x in w:
		var s := 0.0
		for k in range(-r, r + 1):
			s += tmp[posmod(k, h) * w + x]
		for y in h:
			out[y * w + x] = s * inv
			s += tmp[posmod(y + r + 1, h) * w + x] - tmp[posmod(y - r, h) * w + x]
	return out


func _load(path: String) -> Image:
	var img: Image
	if path.ends_with(".png"):
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	else:
		var t: Texture2D = load(path)
		img = t.get_image() if t else null
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func bake(src: Image, scale: float, shape_r: float, shape_h: float, detail_h: float, detail_r: float, tilt: float) -> Image:
	var img := src.duplicate() as Image
	var w := maxi(int(round(img.get_width() * scale)), 1)
	var h := maxi(int(round(img.get_height() * scale)), 1)
	# Премультипликация перед уменьшением: прозрачные пиксели не тянут цвет
	img.premultiply_alpha()
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var data := img.get_data()
	var n := w * h
	var a := PackedFloat32Array()
	var la := PackedFloat32Array()
	a.resize(n)
	la.resize(n)
	for i in n:
		var o := i * 4
		var al := data[o + 3] / 255.0
		a[i] = al
		# Цвет премультиплицирован: яркость × альфа
		la[i] = (0.3 * data[o] + 0.59 * data[o + 1] + 0.11 * data[o + 2]) / 255.0
	# Форма: размытая альфа (три коробки ≈ гаусс)
	var sr := maxi(int(round(shape_r * scale / 1.7)), 1)
	var shape := _gauss(a, w, h, sr)
	# Детали: яркость минус её размытие, нормированная свёртка по альфе
	var dr := maxi(int(round(detail_r * scale / 1.7)), 1)
	var bl := _gauss(la, w, h, dr)
	var ba := _gauss(a, w, h, dr)
	var lum_s := _box(la, w, h, 1)
	var a_s := _box(a, w, h, 1)
	var height := PackedFloat32Array()
	height.resize(n)
	for i in n:
		var d := 0.0
		if a_s[i] > 0.05 and ba[i] > 0.05:
			d = clampf(lum_s[i] / a_s[i] - bl[i] / ba[i], -0.3, 0.3)
		# Форма меняется на всём радиусе, детали — на нескольких px: уравниваем
		# их уклоны делением на радиус
		height[i] = shape[i] * shape_h * float(sr) + d * detail_h * a_s[i] * float(dr)
	# Уклоны
	var gx := PackedFloat32Array()
	var gy := PackedFloat32Array()
	gx.resize(n)
	gy.resize(n)
	var sum := 0.0
	var cnt := 0
	for y in h:
		var ym := maxi(y - 1, 0) * w
		var yp := mini(y + 1, h - 1) * w
		var row := y * w
		for x in w:
			var i := row + x
			gx[i] = (height[row + mini(x + 1, w - 1)] - height[row + maxi(x - 1, 0)]) * 0.5
			gy[i] = (height[yp + x] - height[ym + x]) * 0.5
			if a[i] > 0.5:
				sum += sqrt(gx[i] * gx[i] + gy[i] * gy[i])
				cnt += 1
	# Подгонка крутизны: |xy| = g/√(1+g²) ≈ наклон, если g = наклон/√(1−наклон²)
	var want := tilt / sqrt(1.0 - tilt * tilt)
	var k := want / maxf(sum / maxf(cnt, 1), 0.0001)
	var out := PackedByteArray()
	out.resize(n * 3)
	for i in n:
		var o := i * 3
		if a[i] < 0.02:
			out[o] = 128
			out[o + 1] = 128
			out[o + 2] = 255
			continue
		# y картинки вниз; нормаль (-dx, -dy, 1), в текстуру G — вверх
		var nv := Vector3(-gx[i] * k, -gy[i] * k, 1.0).normalized()
		out[o] = clampi(int(round((nv.x * 0.5 + 0.5) * 255.0)), 0, 255)
		out[o + 1] = clampi(int(round((-nv.y * 0.5 + 0.5) * 255.0)), 0, 255)
		out[o + 2] = clampi(int(round((nv.z * 0.5 + 0.5) * 255.0)), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, out)


static func _gauss(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	return _box(_box(_box(src, w, h, r), w, h, r), w, h, r)


## Скользящее среднее по квадрату (2r+1)², край — повтор крайнего пикселя
static func _box(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var inv := 1.0 / float(2 * r + 1)
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		var row := y * w
		var s := 0.0
		for k in range(-r, r + 1):
			s += src[row + clampi(k, 0, w - 1)]
		for x in w:
			tmp[row + x] = s * inv
			s += src[row + mini(x + r + 1, w - 1)] - src[row + maxi(x - r, 0)]
	var out := PackedFloat32Array()
	out.resize(w * h)
	for x in w:
		var s := 0.0
		for k in range(-r, r + 1):
			s += tmp[clampi(k, 0, h - 1) * w + x]
		for y in h:
			out[y * w + x] = s * inv
			s += tmp[mini(y + r + 1, h - 1) * w + x] - tmp[maxi(y - r, 0) * w + x]
	return out
