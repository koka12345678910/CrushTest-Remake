extends Button
## ToggleSwitch.gd
## Пилюля-переключатель для панели настроек — вместо текстовой кнопки
## ВКЛ/ВЫКЛ рисует классический тумблер (кружок скользит между краями).
## Использует встроенный toggle_mode кнопки, но полностью свой _draw()

const COLOR_OFF_BG := Color(0.16, 0.14, 0.12)
const COLOR_ON_BG := Color(0.55, 0.38, 0.15)
const COLOR_KNOB := Color(0.92, 0.85, 0.72)

var _knob_t := 0.0  # 0 = выключено (кружок слева), 1 = включено (справа)
var _tween: Tween


func _ready() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(62, 31)
	text = ""
	_knob_t = 1.0 if button_pressed else 0.0
	toggled.connect(_animate_to)
	queue_redraw()


## Мгновенно подгоняет вид под текущий button_pressed, без анимации — для
## начальной инициализации значения, чтобы не проигрывать твин/звук лишний
## раз при простом построении списка настроек
func sync() -> void:
	if _tween:
		_tween.kill()
	_knob_t = 1.0 if button_pressed else 0.0
	queue_redraw()


func _animate_to(v: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_knob_t, _knob_t, 1.0 if v else 0.0, 0.15)


func _set_knob_t(t: float) -> void:
	_knob_t = t
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var r := h / 2.0
	if r <= 0.0:
		return
	var bg := COLOR_OFF_BG.lerp(COLOR_ON_BG, _knob_t)
	draw_circle(Vector2(r, r), r, bg)
	draw_circle(Vector2(size.x - r, r), r, bg)
	if size.x - h > 0.0:
		draw_rect(Rect2(r, 0.0, size.x - h, h), bg)
	var knob_x := lerpf(r, size.x - r, _knob_t)
	draw_circle(Vector2(knob_x, r), r * 0.72, COLOR_KNOB)
