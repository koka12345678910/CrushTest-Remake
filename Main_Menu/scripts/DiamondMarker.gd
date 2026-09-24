extends Control
## DiamondMarker.gd
## Ромбик-маркер в стиле орнаментов на лого TLO — контур + залитая точка
## внутри. Переиспользуется и как индикатор наведённой кнопки меню
## (MenuButton.gd), и как центр декоративного разделителя (OrnamentSeparator.gd)

@export var outline_color: Color = Color(0.78, 0.50, 0.19, 1.0)
@export var fill_color: Color = Color(0.92, 0.85, 0.72, 1.0)
@export var outline_width: float = 1.5
## Заливка всего ромба под контуром — по умолчанию прозрачная (обычный маркер);
## непрозрачная нужна значкам с числом внутри (опыт навыков в HUD)
@export var body_color: Color = Color(0.0, 0.0, 0.0, 0.0)


func _draw() -> void:
	var c := size / 2.0
	var outer := PackedVector2Array([
		Vector2(c.x, 0.0), Vector2(size.x, c.y), Vector2(c.x, size.y), Vector2(0.0, c.y), Vector2(c.x, 0.0)
	])
	if body_color.a > 0.0:
		draw_colored_polygon(outer.slice(0, 4), body_color)
	draw_polyline(outer, outline_color, outline_width, true)

	var r := minf(size.x, size.y) * 0.22
	var inner := PackedVector2Array([
		Vector2(c.x, c.y - r), Vector2(c.x + r, c.y), Vector2(c.x, c.y + r), Vector2(c.x - r, c.y)
	])
	draw_colored_polygon(inner, fill_color)
