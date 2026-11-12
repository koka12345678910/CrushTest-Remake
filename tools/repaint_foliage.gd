extends SceneTree
## Перерисовка листвы в атласе деревьев присланной карты.
##
## В исходном autumn_trees.png крона — случайные пиксели трёх цветов без
## объёма: вблизи это читается как шум, а не как листва. Скрипт оставляет
## силуэт и ствол дерева, а крону собирает заново:
##   - цвет усредняется до сгустков (шум уходит, тёмные и светлые участки
##     исходника остаются);
##   - объём: свет сверху-слева по форме кроны и по её сгусткам;
##   - листва собрана из округлых пучков: у каждого свой свет и тень, между
##     пучками тёмные щели;
##   - палитра: тень — тёмно-багровая, середина — рыжая, свет — золотой;
##   - край кроны идёт по листьям, а не по квадратным ступенькам.
##
## Запуск:
##   godot --headless --path . -s res://tools/repaint_foliage.gd -- <исходник.png> <результат.png> [x,y,w,h|all] [autumn|green] [размер пучка]
## Деревья: без необязательных аргументов. Кусты из autumn_decorations.png:
##   ... -- <исходник> <результат> 40,430,730,160 green 8
## Размер и расположение деревьев в атласе не меняются, поэтому карту править
## не нужно — достаточно положить результат на место текстуры и переимпортировать.

