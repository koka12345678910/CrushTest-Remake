@tool
extends StaticBody2D
## Статическая коллизия карты одним узлом.
##
## Раньше каждое препятствие (ствол, стена, ящик) было своим узлом
## CollisionShape2D — на reference_map их было ~1700. Здесь те же фигуры
## лежат списком и при запуске отдаются физике напрямую (shape owner'ы
## этого тела): столкновения те же, навмеш их видит так же
## (parse_source_geometry читает shape owner'ы StaticBody2D), а узлов —
## один. Полигоны воды и прочие CollisionPolygon2D остаются детьми как были.
##
## Собирает и разбирает обратно (для правки руками) tools/optimize_map.gd:
##   ... -- collapse   — узлы CollisionShape2D → этот список
##   ... -- expand     — список → снова узлы (поправить в редакторе)
## В редакторе фигуры рисуются, если включить видимость узла.

@export var shapes: Array[Shape2D] = []
@export var shape_transforms: Array[Transform2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	for i in shapes.size():
		var o := create_shape_owner(self)
		shape_owner_add_shape(o, shapes[i])
		shape_owner_set_transform(o, shape_transforms[i])
	if get_tree().debug_collisions_hint:
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() and not get_tree().debug_collisions_hint:
		return
	var col := Color(0.0, 0.6, 0.7, 0.42)
	for i in shapes.size():
		draw_set_transform_matrix(shape_transforms[i])
		shapes[i].draw(get_canvas_item(), col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
