extends Node2D
## hero_light.gd — герой живёт в свете карты (Immersion/HeroLight).
##
## 1. Свет на фигуре. Материал тела героя (копия) получает
##    shaders/hero_lit.gdshader: та же палитра, что у Shaders/sprite_detail, но
##    светотень — от настоящих источников: огонь перед героем освещает его,
##    огонь за спиной оставляет фигуру в тени с ярким контуром. Нарисованная
##    художником тень под ногами вырезана.
## 2. Тень от света. До MAX_SHADOWS самых сильных источников рядом (огонь,
##    фонари, заклинания) и луна кладут на землю тень героя — его текущий
##    кадр, от источника прочь. Чем ближе огонь — тем длиннее тень; чем
##    сильнее источник по сравнению с остальным светом — тем она плотнее.
##    Плюс мягкая контактная тень у ног.
## 3. Загороженный свет. Если между огнём и героем стена или дом (луч по
##    коллизии мира), огонь его почти не освещает и тени от него нет.

const HERO_LIT := preload("res://reference_map_level/shaders/hero_lit.gdshader")
const SHADOW_SHADER := preload("res://reference_map_level/shaders/hero_shadow.gdshader")

const MAX_SHADOWS := 3
## Тени героя — на земле: над землёй и наземными эффектами (кровь -16…-14),
## под персонажами и предметами (Objects, z 0)
const SHADOW_Z := -13
## Высота огня, мировые px: тень длиной в рост героя на таком расстоянии
const LIGHT_HEIGHT := 70.0
## Насколько ниже экрана по y лежит "пол": тень на земле короче вдоль y
const GROUND_SQUASH := 0.72
## Тень от луны: высокая луна сверху-слева (как MOON_DIR в normal_light)
const MOON_SHADOW_DIR := Vector2(0.5, 0.62)
const MOON_SHADOW_LEN := 0.6
const WORLD_MASK := 1

@export var shadow_strength := 1.0

var stats := {}

var _map: Node
var _hero: Node2D
var _sprite: AnimatedSprite2D
var _mat: ShaderMaterial
var _lights: Array[PointLight2D] = []
var _scan_t := 0.0
var _drawers: Array = []        # ShadowDrawer: [0..MAX_SHADOWS-1] огни, последний — луна
var _contact: ShadowBlob
var _holder: Node2D
var _feet_cache := {}           # "rid:region" -> Vector3(feet_x, feet_y, top_y), тексели кадра
var _images := {}               # RID атласа -> Image
var _alpha := []                # сглаженная плотность теней
var _exposure := 1.0
var _grade: ShaderMaterial


## Тень — кадр героя, положенный на землю
class ShadowDrawer:
	extends Node2D
	var tex: Texture2D
	var rect := Rect2()
	var xf := Transform2D.IDENTITY
	var alpha := 0.0

	func _draw() -> void:
		if tex == null or alpha <= 0.004:
			return
		draw_set_transform_matrix(xf)
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))


## Контактная тень: мягкое пятно у ног (свет снизу под героя не попадает)
class ShadowBlob:
	extends Node2D
	var tex: Texture2D
	var size := Vector2(30, 11)
	var alpha := 0.0

	func _draw() -> void:
		if tex and alpha > 0.004:
			draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color(1, 1, 1, alpha))


func setup(map: Node) -> void:
	_map = map
	process_priority = 1001   # после FireFX: огни уже сдвинуты и вспыхнули
	_holder = Node2D.new()
	_holder.name = "HeroShadows"
	_holder.z_as_relative = false
	_holder.z_index = SHADOW_Z
	add_child(_holder)
	var blob := GradientTexture2D.new()
	blob.width = 64
	blob.height = 64
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0.02, 0.85), Color(0, 0, 0.02, 0.45), Color(0, 0, 0.02, 0.0)])
	blob.gradient = g
	_contact = ShadowBlob.new()
	_contact.tex = blob
	_contact.top_level = true
	_holder.add_child(_contact)
	for i in MAX_SHADOWS + 1:
		var d := ShadowDrawer.new()
		d.top_level = true
		var m := ShaderMaterial.new()
		m.shader = SHADOW_SHADER
		d.material = m
		_holder.add_child(d)
		_drawers.append(d)
		_alpha.append(0.0)
	_scan()


# ------------------------------------------------------------------ герой

