extends RefCounted
## hero_inventory_skin.gd — вид инвентаря героя, окно на весь экран: три
## тёмные полупрозрачные панели (сетка | карточка | правая колонка) без
## картинок, за ними — сам мир, слегка затемнённый (inventory_ui.gd,
## bg_screen "world"). Золотом подсвечивается только выбранное: клетка,
## вкладка, значок категории. Вид один на всех героев; отличаются только их
## разделы (Магия и трофеи рыцаря, колчан Сигрид, Гримуар мага).
##
## Детали рисует proc_skin.gd — по одной StyleBoxFlat на деталь, без
## текстур и шейдеров фона (дёшево для железа). Иконки предметов — свой
## шейдер сглаженного уменьшения (ICON_FADE_CODE).
##
## Логика инвентаря та же (inventory_ui.gd): здесь строятся те же узлы
## (_grid_slots, _detail_*, _big_slots, _btn_equip, _tab_buttons,
## _quick_col_header) в этой раскладке. Тема — статическая (T): инвентарь
## один, и вкладка талисманов (hero_talisman_panel.gd) берёт те же функции.

const Proc := preload("res://Inventory/ui/proc_skin.gd")
## Живые панели правой колонки: сага героя, колчан, алтарь
const Side := preload("res://Inventory/ui/hero_side_panels.gd")

# ═════════════════════ Тема ═════════════════════

const CLEAN := {
	## Палитра деталей proc_skin.gd
	"pal": {
		## Почти непрозрачный чёрный: ночной сине-серый мир не просвечивает
		"fill": Color(0.012, 0.012, 0.012, 0.95),
		"border": Color(1, 1, 1, 0.07),
		"accent": Color(0.86, 0.68, 0.38),
	},
	## Отступ поля от края панели
	"pad": 14,
	## Фона-картинки нет: за инвентарём — мир, затемнённый
	## (inventory_ui._build_backdrop) почти до чёрного — его синева не красит
	## инвентарь; игровой HUD на это время прячется
	"bg_screen": "world",
	"world_dim": 0.78,
	"tabs": {"y": 28, "width": 1180, "h": 58, "text_y": Vector2(6, 52)},
	"layout": {"x0": 46, "top": 118, "frame_h": 890, "grid_w": 820, "detail_w": 560, "right_w": 420,
		"cols": 6, "rows": 5, "title_dy": 14},
	"gold": Color(0.86, 0.68, 0.38),
	"gold_hi": Color(1.0, 0.83, 0.5),
	"text": Color(0.88, 0.86, 0.82),
	"text_dim": Color(0.56, 0.55, 0.53),
	"line": Color(1, 1, 1, 0.08),
	## Каталог магазина с преданиями — по герою (theme_for подставляет)
	"lore": "_knight_items",
	## Категории — значками над сеткой: [id, название, значок]
	"filters": [["", "Всё", "all"], ["potion", "Зелья", "potion"], ["skill", "Навыки", "rune"],
		["talisman", "Талисманы", "amulet"], ["key", "Ключи", "key"]],
}

const CELL_GAP := 12

## Значки навигации из листа UI/icons_inventory (Proc.SheetIcon.RECTS):
## вкладки — по id из TAB_* inventory_ui.gd, фильтры — по значку T.filters
const TAB_ICONS := {0: "bag", 1: "swords", 2: "ring", 3: "gear", 4: "star", 5: "book"}
const CHIP_ICONS := {"all": "chest", "potion": "potion", "rune": "scroll", "amulet": "ring", "key": "key"}

## Тема по герою: вид у всех один, предания предметов — из каталога магазина
## своего героя (character_id лучницы — "archer", мага — "mage", у рыцаря
## (player.gd) поля нет — null)
static func theme_for(character_id) -> Variant:
	var t: Dictionary = CLEAN.duplicate()
	match character_id:
		"archer":
			t["lore"] = "_archer_items"
		"mage":
			t["lore"] = "_mage_items"
		_:
			t["lore"] = "_knight_items"
	return t


static var T: Dictionary
static var GOLD: Color
static var GOLD_HI: Color
static var TEXT: Color
static var TEXT_DIM: Color
static var LINE: Color
static var TOP: int
static var FRAME_H: int

var _lore: Label
var _ui
var _content: Control
var _grid_title: Label


static func use_theme(theme: Dictionary) -> void:
	T = theme
	GOLD = theme["gold"]
	GOLD_HI = theme["gold_hi"]
	TEXT = theme["text"]
	TEXT_DIM = theme["text_dim"]
	LINE = theme["line"]
	TOP = theme["layout"]["top"]
	FRAME_H = theme["layout"]["frame_h"]


func _init(theme: Dictionary) -> void:
	use_theme(theme)


