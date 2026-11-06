# res://ui/health_stamina_bar.gd
# Прикрепи к CanvasLayer ноде "HealthStaminaBar"
# Структура сцены:
#   HealthStaminaBar (CanvasLayer)  ← этот скрипт
extends CanvasLayer
## Здоровье, стамина (левый верхний угол, справа от портрета) и концентрация
## (по центру внизу). Логика значений — здесь же, player.gd и
## character_base.gd только зовут take_damage/use_stamina/set_posture и т.п.
## Отрисовка — в ключе инвентаря (UI/clean_hud.gd): круглый портрет без
## светлой каймы, полоски-капсулы со скруглёнными концами и лёгким глянцем.

const TEX_ICON := preload("res://UI/healthbar/healthbar_icon.png")
const Clean := preload("res://UI/clean_hud.gd")

# Иконка портрета — переопределяется в сцене персонажа (см. archer.tscn),
# чтобы у каждого класса был свой портрет вместо общего рыцарского
@export var icon_texture: Texture2D = TEX_ICON

# --- HP ---
var max_hp: float = 100.0
var current_hp: float = 100.0
var delayed_hp: float = 100.0       # светлая полоска отставания
var delay_speed: float = 30.0       # скорость убывания светлой полоски
var delay_timer: float = 0.0        # пауза перед началом убывания
var delay_pause: float = 0.8        # секунд до начала убывания

# --- Стамина ---
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_regen: float = 20.0     # регенерация в секунду
var stamina_regen_delay: float = 1.0
var stamina_regen_timer: float = 0.0

# --- Портрет: круглый медальон, тёмный, без светлой каймы ---
@export var icon_position: Vector2 = Vector2(32, 28)
@export var icon_size: float = 108.0
@export var icon_darken: float = 0.9

# Полоски выходят из портрета вправо: здоровье, (Одр/Сейд), выносливость —
# стопкой через bar_gap, по центру портрета. Ширина — от середины медальона
@export var hp_bar_size: Vector2 = Vector2(354, 16)
@export var stamina_bar_size: Vector2 = Vector2(304, 12)
## Зазор между полосками: концы скруглены, вплотную капсулы слипаются
@export var bar_gap: float = 2.0

@export var posture_fill_speed: float = 8.0   # скорость заполнения
@export var posture_drain_speed: float = 40.0  # скорость опустошения (быстрее)
@export var posture_bar_size: Vector2 = Vector2(560, 11)
# Отрицательный — отступ центра полоски от НИЖНЕГО края экрана
@export var posture_position_y: float = -96.0

# Цвета тусклые и глубокие, как у полосок Dark Souls 3: тёмно-алое здоровье,
# тёмно-голубая магия, тёмно-зелёная выносливость.
# Здоровье: чем меньше осталось, тем ярче алый
const HP_COLOR_HIGH := Color(0.34, 0.05, 0.06)
const HP_COLOR_MID := Color(0.4, 0.05, 0.06)
const HP_COLOR_LOW := Color(0.48, 0.06, 0.07)
const STAMINA_COLOR := Color(0.13, 0.27, 0.14)
# Концентрация: золото инвентаря → охра → кирпичный по мере приближения к срыву
const POSTURE_COLOR_LOW := Color(0.78, 0.62, 0.36)
const POSTURE_COLOR_MID := Color(0.78, 0.47, 0.26)
const POSTURE_COLOR_HIGH := Color(0.72, 0.22, 0.16)

# --- Концентрация (Posture) ---
var max_posture: float = 100.0
var current_posture: float = 0.0

var _root: Control
var _medal: Control
var _hp_bar: Control
var _stam_bar: Control
var _posture_bar: Control
var _bar_x := 0.0

# ── Одр (связь с богами, магия рыцаря — Player_scene/magic/knight_magic.gd) ──
# Полоска магии: Одр у рыцаря, Сейд у мага (Player_scene/mage.gd) — тот же
# вид, свои цвета. Включает enable_odr(), между здоровьем и выносливостью
const ODR_COLOR := Color(0.1, 0.24, 0.38)
const ODR_LACK_COLOR := Color(0.4, 0.66, 0.92)
@export var odr_bar_size := Vector2(324, 12)
var max_odr := 100.0
var current_odr := 100.0
var _odr_bar: Control
var _odr_blink: Tween
var _odr_color := ODR_COLOR
var _odr_lack_color := ODR_LACK_COLOR


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


## Включить полоску магии: Одр рыцаря (цвета по умолчанию) или Сейд мага (свои
## цвета). Встаёт между здоровьем и выносливостью, выносливость сдвигается ниже
func enable_odr(color := ODR_COLOR, lack_color := ODR_LACK_COLOR) -> void:
	if is_instance_valid(_odr_bar) or not is_instance_valid(_root):
		return
	_odr_color = color
	_odr_lack_color = lack_color
	_odr_bar = _make_bar(Vector2(_bar_x, 0.0), odr_bar_size, color)
	_root.add_child(_odr_bar)
	_layout_bars()


func set_odr(value: float, max_value: float) -> void:
	max_odr = max_value
	current_odr = clampf(value, 0.0, max_value)


