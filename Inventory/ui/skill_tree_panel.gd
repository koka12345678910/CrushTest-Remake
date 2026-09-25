# res://Inventory/ui/skill_tree_panel.gd
extends Control
## Экран одного дерева навыков — строится целиком из данных SkillTrees.gd
## (см. get_nodes/get_node_data), ничего про конкретные узлы не хардкодит.
## Не завязан на конкретного персонажа — принимает любой Node с методами
## can_unlock_skill/try_unlock_skill и полями skill_points/unlocked_skills
## (сейчас это только player.gd, но контракт тот же, что и у SaveManager:
## has-проверки, а не жёсткая типизация).
##
## Вёрстка по макету: слева колонка деревьев (переключение), по центру
## сетка узлов на фоне рунного круга, справа карточка выбранного узла,
## внизу "← НАЗАД" и счётчик очков. Всё рисуется в _draw() в координатах
## макета DESIGN и масштабируется под реальный размер панели — дерево всегда
## видно целиком, без прокрутки.
##
## Клик по узлу — выбрать (карточка справа), двойной клик / кнопка
## "ИЗУЧИТЬ" / E — открыть. Картинка узла — поле "icon" в SkillTrees (если
## есть), иначе руна, нарисованная кодом.

signal back_requested
signal tree_switch_requested(index: int)

const DESIGN := Vector2(1844, 928)

const SIDEBAR_W := 300.0
const SIDEBAR_ITEM_Y := 110.0
const SIDEBAR_STEP := 125.0
const BACK_BTN := Rect2(70, 852, 150, 40)
const TREE_CENTER_X := 855.0
const TREE_TOP := 72.0
const ROW_STEP := 164.0
const COL_STEP := 206.0
const NODE_S := 108.0
const CAPSTONE_S := 138.0
const RING_C := Vector2(855, 420)
const INFO := Rect2(1384, 4, 447, 800)
const POINTS_PILL := Rect2(1548, 846, 206, 40)

const GOLD := Color(0.8, 0.62, 0.34)
const GOLD_BRIGHT := Color(1.0, 0.8, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.3, 0.7)
const GOLD_FAINT := Color(0.55, 0.45, 0.3, 0.22)
const GREY := Color(0.4, 0.38, 0.35)
const TEXT := Color(0.92, 0.86, 0.74)
const TEXT_DIM := Color(0.6, 0.55, 0.47)
const TEXT_LORE := Color(0.7, 0.58, 0.4)
const WARN := Color(0.85, 0.3, 0.25)

const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")

## Руны старшего футарка отрезками в единичных координатах (x ∈ ±0.5,
## y ∈ ±1). Узлу достаётся руна по его id — стабильно между запусками
const RUNES := [
	[[0, -1, 0, 1], [0, -0.55, 0.5, -1], [0, -0.05, 0.5, -0.5]],                        # ᚠ
	[[-0.35, 1, -0.35, -1], [-0.35, -1, 0.35, -0.45], [0.35, -0.45, 0.35, 1]],          # ᚢ
	[[0, -1, 0, 1], [0, -0.5, 0.45, 0], [0.45, 0, 0, 0.5]],                             # ᚦ
	[[0, -1, 0, 1], [0, -1, 0.5, -0.6], [0, -0.45, 0.5, -0.05]],                        # ᚨ
	[[0, -1, 0, 1], [0, -1, 0.45, -0.55], [0.45, -0.55, 0, -0.1], [0, -0.1, 0.45, 1]],  # ᚱ
	[[0.4, -0.7, -0.3, 0], [-0.3, 0, 0.4, 0.7]],                                        # ᚲ
	[[-0.5, -0.8, 0.5, 0.8], [0.5, -0.8, -0.5, 0.8]],                                   # ᚷ
	[[-0.35, -1, -0.35, 1], [0.35, -1, 0.35, 1], [-0.35, -0.3, 0.35, 0.3]],            # ᚺ
	[[0, -0.2, 0, 1], [0, -0.2, -0.5, -1], [0, -0.2, 0.5, -1], [0, -1, 0, -0.2]],     # ᛉ
	[[0, -1, 0, 1], [0, -1, -0.5, -0.5], [0, -1, 0.5, -0.5]],                           # ᛏ
	[[0, -1, 0.45, -0.35], [0, -1, -0.45, -0.35], [-0.45, -0.35, 0.45, 0.9], [0.45, -0.35, -0.45, 0.9]],  # ᛟ
	[[-0.5, -0.8, -0.5, 0.8], [-0.5, 0.8, 0.5, -0.8], [0.5, -0.8, 0.5, 0.8], [0.5, 0.8, -0.5, -0.8]],   # ᛞ
]

