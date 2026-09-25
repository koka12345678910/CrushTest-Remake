extends RefCounted
## archer_fx.gd — мелкие визуальные эффекты и статусы навыков лучницы.
## Всё рисуется кодом (как focus_marker.gd), текстур не нужно.
##
##   Mark   — руна над головой врага: метка Пера Хугина / добыча Пути охотницы
##   Burst  — вспышка критического попадания
##   Bleed  — кровотечение от Кровавого Пера (урон тиками)


## Руна над врагом. Вешается ребёнком на самого врага, поэтому следует за ним
## и умирает вместе с ним. Один враг — одна руна на каждый key
class Mark extends Node2D:
	var color := Color(0.55, 0.75, 1.0)
	var time_left := 0.0
	var offset_y := -40.0
	var _t := 0.0

	static func attach(enemy: Node2D, key: String, col: Color, duration: float, y := -40.0) -> Mark:
		var existing := enemy.get_node_or_null(key) as Mark
		if existing:
			existing.time_left = maxf(existing.time_left, duration)
			return existing
		var m := Mark.new()
		m.name = key
		m.color = col
		m.time_left = duration
		m.offset_y = y
		m.z_index = 20
		enemy.add_child(m)
		return m

	func _process(delta: float) -> void:
		_t += delta
		time_left -= delta
		if time_left <= 0.0:
			queue_free()
			return
		position = Vector2(0.0, offset_y + sin(_t * 3.0) * 1.5)
		queue_redraw()

	func _draw() -> void:
		# Последнюю секунду руна мигает — видно, что метка вот-вот спадёт
		var a := 0.9
		if time_left < 1.0:
			a *= 0.4 + 0.6 * absf(sin(_t * 12.0))
		var s := 5.0
		var pts := PackedVector2Array([
			Vector2(0, -s * 1.5), Vector2(s, 0), Vector2(0, s * 1.5), Vector2(-s, 0), Vector2(0, -s * 1.5)])
		draw_circle(Vector2.ZERO, s * 2.2, Color(color, 0.12 * a))
		draw_polyline(pts, Color(color, a), 1.5, true)
		draw_line(Vector2(0, -s * 0.8), Vector2(0, s * 0.8), Color(color, a), 1.2)


## Вспышка крита: расходящееся кольцо + пара искр. Живёт 0.3 сек
class Burst extends Node2D:
	var color := Color(1.0, 0.85, 0.4)
	var _t := 0.0
	const LIFE := 0.3

	static func spawn(parent: Node, pos: Vector2, col: Color) -> void:
		var b := Burst.new()
		b.color = col
		b.z_index = 30
		parent.add_child(b)
		b.global_position = pos

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var a := 1.0 - k
		draw_arc(Vector2.ZERO, 4.0 + 16.0 * k, 0.0, TAU, 24, Color(color, a), 2.0, true)
		for i in 6:
			var d := Vector2.from_angle(i * TAU / 6.0 + 0.3)
			draw_line(d * (6.0 + 10.0 * k), d * (10.0 + 16.0 * k), Color(color, a * 0.8), 1.5)


## Над головой лучницы: ромбики — чем заряжены следующие стрелы (по одному
## на заряд, цвет навыка), под ними тонкие полоски действующих временных
## навыков. Данные каждый кадр выставляет archer.gd::_update_status_visual
class Status extends Node2D:
	var charges: Array[Color] = []
	var timers: Array[Vector2] = []     # x — осталось, y — всего
	var timer_colors: Array[Color] = []
	var _t := 0.0

	func _ready() -> void:
		position = Vector2(0, -40)
		z_index = 25

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.75 + 0.25 * sin(_t * 6.0)
		var step := 9.0
		var x0 := -step * (charges.size() - 1) / 2.0
		for i in charges.size():
			var c := Vector2(x0 + step * i, 0.0)
			var col: Color = charges[i]
			var pts := PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0)])
			draw_circle(c, 5.5, Color(col, 0.15 * pulse))
			draw_colored_polygon(pts, Color(col, pulse))
		var w := 26.0
		for i in timers.size():
			var y := 8.0 + i * 4.0
			var k := clampf(timers[i].x / maxf(timers[i].y, 0.01), 0.0, 1.0)
			draw_rect(Rect2(-w / 2.0, y, w, 2.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(-w / 2.0, y, w * k, 2.0), Color(timer_colors[i], 0.9))


## Кровотечение: ticks раз по damage с интервалом interval. Повторное
## наложение не складывается, а обновляет число оставшихся тиков. Тикает
## через enemy.take_bleed_damage — без стана и нокбэка, иначе каждый тик
## сбивал бы врага с ног
class Bleed extends Node:
	var ticks_left := 0
	var interval := 1.0
	var damage := 1
	var source: Node2D
	var _timer := 0.0

	static func apply(enemy: Node, ticks: int, dmg: int, every: float, from: Node2D) -> void:
		if not enemy.has_method("take_bleed_damage"):
			return
		var b := enemy.get_node_or_null("ArcherBleed") as Bleed
		if b == null:
			b = Bleed.new()
			b.name = "ArcherBleed"
			enemy.add_child(b)
		b.ticks_left = maxi(b.ticks_left, ticks)
		b.damage = dmg
		b.interval = every
		b.source = from
		b._timer = every
		Mark.attach(enemy as Node2D, "BleedMark", Color(0.9, 0.15, 0.1), every * ticks, -52.0)

	func _process(delta: float) -> void:
		var enemy := get_parent()
		if not is_instance_valid(enemy) or enemy.is_dead or ticks_left <= 0:
			queue_free()
			return
		_timer -= delta
		if _timer > 0.0:
			return
		_timer = interval
		ticks_left -= 1
		enemy.take_bleed_damage(damage, source)
