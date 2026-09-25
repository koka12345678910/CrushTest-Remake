extends Control
## skill_tree_card.gd
## Карточка дерева навыков на экране выбора (окно "НАВЫКИ" в инвентаре):
## тёмный "каменный" фон с трещинами и кругами-разметкой, кованые уголки,
## эмблема дерева и название внизу с орнаментом.
##
## highlight 0..1 — подсветка (наведение). Выключенная карточка серая и
## приглушённая, включённая — эмблема в бронзе с тёплым свечением, рамка
## золотая, сверху/снизу ромбы. Меняется твином в set_highlighted().
##
## Эмблема — PNG из UI/icons (если есть) или нарисованная кодом заглушка
## того же стиля (emblem_kind), пока своей картинки у дерева нет.

signal pressed
## Наведение мыши — какую карточку подсветить, решает экран выбора
signal hovered

const GOLD := Color(0.8, 0.62, 0.34)
const GOLD_BRIGHT := Color(1.0, 0.78, 0.4)
const GREY := Color(0.42, 0.41, 0.4)
const TEXT_ON := Color(0.96, 0.86, 0.66)
const TEXT_OFF := Color(0.62, 0.57, 0.5)

const DESAT_SHADER := """
shader_type canvas_item;
uniform float saturation = 1.0;
uniform float brightness = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(l) * vec3(0.96, 0.96, 1.0), c.rgb, saturation) * brightness;
	COLOR = c;
}
"""

var title := ""
var emblem_texture: Texture2D
## "fang" — копьё-трезубец в круге (Клык Берсерка), "swirl" — вихрь
## (Воля Эйнхерия). Используется, только если emblem_texture == null
var emblem_kind := ""
var seed_value := 0

var highlight := 0.0:
	set(v):
		highlight = v
		_apply_highlight()

var _tween: Tween
var _t := 0.0
var _glow: TextureRect
var _emblem_tex: TextureRect
var _emblem_draw: Control
var _overlay: Control
var _label: Label
var _desat: ShaderMaterial
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	resized.connect(_layout)
	gui_input.connect(_on_gui_input)

	_glow = TextureRect.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.5, 0.15, 0.22))
	g.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_glow.texture = gt
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)

	if emblem_texture:
		_emblem_tex = TextureRect.new()
		_emblem_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_emblem_tex.texture = emblem_texture
		_emblem_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_emblem_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sh := Shader.new()
		sh.code = DESAT_SHADER
		_desat = ShaderMaterial.new()
		_desat.shader = sh
		_emblem_tex.material = _desat
		add_child(_emblem_tex)
	else:
		_emblem_draw = Control.new()
		_emblem_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_emblem_draw.draw.connect(_draw_procedural_emblem)
		add_child(_emblem_draw)

	_label = Label.new()
	_label.text = title
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	# Рамка и орнаменты — поверх всего, отдельной нодой
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	mouse_entered.connect(func(): hovered.emit())
	_make_cracks()
	_layout()
	_apply_highlight()




func set_highlighted(on: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "highlight", 1.0 if on else 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if highlight > 0.01:
		# Угли на эмблеме дышат
		_glow.modulate.a = highlight * (0.75 + 0.25 * sin(_t * 2.2))
		_overlay.queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _layout() -> void:
	if not is_instance_valid(_label):
		return
	var em := minf(size.x * 0.78, size.y * 0.62)
	var ec := Vector2(size.x * 0.5, size.y * 0.42)
	var er := Rect2(ec - Vector2(em, em) * 0.5, Vector2(em, em))
	_glow.position = er.position - er.size * 0.2
	_glow.size = er.size * 1.4
	if _emblem_tex:
		_emblem_tex.position = er.position
		_emblem_tex.size = er.size
	if _emblem_draw:
		_emblem_draw.position = er.position
		_emblem_draw.size = er.size
	_label.position = Vector2(0, size.y - 118.0)
	_label.size = Vector2(size.x, 44)
	_make_cracks()
	queue_redraw()


func _apply_highlight() -> void:
	if not is_instance_valid(_label):
		return
	_label.add_theme_color_override("font_color", TEXT_OFF.lerp(TEXT_ON, highlight))
	if _desat:
		_desat.set_shader_parameter("saturation", lerpf(0.0, 1.0, highlight))
		_desat.set_shader_parameter("brightness", lerpf(0.72, 1.08, highlight))
	if _emblem_draw:
		_emblem_draw.queue_redraw()
	_glow.modulate.a = highlight
	queue_redraw()
	_overlay.queue_redraw()


# ── Фон карточки ─────────────────────────────────────────────────────────────

## Трещины "камня" — случайные ломаные, но одинаковые между запусками (seed)
func _make_cracks() -> void:
	_cracks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_value
	for i in 7:
		var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var dir := Vector2.from_angle(rng.randf_range(0, TAU))
		var line := PackedVector2Array([p])
		for s in rng.randi_range(4, 9):
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			p += dir * rng.randf_range(12, 34)
			line.append(p)
		_cracks.append(line)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.035, 0.032, 0.03, 0.97))
	# Светлее к центру — как тусклый свет на каменной плите
	var c := size * Vector2(0.5, 0.42)
	for i in 6:
		var rad := minf(size.x, size.y) * (0.62 - i * 0.08)
		draw_circle(c, rad, Color(0.09, 0.08, 0.07, 0.07))
	# Тёплый отсвет у подсвеченной карточки
	if highlight > 0.0:
		for i in 5:
			draw_circle(c, minf(size.x, size.y) * (0.55 - i * 0.08), Color(0.35, 0.18, 0.05, 0.018 * highlight))
	# Круги-разметка вокруг эмблемы, как на гравировке
	var guide := Color(0.5, 0.45, 0.38, 0.08 + 0.05 * highlight)
	for k in 3:
		draw_arc(c, minf(size.x, size.y) * (0.3 + k * 0.08), 0.0, TAU, 96, guide, 1.0, true)
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0)
		draw_line(c + d * size.x * 0.3, c + d * size.x * 0.47, guide, 1.0)
	for line in _cracks:
		draw_polyline(line, Color(0, 0, 0, 0.35), 1.5, true)
		draw_polyline(line, Color(0.6, 0.55, 0.48, 0.05), 1.0, true)
	# Виньетка по краям
	for i in 10:
		draw_rect(r.grow(-i * 3.0), Color(0, 0, 0, 0.05), false, 3.0)


