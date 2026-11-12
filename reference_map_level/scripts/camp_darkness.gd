extends CanvasModulate
## The camp's night tint. When the camp is instanced inside another level (reference_map.tscn has its
## own "Night"), this one steps aside so only one CanvasModulate darkens the canvas.


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene != owner:
		queue_free()
