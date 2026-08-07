# res://ui/health_stamina_bar.gd
# Прикрепи к CanvasLayer ноде "HealthStaminaBar"
# Структура сцены:
#   HealthStaminaBar (CanvasLayer)  ← этот скрипт
extends CanvasLayer

# --- HP ---
var max_hp: float = 100.0
var current_hp: float = 100.0
var delayed_hp: float = 100.0       # белая полоска отставания
var delay_speed: float = 30.0       # скорость убывания белой полоски
var delay_timer: float = 0.0        # пауза перед началом убывания
var delay_pause: float = 0.8        # секунд до начала убывания

# --- Стамина ---
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_regen: float = 20.0     # регенерация в секунду
var stamina_regen_delay: float = 1.0
var stamina_regen_timer: float = 0.0
var _displayed_posture: float = 0.0  # то что видит игрок

# --- Размеры (подгонишь в редакторе через export) ---
@export var posture_fill_speed: float = 8.0   # скорость заполнения
@export var posture_drain_speed: float = 40.0  # скорость опустошения (быстрее)
@export var hp_bar_size: Vector2 = Vector2(460, 26)
@export var stamina_bar_size: Vector2 = Vector2(380, 18)
# hp_position теперь отсчитывается от НИЖНЕГО левого угла экрана (контейнер
# висит на якоре BOTTOM_LEFT) — отрицательный Y поднимает полоску над нижним
# краем, а не опускает от верхнего, как было раньше
@export var hp_position: Vector2 = Vector2(16, -76)
@export var stamina_offset_x: float = 16.0  # смещение от левого края
@export var stamina_position_y: float = -124.0  # отступ от нижнего края, стамина висит НАД HP
@export var posture_bar_size: Vector2 = Vector2(440, 16)
@export var posture_offset_x: float = -220.0  # половина ширины — центрирует полоску
@export var posture_position_y: float = 16.0    # теперь отступ от ВЕРХНЕГО края

# --- Концентрация (Posture) ---
var max_posture: float = 100.0
var current_posture: float = 0.0
var _posture_bg: ColorRect
var _posture_fill: ColorRect
var _posture_fill_right: ColorRect

# --- Узлы ---
var _hp_bg: ColorRect
var _hp_delayed: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label

var _stam_bg: ColorRect
var _stam_fill: ColorRect

var _root: Control


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	_update_delayed_hp(delta)
	_update_stamina_regen(delta)
	_update_visuals()


# ----------------------------------------------------------
# ПУБЛИЧНЫЕ МЕТОДЫ — вызывай из player.gd
# ----------------------------------------------------------

func take_damage(amount: float) -> void:
	current_hp = max(current_hp - amount, 0.0)
	delay_timer = delay_pause  # сбрасываем паузу


func heal(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp)
	# delayed тоже двигаем если лечимся выше него
	delayed_hp = max(delayed_hp, current_hp)


func use_stamina(amount: float) -> bool:
	if current_stamina <= 0.0:
		return false
	current_stamina = max(current_stamina - amount, 0.0)
	stamina_regen_timer = stamina_regen_delay  # пауза перед регеном
	return true


func set_max_hp(value: float) -> void:
	max_hp = value
	current_hp = value
	delayed_hp = value


func set_max_stamina(value: float) -> void:
	max_stamina = value
	current_stamina = value


func is_alive() -> bool:
	return current_hp > 0.0

func set_max_posture(value: float) -> void:
	max_posture = value
	current_posture = 0.0

func set_posture(value: float) -> void:
	current_posture = clamp(value, 0.0, max_posture)
# ----------------------------------------------------------
# ВНУТРЕННЯЯ ЛОГИКА
# ----------------------------------------------------------

func _update_delayed_hp(delta: float) -> void:
	if delay_timer > 0.0:
		delay_timer -= delta
		return
	if delayed_hp > current_hp:
		delayed_hp = max(delayed_hp - delay_speed * delta, current_hp)


func _update_stamina_regen(delta: float) -> void:
	# Регенерация только если стамина не тратится прямо сейчас
	if stamina_regen_timer > 0.0:
		stamina_regen_timer -= delta
		return
	current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)


func _update_visuals() -> void:
	if not is_instance_valid(_hp_fill):
		return

	var hp_ratio := current_hp / max_hp
	var delayed_ratio := delayed_hp / max_hp
	var stam_ratio := current_stamina / max_stamina

	_hp_fill.size.x = hp_bar_size.x * hp_ratio
	_hp_delayed.size.x = hp_bar_size.x * delayed_ratio
	_stam_fill.size.x = stamina_bar_size.x * stam_ratio
	
	if _posture_fill and _posture_fill_right:
		var ratio = current_posture / max_posture
		var half = posture_bar_size.x / 2.0
		var fill_width = half * ratio  # ширина каждой половины

		# Левая — позиция сдвигается влево, растёт влево от центра
		_posture_fill.size.x = fill_width
		_posture_fill.position.x = half - fill_width

		# Правая — просто растёт вправо от центра
		_posture_fill_right.size.x = fill_width

		# Цвет обеих половин
		var color: Color
		if ratio < 0.5:
			color = Color(0.9, 0.8, 0.2)   # жёлтый
		elif ratio < 0.8:
			color = Color(0.95, 0.5, 0.1)  # оранжевый
		else:
			color = Color(1.0, 0.15, 0.1)  # красный
		_posture_fill.color = color
		_posture_fill_right.color = color

	# Цвет HP меняется при низком здоровье
	if hp_ratio > 0.5:
		_hp_fill.color = Color(0.85, 0.15, 0.15)
	elif hp_ratio > 0.25:
		_hp_fill.color = Color(0.9, 0.35, 0.1)
	else:
		_hp_fill.color = Color(1.0, 0.1, 0.05)

	if _hp_label:
		_hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]


