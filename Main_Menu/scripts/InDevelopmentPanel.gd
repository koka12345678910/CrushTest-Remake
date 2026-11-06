extends Control
## InDevelopmentPanel.gd — окно «класс в разработке» поверх меню.
##
## Показывается, когда выбран герой, которого нет в Characters.AVAILABLE:
## вместо запуска уровня — это окно, игра не стартует. Сейчас доступны все
## трое, но окно остаётся на случай нового закрытого класса.
##
## Вид — как панели инвентаря (MenuStyle.gd): тёмная плашка с каймой,
## круглый медальон с посеревшим портретом и замком, золотой заголовок.
##
## Создаётся кодом на каждый показ и удаляет себя сам после закрытия.
## Закрыть — кнопка, Esc, Enter или пробел (A/B на геймпаде).

signal closed

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")

const PANEL_SIZE := Vector2(720, 520)
const GREY_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = vec3(l) * 1.1;
	COLOR = c;
}
"""

## Id героя из Characters — задаётся до add_child()
var hero_id := ""

var _font: Font
var _font_caps: Font
var _font_italic: Font
var _panel: Control
var _closing := false
var _audio: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.make_theme()
	_font = Style.font()
	_font_caps = Style.caps_font()
	_font_italic = Style.italic_font()
	_audio = Style.ui_player(self)
	Style.make_dim(self, 0.7)

	# Сама плашка — отдельный Control по центру: её и «наплываем» при открытии
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
	portrait.size = Vector2(256, 256)
	portrait.position = Vector2(PANEL_SIZE.x * 0.5 - 128, -18)
	var sh := Shader.new()
	sh.code = GREY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	portrait.material = mat
	_panel.add_child(portrait)

	var lock := Control.new()
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.size = PANEL_SIZE
	lock.draw.connect(_draw_lock.bind(lock))
	_panel.add_child(lock)

	var btn := Style.chip_button("ПОНЯТНО", 18)
	btn.size = Vector2(240, 48)
	btn.position = Vector2(PANEL_SIZE.x * 0.5 - 120, PANEL_SIZE.y - 84)
	btn.pressed.connect(close)
	_panel.add_child(btn)
	btn.call_deferred("grab_focus")

	resized.connect(_center)
	_center()

	modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Style.play(_audio, Style.SOUND_DENIED, -4.0)


func _center() -> void:
	if is_instance_valid(_panel):
		_panel.position = ((size - PANEL_SIZE) * 0.5).round()


func close() -> void:
	if _closing:
		return
	_closing = true
	Style.play_back(_audio)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2(0.97, 0.97), 0.16)
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
	if not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


func _draw_panel() -> void:
	var p := _panel
	var r := Rect2(Vector2.ZERO, PANEL_SIZE)
	var sb := Style.panel_box(6)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 26
	p.draw_style_box(sb, r)

	# Медальон под портретом — как портрет в HUD (clean_hud.Medallion)
	var c := Vector2(r.size.x * 0.5, 110)
	p.draw_circle(c, 86.0, Color(0, 0, 0, 0.6))
	p.draw_arc(c, 86.0, 0.0, TAU, 96, Color(Style.GOLD, 0.8), 2.0, true)
	p.draw_arc(c, 78.0, 0.0, TAU, 96, Color(1, 1, 1, 0.1), 1.0, true)

	var name_s := tr(String(Characters.display_name(hero_id)))
	p.draw_string(_font_caps, Vector2(0, 252), tr("В РАЗРАБОТКЕ"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Style.GOLD)
	p.draw_string(_font_caps, Vector2(0, 284), name_s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Style.TEXT_DIM)
	var n := 24
	var w := (r.size.x - 240.0) / n
	for i in n:
		var t := (i + 0.5) / n
		p.draw_rect(Rect2(120 + i * w, 306, w + 0.5, 1), Color(Style.GOLD, 0.35 * (1.0 - absf(t - 0.5) * 2.0)))
	var body := tr("Путь этого героя ещё куётся.\nОн появится в одном из следующих обновлений.")
	p.draw_multiline_string(_font_italic, Vector2(60, 350), body, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 120, 19, -1, Style.TEXT)


## Замок поверх портрета — сразу читается «закрыто»
func _draw_lock(c: Control) -> void:
	var lc := Vector2(PANEL_SIZE.x * 0.5 + 58, 168)
	c.draw_circle(lc, 20.0, Color(0.02, 0.02, 0.02))
	c.draw_arc(lc, 20.0, 0.0, TAU, 32, Style.GOLD, 1.5, true)
	c.draw_rect(Rect2(lc + Vector2(-8, -2), Vector2(16, 12)), Style.GOLD_HI)
	c.draw_arc(lc + Vector2(0, -3), 5.5, PI, TAU, 12, Style.GOLD_HI, 2.2, true)
	c.draw_circle(lc + Vector2(0, 4), 1.8, Color(0.02, 0.02, 0.02))
