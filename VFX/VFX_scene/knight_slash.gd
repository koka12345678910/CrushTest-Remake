extends Node2D
## knight_slash.gd — одна дуга клинка рыцаря (создаёт knight_fx.gd::slash).
## Ребёнок рыцаря: если удар с выпадом, дуга едет вместе с ним. Сам эффект —
## один квадрат с шейдером Shaders/slash_arc.gdshader, без частиц.

const SHADER := preload("res://Shaders/slash_arc.gdshader")

var a_from := -1.4
var a_to := 1.4
var radius := 32.0
var width := 0.16
var duration := 0.14
var intensity := 1.0
var squash := 0.62
var tail := 0.7
## true — голова дуги идёт равномерно и доходит до конца ровно за duration
## (дуга по таймингу кадров спрайта); false — резкий старт и мягкий доход
var linear := false
var color_edge := Color(0.55, 0.66, 0.92)
## Своя плоскость дуги (рубящий удар сверху, knight_fx.gd::chop): оси круга
## дуги на экране. Нулевые — обычная дуга вокруг тела, сплющенная на squash
var basis_x := Vector2.ZERO
var basis_y := Vector2.ZERO

var _mat: ShaderMaterial


func setup(from: float, to: float, r: float, w: float, dur: float, power := 1.0) -> void:
	a_from = from
	a_to = to
	radius = r
	width = w
	duration = dur
	intensity = power


func _ready() -> void:
	z_index = 7
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var quad := Sprite2D.new()
	quad.texture = ImageTexture.create_from_image(img)
	# Середина полосы в шейдере — на r_mid половины квадрата
	var half := radius / 0.78
	if basis_x != Vector2.ZERO:
		# Круг дуги кладём в заданную плоскость: угол 0 — вдоль basis_x,
		# 90° — вдоль basis_y (в шейдере +y квадрата — вниз по его UV)
		quad.scale = Vector2(half * 2.0, half * 2.0) / 4.0
		transform = Transform2D(basis_x, basis_y, position)
	else:
		quad.scale = Vector2(half * 2.0, half * 2.0 * squash) / 4.0
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("a_from", a_from)
	_mat.set_shader_parameter("a_to", a_to)
	_mat.set_shader_parameter("width", width)
	_mat.set_shader_parameter("tail", tail)
	_mat.set_shader_parameter("intensity", intensity * 1.35)
	_mat.set_shader_parameter("color_edge", color_edge)
	_mat.set_shader_parameter("seed", randf() * 10.0)
	_mat.set_shader_parameter("progress", 0.0)
	quad.material = _mat
	add_child(quad)

	var t := create_tween()
	if linear:
		# Голова доходит до конца дуги ровно за duration (как след на спрайте),
		# дальше ещё tail доли — хвост догоняет и тает
		var total := duration * (1.0 + tail)
		t.tween_method(_set_param.bind("progress"), 0.0, 1.0, total).set_trans(Tween.TRANS_LINEAR)
		t.parallel().tween_method(_set_param.bind("fade"), 1.0, 0.0, total * 0.45).set_delay(total * 0.55)
	else:
		t.tween_method(_set_param.bind("progress"), 0.0, 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_method(_set_param.bind("fade"), 1.0, 0.0, duration * 0.45).set_delay(duration * 0.6)
	t.tween_callback(queue_free)


func _set_param(v: float, param: String) -> void:
	_mat.set_shader_parameter(param, v)
