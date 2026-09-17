# res://UI/skill_points_bar.gd
# Прикрепи к CanvasLayer ноде "SkillPointsBar", ребёнку персонажа
# (та же схема, что у health_stamina_bar.gd)
extends CanvasLayer
## Полоска очков навыков в правом верхнем углу, "как в Секиро": число слева,
## полоска справа от него, той же породы, что HP-бар (пустая — чёрная,
## заполняется синим).
##
## Число (skill_points) и полоска (skill_progress) — РАЗНЫЕ поля персонажа:
## полоска копит сырой прогресс убийств, а число растёт только когда полоска
## долилась целиком (см. add_skill_points в character_base.gd/player.gd —
## именно там происходит конвертация progress → point, этот файл её не делает,
## только опрашивает оба поля каждый кадр и рисует — тот же приём, что и у
## health_stamina_bar с его _update_visuals()

@export var bar_size := Vector2(400, 20)
## Ширина под число слева от полоски, и зазор между числом и полоской
@export var label_width := 46.0
@export var label_gap := 10.0
## Отступ всего блока от правого верхнего угла экрана
@export var margin := Vector2(20.0, 16.0)

var _label: Label
var _bar_fill: ColorRect
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
		var ratio: float = clamp(float(progress) / float(per_point), 0.0, 1.0)
		_bar_fill.size.x = bar_size.x * ratio


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var total_width := label_width + label_gap + bar_size.x

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.position = Vector2(-margin.x - total_width, margin.y)
	container.size = Vector2(total_width, bar_size.y)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)

	# Число — слева от полоски (не над ней), прижато к её левому краю
	_label = Label.new()
	_label.text = "0"
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, 0)
	_label.size = Vector2(label_width, bar_size.y)
	container.add_child(_label)

	var bar_x := label_width + label_gap

	# Фон — почти чёрный. Полностью пустая полоска (progress=0) показывает
	# ровно его, заливки поверх ещё нет
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(bar_x, 0)
	bar_bg.size = bar_size
	bar_bg.color = Color(0.02, 0.02, 0.03, 0.95)
	container.add_child(bar_bg)

	# Заливка — растёт от 0 до bar_size.x по мере накопления skill_progress
	# (см. _process), обнуляется вместе с ним каждый раз, как долилась целиком
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(bar_x, 0)
	_bar_fill.size = Vector2(0, bar_size.y)
	_bar_fill.color = Color(0.25, 0.5, 1.0)
	container.add_child(_bar_fill)

	var border := _make_bevel_border(Vector2(bar_x, 0), bar_size)
	container.add_child(border)


## Рамка со скосом — та же идея, что у health_stamina_bar.gd::_make_bevel_border
## (светлый верх/тёмный низ — читается как объём, а не плоская линия).
## Продублирована, а не вынесена в общий файл — этот скрипт не пересекается
## ни с чем чужим, тот же приём, что у arrow.gd/focus_marker.gd
func _make_bevel_border(pos: Vector2, size: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var thickness := 1.5
	var top_col := Color(0.5, 0.65, 0.95, 0.9)
	var side_col := Color(0.2, 0.28, 0.42, 0.85)
	var bottom_col := Color(0.02, 0.02, 0.03, 0.95)

	var top := ColorRect.new()
	top.position = Vector2(-thickness, -thickness)
	top.size = Vector2(size.x + thickness * 2, thickness)
	top.color = top_col
	c.add_child(top)

	var bot := ColorRect.new()
	bot.position = Vector2(-thickness, size.y)
	bot.size = Vector2(size.x + thickness * 2, thickness)
	bot.color = bottom_col
	c.add_child(bot)

	var left := ColorRect.new()
	left.position = Vector2(-thickness, 0)
	left.size = Vector2(thickness, size.y)
	left.color = side_col
	c.add_child(left)

	var right := ColorRect.new()
	right.position = Vector2(size.x, 0)
	right.size = Vector2(thickness, size.y)
	right.color = side_col
	c.add_child(right)

	return c