## Иконки — целые картинки 256 px (тёмный рисунок на тёмном фоне со своей
## рамкой), а в ячейке они в 2-2.6 раза меньше. Поэтому:
##  - берётся середина картинки (zoom) — своя рамка иконки не двоится с клеткой;
##  - уменьшение со сглаживанием: 9 выборок по площади экранного пикселя
##    (у иконок нет мип-карт, обычная выборка рвёт тонкие линии в точки);
##  - тёмное НЕ вырезается в прозрачность (от этого перо рассыпалось), края
##    просто мягко растворяются в клетке;
##  - яркость — gain шейдера. COLOR во fragment() уже умножен на текстуру,
##    поэтому цвет считается только из своих выборок
const ICON_FADE_CODE := """
shader_type canvas_item;
uniform float zoom = 0.82;
uniform float gain = 1.0;
void fragment() {
	vec2 uv = 0.5 + (UV - 0.5) * zoom;
	vec2 px = fwidth(uv) / 3.0;
	vec4 c = vec4(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			c += texture(TEXTURE, uv + vec2(float(i), float(j)) * px);
		}
	}
	c /= 9.0;
	vec2 d = abs(UV - 0.5) * 2.0;
	float box = 1.0 - smoothstep(0.74, 1.0, max(d.x, d.y));
	float round_k = 1.0 - smoothstep(0.98, 1.36, length(d));
	COLOR = vec4(c.rgb * gain, c.a * box * round_k);
}
"""
static var _icon_mats := {}


# ═════════════════════ Детали ═════════════════════

## Материал иконки с яркостью gain (по одному на каждую яркость)
static func icon_material(gain := 1.0) -> ShaderMaterial:
	if not _icon_mats.has(gain):
		var sh := Shader.new()
		sh.code = ICON_FADE_CODE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("gain", gain)
		_icon_mats[gain] = m
	return _icon_mats[gain]


## Иконка предмета; gain — яркость (рисунки тёмные, в ячейке чуть светлее)
static func make_icon(gain := 1.15) -> TextureRect:
	var icon := TextureRect.new()
	icon.material = icon_material(gain)
	# Режим растяжения — ДО текстуры и размера: иначе минимальный размер
	# берётся по картинке (256 px) и иконка вылезает за ячейку
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Панель любого размера (тёмная полупрозрачная плашка); возвращает
## прямоугольник её поля (с отступом pad). Второй и третий аргументы — от
## старых нарисованных тем, вызовы их ещё передают; не используются
static func build_frame(root: Control, r: Rect2, _bg = null, _unused := true) -> Rect2:
	var pf := Proc.ProcFrame.new()
	pf.pal = T["pal"]
	pf.position = r.position
	pf.size = r.size
	root.add_child(pf)
	return field_of(r)


static func field_of(r: Rect2) -> Rect2:
	return r.grow(-float(T["pad"]))


## Подсветка выбранной/наведённой клетки (поверх cell_plate) — золотом
static func make_cell_frame() -> HeroCell:
	var f := HeroCell.new()
	f.gold = GOLD_HI
	return f


## Клетка нужного размера — тёмный полупрозрачный квадрат
static func cell_plate(root: Control, sz: Vector2) -> Control:
	var pc := Proc.ProcCell.new()
	pc.size = sz
	root.add_child(pc)
	return pc


## Разделитель — тонкая черта, гаснущая к концам, по отрезку x..x+w
static func divider(root: Control, x: float, w: float, y: float) -> void:
	var d := Proc.ProcDivider.new()
	d.position = Vector2(round(x), round(y))
	d.size = Vector2(round(w), 20)
	root.add_child(d)


## Тонкая черта, растворяющаяся к концам
static func hline(root: Control, x: float, w: float, y: float) -> void:
	var l := FadeLine.new()
	l.color = LINE
	l.position = Vector2(round(x), round(y))
	l.size = Vector2(round(w), 1)
	root.add_child(l)


## Заголовок колонки по центру отрезка x..x+w (золотистая подпись с тонкой
## чертой под ней); возвращает надпись
static func plaque(lbl, root: Control, text: String, x: float, w: float, y: float) -> Label:
	var pp := Proc.ProcPlaque.new()
	pp.pal = T["pal"]
	pp.size = Vector2(250, 40)
	pp.position = Vector2(round(x + (w - 250.0) * 0.5), y)
	root.add_child(pp)
	var l: Label = lbl._make_label(text, 17)
	l.add_theme_color_override("font_color", GOLD)
	l.size = pp.size - Vector2(0, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pp.add_child(l)
	return l


# ═════════════════════ Раскладка ═════════════════════
# Слева направо: сетка, карточка, правая колонка — на всю ширину экрана

static func grid_x() -> int:
	return T["layout"]["x0"]


static func detail_x() -> int:
	return grid_x() + T["layout"]["grid_w"] + 14


static func right_x() -> int:
	return detail_x() + T["layout"]["detail_w"] + 14


## Где в правой колонке (от верха поля) начинаются ячейки — под табличкой
## заголовка; табличка ниже, если верхний ромб рамки крупный (title_dy)
static func column_top() -> float:
	return maxf(100.0, float(T["layout"]["title_dy"]) + 70.0)


static func right_rect() -> Rect2:
	return Rect2(right_x(), TOP, T["layout"]["right_w"], FRAME_H)


## Заголовок последней построенной сетки (build_grid отдаёт только ячейки)
static var last_grid_title: Label
static var last_chips_y := 0.0

## Рамка сетки, заголовок, ячейки; возвращает экранные прямоугольники ячеек
static func build_grid(lbl, root: Control, title: String, top_extra := 0.0) -> Array:
	var f := build_frame(root, Rect2(grid_x(), TOP, T["layout"]["grid_w"], FRAME_H), null)
	var hdr: Label = lbl._make_label(title, 24)
	hdr.add_theme_color_override("font_color", GOLD)
	var ty: float = f.position.y + T["layout"]["title_dy"]
	hdr.position = Vector2(f.position.x, ty)
	hdr.size = Vector2(f.size.x, 32)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hdr)
	last_grid_title = hdr
	divider(root, f.position.x + 40, f.size.x - 80, ty + 36)
	var cols: int = T["layout"]["cols"]
	var rows: int = T["layout"]["rows"]
	# top_extra — место под строкой фильтров (инвентарь), она встаёт на last_chips_y
	last_chips_y = ty + 66
	var gy := ty + 78 + top_extra
	var area := Rect2(f.position.x + 16, gy, f.size.x - 32, f.end.y - 16 - gy)
	var cw := floorf((area.size.x - CELL_GAP * (cols - 1)) / cols)
	var ch := floorf((area.size.y - CELL_GAP * (rows - 1)) / rows)
	var start := (area.position + (area.size - Vector2(cw * cols + CELL_GAP * (cols - 1), ch * rows + CELL_GAP * (rows - 1))) * 0.5).round()
	var cells := []
	for row in rows:
		for col in cols:
			cells.append(Rect2(start + Vector2(col * (cw + CELL_GAP), row * (ch + CELL_GAP)), Vector2(cw, ch)))
	return cells