# ── Рамка и орнаменты поверх ─────────────────────────────────────────────────

func _draw_overlay() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var h := highlight
	var col := Color(0.4, 0.36, 0.3, 0.8).lerp(GOLD, h)

	# Свечение рамки у подсвеченной карточки
	if h > 0.0:
		var pulse := 0.8 + 0.2 * sin(_t * 2.5)
		for i in 4:
			_overlay.draw_rect(r.grow(2.0 + i * 3.0), Color(1.0, 0.6, 0.2, 0.09 * h * pulse * (4 - i) / 4.0), false, 3.0)
	_overlay.draw_rect(r, col, false, 1.5)
	_overlay.draw_rect(r.grow(-8.0), Color(col, 0.35), false, 1.0)

	for cc in [[Vector2.ZERO, 1.0, 1.0], [Vector2(size.x, 0), -1.0, 1.0],
			[Vector2(0, size.y), 1.0, -1.0], [size, -1.0, -1.0]]:
		_draw_corner(cc[0], cc[1], cc[2], col)

	# Орнамент под названием: линия с ромбом и завитками
	var uy := size.y - 58.0
	var cx := size.x * 0.5
	var lc := Color(col, 0.7)
	_overlay.draw_line(Vector2(cx - size.x * 0.3, uy), Vector2(cx - 22, uy), lc, 1.0)
	_overlay.draw_line(Vector2(cx + 22, uy), Vector2(cx + size.x * 0.3, uy), lc, 1.0)
	_diamond(Vector2(cx, uy), 7.0, col, true)
	_diamond(Vector2(cx - 16, uy), 3.0, lc)
	_diamond(Vector2(cx + 16, uy), 3.0, lc)

	# Ромбы на верхней и нижней кромке — только у подсвеченной
	if h > 0.01:
		var dc := Color(GOLD_BRIGHT, h)
		for y in [0.0, size.y]:
			_overlay.draw_circle(Vector2(cx, y), 14.0, Color(1.0, 0.6, 0.2, 0.15 * h))
			_diamond(Vector2(cx, y), 9.0, dc, true)


func _draw_corner(p: Vector2, sx: float, sy: float, col: Color) -> void:
	var L := 40.0
	var o := Vector2(sx, sy)
	# Двойная скобка
	_overlay.draw_line(p + o * 4, p + Vector2(sx * L, sy * 4), col, 1.5)
	_overlay.draw_line(p + o * 4, p + Vector2(sx * 4, sy * L), col, 1.5)
	_overlay.draw_line(p + o * 10, p + Vector2(sx * L * 0.65, sy * 10), Color(col, 0.6), 1.0)
	_overlay.draw_line(p + o * 10, p + Vector2(sx * 10, sy * L * 0.65), Color(col, 0.6), 1.0)
	# Завиток и лист по диагонали
	_overlay.draw_line(p + o * 12, p + o * 26, Color(col, 0.8), 1.2)
	_overlay.draw_arc(p + o * 30, 5.0, 0.0, TAU, 16, Color(col, 0.7), 1.0, true)
	_overlay.draw_arc(p + Vector2(sx * L, sy * 4) + Vector2(sx * 4, sy * 4), 4.0, PI, TAU, 10, Color(col, 0.6), 1.0, true)
	_diamond(p + o * 4, 4.0, col, true)


