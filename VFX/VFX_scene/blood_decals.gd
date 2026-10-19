extends Node2D
## blood_decals.gd — пятна крови на земле. Один узел на уровень (создаёт
## blood_fx.gd::decals), все пятна — его дети.
##
## Пятна лежат под персонажами, но над землёй. Свежая кровь яркая, за
## несколько секунд темнеет (подсыхает), через полминуты тает. Пятен не
## больше MAX_SPLATS — самые старые уходят первыми, так что затяжной бой не
## копит их бесконечно.
##
## Текстуры пятен рисуются кодом из кружков-штампов: так получается живая
## неровная форма, а там, где кровь тонкая (у края), она темнее — как
## засохший ободок у настоящей капли. Вариантов каждого вида — до VARIANTS,
## дальше они переиспользуются, но каждый раз с другим поворотом, размером и
## растяжкой — одинаковых пятен на земле не видно.

enum { DROP, STREAK, SPLASH, POOL }

const MAX_SPLATS := 260
const VARIANTS := 10
const FRESH := Color(0.6, 0.03, 0.04)
const DRY := Color(0.27, 0.025, 0.03)
const DEPTH := 0.62
## Сколько живёт обычное пятно и лужа (с)
const LIFE := 30.0
const POOL_LIFE := 45.0

static var _cache := {}
static var _soft: GradientTexture2D

var _rng := RandomNumberGenerator.new()
var _splats: Array[Sprite2D] = []


func _ready() -> void:
	z_as_relative = false
	z_index = -16
	_rng.randomize()


## Упавшая капля: быстрая — вытянутый след по направлению полёта, медленная — круглая
func drop(at: Vector2, r: float, v: Vector2, col: Color) -> void:
	var ground_v := Vector2(v.x, v.y / DEPTH)
	var speed := ground_v.length()
	if speed > 75.0:
		var stretch := clampf(speed / 110.0, 1.0, 2.6)
		_add(STREAK, at, r * 5.5 * (0.8 + 0.2 * stretch), ground_v.angle(), stretch * 0.6, LIFE, col)
	else:
		_add(DROP, at, r * 4.2, _rng.randf() * TAU, _rng.randf_range(1.0, 1.25), LIFE, col)


## Главное пятно удара — "корона" из брызг, вытянута по направлению удара
func splash(at: Vector2, power: float, dir: Vector2) -> void:
	var size := (18.0 + 12.0 * power) * _rng.randf_range(0.85, 1.15)
	_add(SPLASH, at, size, Vector2(dir.x, dir.y).angle() + _rng.randf_range(-0.3, 0.3), _rng.randf_range(1.0, 1.4), LIFE, FRESH)


## Лужа под павшим — растекается, а не появляется сразу
func pool(at: Vector2, size: float) -> void:
	var s := _add(POOL, at, size, _rng.randf() * TAU, _rng.randf_range(1.0, 1.3), POOL_LIFE, FRESH.darkened(0.12), 2.6)
	s.z_index = -1


## Мягкое круглое пятно — туман у раны (blood_spray.gd)
func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 32
		_soft.height = 32
	return _soft


## size — поперечник пятна в пикселях мира, angle — куда вытянуто (по земле),
## stretch — во сколько раз длиннее вдоль angle, grow — за сколько растекается
func _add(type: int, at: Vector2, size: float, angle: float, stretch: float, life: float, col: Color, grow := 0.07) -> Sprite2D:
	var tex := _texture(type)
	var s := Sprite2D.new()
	s.texture = tex
	var base := size / float(tex.get_height())
	# Поворот по земле и сплющивание в 3/4 вид: оси спрайта сами считаем,
	# обычный scale+rotation сплющил бы пятно уже после поворота неправильно
	var sx := base * stretch
	var sy := base
	var xa := Vector2(cos(angle), sin(angle) * DEPTH)
	var ya := Vector2(-sin(angle), cos(angle) * DEPTH)
	if _rng.randf() < 0.5:
		ya = -ya
	var full := Transform2D(xa * sx, ya * sy, at - global_position)
	s.transform = Transform2D(full.x * 0.35, full.y * 0.35, full.origin)
	s.modulate = col
	add_child(s)
	_splats.append(s)

	var t := s.create_tween()
	# Капля разбивается о землю — пятно за миг растекается до полного размера
	t.tween_property(s, "transform", full, grow).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(s, "modulate", Color(DRY, 1.0), 6.0).set_delay(grow)
	t.tween_interval(maxf(life - 6.0 - 3.0, 0.0))
	t.tween_property(s, "modulate:a", 0.0, 3.0)
	t.tween_callback(_remove.bind(s))

	if _splats.size() > MAX_SPLATS:
		var old: Sprite2D = _splats.pop_front()
		if is_instance_valid(old):
			var ft := old.create_tween()
			ft.tween_property(old, "modulate:a", 0.0, 0.6)
			ft.tween_callback(old.queue_free)
	return s


func _remove(s: Sprite2D) -> void:
	_splats.erase(s)
	s.queue_free()


func _texture(type: int) -> Texture2D:
	var list: Array = _cache.get(type, [])
	if list.size() < VARIANTS:
		list.append(_generate(type))
		_cache[type] = list
		return list.back()
	return list[_rng.randi() % list.size()]


# ── Генерация текстур ──────────────────────────────────────────────────────
# depth[i] — насколько пиксель "внутри" ближайшего кружка (px). Больше нуля —
# кровь; около нуля — край (тонко, темнее, сглажено)

