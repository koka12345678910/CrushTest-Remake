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

const TEXTURE := preload("res://Player_scene/arrow.png")
## Наконечник на исходной текстуре уже смотрит вправо (+X) — проверено по
## пикселям (силуэт сужается до острия у правого края, x≈58-63/64, левый
## край остаётся сплошным блоком — оперение). Совпадает с конвенцией
## rotation = _direction.angle() (0° = вправо), поправка не нужна
const SPRITE_FLIP := 0.0
const SCALE := Vector2(0.4, 0.4)
const HITBOX_SIZE := Vector2(26.0, 3.0)

@export var speed := 520.0
@export var lifetime := 1.6

var damage := 12
var _shooter: Node2D
var _direction := Vector2.RIGHT
var _age := 0.0


## Единственная точка входа — вызывается сразу после add_child(), пока стрела
## ещё не тронута ни одним кадром _process
func launch(from: Vector2, direction: Vector2, shooter: Node2D, dmg: int) -> void:
	global_position = from
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()
	_shooter = shooter
	damage = dmg


func _ready() -> void:
	z_index = 10
	area_entered.connect(_on_area_entered)

	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.rotation = SPRITE_FLIP
	sprite.scale = SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	var shape := RectangleShape2D.new()
	shape.size = HITBOX_SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


func _process(delta: float) -> void:
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	var enemy := area.get_parent()
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if "is_dead" in enemy and enemy.is_dead:
		return
	enemy.take_damage(damage, _shooter)
	queue_free()
