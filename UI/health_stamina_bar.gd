# res://ui/health_stamina_bar.gd
# Прикрепи к CanvasLayer ноде "HealthStaminaBar"
# Структура сцены:
#   HealthStaminaBar (CanvasLayer)  ← этот скрипт
extends CanvasLayer
## Здоровье, стамина (левый верхний угол, выходят из медальона-портрета) и
## концентрация (по центру внизу). Логика значений — здесь же, player.gd и
## character_base.gd только зовут take_damage/use_stamina/set_posture и т.п.
## Отрисовка — через UI/HudBar.gd: заострённые полоски с золотой каймой.

const TEX_ICON := preload("res://UI/healthbar/healthbar_icon.png")
const HudBarScript := preload("res://UI/HudBar.gd")

# Иконка портрета — переопределяется в сцене персонажа (см. archer.tscn),
# чтобы у каждого класса был свой медальон вместо общего рыцарского
@export var icon_texture: Texture2D = TEX_ICON

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

# --- Медальон-портрет слева от баров (круглый PNG с прозрачными углами) ---
# Бары начинаются ПОД ним, примерно от центра — эффект "полоски выходят из
# медальона". Медальон рисуется поверх баров (см. порядок в _build_ui)
@export var icon_position: Vector2 = Vector2(16, 14)
@export var icon_size: Vector2 = Vector2(128, 128)
@export var icon_darken: float = 0.92
# Прозрачность полосок целиком (фон, заливка, кайма)
@export var bar_alpha: float = 0.96

@export var hp_bar_size: Vector2 = Vector2(350, 17)
@export var stamina_bar_size: Vector2 = Vector2(300, 15)
@export var hp_position: Vector2 = Vector2(82, 50)
@export var stamina_offset_x: float = 82.0
@export var stamina_position_y: float = 77.0

@export var posture_fill_speed: float = 8.0   # скорость заполнения
@export var posture_drain_speed: float = 40.0  # скорость опустошения (быстрее)
@export var posture_bar_size: Vector2 = Vector2(440, 16)
# Отрицательный — отступ центра полоски от НИЖНЕГО края экрана
@export var posture_position_y: float = -84.0

# Цвета здоровья: чем меньше осталось, тем ярче и тревожнее красный
const HP_COLOR_HIGH := Color(0.6, 0.06, 0.05)
const HP_COLOR_MID := Color(0.7, 0.1, 0.04)
const HP_COLOR_LOW := Color(0.82, 0.09, 0.03)
const STAMINA_COLOR := Color(0.36, 0.6, 0.22)
# Концентрация: золото → оранжевый → красный по мере приближения к срыву
const POSTURE_COLOR_LOW := Color(0.86, 0.62, 0.24)
const POSTURE_COLOR_MID := Color(0.93, 0.45, 0.12)
const POSTURE_COLOR_HIGH := Color(0.95, 0.16, 0.08)

# --- Концентрация (Posture) ---
var max_posture: float = 100.0
var current_posture: float = 0.0

var _root: Control
var _hp_bar: Control
var _stam_bar: Control
var _posture_bar: Control


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


# Полоски сами перерисовываются только при реальной смене значения (сеттеры
# в HudBar.gd), так что дёргать их каждый кадр дёшево
func _update_visuals() -> void:
	if not is_instance_valid(_hp_bar):
		return

	var hp_ratio := current_hp / max_hp if max_hp > 0.0 else 0.0
	_hp_bar.set("ratio", hp_ratio)
	_hp_bar.set("delayed_ratio", delayed_hp / max_hp if max_hp > 0.0 else 0.0)
	var hp_col := HP_COLOR_HIGH
	if hp_ratio <= 0.25:
		hp_col = HP_COLOR_LOW
	elif hp_ratio <= 0.5:
		hp_col = HP_COLOR_MID
	_hp_bar.set("fill_color", hp_col)

	_stam_bar.set("ratio", current_stamina / max_stamina if max_stamina > 0.0 else 0.0)

	var p_ratio := current_posture / max_posture if max_posture > 0.0 else 0.0
	_posture_bar.set("ratio", p_ratio)
	var p_col := POSTURE_COLOR_LOW
	if p_ratio >= 0.8:
		p_col = POSTURE_COLOR_HIGH
	elif p_ratio >= 0.5:
		p_col = POSTURE_COLOR_MID
	_posture_bar.set("fill_color", p_col)


# ----------------------------------------------------------
# ПОСТРОЕНИЕ UI ЧЕРЕЗ КОД
# ----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Бары СНАЧАЛА, медальон ПОСЛЕДНИМ — сиблинги рисуются в порядке
	# добавления, медальон должен лечь поверх начала полосок
	_hp_bar = _make_bar(hp_position, hp_bar_size, HP_COLOR_HIGH)
	_hp_bar.modulate.a = bar_alpha
	_root.add_child(_hp_bar)

	_stam_bar = _make_bar(Vector2(stamina_offset_x, stamina_position_y), stamina_bar_size, STAMINA_COLOR)
	_stam_bar.modulate.a = bar_alpha
	_root.add_child(_stam_bar)

	_build_icon()
	_build_posture_bar()


func _build_icon() -> void:
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = icon_position
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(icon_darken, icon_darken, icon_darken)
	# Медальон тоже потёртый, в тон полоскам (UI/hud_worn.gdshader)
	icon.material = HudBarScript.WORN_MATERIAL
	_root.add_child(icon)


func _build_posture_bar() -> void:
	# Контейнер на якоре "низ-центр": полоска остаётся по центру при любом
	# разрешении окна
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.anchor_left = 0.5
	anchor.anchor_right = 0.5
	anchor.anchor_top = 1.0
	anchor.anchor_bottom = 1.0
	_root.add_child(anchor)

	_posture_bar = _make_bar(
		Vector2(-posture_bar_size.x / 2.0, posture_position_y - posture_bar_size.y / 2.0),
		posture_bar_size, POSTURE_COLOR_LOW)
	_posture_bar.set("tip_left", true)
	_posture_bar.set("centered", true)
	_posture_bar.set("center_emblem", true)
	_posture_bar.set("ratio", 0.0)
	anchor.add_child(_posture_bar)


func _make_bar(pos: Vector2, sz: Vector2, col: Color) -> Control:
	var bar := Control.new()
	bar.set_script(HudBarScript)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = pos
	bar.size = sz
	bar.set("fill_color", col)
	return bar