var tree_id: String = ""
var _player: Node = null
var _trees: Array = []      # [{name, icon: Texture2D|null, emblem: String}]
var _active_tree := 0

var _font: Font
var _font_italic: Font
var _scale := 1.0
var _offset := Vector2.ZERO
var _t := 0.0

var _nodes: Array = []
var _selected_id := ""
var _hover_id := ""
var _hover_sidebar := -1
var _hover_back := false
var _hover_learn := false
var _learn_rect := Rect2()
var _flash_id := ""
var _flash_t := 0.0
var _last_click_id := ""
var _last_click_time := 0.0
var _node_icons := {}   # id -> Texture2D


## trees/active — колонка слева; без них экран работает с одним деревом
func init(p_tree_id: String, player: Node, trees: Array = [], active := 0) -> void:
	tree_id = p_tree_id
	_player = player
	_trees = trees
	_active_tree = active
	mouse_filter = Control.MOUSE_FILTER_STOP
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	_font = serif
	var ital := SystemFont.new()
	ital.font_names = serif.font_names
	ital.font_italic = true
	_font_italic = ital

	_nodes = SkillTrees.get_nodes(tree_id) if _has_skills() else []
	for n in _nodes:
		var path: String = n.get("icon", "")
		if path != "" and ResourceLoader.exists(path):
			_node_icons[n["id"]] = load(path)
	_selected_id = _nodes[0]["id"] if not _nodes.is_empty() else ""
	queue_redraw()


func _has_skills() -> bool:
	return is_instance_valid(_player) and _player.has_method("try_unlock_skill") \
			and not SkillTrees.get_nodes(tree_id).is_empty()