func build(ui) -> void:
	use_theme(T)
	_ui = ui
	var root: Control = ui._root
	# Под ним живут окна навыков/настроек и подсказки клавиш
	ui._frame_pos = Vector2(grid_x(), TOP)
	ui._frame_size = Vector2(1920 - grid_x() * 2, FRAME_H)

	# Сетка, карточка и быстрый слот — в одном контейнере: экран талисманов
	# встаёт на их место (build_talismans), вкладки остаются
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_content)
	_build_grid(ui, _content)
	_build_detail(ui, _content)
	_build_quick(ui, _content)
	_build_tabs(ui, root)
	ui._build_hints()


## Экран талисманов — в том же стиле, на месте содержимого инвентаря
## (Inventory/ui/hero_talisman_panel.gd). Пока он открыт, сетка/карточка/
## быстрый слот спрятаны
func build_talismans(ui) -> Control:
	# load, а не preload: окно само подключает этот скрипт
	var p: Control = load("res://Inventory/ui/hero_talisman_panel.gd").new()
	p.skin = self
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visibility_changed.connect(func(): _content.visible = not p.visible)
	p.init(ui._inventory_system, ui._talisman_system, ui._play_ui_sound)
	return p


## Стена трофеев рыцаря (Inventory/ui/trophy_wall.gd) и Гримуар мага
## (Inventory/ui/mage_grimoire.gd) — тоже встают на место содержимого
func build_trophies(ui) -> Control:
	return _content_panel(ui, load("res://Inventory/ui/trophy_wall.gd").new())


func build_grimoire(ui) -> Control:
	return _content_panel(ui, load("res://Inventory/ui/mage_grimoire.gd").new())


## Навыки и настройки — тоже на месте содержимого, в раскладке инвентаря,
## а не отдельными окнами поверх (hero_skills_screen.gd, hero_settings_screen.gd)
func build_skills(ui) -> Control:
	return _content_panel(ui, load("res://Inventory/ui/hero_skills_screen.gd").new())


func build_settings(ui) -> Control:
	return _content_panel(ui, load("res://Inventory/ui/hero_settings_screen.gd").new())


func _content_panel(ui, p: Control) -> Control:
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visibility_changed.connect(func():
		_content.visible = not p.visible
		if not p.visible:
			refresh_side())
	p.call("init", ui)
	return p


# ═════════════════════ Сетка ═════════════════════

func _build_grid(ui, root: Control) -> void:
	var cells := build_grid(ui, root, "ИНВЕНТАРЬ", 52.0)
	_grid_title = last_grid_title
	_build_clean_chips(ui, root, Rect2(grid_x(), last_chips_y - 12, T["layout"]["grid_w"], 48))
	ui._grid_slots.clear()
	for i in cells.size():
		var slot := _grid_slot(ui, i, cells[i])
		root.add_child(slot)
		ui._grid_slots.append(slot)
	# Маленьких ячеек быстрого доступа под сеткой больше нет — колонка справа
	ui._mini_slots.clear()


## Фильтры над сеткой: ВСЁ / категории героя (T.filters) с числом предметов.
## Активный — светлый текст, черта и ромб под ним. В режиме магии строки нет:
## заклинаний мало, фильтровать нечего
var _chips: Array = []
var _chip_row: Control

## Чистый вид: категории значками (Proc.SheetIcon) в ряд по центру; название
## и число — во всплывающей подсказке и в заголовке сетки
func _build_clean_chips(ui, root: Control, r: Rect2) -> void:
	_chips.clear()
	_chip_row = Control.new()
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_row.position = r.position
	_chip_row.size = r.size
	root.add_child(_chip_row)
	var defs: Array = T.get("filters", [["", "Всё", "all"]])
	var w := 72.0
	var x0 := roundf((r.size.x - w * defs.size()) * 0.5)
	for i in defs.size():
		var id: String = defs[i][0]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(x0 + i * w, 0)
		b.size = Vector2(w, r.size.y)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, empty)
		var ic := Proc.SheetIcon.new()
		ic.name = "Indicator"
		ic.icon = CHIP_ICONS.get(defs[i][2] if defs[i].size() > 2 else "all", "chest")
		ic.icon_px = 32
		ic.gold = GOLD
		ic.gold_hi = GOLD_HI
		ic.underline = true
		ic.size = b.size
		b.add_child(ic)
		b.mouse_entered.connect(func(): ic.hover = true)
		b.mouse_exited.connect(func(): ic.hover = false)
		var nb := Side.NewBadge.new()
		nb.name = "NewMark"
		nb.label = ""
		nb.color = GOLD_HI
		nb.position = Vector2(w - 22, -4)
		nb.size = Vector2(20, 20)
		nb.visible = false
		b.add_child(nb)
		b.pressed.connect(func(): ui._set_filter(id))
		_chip_row.add_child(b)
		_chips.append([id, b, defs[i][1], true])
	refresh_chips()


