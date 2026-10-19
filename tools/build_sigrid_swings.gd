extends SceneTree
## tools/build_sigrid_swings.gd — по нарисованному в кадрах следу меча
## находит, когда и как идёт каждый взмах Сигрид, и пишет таблицу в
## Player_scene/sigrid_swing_data.gd (её читает archer.gd: дуги клинка и окна
## удара идут ровно со взмахом на спрайте, в каждом из 8 направлений).
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/build_sigrid_swings.gd
##
## След меча — почти белые, ненасыщенные пиксели. Кадр со следом = кадр взмаха.
## По пикселям следа: в каких кадрах он есть, в какую сторону по кругу
## движется его центр (направление взмаха), какой угол он охватывает всего и
## на каком расстоянии от груди лежит.

const SRC := "res://Character/Archer/Sigrid/"
const OUT := "res://Player_scene/sigrid_swing_data.gd"
const DIRS := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]
## Листы взмахов и их скорость в анимации (см. build_sigrid_anims.gd)
const SHEETS := {"Attack1": 25.0, "Attack6": 20.0, "Attack4": 25.0, "Attack2": 25.0, "AttackRun": 25.0}
## Грудь Сигрид в кадре 128x128 — центр дуг
const CHEST := Vector2(64, 62)
## Масштаб спрайта лучницы (archer.tscn) — перевод пикселей кадра в мир
const SCALE := Vector2(0.8125, 0.84375)
## Сплющенность дуги по вертикали (3/4 вид), как у knight_slash.gd
const SQUASH := 0.62
## След ближе к груди не учитываем (пиксели мира, в "круглом" пространстве)
const MIN_R := 14.0


func _smear(c: Color) -> bool:
	var lo := minf(c.r, minf(c.g, c.b))
	var hi := maxf(c.r, maxf(c.g, c.b))
	return c.a > 0.15 and lo > 0.62 and hi - lo < 0.14


func _init() -> void:
	var data := {}
	for sheet: String in SHEETS:
		var fps: float = SHEETS[sheet]
		var img := Image.load_from_file(SRC + sheet + ".png")
		img.convert(Image.FORMAT_RGBA8)
		var per_dir := {}
		for row in DIRS.size():
			# пиксели следа по кадрам: [угол, радиус] в мировых единицах
			var frames := []
			var counts := []
			for f in 15:
				var pts := []
				for y in range(0, 128, 2):
					for x in range(0, 128, 2):
						if _smear(img.get_pixel(f * 128 + x, row * 128 + y)):
							var d := (Vector2(x, y) - CHEST) * SCALE
							var r := Vector2(d.x, d.y / SQUASH).length()
							# Ближе MIN_R к груди — блики на одежде и рука, не след клинка
							if r >= MIN_R:
								pts.append(Vector2(atan2(d.y / SQUASH, d.x), r))
				frames.append(pts)
				counts.append(pts.size())
			var sorted := counts.duplicate()
			sorted.sort()
			var thr := maxf(15.0, sorted[7] * 2.5)
			var hit_frames := []
			for f in 15:
				if counts[f] >= thr:
					hit_frames.append(f)
			if hit_frames.is_empty():
				continue
			# Центр следа по кругу в каждом кадре взмаха (среднее по кругу)
			var means := []
			var all_pts := []
			for f in hit_frames:
				var s := Vector2.ZERO
				for p in frames[f]:
					s += Vector2.from_angle(p.x)
					all_pts.append(p)
				means.append(s.angle())
			var ref: float = means[0]
			var sweep := 0.0
			for i in range(1, means.size()):
				sweep += angle_difference(means[i - 1], means[i])
			# Охват: все углы следа относительно середины
			var mid := Vector2.ZERO
			for p in all_pts:
				mid += Vector2.from_angle(p.x)
			var mid_a := mid.angle()
			var offs := []
			var radii := []
			for p in all_pts:
				offs.append(angle_difference(mid_a, p.x))
				radii.append(p.y)
			offs.sort()
			radii.sort()
			# Охват без крайних выбросов — с 8% по 92% углов следа
			var lo: float = offs[int(offs.size() * 0.08)]
			var hi: float = offs[int(offs.size() * 0.92)]
			# Взмах идёт туда же, куда сдвигается центр следа. Если кадр один —
			# по тому, с какой стороны от середины след плотнее
			var dirs := signf(sweep)
			if dirs == 0.0:
				dirs = 1.0 if angle_difference(mid_a, ref) < 0.0 else -1.0
			var a_from := mid_a + (lo if dirs > 0.0 else hi)
			var a_to := mid_a + (hi if dirs > 0.0 else lo)
			per_dir[DIRS[row]] = {
				"t0": hit_frames[0] / fps,
				"t1": (hit_frames[-1] + 1) / fps,
				"from": snappedf(a_from, 0.001),
				"to": snappedf(a_to, 0.001),
				"radius": snappedf(radii[radii.size() / 2], 0.1),
			}
		data[sheet] = per_dir

	var txt := "extends RefCounted\n"
	txt += "## Сгенерировано tools/build_sigrid_swings.gd — не править руками.\n"
	txt += "## Взмахи меча Сигрид по кадрам спрайтов: [лист][направление] ->\n"
	txt += "## t0/t1 — начало и конец взмаха (с от старта клипа), from/to — откуда и\n"
	txt += "## куда идёт дуга (угол в \"круглом\" пространстве дуги, сплющенность\n"
	txt += "## %.2f), radius — расстояние следа от груди в пикселях мира\n" % SQUASH
	txt += "const DATA := " + var_to_str(data) + "\n"
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	for sheet in data:
		print(sheet, ": ", data[sheet].get("Right", {}), " | Down ", data[sheet].get("Down", {}))
	quit()
