# res://ui/quick_slot_ui.gd
extends Control
## Быстрый слот HUD (правый нижний угол): круглый медальон с иконкой предмета,
## золотое кольцо, по которому идёт дуга кулдауна, стрелки переключения по
## бокам, значок с номером слота, под медальоном — плашка с зарядами и "N / M".

# Иконки предметов (jar_honey.png и т.п.) нарисованы как квадратная карточка
# с чёрными углами — на HUD без обрезки этот чёрный квадрат вылезает поверх
# травы как инородная коробка. Обрезаем иконку и вспышку по кругу шейдером
const CIRCLE_MASK_SHADER_CODE := """
shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.46;
uniform float feather : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float mask = 1.0 - smoothstep(radius, radius + feather, dist);
	COLOR.a *= mask;
}
"""

const OrnateFrameScript := preload("res://Main_Menu/scripts/OrnateFrame.gd")
const WORN_MATERIAL := preload("res://UI/hud_worn_material.tres")

@export var icon_mask_radius := 0.48
@export var icon_mask_feather := 0.015

# Мягкое тёплое свечение позади медальона — вписывается в язык освещения
# уровня (тёплые круги света от фонарей на тёмной ночной сцене)
@export var glow_color := Color(0.9, 0.72, 0.35)
@export var glow_inner_alpha := 0.32

# Цвет счётчика зарядов: обычный — тёплое золото, на последнем заряде —
# тревожный красный, чтобы предмет не кончился внезапно
const CHARGES_COLOR := Color(0.98, 0.82, 0.35)
const CHARGES_LOW_COLOR := Color(0.92, 0.42, 0.25)
const TEXT_COLOR := Color(0.9, 0.84, 0.72)
const GOLD := Color(0.72, 0.57, 0.33)
const GOLD_BRIGHT := Color(0.98, 0.8, 0.42)

# Показывается вместо иконки, когда быстрый слот пуст
const EMPTY_SLOT_ICON := preload("res://Shop/icons/empty_slot_256x256.png")

# Пульсация кольца — плавное дыхание прозрачности. У игрока лёгкий дальтонизм:
# заметность слота держит движение, а не насыщенность цвета
const PULSE_MIN_ALPHA := 0.55
const PULSE_DURATION := 1.1

## Диаметр медальона и отступ его верха от верха контрола
const MEDAL := 128.0
const MEDAL_TOP := 4.0

## Общий масштаб слота. Растёт от правого нижнего угла, чтобы не уезжать
## за край экрана
@export var hud_scale := 1.25

var _ability_system
var _icon: TextureRect
var _flash: ColorRect
var _ring: Control
var _ring_glow: Control
var _badge_label: Label
var _charges_box: Control
var _charges_label: Label
var _index_label: Label
var _cooldown := 1.0


func init(system) -> void:
	_ability_system = system
	system.slot_changed.connect(_on_slot_changed)
	system.cooldown_updated.connect(_on_cooldown_updated)
	system.cooldowns_reset.connect(_on_cooldowns_reset)
	system.ability_depleted.connect(_on_ability_depleted)
	# Заряды живут в сумке, а не в способности — цифру "осталось" обновляет она
	if system.inventory:
		system.inventory.count_changed.connect(func(_n: String, _c: int): _refresh())
	_build_single_slot()
	pivot_offset = Vector2(offset_right - offset_left, offset_bottom - offset_top)
	scale = Vector2(hud_scale, hud_scale)
	_refresh()