func _diamond(c: Vector2, s: float, col: Color, filled := false) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	if filled:
		_overlay.draw_colored_polygon(pts, Color(0.06, 0.05, 0.04))
	pts.append(pts[0])
	_overlay.draw_polyline(pts, col, 1.4, true)
	if filled:
		_overlay.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.4, 0),
				c + Vector2(0, s * 0.4), c + Vector2(-s * 0.4, 0)]), col)


# ── Эмблемы-заглушки (пока нет PNG) ──────────────────────────────────────────
# Рисуются "металлом": тёмный контур, заливка, светлая кромка

func _metal_line(pts: PackedVector2Array, w: float) -> void:
	var base := GREY.lerp(Color(0.72, 0.52, 0.3), highlight)
	_emblem_draw.draw_polyline(pts, Color(0.03, 0.025, 0.02), w + 4.0, true)
	_emblem_draw.draw_polyline(pts, base, w, true)
	_emblem_draw.draw_polyline(pts, Color(base.lightened(0.35), 0.6), maxf(w * 0.25, 1.0), true)


func _metal_poly(pts: PackedVector2Array) -> void:
	var base := GREY.lerp(Color(0.72, 0.52, 0.3), highlight)
	var loop := pts.duplicate()
	loop.append(pts[0])
	_emblem_draw.draw_polyline(loop, Color(0.03, 0.025, 0.02), 4.0, true)
	_emblem_draw.draw_colored_polygon(pts, base)
	_emblem_draw.draw_polyline(loop, Color(base.lightened(0.3), 0.7), 1.0, true)


func _draw_procedural_emblem() -> void:
	var s := _emblem_draw.size
	var c := s * 0.5
	var u := minf(s.x, s.y) / 2.0
	if emblem_kind == "fang":
		_draw_fang(c, u)
	elif emblem_kind == "swirl":
		_draw_swirl(c, u)


## Клык Берсерка: копьё сверху вниз, два изогнутых зубца-рога по бокам,
## разорванное кольцо и шипы
func _draw_fang(c: Vector2, u: float) -> void:
	var ring := u * 0.52
	# Кольцо разорвано сверху — там проходит древко
	var arc := PackedVector2Array()
	for i in 49:
		var a := -PI / 2.0 + 0.35 + (TAU - 0.7) * i / 48.0
		arc.append(c + Vector2.from_angle(a) * ring)
	_metal_line(arc, u * 0.045)
	# Древко
	_metal_line(PackedVector2Array([c + Vector2(0, -u * 0.7), c + Vector2(0, u * 0.95)]), u * 0.05)
	# Наконечник
	_metal_poly(PackedVector2Array([c + Vector2(0, -u * 1.0), c + Vector2(u * 0.13, -u * 0.62),
			c + Vector2(0, -u * 0.7), c + Vector2(-u * 0.13, -u * 0.62)]))
	# Зазубрины под наконечником
	for side: float in [-1.0, 1.0]:
		_metal_line(PackedVector2Array([c + Vector2(0, -u * 0.55), c + Vector2(side * u * 0.12, -u * 0.42)]), u * 0.03)
		# Боковые рога-зубцы: вверх и внутрь
		var horn := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			horn.append(c + Vector2(side * u * (0.15 + 0.3 * sin(t * PI * 0.9)), u * (0.2 - 0.6 * t)))
		_metal_line(horn, u * 0.04)
		# Шипы-наконечники на кольце слева/справа
		var sp := c + Vector2(side * ring, 0)
		_metal_poly(PackedVector2Array([sp + Vector2(side * u * 0.2, 0), sp + Vector2(0, -u * 0.08),
				sp + Vector2(-side * u * 0.06, 0), sp + Vector2(0, u * 0.08)]))
	# Нижний шип
	_metal_poly(PackedVector2Array([c + Vector2(0, u * 1.02), c + Vector2(u * 0.09, u * 0.72),
			c + Vector2(0, u * 0.62), c + Vector2(-u * 0.09, u * 0.72)]))


## Воля Эйнхерия: вихрь из изогнутых клинков вокруг звезды
func _draw_swirl(c: Vector2, u: float) -> void:
	var arms := 5
	for k in arms:
		var base_a := k * TAU / arms
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			var a := base_a + t * 2.4
			var r := u * (0.18 + 0.72 * t)
			var w := u * 0.13 * sin(t * PI) * (1.0 - t * 0.4)
			var d := Vector2.from_angle(a)
			var n := Vector2.from_angle(a + PI / 2.0)
			outer.append(c + d * r + n * w)
			inner.append(c + d * r - n * w * 0.4)
		inner.reverse()
		_metal_poly(outer + inner)
	# Звезда в центре
	var star := PackedVector2Array()
	for i in 8:
		var rr := u * (0.14 if i % 2 == 0 else 0.045)
		star.append(c + Vector2.from_angle(-PI / 2.0 + i * TAU / 8.0) * rr)
	_metal_poly(star)
