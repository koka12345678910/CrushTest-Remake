extends SceneTree
## tools/build_knight_run_swing.gd — по нарисованному в кадрах следу меча
## находит, когда и как идёт главный взмах удара рыцаря на бегу (MeleeRun.png),
## и пишет таблицу в Player_scene/knight_run_swing_data.gd (её читает
## player.gd::play_running_hit_vfx: дуга идёт ровно со взмахом на спрайте, в
## каждом из 8 направлений). Тот же приём, что у Сигрид
## (tools/build_sigrid_swings.gd), с двумя отличиями:
##   - броня рыцаря сама светло-серая — след ищем только дальше тела от груди
##     (MIN_R), там брони нет;
##   - в клипе несколько взмахов (короткий замах, потом большой финальный) —
##     берём самую "тяжёлую" непрерывную серию кадров со следом.
## Запуск (из корня проекта):
##   Godot --headless --path . --script res://tools/build_knight_run_swing.gd

const SHEET := "res://Character/CharacterAnimationAssets/Knight_Character/MELEE/MeleeRun.png"
const OUT := "res://Player_scene/knight_run_swing_data.gd"
const DIRS := ["Right", "Down_Right", "Down", "Down_Left", "Left", "Up_Left", "Up", "Up_Right"]
## Кадров/с клипов Run_Attack_* по направлениям (player.tscn, AnimationPlayer)
const FPS := {"Right": 18.0, "Down_Right": 18.0, "Down": 15.0, "Down_Left": 19.0,
		"Left": 18.0, "Up_Left": 18.0, "Up": 18.0, "Up_Right": 18.0}
## Грудь рыцаря в кадре 128x128 (KnightFx.CHEST = (0, -6) в мире)
const SCALE := Vector2(0.640625, 0.78125)
const CHEST := Vector2(64, 64) + Vector2(0, -6) / SCALE
## Сплющенность дуги по вертикали (3/4 вид), как у knight_slash.gd
const SQUASH := 0.62
## След ближе к груди не учитываем (пиксели мира, в "круглом" пространстве) —
## там светлая броня самого рыцаря
const MIN_R := 20.0


func _smear(c: Color) -> bool:
	var lo := minf(c.r, minf(c.g, c.b))
	var hi := maxf(c.r, maxf(c.g, c.b))
	return c.a > 0.15 and lo > 0.62 and hi - lo < 0.14


func _init() -> void:
	var img := Image.load_from_file(SHEET)
	img.convert(Image.FORMAT_RGBA8)
	var data := {}
	for row in DIRS.size():
		var dir_name: String = DIRS[row]
		var fps: float = FPS[dir_name]
		var frames := []
		var counts := []
		for f in 15:
			var pts := []
			for y in range(0, 128, 2):
				for x in range(0, 128, 2):
					if _smear(img.get_pixel(f * 128 + x, row * 128 + y)):
						var d := (Vector2(x, y) - CHEST) * SCALE
						var r := Vector2(d.x, d.y / SQUASH).length()
						if r >= MIN_R:
							pts.append(Vector2(atan2(d.y / SQUASH, d.x), r))
			frames.append(pts)
			counts.append(pts.size())
		var sorted := counts.duplicate()
		sorted.sort()
		var thr := maxf(12.0, sorted[4] * 2.5)
		# Непрерывные серии кадров со следом; главный взмах — с наибольшей суммой
		var best := []
		var best_sum := 0
		var run := []
		var run_sum := 0
		for f in 16:
			if f < 15 and counts[f] >= thr:
				run.append(f)
				run_sum += counts[f]
			else:
				if run_sum > best_sum:
					best = run.duplicate()
					best_sum = run_sum
				run = []
				run_sum = 0
		print(dir_name, " counts=", counts, " thr=", thr, " main=", best)
		if best.is_empty():
			continue
		var means := []
		var all_pts := []
		for f in best:
			var s := Vector2.ZERO
			for p in frames[f]:
				s += Vector2.from_angle(p.x)
				all_pts.append(p)
			means.append(s.angle())
		# Хвостовые кадры, где след уже не движется, а только гаснет, —
		# не взмах: дуга иначе висела бы дольше самого удара
		while means.size() > 2 and absf(angle_difference(means[-2], means[-1])) < deg_to_rad(8.0):
			means.pop_back()
			best.pop_back()
		all_pts = []
		for f in best:
			all_pts.append_array(frames[f])
		var sweep := 0.0
		for i in range(1, means.size()):
			sweep += angle_difference(means[i - 1], means[i])
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
		var lo: float = offs[int(offs.size() * 0.08)]
		var hi: float = offs[int(offs.size() * 0.92)]
		var dirs := signf(sweep)
		if dirs == 0.0:
			dirs = 1.0
		data[dir_name] = {
			"t0": snappedf(best[0] / fps, 0.001),
			"t1": snappedf((best[-1] + 1) / fps, 0.001),
			"from": snappedf(mid_a + (lo if dirs > 0.0 else hi), 0.001),
			"to": snappedf(mid_a + (hi if dirs > 0.0 else lo), 0.001),
			"radius": snappedf(radii[radii.size() / 2], 0.1),
			"means": means.map(func(a): return snappedf(rad_to_deg(a), 1.0)),
		}
		print("   ", data[dir_name])

	if OS.get_cmdline_user_args().has("--dry"):
		quit()
		return
	for k in data:
		data[k].erase("means")
	var txt := "extends RefCounted\n"
	txt += "## Сгенерировано tools/build_knight_run_swing.gd — не править руками.\n"
	txt += "## Главный взмах удара рыцаря на бегу по кадрам MeleeRun.png: [направление] ->\n"
	txt += "## t0/t1 — начало и конец взмаха (с от старта клипа), from/to — откуда и\n"
	txt += "## куда идёт дуга (угол в \"круглом\" пространстве дуги, сплющенность\n"
	txt += "## %.2f), radius — расстояние следа от груди в пикселях мира\n" % SQUASH
	txt += "const DATA := " + var_to_str(data) + "\n"
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(txt)
	file.close()
	quit()
