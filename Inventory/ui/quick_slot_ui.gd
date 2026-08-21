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

@export var icon_mask_radius := 0.48
# Резкий край, а не размытая виньетка — в магазине круг рисуется полигоном
# (жёсткая геометрическая граница), и здесь нужен тот же чёткий вид, а не
# мягкое затухание
@export var icon_mask_feather := 0.015

# Мягкое тёплое свечение позади иконки — вместо жёсткой панели пытаемся
# вписаться в уже существующий язык освещения уровня (тёплые круги света от
# фонарей на фоне тёмной ночной сцены): тёплое ядро + тёмное кольцо-ореол,
# затухающие к прозрачности, а не сплошной цвет с резким краем
@export var glow_color := Color(0.9, 0.72, 0.35)
@export var glow_ring_color := Color(0.05, 0.05, 0.05)
@export var glow_inner_alpha := 0.4
@export var glow_ring_alpha := 0.22

# Цвет счётчика зарядов: обычный — тёплое золото под стать свечению слота,
# на последнем заряде — тревожный красный, чтобы предмет не кончился внезапно
const CHARGES_COLOR := Color(0.98, 0.82, 0.35)
const CHARGES_LOW_COLOR := Color(0.92, 0.42, 0.25)

# Окантовка круглой иконки. Панель-фон игрок просил убрать (см. комментарий в
# _build_single_slot), но обводка — не коробка, а тонкая линия по контуру уже
# существующего круга: даёт слоту чёткую границу на пёстром фоне уровня, не
# возвращая сплошную плашку.
#
# Цвет взят с фоновой виньетки самих карточек предметов (jar_honey.png и
# подобные — тёмный, почти чёрный, с тёплым бурым оттенком по краю), а не
# случайный акцентный цвет: так кольцо выглядит продолжением самой иконки,
# а не чужеродной рамкой поверх неё. Заметность при этом держит не цвет (у
# игрока лёгкий дальтонизм — насыщенные оттенки путались), а пульсация
# ниже — сигнал через движение читается независимо от восприятия цвета
const RING_COLOR := Color(0.13, 0.10, 0.07)
@export var ring_width := 7.0

# Пульсация — плавное дыхание прозрачности кольца по кругу. Годо привязывает
# время жизни tween к узлу, на котором он создан (create_tween() ниже вызван
# неявно от self), так что при уничтожении HUD анимация сама остановится —
# отдельный disconnect/kill не нужен
const PULSE_MIN_ALPHA := 0.35
const PULSE_DURATION := 1.1

var _ability_system
var _icon: TextureRect
var _cooldown_bar: ProgressBar
var _index_label: Label
var _charges_label: Label
var _flash: ColorRect
var _border: Control
var _vbox: VBoxContainer


func _ready() -> void:
	pass


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
	icon_container.custom_minimum_size = Vector2(190, 190)
	# ВАЖНО: раньше тут стоял EXPAND_FILL по обеим осям — VBoxContainer
	# растягивал контейнер на всю доступную высоту/ширину слота (220x220
	# минус полоска кулдауна и текст), а они не равны друг другу. Контейнер
	# получался прямоугольным (шире, чем выше), и "круг" в UV-координатах
	# превращался в эллипс. SHRINK_CENTER фиксирует контейнер РОВНО на
	# custom_minimum_size (150x150 — квадрат) и центрирует его — без этого
	# никакая математика в шейдере круг не спасёт
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_icon.offset_left = 16
	_icon.offset_top = 16
	_icon.offset_right = -16
	_icon.offset_bottom = -16
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.material = mask_material
	icon_container.add_child(_icon)

	# Вспышка поверх иконки — тот же отступ и та же обрезка по кругу, иначе
	# при срабатывании она мигнула бы жёстким квадратом поверх круглой иконки
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.offset_left = 16
	_flash.offset_top = 16
	_flash.offset_right = -16
	_flash.offset_bottom = -16
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.material = mask_material
	icon_container.add_child(_flash)

	# Кольцо-окантовка — последним ребёнком, поэтому рисуется поверх иконки и
	# вспышки. Тот же инсет (16px), что у иконки, чтобы кольцо легло точно по
	# кругу маски, а не по внешнему краю контейнера
	_border = Control.new()
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.offset_left = 16
	_border.offset_top = 16
	_border.offset_right = -16
	_border.offset_bottom = -16
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.draw.connect(_draw_ring)
	# В момент этого вызова layout ещё не прошёл (init() выполняется синхронно
	# из _ready() владельца), поэтому size контрола на первой отрисовке — 0x0, и
	# кольцо рисовалось нулевым радиусом, то есть невидимым. resized стреляет,
	# когда движок пересчитает реальный размер по анкорам — тогда и просим
	# перерисовать уже с правильным size
	_border.resized.connect(_border.queue_redraw)
	icon_container.add_child(_border)
	_start_ring_pulse()

	# Тонкая полоса кулдауна — свой минималистичный стиль вместо стандартного
	# ползунка темы, чтобы не тащить за собой лишнюю рамку/фон
	_cooldown_bar = ProgressBar.new()
	_cooldown_bar.min_value = 0.0
	_cooldown_bar.max_value = 1.0
	_cooldown_bar.value = 1.0
	_cooldown_bar.show_percentage = false
	# Без ширины отдельно — по умолчанию VBoxContainer растягивает детей на всю
	# ширину контейнера (330px), а иконка теперь уже (170px, SHRINK_CENTER) —
	# полоса выглядела шире самой иконки. Ограничиваем шириной иконки и центрируем
	_cooldown_bar.custom_minimum_size = Vector2(icon_container.custom_minimum_size.x, 7)
	_cooldown_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

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

	# Заряды над номером слота — это то, на что игрок смотрит в бою чаще всего:
	# сколько ещё раз можно нажать. Номер слота ниже и тусклее, он вторичен
	_charges_label = Label.new()
	_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charges_label.add_theme_font_size_override("font_size", 24)
	_charges_label.add_theme_color_override("font_color", CHARGES_COLOR)
	_charges_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_charges_label.add_theme_constant_override("outline_size", 5)
	_vbox.add_child(_charges_label)

	_index_label = Label.new()
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.add_theme_font_size_override("font_size", 20)
	_index_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_index_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_index_label.add_theme_constant_override("outline_size", 5)
	_vbox.add_child(_index_label)


