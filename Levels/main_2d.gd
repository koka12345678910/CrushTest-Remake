extends Node2D

@onready var player = $Player

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.name == "Player":
		player.anim.play()
		
