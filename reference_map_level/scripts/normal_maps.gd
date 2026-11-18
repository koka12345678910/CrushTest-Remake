extends Node
## normal_maps.gd — свет факелов ложится по рельефу HD-арта (reference_map).
##
## Карты нормалей печёт tools/normal_bake.gd в textures/normals/<имя>_n.png.
## Здесь при старте карты текстура каждого тайлового источника и спрайта,
## для которой есть нормаль, подменяется на CanvasTexture (рисунок + нормаль);
## сцена на диске не меняется.
##
## Свет считает normal_light.gdshaderinc (плоское освещено как раньше, склон
## к огню ярче, от огня темнее). Без этого light() Godot с нормалью затемнил
## бы почти всё, поэтому нормаль получает только то, что рисуется таким
## шейдером:
##   общий материал OcclusionFade — шейдер меняется на fade_lit.gdshader;
##   материалы ветра (wind_fade.gdshader) — light() в нём уже есть;
##   без материала — даётся lit_plain.gdshader.
## Узел или слой с чужим шейдером (земля, вода) не трогаем; источник тайлов,
## который рисует такой слой, остаётся без нормали.

const NORMAL_DIR := "res://reference_map_level/textures/normals/"
const FADE_LIT := preload("res://reference_map_level/shaders/fade_lit.gdshader")
const LIT_PLAIN := preload("res://reference_map_level/shaders/lit_plain.gdshader")
const WIND := preload("res://reference_map_level/shaders/wind_fade.gdshader")
const FADE_PLAIN := preload("res://Shaders/occlusion_fade_plain.gdshader")

@export var relief_strength := 1.8
@export var relief_height := 90.0
## Обрывы, каньон, лестницы — камень, рельеф можно сильнее
@export var rock_strength := 2.2
## Земля, трава, брусчатка (terrain_ground) и грязь лагеря (camp_ground)
@export var ground_strength := 1.8

## Земля собирается в своих шейдерах из плиток-массивов — им даются массивы
## нормалей той же раскладки (tools/normal_bake.gd, TILED)
const TERRAIN := preload("res://reference_map_level/shaders/terrain_ground.gdshader")
const CAMP_GROUND := preload("res://reference_map_level/shaders/camp_ground.gdshader")
const GROUND_TEX := {
	"ground_normals": NORMAL_DIR + "ground_layers_n.png",
	"cobble_normals": NORMAL_DIR + "cobble_layers_n.png",
}
const CAMP_TEX := {
	"mud_normal": NORMAL_DIR + "camp_mud_n.png",
	"ash_normal": NORMAL_DIR + "camp_ash_n.png",
}

## путь рисунка -> CanvasTexture
var _ct := {}
var _plain: ShaderMaterial
var _rock: ShaderMaterial
var _mats: Array[ShaderMaterial] = []
var stats := {}


func setup(map: Node, wind_mats: Array) -> void:
	_plain = _lit_mat(relief_strength)
	_rock = _lit_mat(rock_strength)
	# Общий материал окна прозрачности — на шейдер с light()
	var of := map.get_node_or_null("OcclusionFade")
	var fade: ShaderMaterial = of.get("_material") if of else null
	if fade and fade.shader == FADE_PLAIN:
		var keep := {}
		for u in fade.shader.get_shader_uniform_list(true):
			var nm := str(u["name"])
			keep[nm] = fade.get_shader_parameter(nm)
		fade.shader = FADE_LIT
		for nm in keep:
			if keep[nm] != null:
				fade.set_shader_parameter(nm, keep[nm])
		_add_mat(fade, relief_strength)
	for m in wind_mats:
		if m is ShaderMaterial:
			_add_mat(m, relief_strength)
	var layers: Array[TileMapLayer] = []
	var sprites: Array[Sprite2D] = []
	_collect(map, layers, sprites)
	stats["ground_materials"] = _apply_ground(layers, sprites)
	stats["tile_sources"] = _apply_tiles(layers)
	stats["sprites"] = _apply_sprites(sprites)
	stats["textures"] = _ct.size()


