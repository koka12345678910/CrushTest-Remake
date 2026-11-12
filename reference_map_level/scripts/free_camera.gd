extends Camera2D
## Preview camera for running a level on its own: WASD / arrows to pan (Shift = faster), mouse wheel
## to zoom. It switches itself off when the level is instanced inside another scene.

@export var speed := 900.0


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene != owner:
		enabled = false
		set_process(false)
		set_process_unhandled_input(false)
		return
	make_current()


func _process(delta: float) -> void:
	var d := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var boost := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	position += d * speed * boost * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = (zoom * 1.1).clamp(Vector2(0.15, 0.15), Vector2(4, 4))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = (zoom / 1.1).clamp(Vector2(0.15, 0.15), Vector2(4, 4))
