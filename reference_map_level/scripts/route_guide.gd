extends Node
## route_guide.gd — куда идти (узел RouteGuide у корня reference_map).
##
## Без диалогов и без стрелок на мини-карте — три тихие подсказки:
##   1. Название места при первом входе в район (как в souls-играх):
##      крупно сверху, с тонкой чертой; на старте под ним — цель.
##   2. Свет Бальдра: слабое золотое свечение у края экрана со стороны, куда
##      ведёт путь к храму (по навмешу, а не напрямик сквозь дома). Гаснет в
##      бою, у самой цели и пока на экране название места.
##   3. В мире то же говорят святилища Бальдра с лампадами вдоль пути и
##      указатели с солнцем (tools/holmvik_route.gd) — этот узел их не трогает.
## Всё локально для своего героя: в коопе у каждого своё.

## Цель пути — врата двора храма
@export var goal := Vector2(1090, 1290)
## Ближе этого к цели свечение не нужно
@export var goal_radius := 260.0
## Как далеко по пути смотреть вперёд, px
@export var look_ahead := 260.0
@export var glow_color := Color(1.0, 0.78, 0.42)
@export var glow_alpha := 0.32
@export var glow_size := 560.0
## Пауза перед первым названием (экран загрузки, затемнение)
@export var start_delay := 1.6

## Районы: [название, прямоугольник]. Первый подходящий — текущий
const ZONES := [
	["Храм Света Бальдра", Rect2(760, 860, 680, 600)],
	["Дорога к храму", Rect2(100, 1280, 660, 400)],
	["Площадь", Rect2(-820, 840, 920, 620)],
	["Верхняя улица", Rect2(-2000, 480, 1300, 300)],
	["Западная улица", Rect2(-2060, 780, 420, 1080)],
	["Внутренние ворота", Rect2(-2100, 1780, 420, 220)],
	["Нижний город", Rect2(-2000, 1880, 3200, 760)],
]
const START_TITLE := "Хольмвик"
const OBJECTIVE := "Дойди до Храма Света Бальдра"

var _layer: CanvasLayer
var _title: Label
var _sub: Label
var _line: ColorRect
var _box: Control
var _glow: TextureRect
var _seen := {}
var _zone := ""
var _show_t := 0.0
var _path_t := 0.0
var _dir := Vector2.ZERO
var _glow_a := 0.0
var _started := false
var _tween: Tween


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)
	_build_title()
	_build_glow()
	get_tree().create_timer(start_delay).timeout.connect(func():
		_started = true
		_show(START_TITLE, OBJECTIVE))


func _build_title() -> void:
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	_layer.add_child(_box)
	var theme := load("res://Main_Menu/theme/MenuTheme.tres") as Theme
	var font: Font = theme.default_font if theme else null
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.position = Vector2(-600, 150)
	_title.size = Vector2(1200, 70)
	if font:
		_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_constant_override("shadow_outline_size", 8)
	_box.add_child(_title)
	_line = ColorRect.new()
	_line.color = Color(0.85, 0.7, 0.45, 0.7)
	_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_line.position = Vector2(-180, 226)
	_line.size = Vector2(360, 1)
	_box.add_child(_line)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sub.position = Vector2(-600, 236)
	_sub.size = Vector2(1200, 40)
	if font:
		_sub.add_theme_font_override("font", font)
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5))
	_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_sub.add_theme_constant_override("shadow_offset_y", 2)
	_box.add_child(_sub)


func _build_glow() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.gradient = g
	_glow = TextureRect.new()
	_glow.texture = t
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(glow_size, glow_size)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.self_modulate = Color(glow_color, 0.0)
	_layer.add_child(_glow)
	_layer.move_child(_glow, 0)


func _show(title: String, sub: String) -> void:
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	_line.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_box, "modulate:a", 1.0, 0.9)
	_tween.tween_interval(2.8 if sub == "" else 4.0)
	_tween.tween_property(_box, "modulate:a", 0.0, 1.4)
	_show_t = 5.5


func _hero() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	var hero := _hero()
	if hero == null or not _started:
		return
	_show_t = maxf(_show_t - delta, 0.0)
	# Название района — при первом входе
	var z := ""
	for zz in ZONES:
		if (zz[1] as Rect2).has_point(hero.global_position):
			z = zz[0]
			break
	if z != _zone:
		_zone = z
		if z != "" and not _seen.has(z) and _show_t <= 0.0:
			_seen[z] = true
			_show(z, "")
	_update_glow(hero, delta)


func _update_glow(hero: Node2D, delta: float) -> void:
	_path_t -= delta
	if _path_t <= 0.0:
		_path_t = 0.4
		_dir = _path_dir(hero)
	var want := glow_alpha
	if _dir == Vector2.ZERO or hero.global_position.distance_to(goal) < goal_radius or _show_t > 0.0 or _in_combat(hero):
		want = 0.0
	# Медленно дышит — свет зовёт, а не мигает
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.0016)
	_glow_a = move_toward(_glow_a, want, delta * 0.35)
	_glow.self_modulate = Color(glow_color, _glow_a * pulse)
	if _dir == Vector2.ZERO:
		return
	var vs := get_viewport().get_visible_rect().size
	var c := vs * 0.5
	# Точка на краю экрана по направлению пути
	var d := _dir.normalized()
	var k := minf(c.x / maxf(absf(d.x), 0.001), c.y / maxf(absf(d.y), 0.001))
	var edge := c + d * k
	_glow.position = edge - _glow.size * 0.5


## Направление пути к цели: точка на look_ahead px вперёд по навмешу
func _path_dir(hero: Node2D) -> Vector2:
	var nav := hero.get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(nav) == 0:
		return Vector2.ZERO
	var path := NavigationServer2D.map_get_path(nav, hero.global_position, goal, true)
	if path.size() < 2:
		return Vector2.ZERO
	var left := look_ahead
	var p := path[0]
	for i in range(1, path.size()):
		var seg := path[i].distance_to(p)
		if seg >= left:
			p = p.move_toward(path[i], left)
			left = 0.0
			break
		left -= seg
		p = path[i]
	return p - hero.global_position


## Бой: кто-то из отряда поблизости поднят по тревоге
func _in_combat(hero: Node2D) -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("squad_alert") == true and not e.get("is_dead") \
				and (e as Node2D).global_position.distance_to(hero.global_position) < 700.0:
			return true
	return false
