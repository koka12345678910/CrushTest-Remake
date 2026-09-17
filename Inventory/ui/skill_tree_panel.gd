# res://Inventory/ui/skill_tree_panel.gd
extends Control
## Экран одного дерева навыков — строится целиком из данных SkillTrees.gd
## (см. get_nodes/get_node_data), ничего про конкретные узлы не хардкодит.
## Не завязан на конкретного персонажа — принимает любой Node с методами
## can_unlock_skill/try_unlock_skill и полями skill_points/unlocked_skills
## (сейчас это только player.gd, но контракт тот же, что и у SaveManager:
## has-проверки, а не жёсткая типизация).
##
## Вызывающий (Inventory/systems/inventory/inventory_ui.gd) отвечает за
## показ/скрытие всего экрана целиком; этот скрипт просто строит содержимое
## по init() и полностью перестраивает его после каждой покупки — узлов мало
## (10), пересобрать всё с нуля дешевле и надёжнее, чем патчить состояние точечно.

const COLOR_PANEL     := Color(0.08, 0.06, 0.04, 1.0)
const COLOR_BORDER    := Color(0.45, 0.35, 0.15, 1.0)
const COLOR_BORDER_HI := Color(0.80, 0.62, 0.22, 1.0)
const COLOR_TEXT      := Color(0.92, 0.84, 0.66, 1.0)
const COLOR_TEXT_DIM  := Color(0.52, 0.47, 0.36, 1.0)
const COLOR_TEXT_GOLD := Color(0.98, 0.78, 0.28, 1.0)
const COLOR_WARN      := Color(0.85, 0.30, 0.25, 1.0)

const NODE_SIZE := Vector2(104, 104)
const CAPSTONE_SIZE := Vector2(154, 154)
const ROW_HEIGHT := 176.0
const COL_WIDTH := 204.0
const TOP_MARGIN := 70.0

const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")

var tree_id: String = ""
var _player: Node = null

var _header_label: Label
var _scroll: ScrollContainer
var _tree_area: Control
var _connections_layer: Control
var _tooltip: PanelContainer
var _tooltip_label: Label
var _node_buttons: Dictionary = {}  # node_id -> Button
# {from: Vector2, to: Vector2, lit: bool} — читает их _draw_connections(),
# подключённый к сигналу draw() отдельного слоя-Control под узлами
var _connection_segments: Array[Dictionary] = []


