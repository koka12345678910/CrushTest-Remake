extends GPUParticles2D
## RainEffect.gd
## Настраивает систему частиц дождя через код —
## не нужно вручную создавать .tres файл материала.

## Дождь — фоновая атмосфера, а не акцентный эффект: неяркий, некустый и
## помедленнее, чтобы не бил в глаза на переднем плане меню
@export var rain_color := Color(0.65, 0.72, 0.82, 0.2)
@export var drop_speed_min := 750.0
@export var drop_speed_max := 1150.0
# Дистанция = скорость × lifetime. При lifetime 1.4 капли долетали почти до
# самого низа экрана — там, где фон (тёмная земля/рыцарь) темнее неба, они
# читались контрастнее, чем везде выше, и казалось, что дождь виден только
# внизу. Укорачиваем жизнь капли, чтобы она гасла ещё в верхней/средней
# части экрана, не доходя до тёмного переднего плана
@export var lifetime_seconds := 0.75
@export var wind_angle_deg := -12.0  # наклон дождя влево


func _ready() -> void:
	_setup_material()
	emitting = true


func _setup_material() -> void:
	var mat := ParticleProcessMaterial.new()

	# Область спавна — широкая горизонтальная полоса сверху
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1200.0, 1.0, 1.0)

	# Направление: вниз + наклон ветра
	var angle_rad := deg_to_rad(90.0 + wind_angle_deg)
	mat.direction = Vector3(cos(angle_rad), sin(angle_rad), 0.0)
	mat.spread = 2.0
	mat.initial_velocity_min = drop_speed_min
	mat.initial_velocity_max = drop_speed_max

	# Гравитация не нужна — скорость и так большая
	mat.gravity = Vector3.ZERO

	# Цвет капли: полупрозрачный, слегка светится
	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.add_point(0.0, rain_color)
	g.add_point(0.8, rain_color)
	g.add_point(1.0, Color(rain_color.r, rain_color.g, rain_color.b, 0.0))
	grad.gradient = g
	mat.color_ramp = grad

	# Масштаб: вытянутый по вертикали — имитирует капли а не точки
	mat.scale_min = 0.7
	mat.scale_max = 1.0

	process_material = mat

	# Текстура капли — генерируем программно
	texture = _make_drop_texture()

	# Параметры самого GPUParticles2D — лёгкий фоновый дождь, не ливень.
	# amount подобран под ту же плотность (частиц/сек), что и раньше, просто
	# при укороченном lifetime
	lifetime = lifetime_seconds
	amount = int(643.0 * lifetime_seconds)
	one_shot = false
	explosiveness = 0.0
	randomness = 0.4


func _make_drop_texture() -> ImageTexture:
	## Создаёт текстуру капли дождя 2x14 пикселей
	var img := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	for y in range(14):
		var alpha := float(y) / 13.0
		img.set_pixel(0, y, Color(1, 1, 1, alpha * 0.55))
		img.set_pixel(1, y, Color(1, 1, 1, alpha * 0.55))
	return ImageTexture.create_from_image(img)
