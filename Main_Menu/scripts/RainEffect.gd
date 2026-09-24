extends GPUParticles2D
## RainEffect.gd
## Настраивает систему частиц дождя через код —
## не нужно вручную создавать .tres файл материала.
##
## Параметризован так, чтобы одним и тем же скриптом собирать разные слои
## дождя на одной сцене (см. MainMenu.tscn: "Rain" — проливной, "RainFine" —
## мелкая морось поверх него), без копипасты кода под каждый вид дождя.

## Дождь лежит МЕЖДУ дальним фоном и слоем рыцаря (см. MainMenu.tscn), так
## что непрозрачные земля/силуэт рыцаря на переднем плане естественным
## образом перекрывают низ дождя — поэтому даже плотный проливной вариант не
## бьёт в глаза на тёмном переднем плане, как было бы поверх всей сцены
@export var rain_color := Color(0.68, 0.74, 0.85, 0.35)
@export var drop_speed_min := 950.0
@export var drop_speed_max := 1500.0
@export var lifetime_seconds := 1.3
@export var wind_angle_deg := -12.0  # наклон дождя влево

# Плотность (капель в секунду), масштаб капли и альфа текстуры — раньше были
# захардкожены в _setup_material()/_make_drop_texture(). Вынесены в @export,
# чтобы "мелкий" слой мороси мог быть гуще числом, но мельче и бледнее
# каждой отдельной капли, а не просто копией проливного с другой скоростью
@export var density_per_second := 1400.0
@export var drop_scale_min := 0.85
@export var drop_scale_max := 1.3
@export_range(0.0, 1.0) var drop_alpha_mult := 0.75


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
	mat.scale_min = drop_scale_min
	mat.scale_max = drop_scale_max

	process_material = mat

	# Текстура капли — генерируем программно
	texture = _make_drop_texture()

	lifetime = lifetime_seconds
	amount = int(density_per_second * lifetime_seconds)
	one_shot = false
	explosiveness = 0.0
	randomness = 0.4


func _make_drop_texture() -> ImageTexture:
	## Создаёт текстуру капли дождя 2x14 пикселей
	var img := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	for y in range(14):
		var alpha := float(y) / 13.0
		img.set_pixel(0, y, Color(1, 1, 1, alpha * drop_alpha_mult))
		img.set_pixel(1, y, Color(1, 1, 1, alpha * drop_alpha_mult))
	return ImageTexture.create_from_image(img)
