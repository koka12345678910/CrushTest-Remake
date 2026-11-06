# res://UI/skill_points_bar.gd
# Прикрепи к CanvasLayer ноде "SkillPointsBar", ребёнку персонажа
# (та же схема, что у health_stamina_bar.gd)
extends CanvasLayer
## Опыт навыков в правом верхнем углу: плашка с числом накопленных очков
## справа, слева от неё — тонкая полоска прогресса до следующего очка,
## над полоской подписи "НАВЫКИ" и "N / M". Вид — как у инвентаря
## (UI/clean_hud.gd).
##
## Число (skill_points) и полоска (skill_progress) — РАЗНЫЕ поля персонажа:
## полоска копит сырой прогресс убийств, а число растёт только когда полоска
## долилась целиком (см. add_skill_points в character_base.gd/player.gd —
## именно там происходит конвертация progress → point, этот файл её не делает,
## только опрашивает оба поля каждый кадр и рисует)

const Clean := preload("res://UI/clean_hud.gd")

## Заливка — приглушённое золото инвентаря
const FILL_COLOR := Color(0.78, 0.62, 0.36)

@export var bar_size := Vector2(350, 11)
## Отступ всего блока от правого верхнего угла экрана
@export var margin := Vector2(36.0, 28.0)
@export var badge_size := 60.0
## Часы суток под полоской: диаметр циферблата и зазор от блока навыков.
## Слева от часов — время суток и погода словом (Levels/weather.gd)
@export var clock_size := 92.0
@export var clock_gap := 16.0

var _label: Label
var _clock: Control
var _phase_label: Label
var _weather_label: Label
var _progress_label: Label
var _bar: Control
var _last_points := -1
var _last_progress := -1


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	_update_clock_labels()
	var owner_char := get_parent()
	if not is_instance_valid(owner_char):
		return
	if not ("skill_points" in owner_char) or not ("skill_progress" in owner_char):
		return

	var points: int = owner_char.skill_points
	if points != _last_points:
		_last_points = points
		_label.text = str(points)
		# Есть что потратить — число золотое, как выделенное в инвентаре
		_label.add_theme_color_override("font_color", Clean.GOLD_HI if points > 0 else Clean.TEXT_DIM)

	var progress: int = owner_char.skill_progress
	if progress != _last_progress:
		_last_progress = progress
		var per_point: int = owner_char.skill_progress_per_point if ("skill_progress_per_point" in owner_char) else 10
		_bar.ratio = clamp(float(progress) / float(per_point), 0.0, 1.0)
		_progress_label.text = "%d / %d" % [progress, per_point]


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Точка-якорь в правом верхнем углу — от неё отсчитывается весь блок
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	root.add_child(corner)

	var badge := Clean.Plate.new()
	badge.accent = true
	badge.position = Vector2(-margin.x - badge_size, margin.y)
	badge.size = Vector2(badge_size, badge_size)
	corner.add_child(badge)
	_label = Clean.label("0", 30, Clean.TEXT_DIM)
	_label.position = badge.position
	_label.size = badge.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner.add_child(_label)

	# Полоска — по низу плашки, подписи над ней
	var bar_x := badge.position.x - 18.0 - bar_size.x
	var bar_y := badge.position.y + badge_size - bar_size.y - 5.0
	_bar = Clean.Bar.new()
	_bar.position = Vector2(bar_x, bar_y)
	_bar.size = bar_size
	_bar.fill_color = FILL_COLOR
	_bar.ratio = 0.0
	corner.add_child(_bar)

	var title := Clean.label("НАВЫКИ", 18, Clean.TEXT_DIM)
	title.position = Vector2(bar_x, bar_y - 30.0)
	title.size = Vector2(bar_size.x * 0.5, 26.0)
	corner.add_child(title)
	_progress_label = Clean.label("0 / 10", 18, Clean.TEXT)
	_progress_label.position = Vector2(bar_x + bar_size.x * 0.5, bar_y - 30.0)
	_progress_label.size = Vector2(bar_size.x * 0.5, 26.0)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(_progress_label)

	# Часы суток — под плашкой с числом, правым краем по ней; подписи слева,
	# прижаты к циферблату
	var clock_y := badge.position.y + badge_size + clock_gap
	_clock = Clean.DayClock.new()
	_clock.position = Vector2(-margin.x - clock_size, clock_y)
	_clock.size = Vector2(clock_size, clock_size)
	corner.add_child(_clock)
	var text_x := _clock.position.x - 14.0 - 220.0
	_phase_label = Clean.label("", 18, Clean.TEXT)
	_phase_label.position = Vector2(text_x, clock_y + clock_size * 0.5 - 28.0)
	_phase_label.size = Vector2(220.0, 26.0)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(_phase_label)
	_weather_label = Clean.label("", 16, Clean.TEXT_DIM)
	_weather_label.position = Vector2(text_x, clock_y + clock_size * 0.5)
	_weather_label.size = Vector2(220.0, 24.0)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(_weather_label)


## Подписи у часов: "ВЕЧЕР" и "Дождь". Без смены суток (меню, старые
## уровни) часов нет вовсе
func _update_clock_labels() -> void:
	var on := Weather.is_active()
	_phase_label.visible = on
	_weather_label.visible = on
	if not on:
		return
	var phase := tr(Weather.phase_name()).to_upper()
	if _phase_label.text != phase:
		_phase_label.text = phase
	var w := tr(Weather.weather_name())
	if _weather_label.text != w:
		_weather_label.text = w
