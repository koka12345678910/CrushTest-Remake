extends GPUParticles2D

@export var ember_count := 35
@export var base_color := Color(1.0, 0.55, 0.08, 1.0)
@export var spread_radius := 18.0


func _ready() -> void:
	_setup_material()
	emitting = true


func _setup_material() -> void:
	var mat := ParticleProcessMaterial.new()

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = spread_radius
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 35.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 180.0
	mat.gravity = Vector3(0.0, 20.0, 0.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.8
	mat.turbulence_noise_scale = 2.0
	mat.emission_sphere_radius = 18.0

	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.add_point(0.0, Color(1.0, 0.85, 0.3, 1.0))
	g.add_point(0.3, base_color)
	g.add_point(0.7, Color(0.7, 0.15, 0.05, 0.7))
	g.add_point(1.0, Color(0.2, 0.05, 0.02, 0.0))
	grad.gradient = g
	mat.color_ramp = grad

	mat.scale_min = 1.5
	mat.scale_max = 3.5

	process_material = mat
	texture = _make_ember_texture()

	lifetime = 3.0
	amount = ember_count
	randomness = 0.7
	explosiveness = 0.0


func _make_ember_texture() -> ImageTexture:
	var size: int = 8
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x: int in range(size):
		for y: int in range(size):
			var dist: float = Vector2(x, y).distance_to(center)
			var alpha: float = clamp(1.0 - dist / (size / 2.0), 0.0, 1.0)
			alpha = pow(alpha, 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
