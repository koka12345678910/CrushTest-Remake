extends RefCounted
## Общие операции над картинками от GPT (src/hd): загрузка png/webp, чистка
## края после вырезки фона, уменьшение без тёмной каймы, файл импорта.
## Подключается через preload из tools/*.gd.


## Картинка из src/hd по имени без расширения (или с ним): png, потом webp
static func load_hd(dir: String, name: String) -> Image:
	var tries := [name] if name.get_extension() != "" else [name + ".png", name + ".webp"]
	for f in tries:
		var p := ProjectSettings.globalize_path(dir + f)
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			img.convert(Image.FORMAT_RGBA8)
			return img
	push_error("art_util: нет картинки %s%s" % [dir, name])
	return null


## Чистка края. GPT вырезает фон неаккуратно: в полупрозрачной кайме
## остаётся цвет фона (часто красный или белый), а под полностью прозрачными
## пикселями — мусор, который при линейной фильтрации проступает ореолом.
## Цвет каймы заменяется цветом ближайшего плотного пикселя предмета,
## ярко-красные и белёсые остатки фона в кайме гасятся.
static func clean_edges(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for i in w * h:
		solid[i] = 1 if d[i * 4 + 3] >= 245 else 0
	var out := d.duplicate()
	for y in h:
		for x in w:
			var i := y * w + x
			if solid[i] == 1:
				continue
			var a := d[i * 4 + 3]
			var r := d[i * 4]
			var g := d[i * 4 + 1]
			var b := d[i * 4 + 2]
			# Остаток фона: насыщенно-красный или почти белый в кайме
			if a > 0 and (r - maxi(g, b) > 60 or (mini(r, mini(g, b)) > 215)):
				a = a / 3
			# Цвет — от плотных соседей (окно растёт до 4 px)
			var sr := 0
			var sg := 0
			var sb := 0
			var n := 0
			for rad in [1, 2, 4]:
				for dy in range(-rad, rad + 1):
					var yy: int = y + dy
					if yy < 0 or yy >= h:
						continue
					for dx in range(-rad, rad + 1):
						var xx: int = x + dx
						if xx < 0 or xx >= w:
							continue
						var j := yy * w + xx
						if solid[j] == 1:
							sr += d[j * 4]
							sg += d[j * 4 + 1]
							sb += d[j * 4 + 2]
							n += 1
				if n > 0:
					break
			if n > 0:
				out[i * 4] = sr / n
				out[i * 4 + 1] = sg / n
				out[i * 4 + 2] = sb / n
			elif a < 8:
				out[i * 4] = 0
				out[i * 4 + 1] = 0
				out[i * 4 + 2] = 0
			out[i * 4 + 3] = a
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## Уменьшение с премультипликацией: без тёмной каймы на краях
static func resize_clean(img: Image, w: int, h: int) -> Image:
	var im := img.duplicate() as Image
	im.premultiply_alpha()
	im.resize(maxi(w, 1), maxi(h, 1), Image.INTERPOLATE_LANCZOS)
	var d := im.get_data()
	for i in range(0, d.size(), 4):
		var a := d[i + 3]
		if a < 4:
			continue
		for ch in 3:
			d[i + ch] = clampi(int(d[i + ch] * 255.0 / a + 0.5), 0, 255)
	return Image.create_from_data(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8, d)


## Только сам предмет: в прямоугольник нарезки с листа попадают обрывки
## соседних предметов. Остаются связные куски не меньше min_share от самого
## крупного (так сломанный забор из двух половин сохраняется целиком)
static func keep_main(img: Image, min_share: float = 0.15) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var lab := PackedInt32Array()
	lab.resize(w * h)
	var sizes := [0]
	for y0 in h:
		for x0 in w:
			if lab[y0 * w + x0] != 0 or img.get_pixel(x0, y0).a < 0.05:
				continue
			var id := sizes.size()
			var n := 0
			var st := [Vector2i(x0, y0)]
			lab[y0 * w + x0] = id
			while not st.is_empty():
				var p: Vector2i = st.pop_back()
				n += 1
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
							continue
						var qi := q.y * w + q.x
						if lab[qi] != 0 or img.get_pixel(q.x, q.y).a < 0.05:
							continue
						lab[qi] = id
						st.append(q)
			sizes.append(n)
	var biggest := 0
	for s in sizes:
		biggest = maxi(biggest, s)
	var out := img.duplicate() as Image
	for y in h:
		for x in w:
			var id := lab[y * w + x]
			if id != 0 and sizes[id] < biggest * min_share:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out.get_region(out.get_used_rect())


## Бесшовность плитки: края смешиваются с копией, сдвинутой на полразмера
## (у той на краях — середина картинки). GPT обещает бесшовность, но шов
## обычно остаётся. border — ширина перехода, доля от размера
static func make_tileable(img: Image, border: float = 0.18) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := img.duplicate() as Image
	var bw := maxf(w * border, 1.0)
	var bh := maxf(h * border, 1.0)
	for y in h:
		var dy := minf(y, h - 1 - y)
		for x in w:
			var dx := minf(x, w - 1 - x)
			var k := 1.0 - minf(minf(dx / bw, dy / bh), 1.0)
			if k <= 0.0:
				continue
			k = k * k * (3.0 - 2.0 * k)
			var a := img.get_pixel(x, y)
			var b := img.get_pixel((x + w / 2) % w, (y + h / 2) % h)
			out.set_pixel(x, y, a.lerp(b, k))
	return out


## Средний цвет плотных пикселей
static func mean_color(img: Image) -> Color:
	var d := img.get_data()
	var s := [0.0, 0.0, 0.0]
	var n := 0
	for i in range(0, d.size(), 4 * 7):
		if d[i + 3] < 240:
			continue
		for ch in 3:
			s[ch] += d[i + ch]
		n += 1
	if n == 0:
		return Color(0.5, 0.5, 0.5)
	return Color(s[0] / n / 255.0, s[1] / n / 255.0, s[2] / n / 255.0)


## Подгонка тона под окружение: средний цвет картинки становится target
## (по каналам, умножением — тени остаются тенями), контраст вокруг среднего
## умножается на contrast
static func match_tone(img: Image, target: Color, contrast: float = 1.0) -> Image:
	var m := mean_color(img)
	var gain := [target.r / maxf(m.r, 0.01), target.g / maxf(m.g, 0.01), target.b / maxf(m.b, 0.01)]
	var mean := [target.r * 255.0, target.g * 255.0, target.b * 255.0]
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		for ch in 3:
			var v: float = d[i + ch] * gain[ch]
			v = mean[ch] + (v - mean[ch]) * contrast
			d[i + ch] = clampi(int(v + 0.5), 0, 255)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)


## Лёгкая резкость после сильного уменьшения
static func unsharp(img: Image, amount: float) -> Image:
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


## Файл .import для PNG рядом с ним: BPTC, как у остальных атласов карты.
## Без него консольный --import взял бы настройки по умолчанию (Lossless)
static func write_import(res_png: String, mipmaps: bool) -> void:
	var p := ProjectSettings.globalize_path(res_png + ".import")
	if FileAccess.file_exists(p):
		return
	var t := """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=%s
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
""" % [res_png, "true" if mipmaps else "false"]
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(t)
	f.close()
