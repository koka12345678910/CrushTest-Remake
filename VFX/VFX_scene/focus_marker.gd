extends Node2D
## Маркер фокуса на враге — просто белая точка по центру цели, как прицел
## лок-она в соулс-лайках. player.gd создаёт/удаляет этот узел и таскает
## его global_position за целью, пока враг в фокусе (см. player.gd:_set_focused_enemy)

const COLOR := Color(1, 1, 1, 0.95)
const RADIUS := 3.5

func _ready() -> void:
	z_index = 50  # поверх спрайтов игрока и врагов
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