## Ширина надписи шрифтом инвентаря (с засечками, тема _root)
static func _text_w(ui, s: String, font_size: int) -> float:
	var fnt: Font = ui._root.theme.default_font
	# Меряем то, что будет на экране: надписи кнопок переводятся (tr)
	return fnt.get_string_size(TranslationServer.translate(s), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Значки категорий: золотой — выбранный, число предметов — в подсказке,
## метка «новое»; в режиме магии ряда нет
func refresh_chips() -> void:
	if not is_instance_valid(_chip_row):
		return
	_chip_row.visible = not _ui._magic_mode
	for ch in _chips:
		var id: String = ch[0]
		var b: Button = ch[1]
		var n: int = _ui._count_in_category(id)
		b.tooltip_text = ch[2] if id == "" else "%s: %d" % [ch[2], n]
		(b.get_node("Indicator") as Control).set("active", _ui._filter == id)
		(b.get_node("NewMark") as Control).visible = id != "" and _ui._category_has_new(id)


func _grid_slot(ui, idx: int, r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell_plate(c, r.size)

	var frame := make_cell_frame()
	frame.name = "Frame"
	frame.size = r.size
	c.add_child(frame)

	var icon := make_icon()
	icon.name = "Icon"
	icon.position = Vector2(10, 8)
	icon.size = Vector2(r.size.x - 20, r.size.y - 38)
	c.add_child(icon)

	# Подпись — внутри клетки между нижними уголками; длинное название
	# обрезается многоточием, а не с обоих краёв
	var lbl: Label = ui._make_label("", 12)
	lbl.name = "Name"
	lbl.position = Vector2(8, r.size.y - 28)
	lbl.size = Vector2(r.size.x - 16, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	c.add_child(lbl)

	var cnt: Label = ui._make_label("", 15)
	cnt.name = "Count"
	# Левее правого верхнего уголка клетки
	cnt.position = Vector2(r.size.x - 66, 8)
	cnt.size = Vector2(44, 20)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(cnt)

	# Только что полученный предмет — дышащий ромб «НОВОЕ» в левом верхнем
	# углу, пока на ячейку не наведут (inventory_ui._on_slot_hover)
	var nb := Side.NewBadge.new()
	nb.name = "NewMark"
	nb.color = GOLD_HI
	nb.position = Vector2(8, 6)
	nb.size = Vector2(70, 20)
	nb.visible = false
	c.add_child(nb)

	var area := Control.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(func(ev): ui._on_slot_input(ev, idx))
	area.mouse_entered.connect(func(): ui._on_slot_hover(idx, true))
	area.mouse_exited.connect(func(): ui._on_slot_hover(idx, false))
	c.add_child(area)
	return c


func _quick_slot(ui, index: int, r: Rect2) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell_plate(c, r.size)
	var frame := make_cell_frame()
	frame.name = "Frame"
	frame.size = r.size
	c.add_child(frame)
	var icon := make_icon()
	icon.name = "Icon"
	icon.position = Vector2(10, 10)
	icon.size = r.size - Vector2(20, 20)
	c.add_child(icon)
	# Заряды предмета — числом в углу
	var flask := Side.FlaskLevel.new()
	flask.name = "Flask"
	flask.size = r.size
	flask.text_color = TEXT
	flask.glass = Color(GOLD, 0.4)
	c.add_child(flask)
	var num: Label = ui._make_label(str(index + 1), 14)
	num.add_theme_color_override("font_color", GOLD)
	num.position = Vector2(9, 5)
	c.add_child(num)
	var area := Control.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			ui._on_quick_slot_clicked(index))
	c.add_child(area)
	return c


# ═════════════════════ Карточка ═════════════════════

func _build_detail(ui, root: Control) -> void:
	var d := make_detail(ui, root, "При себе", "Макс. за сессию")
	ui._detail_icon_frame = d["icon_box"]
	ui._detail_icon = d["icon"]
	ui._detail_name = d["name"]
	ui._detail_type = d["type"]
	ui._detail_count = d["row1"]
	ui._detail_max_count = d["row2"]
	ui._detail_effect = d["effect"]
	ui._btn_equip = d["button"]
	ui._quick_slot_status = d["status"]
	_lore = d["lore"]
	(d["button"] as Button).pressed.connect(ui._on_equip_pressed)


## Где что в карточке (экранные координаты): панель, иконка в тёмной клетке
## сверху, под ней название, тип, предание; снизу — от кнопки вверх: эффект,
## строка характеристик (две колонки через тонкую черту), разделитель
static func _card_layout(root: Control) -> Dictionary:
	var L := {}
	var f := build_frame(root, Rect2(detail_x(), TOP, T["layout"]["detail_w"], FRAME_H))
	L["icon_center"] = Vector2(f.get_center().x, f.position.y + 176.0)
	L["icon"] = 180.0
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Proc.CleanU.box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.07), 6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(212, 212)
	box.position = (L["icon_center"] - box.size * 0.5).round()
	root.add_child(box)
	var left := f.position.x + 44.0
	var width := f.size.x - 88.0
	L["left"] = left
	L["width"] = width
	var ny: float = L["icon_center"].y + 156.0
	L["name"] = Rect2(left, ny, width, 44)
	L["name_font"] = 34
	L["font"] = 18
	L["type_y"] = ny + 44
	L["lore"] = Rect2(left - 10, ny + 72, width + 20, 78)
	var plate_h := 56.0
	var plate_y: float = f.end.y - 18 - plate_h
	var ey: float = plate_y - 82.0
	var ry: float = ey - 66.0
	L["divider"] = Rect2(f.position.x + 30, ry - 30, f.size.x - 60, 0)
	L["rows_y"] = ry
	L["eff_y"] = ey - 26
	L["eff_h"] = 78.0
	var pw := width + 40.0
	var px: float = round(f.get_center().x - pw * 0.5)
	L["button"] = Rect2(px + 56, plate_y + 8, pw - 112, plate_h - 16)
	return L



## Карточка предмета: иконка, название, тип, предание, две строки
## характеристик, "Эффект" абзацем, кнопка на нарисованной плашке.
## lbl — у кого брать _make_label (inventory_ui или окно талисманов).
## Возвращает узлы по именам
static func make_detail(lbl, root: Control, row1: String, row2: String) -> Dictionary:
	var d := {}
	var L := _card_layout(root)
	var left: float = L["left"]
	var width: float = L["width"]
	var font: int = L["font"]

	# Крупная иконка (свечения нет — золотом горит только выбранное)
	var icon_sz: float = L["icon"]
	var icon_box := Control.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.position = (L["icon_center"] - Vector2(icon_sz, icon_sz) * 0.5).round()
	icon_box.size = Vector2(icon_sz, icon_sz)
	root.add_child(icon_box)
	var icon := make_icon(1.25)
	icon.size = Vector2(icon_sz, icon_sz)
	icon_box.add_child(icon)
	d["icon_box"] = icon_box
	d["icon"] = icon

	var nr: Rect2 = L["name"]
	var name_l: Label = lbl._make_label("", L["name_font"])
	name_l.position = nr.position
	name_l.size = nr.size
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	root.add_child(name_l)
	d["name"] = name_l

	var type_l: Label = lbl._make_label("", font)
	type_l.add_theme_color_override("font_color", TEXT_DIM)
	type_l.position = Vector2(left, L["type_y"])
	type_l.size = Vector2(width, 24)
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(type_l)
	d["type"] = type_l

	# Предание предмета (из каталога магазина) — абзац под названием
	var lr: Rect2 = L["lore"]
	var lore: Label = lbl._make_label("", font)
	lore.add_theme_color_override("font_color", TEXT)
	lore.position = lr.position
	lore.size = lr.size
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.clip_text = true
	root.add_child(lore)
	d["lore"] = lore

	divider(root, L["divider"].position.x, L["divider"].size.x, L["divider"].position.y)
	# Обе характеристики в одну строку, двумя колонками через тонкую черту
	var ry: float = L["rows_y"]
	var half := floorf((width - 40.0) * 0.5)
	d["row1"] = _stat_row(lbl, root, row1, left, half, ry)
	d["row2"] = _stat_row(lbl, root, row2, left + half + 40.0, half, ry)
	var sep := ColorRect.new()
	sep.color = LINE
	sep.position = Vector2(left + half + 20.0, ry + 2)
	sep.size = Vector2(1, 24)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sep)
	hline(root, left - 10, width + 20, ry + 34)

	var ey: float = L["eff_y"]
	var eff_cap: Label = lbl._make_label("Эффект", font + 2)
	eff_cap.add_theme_color_override("font_color", TEXT_DIM)
	eff_cap.position = Vector2(left, ey)
	root.add_child(eff_cap)
	var eff: Label = lbl._make_label("", font)
	eff.position = Vector2(left, ey + 26)
	eff.size = Vector2(width, L["eff_h"])
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.clip_text = true
	root.add_child(eff)
	d["effect"] = eff

	# Кнопка действия — простая плашка с золотистой каймой; при наведении
	# чуть светлеет
	var bp := Panel.new()
	bp.add_theme_stylebox_override("panel", Proc.CleanU.box(Color(0, 0, 0, 0.35), Color(GOLD, 0.35), 4))
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp.position = L["button"].position - Vector2(0, 2)
	bp.size = L["button"].size + Vector2(0, 4)
	root.add_child(bp)
	var br: Rect2 = L["button"]
	var btn := Button.new()
	btn.position = br.position
	btn.size = br.size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", GOLD_HI)
	btn.add_theme_color_override("font_pressed_color", GOLD_HI)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(GOLD_HI, 0.07)
	hover.set_corner_radius_all(3)
	for st in ["normal", "disabled", "focus"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.disabled = true
	root.add_child(btn)
	d["button"] = btn

	# Отказы ("слоты заняты" и т.п.) — строкой под карточкой
	var st_l: Label = lbl._make_label("", 16)
	st_l.add_theme_color_override("font_color", TEXT_DIM)
	st_l.position = Vector2(detail_x(), TOP + FRAME_H + 8)
	st_l.size = Vector2(T["layout"]["detail_w"], 22)
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(st_l)
	d["status"] = st_l
	return d


static func _stat_row(lbl, root: Control, caption: String, x: float, w: float, y: float) -> Label:
	var cap: Label = lbl._make_label(caption, 19)
	cap.add_theme_color_override("font_color", TEXT_DIM)
	cap.position = Vector2(x, y)
	root.add_child(cap)
	var val: Label = lbl._make_label("", 20)
	val.position = Vector2(x, y)
	val.size = Vector2(w, 28)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override("font_color", TEXT)
	root.add_child(val)
	val.set_meta("caption", cap)
	return val


## Предание предмета героя из каталога магазина (одной строкой); "" — нет
static func lore_for(tree: SceneTree, item_name: String) -> String:
	var shop := tree.get_first_node_in_group("shop_menu")
	if shop == null or not shop.has_method(T["lore"]):
		return ""
	for it in shop.call(T["lore"]):
		if it["name"] == item_name:
			# Перевод — до склейки строк: ключ перевода с переносами \n
			return String(TranslationServer.translate(String(it.get("lore", "")))).replace("\n", " ")
	return ""


## Выбран предмет (inventory_ui._select_slot): золотое название, предание,
## эффект сплошным абзацем (в описаниях переносы строк под старую колонку)
func on_select(ab: Ability) -> void:
	if not is_instance_valid(_lore):
		return
	# Смена режима магии/сумки тоже проходит здесь (_set_magic_mode сбрасывает
	# выбор) — заголовок сетки следует за режимом
	if is_instance_valid(_grid_title):
		_grid_title.text = "МАГИЯ" if _ui._magic_mode else "ИНВЕНТАРЬ"
		# Выбранная категория — в заголовке (у значков подписи нет)
		if not _ui._magic_mode and _ui._filter != "":
			for fd in T.get("filters", []):
				if fd[0] == _ui._filter:
					_grid_title.text = _ui.tr("ИНВЕНТАРЬ") + "  ·  " + _ui.tr(String(fd[1])).to_upper()
	refresh_side()
	refresh_new_marks()
	_lore.text = ""
	if ab == null:
		return
	_ui._detail_name.add_theme_color_override("font_color", GOLD)
	_ui._detail_effect.text = _ui.tr(ab.description).replace("\n", " ")
	_lore.text = lore_for(_lore.get_tree(), ab.ability_name)


# ═════════════════════ Быстрый слот ═════════════════════

## Правая колонка: табличка "БЫСТРЫЙ СЛОТ" (у рыцаря в режиме магии —
## "СЛОТЫ МАГИИ", её меняет inventory_ui), три ячейки в ряд, под ними
## "Быстрый доступ N/3", а ниже — живые панели героя:
##   все      — «Сага героя» (статы с бонусами талисманов/трофеев/прокачки);
##   Хальвард — на вкладке «Магия» сагу сменяет алтарь Одра; кнопка
##              «Стена трофеев»;
##   Сигрид   — колчан с заряженными стрелами и действующими навыками;
##   маг      — Сосуд душ и кнопка Гримуара.
## Без типа: вложенные классы preload-константы Godot 4.3 типом не берёт,
## а у Control нет их полей
var _saga
var _quiver
var _altar
var _vessel_label: Label
var _side_buttons: Array[Control] = []

func _build_quick(ui, root: Control) -> void:
	var f := build_frame(root, right_rect(), null)
	ui._quick_col_header = plaque(ui, root, "БЫСТРЫЙ СЛОТ", f.position.x, f.size.x, f.position.y + T["layout"]["title_dy"])
	var top := f.position.y + column_top()
	var gap := 12.0
	var sz := floorf(minf(112.0, (f.size.x - 16.0 - gap * 2.0) / 3.0))
	var row_w := sz * 3.0 + gap * 2.0
	var x0 := roundf(f.get_center().x - row_w * 0.5)
	ui._big_slots.clear()
	for i in AbilitySystem.MAX_SLOTS:
		var s := _quick_slot(ui, i, Rect2(x0 + i * (sz + gap), top, sz, sz))
		root.add_child(s)
		ui._big_slots.append(s)
	var qh: Label = ui._make_label("", 15)
	qh.add_theme_color_override("font_color", TEXT_DIM)
	qh.position = Vector2(f.position.x, top + sz + 6)
	qh.size = Vector2(f.size.x, 22)
	qh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(qh)
	ui._quick_slot_header = qh
	var y := top + sz + 34.0
	divider(root, f.position.x + 20, f.size.x - 40, y)
	y += 30.0

	var side := Rect2(f.position.x + 12, y, f.size.x - 24, f.end.y - 12 - y)
	_saga = Side.SagaPanel.new()
	_saga.gold = GOLD
	_saga.text = TEXT
	_saga.text_dim = TEXT_DIM
	_saga.line = LINE
	_saga.position = side.position
	_saga.refresh(ui._player)
	_saga.size = Vector2(side.size.x, _saga.needed_height())
	root.add_child(_saga)
	# У рыцаря на месте саги бывает алтарь Одра — он выше, кнопка трофеев под ним
	var cid = ui._player.get("character_id") if ui._player else null
	var knight: bool = cid != "archer" and cid != "mage"
	var side_h: float = maxf(_saga.size.y, 312.0) if knight else _saga.size.y
	var below: float = side.position.y + side_h + 10.0
	match cid:
		"archer":
			divider(root, f.position.x + 20, f.size.x - 40, below)
			var qt := _side_title(ui, root, "КОЛЧАН", side.position.x, side.size.x, below + 44)
			_quiver = Side.QuiverView.new()
			_quiver.gold = GOLD
			_quiver.text = TEXT
			_quiver.text_dim = TEXT_DIM
			_quiver.line = LINE
			_quiver.position = Vector2(side.position.x, qt + 6)
			_quiver.size = Vector2(side.size.x, side.end.y - qt - 6)
			root.add_child(_quiver)
		"mage":
			divider(root, f.position.x + 20, f.size.x - 40, below)
			var vt := _side_title(ui, root, "СОСУД ДУШ", side.position.x, side.size.x, below + 44)
			_vessel_label = ui._make_label("", 15)
			_vessel_label.add_theme_color_override("font_color", TEXT)
			_vessel_label.position = Vector2(side.position.x, vt + 6)
			_vessel_label.size = Vector2(side.size.x, 50)
			_vessel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_vessel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			root.add_child(_vessel_label)
			_side_button(ui, root, "[G]   ОТКРЫТЬ ГРИМУАР", Rect2(side.position.x + 10, vt + 64, side.size.x - 20, 44),
					func(): ui._on_tab_pressed(ui.TAB_GRIMOIRE))
		_:
			# Рыцарь: алтарь Одра — на месте саги, пока открыта вкладка «Магия»
			_altar = Side.AltarView.new()
			_altar.gold = GOLD
			_altar.text = TEXT
			_altar.text_dim = TEXT_DIM
			_altar.line = LINE
			_altar.position = side.position
			_altar.size = Vector2(side.size.x, side_h)
			_altar.visible = false
			root.add_child(_altar)
			_side_button(ui, root, "[T]   СТЕНА ТРОФЕЕВ", Rect2(side.position.x + 10, below + 6, side.size.x - 20, 44),
					func(): ui._open_trophies())
	refresh_side()


## Подзаголовок секции правой колонки; возвращает его нижний край
func _side_title(ui, root: Control, text: String, x: float, w: float, y: float) -> float:
	var l: Label = ui._make_label(text, 17)
	l.add_theme_color_override("font_color", GOLD)
	l.position = Vector2(x, y - 12)
	l.size = Vector2(w, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return y + 12.0


## Кнопка в правой колонке: тонкая рамка темы, при наведении светлеет
func _side_button(ui, root: Control, text: String, r: Rect2, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD_HI)
	b.add_theme_color_override("font_pressed_color", GOLD_HI)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45) if st == "normal" else Color(GOLD_HI, 0.08)
		sb.border_color = Color(GOLD, 0.45 if st == "normal" else 0.85)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		ui._play_ui_sound(ui.SOUND_ACCEPT)
		on_press.call())
	root.add_child(b)
	_side_buttons.append(b)
	return b