## Материалы земли: выставить массивы нормалей и включить рельеф. Материал
## общий (ground_material.tres) — меняется только в памяти, файл не трогаем
func _apply_ground(layers: Array[TileMapLayer], sprites: Array[Sprite2D]) -> int:
	var seen := {}
	var items: Array[CanvasItem] = []
	items.append_array(layers)
	items.append_array(sprites)
	for it in items:
		var m := it.material as ShaderMaterial
		if m == null or seen.has(m):
			continue
		var tex := {}
		if m.shader == TERRAIN:
			tex = GROUND_TEX
		elif m.shader == CAMP_GROUND:
			tex = CAMP_TEX
		else:
			continue
		seen[m] = true
		var ok := true
		for u in tex:
			if not ResourceLoader.exists(tex[u]):
				ok = false
				break
			m.set_shader_parameter(u, load(tex[u]))
		if not ok:
			continue
		m.set_shader_parameter("use_normals", true)
		_add_mat(m, ground_strength)
	return seen.size()


func _lit_mat(strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT_PLAIN
	_add_mat(m, strength)
	return m


func _add_mat(m: ShaderMaterial, strength: float) -> void:
	m.set_shader_parameter("relief_strength", strength)
	m.set_shader_parameter("relief_height", relief_height)
	_mats.append(m)


func _collect(n: Node, layers: Array[TileMapLayer], sprites: Array[Sprite2D]) -> void:
	for c in n.get_children():
		# Чужие сцены (враги, герой, лут) — не карта
		if c.scene_file_path != "" and not c.scene_file_path.begins_with("res://reference_map_level/"):
			continue
		if c is TileMapLayer:
			layers.append(c)
		elif c is Sprite2D:
			sprites.append(c)
		_collect(c, layers, sprites)


## Рисует ли это шейдер с нашим light()
func _lit(m: Material) -> bool:
	return m is ShaderMaterial and ((m as ShaderMaterial).shader in [FADE_LIT, LIT_PLAIN, WIND])


func _canvas_tex(diffuse: Texture2D) -> CanvasTexture:
	if diffuse == null or diffuse is CanvasTexture:
		return null
	var path := diffuse.resource_path
	if path == "":
		return null
	if _ct.has(path):
		return _ct[path]
	var np := NORMAL_DIR + path.get_file().get_basename() + "_n.png"
	if not ResourceLoader.exists(np):
		_ct[path] = null
		return null
	var ct := CanvasTexture.new()
	ct.diffuse_texture = diffuse
	ct.normal_texture = load(np)
	_ct[path] = ct
	return ct


func _apply_tiles(layers: Array[TileMapLayer]) -> int:
	# Источник получает нормаль, только если ВСЕ слои, где он нарисован,
	# рисуют его шейдером с light() (своим материалом тайла или слоя)
	var ok := {}
	var bad := {}
	for l in layers:
		var ts := l.tile_set
		if ts == null:
			continue
		for si in ts.get_source_count():
			var sid := ts.get_source_id(si)
			var src := ts.get_source(sid) as TileSetAtlasSource
			if src == null or _canvas_tex(src.texture) == null:
				continue
			if l.get_used_cells_by_id(sid).is_empty():
				continue
			if l.material == null:
				# Слой без материала — дадим ему lit_plain ниже
				ok[src] = true
				l.set_meta("_needs_lit", true)
			elif _lit(l.material) or _tiles_lit(src):
				ok[src] = true
			else:
				bad[src] = true
	var n := 0
	for src in ok:
		if bad.has(src):
			continue
		(src as TileSetAtlasSource).texture = _canvas_tex((src as TileSetAtlasSource).texture)
		n += 1
	for l in layers:
		if l.has_meta("_needs_lit"):
			l.remove_meta("_needs_lit")
			l.material = _plain
	stats["tile_sources_skipped"] = bad.size()
	return n


## У каждого тайла источника свой материал с light()
func _tiles_lit(src: TileSetAtlasSource) -> bool:
	for ti in src.get_tiles_count():
		var coords := src.get_tile_id(ti)
		for ai in src.get_alternative_tiles_count(coords):
			var td := src.get_tile_data(coords, src.get_alternative_tile_id(coords, ai))
			if td and not _lit(td.material):
				return false
	return true


func _apply_sprites(sprites: Array[Sprite2D]) -> int:
	var n := 0
	for s in sprites:
		# Разбиваемые бочки/ящики (breakables.gd) — кусок атласа: нормаль
		# берётся у атласа, кусок остаётся тем же
		var at := s.texture as AtlasTexture
		var ct := _canvas_tex(at.atlas if at else s.texture)
		if ct == null:
			continue
		var path := (at.atlas if at else s.texture).resource_path
		if s.material == null and not s.use_parent_material:
			s.material = _rock if path.contains("/terrain/") else _plain
		elif not _lit(s.material):
			continue
		if at:
			var na := AtlasTexture.new()
			na.atlas = ct
			na.region = at.region
			s.texture = na
		else:
			s.texture = ct
		n += 1
	return n
