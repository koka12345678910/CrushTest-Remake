# res://ui/quick_slot_ui.gd
extends Control
## Быстрый слот HUD (правый нижний угол) в ключе инвентаря (UI/clean_hud.gd):
## тёмная квадратная клетка с иконкой предмета, клавиша в левом верхнем углу,
## заряды — в правом нижнем, под клеткой "N / M". Кулдаун — затемнение,
## которое сходит сверху вниз; предмет снова готов — короткая вспышка.

const Clean := preload("res://UI/clean_hud.gd")

# Цвет счётчика зарядов: обычный — светлый текст, на последнем заряде —
# приглушённый красный, чтобы предмет не кончился внезапно
const CHARGES_COLOR := Clean.TEXT
const CHARGES_LOW_COLOR := Color(0.78, 0.38, 0.26)

# Показывается вместо иконки, когда быстрый слот пуст
const EMPTY_SLOT_ICON := preload("res://Shop/icons/empty_slot_256x256.png")

## Сторона клетки и место под подпись "N / M" под ней
const CELL := 124.0
const CAPTION_H := 32.0

## Общий масштаб слота. Растёт от нижнего угла, к которому прижат слот,
## чтобы не уезжать за край экрана
@export var hud_scale := 1.0
## Слот магии рыцаря (левый нижний угол, Player_scene/magic/knight_magic.gd):
## вместо зарядов — стоимость в Одре, прижат к левому нижнему углу.
## Выставляется ДО init()
var magic_mode := false
const ODR_TEXT_COLOR := Color(0.6, 0.7, 0.95)

var _ability_system
var _icon: TextureRect
var _flash: ColorRect
var _cooldown_veil: Control
var _charges_label: Label
var _index_label: Label
var _key_label: Label
var _cooldown := 1.0
var _empty := false


func init(system) -> void:
	_ability_system = system
	system.slot_changed.connect(_on_slot_changed)
	system.cooldown_updated.connect(_on_cooldown_updated)
	system.cooldowns_reset.connect(_on_cooldowns_reset)
	system.ability_depleted.connect(_on_ability_depleted)
	# Заряды живут в сумке, а не в способности — цифру "осталось" обновляет она
	if system.inventory:
		system.inventory.count_changed.connect(func(_n: String, _c: int): _refresh())
	_build_slot()
	var box := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	pivot_offset = Vector2(0.0, box.y) if magic_mode else box
	scale = Vector2(hud_scale, hud_scale)
	_refresh()


## Хватает ли Одра на заклинание в слоте — не хватает, иконка тускнеет
func set_affordable(ok: bool) -> void:
	if _icon and not _empty:
		_icon.modulate = Color.WHITE if ok else Color(0.4, 0.4, 0.44)


func _build_slot() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# size контрола на момент init() может быть ещё не выставлен (layout не
	# прошёл) — берём размер из offset'ов
	var w := maxf(size.x, offset_right - offset_left)
	var h := maxf(size.y, offset_bottom - offset_top)
	# Клетка прижата к своему нижнему углу: предметы — к правому, магия — к левому
	var pos := Vector2(0.0 if magic_mode else w - CELL, h - CELL - CAPTION_H).round()

	var cell := Clean.Plate.new()
	cell.position = pos
	cell.size = Vector2(CELL, CELL)
	add_child(cell)

	var inset := 10.0
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.material = Clean.icon_material()
	# Режим растяжения — ДО текстуры и размера (иначе размер берётся по картинке)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = pos + Vector2(inset, inset)
	_icon.size = Vector2(CELL - inset * 2.0, CELL - inset * 2.0)
	add_child(_icon)

	# Кулдаун: затемнение поверх иконки, сходит сверху вниз по мере готовности
	_cooldown_veil = Control.new()
	_cooldown_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_veil.position = pos + Vector2(2, 2)
	_cooldown_veil.size = Vector2(CELL - 4.0, CELL - 4.0)
	_cooldown_veil.draw.connect(_draw_cooldown)
	add_child(_cooldown_veil)

	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.position = pos + Vector2(2, 2)
	_flash.size = Vector2(CELL - 4.0, CELL - 4.0)
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)

	# Клавиша — в левом верхнем углу клетки
	_key_label = Clean.label(_key_text("magic_use" if magic_mode else "ability_use"), 17, Clean.TEXT_DIM)
	_key_label.position = pos + Vector2(8, 3)
	_key_label.size = Vector2(50, 22)
	add_child(_key_label)

	# Заряды (или цена в Одре) — в правом нижнем
	_charges_label = Clean.label("", 21, CHARGES_COLOR)
	_charges_label.position = pos + Vector2(CELL - 78.0, CELL - 30.0)
	_charges_label.size = Vector2(70, 28)
	_charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_charges_label)

	_index_label = Clean.label("", 18, Clean.TEXT_DIM)
	_index_label.position = pos + Vector2(0, CELL + 6.0)
	_index_label.size = Vector2(CELL, 24)
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_index_label)


