extends Node2D
## Интерьер дома, в который можно просто зайти — без кнопки взаимодействия.
##
## Снаружи виден цельный спрайт дома (exterior), интерьер спрятан. Как только
## игрок оказывается в одной из комнат (rooms), всё плавно меняется местами:
## дом снаружи растворяется, проступает интерьер со своим тёплым светом, а
## улица уходит в темноту (Shade — полигон с Shaders/indoor_shade.gdshader,
## "дыра" в нём точно по комнатам). Заодно в доме не бывает неба: лунные
## лучи и капли дождя гаснут, а шум дождя становится глуше — как за стенами.
##
## Этажи — дочерние узлы Floor0, Floor1… (в каждом Visuals, Lights и оклюдеры
## стен). Стены первого этажа — обычные StaticBody2D (слой 1, работают
## всегда, и снаружи тоже — комнаты совпадают с корпусом дома). Стены верхнего
## этажа — на своём слое upper_layer: с ними сталкивается только игрок наверху.
##
## Лестница (stairs_rect) общая для обоих этажей. Пока игрок поднимается по
## ней, первый этаж так же плавно растворяется, а второй проступает поверх —
## без затемнения и переноса. С середины пролёта игрок уже "наверху": он
## сталкивается со стенами второго этажа (перила первого больше не мешают
## сойти с лестницы влево, на второй этаж) и сам на слое upper_body_layer,
## которого не видит никто — враги снизу теряют его из виду и не бьют сквозь
## пол. Спустился ниже середины — всё обратно.
##
## Узел собирает tools/graveyard_generator.gd (house_interior()).

## Спрайт дома снаружи
@export var exterior_path: NodePath
## Комнаты в координатах этого узла: внутри них игрок считается "в доме"
@export var rooms: Array[Rect2] = []
@export var fade_time := 0.45
## Насколько темнеет улица, пока игрок внутри (альфа затемнения)
@export var outside_darkness := 0.62
## Громкость дождя, слышного из-под крыши (см. level_music_manager.gd)
@export var rain_volume_inside := -26.0
## Размер героя внутри (картинка и коллизия), 1 — как на улице
@export var inside_scale := 0.8

@export_group("Лестница")
## Ступени между перилами (низ — первый этаж, верх — второй)
@export var stairs_rect := Rect2()
## На какой доле пролёта (0 — низ, 1 — верх) второй этаж начинает
## проступать и где уже виден целиком
@export var blend_from := 0.3
@export var blend_to := 0.8
## Слой стен верхнего этажа и слой самого игрока, пока он наверху
@export_flags_2d_physics var upper_layer := 512
@export_flags_2d_physics var upper_body_layer := 1024

const BODY_LIGHT_BIT := 8

@onready var _shade: CanvasItem = $Shade

var _exterior: CanvasItem
var _floors: Array[Node2D] = []
## Этаж, к которому игрок сейчас относится (стены, видимость для врагов)
var _floor := 0
## Сколько видно второго этажа: 0 — только первый, 1 — только второй
var _blend := 0.0
var _inside := false
var _t := 0.0
var _tween: Tween
var _base_energy := {}
var _light_floor := {}
var _clock := 0.0
var _saved_player := {}


func _ready() -> void:
	add_to_group("house_interior")
	_exterior = get_node_or_null(exterior_path) as CanvasItem
	for ch in get_children():
		if ch.name.begins_with("Floor"):
			_floors.append(ch)
			for l in ch.get_node("Lights").get_children():
				_base_energy[l] = (l as Light2D).energy
				_light_floor[l] = _floors.size() - 1
	var mat := _shade.material as ShaderMaterial
	mat.set_shader_parameter("rect_count", mini(rooms.size(), 4))
	for i in mini(rooms.size(), 4):
		var r := Rect2(to_global(rooms[i].position), rooms[i].size * global_scale)
		mat.set_shader_parameter("rect%d" % i, Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	_apply(0.0)


func _process(delta: float) -> void:
	_clock += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var inside := player != null and contains_point(player.global_position)
	if inside != _inside:
		_set_inside(inside)
	if player and _floors.size() > 1:
		_update_stairs(player, delta)
	if _t > 0.0:
		_update_lights()


func _update_stairs(player: Node2D, delta: float) -> void:
	var lp := to_local(player.global_position)
	var target := float(_floor)
	if stairs_rect.has_point(lp):
		var p := clampf((stairs_rect.end.y - lp.y) / stairs_rect.size.y, 0.0, 1.0)
		target = smoothstep(blend_from, blend_to, p)
		_set_floor(player, 1 if p > 0.5 else 0)
		# На ступенях смена идёт ровно за шагами игрока
		_blend = target
	else:
		# Сошёл с лестницы, не дойдя до конца перехода, — доводим плавно
		_blend = move_toward(_blend, target, delta / fade_time)
	_apply_floors()


func _set_floor(player: Node2D, f: int) -> void:
	if f == _floor:
		return
	_floor = f
	_set_player_upstairs(player, f > 0)


## Точка (в мировых координатах) внутри какой-либо комнаты этого дома
func contains_point(p: Vector2) -> bool:
	var lp := to_local(p)
	for r in rooms:
		if r.has_point(lp):
			return true
	return false


## Есть ли над точкой крыша прямо сейчас (интерьер показан) — например, чтобы
## не рисовать всплески дождя на полу дома
func is_roofed(p: Vector2) -> bool:
	return _t > 0.5 and contains_point(p)


func _set_inside(value: bool) -> void:
	_inside = value
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_set_player_small(player, value)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply, _t, 1.0 if value else 0.0, fade_time)
	var music := get_tree().get_first_node_in_group("level_music")
	if music and music.has_method("set_indoors"):
		music.set_indoors(value, fade_time * 2.0, rain_volume_inside)


