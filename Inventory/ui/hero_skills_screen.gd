extends Control
## hero_skills_screen.gd — вкладка «НАВЫКИ» внутри нарисованного инвентаря
## героя: не отдельное окно поверх, а те же три панели, что у инвентаря и
## талисманов (вкладки остаются на месте):
##   слева  — дерево узлов на рунном круге (название дерева сверху);
##   центр  — карточка выбранного навыка: медальон, цена, эффект, «Изучить»;
##   справа — «ДРЕВА»: переключение между деревьями, очки навыков, «Назад».
## Отрисовку и логику узлов делает тот же skill_tree_panel.gd в трёх режимах
## ("tree"/"info"/"sidebar"), в цветах темы героя.

const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const SkillTreePanelScript := preload("res://Inventory/ui/skill_tree_panel.gd")

var _ui
var _tree: Control
var _info: Control
var _side: Control
var _title: Label
var _points: Label
var _progress: Label
var _trees: Array = []
var _active := 0


func init(ui) -> void:
	_ui = ui
	# Три дерева именно этого героя (Save/skill_trees.gd: HERO_TREES)
	_trees = ui.skill_trees()
	_build()


func _make_label(text: String, font_size: int) -> Label:
	return _ui._make_label(text, font_size)


## inventory_ui._show_content_panel — при каждом открытии
func refresh() -> void:
	var p: Node = _ui._player
	var pts: int = p.get("skill_points") if p != null and p.get("skill_points") != null else 0
	_points.text = tr("ОЧКОВ НАВЫКОВ:  %d") % pts
	var prog = p.get("skill_progress") if p != null else null
	var per = p.get("skill_progress_per_point") if p != null else null
	_progress.text = tr("До следующего очка: %d / %d") % [int(prog), int(per)] if prog != null and per != null else ""
	_title.text = String(_trees[_active]["name"])


func _build() -> void:
	var lay: Dictionary = HeroSkin.T["layout"]
	# Слева — дерево
	var gf := HeroSkin.build_frame(self, Rect2(HeroSkin.grid_x(), HeroSkin.TOP, lay["grid_w"], HeroSkin.FRAME_H), null, false)
	var ty: float = gf.position.y + lay["title_dy"]
	_title = _make_label("", 24)
	_title.add_theme_color_override("font_color", HeroSkin.GOLD)
	_title.position = Vector2(gf.position.x, ty)
	_title.size = Vector2(gf.size.x, 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	HeroSkin.divider(self, gf.position.x + 40, gf.size.x - 80, ty + 36)
	var tr := Rect2(gf.position.x + 8, ty + 70, gf.size.x - 16, gf.end.y - 8 - (ty + 70))
	_tree = _part("tree", tr)

	# Центр — карточка навыка в простой рамке темы (своя нарисованная карточка
	# Хальварда — под предмет, у неё другие поля)
	var mf := HeroSkin.build_frame(self, Rect2(HeroSkin.detail_x(), HeroSkin.TOP, lay["detail_w"], HeroSkin.FRAME_H), null, false)
	HeroSkin.plaque(self, self, "НАВЫК", mf.position.x, mf.size.x, mf.position.y + lay["title_dy"])
	var it: float = mf.position.y + HeroSkin.column_top() - 10.0
	_info = _part("info", Rect2(mf.position.x + 6, it, mf.size.x - 12, mf.end.y - 6 - it))

	# Справа — деревья, очки, назад
	var rf := HeroSkin.build_frame(self, HeroSkin.right_rect(), null)
	HeroSkin.plaque(self, self, "ДРЕВА", rf.position.x, rf.size.x, rf.position.y + lay["title_dy"])
	var sy: float = rf.position.y + HeroSkin.column_top()
	_side = _part("sidebar", Rect2(rf.position.x + 4, sy, rf.size.x - 8, 360))
	_side.connect("tree_switch_requested", _select_tree)
	var y := sy + 380.0
	HeroSkin.divider(self, rf.position.x + 20, rf.size.x - 40, y)
	_points = _make_label("", 20)
	_points.add_theme_color_override("font_color", HeroSkin.GOLD_HI)
	_points.position = Vector2(rf.position.x, y + 34)
	_points.size = Vector2(rf.size.x, 28)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_points)
	_progress = _make_label("", 15)
	_progress.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	_progress.position = Vector2(rf.position.x, y + 64)
	_progress.size = Vector2(rf.size.x, 22)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_progress)
	var hint := _make_label("Клик — выбрать навык,\nдвойной клик или E — изучить", 15)
	hint.add_theme_color_override("font_color", HeroSkin.TEXT_DIM)
	hint.position = Vector2(rf.position.x + 10, y + 100)
	hint.size = Vector2(rf.size.x - 20, 44)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var back := Button.new()
	back.text = "[ ESC ]   НАЗАД"
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(rf.position.x + 30, minf(y + 160.0, rf.end.y - 70.0))
	back.size = Vector2(rf.size.x - 60, 44)
	back.add_theme_font_size_override("font_size", 17)
	back.add_theme_color_override("font_color", HeroSkin.TEXT)
	back.add_theme_color_override("font_hover_color", HeroSkin.GOLD_HI)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45) if st == "normal" else Color(HeroSkin.GOLD_HI, 0.08)
		sb.border_color = Color(HeroSkin.GOLD, 0.45 if st == "normal" else 0.85)
		sb.set_border_width_all(1)
		back.add_theme_stylebox_override(st, sb)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(func(): _ui._close_skills())
	add_child(back)

	_info.set("source", _tree)
	_side.set("source", _tree)
	_select_tree(0, false)


## Кусок дерева навыков в своём режиме, в цветах темы
func _part(mode: String, r: Rect2) -> Control:
	var p: Control = SkillTreePanelScript.new()
	p.set("mode", mode)
	p.set("bare", true)
	p.call("apply_palette", HeroSkin.GOLD, HeroSkin.GOLD_HI, HeroSkin.TEXT, HeroSkin.TEXT_DIM)
	p.position = r.position.round()
	p.size = r.size.round()
	# Рунный круг дерева шире своей панели — не вылезает на рамку
	p.clip_contents = true
	add_child(p)
	return p


func _select_tree(index: int, sound := true) -> void:
	_active = clampi(index, 0, _trees.size() - 1)
	if sound:
		_ui._play_ui_sound(_ui.SOUND_CHOICE)
	var id: String = _trees[_active]["id"]
	for p in [_tree, _info, _side]:
		p.call("init", id, _ui._player, _trees, _active)
	refresh()