## Первая клавиша действия, как её подписывает клавиатура ("R", "Q")
func _key_text(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			return OS.get_keycode_string(code)
	return ""


func _draw_cooldown() -> void:
	if _cooldown >= 1.0 or _empty:
		return
	var s := _cooldown_veil.size
	var h := roundf(s.y * (1.0 - _cooldown))
	_cooldown_veil.draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 0.62))
	# Граница затемнения — тонкая светлая черта
	_cooldown_veil.draw_line(Vector2(0, h), Vector2(s.x, h), Color(Clean.TEXT, 0.35), 1.0)


# peak_color задаётся отдельным параметром — чтобы отличать смену слота
# (нейтральный белый) от сброса кулдаунов (тёплое золото)
func _play_flash(peak_color := Color(1, 1, 1, 0.45), duration := 0.2) -> void:
	_flash.color = peak_color
	var tween = create_tween()
	tween.tween_property(_flash, "color", Color(peak_color.r, peak_color.g, peak_color.b, 0.0), duration)


func _set_cooldown(progress: float) -> void:
	progress = clampf(progress, 0.0, 1.0)
	if not is_equal_approx(progress, _cooldown):
		# Предмет снова готов — короткая вспышка: заметность держит движение,
		# а не цвет
		if progress >= 1.0 and _cooldown < 1.0 and not _empty:
			_play_flash(Color(1, 1, 1, 0.25), 0.3)
		_cooldown = progress
		_cooldown_veil.queue_redraw()


func _refresh() -> void:
	if _ability_system == null:
		return
	var ability = _ability_system.get_current_ability()
	var total = _ability_system.abilities.size()
	var idx = _ability_system.current_index
	_empty = ability == null
	_icon.modulate = Color.WHITE

	if ability and magic_mode:
		_icon.texture = ability.icon
		_set_cooldown(ability.get_cooldown_progress())
		_charges_label.text = "%d" % int(ability.get("odr_cost"))
		_charges_label.add_theme_color_override("font_color", ODR_TEXT_COLOR)
	elif ability:
		_icon.texture = ability.icon
		_set_cooldown(ability.get_cooldown_progress())
		var charges = _ability_system.get_charges(ability)
		_charges_label.text = "x%d" % charges
		_charges_label.add_theme_color_override(
			"font_color", CHARGES_LOW_COLOR if charges <= 1 else CHARGES_COLOR)
	else:
		# Пустая клетка — едва различимая заглушка, без затемнения кулдауна
		_icon.texture = EMPTY_SLOT_ICON
		_icon.modulate = Color(1, 1, 1, 0.25)
		_cooldown = 1.0
		_cooldown_veil.queue_redraw()
		_charges_label.text = ""

	# Пустой быстрый доступ — не "1 / 0", а честный ноль
	_index_label.text = "%d / %d" % [idx + 1, total] if total > 0 else "0 / %d" % _ability_system.MAX_SLOTS


func _on_slot_changed(_index: int, _ability) -> void:
	_play_flash()
	_refresh()


# Предмет израсходован до конца и вылетел из слота. Красная вспышка отличает
# это от обычной смены слота (белая) и сброса кулдаунов (золотая)
func _on_ability_depleted(_ability) -> void:
	_play_flash(Color(0.95, 0.3, 0.2, 0.6), 0.3)


func _on_cooldown_updated(index: int, progress: float) -> void:
	if _ability_system and index == _ability_system.current_index:
		_set_cooldown(progress)


# Массовый сброс кулдаунов (Руна Жертвы и подобное) — тёплая золотая вспышка
func _on_cooldowns_reset() -> void:
	_play_flash(Color(Clean.GOLD_HI, 0.6), 0.35)
	if _ability_system:
		var ability = _ability_system.get_current_ability()
		if ability:
			_set_cooldown(ability.get_cooldown_progress())
