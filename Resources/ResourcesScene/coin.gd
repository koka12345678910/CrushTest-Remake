extends Area2D

@export var coin_value := 1
@export var pickup_radius := 60.0
@export var fly_speed := 80.0
@export var spawn_force_min := 60.0
@export var spawn_force_max := 150.0
@export var is_big_coin := false  # большая ли это монета (если в дропе > 5)

var velocity := Vector2.ZERO
var is_flying_to_player := false
var target_player: Node2D = null
var player_in_range: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trail_particles: GPUParticles2D = $TrailParticles

func _ready() -> void:
	sprite.play("coin")
	var angle = randf_range(0, TAU)
	var force = randf_range(spawn_force_min, spawn_force_max)
	velocity = Vector2(cos(angle), sin(angle)) * force

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if is_big_coin:
		_start_shine()

	_compensate_for_ambient_tint()


# Уровень красит весь мир через CanvasModulate (сейчас — холодный ночной
# синеватый), и монета живёт в мире, а не на отдельном HUD-слое — поэтому
# золотой цвет частиц шлейфа умножается на этот тон и на глаз съезжает в
# голубой/зелёный. Компенсируем через modulate самого узла частиц (обратный
# множитель), а не правкой цвета частиц напрямую — ParticleProcessMaterial
# общий на все монеты (один SubResource в .tscn), и если красить его
# напрямую, мигать/перекрашиваться будут ВСЕ монеты на экране разом.
# Значение считаем от РЕАЛЬНОГО CanvasModulate.color на сцене, а не
# захардкоженным числом — переживёт смену освещения/будущую пасмурную карту
func _compensate_for_ambient_tint() -> void:
	var cm := _find_canvas_modulate()
	if cm == null:
		return
	var t := cm.color
	trail_particles.modulate = Color(
		1.0 / maxf(t.r, 0.05),
		1.0 / maxf(t.g, 0.05),
		1.0 / maxf(t.b, 0.05),
		1.0
	)


func _find_canvas_modulate() -> CanvasModulate:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for child in scene.get_children():
		if child is CanvasModulate:
			return child
	return null

func _physics_process(delta: float) -> void:
	if is_flying_to_player and target_player and is_instance_valid(target_player):
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * fly_speed * delta
		if global_position.distance_to(target_player.global_position) < 10.0:
			_collect()
		return
	
	# затухание разлёта при спавне
	velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	global_position += velocity * delta
	
	# проверяем зажатие E если игрок рядом
	if player_in_range and Input.is_action_pressed("interact"):
		target_player = player_in_range
		is_flying_to_player = true
		# золотой шлейф загорается ровно в момент, когда монета срывается к
		# игроку — до этого она просто лежит/разлетается после спавна, шлейф
		# тут неуместен, он должен читаться как "магнитом тянет к игроку"
		trail_particles.emitting = true

func _start_shine() -> void:
	# пульсация яркости — "блеск"
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(2.0, 1.9, 1.2, 1.0), 0.4)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null

func _collect() -> void:
	if target_player and target_player.has_method("add_gold"):
		target_player.add_gold(coin_value)
	queue_free()
