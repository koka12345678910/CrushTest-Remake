extends Node2D

func _ready():
	$AnimatedSprite2D.play("start_run")
	await $AnimatedSprite2D.animation_finished
	queue_free()