func init(p_tree_id: String, player: Node) -> void:
	tree_id = p_tree_id
	_player = player
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _play_ui_sound(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ─────────────────────────────────────────────
# ПОСТРОЕНИЕ
# ─────────────────────────────────────────────

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_node_buttons.clear()

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	_header_label.position = Vector2(0, 0)
	_header_label.size = Vector2(size.x, 28)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_header_label)
	_update_header()

	var nodes: Array = SkillTrees.get_nodes(tree_id)
	var max_row := 0
	var max_col := 0.0
	for n in nodes:
		max_row = max(max_row, int(n["row"]))
		max_col = max(max_col, float(n["col"]))

	var content_w: float = (max_col + 1.0) * COL_WIDTH
	var content_h: float = TOP_MARGIN + (max_row + 1) * ROW_HEIGHT + 40.0

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 36)
	_scroll.size = Vector2(size.x, size.y - 36.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_tree_area = Control.new()
	_tree_area.custom_minimum_size = Vector2(size.x, content_h)
	_tree_area.size = Vector2(size.x, content_h)
	_scroll.add_child(_tree_area)

	# Слой связей — ОТДЕЛЬНЫЙ Control с ручной отрисовкой (draw_line в
	# обработчике сигнала draw), а не Line2D: Line2D как ребёнок Control
	# в связке со ScrollContainer у нас просто не отрисовывался. draw_line
	# работает в той же системе координат, что и position узлов-кнопок —
	# никакой мешанины Node2D/Control
	_connections_layer = Control.new()
	_connections_layer.position = Vector2.ZERO
	_connections_layer.size = Vector2(size.x, content_h)
	_connections_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connections_layer.draw.connect(_draw_connections)
	_tree_area.add_child(_connections_layer)

	var origin_x: float = size.x / 2.0 - content_w / 2.0

	# Примерные связи по prerequisites — просто линия от узла к каждому его
	# требованию. Не окончательная схема, перерисуем точнее отдельной задачей
	_connection_segments.clear()
	for n in nodes:
		for req_id in n.get("prerequisites", []):
			var req: Dictionary = SkillTrees.get_node_data(tree_id, req_id)
			if req.is_empty():
				continue
			_connection_segments.append({
				"from": Vector2(origin_x + (float(req["col"]) + 0.5) * COL_WIDTH, TOP_MARGIN + int(req["row"]) * ROW_HEIGHT),
				"to": Vector2(origin_x + (float(n["col"]) + 0.5) * COL_WIDTH, TOP_MARGIN + int(n["row"]) * ROW_HEIGHT),
				"lit": (n["id"] in _player.unlocked_skills) or (req_id in _player.unlocked_skills),
			})
	_connections_layer.queue_redraw()

	# Узлы поверх слоя связей (добавлены позже — рисуются позже, то есть сверху)
	for n in nodes:
		_add_node(n, origin_x)


func _draw_connections() -> void:
	for seg in _connection_segments:
		var col: Color = COLOR_BORDER_HI if seg["lit"] else COLOR_BORDER
		col.a = 0.85 if seg["lit"] else 0.45
		_connections_layer.draw_line(seg["from"], seg["to"], col, 3.0, true)


func _add_node(n: Dictionary, origin_x: float) -> void:
	var node_id: String = n["id"]
	var is_capstone: bool = n.get("is_capstone", false)
	var node_size: Vector2 = CAPSTONE_SIZE if is_capstone else NODE_SIZE
	var center := Vector2(
		origin_x + (float(n["col"]) + 0.5) * COL_WIDTH,
		TOP_MARGIN + int(n["row"]) * ROW_HEIGHT,
	)

	var state := _node_state(node_id)

	var btn := Button.new()
	btn.position = center - node_size / 2.0
	btn.size = node_size
	btn.text = _short_title(n["name"])
	btn.clip_text = true
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", 11 if not is_capstone else 13)
	btn.focus_mode = Control.FOCUS_NONE

	# Квадратные узлы (не круглые) — временная сетка по просьбе, точную форму
	# и расстановку доработаем отдельно. Небольшое скругление (не 0) — тот же
	# приём, что и у остальных панелей/кнопок в инвентаре (_make_panel/_make_button)
	var corner_radius := 8 if not is_capstone else 12
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3

	match state:
		"UNLOCKED":
			style.bg_color = Color(0.30, 0.22, 0.06, 1.0)
			style.border_color = COLOR_TEXT_GOLD
			btn.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
			btn.disabled = false  # кликабелен — можно навести и посмотреть тултип, но покупка не сработает повторно
		"AVAILABLE":
			style.bg_color = Color(0.16, 0.12, 0.05, 1.0)
			style.border_color = COLOR_BORDER_HI
			btn.add_theme_color_override("font_color", COLOR_TEXT)
			btn.disabled = false
		_:  # LOCKED
			style.bg_color = Color(0.05, 0.05, 0.05, 1.0)
			style.border_color = Color(0.25, 0.22, 0.18, 1.0)
			btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			btn.disabled = false  # тоже кликабелен — клик по LOCKED просто ничего не покупает, но тултип с причиной нужен

	if is_capstone:
		style.border_color = style.border_color.lightened(0.15) if state != "LOCKED" else style.border_color
		style.shadow_color = Color(0.9, 0.6, 0.1, 0.35)
		style.shadow_size = 10

	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.border_color = hover_style.border_color.lightened(0.25)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)

	btn.pressed.connect(_on_node_clicked.bind(node_id))
	btn.mouse_entered.connect(_show_tooltip.bind(n, state))
	btn.mouse_exited.connect(_hide_tooltip)

	_tree_area.add_child(btn)
	_node_buttons[node_id] = btn


func _short_title(full_name: String) -> String:
	return full_name


