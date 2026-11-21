extends SceneTree
## tools/repair_clipped.gd — чинит оружие, обрезанное краем ячейки 128 px.
##
## В паке "2D HD Enemy pack 1" у молотобойца головка молота часто выходит за
## кадр рендера и срезана (это видно и в отдельных кадрах в Downloads — значит,
## срезано ещё при рендере). Растворение края тут не годится: получилась бы
## полупрозрачная половина молота. Поэтому:
##   1. Каждый лист копируется с увеличенной ячейкой (128 -> 128 + 2*PAD),
##      рисунок по центру — выравнивание спрайта в игре не меняется.
##   2. В кадре, где серая металлическая деталь (головка) упирается в край,
##      ищется кадр ТОГО ЖЕ направления (камера та же — молот выглядит так же),
##      где такая же деталь целиком внутри, и совмещается с видимым куском.
##   3. Недостающая часть дописывается в новые поля настоящими пикселями
##      из того кадра. Пиксели внутри исходной ячейки не меняются.
##   4. Всё остальное, что касалось края (след удара, кончик древка), плавно
##      растворяется, как в build_enemy_anims.gd --clean.
## Отчёт по каждому кадру печатается; кадры с плохим совпадением помечены "??".
##
## Запуск:
##   Godot --headless --path . --script res://tools/repair_clipped.gd -- \
##       <src_dir> <out_dir> <Sheet1,Sheet2,...> [Лист:ряд:кадр,...]
## Листы — имена без "_Shadowless.png". Ссылки на кадры-доноры берутся из
## всех перечисленных листов. Четвёртый аргумент — кадры, где дорисовка
## проверена глазами и признана плохой (головка смазана внутри следа удара,
## донора нет): там срез только растворяется.
##
## Молотобоец (enemy/humans/hammer):
##   ... -- res://enemys/1Hammer/ res://enemy/humans/hammer/sheets/ \
##       Attack1,Attack3,Attack4,Die,Idle,Idle2,TakeDamage,Walk,Run Attack3:2:9,Attack3:2:11

const CELL := 128
const PAD := 16
const OUT := CELL + PAD * 2
const FEATHER := 8
## Пиксель металла: почти непрозрачный, серый (без насыщенности), средней яркости
const MIN_A := 0.8
const MAX_SAT := 0.12
const MIN_LUM := 0.18
const MAX_LUM := 0.72
## Минимальное совпадение формы видимого куска с донором (IoU внутри ячейки)
const GOOD_SCORE := 0.6

