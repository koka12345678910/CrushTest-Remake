extends Button
## MenuButton.gd — пункт главного меню в ключе инвентаря.
##
## Одно состояние «выбран» на мышь, клавиатуру и геймпад: наведение мышью
## забирает фокус, а фокус рисуется так же, как выбранное в инвентаре —
## золотая черта слева, полоса света, гаснущая вправо, текст в светлое
## золото. Остальное время текст тёплый почти белый (TEXT), а не бежевый.
##
## subtitle — серая подпись под пунктом (у «Продолжить» — чем продолжаем).
## Звуки и действия — в MainMenu.gd.

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")

const FONT_SIZE := 29
const SUB_SIZE := 16
const PAD_LEFT := 26.0
## Насколько текст выбранного пункта отъезжает вправо
const SHIFT := 10.0

var subtitle := "":
	set(v):
		subtitle = v
		_apply_margins()
		queue_redraw()

var _hl := 0.0
var _tween: Tween
var _sb: StyleBoxEmpty


func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font", Style.caps_font())
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_disabled_color", Color(Style.TEXT_DIM, 0.45))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 2)
	_set_text_color(Style.TEXT)

	# Один пустой стиль на все состояния: всё рисует _draw, а отступ слева
	# анимируется (сдвиг выбранного пункта)
	_sb = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, _sb)
	_apply_margins()

	mouse_entered.connect(func():
		if not disabled and is_visible_in_tree():
			grab_focus())
	focus_entered.connect(_light.bind(true))
	focus_exited.connect(_light.bind(false))
	button_down.connect(_on_down)


func _apply_margins() -> void:
	if _sb == null:
		return
	_sb.content_margin_left = PAD_LEFT + SHIFT * _hl
	_sb.content_margin_right = 16
	_sb.content_margin_top = 8
	_sb.content_margin_bottom = 8 + (24 if subtitle != "" else 0)


func _set_text_color(c: Color) -> void:
	for n in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(n, c)


func _set_hl(v: float) -> void:
	_hl = v
	_set_text_color(Style.TEXT.lerp(Style.GOLD_HI, clampf(v, 0.0, 1.0)))
	_apply_margins()
	queue_redraw()


func _light(on: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hl, _hl, 1.0 if on else 0.0, 0.16 if on else 0.24)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Нажатие — короткая вспышка полосы
func _on_down() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hl, 1.7, 1.0 if has_focus() else 0.0, 0.3).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	Style.draw_row_highlight(self, Rect2(Vector2.ZERO, size), minf(_hl, 1.7))
	if subtitle != "":
		var f := Style.font()
		var y := size.y - _sb.content_margin_bottom + 18.0
		draw_string(f, Vector2(_sb.content_margin_left + 2, y), subtitle,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - _sb.content_margin_left, SUB_SIZE,
			Color(Style.TEXT_DIM, 0.6 if disabled else 1.0))