# Радиус кольца привязан к тем же icon_mask_radius/feather, что и обрезка
# иконки шейдером — так граница обводки совпадает с видимым краем круга, а не
# рисуется отдельным произвольным числом, которое разъедется при правке маски.
# ВАЖНО: в шейдере radius — это доля от ПОЛНОЙ ширины UV (0..1), а не от
# половины размера контрола, так что переводим в пиксели через size.x целиком,
# без дополнительного деления на 2 (та ошибка и делала кольцо вдвое меньше нужного)
func _draw_ring() -> void:
	if _border.size.x <= 0.0:
		return
	var r := _border.size.x * (icon_mask_radius + icon_mask_feather * 0.5)
	_border.draw_arc(_border.size / 2.0, r, 0.0, TAU, 64, RING_COLOR, ring_width, true)


# Бесконечное плавное дыхание alpha кольца — modulate, а не перерисовка цвета
# в draw_arc: дешевле (не гоняет queue_redraw каждый кадр) и не мешает
# _draw_ring пересчитывать геометрию отдельно при ресайзе
func _start_ring_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_border, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_border, "modulate:a", 1.0, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# peak_color задаётся отдельным параметром, а не фиксирован — чтобы отличать
# смену слота (нейтральный белый) от сброса кулдаунов (тёплое золото), не
# заводя два дублирующих друг друга метода
func _play_flash(peak_color := Color(1, 1, 1, 0.6), duration := 0.2) -> void:
	_flash.color = peak_color
	var tween = create_tween()
	tween.tween_property(_flash, "color", Color(peak_color.r, peak_color.g, peak_color.b, 0.0), duration)


func _refresh() -> void:
	if _ability_system == null:
		return
	var ability = _ability_system.get_current_ability()
	var total = _ability_system.abilities.size()
	var idx = _ability_system.current_index

	if ability:
		_icon.texture = ability.icon
		_cooldown_bar.value = ability.get_cooldown_progress()
		var charges = _ability_system.get_charges(ability)
		_charges_label.text = "x%d" % charges
		_charges_label.add_theme_color_override(
			"font_color", CHARGES_LOW_COLOR if charges <= 1 else CHARGES_COLOR)
	else:
		_icon.texture = null
		_cooldown_bar.value = 1.0
		_charges_label.text = ""

	# Пустой быстрый доступ — не "1 / 0", а честный ноль
	_index_label.text = "%d / %d" % [idx + 1, total] if total > 0 else "0 / %d" % _ability_system.MAX_SLOTS


func _on_slot_changed(_index: int, _ability) -> void:
	_play_flash()
	_refresh()


# Предмет израсходован до конца и вылетел из слота. Красная вспышка отличает
# это от обычной смены слота (белая) и сброса кулдаунов (золотая) — иначе
# исчезновение иконки посреди боя выглядело бы как баг
func _on_ability_depleted(_ability) -> void:
	_play_flash(Color(0.95, 0.3, 0.2, 0.7), 0.3)


func _on_cooldown_updated(index: int, progress: float) -> void:
	if _ability_system and index == _ability_system.current_index:
		_cooldown_bar.value = progress


# Массовый сброс кулдаунов (Руна Жертвы и подобное) — заметная тёплая
# золотая вспышка вместо нейтрального белого сигнала смены слота. Срабатывает
# независимо от того, какая способность сейчас в слоте: событие общее для
# всей системы, а виден игроку только один слот за раз
func _on_cooldowns_reset() -> void:
	_play_flash(Color(1.0, 0.85, 0.3, 0.75), 0.35)
	if _ability_system:
		var ability = _ability_system.get_current_ability()
		if ability:
			_cooldown_bar.value = ability.get_cooldown_progress()
