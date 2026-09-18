extends Control
## OrnamentSeparator.gd
## Разделитель между группами пунктов меню — тонкая линия с ромбиком
## по центру, в стиле разделительных линий на лого TLO

const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")

@export var line_color: Color = Color(0.55, 0.5, 0.4, 0.5)
@export var diamond_size: float = 12.0
@export var gap: float = 8.0


func _ready() -> void:
	var d := Control.new()
	d.set_script(DiamondMarkerScript)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.anchor_left = 0.5
	d.anchor_right = 0.5
	d.anchor_top = 0.5
	d.anchor_bottom = 0.5
	d.offset_left = -diamond_size / 2.0
	d.offset_right = diamond_size / 2.0
	d.offset_top = -diamond_size / 2.0
	d.offset_bottom = diamond_size / 2.0
	add_child(d)


func _draw() -> void:
	var y := size.y / 2.0
	var half_gap := diamond_size / 2.0 + gap
	draw_line(Vector2(0.0, y), Vector2(size.x / 2.0 - half_gap, y), line_color, 1.0)
	draw_line(Vector2(size.x / 2.0 + half_gap, y), Vector2(size.x, y), line_color, 1.0)
