extends MultiMeshInstance2D
## Мягкие контактные тени под домами, деревьями и пропсами — одним MultiMesh.
## Координаты лежат в data (их считает tools/polish_reference_map.gd), сама
## сетка собирается при загрузке уровня: готовый MultiMesh в сцене не хранится,
## потому что из консольного Godot его буфер не сохраняется.

## По 5 чисел на тень: x, y, полуширина, полувысота, непрозрачность
@export var data: PackedFloat32Array


func _ready() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	texture = tex

	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = quad
	var count := data.size() / 5
	mm.instance_count = count
	for i in count:
		var o := i * 5
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(data[o + 2], data[o + 3]), 0.0, Vector2(data[o], data[o + 1])))
		mm.set_instance_color(i, Color(1, 1, 1, data[o + 4]))
	multimesh = mm
