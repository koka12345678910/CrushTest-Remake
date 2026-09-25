extends Control
## InDevelopmentPanel.gd — окно "класс в разработке" поверх меню.
##
## Показывается, когда выбран герой, которого ещё нет в Characters.AVAILABLE
## (сейчас лучница и маг): вместо запуска уровня — это окно, игра не стартует.
## Стиль тот же, что у окон навыков и магазина: тёмная плита, двойная
## золотая кайма, кованые уголки, ромбы, медальон с посеревшим портретом.
##
## Создаётся кодом на каждый показ и удаляет себя сам после закрытия.
## Закрыть — кнопка, Esc, Enter или пробел.

signal closed

const OrnateButtonScript := preload("res://Inventory/ui/ornate_button.gd")

const PANEL_SIZE := Vector2(760, 540)
const GOLD := Color(0.8, 0.62, 0.34)
const GOLD_BRIGHT := Color(1.0, 0.8, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.3, 0.75)
const GOLD_FAINT := Color(0.55, 0.45, 0.3, 0.25)
const TEXT := Color(0.9, 0.84, 0.72)
const TEXT_DIM := Color(0.62, 0.57, 0.48)

const SOUND_OPEN := preload("res://Sound/UI_button/accept.wav")
const SOUND_CLOSE := preload("res://Sound/UI_button/choice.wav")