## В доме герой чуть меньше — комнаты кажутся просторнее. Картинку плавно
## уменьшает DepthComponent (scale_mul), коллизию и оклюдер тени у ног
## масштабируем сразу. Исходные значения хранятся в meta узлов, поэтому
## повторный вход не накапливает уменьшение
func _set_player_small(player: Node2D, small: bool) -> void:
	var k := inside_scale if small else 1.0
	var depth = player.get_node_or_null("DepthComponent")
	if depth:
		depth.scale_mul = k
	for ch in player.get_children():
		if ch is CollisionShape2D or ch is LightOccluder2D:
			var n := ch as Node2D
			if not n.has_meta("base_scale"):
				n.set_meta("base_scale", n.scale)
				n.set_meta("base_pos", n.position)
			n.scale = (n.get_meta("base_scale") as Vector2) * k
			n.position = (n.get_meta("base_pos") as Vector2) * k


## Наверху игрок сталкивается только со стенами верхнего этажа, а сам — на
## слое, которого не видит никто (зрение и удары врагов, их снаряды). Его
## собственные области (удары, подбор) тоже выключаются, чтобы не бить
## врагов внизу сквозь пол. Внизу всё возвращается как было
func _set_player_upstairs(player: Node2D, up: bool) -> void:
	var body := player as CollisionObject2D
	if body == null:
		return
	if up:
		_saved_player = {"layer": body.collision_layer, "mask": body.collision_mask, "areas": {}}
		body.collision_layer = upper_body_layer
		body.collision_mask = upper_layer
		for a in player.find_children("*", "Area2D", true, false):
			var area := a as Area2D
			_saved_player.areas[area] = [area.collision_layer, area.collision_mask]
			area.collision_layer = 0
			area.collision_mask = 0
	elif not _saved_player.is_empty():
		body.collision_layer = _saved_player.layer
		body.collision_mask = _saved_player.mask
		for area in _saved_player.areas:
			if is_instance_valid(area):
				area.collision_layer = _saved_player.areas[area][0]
				area.collision_mask = _saved_player.areas[area][1]
		_saved_player = {}


func _apply(t: float) -> void:
	_t = t
	_apply_floors()
	_shade.visible = t > 0.0
	(_shade.material as ShaderMaterial).set_shader_parameter("amount", t * outside_darkness)
	if _exterior:
		_exterior.modulate.a = 1.0 - t
		_exterior.visible = t < 1.0
	_update_lights()
	# Под крышей на героя не светят луна, облака и его холодный ореол — только
	# огонь, поэтому в доме он окрашивается тёплым светом камина и свечей.
	# Слой тела героя — 8 (см. player_spawner.gd, player_shadow)
	var roofed := t > 0.5
	for l in get_tree().get_nodes_in_group("outdoor_light"):
		var light := l as Light2D
		if roofed:
			light.range_item_cull_mask &= ~BODY_LIGHT_BIT
		elif (light.range_item_cull_mask & 1) != 0:
			light.range_item_cull_mask |= BODY_LIGHT_BIT
	# Под крышей неба нет: лучи луны и капли дождя гаснут вместе с улицей
	for ray in get_tree().get_nodes_in_group("moon_rays"):
		(ray as CanvasItem).modulate.a = 1.0 - t
	# Дождь уровня (Levels/rain_system.gd) — пелена, капли и круги на земле
	for rain in get_tree().get_nodes_in_group("rain_fx"):
		(rain as CanvasItem).modulate.a = 1.0 - t
	var player := get_tree().get_first_node_in_group("player")
	var cam: Node = player.get_node_or_null("Camera2D") if player else null
	if cam:
		for ch in cam.get_children():
			if ch is GPUParticles2D and String(ch.name).begins_with("Rain"):
				(ch as CanvasItem).modulate.a = 1.0 - t


## Первый этаж лежит снизу непрозрачным, второй проступает поверх него с
## прозрачностью _blend — так между ними нет "просвета" на улицу
func _apply_floors() -> void:
	for i in _floors.size():
		var vis := _floors[i].get_node("Visuals") as CanvasItem
		var a := _t if i == 0 else _t * _blend
		vis.modulate.a = a
		vis.visible = a > 0.0 and not (i == 0 and _blend >= 1.0 and _floors.size() > 1)


func _floor_weight(i: int) -> float:
	if _floors.size() < 2:
		return 1.0
	return 1.0 - _blend if i == 0 else _blend


func _update_lights() -> void:
	for l: Light2D in _base_energy:
		var e: float = _base_energy[l] * _t * _floor_weight(_light_floor[l])
		# Огонь в камине живой: энергия чуть "дышит" на нескольких частотах
		if l.get_meta("flicker", false):
			e *= 0.88 + 0.07 * sin(_clock * 7.3) + 0.05 * sin(_clock * 12.9 + 1.7)
		l.energy = e
		l.visible = e > 0.0