## Перерисовать живые панели (открытие инвентаря, выбор, смена вкладки)
func refresh_side() -> void:
	var p: Node = _ui._player if _ui else null
	if is_instance_valid(_saga):
		_saga.refresh(p)
	if is_instance_valid(_quiver):
		_quiver.refresh(p)
	if is_instance_valid(_altar):
		var magic_mode: bool = _ui._magic_mode
		_altar.visible = magic_mode
		_saga.visible = not magic_mode
		if magic_mode:
			_altar.refresh(p)
	if is_instance_valid(_vessel_label) and p != null:
		var lvl := int(p.get("vessel_level"))
		var pips := ""
		for i in p.VESSEL_PRICES.size():
			pips += "◆ " if i < lvl else "◇ "
		_vessel_label.text = _ui.tr("%s  ·  %d душ\nПрокачка заклинаний — в Гримуаре") % [pips.strip_edges(), int(p.get("souls"))]
	_refresh_flasks()


## Заряды предмета в быстрых слотах — числом в углу (в режиме магии — пусто)
func _refresh_flasks() -> void:
	var slots: AbilitySystem = _ui._ability_system
	for i in _ui._big_slots.size():
		var fl = (_ui._big_slots[i] as Control).get_node_or_null("Flask")
		if fl == null:
			continue
		var ab: Ability = slots.abilities[i] if slots and i < slots.abilities.size() else null
		fl.bottle = false
		fl.level = 0.0
		if ab == null or _ui._magic_mode:
			fl.text = ""
			continue
		fl.text = "%d" % _ui._bag_inventory.get_count(ab.ability_name)