# ----------------------------------------------------------
# ПОСТРОЕНИЕ UI ЧЕРЕЗ КОД
# ----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_hp_bar()
	_build_stamina_bar()
	_build_posture_bar()  # ← добавь


func _build_hp_bar() -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = hp_position
	container.size = hp_bar_size + Vector2(0, 30)
	_root.add_child(container)

	# Метка HP
	_hp_label = Label.new()
	_hp_label.position = Vector2(0, 0)
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.75))
	_hp_label.text = "HP"
	container.add_child(_hp_label)

	var bar_y: float = 18.0

	# Фон полоски
	_hp_bg = ColorRect.new()
	_hp_bg.position = Vector2(0, bar_y)
	_hp_bg.size = hp_bar_size
	_hp_bg.color = Color(0.08, 0.08, 0.08, 0.9)
	container.add_child(_hp_bg)

	# Белая полоска отставания
	_hp_delayed = ColorRect.new()
	_hp_delayed.position = Vector2(0, bar_y)
	_hp_delayed.size = hp_bar_size
	_hp_delayed.color = Color(0.85, 0.85, 0.85, 0.75)
	container.add_child(_hp_delayed)

	# Красная полоска текущего HP
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(0, bar_y)
	_hp_fill.size = hp_bar_size
	_hp_fill.color = Color(0.85, 0.15, 0.15)
	container.add_child(_hp_fill)

	# Рамка
	var border := _make_border(Vector2(0, bar_y), hp_bar_size)
	container.add_child(border)

func _build_stamina_bar() -> void:
	var container := Control.new()
	# левый нижний угол, НАД hp баром
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(stamina_offset_x, stamina_position_y)
	container.size = stamina_bar_size + Vector2(0, 20)
	_root.add_child(container)

	var lbl := Label.new()
	lbl.position = Vector2(0, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	lbl.text = "STAMINA"
	container.add_child(lbl)

	var bar_y: float = 16.0

	_stam_bg = ColorRect.new()
	_stam_bg.position = Vector2(0, bar_y)
	_stam_bg.size = stamina_bar_size
	_stam_bg.color = Color(0.08, 0.08, 0.08, 0.85)
	container.add_child(_stam_bg)

	_stam_fill = ColorRect.new()
	_stam_fill.position = Vector2(0, bar_y)
	_stam_fill.size = stamina_bar_size
	_stam_fill.color = Color(0.25, 0.75, 0.3)
	container.add_child(_stam_fill)

	var border := _make_border(Vector2(0, bar_y), stamina_bar_size)
	container.add_child(border)


func _make_border(pos: Vector2, bar_size: Vector2) -> Control:
	# Рисуем 4 тонкие линии вокруг полоски
	var c := Control.new()
	c.position = pos

	var thickness := 1.5
	var col := Color(0.5, 0.45, 0.3, 0.8)

	var top := ColorRect.new()
	top.position = Vector2(-thickness, -thickness)
	top.size = Vector2(bar_size.x + thickness * 2, thickness)
	top.color = col
	c.add_child(top)

	var bot := ColorRect.new()
	bot.position = Vector2(-thickness, bar_size.y)
	bot.size = Vector2(bar_size.x + thickness * 2, thickness)
	bot.color = col
	c.add_child(bot)

	var left := ColorRect.new()
	left.position = Vector2(-thickness, 0)
	left.size = Vector2(thickness, bar_size.y)
	left.color = col
	c.add_child(left)

	var right := ColorRect.new()
	right.position = Vector2(bar_size.x, 0)
	right.size = Vector2(thickness, bar_size.y)
	right.color = col
	c.add_child(right)

	return c

func _build_posture_bar() -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	container.position = Vector2(posture_offset_x, posture_position_y)
	container.size = posture_bar_size + Vector2(0, 20)
	_root.add_child(container)

	var lbl := Label.new()
	lbl.position = Vector2(0, 0)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	lbl.text = "POSTURE"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size.x = posture_bar_size.x
	container.add_child(lbl)

	var bar_y: float = 13.0

	# Фон
	_posture_bg = ColorRect.new()
	_posture_bg.position = Vector2(0, bar_y)
	_posture_bg.size = posture_bar_size
	_posture_bg.color = Color(0.08, 0.08, 0.08, 0.85)
	container.add_child(_posture_bg)

	# Левая половина — растёт влево от центра
	_posture_fill = ColorRect.new()
	_posture_fill.position = Vector2(posture_bar_size.x / 2.0, bar_y)
	_posture_fill.size = Vector2(0, posture_bar_size.y)
	_posture_fill.color = Color(0.9, 0.8, 0.2)
	container.add_child(_posture_fill)

	# Правая половина — растёт вправо от центра
	_posture_fill_right = ColorRect.new()
	_posture_fill_right.position = Vector2(posture_bar_size.x / 2.0, bar_y)
	_posture_fill_right.size = Vector2(0, posture_bar_size.y)
	_posture_fill_right.color = Color(0.9, 0.8, 0.2)
	container.add_child(_posture_fill_right)

	var border := _make_border(Vector2(0, bar_y), posture_bar_size)
	container.add_child(border)
