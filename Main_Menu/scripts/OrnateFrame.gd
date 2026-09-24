extends Control
## OrnateFrame.gd
## Рамка в стиле интерфейса The Last Oath: тёмная заливка, тонкая кайма,
## золотые уголки-скобки с диагональной засечкой и (для пустых ячеек) тонкий
## крестик по центру. Одна нода с _draw() вместо десятка ColorRect на каждую
## ячейку — рамок в инвентаре под сотню, и рисовать их примитивами дешевле.

@export var fill_color := Color(0.05, 0.045, 0.04, 0.9):
	set(v):
		fill_color = v
		queue_redraw()
@export var border_color := Color(0.45, 0.37, 0.24, 0.45):
	set(v):
		border_color = v
		queue_redraw()
@export var corner_color := Color(0.7, 0.57, 0.34, 0.85):
	set(v):
		corner_color = v
		queue_redraw()
@export var highlight_color := Color(0.95, 0.76, 0.38, 1.0)
@export var corner_length := 14.0:
	set(v):
		corner_length = v
		queue_redraw()
@export var corner_width := 1.5:
	set(v):
		corner_width = v
		queue_redraw()
## Вторая, бледная кайма чуть внутри — у крупных окон, чтобы край читался
## "кованым", а не просто линией
@export var double_border := false:
	set(v):
		double_border = v
		queue_redraw()
@export var show_cross := false:
	set(v):
		show_cross = v
		queue_redraw()
@export var cross_color := Color(0.55, 0.47, 0.32, 0.32)
@export var cross_size := 12.0
## 0 — обычное состояние, 1 — выделено: кайма и уголки уходят в золото,
## заливка теплеет. Промежуточные значения — наведение
@export_range(0.0, 1.0) var highlight := 0.0:
	set(v):
		highlight = clampf(v, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	var fill := fill_color.lerp(Color(0.15, 0.11, 0.065, fill_color.a), highlight * 0.6)
	var border := border_color.lerp(highlight_color, highlight * 0.8)
	var corner := corner_color.lerp(highlight_color, highlight)

	if fill.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), fill)

	# +0.5 — чтобы однопиксельная линия легла ровно на пиксель, а не
	# размазалась на два полупрозрачных
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), border, false, 1.0)
	if double_border:
		draw_rect(Rect2(Vector2(5.5, 5.5), size - Vector2(11.0, 11.0)),
			Color(border, border.a * 0.55), false, 1.0)

	var L := minf(corner_length, minf(w, h) * 0.35)
	var corners := [
		[Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(w, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(0.0, h), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(w, h), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
	]
	for c in corners:
		var p: Vector2 = c[0]
		var dx: Vector2 = c[1]
		var dy: Vector2 = c[2]
		draw_line(p, p + dx * L, corner, corner_width)
		draw_line(p, p + dy * L, corner, corner_width)
		# Засечка по диагонали внутрь — отличает "кованый" уголок от простой скобки
		draw_line(p + (dx + dy) * 3.0, p + (dx + dy) * (3.0 + L * 0.3), corner, 1.0)

	if show_cross:
		var cc := size / 2.0
		var s := cross_size
		var g := 3.0
		var col := cross_color.lerp(highlight_color, highlight * 0.5)
		draw_line(cc + Vector2(-s, 0.0), cc + Vector2(-g, 0.0), col, 1.0)
		draw_line(cc + Vector2(g, 0.0), cc + Vector2(s, 0.0), col, 1.0)
		draw_line(cc + Vector2(0.0, -s), cc + Vector2(0.0, -g), col, 1.0)
		draw_line(cc + Vector2(0.0, g), cc + Vector2(0.0, s), col, 1.0)
		# Крошечные поперечные засечки на концах — как на референсе
		draw_line(cc + Vector2(-s, -2.0), cc + Vector2(-s, 2.0), col, 1.0)
		draw_line(cc + Vector2(s, -2.0), cc + Vector2(s, 2.0), col, 1.0)
		draw_line(cc + Vector2(-2.0, -s), cc + Vector2(2.0, -s), col, 1.0)
		draw_line(cc + Vector2(-2.0, s), cc + Vector2(2.0, s), col, 1.0)
