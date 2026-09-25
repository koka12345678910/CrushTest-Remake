extends Button
## ornate_button.gd
## Кнопка в стиле окна навыков: тонкая рамка с внутренней каймой и
## "крыльями" по бокам — шеврон и ромбы снаружи рамки. Текст рисует сам
## Button, здесь только фон и орнамент.

const GOLD := Color(0.8, 0.62, 0.34)
const GOLD_DIM := Color(0.55, 0.45, 0.3, 0.75)


func _ready() -> void:
	# Фон — стилбоксом, а не в _draw(): скриптовый _draw идёт ПОСЛЕ отрисовки
	# текста кнопкой и залил бы надпись
	add_theme_stylebox_override("normal", _box(Color(0.04, 0.036, 0.032, 0.92)))
	add_theme_stylebox_override("hover", _box(Color(0.14, 0.1, 0.06, 0.9)))
	add_theme_stylebox_override("pressed", _box(Color(0.1, 0.075, 0.045, 0.95)))
	add_theme_stylebox_override("disabled", _box(Color(0.04, 0.036, 0.032, 0.6)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_color_override("font_color", Color(0.86, 0.8, 0.68))
	add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.5))
	add_theme_color_override("font_pressed_color", Color(0.9, 0.75, 0.45))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var hot := is_hovered()
	var col := GOLD if hot else GOLD_DIM
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, col, false, 1.4)
	draw_rect(r.grow(-5.0), Color(col, 0.35), false, 1.0)
	var cy := size.y * 0.5
	for side: float in [-1.0, 1.0]:
		var x := 0.0 if side < 0.0 else size.x
		# Засечки на углах рамки
		for y in [0.0, size.y]:
			draw_line(Vector2(x, y), Vector2(x + side * 10.0, y), col, 1.4)
		# Шеврон и два ромба снаружи
		draw_polyline(PackedVector2Array([Vector2(x + side * 6.0, cy - 11.0),
				Vector2(x + side * 16.0, cy), Vector2(x + side * 6.0, cy + 11.0)]), col, 1.3, true)
		_diamond(Vector2(x + side * 24.0, cy), 5.0, col)
		_diamond(Vector2(x + side * 36.0, cy), 3.0, Color(col, 0.7))


func _box(bg: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	return b


func _diamond(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)])
	draw_polyline(pts, col, 1.3, true)
