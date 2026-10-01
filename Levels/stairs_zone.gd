@tool
extends Area2D
## stairs_zone.gd — лестница между этажами.
##
## Как пользоваться: добавь на уровень Area2D с этим скриптом, дай ей
## CollisionShape2D с прямоугольником поверх ступенек и выстави в инспекторе:
##   up_direction   — в какую сторону по лестнице ВВЕРХ (стрелка в редакторе);
##   bottom_height  — этаж у нижнего края лестницы (например 0);
##   top_height     — этаж у верхнего края (например 1).
## Пока герой внутри, его высота плавно меняется от bottom к top по мере
## продвижения вдоль стрелки — он растёт, поднимаясь, и уменьшается,
## спускаясь. Вышел из зоны — высота фиксируется на ближайшем этаже.
##
## Работает с любым телом, у которого есть ребёнок "DepthComponent"
## (Player_scene/depth_component.gd) — сейчас это все играбельные герои.

@export var up_direction := Vector2.UP:
	set(v):
		up_direction = v.normalized() if v != Vector2.ZERO else Vector2.UP
		queue_redraw()
@export var bottom_height := 0.0
@export var top_height := 1.0

var _inside: Array[Node2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Герои на слое "player" (2) — зона должна их видеть
	set_collision_mask_value(2, true)


func _on_body_entered(body: Node) -> void:
	if body is Node2D and body.get_node_or_null("DepthComponent"):
		_inside.append(body)


func _on_body_exited(body: Node) -> void:
	if not body in _inside:
		return
	_inside.erase(body)
	var depth = body.get_node_or_null("DepthComponent")
	if depth:
		# Сошёл с лестницы — встаём ровно на ближайший этаж, без "полуэтажей"
		var t := _progress(body.global_position)
		depth.set_height(top_height if t >= 0.5 else bottom_height)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body in _inside:
		if not is_instance_valid(body):
			continue
		var depth = body.get_node_or_null("DepthComponent")
		if depth:
			depth.set_height(lerpf(bottom_height, top_height, _progress(body.global_position)))


## 0 — у нижнего края лестницы, 1 — у верхнего (вдоль up_direction)
func _progress(point: Vector2) -> float:
	var span := _span()
	if span.y - span.x < 0.001:
		return 0.0
	var up := (global_transform.basis_xform(up_direction)).normalized()
	return clampf((point.dot(up) - span.x) / (span.y - span.x), 0.0, 1.0)


## Проекции краёв формы на направление "вверх": x — низ, y — верх
func _span() -> Vector2:
	var up := (global_transform.basis_xform(up_direction)).normalized()
	var lo := INF
	var hi := -INF
	for c in get_children():
		var cs := c as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		var rect := cs.shape.get_rect()
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y)]:
			var d: float = (cs.global_transform * corner).dot(up)
			lo = minf(lo, d)
			hi = maxf(hi, d)
	if lo == INF:
		return Vector2.ZERO
	return Vector2(lo, hi)


# ── Подсказка в редакторе: стрелка "ВВЕРХ" и этажи на концах ────────────────

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var up := up_direction
	var half := 40.0
	for c in get_children():
		var cs := c as CollisionShape2D
		if cs and cs.shape:
			var r := cs.shape.get_rect()
			half = maxf(half, absf(r.size.dot(Vector2(absf(up.x), absf(up.y)))) * 0.5 - 6.0)
	var col := Color(1.0, 0.8, 0.3, 0.9)
	var a := -up * half
	var b := up * half
	draw_line(a, b, col, 2.0)
	var side := Vector2(-up.y, up.x)
	draw_colored_polygon(PackedVector2Array([b, b - up * 12 + side * 7, b - up * 12 - side * 7]), col)
	var font := ThemeDB.fallback_font
	draw_string(font, b + up * 10 + Vector2(-20, 0), "ВВЕРХ  %s" % top_height, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	draw_string(font, a - up * 4 + Vector2(-20, 0), "низ  %s" % bottom_height, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, 0.7))