func _build_single_slot() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Шрифт с засечками и нормальными цифрами — как в инвентаре
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	var t := Theme.new()
	t.default_font = serif
	theme = t

	# size контрола на момент init() может быть ещё не выставлен (layout не
	# прошёл) — берём ширину из custom-размера сцены через offset'ы
	var w := maxf(size.x, offset_right - offset_left)
	var cx := w / 2.0
	var medal_pos := Vector2(cx - MEDAL / 2.0, MEDAL_TOP)

	# Свечение-ореол позади медальона
	var glow := TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(glow_color, glow_inner_alpha),
		Color(0.05, 0.05, 0.05, 0.2),
		Color(0, 0, 0, 0),
	])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 256
	grad_tex.height = 256
	glow.texture = grad_tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.position = medal_pos - Vector2(26, 26)
	glow.size = Vector2(MEDAL + 52, MEDAL + 52)
	add_child(glow)

	# Тёмный диск под иконкой — иконка лежит на нём, а не на траве уровня
	var disc := Control.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.position = medal_pos
	disc.size = Vector2(MEDAL, MEDAL)
	disc.draw.connect(func():
		disc.draw_circle(Vector2(MEDAL, MEDAL) / 2.0, MEDAL * 0.44, Color(0.035, 0.03, 0.026, 0.94)))
	add_child(disc)

	# Общий материал обрезки по кругу — один на иконку и вспышку
	var mask_shader := Shader.new()
	mask_shader.code = CIRCLE_MASK_SHADER_CODE
	var mask_material := ShaderMaterial.new()
	mask_material.shader = mask_shader
	mask_material.set_shader_parameter("radius", icon_mask_radius)
	mask_material.set_shader_parameter("feather", icon_mask_feather)

	var inset := 14.0
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = medal_pos + Vector2(inset, inset)
	_icon.size = Vector2(MEDAL - inset * 2.0, MEDAL - inset * 2.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.material = mask_material
	add_child(_icon)

	# Вспышка поверх иконки — та же обрезка по кругу, иначе мигнула бы квадратом
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.position = _icon.position
	_flash.size = _icon.size
	_flash.color = Color(1, 1, 1, 0)
	_flash.material = mask_material
	add_child(_flash)

	# Кольцо с дугой кулдауна, стрелками и засечками — поверх иконки
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.position = medal_pos
	_ring.size = Vector2(MEDAL, MEDAL)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)

	# Внешнее мерцающее кольцо — отдельной нодой, чтобы пульсировало только
	# оно, а не дуга кулдауна
	_ring_glow = Control.new()
	_ring_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_glow.position = medal_pos
	_ring_glow.size = Vector2(MEDAL, MEDAL)
	_ring_glow.draw.connect(func():
		_ring_glow.draw_arc(Vector2(MEDAL, MEDAL) / 2.0, MEDAL * 0.5 + 3.0, 0.0, TAU, 64,
			Color(GOLD_BRIGHT, 0.45), 1.2, true))
	add_child(_ring_glow)
	_start_ring_pulse()

	# Значок с номером слота — у нижнего правого края медальона
	var badge_c := medal_pos + Vector2(MEDAL, MEDAL) / 2.0 + Vector2(MEDAL * 0.36, MEDAL * 0.36)
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = badge_c - Vector2(14, 14)
	badge.size = Vector2(28, 28)
	badge.draw.connect(func():
		badge.draw_circle(Vector2(14, 14), 13.0, Color(0.04, 0.035, 0.03, 0.97))
		badge.draw_arc(Vector2(14, 14), 13.0, 0.0, TAU, 32, GOLD, 1.5, true))
	add_child(badge)
	_badge_label = _make_label("", 15, TEXT_COLOR)
	_badge_label.position = badge.position
	_badge_label.size = badge.size
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_badge_label)

	# Плашка с зарядами под медальоном
	var box_w := 92.0
	var box_h := 34.0
	var box_y := MEDAL_TOP + MEDAL + 12.0
	_charges_box = Control.new()
	_charges_box.set_script(OrnateFrameScript)
	_charges_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charges_box.position = Vector2(cx - box_w / 2.0, box_y)
	_charges_box.size = Vector2(box_w, box_h)
	_charges_box.set("fill_color", Color(0.035, 0.03, 0.027, 0.92))
	_charges_box.set("corner_length", 8.0)
	add_child(_charges_box)

	_charges_label = _make_label("", 21, CHARGES_COLOR)
	_charges_label.position = _charges_box.position
	_charges_label.size = _charges_box.size
	_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charges_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_charges_label)

	_index_label = _make_label("", 18, TEXT_COLOR)
	_index_label.position = Vector2(cx - 60.0, box_y + box_h + 4.0)
	_index_label.size = Vector2(120.0, 26.0)
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_index_label)

	# Потёртость на всём "металле" слота — тот же материал, что у полосок HUD.
	# Иконку предмета и цифры не трогаем: им нужна читаемость
	for node: CanvasItem in [disc, _ring, _ring_glow, badge, _charges_box]:
		node.material = WORN_MATERIAL


