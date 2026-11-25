extends Button
## MenuButton.gd — пункт главного меню в духе souls-like.
##
## Никаких плашек и рамок: заглавная антиква с разрядкой по центру колонки.
## Обычный пункт — приглушённый серый, выбранный «загорается»: текст светлеет
## до тёплого белого, за ним — едва заметное свечение, гаснущее к краям, по
## бокам — два тлеющих ромбика с тонкими чертами. Выбор — только светом.
##
## Одно состояние «выбран» на мышь, клавиатуру и геймпад: наведение мышью
## забирает фокус. subtitle — серая подпись под пунктом (сейчас не нужна, но
## оставлена). Звуки и действия — в MainMenu.gd.

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")

const FONT_SIZE := 23
const SUB_SIZE := 15
## Цвет выбранного: тёплый белый, как пламя свечи, а не золото
const LIT := Color(1.0, 0.95, 0.86)
const IDLE := Color(0.7, 0.69, 0.66)
const EMBER := Color(1.0, 0.62, 0.3)

var subtitle := "":
	set(v):
		subtitle = v
		_apply_margins()
		queue_redraw()

var _hl := 0.0
var _tween: Tween
var _sb: StyleBoxEmpty


func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font", Style.caps_font())
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_disabled_color", Color(IDLE, 0.4))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 2)
	_set_text_color(IDLE)

	# Один пустой стиль на все состояния: всё рисует _draw
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
	_sb.content_margin_left = 16
	_sb.content_margin_right = 16
	_sb.content_margin_top = 11
	_sb.content_margin_bottom = 11 + (22 if subtitle != "" else 0)


func _set_text_color(c: Color) -> void:
	for n in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(n, c)


func _set_hl(v: float) -> void:
	_hl = v
	_set_text_color(IDLE.lerp(LIT, clampf(v, 0.0, 1.0)))
	queue_redraw()


func _light(on: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hl, _hl, 1.0 if on else 0.0, 0.22 if on else 0.35)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## Нажатие — короткая вспышка, как искра от удара
func _on_down() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hl, 1.6, 1.0 if has_focus() else 0.0, 0.4).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var k := clampf(_hl, 0.0, 1.6)
	var font := Style.caps_font()
	var tw := font.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var cy := _sb.content_margin_top + (size.y - _sb.content_margin_top - _sb.content_margin_bottom) * 0.5
	var cx := size.x * 0.5
	if k > 0.001:
		# Свечение за текстом: широкая полоса, гаснущая к краям и по высоте
		var w := tw + 260.0
		var n := 28
		var sw := w / n
		for i in n:
			var t := (i + 0.5) / n
			var a := 1.0 - absf(t - 0.5) * 2.0
			a = a * a
			var x := cx - w * 0.5 + i * sw
			draw_rect(Rect2(x, cy - 13, sw + 0.5, 26), Color(EMBER, 0.045 * k * a))
			draw_rect(Rect2(x, cy - 5, sw + 0.5, 10), Color(EMBER, 0.04 * k * a))
		# Ромбики и черты по бокам текста
		for side in [-1.0, 1.0]:
			var mx: float = cx + side * (tw * 0.5 + 26.0)
			var d := 3.5
			var pts := PackedVector2Array([
				Vector2(mx, cy - d), Vector2(mx + d, cy), Vector2(mx, cy + d), Vector2(mx - d, cy)])
			draw_colored_polygon(pts, Color(EMBER, 0.85 * minf(k, 1.0)))
			var seg := 10
			for j in seg:
				var t2 := float(j) / seg
				var lx: float = mx + side * (10.0 + j * 4.0)
				draw_rect(Rect2(lx - (4.0 if side < 0 else 0.0), cy, 4.0, 1.0),
					Color(LIT, 0.35 * minf(k, 1.0) * (1.0 - t2)))
	if subtitle != "":
		var f := Style.font()
		var y := size.y - _sb.content_margin_bottom + 17.0
		draw_string(f, Vector2(0, y), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, SUB_SIZE,
			Color(Style.TEXT_DIM, 0.6 if disabled else 1.0))
