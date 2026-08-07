# res://ui/quick_slot_ui.gd
extends Control

# Иконки предметов (jar_honey.png и т.п.) нарисованы как квадратная карточка
# с чёрными углами — это нормально смотрится в инвентаре на тёмном фоне, но
# без панели-подложки на HUD этот чёрный квадрат вылезает поверх травы как
# инородная коробка. Обрезаем иконку и вспышку по кругу шейдером — так виден
# только сам предмет, без квадратной рамки исходной текстуры
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

@export var icon_mask_radius := 0.46
@export var icon_mask_feather := 0.12

# Мягкое тёплое свечение позади иконки — вместо жёсткой панели пытаемся
# вписаться в уже существующий язык освещения уровня (тёплые круги света от
# фонарей на фоне тёмной ночной сцены): тёплое ядро + тёмное кольцо-ореол,
# затухающие к прозрачности, а не сплошной цвет с резким краем
@export var glow_color := Color(0.9, 0.72, 0.35)
@export var glow_ring_color := Color(0.05, 0.05, 0.05)
@export var glow_inner_alpha := 0.4
@export var glow_ring_alpha := 0.22

var _ability_system
var _icon: TextureRect
var _cooldown_bar: ProgressBar
var _index_label: Label
var _flash: ColorRect
var _vbox: VBoxContainer


func _ready() -> void:
	pass


func init(system) -> void:
	_ability_system = system
	system.slot_changed.connect(_on_slot_changed)
	system.cooldown_updated.connect(_on_cooldown_updated)
	_build_single_slot()
	_refresh()


func _build_single_slot() -> void:
	# Без панели-фона — раньше тут была тёмная плашка с рамкой, но игрок
	# просил показывать только саму иконку и цифры под ней, без коробки.
	# Из-за этого текст/иконка лежат прямо на игровом мире (трава, камни,
	# что угодно), поэтому читаемость держим обводкой шрифта, а не фоном.
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_vbox)

	# Контейнер для свечения + иконки + вспышки — размер заметно увеличен
	# относительно старых 112x112, чтобы слот было видно с одного взгляда
	var icon_container := Control.new()
	icon_container.custom_minimum_size = Vector2(150, 150)
	icon_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(icon_container)

	# Свечение — фон-подложка. Радиальный градиент вместо панели: тёплое ядро,
	# тёмное кольцо-ореол, прозрачные края. Рисуется ПЕРВЫМ, поэтому лежит под
	# иконкой
	var glow := TextureRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(glow_color.r, glow_color.g, glow_color.b, glow_inner_alpha),
		Color(glow_ring_color.r, glow_ring_color.g, glow_ring_color.b, glow_ring_alpha),
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
	icon_container.add_child(glow)

	# Общий материал обрезки по кругу — общие параметры, поэтому один
	# ShaderMaterial безопасно разделить между иконкой и вспышкой
	var mask_shader := Shader.new()
	mask_shader.code = CIRCLE_MASK_SHADER_CODE
	var mask_material := ShaderMaterial.new()
	mask_material.shader = mask_shader
	mask_material.set_shader_parameter("radius", icon_mask_radius)
	mask_material.set_shader_parameter("feather", icon_mask_feather)

	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Отступ внутрь контейнера — оставляет свечению место "выйти" за пределы
	# самой иконки мягким ореолом, а не обрываться точно по её границе
	_icon.offset_left = 12
	_icon.offset_top = 12
	_icon.offset_right = -12
	_icon.offset_bottom = -12
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.material = mask_material
	icon_container.add_child(_icon)

	# Вспышка поверх иконки — тот же отступ и та же обрезка по кругу, иначе
	# при срабатывании она мигнула бы жёстким квадратом поверх круглой иконки
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.offset_left = 12
	_flash.offset_top = 12
	_flash.offset_right = -12
	_flash.offset_bottom = -12
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.material = mask_material
	icon_container.add_child(_flash)

	# Тонкая полоса кулдауна — свой минималистичный стиль вместо стандартного
	# ползунка темы, чтобы не тащить за собой лишнюю рамку/фон
	_cooldown_bar = ProgressBar.new()
	_cooldown_bar.min_value = 0.0
	_cooldown_bar.max_value = 1.0
	_cooldown_bar.value = 1.0
	_cooldown_bar.show_percentage = false
	_cooldown_bar.custom_minimum_size = Vector2(0, 6)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.35)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	_cooldown_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.85, 0.5, 0.9)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	_cooldown_bar.add_theme_stylebox_override("fill", bar_fill)

	_vbox.add_child(_cooldown_bar)

	_index_label = Label.new()
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.add_theme_font_size_override("font_size", 18)
	_index_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_index_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_index_label.add_theme_constant_override("outline_size", 5)
	_vbox.add_child(_index_label)


func _play_flash() -> void:
	_flash.color = Color(1, 1, 1, 0.6)
	var tween = create_tween()
	tween.tween_property(_flash, "color", Color(1, 1, 1, 0), 0.2)


func _refresh() -> void:
	if _ability_system == null:
		return
	var ability = _ability_system.get_current_ability()
	var total = _ability_system.abilities.size()
	var idx = _ability_system.current_index

	if ability:
		_icon.texture = ability.icon
		_cooldown_bar.value = ability.get_cooldown_progress()
	else:
		_icon.texture = null
		_cooldown_bar.value = 1.0

	_index_label.text = "%d / %d" % [idx + 1, total]


func _on_slot_changed(_index: int, _ability) -> void:
	_play_flash()
	_refresh()


func _on_cooldown_updated(index: int, progress: float) -> void:
	if _ability_system and index == _ability_system.current_index:
		_cooldown_bar.value = progress