var W := 0
var H := 0
## Размер пучка листвы в пикселях атласа (на карте вдвое меньше)
var TUFT := 12


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src := Image.load_from_file(args[0])
	# Необязательные: область "x,y,w,h" (вне её атлас не трогается), палитра
	# autumn или green, размер пучка листвы
	var region := Rect2i(0, 0, 1 << 20, 1 << 20)
	if args.size() > 2 and args[2] != "all":
		var p := args[2].split(",")
		region = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
	var green: bool = args.size() > 3 and args[3] == "green"
	if args.size() > 4:
		TUFT = int(args[4])
	src.convert(Image.FORMAT_RGBA8)
	W = src.get_width()
	H = src.get_height()

	# ── маски: листва и ствол ──
	var fol := Image.create(W, H, false, Image.FORMAT_RGBA8)     # цвет листвы, альфа = листва
	var mask := Image.create(W, H, false, Image.FORMAT_RGBA8)    # r = непрозрачно, g = ствол
	var trunk := PackedByteArray()
	trunk.resize(W * H)
	for y in H:
		for x in W:
			if not region.has_point(Vector2i(x, y)):
				continue
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var is_trunk := (not green) and c.s < 0.33 and c.v > 0.22
			if c.h > 0.45 and c.h < 0.8 and c.s > 0.15:
				is_trunk = true          # синеватые тени берёз
			if is_trunk:
				trunk[y * W + x] = 1
				mask.set_pixel(x, y, Color(1, 1, 0, 1))
			else:
				fol.set_pixel(x, y, Color(c.r, c.g, c.b, 1))
				mask.set_pixel(x, y, Color(1, 0, 0, 1))

	fol.premultiply_alpha()
	var low := _blur(fol, 3)       # сгустки цвета
	var wide := _blur(fol, 6)      # средний цвет дерева
	var dome := _blur(mask, 5)     # форма кроны
	var dome2 := _blur(mask, 3)    # форма крупных ветвей
	var soft := _blur(mask, 2)     # мягкий край и плотность ствола

	# ── пучки листвы: точки на сетке со случайным сдвигом ──
	var gw: int = W / TUFT + 2
	var gh: int = H / TUFT + 2
	var fx := PackedFloat32Array(); fx.resize(gw * gh)
	var fy := PackedFloat32Array(); fy.resize(gw * gh)
	var fr := PackedFloat32Array(); fr.resize(gw * gh)
	var fin := PackedByteArray(); fin.resize(gw * gh)     # пучок растёт из кроны
	for gy in gh:
		for gx in gw:
			var gi := gy * gw + gx
			fx[gi] = (gx + 0.15 + 0.7 * _hash(gx, gy)) * TUFT
			fy[gi] = (gy + 0.15 + 0.7 * _hash(gx + 71, gy + 13)) * TUFT
			fr[gi] = _hash(gx + 5, gy + 131)
			fin[gi] = 1 if _r(soft, int(fx[gi]), int(fy[gi])) > 0.42 else 0

	var deep := Color(0.15, 0.04, 0.04)
	var crimson := Color(0.47, 0.11, 0.05)
	var rust := Color(0.80, 0.33, 0.08)
	var gold := Color(0.98, 0.68, 0.2)
	var own_mix := 0.32
	var lit_k := 0.62
	var lit_base := 0.47
	if green:
		# Кусты: тёмная зелень с оливковым светом
		deep = Color(0.04, 0.065, 0.04)
		crimson = Color(0.09, 0.15, 0.07)
		rust = Color(0.2, 0.28, 0.11)
		gold = Color(0.4, 0.45, 0.19)
		own_mix = 0.1
		# Куст маленький: тень от формы слабее, иначе полкуста уходит в черноту
		lit_k = 0.3
		lit_base = 0.52
	var light := Vector2(-0.55, -0.83)      # откуда свет

	var warp := FastNoiseLite.new()
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.frequency = 0.16
	warp.seed = 11

	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var painted := 0
	for y in H:
		for x in W:
			if not region.has_point(Vector2i(x, y)):
				out.set_pixel(x, y, src.get_pixel(x, y))
				continue
			var i := y * W + x
			var sm := soft.get_pixel(x, y)
			if sm.r < 0.02:
				continue
			# Ствол остаётся, где он идёт сплошь (ниже кроны); одиночные серые
			# пиксели внутри кроны закрываются листвой
			if trunk[i] == 1 and sm.g > 0.45:
				out.set_pixel(x, y, src.get_pixel(x, y))
				continue
			# Ближайший пучок, растущий из кроны
			# Координаты слегка искажены шумом — края пучков рваные, как листва
			var px: float = x + warp.get_noise_2d(x, y) * 3.2
			var py: float = y + warp.get_noise_2d(x + 300.0, y) * 3.2
			var gx0: int = int(px) / TUFT
			var gy0: int = int(py) / TUFT
			var best := 1e9
			var second := 1e9
			var bi := -1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cx: int = gx0 + dx
					var cy: int = gy0 + dy
					if cx < 0 or cy < 0 or cx >= gw or cy >= gh:
						continue
					var gi2 := cy * gw + cx
					if fin[gi2] == 0:
						continue
					var ddx: float = px - fx[gi2]
					var ddy: float = (py - fy[gi2]) * 1.15
					var d := ddx * ddx + ddy * ddy
					if d < best:
						second = best
						best = d
						bi = gi2
					elif d < second:
						second = d
			if bi == -1:
				continue
			var dist := sqrt(best)
			# Край кроны — по округлым пучкам
			var rad: float = TUFT * (0.62 + 0.3 * fr[bi])
			if sm.r < 0.5 and dist > rad:
				continue
			if sm.r < 0.12:
				continue
			var lw := low.get_pixel(x, y)
			var wd := wide.get_pixel(x, y)
			if wd.a < 0.01:
				continue
			var avg := Color(wd.r / wd.a, wd.g / wd.a, wd.b / wd.a)
			var base := avg
			if lw.a > 0.05:
				base = Color(lw.r / lw.a, lw.g / lw.a, lw.b / lw.a)
			var rel: float = base.get_luminance() / maxf(avg.get_luminance(), 0.04)
			# Объём пучка: его левый верх на свету, правый низ в тени
			var nrm := Vector2(px - fx[bi], (py - fy[bi]) * 1.15) / (TUFT * 0.8)
			var tuft_l: float = clampf(nrm.dot(light), -1.0, 1.0)
			# Объём кроны и крупных ветвей
			var lit: float = 3.4 * (_r(dome, x + 16, y + 24) - _r(dome, x - 16, y - 24))
			lit += 1.5 * (_r(dome2, x + 5, y + 8) - _r(dome2, x - 5, y - 8))
			var t: float = lit_base + 0.24 * tuft_l + lit_k * clampf(lit, -0.7, 0.7)
			t += 0.28 * (rel - 1.0) + 0.14 * (fr[bi] - 0.5) + 0.07 * warp.get_noise_2d(x * 3.0, y * 3.0)
			# Часть пучков — провалы вглубь кроны: без них поверхность плоская
			if fr[bi] < 0.13:
				t -= 0.3
			# Щель между пучками — глубокая тень
			var edge: float = sqrt(second) - dist
			if edge < 1.6:
				t -= 0.16 * (1.0 - edge / 1.6)
			t = clampf(t, 0.0, 1.0)
			var pal: Color
			if t < 0.3:
				pal = deep.lerp(crimson, t / 0.3)
			elif t < 0.64:
				pal = crimson.lerp(rust, (t - 0.3) / 0.34)
			else:
				pal = rust.lerp(gold, (t - 0.64) / 0.36)
			# Свой тон дерева и пучка: часть пучков желтее, часть краснее
			var k: float = 0.65 + 0.7 * t
			var own := Color(base.r * k, base.g * k, base.b * k)
			var col := pal.lerp(own, own_mix)
			var warm: float = (fr[bi] - 0.5) * 0.16
			col = Color(clampf(col.r + warm * 0.3, 0, 1), clampf(col.g + warm, 0, 1), col.b)
			out.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
			painted += 1

	var err := out.save_png(args[1])
	print("[repaint_foliage] %dx%d, перерисовано %d пикселей листвы, сохранено в %s (%s)" % [W, H, painted, args[1], error_string(err)])
	quit(0 if err == OK else 1)


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 1000) / 1000.0


func _r(img: Image, x: int, y: int) -> float:
	return img.get_pixel(clampi(x, 0, W - 1), clampi(y, 0, H - 1)).r


## Размытие через уменьшение вдвое levels раз и возврат к размеру
func _blur(img: Image, levels: int) -> Image:
	var b := img.duplicate() as Image
	for i in levels:
		b.resize(maxi(b.get_width() / 2, 1), maxi(b.get_height() / 2, 1), Image.INTERPOLATE_BILINEAR)
	b.resize(W, H, Image.INTERPOLATE_CUBIC)
	return b