# ═════════════════════ Вкладки ═════════════════════

func _build_tabs(ui, root: Control) -> void:
	# id вкладок — как TAB_* в inventory_ui.gd; "МАГИЯ" — у кого есть книга
	# заклинаний (рыцарь)
	var defs := [["ИНВЕНТАРЬ", 0], ["НАВЫКИ", 1], ["ТАЛИСМАНЫ", 2], ["НАСТРОЙКИ", 3]]
	if ui._magic_inventory != null:
		defs.insert(1, ["МАГИЯ", 4])
	# Гримуар мага — заклинания и их прокачка за души (mage_grimoire.gd)
	if ui._player != null and ui._player.get("character_id") == "mage":
		defs.insert(1, ["ГРИМУАР", ui.TAB_GRIMOIRE])
	# Полоса — тёмная полупрозрачная плашка, ширина делится на вкладки
	var tb: Dictionary = T["tabs"]
	var bar := Proc.ProcTabBar.new()
	bar.pal = T["pal"]
	bar.count = defs.size()
	var width: float = tb["width"]
	bar.size = Vector2(width, tb["h"])
	bar.position = Vector2(round((1920 - width) * 0.5), tb["y"])
	root.add_child(bar)
	var rects := bar.seg_rects()
	var ty: Vector2 = tb["text_y"]
	var screen_rects := []
	for i in defs.size():
		var seg: Rect2 = rects[1 + i * 2]
		screen_rects.append(Rect2(bar.position + Vector2(seg.position.x, ty.x), Vector2(seg.size.x, ty.y - ty.x)))
	_tab_buttons(ui, root, defs, screen_rects)


