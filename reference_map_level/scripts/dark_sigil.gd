@tool
extends Node2D
## dark_sigil.gd — знак Тёмного Солнца, намалёванный Орденом кровью и сажей
## на плитах двора храма Бальдра (ставит tools/temple_court.gd, узел
## TempleSigil у корня карты). Чёрный диск затмения, корона рваных
## кроваво-красных лучей, разорванное кольцо, потёки и брызги. Лежит на земле
## (3/4 вид — круг сплюснут), рисуется один раз; ночью темнеет вместе с землёй.

## Радиус знака (до концов длинных лучей), px
@export var radius := 112.0
@export var rays := 12
@export var seed_value := 7
## Сплющивание по вертикали (вид 3/4)
@export var depth := 0.62
@export var ray_color := Color(0.34, 0.03, 0.02, 0.78)
@export var disc_color := Color(0.03, 0.02, 0.02, 0.86)
@export var ring_color := Color(0.3, 0.03, 0.02, 0.62)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, depth))
	var disc_r := radius * 0.3
	# Лучи: длинные и короткие через один, края рваные, концы — потёки
	for i in rays:
		var a := TAU * i / rays + rng.randf_range(-0.05, 0.05)
		var long := i % 2 == 0
		var len := radius * (1.0 if long else 0.68) * rng.randf_range(0.9, 1.05)
		var half := (0.17 if long else 0.13) * rng.randf_range(0.85, 1.15)
		var pts := PackedVector2Array()
		var steps := 6
		# Левая кромка от диска к острию, правая — обратно, с зубцами
		for k in steps + 1:
			var t := float(k) / steps
			var w := half * (1.0 - t) + 0.01
			var rr := lerpf(disc_r * 0.9, len, t) + rng.randf_range(-3.0, 3.0)
			pts.append(Vector2.from_angle(a - w + rng.randf_range(-0.02, 0.02)) * rr)
		for k in range(steps, -1, -1):
			var t := float(k) / steps
			var w := half * (1.0 - t) + 0.01
			var rr := lerpf(disc_r * 0.9, len, t) + rng.randf_range(-3.0, 3.0)
			pts.append(Vector2.from_angle(a + w + rng.randf_range(-0.02, 0.02)) * rr)
		var c := ray_color
		c.a *= rng.randf_range(0.8, 1.0)
		draw_colored_polygon(pts, c)
		# Потёк с конца луча и пара капель
		var tip := Vector2.from_angle(a) * len
		draw_line(tip, tip + Vector2.from_angle(a) * rng.randf_range(4.0, 12.0), Color(c, c.a * 0.7), 2.0)
		for d in rng.randi_range(1, 3):
			var p := tip + Vector2.from_angle(a + rng.randf_range(-0.4, 0.4)) * rng.randf_range(6.0, 20.0)
			draw_circle(p, rng.randf_range(1.2, 3.0), Color(c, c.a * 0.8))
	# Разорванное кольцо между концами коротких и длинных лучей
	var ring_r := radius * 0.82
	var a0 := 0.0
	while a0 < TAU:
		var span := rng.randf_range(0.35, 0.9)
		draw_arc(Vector2.ZERO, ring_r + rng.randf_range(-2.0, 2.0), a0, minf(a0 + span, TAU), 16, ring_color,
				rng.randf_range(2.0, 3.6), true)
		a0 += span + rng.randf_range(0.08, 0.3)
	# Диск затмения: сплошной, край чуть рваный, тонкий кровавый ободок
	var disc := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		disc.append(Vector2.from_angle(a) * (disc_r + rng.randf_range(-1.5, 1.5)))
	draw_colored_polygon(disc, disc_color)
	draw_arc(Vector2.ZERO, disc_r + 2.0, 0.0, TAU, 48, Color(ray_color, 0.7), 2.5, true)
	# Брызги вокруг — мазали в спешке
	for i in 26:
		var a := rng.randf() * TAU
		var p := Vector2.from_angle(a) * rng.randf_range(radius * 0.35, radius * 1.15)
		draw_circle(p, rng.randf_range(0.8, 2.6), Color(ray_color, ray_color.a * rng.randf_range(0.4, 0.9)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
