extends Node2D

func _ready():
	$AnimatedSprite2D.play("turn")
	await $AnimatedSprite2D.animation_finished
	queue_free()
