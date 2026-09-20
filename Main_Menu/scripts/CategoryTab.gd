extends Button
## CategoryTab.gd
## Пункт списка категорий в сайдбаре настроек (GENERAL / GRAPHICS / ...).
## Активная вкладка — золотой текст + ромбик слева, как индикатор фокуса
## у кнопок главного меню (MenuButton.gd). Остальные — приглушённый текст,
## светлеет по наведению.

const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")

const COLOR_TEXT := Color(0.62, 0.56, 0.48, 1.0)
const COLOR_HOVER := Color(0.85, 0.78, 0.66, 1.0)
const COLOR_ACTIVE := Color(0.92, 0.78, 0.45, 1.0)

var _marker: Control


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, 48)
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_color", COLOR_TEXT)
	add_theme_color_override("font_hover_color", COLOR_HOVER)
	add_theme_color_override("font_pressed_color", COLOR_ACTIVE)
	add_theme_color_override("font_focus_color", COLOR_TEXT)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("outline_size", 4)

	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 34
	empty.content_margin_top = 8
	empty.content_margin_bottom = 8
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)

	_marker = Control.new()
	_marker.set_script(DiamondMarkerScript)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.modulate.a = 0.0
	_marker.anchor_left = 0.0
	_marker.anchor_right = 0.0
	_marker.anchor_top = 0.5
	_marker.anchor_bottom = 0.5
	_marker.offset_left = 2.0
	_marker.offset_right = 17.0
	_marker.offset_top = -7.5
	_marker.offset_bottom = 7.5
	add_child(_marker)


## Отмечает вкладку активной/неактивной — вызывается через .call(), т.к.
## переменная-ссылка на кнопку в SettingsPanel.gd типизирована как Button
func set_active(is_active: bool) -> void:
	add_theme_color_override("font_color", COLOR_ACTIVE if is_active else COLOR_TEXT)
	_marker.modulate.a = 1.0 if is_active else 0.0
