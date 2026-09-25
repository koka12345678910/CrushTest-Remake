extends Area2D
## arrow.gd — снаряд лучника. Летит по прямой от точки выстрела, при попадании
## во врага наносит урон и исчезает; если ни во что не попал — гаснет по
## таймауту (lifetime), чтобы промахи не летали вечно.
##
## Собран целиком кодом, без .tscn — тот же приём, что у focus_marker.gd:
## новый файл, ничего чужого не пересекает, проще держать в одном месте.
##
## Урон бьёт НАПРЯМУЮ через enemy.take_damage(), а не через пассивное
## обнаружение вражеским $Hitbox (как у рукопашного PlayerHitbox) — так
## source гарантированно оказывается стрелком, а не родителем стрелы в дереве
## сцены, и knockback у врага считается от правильной точки.
##
## Если у стрелка есть resolve_arrow_hit(enemy, arrow) — урон, криты и прочие
## эффекты навыков считает он (archer.gd), стрела только сообщает о попадании.

const TEXTURE := preload("res://Player_scene/arrow.png")
## Наконечник на исходной текстуре уже смотрит вправо (+X) — проверено по
## пикселям (силуэт сужается до острия у правого края, x≈58-63/64, левый
## край остаётся сплошным блоком — оперение). Совпадает с конвенцией
## rotation = _direction.angle() (0° = вправо), поправка не нужна
const SPRITE_FLIP := 0.0
const SCALE := Vector2(0.4, 0.4)
const HITBOX_SIZE := Vector2(26.0, 3.0)
## Сколько стрела торчит в стене, прежде чем растаять
const STUCK_TIME := 0.6
const TRAIL_POINTS := 10

@export var speed := 520.0
@export var lifetime := 1.6

var damage := 12
## Сколько врагов стрела может пробить насквозь (Коготь Фенрира)
var pierce := 0
## Не втыкается в стены (Шёпот Одина)
var ignore_walls := false
## Цель, к которой стрела доворачивает в полёте (Последний взор). null — прямо
var homing_target: Node2D = null
## Скорость доворота, рад/сек
var homing_turn := 5.0
## Цвет следа за стрелой. Прозрачный — следа нет (обычная стрела)
var trail_color := Color(0, 0, 0, 0)
## Произвольные пометки для стрелка: "guaranteed_crit" и т.п. — стрела их не
## читает, только отдаёт обратно в resolve_arrow_hit
var tags := {}

var _shooter: Node2D
var _direction := Vector2.RIGHT
var _age := 0.0
var _stuck := false
var _sprite: Sprite2D
var _trail: Line2D
# Одного врага бьём один раз: у пробивающей стрелы хёртбокс может войти
# повторно, пока она ещё летит сквозь него
var _hit_ids := {}


## Единственная точка входа — вызывается сразу после add_child(), пока стрела
## ещё не тронута ни одним кадром _process
func launch(from: Vector2, direction: Vector2, shooter: Node2D, dmg: int) -> void:
	global_position = from
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()
	_shooter = shooter
	damage = dmg
	if trail_color.a > 0.0:
		_start_trail()


func _ready() -> void:
	z_index = 10
	area_entered.connect(_on_area_entered)
	# Маска по умолчанию — слой 1 "world": стены тайлмапа и статические тела.
	# Хёртбоксы врагов тоже на 1-м слое, но это Area2D — они идут через
	# area_entered, а сюда попадают только твёрдые тела
	body_entered.connect(_on_body_entered)

	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.rotation = SPRITE_FLIP
	_sprite.scale = SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	var shape := RectangleShape2D.new()
	shape.size = HITBOX_SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


func _process(delta: float) -> void:
	if _stuck:
		return
	if is_instance_valid(homing_target) and not homing_target.is_dead:
		var want := (homing_target.global_position - global_position).angle()
		var ang := rotate_toward(_direction.angle(), want, homing_turn * delta)
		_direction = Vector2.from_angle(ang)
		rotation = ang
	global_position += _direction * speed * delta
	_update_trail()
	_age += delta
	if _age >= lifetime:
		_fade_out(0.12)


func _on_area_entered(area: Area2D) -> void:
	if _stuck or not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := area.get_parent()
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if "is_dead" in enemy and enemy.is_dead:
		return
	var id := enemy.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true

	if is_instance_valid(_shooter) and _shooter.has_method("resolve_arrow_hit"):
		_shooter.resolve_arrow_hit(enemy, self)
	else:
		enemy.take_damage(damage, _shooter)

	if pierce > 0:
		pierce -= 1
		# Пробитая цель больше не тянет стрелу к себе — летим дальше прямо
		if homing_target == enemy:
			homing_target = null
		return
	queue_free()


## Стена/препятствие. Стрела не исчезает мгновенно, а на миг застревает —
## так промах читается глазом, а не выглядит как баг
func _on_body_entered(body: Node) -> void:
	if _stuck or ignore_walls or body == _shooter:
		return
	_stuck = true
	set_deferred("monitoring", false)
	await get_tree().create_timer(STUCK_TIME).timeout
	_fade_out(0.2)


func _fade_out(time: float) -> void:
	set_process(false)
	set_deferred("monitoring", false)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, time)
	if is_instance_valid(_trail):
		t.tween_property(_trail, "modulate:a", 0.0, time)
	# След — ребёнок стрелы, уходит вместе с ней
	t.chain().tween_callback(queue_free)


# ── След ─────────────────────────────────────────────────────────────────────
# Line2D вне иерархии поворота стрелы (top_level) — точки в мировых координатах

func _start_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 3.0
	_trail.z_index = 9
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(trail_color, 0.0))
	grad.set_color(1, trail_color)
	_trail.gradient = grad
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve
	add_child(_trail)
	_sprite.modulate = trail_color.lerp(Color.WHITE, 0.55)


func _update_trail() -> void:
	if not is_instance_valid(_trail):
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)
