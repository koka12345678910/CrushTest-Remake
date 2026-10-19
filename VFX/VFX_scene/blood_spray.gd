extends Node2D
## blood_spray.gd — брызги крови одного удара (создаёт blood_fx.gd::hit).
##
## Узел стоит на земле под раненым. Капли — простая физика в 3/4 виде:
## позиция на земле + высота над ней, гравитация тянет высоту вниз. Капля
## рисуется там, где она в воздухе, с коротким хвостом по направлению полёта,
## а упав — оставляет пятно (blood_decals.gd): быстрая — вытянутое, медленная
## — круглое. Крупные капли при ударе о землю ещё и разбрызгиваются.
## Весь эффект — одна отрисовка _draw на удар, без частиц и шейдеров.
##
## Что делает каждый удар своим: число, размер и цвет капель, их разброс и в
## какую сторону завален веер, иногда — пульсирующая струя из раны, туман,
## место и форма главного пятна. Всё из случайных чисел на каждый удар.

## Номера — те же, что BloodFx.Kind (без preload, чтобы не было цикла)
enum { SLASH, PIERCE, BLUNT, BLAST, DRIP }

const GRAVITY := 620.0
const DEPTH := 0.62
## Хвост капли — путь за последние STREAK секунд полёта
const STREAK := 0.022
const FRESH := Color(0.52, 0.02, 0.03)

var _decals: Node2D
var _dir := Vector2.RIGHT
var _power := 1.0
var _kind := SLASH
var _height := 18.0
var _rng := RandomNumberGenerator.new()
var _drops: Array[Dictionary] = []
var _mists: Array[Dictionary] = []
var _soft: Texture2D


func setup(decals: Node2D, dir: Vector2, power: float, kind: int, height: float) -> void:
	_decals = decals
	_dir = dir.normalized()
	_power = power
	_kind = kind
	_height = height


func _ready() -> void:
	# Над персонажами: брызги в воздухе должны быть видны поверх раненого
	z_index = 6
	_rng.randomize()
	_soft = _decals.soft_texture() if is_instance_valid(_decals) else null
	_plan()


## Раскладка брызг под вид удара
func _plan() -> void:
	var p := _power
	match _kind:
		SLASH:
			# Веер заваливается в сторону замаха — каждый раз в свою
			var lean := _rng.randf_range(0.2, 0.55) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_burst(int(14 + 12 * p), lean, 0.7, 60.0, 210.0, 30.0, 150.0)
			if _rng.randf() < 0.35 + 0.2 * p:
				_jet(lean + _rng.randf_range(-0.3, 0.3))
			_mist(2 + _rng.randi_range(0, 1))
		PIERCE:
			_burst(int(10 + 9 * p), 0.0, 0.26, 120.0, 290.0, 10.0, 90.0)
			# Немного назад, из входного отверстия
			_burst(_rng.randi_range(2, 5), PI, 0.5, 20.0, 70.0, 20.0, 70.0)
			if _rng.randf() < 0.5 + 0.2 * p:
				_jet(_rng.randf_range(-0.2, 0.2))
			_mist(1)
		BLUNT:
			_burst(int(12 + 9 * p), 0.0, 1.5, 40.0, 150.0, 60.0, 170.0)
			_mist(3 + _rng.randi_range(0, 1))
		BLAST:
			_burst(int(9 + 8 * p), 0.0, PI, 50.0, 180.0, 40.0, 160.0, 0.62)
			_mist(4)
		DRIP:
			# Стекает по боку и капает чуть впереди ног — прямо под ногами
			# пятна закрыл бы сам персонаж
			for i in _rng.randi_range(2, 4):
				var side := _rng.randf_range(5.0, 10.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
				_add_drop(Vector2(side, _rng.randf_range(3.0, 7.0)), _height * _rng.randf_range(0.5, 0.9),
						Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-2, 4)), _rng.randf_range(-10, 10),
						_rng.randf_range(1.1, 1.9), _rng.randf_range(0.0, 0.3))
	# Главное пятно — туда, куда ушла основная масса брызг, когда она долетит
	if _kind != DRIP and is_instance_valid(_decals):
		var at := global_position + Vector2(_dir.x, _dir.y * DEPTH) * _rng.randf_range(6.0, 20.0) * p
		var dir := _dir
		var pw := p
		var dec := _decals
		get_tree().create_timer(_rng.randf_range(0.1, 0.18)).timeout.connect(func():
			if is_instance_valid(dec):
				dec.splash(at, pw, dir))


## Выброс капель конусом: lean — поворот оси от направления удара (рад),
## spread — разброс, скорости по земле и вверх — диапазоны
func _burst(count: int, lean: float, spread: float, sp_min: float, sp_max: float, up_min: float, up_max: float, dark := 1.0) -> void:
	for i in count:
		var ang := _dir.angle() + lean + _rng.randfn(0.0, spread * 0.5)
		var speed := _rng.randf_range(sp_min, sp_max) * (0.85 + 0.15 * _power)
		var v := Vector2.from_angle(ang) * speed
		v.y *= DEPTH
		# Размер: в основном мелкие, изредка крупные капли
		var r := lerpf(0.7, 2.3, pow(_rng.randf(), 2.2)) * (0.85 + 0.15 * _power)
		if _rng.randf() < 0.08 * _power:
			r = _rng.randf_range(2.6, 3.6)
		# Крупные летят медленнее, мелкие — дальше и быстрее
		v *= lerpf(1.15, 0.7, (r - 0.7) / 2.9)
		_add_drop(Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2)), _height + _rng.randf_range(-4, 4),
				v, _rng.randf_range(up_min, up_max), r, _rng.randf_range(0.0, 0.03), dark)


