extends Button
## MenuButton.gd
## Кастомное поведение кнопок меню:
## — при наведении появляется линия слева и текст светлеет
## — при нажатии лёгкий сдвиг вправо
## — звуковые эффекты hover/click

const COLOR_NORMAL  := Color(0.70, 0.62, 0.52, 1.0)
const COLOR_HOVER   := Color(0.92, 0.85, 0.72, 1.0)
const COLOR_PRESSED := Color(0.78, 0.50, 0.19, 1.0)

var _line: Line2D
var _tween: Tween
var _base_x: float


func _ready() -> void:
	# Создаём декоративную линию слева от кнопки
	_line = Line2D.new()
	_line.width = 1.5
	_line.default_color = Color(0.78, 0.50, 0.19, 0.0)
	_line.add_point(Vector2(-24, size.y / 2))
	_line.add_point(Vector2(-6, size.y / 2))
	add_child(_line)

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

	# Линия появляется
	_tween.tween_method(
		func(a: float): _line.default_color.a = a,
		0.0, 1.0, 0.2
	)

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
	_tween.tween_method(
		func(a: float): _line.default_color.a = a,
		1.0, 0.0, 0.25
	)


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
