extends Node2D
## spark_spray.gd — сноп искр от удара металла о металл (создаёт knight_fx.gd).
##
## Узел стоит на земле под точкой удара. Искры — та же простая физика 3/4
## вида, что у крови (blood_spray.gd): позиция на земле + высота, гравитация.
## Каждая искра — светящийся штрих по направлению полёта, остывает от
## бело-жёлтого к оранжевому и тёмно-красному; упав, один раз отскакивает и
## гаснет. Одна отрисовка _draw на весь сноп, аддитивно и без освещения —
## искры светятся и ночью.

const GRAVITY := 520.0
const DEPTH := 0.62
## Хвост искры — путь за последние STREAK секунд полёта
const STREAK := 0.03

const HOT := Color(1.0, 0.96, 0.82)
const WARM := Color(1.0, 0.68, 0.24)
const COOL := Color(0.8, 0.22, 0.06)

var _sparks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## dir — куда летит основной сноп (по экрану), spread — разброс (рад),
## height — высота точки удара над землёй
func setup(count: int, dir: Vector2, spread: float, speed_min: float, speed_max: float, height: float, life := 0.55) -> void:
	_rng.randomize()
	for i in count:
		var ang := dir.angle() + _rng.randfn(0.0, spread * 0.5)
		var v := Vector2.from_angle(ang) * _rng.randf_range(speed_min, speed_max)
		v.y *= DEPTH
		_sparks.append({
			"p": Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-1, 1)),
			"h": height + _rng.randf_range(-3, 3),
			"v": v,
			"vz": _rng.randf_range(20.0, 150.0),
			"t": 0.0,
			"life": life * _rng.randf_range(0.55, 1.15),
			"w": _rng.randf_range(0.7, 1.5),
			"bounced": false,
		})


func _ready() -> void:
	z_index = 12
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	var alive := false
	for s in _sparks:
		if s.t >= s.life:
			continue
		alive = true
		s.t += delta
		s.vz -= GRAVITY * delta
		s.v *= 1.0 - 1.6 * delta
		s.p += s.v * delta
		s.h += s.vz * delta
		if s.h <= 0.0:
			s.h = 0.0
			if not s.bounced and s.vz < -40.0:
				# Отскок от земли — слабее, и искра уже остывает
				s.bounced = true
				s.vz = -s.vz * 0.32
				s.v *= 0.55
			else:
				s.vz = 0.0
				s.v *= 0.8
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for s in _sparks:
		if s.t >= s.life:
			continue
		var k: float = s.t / s.life
		var col := HOT.lerp(WARM, smoothstep(0.0, 0.35, k)).lerp(COOL, smoothstep(0.35, 1.0, k))
		col.a = 1.0 - smoothstep(0.6, 1.0, k)
		var pos := Vector2(s.p.x, s.p.y - s.h)
		var vel := Vector2(s.v.x, s.v.y - s.vz)
		var tail := pos - vel * STREAK * (1.0 - k * 0.6)
		draw_line(tail, pos, col, s.w)
		draw_rect(Rect2(pos - Vector2.ONE * s.w * 0.6, Vector2.ONE * s.w * 1.2), Color(1, 1, 1, col.a * (1.0 - k)))