func _play_ui_sound(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _process(delta: float) -> void:
	_t += delta
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
	queue_redraw()


# ─────────────────────────────────────────────
# ВВОД
# ─────────────────────────────────────────────

func _to_design(p: Vector2) -> Vector2:
	return (p - _offset) / _scale


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(_to_design(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(_to_design(event.position))
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_try_learn(_selected_id)
		get_viewport().set_input_as_handled()


func _update_hover(p: Vector2) -> void:
	_hover_id = ""
	for n in _nodes:
		if _node_rect(n).has_point(p):
			_hover_id = n["id"]
	_hover_sidebar = -1
	for i in _trees.size():
		if _sidebar_rect(i).has_point(p):
			_hover_sidebar = i
	_hover_back = BACK_BTN.has_point(p)
	_hover_learn = _learn_rect.has_area() and _learn_rect.has_point(p)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
			if (_hover_id != "" or _hover_sidebar >= 0 or _hover_back or _hover_learn) else Control.CURSOR_ARROW


func _click(p: Vector2) -> void:
	if BACK_BTN.has_point(p):
		back_requested.emit()
		return
	for i in _trees.size():
		if _sidebar_rect(i).has_point(p):
			if i != _active_tree:
				tree_switch_requested.emit(i)
			return
	if _learn_rect.has_area() and _learn_rect.has_point(p):
		_try_learn(_selected_id)
		return
	for n in _nodes:
		if _node_rect(n).has_point(p):
			var id: String = n["id"]
			var now := Time.get_ticks_msec() / 1000.0
			if id == _last_click_id and now - _last_click_time < 0.35:
				_try_learn(id)
			else:
				if id != _selected_id:
					_play_ui_sound(SOUND_CHOICE)
				_selected_id = id
			_last_click_id = id
			_last_click_time = now
			return


# ─────────────────────────────────────────────
# СОСТОЯНИЯ И ПОКУПКА
# ─────────────────────────────────────────────

func _node_state(node_id: String) -> String:
	if node_id in _player.unlocked_skills:
		return "UNLOCKED"
	if _player.can_unlock_skill(tree_id, node_id):
		return "AVAILABLE"
	return "LOCKED"


func _points() -> int:
	return _player.skill_points if (is_instance_valid(_player) and "skill_points" in _player) else 0


func _try_learn(node_id: String) -> void:
	if node_id == "" or not _has_skills():
		return
	if _node_state(node_id) != "AVAILABLE":
		if _node_state(node_id) == "LOCKED":
			_deny(node_id)
		return
	var n: Dictionary = SkillTrees.get_node_data(tree_id, node_id)
	if _points() < int(n.get("cost", 1)) or not _player.try_unlock_skill(tree_id, node_id):
		_deny(node_id)
		return
	_play_ui_sound(SOUND_ACCEPT)
	_selected_id = node_id


func _deny(node_id: String) -> void:
	_play_ui_sound(SOUND_DENIED)
	_flash_id = node_id
	_flash_t = 0.3


func _missing_requirements_text(n: Dictionary) -> String:
	var missing: Array[String] = []
	for req_id in n.get("prerequisites", []):
		if not (req_id in _player.unlocked_skills):
			var req: Dictionary = SkillTrees.get_node_data(tree_id, req_id)
			missing.append(String(req.get("name", req_id)).capitalize())
	var min_count: int = n.get("min_unlocked_in_tree", 0)
	if min_count > 0:
		var tree_ids := {}
		for tn in _nodes:
			tree_ids[tn["id"]] = true
		var unlocked_in_tree := 0
		for id in _player.unlocked_skills:
			if id in tree_ids:
				unlocked_in_tree += 1
		if unlocked_in_tree < min_count:
			missing.append("открыто навыков %d/%d" % [unlocked_in_tree, min_count])
	return ", ".join(missing)


static func _points_word(n: int) -> String:
	var m10 := n % 10
	var m100 := n % 100
	if m10 == 1 and m100 != 11:
		return "очко"
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "очка"
	return "очков"


# ─────────────────────────────────────────────
# ГЕОМЕТРИЯ
# ─────────────────────────────────────────────

func _node_center(n: Dictionary) -> Vector2:
	# Колонки центрируются по самой широкой строке: col 1.5 — середина дерева
	return Vector2(TREE_CENTER_X + (float(n["col"]) - 1.5) * COL_STEP,
			TREE_TOP + int(n["row"]) * ROW_STEP)


func _node_size(n: Dictionary) -> float:
	return CAPSTONE_S if n.get("is_capstone", false) else NODE_S


func _node_rect(n: Dictionary) -> Rect2:
	var s := _node_size(n)
	return Rect2(_node_center(n) - Vector2(s, s) * 0.5, Vector2(s, s))


func _sidebar_rect(i: int) -> Rect2:
	return Rect2(8, SIDEBAR_ITEM_Y + i * SIDEBAR_STEP - 52, SIDEBAR_W - 24, 104)


# ─────────────────────────────────────────────
# ОТРИСОВКА
# ─────────────────────────────────────────────

func _draw() -> void:
	if _font == null:
		return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_offset = (size - DESIGN * _scale) * 0.5
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))

	_draw_ring_background()
	_draw_sidebar()
	_draw_back_button()
	if _nodes.is_empty():
		_text(Vector2(SIDEBAR_W, RING_C.y - 10), _tree_name().to_upper(), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER, INFO.position.x - SIDEBAR_W)
		_text(Vector2(SIDEBAR_W, RING_C.y + 26), "Древо навыков в разработке", 18, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, INFO.position.x - SIDEBAR_W)
	else:
		_draw_connections()
		for n in _nodes:
			_draw_node(n)
	_draw_info_panel()
	_draw_points_pill()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tree_name() -> String:
	if _active_tree < _trees.size():
		return String(_trees[_active_tree].get("name", ""))
	return String(SkillTrees.get_tree_data(tree_id).get("name", ""))


func _text(pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font: Font = null) -> void:
	draw_string(font if font else _font, pos, s, align, width, sz, col)


func _text_w(s: String, sz: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


func _diamond(c: Vector2, s: float, col: Color, filled := false) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	if filled:
		draw_colored_polygon(pts, Color(0.06, 0.05, 0.04))
	pts.append(pts[0])
	draw_polyline(pts, col, 1.3, true)
	if filled:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.4, 0),
				c + Vector2(0, s * 0.4), c + Vector2(-s * 0.4, 0)]), col)


