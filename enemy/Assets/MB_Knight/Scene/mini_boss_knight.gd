extends CharacterBody2D
## Мини-босс "Большой рыцарь" (GreatSwordKnight).
## Пока только движение: бродит стоя на месте (Idle), замечает игрока в радиусе
## chase_range и идёт к нему (Walk), останавливаясь на preferred_distance.
## Боёвка (Slash-анимация уже есть в SpriteFrames) добавится отдельным заходом.

@export var walk_speed := 55.0
@export var chase_range := 280.0
@export var preferred_distance := 70.0
@export var direction_smoothness := 6.0
@export var acceleration := 6.0
@export var friction := 8.0

# Плейсхолдер для совместимости с уже существующими системами, которые
# ищут врагов через group("enemy") и читают is_dead напрямую (например,
# Player.get_nearest_enemy()) — без этого поля игра упадёт, как только
# игрок окажется рядом с боссом. Реальная смерть/здоровье — в следующем шаге.
var is_dead := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: Node2D = null
var direction := Vector2.DOWN   # текущее направление взгляда (для Idle/Walk)
var _dir_name := "Down"         # последнее имя направления, вида "Down_Left"


func _ready() -> void:
	add_to_group("enemy")
	_find_player()


func _find_player() -> void:
	var candidates := get_tree().get_nodes_in_group("player")
	if candidates.size() > 0:
		player = candidates[0]


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(player):
		_find_player()

	var target_velocity := Vector2.ZERO

	if is_instance_valid(player):
		var to_player := player.global_position - global_position
		var dist := to_player.length()

		# в радиусе погони, но не вплотную — идём к игроку
		if dist <= chase_range and dist > preferred_distance:
			var move_dir := to_player / dist
			direction = direction.lerp(move_dir, direction_smoothness * delta)
			if direction.length() > 0.001:
				target_velocity = direction.normalized() * walk_speed
		elif dist > 0.001:
			# слишком далеко или уже вплотную — стоим, но смотрим на игрока
			direction = to_player / dist

	# плавный разгон/торможение — как у обычных врагов
	if target_velocity != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, walk_speed * acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, walk_speed * friction * delta)

	if not velocity.is_finite():
		velocity = Vector2.ZERO

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	# анимация идёт по направлению ВЗГЛЯДА (direction), а не только когда
	# реально двигаемся — босс поворачивается к игроку, даже стоя на месте
	if direction.length() > 0.001:
		_dir_name = _get_direction_name(direction)

	var moving := velocity.length() > 5.0
	var anim_name := ("Walk_" if moving else "Idle_") + _dir_name
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


# та же логика, что у Player.get_direction() — совпадает с именами анимаций
# (Down, Down_Left, Down_Right, Left, Right, Up, Up_Left, Up_Right)
func _get_direction_name(vec: Vector2) -> String:
	var dir := ""
	if vec.y < -0.3:
		dir = "Up"
	elif vec.y > 0.3:
		dir = "Down"

	if vec.x < -0.3:
		dir = "Left" if dir == "" else dir + "_Left"
	elif vec.x > 0.3:
		dir = "Right" if dir == "" else dir + "_Right"

	return dir if dir != "" else _dir_name
