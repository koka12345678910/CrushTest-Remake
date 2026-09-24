extends Control
## GlyphIcon.gd
## Мелкие векторные иконки меню (класс героя, строки статов). Рисуются
## примитивами по нормализованным координатам 0..1 — готовых иконок в
## проекте нет, а тянуть ради шести значков сторонний набор незачем.

@export var glyph := "rune"
@export var color := Color(0.78, 0.50, 0.19, 1.0)


func set_glyph(name_of_glyph: String, glyph_color: Color) -> void:
	glyph = name_of_glyph
	color = glyph_color
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	# Глиф всегда квадратный и по центру контрола, каким бы тот ни был
	var o := (size - Vector2(s, s)) * 0.5

	match glyph:
		"shield":
			_fill(o, s, [[0.5, 0.04], [0.92, 0.22], [0.92, 0.55],
				[0.5, 0.96], [0.08, 0.55], [0.08, 0.22]])
		"bow":
			draw_arc(o + Vector2(0.78, 0.5) * s, 0.46 * s,
				deg_to_rad(120.0), deg_to_rad(240.0), 24, color, 0.09 * s)
			_line(o, s, [0.55, 0.08], [0.55, 0.92], 0.05)
			_line(o, s, [0.2, 0.5], [0.78, 0.5], 0.07)
		"rune":
			_fill(o, s, [[0.5, 0.0], [0.6, 0.4], [1.0, 0.5], [0.6, 0.6],
				[0.5, 1.0], [0.4, 0.6], [0.0, 0.5], [0.4, 0.4]])
		"heart":
			draw_circle(o + Vector2(0.31, 0.34) * s, 0.23 * s, color)
			draw_circle(o + Vector2(0.69, 0.34) * s, 0.23 * s, color)
			_fill(o, s, [[0.07, 0.38], [0.93, 0.38], [0.5, 0.95]])
		"bolt":
			_fill(o, s, [[0.6, 0.04], [0.22, 0.56], [0.46, 0.56],
				[0.38, 0.96], [0.8, 0.42], [0.54, 0.42]])
		"fist":
			# Сила — не кулак, а направленная вверх стрела: на 18 пикселях
			# кулак превращается в пятно, а стрелка читается однозначно
			_fill(o, s, [[0.5, 0.06], [0.94, 0.5], [0.68, 0.5],
				[0.68, 0.94], [0.32, 0.94], [0.32, 0.5], [0.06, 0.5]])
		"feather":
			_fill(o, s, [[0.5, 0.04], [0.76, 0.5], [0.5, 0.96], [0.24, 0.5]])
			_line(o, s, [0.5, 0.12], [0.5, 0.88], 0.05)
		"book":
			draw_rect(Rect2(o + Vector2(0.1, 0.22) * s, Vector2(0.36, 0.56) * s), color)
			draw_rect(Rect2(o + Vector2(0.54, 0.22) * s, Vector2(0.36, 0.56) * s), color)
		"flame":
			_fill(o, s, [[0.5, 0.02], [0.8, 0.44], [0.82, 0.7],
				[0.5, 0.98], [0.18, 0.7], [0.2, 0.44]])
		"medallion":
			# Кольцо с руной-звездой внутри — эмблема шапки инвентаря
			var c := o + Vector2(0.5, 0.5) * s
			draw_arc(c, 0.46 * s, 0.0, TAU, 40, color, maxf(1.0, 0.06 * s))
			draw_arc(c, 0.36 * s, 0.0, TAU, 32, Color(color, color.a * 0.55),
				maxf(1.0, 0.03 * s))
			_fill(o, s, [[0.5, 0.17], [0.56, 0.44], [0.83, 0.5], [0.56, 0.56],
				[0.5, 0.83], [0.44, 0.56], [0.17, 0.5], [0.44, 0.44]])
		"bag":
			# Завязанный мешочек: круглое брюшко, горловина, раструб сверху и
			# тёмная стяжка. Не прямоугольник с дугой — такой силуэт читается
			# как навесной замок, а не как сумка
			draw_circle(o + Vector2(0.5, 0.64) * s, 0.31 * s, color)
			_fill(o, s, [[0.37, 0.22], [0.63, 0.22], [0.58, 0.42], [0.42, 0.42]])
			_fill(o, s, [[0.28, 0.1], [0.72, 0.1], [0.63, 0.25], [0.37, 0.25]])
			draw_line(o + Vector2(0.36, 0.3) * s, o + Vector2(0.64, 0.3) * s,
				Color(0.0, 0.0, 0.0, 0.55), maxf(1.0, 0.06 * s))
		_:
			_fill(o, s, [[0.5, 0.05], [0.95, 0.5], [0.5, 0.95], [0.05, 0.5]])


func _fill(o: Vector2, s: float, pts: Array) -> void:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(o + Vector2(p[0], p[1]) * s)
	draw_colored_polygon(poly, color)


func _line(o: Vector2, s: float, from: Array, to: Array, width: float) -> void:
	draw_line(
		o + Vector2(from[0], from[1]) * s,
		o + Vector2(to[0], to[1]) * s,
		color, width * s)