var sheets := {}        # name -> Image (RGBA8, исходный)
var masks := {}         # "name/r/c" -> PackedByteArray маски металла 128x128
var skip := {}          # "Лист:ряд:кадр" — не дорисовывать, только растворить


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("нужно: <src_dir> <out_dir> <Sheet1,Sheet2,...>")
		quit(1)
		return
	var src: String = a[0]
	var out: String = a[1]
	var names := a[2].split(",")
	if a.size() > 3:
		for s in a[3].split(","):
			skip[s] = true
	for n in names:
		var img := (load(src + n + "_Shadowless.png") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		sheets[n] = img
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var total_fixed := 0
	var total_weak := 0
	for n in names:
		var res := _process_sheet(n)
		total_fixed += res[0]
		total_weak += res[1]
		(res[2] as Image).save_png(ProjectSettings.globalize_path(out + n + "_Shadowless.png"))
	print("ГОТОВО: дорисовано кадров %d, слабых совпадений %d" % [total_fixed, total_weak])
	quit()


func _is_metal(c: Color) -> bool:
	return c.a >= MIN_A and c.s <= MAX_SAT and c.v >= MIN_LUM and c.get_luminance() <= MAX_LUM and c.get_luminance() >= MIN_LUM


func _mask(n: String, r: int, c: int) -> PackedByteArray:
	var key := "%s/%d/%d" % [n, r, c]
	if masks.has(key):
		return masks[key]
	var img: Image = sheets[n]
	var m := PackedByteArray()
	m.resize(CELL * CELL)
	for y in CELL:
		for x in CELL:
			if _is_metal(img.get_pixel(c * CELL + x, r * CELL + y)):
				m[y * CELL + x] = 1
	masks[key] = m
	return m


var comp_cache := {}

## Детали металла кадра. Близкие куски (зазор до GROUP_GAP px) объединяются:
## головка, повёрнутая торцом, видна как 2-3 отдельных блока, и искать донора
## для каждого блока отдельно — значит собрать мешанину из разных головок
const GROUP_GAP := 5

func _comps_cached(n: String, r: int, c: int) -> Array:
	var key := "%s/%d/%d" % [n, r, c]
	if not comp_cache.has(key):
		var parts := []
		for comp in _components(_mask(n, r, c)):
			if comp.size() >= 3:
				parts.append(comp)
		var merged := true
		while merged:
			merged = false
			for i in parts.size():
				for j in range(i + 1, parts.size()):
					if _bbox(parts[i]).grow(GROUP_GAP).intersects(_bbox(parts[j])):
						var joined: PackedInt32Array = parts[i]
						joined.append_array(parts[j])
						parts[i] = joined
						parts.remove_at(j)
						merged = true
						break
				if merged:
					break
		var list := []
		for g in parts:
			if (g as PackedInt32Array).size() >= 8:
				list.append(g)
		comp_cache[key] = list
	return comp_cache[key]


## Связные области маски (8-связность): массив PackedInt32Array индексов
func _components(m: PackedByteArray) -> Array:
	var seen := PackedByteArray()
	seen.resize(CELL * CELL)
	var comps := []
	for i in CELL * CELL:
		if m[i] == 0 or seen[i] == 1:
			continue
		var comp := PackedInt32Array()
		var stack := PackedInt32Array([i])
		seen[i] = 1
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			comp.append(p)
			var px := p % CELL
			var py := p / CELL
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := px + dx
					var ny := py + dy
					if nx < 0 or ny < 0 or nx >= CELL or ny >= CELL:
						continue
					var q := ny * CELL + nx
					if m[q] == 1 and seen[q] == 0:
						seen[q] = 1
						stack.append(q)
		comps.append(comp)
	return comps


func _touches_edge(comp: PackedInt32Array) -> bool:
	for p in comp:
		var x := p % CELL
		var y := p / CELL
		if x == 0 or y == 0 or x == CELL - 1 or y == CELL - 1:
			return true
	return false


func _bbox(comp: PackedInt32Array) -> Rect2i:
	var x0 := CELL
	var y0 := CELL
	var x1 := -1
	var y1 := -1
	for p in comp:
		var x := p % CELL
		var y := p / CELL
		x0 = mini(x0, x)
		y0 = mini(y0, y)
		x1 = maxi(x1, x)
		y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Возвращает [дорисовано кадров, слабых, новый лист]
func _process_sheet(n: String) -> Array:
	var img: Image = sheets[n]
	var cols := img.get_width() / CELL
	var rows := img.get_height() / CELL
	var dst := Image.create(cols * OUT, rows * OUT, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	var fixed := 0
	var weak := 0
	for r in rows:
		for c in cols:
			dst.blit_rect(img, Rect2i(c * CELL, r * CELL, CELL, CELL), Vector2i(c * OUT + PAD, r * OUT + PAD))
			var cut_parts := []
			if not skip.has("%s:%d:%d" % [n, r, c]):
				for grp in _comps_cached(n, r, c):
					if _touches_edge(grp):
						cut_parts.append(grp)
			var notes := []
			var protect := PackedByteArray()
			protect.resize(CELL * CELL)
			for part in cut_parts:
				var best := _find_donor(n, r, c, part)
				if best.is_empty():
					notes.append("нет донора")
					weak += 1
					continue
				for p in part:
					protect[p] = 1
				var added := _paste(dst, n, r, c, best)
				var tag := "" if best["score"] >= GOOD_SCORE else " ??"
				if tag != "":
					weak += 1
				notes.append("%s#%d d=%s iou=%.2f join=%.2f +%dpx%s" % [best["sheet"], best["col"], best["d"], best["iou"], best["join"], added, tag])
				fixed += 1
			_feather_rest(dst, c * OUT, r * OUT, protect)
			if not notes.is_empty():
				print("%s r%d f%d: %s" % [n, r, c, "; ".join(notes)])
	return [fixed, weak, dst]


## Лучший донор: кадр того же направления (строка r) любого листа, где металл
## целиком внутри и после сдвига на d совпадает с видимым куском
func _find_donor(n: String, r: int, c: int, part: PackedInt32Array) -> Dictionary:
	var target := PackedByteArray()
	target.resize(CELL * CELL)
	for p in part:
		target[p] = 1
	var tb := _bbox(part)
	# Какой стороной срезан кусок: вдоль среза размер донора должен совпасть
	var cut_x := tb.position.x == 0 or tb.end.x == CELL
	var cut_y := tb.position.y == 0 or tb.end.y == CELL
	# Пиксели куска на самой границе ячейки и направление "наружу" — по ним
	# проверяется стык: дорисовка должна продолжать именно их
	var edge_px: Array[Vector2i] = []
	var edge_out: Array[Vector2i] = []
	for p in part:
		var x := p % CELL
		var y := p / CELL
		var o := Vector2i(-1 if x == 0 else (1 if x == CELL - 1 else 0), -1 if y == 0 else (1 if y == CELL - 1 else 0))
		if o != Vector2i.ZERO:
			edge_px.append(Vector2i(x, y))
			edge_out.append(o)
	var best := {}
	var best_score := 0.0
	for sn in sheets:
		var cols: int = (sheets[sn] as Image).get_width() / CELL
		for dc in cols:
			if sn == n and dc == c:
				continue
			for comp in _comps_cached(sn, r, dc):
				if comp.size() < part.size() or comp.size() > part.size() * 4 or _touches_edge(comp):
					continue
				var cb := _bbox(comp)
				# Донор должен быть не меньше видимого куска
				if cb.size.x + 2 < tb.size.x or cb.size.y + 2 < tb.size.y:
					continue
				# Срез только сверху/снизу — ширина та же; только слева/справа — высота
				if cut_y and not cut_x and absi(cb.size.x - tb.size.x) > 3:
					continue
				if cut_x and not cut_y and absi(cb.size.y - tb.size.y) > 3:
					continue
				var res := _best_offset(comp, cb, target, tb, part.size(), edge_px, edge_out)
				if res["score"] > best_score:
					best_score = res["score"]
					best = {"sheet": sn, "row": r, "col": dc, "comp": comp, "d": res["d"], "score": res["score"], "iou": res["iou"], "join": res["join"]}
	return best


## Оценка сдвига: 60% — совпадение формы внутри ячейки (IoU), 40% — стык
## (доля граничных пикселей куска, которые донор продолжает за границей).
## Стык меньше MIN_JOIN — сдвиг отбрасывается: иначе дорисовка висела бы
## отдельно от молота
const MIN_JOIN := 0.5

func _best_offset(comp: PackedInt32Array, cb: Rect2i, target: PackedByteArray, tb: Rect2i, tsize: int, edge_px: Array[Vector2i], edge_out: Array[Vector2i]) -> Dictionary:
	var donor := PackedByteArray()
	donor.resize(CELL * CELL)
	for p in comp:
		donor[p] = 1
	var best_d := Vector2i.ZERO
	var best_s := 0.0
	var best_iou := 0.0
	var best_join := 0.0
	# Сдвиги, при которых рамки пересекаются
	for dy in range(tb.position.y - cb.end.y + 1, tb.end.y - cb.position.y):
		for dx in range(tb.position.x - cb.end.x + 1, tb.end.x - cb.position.x):
			var inter := 0
			var inside := 0
			var outside := 0
			for p in comp:
				var x := p % CELL + dx
				var y := p / CELL + dy
				if x < 0 or y < 0 or x >= CELL or y >= CELL:
					outside += 1
					continue
				inside += 1
				if target[y * CELL + x] == 1:
					inter += 1
			if outside == 0 or inter == 0:
				continue
			var union := inside + tsize - inter
			var iou := float(inter) / float(union)
			var hits := 0
			for i in edge_px.size():
				var q: Vector2i = edge_px[i] + edge_out[i] - Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < CELL and q.y < CELL and donor[q.y * CELL + q.x] == 1:
					hits += 1
			var join := float(hits) / float(maxi(edge_px.size(), 1))
			if join < MIN_JOIN:
				continue
			var s := iou * 0.6 + join * 0.4
			if s > best_s:
				best_s = s
				best_iou = iou
				best_join = join
				best_d = Vector2i(dx, dy)
	return {"d": best_d, "score": best_s, "iou": best_iou, "join": best_join}


## Переносит часть донора, оказавшуюся за краем исходной ячейки, в поля.
## Берётся металл донора и его тёмный контур (соседние непрозрачные пиксели)
func _paste(dst: Image, n: String, r: int, c: int, best: Dictionary) -> int:
	var src: Image = sheets[best["sheet"]]
	var dc: int = best["col"]
	var d: Vector2i = best["d"]
	var take := {}
	var donor_comp: PackedInt32Array = best["comp"]
	for p in donor_comp:
		var x := p % CELL
		var y := p / CELL
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var sx := x + ox
				var sy := y + oy
				if sx < 0 or sy < 0 or sx >= CELL or sy >= CELL:
					continue
				take[Vector2i(sx, sy)] = true
	# Кандидаты: пиксели донора, попавшие за пределы исходной ячейки
	var cand := {}
	for k in take:
		var sp: Vector2i = k
		var col := src.get_pixel(dc * CELL + sp.x, r * CELL + sp.y)
		if col.a < 0.05:
			continue
		var t := sp + d
		# Только за пределами исходной ячейки — внутри рисунок не трогаем
		if t.x >= 0 and t.y >= 0 and t.x < CELL and t.y < CELL:
			continue
		if t.x < -PAD or t.y < -PAD or t.x >= CELL + PAD or t.y >= CELL + PAD:
			continue
		cand[t] = col
	# Оставляем только то, что непрерывно продолжает рисунок через старую
	# границу: старт — пиксели, у которых сосед внутри ячейки непрозрачен.
	# Оторванные островки (кусок помпона, обрывок следа) отбрасываются
	var keep := {}
	var queue: Array[Vector2i] = []
	for k in cand:
		var t: Vector2i = k
		var inner := Vector2i(clampi(t.x, 0, CELL - 1), clampi(t.y, 0, CELL - 1))
		if inner.distance_squared_to(t) <= 2 and dst.get_pixel(c * OUT + PAD + inner.x, r * OUT + PAD + inner.y).a > 0.3:
			keep[t] = true
			queue.append(t)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var q: Vector2i = p + dv
			if cand.has(q) and not keep.has(q):
				keep[q] = true
				queue.append(q)
	var added := 0
	for k in keep:
		var t: Vector2i = k
		var col: Color = cand[t]
		var ox2 := c * OUT + PAD + t.x
		var oy2 := r * OUT + PAD + t.y
		if dst.get_pixel(ox2, oy2).a < col.a:
			dst.set_pixel(ox2, oy2, col)
			added += 1
	return added


## Всё, что по-прежнему обрывается ровно на старой границе ячейки и НЕ
## продолжено в полях, плавно растворяется к этой границе
func _feather_rest(dst: Image, ox: int, oy: int, protect: PackedByteArray) -> void:
	var seen := {}
	var queue: Array[Vector2i] = []
	# Дорисованный металл и его ближайшие соседи не растворяются
	for i in CELL * CELL:
		if protect[i] == 1:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var x := i % CELL + dx
					var y := i / CELL + dy
					if x >= 0 and y >= 0 and x < CELL and y < CELL:
						seen[Vector2i(x, y)] = true
	for i in CELL:
		for pv in [Vector2i(i, 0), Vector2i(i, CELL - 1), Vector2i(0, i), Vector2i(CELL - 1, i)]:
			var p: Vector2i = pv
			if seen.has(p):
				continue
			if dst.get_pixel(ox + PAD + p.x, oy + PAD + p.y).a <= 0.02:
				continue
			# Продолжено в полях (дорисовано) — не трогаем
			var outward := Vector2i(signi(p.x - CELL / 2) if (p.x == 0 or p.x == CELL - 1) else 0, signi(p.y - CELL / 2) if (p.y == 0 or p.y == CELL - 1) else 0)
			var q := p + outward
			if dst.get_pixel(ox + PAD + q.x, oy + PAD + q.y).a > 0.3:
				continue
			seen[p] = true
			queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var nq: Vector2i = p + d
			if nq.x < 0 or nq.y < 0 or nq.x >= CELL or nq.y >= CELL or seen.has(nq):
				continue
			if mini(mini(nq.x, nq.y), mini(CELL - 1 - nq.x, CELL - 1 - nq.y)) >= FEATHER:
				continue
			if dst.get_pixel(ox + PAD + nq.x, oy + PAD + nq.y).a > 0.02:
				seen[nq] = true
				queue.append(nq)
	for p in queue:
		if protect[p.y * CELL + p.x] == 1:
			continue
		var dist := mini(mini(p.x, p.y), mini(CELL - 1 - p.x, CELL - 1 - p.y))
		var k := smoothstep(0.0, float(FEATHER), float(dist) + 0.5)
		var col := dst.get_pixel(ox + PAD + p.x, oy + PAD + p.y)
		col.a *= k
		dst.set_pixel(ox + PAD + p.x, oy + PAD + p.y, col)
