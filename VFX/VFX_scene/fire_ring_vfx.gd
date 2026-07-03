extends Node2D
@export var start_scale := 0.6
@export var end_scale := 2.5
@export var grow_duration := 0.6
@export var hold_before_fade := 1.0
@export var fade_duration := 0.3

func _ready():
	scale = Vector2.ONE * start_scale
	modulate.a = 1.0
	$AnimatedSprite2D.play("fire_ring")
	$AnimatedSprite2D.modulate = Color(2.5, 2.0, 1.2, 1.0)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * end_scale, grow_duration).set_ease(Tween.EASE_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(hold_before_fade)
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN)
	
	await fade_tween.finished
	queue_free()
