extends Node2D

var move_direction := Vector2.ZERO
var speed := 140.0
var anim_name := "berserk_hit_1"

func _ready():
	scale *= randf_range(0.9, 1.2)
	$AnimatedSprite2D.play(anim_name)

func _process(delta):
	position += move_direction * speed * delta
	speed = lerp(speed, 0.0, 6 * delta)

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