func _bind(hero: Node2D) -> void:
	_hero = hero
	_sprite = null
	for s in hero.find_children("*", "AnimatedSprite2D", true, false):
		var m := (s as CanvasItem).material as ShaderMaterial
		if m and m.shader and String(m.shader.resource_path).ends_with("sprite_detail.gdshader"):
			_sprite = s
			break
	if _sprite == null:
		return
	# Копия материала: на кладбище и у других героев всё как было
	var base := _sprite.material as ShaderMaterial
	_mat = base.duplicate() as ShaderMaterial
	_mat.shader = HERO_LIT
	# Нарисованная светотень с одной стороны больше не нужна — её даёт свет;
	# остаётся проработка формы и палитра
	_mat.set_shader_parameter("light_strength", float(_param(base, "light_strength")) * 0.3)
	_mat.set_shader_parameter("shadow_strength", float(_param(base, "shadow_strength")) * 0.35)
	_sprite.material = _mat
	# Свечение вокруг героя — ровная подсветка, а не источник сбоку:
	# hero_lit узнаёт его по альфе цвета 0.75
	var glow := hero.get_node_or_null("PlayerGlow") as PointLight2D
	if glow:
		glow.color.a = 0.75
	stats["hero"] = String(hero.name)


func _param(m: ShaderMaterial, n: String) -> Variant:
	var v: Variant = m.get_shader_parameter(n)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), n)
	return v if v != null else 0.0


## Источники света карты, кроме луны, свечения героя и копий для тела
func _scan() -> void:
	_lights.clear()
	var moon := _map.get_node_or_null("Moonlight")
	for l in _map.find_children("*", "PointLight2D", true, false):
		var pl := l as PointLight2D
		if pl.texture == null or (pl.range_item_cull_mask & 1) == 0:
			continue
		if moon and moon.is_ancestor_of(pl):
			continue
		if pl.name == "PlayerGlow" or (is_instance_valid(_hero) and _hero.is_ancestor_of(pl)):
			continue
		_lights.append(pl)
	stats["lights"] = _lights.size()


# ------------------------------------------------------------------ кадр

