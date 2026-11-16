extends SceneTree
## Ресурсы «погружения» reference_map (reference_map_level/scripts/immersion.gd).
##
## Шаги:
##   foreground — reference_map_level/textures/immersion/foreground.png (+ .json):
##                размытые тёмные силуэты переднего плана (кроны, ветви,
##                папоротник, трава) из картинок src/hd. Хранятся маленькими:
##                в игре растягиваются в несколько раз — линейная фильтрация
##                даёт мягкость «не в фокусе» бесплатно.
##   smoke      — reference_map_level/textures/immersion/smoke.png: 4 клуба дыма
##                (шум с мягким краем) в одну строку.
##   sounds     — Sound/ambience/*.wav: звуки, которых в проекте не было,
##                синтезом (никаких чужих лицензий): река, шелест листвы,
##                болото (лягушки, мухи), хлопающая ткань, скрип ставней,
##                скрип верёвки. Моно 22 050 Гц, 16 бит.
##   ravine     — textures/immersion/ravine_mask.res: где в слое South чёрная
##                пустота западного оврага (туман в нём).
##   steps      — Sound/footsteps/wood_1..6, water_1..6 (шаги по доскам и по
##                воде/грязи), Sound/ambience/squeak_1..3 (писк крыс).
##   all        — всё сразу.
##
## Запуск (после — импорт, иначе игра не увидит новые файлы):
##   godot --headless --path . -s res://tools/immersion_bake.gd -- all
##   godot --headless --path . --import

const AU := preload("res://tools/art_util.gd")
const HD := "res://reference_map_level/textures/src/hd/"
const OUT := "res://reference_map_level/textures/immersion/"
const SND := "res://Sound/ambience/"
const SR := 22050


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var step := args[0] if args.size() > 0 else "all"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if step in ["foreground", "all"]:
		_foreground()
	if step in ["smoke", "all"]:
		_smoke()
	if step in ["sounds", "all"]:
		_sounds()
	if step in ["ravine", "all"]:
		_ravine()
	if step in ["steps", "all"]:
		_steps()
	quit()


# ======================= ОВРАГ =======================
# Западный овраг с верёвочным мостом нарисован чёрными тайлами внутри слоя
# South (вперемешку с землёй). Какие клетки — пустота, видно только по
# картинке тайла; атлас 4096×7424 в игре разжимать дорого, поэтому маска
# считается здесь: textures/immersion/ravine_mask.res (ImageTexture L8,
# тексель = клетка, meta "area" — прямоугольник в мире).