# ─────────────────────────────────────────────
# СОСТОЯНИЯ
# ─────────────────────────────────────────────

func _node_state(node_id: String) -> String:
	if node_id in _player.unlocked_skills:
		return "UNLOCKED"
	if _player.can_unlock_skill(tree_id, node_id):
		return "AVAILABLE"
	return "LOCKED"


func _update_header() -> void:
	var pts: int = _player.skill_points if ("skill_points" in _player) else 0
	_header_label.text = "SKILL POINTS: %d" % pts


# ─────────────────────────────────────────────
# ТУЛТИП
# ─────────────────────────────────────────────

func _ensure_tooltip() -> void:
	if is_instance_valid(_tooltip):
		return
	_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER_HI
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.custom_minimum_size = Vector2(260, 0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 100
	_tooltip.visible = false

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", COLOR_TEXT)
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)


func _show_tooltip(n: Dictionary, state: String) -> void:
	_ensure_tooltip()
	var status_ru: String = {"LOCKED": "ЗАПЕРТО", "AVAILABLE": "ДОСТУПНО", "UNLOCKED": "ОТКРЫТО"}.get(state, state)
	var lines: Array[String] = [
		"[%s]" % n["name"],
		"",
		String(n.get("lore", "")),
		"",
		"Эффект: %s" % n.get("effect_text", ""),
		"Стоимость: %d очко(ов) навыка" % int(n.get("cost", 1)),
		"Статус: %s" % status_ru,
	]
	if state == "LOCKED":
		var reason := _missing_requirements_text(n)
		if reason != "":
			lines.append("Требуется: %s" % reason)
	_tooltip_label.text = "\n".join(lines)

	var btn: Button = _node_buttons.get(n["id"])
	if is_instance_valid(btn):
		var global_pos: Vector2 = btn.global_position
		var local_pos: Vector2 = global_pos - global_position + Vector2(btn.size.x + 10.0, 0)
		_tooltip.position = local_pos
	_tooltip.visible = true


func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.visible = false


func _missing_requirements_text(n: Dictionary) -> String:
	var missing: Array[String] = []
	for req_id in n.get("prerequisites", []):
		if not (req_id in _player.unlocked_skills):
			var req: Dictionary = SkillTrees.get_node_data(tree_id, req_id)
			missing.append(String(req.get("name", req_id)))
	var min_count: int = n.get("min_unlocked_in_tree", 0)
	if min_count > 0:
		var tree_ids := {}
		for tn in SkillTrees.get_nodes(tree_id):
			tree_ids[tn["id"]] = true
		var unlocked_in_tree := 0
		for id in _player.unlocked_skills:
			if id in tree_ids:
				unlocked_in_tree += 1
		if unlocked_in_tree < min_count:
			missing.append("всего открыто узлов: %d/%d" % [unlocked_in_tree, min_count])
	return ", ".join(missing)


# ─────────────────────────────────────────────
# ПОКУПКА
# ─────────────────────────────────────────────

func _on_node_clicked(node_id: String) -> void:
	var state := _node_state(node_id)
	if state != "AVAILABLE":
		return  # LOCKED — клик по нему просто ничего не делает; UNLOCKED — уже куплено

	var n: Dictionary = SkillTrees.get_node_data(tree_id, node_id)
	var cost: int = n.get("cost", 1)
	if _player.skill_points < cost:
		_play_ui_sound(SOUND_DENIED)
		_flash_denied(node_id)
		return

	if not _player.try_unlock_skill(tree_id, node_id):
		_play_ui_sound(SOUND_DENIED)
		_flash_denied(node_id)
		return

	_play_ui_sound(SOUND_CHOICE)
	_hide_tooltip()
	_build()  # состояния/связи/шапка могли поменяться сразу у нескольких узлов


func _flash_denied(node_id: String) -> void:
	var btn: Button = _node_buttons.get(node_id)
	if not is_instance_valid(btn):
		return
	var tw := create_tween()
	tw.tween_property(btn, "modulate", COLOR_WARN, 0.08)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.18)
