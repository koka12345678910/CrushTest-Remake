extends CanvasLayer
## Постоянная цветокоррекция уровня (десатурация + контраст + виньетка) —
## в отличие от damage_vignette/exhaust_vignette это не вспышка на событие,
## а всегда включённый грейдинг, задающий общее мрачное настроение сцены.
## layer=0 в сцене — рисуется НАД миром, но ПОД HUD-слоями игрока (у тех
## layer по умолчанию), поэтому здоровье/стамину/иконки не искажает.

@export_range(0.0, 1.0) var desaturation := 0.12:
	set(value):
		desaturation = value
		_apply()
@export_range(0.5, 2.0) var contrast := 1.02:
	set(value):
		contrast = value
		_apply()
@export var shadow_tint := Color(0.96, 0.97, 1.0):
	set(value):
		shadow_tint = value
		_apply()
@export_range(0.0, 1.0) var vignette_strength := 0.16:
	set(value):
		vignette_strength = value
		_apply()
@export_range(0.1, 1.5) var vignette_radius := 0.85:
	set(value):
		vignette_radius = value
		_apply()

@onready var rect: ColorRect = $ColorRect


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_instance_valid(rect):
		return
	var mat := rect.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("desaturation", desaturation)
	mat.set_shader_parameter("contrast", contrast)
	mat.set_shader_parameter("shadow_tint", shadow_tint)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
	mat.set_shader_parameter("vignette_radius", vignette_radius)
