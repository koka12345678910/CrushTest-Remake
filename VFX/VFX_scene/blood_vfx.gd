extends Node2D

func _ready():
	scale *= randf_range(0.8, 1.2)  # небольшая случайность размера
	rotation = randf_range(0, TAU)   # случайный поворот для разнообразия
	$AnimatedSprite2D.play("blood")

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
	
