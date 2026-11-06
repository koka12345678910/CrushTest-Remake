extends Control
## OrnamentSeparator.gd — разделитель групп пунктов меню: тонкая черта,
## гаснущая вправо, как разделители инвентаря (без орнаментов и ромбов).

@export var line_color: Color = Color(1, 1, 1, 0.13)
## Отступ слева (под золотую черту выбранного пункта) и длина черты;
## length 0 — до правого края
@export var inset: float = 26.0
@export var length: float = 300.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var y := roundf(size.y / 2.0)
	var w := (size.x - inset) if length <= 0.0 else minf(length, size.x - inset)
	var n := 20
	var step := w / n
	for i in n:
		var t := (i + 0.5) / n
		draw_rect(Rect2(inset + i * step, y, step + 0.5, 1), Color(line_color, line_color.a * (1.0 - t)))