## Струя из раны: несколько толчков подряд, каждый слабее — как пульс
func _jet(lean: float) -> void:
	var pulses := _rng.randi_range(2, 4)
	var t := 0.04
	var strength := _rng.randf_range(150.0, 230.0) * (0.8 + 0.2 * _power)
	var ang := _dir.angle() + lean
	for k in pulses:
		for i in _rng.randi_range(4, 7):
			var v := Vector2.from_angle(ang + _rng.randfn(0.0, 0.08)) * strength * _rng.randf_range(0.85, 1.05)
			v.y *= DEPTH
			_add_drop(Vector2.ZERO, _height, v, _rng.randf_range(50.0, 90.0), _rng.randf_range(0.9, 1.8), t + i * 0.012)
		t += _rng.randf_range(0.09, 0.14)
		strength *= _rng.randf_range(0.6, 0.75)
		ang += _rng.randf_range(-0.12, 0.12)


## Кровавый туман у раны — мягкие пятна, которые расплываются и тают
func _mist(count: int) -> void:
	for i in count:
		_mists.append({
			"p": Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-3, 3)),
			"h": _height + _rng.randf_range(-3, 5),
			"v": Vector2(_dir.x, _dir.y * DEPTH) * _rng.randf_range(15.0, 45.0) + Vector2(_rng.randf_range(-8, 8), 0),
			"r0": _rng.randf_range(3.0, 5.0) * (0.8 + 0.2 * _power),
			"r1": _rng.randf_range(9.0, 15.0) * (0.8 + 0.2 * _power),
			"life": _rng.randf_range(0.3, 0.55),
			"t": 0.0,
			"a": _rng.randf_range(0.25, 0.4),
		})


func _add_drop(p: Vector2, h: float, v: Vector2, vz: float, r: float, delay: float, dark := 1.0) -> void:
	var shade := _rng.randf_range(0.75, 1.15) * dark
	_drops.append({
		"p": p, "h": h, "v": v, "vz": vz, "r": r, "delay": delay, "alive": true,
		"col": Color(FRESH.r * shade, FRESH.g * shade, FRESH.b * shade),
	})


func _process(delta: float) -> void:
	var busy := false
	var spawned: Array[Dictionary] = []
	for d in _drops:
		if not d.alive:
			continue
		busy = true
		if d.delay > 0.0:
			d.delay -= delta
			continue
		d.vz -= GRAVITY * delta
		d.v *= 1.0 - 0.9 * delta
		d.p += d.v * delta
		d.h += d.vz * delta
		if d.h <= 0.0:
			d.alive = false
			_land(d, spawned)
	_drops.append_array(spawned)
	for m in _mists:
		if m.t < m.life:
			busy = true
			m.t += delta
			m.p += m.v * delta
			m.h += 6.0 * delta
	queue_redraw()
	if not busy:
		queue_free()


## Капля упала: пятно на землю, крупная и быстрая — ещё и брызги от удара
func _land(d: Dictionary, spawned: Array[Dictionary]) -> void:
	if not is_instance_valid(_decals):
		return
	# Пятно — от всех крупных капель и части мелких: на земле мелочь всё равно
	# сливается, а пятна ограничены (blood_decals.gd::MAX_SPLATS)
	if d.r > 1.5 or _kind == DRIP or _rng.randf() < 0.35:
		_decals.drop(global_position + d.p, d.r, d.v, d.col)
	if d.r > 2.2 and d.v.length() > 60.0:
		for i in _rng.randi_range(1, 3):
			var v: Vector2 = d.v.rotated(_rng.randf_range(-0.8, 0.8)) * _rng.randf_range(0.25, 0.5)
			spawned.append({
				"p": d.p, "h": 0.5, "v": v, "vz": _rng.randf_range(20.0, 45.0),
				"r": d.r * _rng.randf_range(0.3, 0.45), "delay": 0.0, "alive": true, "col": d.col,
			})


func _draw() -> void:
	for m in _mists:
		if m.t >= m.life or _soft == null:
			continue
		var k: float = m.t / m.life
		var r: float = lerpf(m.r0, m.r1, 1.0 - pow(1.0 - k, 2.0))
		var c := Vector2(m.p.x, m.p.y - m.h)
		draw_texture_rect(_soft, Rect2(c - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false,
				Color(0.42, 0.02, 0.03, m.a * (1.0 - k)))
	for d in _drops:
		if not d.alive or d.delay > 0.0:
			continue
		var s := Vector2(d.p.x, d.p.y - d.h)
		var vel := Vector2(d.v.x, d.v.y - d.vz)
		var tail := s - vel * STREAK
		draw_line(tail, s, d.col, d.r * 1.5)
		draw_circle(s, d.r, d.col)
