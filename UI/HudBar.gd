extends Control
## HudBar.gd
## Полоска игрового HUD в стиле The Last Oath: тёмная подложка с заострёнными
## концами-стрелками, золотая кайма с шевроном за острием, блик по верху
## заливки. Одна нода рисует здоровье, стамину, опыт навыков и концентрацию —
## вместо набора ColorRect'ов, которые не умеют косые края.
##
## Режим centered — для концентрации: заливка растёт от середины к обоим
## краям, по центру эмблема-ромб.

@export var fill_color := Color(0.62, 0.07, 0.05):
	set(v):
		fill_color = v
		queue_redraw()
@export var back_color := Color(0.025, 0.02, 0.018, 0.88)
@export var frame_color := Color(0.64, 0.51, 0.3, 0.95)
## Полоска отставания (белая у здоровья): показывает, сколько только что сняли
@export var delayed_color := Color(0.9, 0.84, 0.72, 0.6)
@export var tip_left := false
@export var tip_right := true
@export var centered := false
@export var center_emblem := false

var ratio := 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, ratio):
			ratio = v
			queue_redraw()
var delayed_ratio := 0.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, delayed_ratio):
			delayed_ratio = v
			queue_redraw()


const WORN_MATERIAL := preload("res://UI/hud_worn_material.tres")


func _ready() -> void:
	resized.connect(queue_redraw)
	# Потёртость: грязь, патина, царапины (UI/hud_worn.gdshader)
	if material == null:
		material = WORN_MATERIAL


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= h or h <= 0.0:
		return

	draw_colored_polygon(_span(0.0, w), back_color)

	if centered:
		var half := w * 0.5 * ratio
		_draw_fill(w * 0.5 - half, w * 0.5 + half, fill_color)
	else:
		if delayed_ratio > ratio:
			_draw_fill(w * ratio, w * delayed_ratio, delayed_color, false)
		_draw_fill(0.0, w * ratio, fill_color)

	# Кайма по контуру всей фигуры
	var outline := _span(0.0, w)
	outline.append(outline[0])
	draw_polyline(outline, frame_color, 1.3, true)

	# Шевроны за остриями — "наконечник стрелы", как на референсе
	var t := h * 0.5
	if tip_right:
		_chevron(Vector2(w + 3.0, t), 1.0, h)
	if tip_left:
		_chevron(Vector2(-3.0, t), -1.0, h)

	if center_emblem:
		_draw_emblem(Vector2(w * 0.5, t), h)


func _draw_fill(a: float, b: float, col: Color, shaded := true) -> void:
	if b - a < 0.5:
		return
	draw_colored_polygon(_span(a, b), col)
	if not shaded:
		return
	# Блик сверху и тень снизу — плоская заливка превращается в объёмную
	var h := size.y
	var fa := maxf(a, _x0()) + 1.0
	var fb := minf(b, _x1()) - 1.0
	if fb > fa:
		draw_line(Vector2(fa, 1.6), Vector2(fb, 1.6), Color(col.lightened(0.45), 0.75), 1.4)
		draw_line(Vector2(fa, h - 1.6), Vector2(fb, h - 1.6), Color(0.0, 0.0, 0.0, 0.35), 1.4)


## Многоугольник куска полоски между x=a и x=b с учётом косых концов
func _span(a: float, b: float) -> PackedVector2Array:
	var h := size.y
	var xs: Array[float] = [a]
	for k in [_x0(), _x1()]:
		if k > a and k < b:
			xs.append(k)
	xs.append(b)
	var pts := PackedVector2Array()
	for x in xs:
		pts.append(Vector2(x, _top(x)))
	for i in range(xs.size() - 1, -1, -1):
		pts.append(Vector2(xs[i], h - _top(xs[i])))
	return pts


func _x0() -> float:
	return size.y * 0.5 if tip_left else 0.0


func _x1() -> float:
	return size.x - size.y * 0.5 if tip_right else size.x


## Верхняя граница фигуры в точке x. На самом острие верх и низ сходятся —
## оставляем полпикселя зазора, иначе многоугольник вырождается и Godot
## отказывается его триангулировать
func _top(x: float) -> float:
	var h := size.y
	var t := h * 0.5
	var y := 0.0
	if tip_left and x < _x0():
		y = t * (1.0 - x / t)
	elif tip_right and x > _x1():
		y = t * (x - _x1()) / t
	return minf(y, t - 0.5)


func _chevron(p: Vector2, dir: float, h: float) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0.0, -h * 0.75),
		p + Vector2(dir * h * 0.6, 0.0),
		p + Vector2(0.0, h * 0.75),
	])
	draw_polyline(pts, frame_color, 1.5, true)
	draw_circle(p + Vector2(dir * h * 0.95, 0.0), 1.6, frame_color)


## Вытянутый ромб с руной по центру полоски концентрации
func _draw_emblem(c: Vector2, h: float) -> void:
	var rw := h * 0.85
	var rh := h * 1.6
	var outer := PackedVector2Array([
		c + Vector2(0.0, -rh), c + Vector2(rw, 0.0), c + Vector2(0.0, rh), c + Vector2(-rw, 0.0)])
	draw_colored_polygon(outer, Color(0.05, 0.04, 0.035, 0.97))
	var loop := outer.duplicate()
	loop.append(outer[0])
	draw_polyline(loop, frame_color, 1.6, true)
	# шпиль сверху и снизу
	draw_line(c + Vector2(0.0, -rh), c + Vector2(0.0, -rh - h * 0.7), frame_color, 1.4)
	draw_line(c + Vector2(0.0, rh), c + Vector2(0.0, rh + h * 0.4), frame_color, 1.4)
	# руна: вертикальная черта с двумя косыми ветвями
	var rc := fill_color.lightened(0.25)
	draw_line(c + Vector2(0.0, -rh * 0.55), c + Vector2(0.0, rh * 0.55), rc, 1.6)
	draw_line(c + Vector2(0.0, -rh * 0.3), c + Vector2(rw * 0.4, -rh * 0.05), rc, 1.4)
	draw_line(c + Vector2(0.0, rh * 0.05), c + Vector2(rw * 0.4, rh * 0.3), rc, 1.4)