func _process(delta: float) -> void:
	if not is_instance_valid(_hero) or not is_instance_valid(_sprite):
		var h := get_tree().get_first_node_in_group("player") as Node2D
		if h and _map.is_ancestor_of(h):
			_bind(h)
		if not is_instance_valid(_sprite):
			_hide_all()
			return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.75
		_scan()
	if not _sprite.is_visible_in_tree():
		_hide_all()
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		_hide_all()
		return
	var frame_size := tex.get_size()
	var feet_info := _feet(tex)          # тексели кадра: x ног, y ног, y макушки
	# Кадр в локальных координатах спрайта (центр кадра — 0)
	var rect := Rect2(-frame_size * 0.5 + _sprite.offset, frame_size)
	if not _sprite.centered:
		rect.position = _sprite.offset
	var pf := rect.position + Vector2(feet_info.x, feet_info.y)
	var g := _sprite.global_transform
	var flip := -1.0 if _sprite.flip_h else 1.0
	if _sprite.flip_h:
		pf.x = rect.position.x + frame_size.x - feet_info.x
	var feet: Vector2 = g * pf
	var sx := g.x.length()
	var sy := g.y.length()

	# Сколько света откуда: окружение, луна, огни
	var ambient := 0.12
	var nm := _map.get_node_or_null("NightModulate") as CanvasModulate
	if nm and nm.visible:
		ambient = _lum(nm.color)
	var moon_i := _moon_light()
	var cands: Array = []   # [сила, свет, расстояние]
	var space := get_world_2d().direct_space_state
	var blocked: Array[Vector4] = []
	var screen_xf := get_viewport().get_final_transform() * get_viewport().get_canvas_transform()
	for l in _lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.energy <= 0.01:
			continue
		var lp := l.global_position
		var r := l.texture.get_width() * l.texture_scale * 0.5 * absf(l.global_scale.x)
		var dist := lp.distance_to(feet)
		if dist >= r:
			continue
		var x := dist / r
		var fall := pow(1.0 - x, 1.4)
		var inten := l.energy * fall * _lum(l.color)
		if inten < 0.02:
			continue
		if _blocked(space, feet, lp):
			if blocked.size() < 4:
				var sp := screen_xf * lp
				blocked.append(Vector4(sp.x, sp.y, 0, 0))
			continue
		cands.append([inten, l, dist])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var total := ambient + moon_i
	for c in cands:
		total += float(c[0])
	_expose(total, delta)
	if _mat:
		var arr: Array[Vector4] = []
		for b in blocked:
			arr.append(b)
		while arr.size() < 4:
			arr.append(Vector4.ZERO)
		_mat.set_shader_parameter("blocked", arr)
		_mat.set_shader_parameter("blocked_n", blocked.size())

	# Тени от огней
	var fh := maxf(feet_info.y - feet_info.z, 8.0)
	for i in MAX_SHADOWS:
		var d: ShadowDrawer = _drawers[i]
		var want := 0.0
		if i < cands.size():
			var c: Array = cands[i]
			var l: PointLight2D = c[1]
			var dist: float = c[2]
			var dir := (feet - l.global_position)
			dir = dir.normalized() if dir.length() > 0.5 else Vector2.DOWN
			var length := clampf(dist / LIGHT_HEIGHT, 0.3, 2.4)
			want = clampf(float(c[0]) / total * 1.5, 0.0, 0.8) * shadow_strength
			_place(d, tex, rect, pf, feet, dir, length, sx, sy, flip, frame_size, feet_info)
		_alpha[i] = move_toward(float(_alpha[i]), want, delta * 3.0)
		d.alpha = _alpha[i]
		d.queue_redraw()
	# Тень от луны — короткая, к низу-вправо
	var md: ShadowDrawer = _drawers[MAX_SHADOWS]
	var mwant := clampf(moon_i / total * 1.3, 0.0, 0.55) * shadow_strength
	_place(md, tex, rect, pf, feet, MOON_SHADOW_DIR.normalized(), MOON_SHADOW_LEN, sx, sy, flip, frame_size, feet_info)
	_alpha[MAX_SHADOWS] = move_toward(float(_alpha[MAX_SHADOWS]), mwant, delta * 2.0)
	md.alpha = _alpha[MAX_SHADOWS]
	md.queue_redraw()
	# Контактная тень: всегда, плотнее в темноте и у яркого света рядом
	_contact.global_position = feet + Vector2(0, -1)
	_contact.size = Vector2(maxf(fh * sx * 0.55, 14.0), maxf(fh * sx * 0.2, 6.0))
	_contact.alpha = 0.55
	_contact.queue_redraw()


func _place(d: ShadowDrawer, tex: Texture2D, rect: Rect2, pf: Vector2, feet: Vector2, dir: Vector2,
		length: float, sx: float, sy: float, flip: float, frame_size: Vector2, feet_info: Vector3) -> void:
	# Ширина тени — поперёк направления; ось перпендикуляра — вправо по экрану
	var perp := Vector2(-dir.y, dir.x)
	if perp.x < 0.0 or (absf(perp.x) < 0.001 and perp.y < 0.0):
		perp = -perp
	var ax := perp * sx * 0.9
	var ay := -dir * sy * length
	ax.y *= GROUND_SQUASH
	ay.y *= GROUND_SQUASH
	# Точка ног кадра (в координатах спрайта, как он нарисован) — в ноги героя
	var basis := Transform2D(ax, ay, Vector2.ZERO)
	basis.origin = feet - basis.basis_xform(pf)
	d.xf = basis
	d.tex = tex
	# Отражённый кадр: тот же прямоугольник, развёрнутая текстура (как у Godot)
	d.rect = Rect2(rect.position, Vector2(-rect.size.x, rect.size.y)) if flip < 0.0 else rect
	var m := d.material as ShaderMaterial
	var at := tex as AtlasTexture
	if at and at.atlas:
		var asz := at.atlas.get_size()
		m.set_shader_parameter("region", Vector4(at.region.position.x / asz.x, at.region.position.y / asz.y,
				at.region.size.x / asz.x, at.region.size.y / asz.y))
	else:
		m.set_shader_parameter("region", Vector4(0, 0, 1, 1))
	m.set_shader_parameter("feet_v", feet_info.y / frame_size.y)
	m.set_shader_parameter("body_h", maxf(feet_info.y - feet_info.z, 8.0) / frame_size.y)


