extends Node
## motion_feel.gd — «вес» в движении героя без новых анимаций: лёгкий наклон
## корпуса в сторону бега, сжатие/растяжение на старте, остановке и
## развороте, пыль из-под ног на рывке с места и на резкой остановке.
## Вешается ребёнком на любого героя (player.gd, character_base.gd).
##
## Масштаб картинки каждый кадр выставляет DepthComponent (этажность), поэтому
## сжатие идёт через его fx_scale, а не прямо в sprite.scale. Наклон — через
## rotation самой картинки (её больше никто не крутит).

const SkidDust := preload("res://VFX/VFX_scene/skid_dust.gd")

## Наклон корпуса на полном беге, градусы (по горизонтальной составляющей)
@export var max_lean_deg := 4.0
@export var lean_smoothing := 10.0
## Сила сжатия/растяжения (0.07 = на 7%) и как быстро возвращается
@export var squash_amount := 0.07
@export var squash_return := 9.0
## Пыль: старт с места быстрее этого / остановка с этой скорости
## Пыль на рывке с места. У рыцаря своя (player.gd::handle_movement_vfx) —
## ему выключено, чтобы не двоилась
@export var start_dust := true
@export var dust_start_speed := 140.0
@export var dust_stop_speed := 150.0

var _body: CharacterBody2D
var _sprite: Node2D
var _depth: Node
var _squash := 0.0
var _lean := 0.0
var _prev_speed := 0.0
var _prev_dir := Vector2.ZERO
var _dust_cd := 0.0
## Недавний пик скорости: торможение длится несколько кадров, и «резкая
## остановка» — это пик выше dust_stop_speed и затем скорость почти ноль
var _recent_peak := 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		return
	for c in _body.get_children():
		if c is AnimatedSprite2D:
			_sprite = c
			break
	_depth = _body.get_node_or_null("DepthComponent")


func _physics_process(delta: float) -> void:
	if _body == null or not is_instance_valid(_sprite):
		return
	_dust_cd = maxf(_dust_cd - delta, 0.0)
	var v := _body.velocity
	var speed := v.length()
	var busy: bool = _flag("is_attacking") or _flag("is_rolling") or _flag("is_stunned") \
			or _flag("is_in_shop") or (_body.has_method("is_dead") and _body.is_dead())
	var run_speed: float = _body.get("run_speed") if "run_speed" in _body else 200.0

	if not busy:
		var dir := v / speed if speed > 1.0 else Vector2.ZERO
		# Рывок с места — тянется вверх (растяжение), пыль назад из-под ног
		if _prev_speed < 25.0 and speed > 60.0:
			_squash = -1.0
			if start_dust and (speed > dust_start_speed or _flag("is_running")):
				_dust(-dir, SkidDust.Kind.START, 0.8)
		# Резкая остановка с бега — оседает (сжатие), пыль вперёд по инерции
		elif _prev_speed >= 40.0 and speed < 40.0 and _recent_peak > dust_stop_speed:
			_squash = 1.0
			_dust(_prev_dir, SkidDust.Kind.STOP, _recent_peak / run_speed)
		# Разворот на ходу — короткое сжатие
		elif speed > 80.0 and _prev_speed > 80.0 and dir.dot(_prev_dir) < -0.3:
			_squash = 0.8
		if speed > 1.0:
			_prev_dir = dir

	_prev_speed = speed
	_recent_peak = maxf(speed, _recent_peak - 500.0 * delta)
	if speed < 40.0 and _prev_speed < 40.0:
		_recent_peak = minf(_recent_peak, speed)
	_squash = move_toward(_squash, 0.0, squash_return * delta * maxf(absf(_squash), 0.15))
	var s := _squash * squash_amount
	var fx := Vector2(1.0 + s, 1.0 - s)

	# Наклон — только на беге и в свободном движении
	var target_lean := 0.0
	if not busy and speed > run_speed * 0.55:
		target_lean = clampf(v.x / run_speed, -1.0, 1.0) * deg_to_rad(max_lean_deg)
	_lean = lerpf(_lean, target_lean, minf(lean_smoothing * delta, 1.0))
	_sprite.rotation = _lean

	if _depth and "fx_scale" in _depth:
		_depth.fx_scale = fx


func _flag(name: String) -> bool:
	return name in _body and bool(_body.get(name))


## Пыль из-под ног (VFX/VFX_scene/skid_dust.gd) — та же, что на развороте.
## dir — куда летит пыль, power — во сколько раз скорость выше бега
func _dust(dir: Vector2, kind: int, power: float) -> void:
	if _dust_cd > 0.0 or dir == Vector2.ZERO:
		return
	_dust_cd = 0.25
	SkidDust.skid(_body.get_tree(), _body.global_position + Vector2(0, 14) + dir * 4.0, dir, kind, power)