## Не хватает Одра на заклинание — полоска дважды вспыхивает светлее, чтобы
## было видно, почему ничего не произошло
func blink_odr() -> void:
	if not is_instance_valid(_odr_bar):
		return
	if _odr_blink:
		_odr_blink.kill()
	var bright := Color(
		_odr_lack_color.r / maxf(_odr_color.r, 0.01),
		_odr_lack_color.g / maxf(_odr_color.g, 0.01),
		_odr_lack_color.b / maxf(_odr_color.b, 0.01))
	_odr_blink = create_tween()
	_odr_blink.tween_property(_odr_bar, "fill_mod", bright, 0.06)
	_odr_blink.tween_property(_odr_bar, "fill_mod", Color.WHITE, 0.1)
	_odr_blink.tween_property(_odr_bar, "fill_mod", bright, 0.06)
	_odr_blink.tween_property(_odr_bar, "fill_mod", Color.WHITE, 0.22)
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
# в clean_hud.gd::Bar), так что дёргать их каждый кадр дёшево
func _update_visuals() -> void:
	if not is_instance_valid(_hp_bar):
		return

	var hp_ratio := current_hp / max_hp if max_hp > 0.0 else 0.0
	_hp_bar.ratio = hp_ratio
	_hp_bar.delayed_ratio = delayed_hp / max_hp if max_hp > 0.0 else 0.0
	var hp_col := HP_COLOR_HIGH
	if hp_ratio <= 0.25:
		hp_col = HP_COLOR_LOW
	elif hp_ratio <= 0.5:
		hp_col = HP_COLOR_MID
	_hp_bar.fill_color = hp_col

	_stam_bar.ratio = current_stamina / max_stamina if max_stamina > 0.0 else 0.0
	if is_instance_valid(_odr_bar):
		_odr_bar.ratio = current_odr / max_odr if max_odr > 0.0 else 0.0

	var p_ratio := current_posture / max_posture if max_posture > 0.0 else 0.0
	_posture_bar.ratio = p_ratio
	var p_col := POSTURE_COLOR_LOW
	if p_ratio >= 0.8:
		p_col = POSTURE_COLOR_HIGH
	elif p_ratio >= 0.5:
		p_col = POSTURE_COLOR_MID
	_posture_bar.fill_color = p_col


# ----------------------------------------------------------
# ПОСТРОЕНИЕ UI ЧЕРЕЗ КОД
# ----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_icon()

	# Полоски выходят из медальона: начинаются под ним, от его середины
	# (медальон рисуется поверх), видимая часть — от края кольца. Здоровье
	# толще, остальные чуть тоньше
	_bar_x = icon_position.x + icon_size * 0.5
	_hp_bar = _make_bar(Vector2(_bar_x, 0.0), hp_bar_size, HP_COLOR_HIGH)
	_root.add_child(_hp_bar)
	_stam_bar = _make_bar(Vector2(_bar_x, 0.0), stamina_bar_size, STAMINA_COLOR)
	_root.add_child(_stam_bar)
	_layout_bars()

	_build_posture_bar()


## Стопка полосок (здоровье, Одр/Сейд, выносливость) через bar_gap, по
## вертикали — по центру портрета.
## Медальон — поверх полосок, в т.ч. добавленной позже полоски магии
func _layout_bars() -> void:
	_root.move_child(_medal, -1)
	var bars: Array[Control] = [_hp_bar]
	if is_instance_valid(_odr_bar):
		bars.append(_odr_bar)
	bars.append(_stam_bar)
	var total := bar_gap * (bars.size() - 1)
	for b in bars:
		total += b.size.y
	var y := roundf(icon_position.y + (icon_size - total) * 0.5)
	for b in bars:
		b.inset = 1.0
		b.position = Vector2(_bar_x, y)
		y += b.size.y + bar_gap


## Портрет: круглый медальон (Clean.Medallion) — тёмный круг с мягкой тёмной кромкой,
## в нём лицо под круглой маской. Своя нарисованная рамка картинки срезается
func _build_icon() -> void:
	var medal := Clean.Medallion.new()
	_medal = medal
	medal.position = icon_position
	medal.size = Vector2(icon_size, icon_size)
	_root.add_child(medal)

	# Лицо почти во весь медальон — вокруг лишь узкая тёмная кромка
	var inner := icon_size - 6.0
	medal.inner_radius = inner * 0.5
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Светлая нарисованная рамка картинки начинается на радиусе ~0.345
	# стороны (UI/healthbar/*_icon.png, 128 px) — маска режет внутри неё,
	# по 0.325, а картинка растянута так, чтобы этот круг = inner
	icon.size = Vector2(inner, inner) / 0.65
	icon.position = ((medal.size - icon.size) * 0.5).round()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(icon_darken, icon_darken, icon_darken)
	icon.material = Clean.mask_material(0.325)
	medal.set_portrait(icon)


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
		(Vector2(-posture_bar_size.x / 2.0, posture_position_y - posture_bar_size.y / 2.0)).round(),
		posture_bar_size, POSTURE_COLOR_LOW)
	_posture_bar.centered = true
	_posture_bar.ratio = 0.0
	anchor.add_child(_posture_bar)


func _make_bar(pos: Vector2, sz: Vector2, col: Color) -> Control:
	var bar := Clean.Bar.new()
	bar.position = pos
	bar.size = sz
	bar.fill_color = col
	return bar
