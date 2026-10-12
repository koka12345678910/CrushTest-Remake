extends Node2D
## Лунный свет сквозь облака: вместо ровной заливки по карте медленно ползут
## светлые прогалины и тени от облаков. Это настоящий Light2D (ADD), а не
## наложенный сверху спрайт: он умножается на цвет поверхности, поэтому
## тёмные стволы/стены остаются тёмными, а светлеют трава, дорожки и надгробия.
##
## Облака — бесшовная шумовая текстура; ею "плиткой" (сетка 2x2 PointLight2D)
## накрыта вся карта, сетка сдвигается по ветру и заворачивается на период
## текстуры — движение бесконечное, без разворотов и видимых краёв.

## Прямоугольник карты в пикселях мира — его свет должен накрыть целиком
@export var area := Rect2(0, 0, 3072, 1536)
@export var color := Color(0.6, 0.72, 0.95)
## Яркость в самых светлых прогалинах (в тени облаков ~в 5 раз меньше)
@export var energy := 0.3
## Ветер, px/с: куда и как быстро плывут облака
@export var wind := Vector2(14.0, 6.0)
## Размер одной плитки облаков в пикселях мира (= период шума)
@export var period := 4096.0
## Частота шума: больше — облака мельче и чаще
@export var cloud_frequency := 0.011

const TEX_SIZE := 512

var _lights: Array[PointLight2D] = []
var _cells := Vector2i.ONE
var _drift := Vector2.ZERO


func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = cloud_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4

	# Кривая "облачности": большая часть неба — полупрозрачные облака (свет
	# слабый, но не ноль), между ними — прогалины, где луна светит в полную силу
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.72, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.06, 0.06, 0.06), Color(0.16, 0.16, 0.16),
		Color(0.8, 0.8, 0.8), Color(1, 1, 1),
	])

	var tex := NoiseTexture2D.new()
	tex.width = TEX_SIZE
	tex.height = TEX_SIZE
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp

	# Сетка плиток с запасом в одну плитку — чтобы при сдвиге до period
	# карта оставалась накрыта
	_cells = Vector2i(ceili(area.size.x / period) + 1, ceili(area.size.y / period) + 1)
	for i in _cells.x * _cells.y:
		var l := PointLight2D.new()
		l.texture = tex
		l.texture_scale = period / TEX_SIZE
		l.color = color
		l.energy = energy
		l.blend_mode = Light2D.BLEND_MODE_ADD
		l.shadow_enabled = false
		# Под крышей луна на героя не светит (Levels/house_interior.gd)
		l.add_to_group("outdoor_light")
		add_child(l)
		_lights.append(l)
	_place()


func _process(delta: float) -> void:
	_drift = Vector2(fposmod(_drift.x + wind.x * delta, period), fposmod(_drift.y + wind.y * delta, period))
	_place()


func _place() -> void:
	var origin := area.position - Vector2(period, period) + _drift
	for i in _lights.size():
		var c := Vector2(i % _cells.x, floori(float(i) / _cells.x))
		_lights[i].position = origin + (c + Vector2(0.5, 0.5)) * period