## Кнопки вкладок поверх полосы (rects — экранные прямоугольники надписей)
func _tab_buttons(ui, root: Control, defs: Array, rects: Array) -> void:
	ui._tab_ids.clear()
	ui._tab_buttons.clear()
	# Значок слева от надписи, пара — по центру сегмента. Если самая длинная
	# надпись не влезает (5 вкладок), шрифт меньше — у всех вкладок одинаково
	var ic_px := 30
	var gap := 8.0
	var fs := 22
	for i in defs.size():
		while fs > 16 and ic_px + gap + _text_w(ui, defs[i][0], fs) > rects[i].size.x - 10:
			fs -= 1
	for i in defs.size():
		var p: Vector2 = rects[i].position
		var sz: Vector2 = rects[i].size
		var btn := Button.new()
		btn.text = defs[i][0]
		btn.position = p
		btn.size = sz
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tw := _text_w(ui, btn.text, fs)
		btn.add_theme_font_size_override("font_size", fs)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = ic_px + gap
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, empty)
		# Цвет надписи ведёт значок — тот же плавный переход
		var ic := Proc.SheetIcon.new()
		ic.name = "NavIcon"
		ic.icon = TAB_ICONS.get(defs[i][1], "bag")
		ic.icon_px = ic_px
		ic.gold = GOLD
		ic.gold_hi = GOLD_HI
		ic.text_dim = TEXT_DIM
		ic.label_button = btn
		ic.size = Vector2(ic_px + 12, ic_px + 12)
		ic.position = Vector2(roundf((sz.x - ic_px - gap - tw) * 0.5) - 6, roundf(sz.y * 0.5 - ic.size.y * 0.5) - 1)
		btn.add_child(ic)
		btn.mouse_entered.connect(func(): ic.hover = true)
		btn.mouse_exited.connect(func(): ic.hover = false)
		# Активная вкладка: золотистый текст, тёплое свечение по сегменту и
		# черта под надписью
		var ind := Control.new()
		ind.name = "Indicator"
		ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind.size = sz
		ind.show_behind_parent = true
		ind.draw.connect(func():
			for k in 6:
				ind.draw_rect(Rect2(Vector2.ZERO, sz).grow(-k * 3.0), Color(GOLD_HI, 0.035))
			ind.draw_line(Vector2(round(sz.x * 0.2), sz.y - 7), Vector2(round(sz.x * 0.8), sz.y - 7), Color(GOLD_HI, 0.75), 1.0))
		btn.add_child(ind)
		# Неосмотренная находка в этом разделе — дышащий ромб у надписи
		var nb := Side.NewBadge.new()
		nb.name = "NewMark"
		nb.label = ""
		nb.color = GOLD_HI
		nb.position = Vector2(roundf((sz.x + ic_px + gap + tw) * 0.5) - 2, sz.y * 0.5 - 22)
		nb.size = Vector2(20, 20)
		nb.visible = false
		btn.add_child(nb)
		var tab_id: int = defs[i][1]
		btn.pressed.connect(func(): ui._on_tab_pressed(tab_id))
		root.add_child(btn)
		ui._tab_buttons.append(btn)
		ui._tab_ids.append(tab_id)
	ui._update_tab_visuals()