func _ornament_line(a: Vector2, b: Vector2, col: Color) -> void:
	var mid := (a + b) * 0.5
	draw_line(a, mid - Vector2(12, 0), col, 1.0)
	draw_line(mid + Vector2(12, 0), b, col, 1.0)
	_diamond(mid, 5.0, col)
	draw_circle(a, 1.5, col)
	draw_circle(b, 1.5, col)


func _draw_rune(c: Vector2, h: float, rune_i: int, col: Color, width: float) -> void:
	for seg in RUNES[rune_i % RUNES.size()]:
		var a := c + Vector2(seg[0], seg[1]) * h
		var b := c + Vector2(seg[2], seg[3]) * h
		draw_line(a, b, col, width, true)


func _rune_for(node_id: String) -> int:
	return absi(node_id.hash()) % RUNES.size()


## Фон под деревом: гравированный рунный круг, как на макете
func _draw_ring_background() -> void:
	var c := RING_C
	var faint := Color(0.55, 0.48, 0.38, 0.07)
	for r in [440.0, 400.0, 360.0, 240.0]:
		draw_arc(c, r, 0.0, TAU, 128, faint, 1.2, true)
	draw_arc(c, 380.0, 0.0, TAU, 128, Color(faint, 0.05), 18.0, true)
	for k in 24:
		var a := k * TAU / 24.0
		var p := c + Vector2.from_angle(a) * 380.0
		_draw_rune(p, 8.0, k, Color(0.6, 0.5, 0.38, 0.12), 1.5)
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0 + PI / 8.0)
		draw_line(c + d * 240.0, c + d * 360.0, faint, 1.0)


# ── Колонка деревьев ─────────────────────────────────────────────────────────

func _draw_sidebar() -> void:
	draw_line(Vector2(SIDEBAR_W, 10), Vector2(SIDEBAR_W, 910), GOLD_FAINT, 1.0)
	draw_line(Vector2(SIDEBAR_W - 6, 10), Vector2(SIDEBAR_W - 6, 910), Color(GOLD_FAINT, 0.1), 1.0)
	for i in _trees.size():
		var cy := SIDEBAR_ITEM_Y + i * SIDEBAR_STEP
		var active := i == _active_tree
		var hot := i == _hover_sidebar
		var ec := Vector2(58, cy)
		if active:
			# Подсветка строки: тёплая полоса, гаснущая вправо
			for k in 8:
				draw_rect(Rect2(8 + k * 30, cy - 50, 30, 100), Color(0.5, 0.3, 0.1, 0.06 * (8 - k) / 8.0))
			draw_line(Vector2(8, cy - 50), Vector2(SIDEBAR_W - 20, cy - 50), Color(GOLD, 0.35), 1.0)
			draw_line(Vector2(8, cy + 50), Vector2(SIDEBAR_W - 20, cy + 50), Color(GOLD, 0.35), 1.0)
			_diamond(Vector2(SIDEBAR_W - 6, cy), 6.0, GOLD, true)
			var pulse := 0.8 + 0.2 * sin(_t * 2.2)
			for g in 4:
				_diamond(ec, 46.0 + g * 3.0, Color(1.0, 0.62, 0.22, 0.14 * pulse * (4 - g) / 4.0))
			_diamond(ec, 46.0, GOLD_BRIGHT, true)
			_diamond(ec, 38.0, Color(GOLD, 0.5))
		else:
			draw_circle(ec, 42.0, Color(0.05, 0.045, 0.04))
			draw_arc(ec, 42.0, 0.0, TAU, 48, GOLD if hot else Color(0.45, 0.4, 0.34, 0.8), 1.5, true)
			draw_arc(ec, 35.0, 0.0, TAU, 48, Color(0.45, 0.4, 0.34, 0.35), 1.0, true)
			for k in 4:
				var d := Vector2.from_angle(k * PI / 2.0)
				draw_line(ec + d * 42.0, ec + d * 50.0, Color(0.45, 0.4, 0.34, 0.7), 1.2)
		_draw_tree_emblem(i, ec, 24.0, active or hot)
		if i < _trees.size() - 1:
			draw_line(Vector2(110, cy + SIDEBAR_STEP * 0.5), Vector2(SIDEBAR_W - 30, cy + SIDEBAR_STEP * 0.5), GOLD_FAINT, 1.0)
		var name_col := TEXT if active else (GOLD if hot else TEXT_DIM)
		_text(Vector2(118, cy + 7), String(_trees[i].get("name", "")).capitalize(), 20, name_col)


