extends Node
## occlusion_fade_apply.gd — "окно" прозрачности вокруг героя для готовых карт.
##
## На кладбище материал Shaders/occlusion_fade.gdshader прописан у каждого
## пропса в сцене. У присланных карт (reference_map: сотни спрайтов, тайловые
## кроны, лагерь отдельной сценой) так делать незачем — этот узел при старте
## уровня раздаёт один общий материал всему, что нарисовано в targets.
##
## Режим глубины 1: предмет становится полупрозрачным вокруг героя, только если
## стоит ПЕРЕД ним. Линия сортировки — начало координат канвас-айтема, ровно то,
## по чему Godot сортирует y-sort: у спрайта это его позиция, у y-сортированного
## тайлового слоя — точка сортировки каждой группы тайлов. Поэтому смещение 0.
##
## Не трогает:
##   - узлы, у которых уже есть свой материал (огоньки, туман и т.п.);
##   - инстансы чужих сцен (враги, герой, лут) — только сцены из allowed_scene_dirs;
##   - то, что создано кодом (owner == null): костры, эффекты, кукла напарника.

@export var targets: Array[NodePath] = []
## Инстансы сцен из этих папок считаются частью карты (лагерь внутри карты)
@export var allowed_scene_dirs: PackedStringArray = []

@export_group("Окно")
@export_range(0.0, 1.0) var min_alpha := 0.35
@export var radius := 30.0
@export var stretch_y := 1.35
@export var softness := 14.0
@export var window_offset := Vector2(0, -4)

## Не occlusion_fade.gdshader: тот умножает цвет на текстуру дважды (см. шапку
## occlusion_fade_plain), и карта стала бы заметно темнее
const SHADER := preload("res://Shaders/occlusion_fade_plain.gdshader")

var _material: ShaderMaterial
var applied := 0


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("occlusion_min_alpha", min_alpha)
	_material.set_shader_parameter("occlusion_radius", radius)
	_material.set_shader_parameter("occlusion_stretch_y", stretch_y)
	_material.set_shader_parameter("occlusion_softness", softness)
	_material.set_shader_parameter("occlusion_offset", window_offset)
	_material.set_shader_parameter("occlusion_depth_mode", 1)
	_material.set_shader_parameter("occlusion_sort_offset", 0.0)
	for path in targets:
		var n := get_node_or_null(path)
		if n:
			_walk(n)


func _walk(n: Node) -> void:
	for ch in n.get_children():
		if ch.scene_file_path != "" and not _is_map_scene(ch.scene_file_path):
			continue
		if ch.owner == null:
			continue
		if (ch is Sprite2D or ch is TileMapLayer or ch is AnimatedSprite2D or ch is Polygon2D) \
				and (ch as CanvasItem).material == null and not (ch as CanvasItem).use_parent_material:
			(ch as CanvasItem).material = _material
			applied += 1
		_walk(ch)


func _is_map_scene(path: String) -> bool:
	for dir in allowed_scene_dirs:
		if path.begins_with(dir):
			return true
	return false
