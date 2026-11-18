extends Node2D
## fallen_blood.gd — засохшие лужи крови под павшими Хольмвика.
##
## Тела ставит tools/holmvik_town.gd (fallen) с метой blood_at — центр тела.
## Здесь при старте под каждым рисуется лужа и пара брызг теми же текстурами,
## что кровь в бою (VFX/VFX_scene/blood_decals.gd, кладбище), но навсегда и
## уже подсохшая. Слой — по z, а не по месту в дереве: земля карты на z -20
## (immersion.gd _lower_ground), лужи на -17, свежая кровь боя на -16 —
## поверх них, персонажи (Objects) на 0.
const Z := -17

const BloodDecals := preload("res://VFX/VFX_scene/blood_decals.gd")
## Цвет засохшей крови (как DRY у боевой, чуть темнее — прошло несколько дней)
@export var color := Color(0.24, 0.02, 0.025, 0.92)
@export var pool_size := Vector2(46.0, 74.0)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	z_index = Z
	_rng.seed = 7
	_build.call_deferred()


func _build() -> void:
	var objects := get_parent().get_node_or_null("Objects")
	if objects == null:
		return
	var gen := BloodDecals.new()
	var n := 0
	for c in objects.get_children():
		if not c.has_meta("blood_at"):
			continue
		var at: Vector2 = c.get_meta("blood_at")
		_stain(gen._texture(BloodDecals.POOL), at + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(0, 6)),
			_rng.randf_range(pool_size.x, pool_size.y), _rng.randf() * TAU, _rng.randf_range(1.0, 1.4))
		for i in _rng.randi_range(1, 3):
			var o := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(22.0, 44.0)
			_stain(gen._texture(BloodDecals.SPLASH), at + o * Vector2(1.0, 0.62), _rng.randf_range(14.0, 24.0), _rng.randf() * TAU, 1.0)
		n += 1
	gen.free()


## Пятно, сплющенное в вид 3/4 (как в blood_decals._add)
func _stain(tex: Texture2D, at: Vector2, size: float, angle: float, stretch: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	var base := size / float(tex.get_height())
	var xa := Vector2(cos(angle), sin(angle) * BloodDecals.DEPTH) * base * stretch
	var ya := Vector2(-sin(angle), cos(angle) * BloodDecals.DEPTH) * base
	s.transform = Transform2D(xa, ya, at - global_position)
	s.modulate = color
	add_child(s)
