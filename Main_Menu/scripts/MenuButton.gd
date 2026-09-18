extends Button
## MenuButton.gd
## Кастомное поведение кнопок меню:
## — при наведении слева появляется ромбик-маркер (как в референсе меню) и текст светлеет
## — при нажатии лёгкий сдвиг вправо
## — звуковые эффекты hover/click

const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")

const COLOR_NORMAL  := Color(0.70, 0.62, 0.52, 1.0)
const COLOR_HOVER   := Color(0.92, 0.85, 0.72, 1.0)
const COLOR_PRESSED := Color(0.78, 0.50, 0.19, 1.0)

const MARKER_SIZE := 16.0
const MARKER_OFFSET_X := -32.0

var _marker: Control
var _tween: Tween
var _base_x: float


func _ready() -> void:
	# Ромбик-маркер слева от кнопки — заанкорен на левый край по центру
	# высоты, поэтому не зависит от того, когда именно контейнер выставит
	# финальный size.y (та же ловушка тайминга, что и с _base_x ниже)
	_marker = Control.new()
	_marker.set_script(DiamondMarkerScript)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.modulate.a = 0.0
	_marker.anchor_left = 0.0
	_marker.anchor_right = 0.0
	_marker.anchor_top = 0.5
	_marker.anchor_bottom = 0.5
	_marker.offset_left = MARKER_OFFSET_X
	_marker.offset_right = MARKER_OFFSET_X + MARKER_SIZE
	_marker.offset_top = -MARKER_SIZE / 2.0
	_marker.offset_bottom = MARKER_SIZE / 2.0
	add_child(_marker)

	# Кнопка теперь центрируется контейнером (size_flags_horizontal = SHRINK_CENTER),
	# а не растягивается на всю ширину — реальный x выставляется отложенным
	# layout-пересчётом ПОСЛЕ _ready(). Если запомнить position.x прямо тут,
	# получим 0 (позицию до центрирования), и наведение будет анимировать
	# кнопку обратно к этой неверной точке у левого края. Ждём кадр, чтобы
	# контейнер успел расставить детей по местам
	await get_tree().process_frame
	_base_x = position.x

	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	button_down.connect(_on_press)
	button_up.connect(_on_release)

	# Начальный цвет
	add_theme_color_override("font_color", COLOR_NORMAL)


func _on_hover_enter() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)

	# Текст светлеет
	_tween.tween_method(
		func(c: Color): add_theme_color_override("font_color", c),
		COLOR_NORMAL, COLOR_HOVER, 0.18
	)

	# Сдвиг вправо
	_tween.tween_property(self, "position:x", _base_x + 10.0, 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Ромбик проявляется
	_tween.tween_property(_marker, "modulate:a", 1.0, 0.2)

	# Звук hover (если есть AudioManager)
	if Engine.has_singleton("AudioManager"):
		Engine.get_singleton("AudioManager").play_sfx("menu_hover")


func _on_hover_exit() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)

	_tween.tween_method(
		func(c: Color): add_theme_color_override("font_color", c),
		COLOR_HOVER, COLOR_NORMAL, 0.25
	)
	_tween.tween_property(self, "position:x", _base_x, 0.25)\
		.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_marker, "modulate:a", 0.0, 0.25)


func _on_press() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(
		func(c: Color): add_theme_color_override("font_color", c),
		COLOR_HOVER, COLOR_PRESSED, 0.08
	)

	if Engine.has_singleton("AudioManager"):
		Engine.get_singleton("AudioManager").play_sfx("menu_click")


func _on_release() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(
		func(c: Color): add_theme_color_override("font_color", c),
		COLOR_PRESSED, COLOR_HOVER, 0.15
	)
