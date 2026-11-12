@tool
extends Node2D
## Много неподвижных плоских спрайтов (декали на земле) одним узлом.
##
## Каждый Sprite2D — отдельный узел и отдельный элемент отрисовки. Плоские
## декали (кровь, мусор, следы) не сортируются по глубине и не двигаются,
## поэтому их можно рисовать списком из одного узла — в том же порядке и
## с тем же результатом на экране (позиция, масштаб, регион атласа, сдвиг,
## центрирование, отражение — как у Sprite2D).
##
## Собирает и разбирает обратно tools/optimize_map.gd (collapse / expand).

@export var textures: Array[Texture2D] = []
## На спрайт STRIDE чисел: текстура, x, y, масштаб x, y, сдвиг x, y,
## регион x, y, w, h (w = 0 — вся текстура), флаги (1 центр, 2 по X, 4 по Y)
@export var data := PackedFloat32Array()

const STRIDE := 12


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var n := data.size() / STRIDE
	for i in n:
		var b := i * STRIDE
		var tex := textures[int(data[b])]
		if tex == null:
			continue
		var src := Rect2(data[b + 7], data[b + 8], data[b + 9], data[b + 10])
		if src.size.x <= 0.0:
			src = Rect2(Vector2.ZERO, tex.get_size())
		var flags := int(data[b + 11])
		var ofs := Vector2(data[b + 5], data[b + 6])
		if flags & 1:
			ofs -= src.size / 2.0
		var dst := Rect2(ofs, src.size)
		# Отрицательный размер — отражение на месте, как у Sprite2D
		if flags & 2:
			dst.size.x = -dst.size.x
		if flags & 4:
			dst.size.y = -dst.size.y
		draw_set_transform(Vector2(data[b + 1], data[b + 2]), 0.0, Vector2(data[b + 3], data[b + 4]))
		draw_texture_rect_region(tex, dst, src)
	draw_set_transform_matrix(Transform2D.IDENTITY)
