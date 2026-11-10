extends Node2D
## mage_frost_ring.gd — «Кольцо инея» (руна Иса, Q): вокруг мага из земли
## вырастают ледяные шипы. Две волны, по кадрам клипа Attack_4_ (лист Attack4,
## 15 к/с): на 2-3 кадре маг тянет силу — вплотную встаёт малое кольцо шипов
## (без урона, только видно, что сейчас будет); на 8-9 кадре выброс — большое
## кольцо: шипы бьют, озноб замедляет, лёгкий отброс наружу. На земле остаётся
## иней. Узел — точка под ногами мага, живёт в мире (маг может отойти).

const MageFx := preload("res://Player_scene/mage_fx.gd")
const IceFx := preload("res://Player_scene/mage_ice_fx.gd")
const SoundBank := preload("res://Levels/sound_bank.gd")

var caster: Node2D
var damage := 1
var radius := 78.0
var push := 140.0
var slow_pct := 50.0
var slow_sec := 2.5
## Длительность кадра клипа (mage.gd::_clip_frame_time)
var frame := 1.0 / 15.0
var inner_frame := 2.5
var outer_frame := 8.5
## Шипов во внешнем кольце; ранг/навыки могут добавить
var outer_count := 12

## Сорвалось ли заклинание (мага сбили): проверяет маг перед волной
var alive_check: Callable


func setup(caster_: Node2D, dmg: int, r: float, frame_: float) -> void:
	caster = caster_
	damage = dmg
	radius = r
	frame = frame_


func _ready() -> void:
	z_index = 11
	_run()


func _run() -> void:
	await get_tree().create_timer(inner_frame * frame).timeout
	if not _ok():
		queue_free()
		return
	_inner()
	await get_tree().create_timer(maxf(outer_frame - inner_frame, 0.0) * frame).timeout
	if not _ok():
		queue_free()
		return
	_outer()
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _ok() -> bool:
	return is_instance_valid(caster) and (not alive_check.is_valid() or alive_check.call())


## Малое кольцо вплотную: тонкие шипы, иней проступает, холодный свет
func _inner() -> void:
	var center := global_position
	var n := 7
	var r := radius * 0.42
	for i in n:
		var a := TAU * (i + randf_range(-0.2, 0.2)) / n
		var at := center + Vector2(cos(a), sin(a) * 0.62) * r
		IceFx.spike(get_tree(), at, randf_range(14.0, 20.0), randf_range(5.0, 7.0), i * 0.012,
				outer_frame * frame - inner_frame * frame + 0.05, cos(a) * 0.25)
	IceFx.frost_decal(get_tree(), center, r * 1.3, 1.0, 0.4)
	MageFx.light_pulse(self, 60.0, 0.8, 0.4, IceFx.MID)
	IceFx.mist(self, 5, r * 0.6, 22.0, 0.8, 0.18)


## Большое кольцо: шипы в два ряда, удар по всем в радиусе, вспышка, осколки,
## иней и дымка
func _outer() -> void:
	var center := global_position
	var tree := get_tree()
	var n := outer_count
	for i in n:
		var a := TAU * (i + randf_range(-0.25, 0.25)) / n
		var rr := radius * randf_range(0.72, 0.95)
		var at := center + Vector2(cos(a), sin(a) * 0.62) * rr
		IceFx.spike(tree, at, randf_range(26.0, 40.0), randf_range(8.0, 12.0), randf_range(0.0, 0.05),
				randf_range(0.55, 0.8), cos(a) * 0.35)
	# Второй ряд — мельче, между крупными, чуть дальше
	for i in n:
		var a := TAU * (i + 0.5 + randf_range(-0.2, 0.2)) / n
		var at := center + Vector2(cos(a), sin(a) * 0.62) * radius * randf_range(0.95, 1.1)
		IceFx.spike(tree, at, randf_range(12.0, 20.0), randf_range(5.0, 8.0), 0.04 + randf_range(0.0, 0.05),
				randf_range(0.4, 0.6), cos(a) * 0.45)

	IceFx.frost_decal(tree, center, radius * 1.25, 2.8, 0.6)
	MageFx.flash(self, radius * 0.9, 0.16, IceFx.CORE)
	MageFx.light_pulse(self, radius * 1.6, 1.6, 0.5, IceFx.MID)
	IceFx.shards(self, 26, 190.0, 0.6, Vector2.ZERO, 180.0, 220.0)
	IceFx.mist(self, 12, radius * 0.5, 36.0, 1.3, 0.24)
	MageFx.sparks(self, 14, 220.0, 0.35)
	SoundBank.play_at(tree, "trap_snap", center, -6.0, 1.35)
	if caster and caster.has_method("shake_camera"):
		caster.shake_camera(3.5, 0.2)

	for e in IceFx.targets(tree):
		if IceFx.ground_dist(center, IceFx.feet(e), 0.62) <= radius * 1.12:
			IceFx.hit(caster, e, damage, center, push, slow_pct, slow_sec)