## Эмблема дерева в колонке: PNG (серым, если не активно) или простая
## фигура-заглушка того же смысла, что и на карточках выбора
func _draw_tree_emblem(i: int, c: Vector2, r: float, lit: bool) -> void:
	var col := GOLD_BRIGHT if lit else Color(0.55, 0.53, 0.5)
	var tex = _trees[i].get("icon", null)
	if tex is Texture2D:
		var m := Color(1, 1, 1) if lit else Color(0.5, 0.5, 0.5)
		draw_texture_rect(tex, Rect2(c - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, m)
		return
	match String(_trees[i].get("emblem", "")):
		"fang":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 2.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 0.22, -r * 0.6), c + Vector2(-r * 0.22, -r * 0.6)]), col)
			for s: float in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([c + Vector2(s * r * 0.15, r * 0.25), c + Vector2(s * r * 0.55, 0), c + Vector2(s * r * 0.5, -r * 0.5)]), col, 1.8, true)
		"swirl":
			for k in 4:
				draw_arc(c, r * (0.3 + k * 0.18), k * 1.6, k * 1.6 + 2.6, 16, col, 2.0, true)
			_diamond(c, r * 0.18, col, true)
		_:
			_draw_rune(c, r * 0.6, i, col, 2.0)


func _draw_back_button() -> void:
	var r := BACK_BTN
	var col := GOLD if _hover_back else GOLD_DIM
	draw_rect(r, Color(0.12, 0.09, 0.05, 0.9) if _hover_back else Color(0.04, 0.036, 0.032, 0.9))
	draw_rect(r, col, false, 1.3)
	draw_rect(r.grow(-4.0), Color(col, 0.3), false, 1.0)
	_diamond(Vector2(r.position.x + 16, r.get_center().y), 4.0, col)
	_text(Vector2(r.position.x + 30, r.get_center().y + 7), "←  НАЗАД", 18, GOLD_BRIGHT if _hover_back else TEXT)


# ── Узлы ─────────────────────────────────────────────────────────────────────

func _draw_connections() -> void:
	for n in _nodes:
		for req_id in n.get("prerequisites", []):
			var req: Dictionary = SkillTrees.get_node_data(tree_id, req_id)
			if req.is_empty():
				continue
			var lit: bool = (n["id"] in _player.unlocked_skills) or (req_id in _player.unlocked_skills)
			var col := Color(GOLD, 0.7) if lit else Color(0.5, 0.45, 0.36, 0.35)
			draw_line(_node_center(req), _node_center(n), col, 1.6 if lit else 1.2, true)


