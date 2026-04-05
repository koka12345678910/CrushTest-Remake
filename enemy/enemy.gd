extends CharacterBody2D

@export var speed := 80
@onready var anim = $AnimatedSprite2D

@export var max_health := 100
var health := max_health

@export var attack_distance := 40
@export var attack_cooldown := 1.0
var attack_timer := 0.0

var player = null
var see_player = false
var is_attacking := false
var is_dead := false

const TAU = PI * 2

func _ready():
	$VisionArea.body_entered.connect(_on_enter)
	$VisionArea.body_exited.connect(_on_exit)

func _on_enter(body):
	if body.is_in_group("player"):
		player = body
		see_player = true

func _on_exit(body):
	if body.is_in_group("player"):
		see_player = false

func _physics_process(delta):
	if is_dead or not see_player or is_attacking:
		velocity = Vector2.ZERO
		return

	var dir = player.global_position - global_position
	
	if dir.length() <= attack_distance:
		attack_timer -= delta
		
		if attack_timer <= 0:
			start_attack(dir)
			attack_timer = attack_cooldown
	else:
		velocity = dir.normalized() * speed
		move_and_slide()
		anim.play(get_anim("run", dir))

# ================= АТАКА =================

func start_attack(dir):
	is_attacking = true
	velocity = Vector2.ZERO
	
	anim.play(get_anim("attack", dir))

# вызывается из анимации
func deal_damage():
	if player and player.has_method("take_damage"):
		player.take_damage(10)

# вызывается в конце анимации
func end_attack():
	is_attacking = false

# ================= УРОН =================

func take_damage(amount):
	if is_dead:
		return

	health -= amount

	var dir = player.global_position - global_position
	anim.play(get_anim("hi", dir))

	if health <= 0:
		die()

# ================= СМЕРТЬ =================

func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	var dir = player.global_position - global_position
	anim.play(get_anim("death", dir))

	# отключаем коллизию
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	# задержка перед удалением (чтобы анимация успела)
	await get_tree().create_timer(0.5).timeout
	queue_free()

# ================= УНИВЕРСАЛЬНАЯ АНИМАЦИЯ =================

func get_anim(state: String, dir: Vector2) -> String:
	return state + "_" + get_dir_8(dir)

func get_dir_8(dir: Vector2) -> String:
	var angle = dir.angle()
	if angle < 0:
		angle += TAU

	if angle < PI/8 or angle >= 15*PI/8:
		return "right"
	elif angle < 3*PI/8:
		return "down_right"
	elif angle < 5*PI/8:
		return "down"
	elif angle < 7*PI/8:
		return "down_left"
	elif angle < 9*PI/8:
		return "left"
	elif angle < 11*PI/8:
		return "up_left"
	elif angle < 13*PI/8:
		return "up"
	else:
		return "up_right" 
