# res://UI/skill_points_bar.gd
# Прикрепи к CanvasLayer ноде "SkillPointsBar", ребёнку персонажа
# (та же схема, что у health_stamina_bar.gd)
extends CanvasLayer
## Опыт навыков в правом верхнем углу: ромб с числом накопленных очков слева,
## полоска прогресса до следующего очка и подпись "N / M" внутри неё.
##
## Число (skill_points) и полоска (skill_progress) — РАЗНЫЕ поля персонажа:
## полоска копит сырой прогресс убийств, а число растёт только когда полоска
## долилась целиком (см. add_skill_points в character_base.gd/player.gd —
## именно там происходит конвертация progress → point, этот файл её не делает,
## только опрашивает оба поля каждый кадр и рисует)

const HudBarScript := preload("res://UI/HudBar.gd")
const DiamondMarkerScript := preload("res://Main_Menu/scripts/DiamondMarker.gd")

const FILL_COLOR := Color(0.78, 0.56, 0.22)
const TEXT_COLOR := Color(0.9, 0.84, 0.72)

@export var bar_size := Vector2(420, 22)
## Отступ всего блока от правого верхнего угла экрана
@export var margin := Vector2(34.0, 26.0)
@export var badge_size := 46.0

var _label: Label
var _progress_label: Label
var _bar: Control
var _last_points := -1
var _last_progress := -1


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	var owner_char := get_parent()
	if not is_instance_valid(owner_char):
		return
	if not ("skill_points" in owner_char) or not ("skill_progress" in owner_char):
		return

	var points: int = owner_char.skill_points
	if points != _last_points:
		_last_points = points
		_label.text = str(points)

	var progress: int = owner_char.skill_progress
	if progress != _last_progress:
		_last_progress = progress
		var per_point: int = owner_char.skill_progress_per_point if ("skill_progress_per_point" in owner_char) else 10
		_bar.set("ratio", clamp(float(progress) / float(per_point), 0.0, 1.0))
		_progress_label.text = "%d / %d" % [progress, per_point]


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Шрифт с засечками и нормальными цифрами — тот же, что у инвентаря
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	var t := Theme.new()
	t.default_font = serif
	root.theme = t
	add_child(root)

	# Точка-якорь в правом верхнем углу — от неё отсчитывается весь блок
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	root.add_child(corner)

	var bar_x := -margin.x - bar_size.x
	var cy := margin.y + badge_size / 2.0

	_bar = Control.new()
	_bar.set_script(HudBarScript)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.position = Vector2(bar_x, cy - bar_size.y / 2.0)
	_bar.size = bar_size
	_bar.set("fill_color", FILL_COLOR)
	_bar.set("ratio", 0.0)
	corner.add_child(_bar)

	_progress_label = _make_label("0 / 10", 17)
	_progress_label.position = Vector2(bar_x, cy - bar_size.y / 2.0 - 1.0)
	_progress_label.size = Vector2(bar_size.x - bar_size.y - 8.0, bar_size.y)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner.add_child(_progress_label)

	# Ромб-значок с числом очков — поверх левого края полоски
	var badge := Control.new()
	badge.set_script(DiamondMarkerScript)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(bar_x - badge_size * 0.55, cy - badge_size / 2.0)
	badge.size = Vector2(badge_size, badge_size)
	badge.set("outline_color", Color(0.72, 0.57, 0.33))
	badge.set("outline_width", 2.0)
	# Тёмное тело ромба — иначе число ложится прямо на мир
	badge.set("body_color", Color(0.04, 0.035, 0.03, 0.95))
	badge.set("fill_color", Color(0.0, 0.0, 0.0, 0.0))
	badge.material = HudBarScript.WORN_MATERIAL
	corner.add_child(badge)

	# Вторая, бледная кайма внутри — "кованый" значок, как на референсе
	var inner := Control.new()
	inner.set_script(DiamondMarkerScript)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = badge.position + Vector2(5.0, 5.0)
	inner.size = Vector2(badge_size - 10.0, badge_size - 10.0)
	inner.set("outline_color", Color(0.72, 0.57, 0.33, 0.4))
	inner.set("fill_color", Color(0.0, 0.0, 0.0, 0.0))
	inner.material = HudBarScript.WORN_MATERIAL
	corner.add_child(inner)

	_label = _make_label("0", 21)
	_label.position = badge.position
	_label.size = badge.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner.add_child(_label)


func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l