func _ravine() -> void:
	var lvl: Node = (load("res://reference_map_level/reference_map.tscn") as PackedScene).instantiate()
	var l := lvl.get_node("South") as TileMapLayer
	var dark := {}
	var imgs := {}
	var cells: Array[Vector2i] = []
	for cell in l.get_used_cells():
		var sid := l.get_cell_source_id(cell)
		var ac := l.get_cell_atlas_coords(cell)
		var key := Vector3i(sid, ac.x, ac.y)
		if not dark.has(key):
			var src := l.tile_set.get_source(sid) as TileSetAtlasSource
			var path := src.texture.resource_path
			if not imgs.has(path):
				imgs[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
			var img: Image = imgs[path]
			var r := src.get_tile_texture_region(ac)
			var sum := 0.0
			var n := 0
			for y in range(r.position.y + 2, r.end.y - 2, 3):
				for x in range(r.position.x + 2, r.end.x - 2, 3):
					var c := img.get_pixel(x, y)
					sum += c.get_luminance() * c.a + (1.0 - c.a)
					n += 1
			dark[key] = n > 0 and sum / n < 0.06
		if dark[key]:
			cells.append(cell)
	cells = _keep_big_groups(cells, 40)
	if cells.is_empty():
		print("ravine: тёмных клеток нет")
		lvl.free()
		return
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var size := hi - lo + Vector2i.ONE
	var mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for c in cells:
		mask.set_pixel(c.x - lo.x, c.y - lo.y, Color.WHITE)
	var tex := ImageTexture.create_from_image(mask)
	var ts := Vector2(l.tile_set.tile_size) * l.scale
	var p0 := l.position + l.map_to_local(lo) * l.scale - ts * 0.5
	tex.set_meta("area", Rect2(p0, Vector2(size) * ts))
	ResourceSaver.save(tex, OUT + "ravine_mask.res")
	print("ravine: %d клеток, область %s" % [cells.size(), Rect2(p0, Vector2(size) * ts)])
	lvl.free()


## Только связные группы клеток не меньше min_cells: тёмные пятна болота
## и одиночные тени — не овраг
func _keep_big_groups(cells: Array[Vector2i], min_cells: int) -> Array[Vector2i]:
	var left := {}
	for c in cells:
		left[c] = true
	var out: Array[Vector2i] = []
	for c in cells:
		if not left.has(c):
			continue
		var group: Array[Vector2i] = [c]
		left.erase(c)
		var i := 0
		while i < group.size():
			var g := group[i]
			i += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = g + d
				if left.has(nb):
					left.erase(nb)
					group.append(nb)
		if group.size() >= min_cells:
			out.append_array(group)
	return out


# ======================= ПЕРЕДНИЙ ПЛАН =======================

## имя: [файл, доля сверху (0..1, обрезка ствола), макс. размер, сила размытия, вид]
const FG := {
	"crown_oak": ["tree_oak", 0.72, 256, 2, "crown"],
	"crown_ancient": ["tree_oak_ancient", 0.75, 256, 2, "crown"],
	"crown_crimson": ["tree_crimson", 0.72, 256, 2, "crown"],
	"crown_spruce": ["tree_spruce", 0.8, 224, 2, "crown"],
	"crown_weeping": ["tree_birch_weeping_dark", 0.8, 224, 2, "crown"],
	"branch_dead": ["tree_dead", 0.75, 256, 2, "branch"],
	"branch_broken": ["tree_dead_broken", 0.8, 224, 2, "branch"],
	"fern": ["fern", 1.0, 192, 2, "grass"],
	"grass": ["grass_tuft", 1.0, 192, 2, "grass"],
	"twigs": ["bush_dry_twigs", 1.0, 192, 2, "grass"],
	"bush": ["bush_green", 1.0, 192, 2, "grass"],
}


func _foreground() -> void:
	var parts := {}
	for key in FG:
		var d: Array = FG[key]
		var src := AU.load_hd(HD, d[0])
		if src == null:
			continue
		var used := src.get_used_rect()
		used.size.y = int(used.size.y * float(d[1]))
		var img := src.get_region(used)
		var mx: int = d[2]
		var s := float(mx) / maxf(img.get_width(), img.get_height())
		var w := maxi(int(img.get_width() * s), 8)
		var h := maxi(int(img.get_height() * s), 8)
		# Размытие: уменьшить в blur раз и вернуть размер кубикой
		var blur: int = d[3]
		var small := AU.resize_clean(img, maxi(w / blur, 4), maxi(h / blur, 4))
		var soft := AU.resize_clean(small, w, h)
		# Чуть резкости поверх, чтобы не превращалось в пятно
		var sharp := AU.resize_clean(img, w, h)
		_mix_into(soft, sharp, 0.25)
		_silhouette(soft, d[4])
		_pad(soft)
		parts[key] = soft
	# Упаковка в одну строку-полку
	var total_w := 0
	var max_h := 0
	for k in parts:
		total_w += parts[k].get_width() + 4
		max_h = maxi(max_h, parts[k].get_height())
	var atlas := Image.create(total_w, max_h, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var meta := {}
	var x := 0
	for k in parts:
		var p: Image = parts[k]
		atlas.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(x, 0))
		meta[k] = {"rect": [x, 0, p.get_width(), p.get_height()], "kind": FG[k][4]}
		x += p.get_width() + 4
	var path := OUT + "foreground.png"
	atlas.save_png(ProjectSettings.globalize_path(path))
	AU.write_import(path, false)
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "foreground.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("foreground: %d частей, атлас %dx%d" % [parts.size(), total_w, max_h])


func _mix_into(dst: Image, src: Image, k: float) -> void:
	for y in dst.get_height():
		for x in dst.get_width():
			dst.set_pixel(x, y, dst.get_pixel(x, y).lerp(src.get_pixel(x, y), k))


## Тёмный силуэт против света: немного фактуры, почти без цвета
func _silhouette(img: Image, kind: String) -> void:
	var tint := Color(0.05, 0.06, 0.05) if kind != "branch" else Color(0.05, 0.05, 0.055)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			var rgb := Color(l, l, l).lerp(c, 0.45)
			var o := Color(tint.r + rgb.r * 0.22, tint.g + rgb.g * 0.22, tint.b + rgb.b * 0.22, c.a)
			img.set_pixel(x, y, o)


## Прозрачная рамка в 2 пикселя: линейная фильтрация не тянет край к соседу
func _pad(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if x < 2 or y < 2 or x >= img.get_width() - 2 or y >= img.get_height() - 2:
				var c := img.get_pixel(x, y)
				c.a = 0.0
				img.set_pixel(x, y, c)


# ======================= ДЫМ =======================

func _smoke() -> void:
	var n := 4
	var size := 128
	var img := Image.create(size * n, size, false, Image.FORMAT_RGBA8)
	for i in n:
		var noise := FastNoiseLite.new()
		noise.seed = 17 + i * 31
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		for y in size:
			for x in size:
				var dx := (x - size * 0.5) / (size * 0.5)
				var dy := (y - size * 0.5) / (size * 0.5)
				var r := sqrt(dx * dx + dy * dy)
				var fall := clampf(1.0 - r, 0.0, 1.0)
				fall = fall * fall * (3.0 - 2.0 * fall)
				var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf((v - 0.2) * 2.2, 0.0, 1.0) * fall
				var shade := 0.82 + 0.18 * v
				img.set_pixel(i * size + x, y, Color(shade, shade, shade, a))
	var path := OUT + "smoke.png"
	img.save_png(ProjectSettings.globalize_path(path))
	AU.write_import(path, true)
	print("smoke: ok")


# ======================= ЗВУКИ =======================

var _rng := RandomNumberGenerator.new()


func _sounds() -> void:
	_rng.seed = 4242
	_save_wav("river_loop", _loopify(_river(12.0), 1.0))
	_save_wav("leaves_loop", _loopify(_leaves(12.0), 1.0))
	_save_wav("swamp_loop", _loopify(_swamp(16.0), 1.0))
	_save_wav("cloth_loop", _loopify(_cloth(10.0), 1.0))
	for i in 3:
		_save_wav("creak_%d" % (i + 1), _creak(0.7 + i * 0.25, [620.0 + i * 90.0, 1240.0 + i * 140.0, 2050.0, 175.0], 38.0 + i * 8.0, 95.0 + i * 10.0))
	for i in 2:
		_save_wav("rope_creak_%d" % (i + 1), _creak(1.1 + i * 0.3, [330.0 + i * 40.0, 720.0, 1180.0, 140.0], 18.0, 46.0 + i * 6.0))
	print("sounds: ok")


## Шаги по доскам и по воде/грязи (Sound/footsteps/wood_*, water_*) и писк
## крысы (Sound/ambience/squeak_*). Громкость — по пику готовых шагов soft_*
func _steps() -> void:
	_rng.seed = 777
	var peak := 0.0
	for i in 6:
		var b := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://Sound/footsteps/soft_%d.wav" % (i + 1)))
		for j in range(44, b.size() - 1, 2):
			peak = maxf(peak, absf(b.decode_s16(j) / 32768.0))
	peak = clampf(peak, 0.2, 0.95)
	for i in 6:
		_save_wav("wood_%d" % (i + 1), _wood_step(i), "res://Sound/footsteps/", peak)
		_save_wav("water_%d" % (i + 1), _water_step(), "res://Sound/footsteps/", peak * 0.9)
	for i in 3:
		_save_wav("squeak_%d" % (i + 1), _squeak(2 + i), SND, 0.6)
	for i in 2:
		_save_wav("wings_%d" % (i + 1), _wings(5 + i * 2), SND, 0.7)
	print("steps: ok (пик soft = %.2f)" % peak)


## Каблук по доске: глухой удар + резонансы доски + короткий щелчок
func _wood_step(v: int) -> PackedFloat32Array:
	var total := int(0.3 * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var modes := [_rng.randf_range(150, 200), _rng.randf_range(300, 380), _rng.randf_range(560, 680), _rng.randf_range(1000, 1250)]
	var res := []
	for i in modes.size():
		var f: float = modes[i]
		var r := exp(-PI * (25.0 + i * 25.0) / SR)
		res.append([2.0 * r * cos(TAU * f / SR), -r * r, 0.0, 0.0, 1.0 / (1.0 + i * 0.6)])
	var thump := Biquad.new("lp", 260.0, 0.8, SR)
	var click := Biquad.new("bp", 2600.0, 1.0, SR)
	# Носок догоняет пятку через 40–70 мс, тише
	var toe := int(_rng.randf_range(0.04, 0.07) * SR)
	for i in total:
		var t := float(i) / SR
		var exc := 0.0
		if i < 40:
			exc += _noise() * (1.0 - i / 40.0)
		if i >= toe and i < toe + 30:
			exc += _noise() * 0.45 * (1.0 - (i - toe) / 30.0)
		var y := 0.0
		for r in res:
			var s: float = r[0] * r[2] + r[1] * r[3] + exc
			r[3] = r[2]
			r[2] = s
			y += s * r[4]
		var th := thump.run(_noise()) * exp(-t / 0.03) * 6.0
		var cl := click.run(_noise()) * exp(-t / 0.004) * 0.8
		buf[i] = y * 0.08 + th + cl
	return _normalize(buf, 1.0)


## Шлепок по воде: всплеск с поднимающимся тоном, капли, глухой плеск
func _water_step() -> PackedFloat32Array:
	var total := int(0.45 * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var slosh := Biquad.new("lp", 280.0, 0.7, SR)
	var drops := []
	for i in _rng.randi_range(3, 6):
		drops.append([_rng.randf_range(0.03, 0.22), _rng.randf_range(900, 2400), _rng.randf_range(0.012, 0.03), _rng.randf_range(0.15, 0.5)])
	var bp := Biquad.new("bp", 700.0, 0.9, SR)
	for i in total:
		var t := float(i) / SR
		# Полоса всплеска ползёт вверх: фильтр пересчитывается каждые 64 сэмпла
		if i % 64 == 0:
			var f := lerpf(500.0, 1900.0, minf(t / 0.12, 1.0))
			var nb := Biquad.new("bp", f, 0.9, SR)
			nb.x1 = bp.x1; nb.x2 = bp.x2; nb.y1 = bp.y1; nb.y2 = bp.y2
			bp = nb
		var env := minf(t / 0.006, 1.0) * exp(-t / 0.07)
		var s := bp.run(_noise()) * env * 1.4
		s += slosh.run(_noise()) * exp(-t / 0.12) * 1.6
		for d in drops:
			var dt: float = t - d[0]
			if dt > 0.0 and dt < d[2] * 6.0:
				s += sin(TAU * d[1] * (1.0 + 0.6 * dt / (d[2] * 6.0)) * dt) * exp(-dt / d[2]) * d[3]
		buf[i] = s
	return _normalize(buf, 1.0)


## Взлёт птиц: частые хлопки крыльев, реже и тише к концу
func _wings(flaps: int) -> PackedFloat32Array:
	var total := int(1.2 * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var lp := Biquad.new("lp", 1500.0, 0.7, SR)
	var hp := Biquad.new("hp", 150.0, 0.7, SR)
	var t0 := 0.02
	var hits := []
	for i in flaps:
		hits.append([t0, 1.0 - 0.6 * float(i) / flaps])
		t0 += _rng.randf_range(0.07, 0.11) * (1.0 + 0.5 * float(i) / flaps)
	for i in total:
		var t := float(i) / SR
		var e := 0.0
		for h in hits:
			var dt: float = t - h[0]
			if dt > 0.0 and dt < 0.2:
				e += h[1] * minf(dt / 0.006, 1.0) * exp(-dt / 0.035)
		buf[i] = hp.run(lp.run(_noise() * e))
	return _normalize(buf, 1.0)


## Писк: несколько коротких свистов 3–5 кГц с вибрато
func _squeak(chirps: int) -> PackedFloat32Array:
	var total := int((0.08 + chirps * 0.11) * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for c in chirps:
		var start := int((0.02 + c * 0.11 + _rng.randf_range(-0.02, 0.02)) * SR)
		var dur := _rng.randf_range(0.05, 0.09)
		var f0 := _rng.randf_range(3200, 4800)
		var ph := 0.0
		var n := int(dur * SR)
		for k in n:
			if start + k >= total:
				break
			var x := float(k) / n
			var f := f0 * (1.0 + 0.12 * sin(PI * x)) + 180.0 * sin(TAU * 32.0 * k / SR)
			ph += f / SR
			buf[start + k] += sin(TAU * ph) * pow(sin(PI * x), 1.5) * _rng.randf_range(0.6, 1.0)
	return _normalize(buf, 1.0)


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


## Биквад (RBJ): тип "lp", "hp", "bp"
class Biquad:
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(kind: String, f: float, q: float, sr: float) -> void:
		var w := TAU * f / sr
		var c := cos(w)
		var al := sin(w) / (2.0 * q)
		var a0 := 1.0 + al
		match kind:
			"lp":
				b0 = (1.0 - c) / 2.0; b1 = 1.0 - c; b2 = (1.0 - c) / 2.0
			"hp":
				b0 = (1.0 + c) / 2.0; b1 = -(1.0 + c); b2 = (1.0 + c) / 2.0
			"bp":
				b0 = al; b1 = 0.0; b2 = -al
		a1 = -2.0 * c
		a2 = 1.0 - al
		b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0

	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		return y


## Медленная огибающая, которая сама замыкается на длине петли: сумма синусов
## с целым числом периодов на петлю
func _env_fn(length: float, seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var comps := []
	for i in 4:
		comps.append([r.randi_range(1 + i * 2, 3 + i * 3), r.randf() * TAU, 1.0 / (i + 1)])
	return comps


func _env(comps: Array, t: float, length: float) -> float:
	var s := 0.0
	var n := 0.0
	for c in comps:
		s += sin(TAU * c[0] * t / length + c[1]) * c[2]
		n += c[2]
	return s / n * 0.5 + 0.5


## Петля без щелчка: хвост длиной xf секунд подмешивается в начало
func _loopify(buf: PackedFloat32Array, xf: float) -> PackedFloat32Array:
	var n := int(xf * SR)
	var body := buf.size() - n
	var out := buf.slice(0, body)
	for i in n:
		var k := float(i) / n
		out[i] = out[i] * sqrt(k) + buf[body + i] * sqrt(1.0 - k)
	return out


func _river(length: float) -> PackedFloat32Array:
	var total := int((length + 1.0) * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var lp1 := Biquad.new("lp", 700.0, 0.7, SR)
	var lp2 := Biquad.new("lp", 900.0, 0.7, SR)
	var hiss := Biquad.new("bp", 1900.0, 0.6, SR)
	var hp := Biquad.new("hp", 60.0, 0.7, SR)
	var env := _env_fn(length, 11)
	# Пузыри и бульканье: короткие синусы с подъёмом тона
	var bubbles := []
	var t := 0.0
	while t < length + 1.0:
		t += -log(maxf(_rng.randf(), 0.0001)) / 22.0
		bubbles.append([t, _rng.randf_range(380.0, 1500.0), _rng.randf_range(0.008, 0.035), pow(_rng.randf(), 2.0) * 0.35 + 0.03, _rng.randf_range(0.2, 0.7)])
	var bi := 0
	var active := []
	for i in total:
		var tt := float(i) / SR
		var e := _env(env, fmod(tt, length), length)
		var n := _noise()
		var rush := lp2.run(lp1.run(n)) * (1.6 + 0.6 * e)
		var hs := hiss.run(_noise()) * (0.25 + 0.25 * e)
		while bi < bubbles.size() and bubbles[bi][0] <= tt:
			active.append(bubbles[bi])
			bi += 1
		var b := 0.0
		for j in range(active.size() - 1, -1, -1):
			var bb: Array = active[j]
			var dt: float = tt - bb[0]
			if dt > bb[2] * 6.0:
				active.remove_at(j)
				continue
			var f: float = bb[1] * (1.0 + bb[4] * dt / (bb[2] * 6.0))
			b += sin(TAU * f * dt) * exp(-dt / bb[2]) * bb[3]
		buf[i] = hp.run(rush + hs + b * (0.6 + 0.6 * e))
	return _normalize(buf, 0.7)


func _leaves(length: float) -> PackedFloat32Array:
	var total := int((length + 1.0) * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var hiss := Biquad.new("bp", 3800.0, 0.5, SR)
	var low := Biquad.new("bp", 900.0, 0.5, SR)
	var click := Biquad.new("bp", 3000.0, 1.2, SR)
	var env := _env_fn(length, 23)
	var crack := 0.0
	for i in total:
		var tt := float(i) / SR
		var g := _env(env, fmod(tt, length), length)
		g = g * g
		# Отдельные листья: редкие щелчки, чаще в порыв
		if _rng.randf() < (40.0 + 900.0 * g) / SR:
			crack = _rng.randf_range(0.3, 1.0)
		crack *= 0.993
		var c := click.run(_noise() * crack)
		buf[i] = hiss.run(_noise()) * (0.15 + 0.85 * g) + low.run(_noise()) * 0.25 * g + c * 0.9
	return _normalize(buf, 0.7)


func _swamp(length: float) -> PackedFloat32Array:
	var total := int((length + 1.0) * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	# Фон: тихая вода и воздух
	var lp := Biquad.new("lp", 400.0, 0.7, SR)
	for i in total:
		buf[i] = lp.run(_noise()) * 0.35
	# Лягушки: серия импульсов с гармониками, тон чуть падает к концу
	var voices := [[200.0, 15.0, 9, 0.9], [285.0, 21.0, 6, 0.7], [400.0, 27.0, 12, 0.45], [520.0, 34.0, 40, 0.18]]
	for v in voices:
		var t := _rng.randf_range(0.2, 2.5)
		while t < length - 2.0:
			var pulses: int = v[2] + _rng.randi_range(-2, 2)
			var f0: float = v[0] * _rng.randf_range(0.95, 1.05)
			for p in pulses:
				var pt: float = t + p / float(v[1])
				var pl: float = 0.55 / float(v[1])
				var f := f0 * (1.0 - 0.08 * float(p) / pulses)
				var amp: float = v[3] * _rng.randf_range(0.75, 1.0)
				var s0 := int(pt * SR)
				var n := int(pl * SR)
				for k in n:
					var idx := s0 + k
					if idx >= total:
						break
					var tk := float(k) / SR
					var w := sin(PI * float(k) / n)
					w *= w
					var x := sin(TAU * f * tk) + 0.8 * sin(TAU * 2.0 * f * tk) + 0.45 * sin(TAU * 3.0 * f * tk) + 0.2 * sin(TAU * 4.0 * f * tk)
					buf[idx] += x * w * amp * 0.5
			t += pulses / float(v[1]) + _rng.randf_range(1.2, 4.5)
	# Мухи: два пролёта с допплером
	for fly in 2:
		var start := _rng.randf_range(1.0, length - 5.0)
		var dur := _rng.randf_range(2.2, 3.4)
		var base := _rng.randf_range(185.0, 235.0)
		var bp := Biquad.new("bp", 700.0, 0.6, SR)
		var ph := 0.0
		var s0 := int(start * SR)
		var n := int(dur * SR)
		for k in n:
			var x := float(k) / n
			var amp := pow(sin(PI * x), 2.0)
			var f := base * (1.06 - 0.12 * x) + 7.0 * sin(TAU * 5.5 * k / SR)
			ph += f / SR
			var saw := fmod(ph, 1.0) * 2.0 - 1.0
			buf[s0 + k] += bp.run(saw) * amp * 0.35
	return _normalize(buf, 0.7)


func _cloth(length: float) -> PackedFloat32Array:
	var total := int((length + 1.0) * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var base := Biquad.new("bp", 550.0, 0.5, SR)
	var flap_lp := Biquad.new("lp", 1300.0, 0.8, SR)
	var flap_hp := Biquad.new("hp", 120.0, 0.7, SR)
	var env := _env_fn(length, 37)
	var flaps := []
	var t := 0.3
	while t < length + 1.0:
		var g := _env(env, fmod(t, length), length)
		t += _rng.randf_range(0.18, 0.5) / (0.4 + g)
		var a := _rng.randf_range(0.4, 1.0) * (0.4 + 0.6 * g)
		flaps.append([t, a, _rng.randf_range(0.035, 0.09)])
		if _rng.randf() < 0.35:
			flaps.append([t + _rng.randf_range(0.05, 0.09), a * 0.6, 0.04])
	flaps.sort_custom(func(p, q): return p[0] < q[0])
	var fi := 0
	var active := []
	for i in total:
		var tt := float(i) / SR
		var g := _env(env, fmod(tt, length), length)
		while fi < flaps.size() and flaps[fi][0] <= tt:
			active.append(flaps[fi])
			fi += 1
		var e := 0.0
		for j in range(active.size() - 1, -1, -1):
			var f: Array = active[j]
			var dt: float = tt - f[0]
			if dt > f[2] * 6.0:
				active.remove_at(j)
				continue
			var att := minf(dt / 0.004, 1.0)
			e += f[1] * att * exp(-dt / f[2])
		var n := _noise()
		buf[i] = flap_hp.run(flap_lp.run(n * e)) + base.run(_noise()) * 0.12 * g
	return _normalize(buf, 0.7)


## Скрип: трение «прилипание-срыв» — серия толчков с меняющейся частотой
## раскачивает несколько резонансов дерева
func _creak(dur: float, freqs: Array, rate0: float, rate1: float) -> PackedFloat32Array:
	var total := int((dur + 0.25) * SR)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var res := []
	for i in freqs.size():
		var f: float = freqs[i]
		var bw := 70.0 + f * 0.05
		var r := exp(-PI * bw / SR)
		res.append([2.0 * r * cos(TAU * f / SR), -r * r, 0.0, 0.0, 1.0 / (i + 1.0)])
	var next := 0.0
	var hp := Biquad.new("hp", 90.0, 0.7, SR)
	for i in total:
		var tt := float(i) / SR
		var x := clampf(tt / dur, 0.0, 1.0)
		var exc := 0.0
		if tt < dur and tt >= next:
			var rate := lerpf(rate0, rate1, sin(PI * x))
			next = tt + (1.0 / rate) * _rng.randf_range(0.85, 1.15)
			exc = pow(sin(PI * x), 0.6) * _rng.randf_range(0.7, 1.0)
		var y := 0.0
		for r in res:
			var v: float = r[0] * r[2] + r[1] * r[3] + exc
			r[3] = r[2]
			r[2] = v
			y += v * r[4]
		buf[i] = hp.run(y)
	# Мягкий выход
	var fade := int(0.05 * SR)
	for i in fade:
		buf[total - 1 - i] *= float(i) / fade
	return _normalize(buf, 0.75)


func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in buf:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in buf.size():
		buf[i] *= k
	return buf


func _save_wav(name: String, buf: PackedFloat32Array, dir: String = SND, peak: float = -1.0) -> void:
	if peak > 0.0:
		buf = _normalize(buf, peak)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)  # RIFF
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)  # WAVE
	h.encode_u32(12, 0x20746d66)  # fmt
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 1)
	h.encode_u32(24, SR)
	h.encode_u32(28, SR * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)  # data
	h.encode_u32(40, data.size())
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + name + ".wav"), FileAccess.WRITE)
	f.store_buffer(h)
	f.store_buffer(data)
	f.close()
	print("  ", name, ".wav ", "%.1f" % (float(buf.size()) / SR), " c")
