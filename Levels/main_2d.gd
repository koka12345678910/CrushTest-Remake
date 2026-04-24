extends Node2D

@onready var player = $Player
@onready var enemy_root: Node2D = self

const ENEMY_SCENE := preload("res://enemy/Assets/enemy.tscn")

@export var max_enemies := 3
@export var respawn_delay := 1.0
# Area where enemies can spawn; tune this to your map size.
@export var spawn_area := Rect2(Vector2(80, 80), Vector2(1800, 1000))

var _alive_enemies := 0

func _on_area_2d_area_entered(area: Area2D) -> void:
	# Handles entering the trigger area used by the player.
	if area.name == "Player":
		player.anim.play()

func _ready() -> void:
	# Initializes enemy spawner state on scene start.
	randomize()
	_register_existing_enemies()
	_fill_to_max_enemies()

func _register_existing_enemies() -> void:
	# Registers enemies already placed in the scene.
	for child in get_children():
		if child is CharacterBody2D and child.is_in_group("enemy"):
			_track_enemy(child)

func _track_enemy(enemy: CharacterBody2D) -> void:
	# Adds one enemy to tracked set and listens for death/exit.
	if enemy == null:
		return
	if enemy.get_meta("tracked_by_spawner", false):
		return
	enemy.set_meta("tracked_by_spawner", true)
	_alive_enemies += 1
	if not enemy.tree_exited.is_connected(_on_enemy_tree_exited):
		enemy.tree_exited.connect(_on_enemy_tree_exited)

func _on_enemy_tree_exited() -> void:
	# Decrements alive counter and schedules delayed respawn.
	_alive_enemies = max(0, _alive_enemies - 1)
	_respawn_enemy_after_delay()

func _respawn_enemy_after_delay() -> void:
	# Waits before refilling enemies; safely exits if scene is closing.
	var scene_tree := get_tree()
	if scene_tree == null or not is_inside_tree():
		return
	await scene_tree.create_timer(respawn_delay).timeout
	if not is_inside_tree() or get_tree() == null:
		return
	_fill_to_max_enemies()

func _fill_to_max_enemies() -> void:
	# Spawns enemies until the configured map limit is reached.
	while _alive_enemies < max_enemies:
		_spawn_enemy()

func _spawn_enemy() -> void:
	# Instantiates one enemy and places it at a random spawn point.
	var enemy = ENEMY_SCENE.instantiate()
	if enemy == null:
		return
	if enemy is Node2D:
		enemy.global_position = _get_spawn_position()
	enemy_root.add_child(enemy)
	if enemy is CharacterBody2D:
		_track_enemy(enemy)

func _get_spawn_position() -> Vector2:
	# Returns a random point inside the spawn rectangle.
	var x = randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x)
	var y = randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
	return Vector2(x, y)