## Между героем и огнём — стена или дом? Луч по коллизии мира от ног к огню;
## упор у самого огня (факел на стене, костёр в кольце) не считается
func _blocked(space: PhysicsDirectSpaceState2D, feet: Vector2, lp: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(feet + Vector2(0, -6), lp, WORLD_MASK)
	q.collide_with_areas = false
	q.hit_from_inside = false
	if is_instance_valid(_hero) and _hero is CollisionObject2D:
		q.exclude = [(_hero as CollisionObject2D).get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	return (hit["position"] as Vector2).distance_to(lp) > 40.0


func _moon_light() -> float:
	var moon := _map.get_node_or_null("Moonlight")
	if moon == null or not moon.is_visible_in_tree():
		return 0.0
	var e := 0.0
	for c in moon.get_children():
		if c is PointLight2D:
			e = maxf(e, (c as PointLight2D).energy * (c as PointLight2D).color.a)
	var col: Color = moon.get("color") if moon.get("color") != null else Color.WHITE
	# Средняя прозрачность облаков в лунной текстуре ~0.75
	return e * _lum(col) * 0.75


func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


func _hide_all() -> void:
	for d in _drawers:
		(d as ShadowDrawer).alpha = 0.0
		(d as ShadowDrawer).queue_redraw()
	if _contact:
		_contact.alpha = 0.0
		_contact.queue_redraw()


## Где в кадре ноги и макушка (тексели кадра): нижняя строка тела, среднее
## x по ней, верхняя строка. Считается один раз на кадр анимации
func _feet(tex: Texture2D) -> Vector3:
	var at := tex as AtlasTexture
	var key := str(tex.get_rid()) if at == null else "%s:%s" % [at.atlas.get_rid(), at.region]
	if _feet_cache.has(key):
		return _feet_cache[key]
	var img: Image
	var region := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	if at and at.atlas:
		var rid := at.atlas.get_rid()
		if not _images.has(rid):
			var im := at.atlas.get_image()
			if im and im.is_compressed():
				im.decompress()
			_images[rid] = im
		img = _images[rid]
		region = Rect2i(at.region)
	else:
		img = tex.get_image()
		if img and img.is_compressed():
			img.decompress()
	var res := Vector3(region.size.x * 0.5, region.size.y * 0.82, region.size.y * 0.35)
	if img:
		var bottom := -1
		var top := -1
		for y in range(region.size.y - 1, -1, -1):
			for x in region.size.x:
				var c := img.get_pixel(region.position.x + x, region.position.y + y)
				if c.a >= 0.9 and maxf(c.r, maxf(c.g, c.b)) >= 0.02:
					bottom = y
					break
			if bottom >= 0:
				break
		for y in region.size.y:
			for x in region.size.x:
				var c := img.get_pixel(region.position.x + x, region.position.y + y)
				if c.a >= 0.9 and maxf(c.r, maxf(c.g, c.b)) >= 0.02:
					top = y
					break
			if top >= 0:
				break
		if bottom >= 0:
			var sum := 0.0
			var n := 0
			for y in range(maxi(bottom - 3, 0), bottom + 1):
				for x in region.size.x:
					var c := img.get_pixel(region.position.x + x, region.position.y + y)
					if c.a >= 0.9 and maxf(c.r, maxf(c.g, c.b)) >= 0.02:
						sum += x
						n += 1
			res = Vector3(sum / maxi(n, 1), bottom + 1, maxf(top, 0))
	_feet_cache[key] = res
	return res


## Адаптация глаза: сколько света вокруг героя (окружение, луна, огни) —
## такая и экспозиция ночного цветокора (shaders/cloud_shadows.gdshader).
## К яркому глаз привыкает быстро, к темноте — медленно
const EXPOSURE_KEY := 0.5
const EXPOSURE_RANGE := Vector2(0.82, 1.25)

func _expose(total: float, delta: float) -> void:
	if _grade == null:
		var cs := get_parent().get_node_or_null("CloudShadows") as CanvasItem
		if cs == null or not (cs.material is ShaderMaterial):
			return
		_grade = cs.material
	var target := clampf(pow(EXPOSURE_KEY / maxf(total, 0.05), 0.35), EXPOSURE_RANGE.x, EXPOSURE_RANGE.y)
	var speed := 0.8 if target < _exposure else 0.22
	_exposure = move_toward(_exposure, target, delta * speed)
	_grade.set_shader_parameter("exposure", _exposure)
