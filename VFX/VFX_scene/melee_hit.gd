extends Node2D

var move_direction := Vector2.ZERO
var speed := 140.0

func _ready():
	scale *= randf_range(0.9, 1.2)
	$AnimatedSprite2D.play("hit")

func _process(delta):
	# движение вперёд
	position += move_direction * speed * delta
	
	# плавное замедление
	speed = lerp(speed, 0.0, 6 * delta)

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
