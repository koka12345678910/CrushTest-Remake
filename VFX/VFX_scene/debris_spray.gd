extends Node2D
## debris_spray.gd — комья земли и камешки от тяжёлого удара о землю (вихрь
## рыцаря, skid_dust.gd::slam). Та же простая физика 3/4 вида, что у искр
## (spark_spray.gd) и крови: точка на земле + высота, гравитация, отскок.
##
## Каждый обломок — неровный многоугольник своей формы и оттенка земли, со
## светлой гранью к свету, кувыркается в полёте; под ним — тень, которая
## сжимается и темнеет, когда он падает. Упав, пару раз подпрыгивает, скользит,
## лежит и тает. Одна отрисовка _draw на весь сноп. Освещение сцены обычное —
## ночью камни темнеют вместе с землёй.

const GRAVITY := 620.0
const DEPTH := 0.62
const LIGHT_DIR := Vector2(-0.55, -0.83)

## Оттенки земли и камня
const TONES := [Color(0.3, 0.26, 0.21), Color(0.36, 0.31, 0.25), Color(0.26, 0.24, 0.22),
		Color(0.42, 0.37, 0.3), Color(0.22, 0.19, 0.16)]

var _bits: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## count — сколько обломков, radius — разброс точек вылета вокруг центра,
## speed_min/max — скорость по земле, up_min/max — подброс вверх, size — px
func setup(count: int, radius: float, speed_min: float, speed_max: float, up_min: float, up_max: float,
		size_min := 1.4, size_max := 3.6, dir := Vector2.ZERO, spread := TAU) -> void:
	_rng.randomize()
	for i in count:
		var ang := (dir.angle() + _rng.randf_range(-spread * 0.5, spread * 0.5)) if dir != Vector2.ZERO else _rng.randf() * TAU
		var from := Vector2(cos(ang), sin(ang) * DEPTH) * _rng.randf_range(0.0, radius)
		var v := Vector2.from_angle(ang) * _rng.randf_range(speed_min, speed_max)
		v.y *= DEPTH
		var size := _rng.randf_range(size_min, size_max)
		# Форма: 5-7 вершин на неровном радиусе
		var pts := PackedVector2Array()
		var n := _rng.randi_range(5, 7)
		for k in n:
			var a := TAU * k / n + _rng.randf_range(-0.3, 0.3)
			pts.append(Vector2(cos(a), sin(a)) * size * _rng.randf_range(0.65, 1.15))
		_bits.append({
			"p": from,
			"h": _rng.randf_range(0.0, 4.0),
			"v": v,
			"vz": _rng.randf_range(up_min, up_max),
			"rot": _rng.randf() * TAU,
			"rv": _rng.randf_range(-14.0, 14.0),
			"pts": pts,
			"size": size,
			"col": TONES[_rng.randi() % TONES.size()],
			"t": 0.0,
			"rest": 0.0,
			"stay": _rng.randf_range(0.5, 1.3),
			"bounces": 0,
		})


func _ready() -> void:
	z_index = 11


func _process(delta: float) -> void:
	var alive := false
	for b in _bits:
		if b.rest >= b.stay + 0.5:
			continue
		alive = true
		b.t += delta
		if b.h > 0.0 or b.vz > 0.0:
			b.vz -= GRAVITY * delta
			b.p += b.v * delta
			b.h += b.vz * delta
			b.rot += b.rv * delta
			if b.h <= 0.0:
				b.h = 0.0
				if b.bounces < 2 and b.vz < -60.0:
					# Отскок: каждый слабее, вращение гаснет
					b.bounces += 1
					b.vz = -b.vz * (0.34 if b.bounces == 1 else 0.2)
					b.v *= 0.5
					b.rv *= 0.5
				else:
					b.vz = 0.0
		else:
			# На земле: скользит и замирает, потом лежит и тает
			b.v *= maxf(1.0 - 9.0 * delta, 0.0)
			b.p += b.v * delta
			b.rot += b.rv * delta * 0.2
			if b.v.length() < 4.0:
				b.rest += delta
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for b in _bits:
		if b.rest >= b.stay + 0.5:
			continue
		var fade: float = 1.0 - clampf((b.rest - b.stay) / 0.5, 0.0, 1.0)
		var size: float = b.size
		# Тень на земле: в полёте больше и бледнее, у земли — плотная
		var hk := clampf(b.h / 60.0, 0.0, 1.0)
		draw_set_transform(b.p, 0.0, Vector2(1.0, DEPTH))
		draw_circle(Vector2.ZERO, size * (1.0 + hk * 0.6), Color(0, 0, 0, 0.35 * (1.0 - hk * 0.7) * fade))
		# Сам обломок — над тенью на высоте h
		var pos := Vector2(b.p.x, b.p.y - b.h)
		draw_set_transform(pos, b.rot, Vector2.ONE)
		var col: Color = b.col
		draw_colored_polygon(b.pts, Color(col, fade))
		# Светлая грань к свету: половина вершин, что смотрят на свет
		# Вершины идут по кругу — берём сплошной отрезок освещённых, начиная с
		# первой после тёмной, иначе веер из центра мог бы перекрутиться
		var pts: PackedVector2Array = b.pts
		var n := pts.size()
		var dir_l := LIGHT_DIR.rotated(-b.rot)
		var start := -1
		for k in n:
			var cur := pts[k].dot(dir_l) > 0.0
			var prev := pts[(k - 1 + n) % n].dot(dir_l) > 0.0
			if cur and not prev:
				start = k
				break
		var lit := PackedVector2Array([Vector2.ZERO])
		if start >= 0:
			for k in n:
				var p := pts[(start + k) % n]
				if p.dot(dir_l) <= 0.0:
					break
				lit.append(p * 0.92)
		if lit.size() >= 3:
			draw_colored_polygon(lit, Color(col.lightened(0.35), 0.85 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