## Ромбы «новое» на вкладках Инвентарь / Магия и на фильтрах
func refresh_new_marks() -> void:
	for i in _ui._tab_buttons.size():
		var nb := (_ui._tab_buttons[i] as Control).get_node_or_null("NewMark") as Control
		if nb == null:
			continue
		var id: int = _ui._tab_ids[i]
		nb.visible = (id == _ui.TAB_INVENTORY and not _ui._new_items.is_empty()) \
				or (id == _ui.TAB_MAGIC and not _ui._new_spells.is_empty())
	refresh_chips()


# ═════════════════════ Сборные детали ═════════════════════

## Тонкая черта, растворяющаяся к концам
class FadeLine extends Control:
	var color := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var c0 := Color(color, 0.0)
		draw_polyline_colors(PackedVector2Array([Vector2(0, 0.5), Vector2(w * 0.18, 0.5), Vector2(w * 0.82, 0.5), Vector2(w, 0.5)]),
				PackedColorArray([c0, color, color, c0]), 1.0)


## Подсветка поверх клетки: выбранная/наведённая — золотая кромка и мягкий
## ореол внутрь (наведённая — вполсилы). Поля highlight/show_cross — как у
## OrnateFrame (их ставит inventory_ui.gd)
class HeroCell extends Control:
	var highlight := 0.0:
		set(v):
			highlight = v
			queue_redraw()
	var show_cross := false
	var thin := false
	## Цвет подсветки — GOLD_HI темы (ставит make_cell_frame)
	var gold := Color(1.0, 0.8, 0.45)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if highlight <= 0.0:
			return
		var r := Rect2(Vector2.ZERO, size)
		for k in 6:
			draw_rect(r.grow(-2.0 - k * 2.0), Color(gold, 0.045 * highlight), false, 2.0)
		draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), Color(gold, 0.85 * highlight), false, 1.0)
		draw_rect(r.grow(-3.0), Color(gold, 0.05 * highlight))