var _w := 0
var _h := 0
var _depth := PackedFloat32Array()


func _stamp(cx: float, cy: float, r: float) -> void:
	var x0 := maxi(int(cx - r - 1.0), 0)
	var x1 := mini(int(cx + r + 1.0), _w - 1)
	var y0 := maxi(int(cy - r - 1.0), 0)
	var y1 := mini(int(cy + r + 1.0), _h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var v := r - Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			var i := y * _w + x
			if v > _depth[i]:
				_depth[i] = v


## Цепочка кружков от a к b с радиусом от ra до rb
func _stroke(a: Vector2, b: Vector2, ra: float, rb: float) -> void:
	var n := maxi(int(a.distance_to(b) / maxf(minf(ra, rb) * 0.6, 0.5)), 1)
	for k in n + 1:
		var f := float(k) / n
		var p := a.lerp(b, f)
		_stamp(p.x, p.y, lerpf(ra, rb, f))


func _generate(type: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match type:
		DROP:
			_w = 24; _h = 24
		STREAK:
			_w = 64; _h = 24
		SPLASH:
			_w = 72; _h = 72
		POOL:
			_w = 96; _h = 96
	_depth = PackedFloat32Array()
	_depth.resize(_w * _h)
	_depth.fill(-99.0)
	var c := Vector2(_w, _h) * 0.5
	var thick := 2.5

	match type:
		DROP:
			var r := _w * 0.26
			_stamp(c.x, c.y, r)
			for i in rng.randi_range(2, 4):
				var o := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.3, 0.55)
				_stamp(c.x + o.x, c.y + o.y, r * rng.randf_range(0.55, 0.8))
			for i in rng.randi_range(0, 2):
				var o := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(1.45, 1.8)
				_stamp(c.x + o.x, c.y + o.y, rng.randf_range(0.8, 1.4))
		STREAK:
			# Голова справа (туда летела капля), хвост тянется назад и тает
			var hr := _h * 0.26
			var head := Vector2(_w * 0.7, c.y + rng.randf_range(-1.5, 1.5))
			_stamp(head.x, head.y, hr)
			_stamp(head.x - hr * 0.4, head.y + rng.randf_range(-1, 1), hr * 0.85)
			var tail_end := Vector2(_w * rng.randf_range(0.08, 0.22), c.y + rng.randf_range(-3, 3))
			var mid := head.lerp(tail_end, 0.5) + Vector2(0, rng.randf_range(-2, 2))
			_stroke(head, mid, hr * 0.75, hr * 0.45)
			_stroke(mid, tail_end, hr * 0.45, 0.6)
			# Брызги, обогнавшие каплю, и капельки вдоль следа
			for i in rng.randi_range(1, 3):
				_stamp(head.x + hr * rng.randf_range(1.5, 2.6), head.y + rng.randf_range(-hr, hr), rng.randf_range(0.7, 1.4))
			for i in rng.randi_range(0, 3):
				var p := head.lerp(tail_end, rng.randf_range(0.2, 0.9))
				_stamp(p.x, p.y + rng.randf_range(-4, 4), rng.randf_range(0.6, 1.1))
		SPLASH:
			var r := _w * 0.15
			_stamp(c.x, c.y, r)
			for i in rng.randi_range(4, 6):
				var o := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.35, 0.7)
				_stamp(c.x + o.x, c.y + o.y, r * rng.randf_range(0.5, 0.8))
			# Лучи короны: сужаются наружу, на конце часто отдельная капля
			for i in rng.randi_range(7, 14):
				var a := rng.randf() * TAU
				var dirv := Vector2.from_angle(a)
				var length := r * rng.randf_range(1.2, 2.6)
				var end := c + dirv * length
				_stroke(c + dirv * r * 0.5, end, r * rng.randf_range(0.25, 0.4), rng.randf_range(0.5, 0.9))
				if rng.randf() < 0.6:
					var tip := c + dirv * (length + rng.randf_range(2.0, 6.0))
					_stamp(tip.x, tip.y, rng.randf_range(0.9, 1.9))
			for i in rng.randi_range(6, 14):
				var o := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(1.8, 2.9)
				_stamp(c.x + o.x, c.y + o.y, rng.randf_range(0.6, 1.6))
		POOL:
			var r := _w * 0.24
			thick = 5.0
			_stamp(c.x, c.y, r)
			for i in rng.randi_range(8, 14):
				var o := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.3, 0.85)
				_stamp(c.x + o.x, c.y + o.y, r * rng.randf_range(0.4, 0.75))
			for i in rng.randi_range(3, 7):
				var o := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(1.3, 1.8)
				_stamp(c.x + o.x, c.y + o.y, rng.randf_range(1.0, 2.5))

	var img := Image.create(_w, _h, false, Image.FORMAT_LA8)
	for y in _h:
		for x in _w:
			var v := _depth[y * _w + x]
			if v <= -0.5:
				continue
			var a := clampf(v + 0.5, 0.0, 1.0)
			# Край тоньше — темнее (засохший ободок), середина лужи гуще — тоже темнее
			var lum := lerpf(0.66, 1.0, clampf(v / thick, 0.0, 1.0))
			if type == POOL:
				lum *= lerpf(1.0, 0.84, clampf((v - thick) / (_w * 0.2), 0.0, 1.0))
			img.set_pixel(x, y, Color(lum, lum, lum, a))
	return ImageTexture.create_from_image(img)