func _draw_node(n: Dictionary) -> void:
	var id: String = n["id"]
	var state := _node_state(id)
	var cap: bool = n.get("is_capstone", false)
	var r := _node_rect(n)
	var c := r.get_center()
	var selected := id == _selected_id
	var hot := id == _hover_id
	var pulse := 0.75 + 0.25 * sin(_t * 2.4)

	var frame := GREY
	var icon_col := Color(0.38, 0.36, 0.33)
	match state:
		"UNLOCKED":
			frame = GOLD_BRIGHT
			icon_col = Color(1.0, 0.82, 0.48)
		"AVAILABLE":
			frame = GOLD
			icon_col = Color(0.78, 0.72, 0.62)
	if hot:
		frame = frame.lightened(0.2)
	if _flash_id == id and _flash_t > 0.0:
		frame = frame.lerp(WARN, _flash_t / 0.3)

	# Свечение: у изученных и у выбранного
	if state == "UNLOCKED" or selected or cap:
		var ga := (0.16 if selected else 0.1) * pulse
		if state == "LOCKED" and not selected:
			ga *= 0.4
		for g in 5:
			draw_rect(r.grow(3.0 + g * 4.0), Color(1.0, 0.6, 0.2, ga * (5 - g) / 5.0), false, 4.0)

	# Коробка узла: тёмная плита, двойная кайма, уголки
	draw_rect(r, Color(0.045, 0.04, 0.036, 0.98))
	for k in 4:
		draw_rect(r.grow(-6.0 - k * 6.0), Color(0.1, 0.09, 0.08, 0.05))
	draw_rect(r, frame, false, 1.8)
	draw_rect(r.grow(-5.0), Color(frame, 0.4), false, 1.0)
	for cc in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0],
			[Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		var p: Vector2 = cc[0]
		var sx: float = cc[1]
		var sy: float = cc[2]
		draw_line(p + Vector2(-sx * 3, -sy * 3), p + Vector2(sx * 14, -sy * 3), frame, 1.4)
		draw_line(p + Vector2(-sx * 3, -sy * 3), p + Vector2(-sx * 3, sy * 14), frame, 1.4)

	# Картинка узла или руна
	if _node_icons.has(id):
		var m := Color.WHITE if state != "LOCKED" else Color(0.45, 0.45, 0.45)
		draw_texture_rect(_node_icons[id], r.grow(-8.0), false, m)
	else:
		var rh := r.size.y * 0.3
		draw_circle(c + Vector2(0, -6), r.size.x * 0.34, Color(0, 0, 0, 0.35))
		draw_arc(c + Vector2(0, -6), r.size.x * 0.34, 0.0, TAU, 40, Color(icon_col, 0.3), 1.0, true)
		_draw_rune(c + Vector2(0, -6), rh, _rune_for(id), Color(0.02, 0.02, 0.02, 0.8), 6.0)
		_draw_rune(c + Vector2(0, -6), rh, _rune_for(id), icon_col, 3.2)

	# Ромбы-подвески у первого и финального узла, как на макете
	if int(n["row"]) == 0:
		_diamond(Vector2(c.x, r.position.y - 14), 7.0, frame, true)
		draw_line(Vector2(c.x, r.position.y - 7), Vector2(c.x, r.position.y), frame, 1.2)
	if cap:
		_diamond(Vector2(c.x, r.end.y + 52), 7.0, frame, true)

	_draw_plate(n, r, frame, state, cap, selected)


## Табличка с названием у нижней кромки узла. Длинное название — первое
## слово на табличке, остальное строкой ниже (как на макете)
func _draw_plate(n: Dictionary, r: Rect2, frame: Color, state: String, cap: bool, selected: bool) -> void:
	var name_s: String = String(n["name"]).to_upper()
	var fs := 16 if cap else 14
	var line1 := name_s
	var line2 := ""
	if not cap and _text_w(name_s, fs) > r.size.x + 6.0 and name_s.contains(" "):
		var cut := name_s.find(" ")
		line1 = name_s.substr(0, cut)
		line2 = name_s.substr(cut + 1)
	var pw := maxf(_text_w(line1, fs) + 26.0, r.size.x * 0.9)
	var ph := 26.0 if cap else 22.0
	var pr := Rect2(r.get_center().x - pw * 0.5, r.end.y - ph * 0.55, pw, ph)
	draw_rect(pr, Color(0.035, 0.03, 0.027, 0.97))
	var border := frame if (selected or cap or state == "UNLOCKED") else Color(frame, 0.75)
	draw_rect(pr, border, false, 1.3)
	draw_rect(pr.grow(-3.0), Color(border, 0.3), false, 1.0)
	if cap:
		var cy := pr.get_center().y
		for s: float in [-1.0, 1.0]:
			var x := pr.position.x - 4.0 if s < 0.0 else pr.end.x + 4.0
			draw_polyline(PackedVector2Array([Vector2(x - s * 2, cy - 9), Vector2(x + s * 8, cy), Vector2(x - s * 2, cy + 9)]), border, 1.3, true)
			_diamond(Vector2(x + s * 16, cy), 3.5, border)
	var tc := TEXT if state != "LOCKED" else TEXT_DIM
	if state == "UNLOCKED" or selected:
		tc = Color(1.0, 0.9, 0.7)
	_text(Vector2(pr.position.x, pr.get_center().y + fs * 0.36), line1, fs, tc, HORIZONTAL_ALIGNMENT_CENTER, pw)
	if line2 != "":
		_text(Vector2(pr.position.x - 20, pr.end.y + 16), line2, fs - 1, Color(tc, 0.85), HORIZONTAL_ALIGNMENT_CENTER, pw + 40)


# ── Карточка выбранного узла ─────────────────────────────────────────────────

func _draw_info_panel() -> void:
	var r := INFO
	draw_rect(r, Color(0.035, 0.032, 0.03, 0.95))
	draw_rect(r, GOLD_DIM, false, 1.3)
	draw_rect(r.grow(-8.0), GOLD_FAINT, false, 1.0)
	for cc in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0],
			[Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		var p: Vector2 = cc[0]
		var sx: float = cc[1]
		var sy: float = cc[2]
		draw_line(p + Vector2(-sx * 5, -sy * 5), p + Vector2(sx * 30, -sy * 5), GOLD, 1.5)
		draw_line(p + Vector2(-sx * 5, -sy * 5), p + Vector2(-sx * 5, sy * 30), GOLD, 1.5)
		draw_line(p + Vector2(sx * 4, sy * 4), p + Vector2(sx * 14, sy * 14), GOLD_DIM, 1.0)
		_diamond(p + Vector2(-sx * 5, -sy * 5), 4.0, GOLD, true)

	_learn_rect = Rect2()
	var n: Dictionary = SkillTrees.get_node_data(tree_id, _selected_id) if _selected_id != "" else {}
	var cx := r.get_center().x
	if n.is_empty():
		var hint := "Выберите навык" if not _nodes.is_empty() else "Навыки появятся позже"
		_text(Vector2(r.position.x, r.get_center().y), hint, 20, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return

	var state := _node_state(_selected_id)
	var cap: bool = n.get("is_capstone", false)

	# Медальон с картинкой/руной узла
	var mc := Vector2(cx, r.position.y + 132)
	var pulse := 0.75 + 0.25 * sin(_t * 2.0)
	for g in 6:
		draw_circle(mc, 96.0 - g * 6.0, Color(1.0, 0.55, 0.2, 0.025 * pulse))
	draw_circle(mc, 84.0, Color(0.03, 0.027, 0.024))
	draw_arc(mc, 92.0, 0.0, TAU, 72, GOLD_FAINT, 1.0, true)
	draw_arc(mc, 84.0, 0.0, TAU, 72, GOLD, 1.8, true)
	draw_arc(mc, 76.0, 0.0, TAU, 72, Color(GOLD, 0.35), 1.0, true)
	for k in 36:
		var d := Vector2.from_angle(k * TAU / 36.0 + _t * 0.04)
		draw_line(mc + d * 85.0, mc + d * (89.0 if k % 3 else 92.0), GOLD_DIM, 1.0)
	for k in 4:
		var d := Vector2.from_angle(k * PI / 2.0 - PI / 2.0)
		_diamond(mc + d * 100.0, 5.0, GOLD, true)
	var lit := state != "LOCKED"
	if _node_icons.has(_selected_id):
		draw_texture_rect(_node_icons[_selected_id], Rect2(mc - Vector2(66, 66), Vector2(132, 132)), false,
				Color.WHITE if lit else Color(0.5, 0.5, 0.5))
	else:
		var rc := Color(1.0, 0.82, 0.48) if lit else Color(0.5, 0.48, 0.44)
		_draw_rune(mc, 44.0, _rune_for(_selected_id), Color(0.02, 0.02, 0.02, 0.8), 9.0)
		_draw_rune(mc, 44.0, _rune_for(_selected_id), rc, 5.0)

	var y := r.position.y + 262.0
	_text(Vector2(r.position.x, y), String(n["name"]).to_upper(), 26, Color(1.0, 0.88, 0.62), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 32.0
	_text(Vector2(r.position.x, y), "Ключевой навык" if cap else "Пассивный навык", 17, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 26.0
	_ornament_line(Vector2(r.position.x + 40, y), Vector2(r.end.x - 40, y), GOLD_DIM)

	# "Требуется: N очков" — плашка с крылышками
	y += 34.0
	var cost := int(n.get("cost", 1))
	var cost_s := "Требуется: %d %s" % [cost, _points_word(cost)]
	var pw := _text_w(cost_s, 17) + 40.0
	var pr := Rect2(cx - pw * 0.5, y - 20, pw, 32)
	draw_rect(pr, Color(0.05, 0.045, 0.04))
	draw_rect(pr, GOLD_DIM, false, 1.2)
	for s: float in [-1.0, 1.0]:
		var x := pr.position.x - 4.0 if s < 0.0 else pr.end.x + 4.0
		draw_line(Vector2(x, pr.get_center().y), Vector2(x + s * 14, pr.get_center().y), GOLD_DIM, 1.0)
		_diamond(Vector2(x + s * 18, pr.get_center().y), 3.0, GOLD_DIM)
	_diamond(Vector2(cx, pr.end.y + 8), 3.5, GOLD_DIM)
	_text(pr.position + Vector2(0, 22), cost_s, 17, Color(0.85, 0.75, 0.55), HORIZONTAL_ALIGNMENT_CENTER, pw)

	# Эффект
	y = pr.end.y + 46.0
	var tw := r.size.x - 76.0
	var effect := String(n.get("effect_text", ""))
	draw_multiline_string(_font, Vector2(r.position.x + 38, y), effect, HORIZONTAL_ALIGNMENT_LEFT, tw, 19, -1, TEXT)
	y += _font.get_multiline_string_size(effect, HORIZONTAL_ALIGNMENT_LEFT, tw, 19).y + 18.0

	# Статус / кнопка
	match state:
		"UNLOCKED":
			_text(Vector2(r.position.x, y + 12), "◆  ИЗУЧЕНО  ◆", 18, GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			y += 30.0
		"AVAILABLE":
			var enough := _points() >= cost
			_learn_rect = Rect2(cx - 120, y - 8, 240, 42)
			var hot := _hover_learn and enough
			var bc := GOLD if hot else GOLD_DIM
			draw_rect(_learn_rect, Color(0.14, 0.1, 0.05, 0.95) if hot else Color(0.05, 0.045, 0.04, 0.95))
			draw_rect(_learn_rect, bc, false, 1.3)
			draw_rect(_learn_rect.grow(-4.0), Color(bc, 0.3), false, 1.0)
			var label := "[E]  ИЗУЧИТЬ" if enough else "Недостаточно очков"
			_text(Vector2(_learn_rect.position.x, _learn_rect.get_center().y + 7), label, 18,
					(GOLD_BRIGHT if hot else TEXT) if enough else Color(WARN, 0.85), HORIZONTAL_ALIGNMENT_CENTER, _learn_rect.size.x)
			y += 48.0
		_:
			var miss := _missing_requirements_text(n)
			if miss != "":
				var ms := "Сначала: " + miss
				draw_multiline_string(_font, Vector2(r.position.x + 38, y + 8), ms, HORIZONTAL_ALIGNMENT_CENTER, tw, 16, -1, Color(WARN, 0.8))
				y += _font.get_multiline_string_size(ms, HORIZONTAL_ALIGNMENT_CENTER, tw, 16).y + 8.0

	# Разделитель и предание
	y = maxf(y + 20.0, r.position.y + 540.0)
	_ornament_line(Vector2(r.position.x + 30, y), Vector2(r.end.x - 30, y), GOLD_FAINT)
	var lore := String(n.get("lore", ""))
	if lore != "":
		var ly := maxf(y + 60.0, r.position.y + 640.0)
		var quote := "«%s»" % lore
		draw_multiline_string(_font_italic, Vector2(r.position.x + 44, ly), quote, HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x - 88.0, 18, -1, TEXT_LORE)
		var lh := _font_italic.get_multiline_string_size(quote, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 88.0, 18).y
		_diamond(Vector2(cx, minf(ly + lh + 10.0, r.end.y - 20.0)), 3.5, GOLD_DIM)


func _draw_points_pill() -> void:
	var r := POINTS_PILL
	var s := "ОЧКОВ НАВЫКОВ: %d" % _points()
	draw_rect(r, Color(0.04, 0.036, 0.032, 0.95))
	draw_rect(r, GOLD_DIM, false, 1.3)
	draw_rect(r.grow(-4.0), GOLD_FAINT, false, 1.0)
	var cy := r.get_center().y
	for side: float in [-1.0, 1.0]:
		var x := r.position.x - 4.0 if side < 0.0 else r.end.x + 4.0
		draw_polyline(PackedVector2Array([Vector2(x - side * 2, cy - 10), Vector2(x + side * 8, cy), Vector2(x - side * 2, cy + 10)]), GOLD_DIM, 1.3, true)
		_diamond(Vector2(x + side * 16, cy), 3.5, GOLD_DIM)
		_diamond(Vector2(x + side * 26, cy), 2.5, Color(GOLD_DIM, 0.6))
	_text(Vector2(r.position.x, cy + 7), s, 17, TEXT if _points() > 0 else TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
