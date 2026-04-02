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
	if not see_player:
		velocity = Vector2.ZERO
		anim.play("idle_down")
		return

	var dir = (player.global_position - global_position)
	
	if dir.length() <= attack_distance:
		attack_timer -= delta
		velocity = Vector2.ZERO
		if attack_timer <= 0:
			attack()
			attack_timer = attack_cooldown
		anim.play("attack") # или get_attack_anim(dir)
	else:
		velocity = dir.normalized() * speed
		move_and_slide()
		anim.play(get_anim_name(dir))



func attack():
	if player.has_method("take_damage"):
		player.take_damage(10) # наносим игроку 10 урона
		

func get_anim_name(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			return "run_right"
		else:
			return "run_left"
	else:
		if dir.y > 0:
			return "run_down"
		else:
			return "run_up"

func take_damage(amount):
	health -= amount
	if health <= 0:
		die()

func die():
	anim.play("death")
	queue_free() # удаляем объект после смерти