func _draw_ring() -> void:
	var c := Vector2(MEDAL, MEDAL) / 2.0
	var r := MEDAL * 0.5 - 2.0
	# Основное кольцо: тусклое целиком, яркая дуга — насколько предмет готов
	_ring.draw_arc(c, r, 0.0, TAU, 64, Color(GOLD, 0.45), 3.0, true)
	if _cooldown > 0.0:
		_ring.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * _cooldown, 64,
			GOLD_BRIGHT if _cooldown >= 1.0 else GOLD, 3.0, true)
	# Внутреннее тонкое кольцо — "кованая" двойная кайма
	_ring.draw_arc(c, r - 6.0, 0.0, TAU, 64, Color(GOLD, 0.4), 1.0, true)

	# Засечки сверху и снизу
	_ring.draw_line(c + Vector2(0, -r - 2.0), c + Vector2(0, -r - 10.0), GOLD, 1.5)
	_ring.draw_line(c + Vector2(0, r + 2.0), c + Vector2(0, r + 8.0), GOLD, 1.5)

	# Стрелки переключения слота по бокам
	for dir in [-1.0, 1.0]:
		var base := c + Vector2(dir * (r + 12.0), 0.0)
		_ring.draw_polyline(PackedVector2Array([
			base + Vector2(0, -7), base + Vector2(dir * 7.0, 0), base + Vector2(0, 7)]),
			GOLD_BRIGHT, 2.0, true)
		_ring.draw_circle(base + Vector2(dir * 13.0, 0), 2.0, GOLD)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


# Бесконечное плавное дыхание внешнего кольца — modulate, а не перерисовка:
# дешевле и не мешает дуге кулдауна
func _start_ring_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_ring_glow, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_ring_glow, "modulate:a", 1.0, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# peak_color задаётся отдельным параметром — чтобы отличать смену слота
# (нейтральный белый) от сброса кулдаунов (тёплое золото)
func _play_flash(peak_color := Color(1, 1, 1, 0.6), duration := 0.2) -> void:
	_flash.color = peak_color
	var tween = create_tween()
	tween.tween_property(_flash, "color", Color(peak_color.r, peak_color.g, peak_color.b, 0.0), duration)


func _set_cooldown(progress: float) -> void:
	progress = clampf(progress, 0.0, 1.0)
	if not is_equal_approx(progress, _cooldown):
		_cooldown = progress
		_ring.queue_redraw()


func _refresh() -> void:
	if _ability_system == null:
		return
	var ability = _ability_system.get_current_ability()
	var total = _ability_system.abilities.size()
	var idx = _ability_system.current_index

	if ability:
		_icon.texture = ability.icon
		_set_cooldown(ability.get_cooldown_progress())
		var charges = _ability_system.get_charges(ability)
		_charges_label.text = "x%d" % charges
		_charges_label.add_theme_color_override(
			"font_color", CHARGES_LOW_COLOR if charges <= 1 else CHARGES_COLOR)
		_charges_box.visible = true
		_badge_label.text = str(idx + 1)
	else:
		_icon.texture = EMPTY_SLOT_ICON
		# Пустому слоту нечего показывать дугой — полная золотая выглядела бы
		# как "готово к использованию", хотя использовать нечего
		_set_cooldown(0.0)
		_charges_label.text = ""
		_charges_box.visible = false
		_badge_label.text = "–"

	# Пустой быстрый доступ — не "1 / 0", а честный ноль
	_index_label.text = "%d / %d" % [idx + 1, total] if total > 0 else "0 / %d" % _ability_system.MAX_SLOTS


func _on_slot_changed(_index: int, _ability) -> void:
	_play_flash()
	_refresh()


# Предмет израсходован до конца и вылетел из слота. Красная вспышка отличает
# это от обычной смены слота (белая) и сброса кулдаунов (золотая)
func _on_ability_depleted(_ability) -> void:
	_play_flash(Color(0.95, 0.3, 0.2, 0.7), 0.3)


func _on_cooldown_updated(index: int, progress: float) -> void:
	if _ability_system and index == _ability_system.current_index:
		_set_cooldown(progress)


# Массовый сброс кулдаунов (Руна Жертвы и подобное) — тёплая золотая вспышка
func _on_cooldowns_reset() -> void:
	_play_flash(Color(1.0, 0.85, 0.3, 0.75), 0.35)
	if _ability_system:
		var ability = _ability_system.get_current_ability()
		if ability:
			_set_cooldown(ability.get_cooldown_progress())