const GREY_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = vec3(l) * vec3(0.95, 0.9, 0.82) * 1.15;
	COLOR = c;
}
"""

## Id героя из Characters — задаётся до add_child()
var hero_id := ""
var _font: Font
var _font_italic: Font
var _panel: Control
var _t := 0.0
var _closing := false
var _audio: AudioStreamPlayer




func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	_font = serif
	var ital := SystemFont.new()
	ital.font_names = serif.font_names
	ital.font_italic = true
	_font_italic = ital

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	# Сама плита — отдельный Control по центру: её и "наплываем" при открытии
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	var portrait := TextureRect.new()
	portrait.texture = Characters.get_portrait(hero_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size = Vector2(250, 250)
	portrait.position = Vector2(PANEL_SIZE.x * 0.5 - 125, -12)
	var sh := Shader.new()
	sh.code = GREY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	portrait.material = mat
	_panel.add_child(portrait)

	var btn := Button.new()
	btn.set_script(OrnateButtonScript)
	btn.text = "UNDERSTOOD"
	btn.size = Vector2(240, 46)
	btn.position = Vector2(PANEL_SIZE.x * 0.5 - 120, PANEL_SIZE.y - 82)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_font_override("font", _font)
	btn.pressed.connect(close)
	_panel.add_child(btn)

	resized.connect(_center)
	_center()

	modulate.a = 0.0
	_panel.scale = Vector2(0.95, 0.95)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_play(SOUND_OPEN)


func _center() -> void:
	if is_instance_valid(_panel):
		_panel.position = (size - PANEL_SIZE) * 0.5


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()


func close() -> void:
	if _closing:
		return
	_closing = true
	_play(SOUND_CLOSE)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2(0.96, 0.96), 0.16)
	await tw.finished
	closed.emit()
	queue_free()


## Окно модальное: пока оно открыто, до панели выбора героя под ним не
## доходят ни Esc, ни стрелки
func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		close()
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_panel.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))


# ── Плита ────────────────────────────────────────────────────────────────────

func _draw_panel() -> void:
	var p := _panel
	var r := Rect2(Vector2.ZERO, PANEL_SIZE)
	var pulse := 0.8 + 0.2 * sin(_t * 2.2)
	var accent: Color = Characters.get_color(hero_id)

	# Свечение вокруг плиты
	for g in 5:
		p.draw_rect(r.grow(3.0 + g * 5.0), Color(1.0, 0.6, 0.2, 0.05 * pulse * (5 - g) / 5.0), false, 5.0)
	p.draw_rect(r, Color(0.04, 0.036, 0.032, 0.98))
	var c := Vector2(r.size.x * 0.5, 110)
	for i in 6:
		p.draw_circle(c, 260.0 - i * 36.0, Color(0.09, 0.08, 0.07, 0.06))
	# Рунный круг-гравировка за медальоном
	for rr in [118.0, 150.0]:
		p.draw_arc(c, rr, 0.0, TAU, 96, Color(0.55, 0.48, 0.38, 0.08), 1.0, true)
	for i in 10:
		p.draw_rect(r.grow(-i * 3.0), Color(0, 0, 0, 0.04), false, 3.0)

	p.draw_rect(r, GOLD_DIM, false, 1.5)
	p.draw_rect(r.grow(-8.0), GOLD_FAINT, false, 1.0)
	for cc in [[r.position, 1.0, 1.0], [Vector2(r.end.x, 0), -1.0, 1.0],
			[Vector2(0, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		_corner(cc[0], cc[1], cc[2])
	# Ромбы на верхней и нижней кромке
	for y in [0.0, r.end.y]:
		p.draw_circle(Vector2(c.x, y), 14.0, Color(1.0, 0.6, 0.2, 0.12 * pulse))
		_diamond(Vector2(c.x, y), 9.0, GOLD_BRIGHT, true)

	# Медальон под портретом
	p.draw_circle(c, 88.0, Color(0.03, 0.027, 0.024))
	p.draw_arc(c, 96.0, 0.0, TAU, 72, GOLD_FAINT, 1.0, true)
	p.draw_arc(c, 88.0, 0.0, TAU, 72, GOLD, 1.8, true)
	p.draw_arc(c, 80.0, 0.0, TAU, 72, Color(GOLD, 0.35), 1.0, true)
	for k in 36:
		var d := Vector2.from_angle(k * TAU / 36.0 + _t * 0.04)
		p.draw_line(c + d * 89.0, c + d * (93.0 if k % 3 else 97.0), GOLD_DIM, 1.0)
	for k in [0, 2]:
		_diamond(c + Vector2.from_angle(k * PI / 2.0) * 104.0, 5.0, GOLD, true)

	# Замок поверх портрета — сразу читается "закрыто"
	var lc := c + Vector2(54, 54)
	p.draw_circle(lc, 20.0, Color(0.05, 0.045, 0.04))
	p.draw_arc(lc, 20.0, 0.0, TAU, 32, GOLD, 1.5, true)
	p.draw_rect(Rect2(lc + Vector2(-8, -2), Vector2(16, 12)), GOLD_BRIGHT)
	p.draw_arc(lc + Vector2(0, -3), 5.5, PI, TAU, 12, GOLD_BRIGHT, 2.2, true)
	p.draw_circle(lc + Vector2(0, 4), 1.8, Color(0.05, 0.045, 0.04))

	# Тексты
	var name_s := Characters.display_name(hero_id)
	p.draw_string(_font, Vector2(0, 262), "IN DEVELOPMENT", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color(1.0, 0.88, 0.62))
	p.draw_string(_font, Vector2(0, 294), name_s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(accent, 0.9))
	_ornament_line(Vector2(120, 318), Vector2(r.size.x - 120, 318))
	var body := "The %s's path is still being forged.\nFor now, only the Warrior can take the oath —\nthis class will arrive in a future update." % name_s.capitalize()
	p.draw_multiline_string(_font_italic, Vector2(60, 360), body, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 120, 19, -1, TEXT)


func _corner(pt: Vector2, sx: float, sy: float) -> void:
	var p := _panel
	var o := Vector2(sx, sy)
	p.draw_line(pt + Vector2(-sx * 5, -sy * 5), pt + Vector2(sx * 44, -sy * 5), GOLD, 1.5)
	p.draw_line(pt + Vector2(-sx * 5, -sy * 5), pt + Vector2(-sx * 5, sy * 44), GOLD, 1.5)
	p.draw_line(pt + o * 10, pt + Vector2(sx * 30, sy * 10), Color(GOLD, 0.5), 1.0)
	p.draw_line(pt + o * 10, pt + Vector2(sx * 10, sy * 30), Color(GOLD, 0.5), 1.0)
	p.draw_line(pt + o * 12, pt + o * 24, GOLD_DIM, 1.0)
	p.draw_arc(pt + o * 28, 4.5, 0.0, TAU, 16, GOLD_DIM, 1.0, true)
	_diamond(pt + Vector2(-sx * 5, -sy * 5), 4.5, GOLD, true)


func _diamond(c: Vector2, s: float, col: Color, filled := false) -> void:
	var p := _panel
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	if filled:
		p.draw_colored_polygon(pts, Color(0.06, 0.05, 0.04))
	pts.append(pts[0])
	p.draw_polyline(pts, col, 1.3, true)
	if filled:
		p.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.4, 0),
				c + Vector2(0, s * 0.4), c + Vector2(-s * 0.4, 0)]), col)


func _ornament_line(a: Vector2, b: Vector2) -> void:
	var p := _panel
	var mid := (a + b) * 0.5
	p.draw_line(a, mid - Vector2(14, 0), GOLD_DIM, 1.0)
	p.draw_line(mid + Vector2(14, 0), b, GOLD_DIM, 1.0)
	_diamond(mid, 6.0, GOLD, true)
	_diamond(mid - Vector2(22, 0), 3.0, GOLD_DIM)
	_diamond(mid + Vector2(22, 0), 3.0, GOLD_DIM)
	p.draw_circle(a, 1.5, GOLD_DIM)
	p.draw_circle(b, 1.5, GOLD_DIM)
