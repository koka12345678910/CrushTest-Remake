extends Node
## hero_silhouette.gd — герой виден сквозь дома, стены и кроны силуэтом,
## а не дырой прозрачности (Immersion/HeroSilhouette).
##
## Маска: невидимый SubViewport с тем же миром (world_2d), что и игра, но
## рисует только тело героя — у его спрайтов и всех их родителей включён
## слой видимости MASK_LAYER, а у вьюпорта canvas_cull_mask = только он.
## Своя камера вьюпорта ходит за героем; кадр — текстура hero_mask в мировом
## прямоугольнике hero_mask_rect.
##
## Шейдеры предметов (shaders/fade_lit.gdshader — дома, стены, пропсы;
## shaders/wind_fade.gdshader — кроны, кусты, ткань) через
## shaders/hero_silhouette.gdshaderinc рисуют на себе контур и лёгкую
## заливку там, где предмет стоит перед героем. Окно прозрачности гасится
## (occlusion_min_alpha = 1). Цвет — лунный холодный, у огня тёплый
## (FireFX.warmth_at).

const FADE_LIT := preload("res://reference_map_level/shaders/fade_lit.gdshader")
const WIND_FADE := preload("res://reference_map_level/shaders/wind_fade.gdshader")
## Слой видимости 20 — только для маски
const MASK_LAYER := 1 << 19
## Размер маски (мировые px) и центр относительно ног героя: с запасом под
## замах оружия и перекат
const MASK_SIZE := Vector2i(192, 208)
const MASK_CENTER := Vector2(0, -44)
const MOON := Color(0.42, 0.54, 0.82)
const WARM := Color(0.88, 0.5, 0.22)

var stats := {}

var _map: Node
var _mats: Array[ShaderMaterial] = []
var _vp: SubViewport
var _cam: Camera2D
var _hero: Node2D
var _on := 0.0
var _warm := 0.0


func setup(map: Node) -> void:
	_map = map
	_walk(map)
	_vp = SubViewport.new()
	_vp.name = "HeroMask"
	_vp.size = MASK_SIZE
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.world_2d = get_viewport().world_2d
	_vp.canvas_cull_mask = MASK_LAYER
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = false
	_vp.add_child(_cam)
	_cam.make_current()
	var tex := _vp.get_texture()
	for m in _mats:
		m.set_shader_parameter("hero_mask", tex)
		m.set_shader_parameter("occlusion_min_alpha", 1.0)
	stats = {"materials": _mats.size()}


func _walk(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			_take((c as CanvasItem).material)
		if c is TileMapLayer and (c as TileMapLayer).tile_set:
			var ts := (c as TileMapLayer).tile_set
			for si in ts.get_source_count():
				var src := ts.get_source(ts.get_source_id(si)) as TileSetAtlasSource
				if src == null:
					continue
				for ti in src.get_tiles_count():
					var coords := src.get_tile_id(ti)
					for ai in src.get_alternative_tiles_count(coords):
						var td := src.get_tile_data(coords, src.get_alternative_tile_id(coords, ai))
						if td:
							_take(td.material)
		_walk(c)


func _take(m: Material) -> void:
	var sm := m as ShaderMaterial
	if sm and (sm.shader == FADE_LIT or sm.shader == WIND_FADE) and not _mats.has(sm):
		_mats.append(sm)


## Тело героя — на слой маски (и все родители до карты: вьюпорт рисует
## предмет, только если слой есть у него и у каждого родителя)
func _bind(hero: Node2D) -> void:
	_hero = hero
	for s in hero.find_children("*", "Node2D", true, false):
		if not (s is Sprite2D or s is AnimatedSprite2D):
			continue
		if _under_layer(s, hero) or String(s.name).to_lower().contains("shadow"):
			continue
		var p: Node = s
		while p and p != _map.get_parent():
			if p is CanvasItem:
				(p as CanvasItem).visibility_layer |= MASK_LAYER
			p = p.get_parent()


func _under_layer(n: Node, top: Node) -> bool:
	var p := n.get_parent()
	while p and p != top:
		if p is CanvasLayer:
			return true
		p = p.get_parent()
	return false


func _process(delta: float) -> void:
	if not is_instance_valid(_hero):
		var h := get_tree().get_first_node_in_group("player") as Node2D
		if h and _map.is_ancestor_of(h):
			_bind(h)
	var want := 0.0
	if is_instance_valid(_hero) and _hero.is_visible_in_tree():
		want = 1.0
		var center := _hero.global_position + MASK_CENTER
		_cam.global_position = center
		var rect := Rect2(center - Vector2(MASK_SIZE) * 0.5, Vector2(MASK_SIZE))
		var fx := get_parent().get_node_or_null("FireFX")
		var w := 0.0
		if fx and fx.has_method("warmth_at"):
			w = float(fx.call("warmth_at", _hero.global_position))
		_warm = move_toward(_warm, w, delta * 1.5)
		for m in _mats:
			m.set_shader_parameter("hero_mask_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_on = move_toward(_on, want, delta * 3.0)
	# Ночной CanvasModulate умножит цвет силуэта — заранее делим на него
	var comp := Vector3.ONE
	var nm := _map.get_node_or_null("NightModulate") as CanvasModulate
	if nm and nm.visible:
		comp = Vector3(1.0 / maxf(nm.color.r, 0.08), 1.0 / maxf(nm.color.g, 0.08), 1.0 / maxf(nm.color.b, 0.08))
	var col := MOON.lerp(WARM, _warm)
	for m in _mats:
		m.set_shader_parameter("hero_sil_on", _on)
		m.set_shader_parameter("hero_sil_comp", comp)
		m.set_shader_parameter("hero_sil_color", col)
