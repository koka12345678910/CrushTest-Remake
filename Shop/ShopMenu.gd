extends Control

# =============================================================================
# НАСТРОЙКА ИКОНОК — МЕНЯЙ ТОЛЬКО ЗДЕСЬ
# =============================================================================
#
# Положи свои PNG файлы в папку res://icons/ внутри проекта.
# Затем укажи путь к файлу в поле "icon" каждого предмета ниже.
#
# Пример структуры папок:
#   res://
#   ├── ShopMenu.gd
#   ├── ShopMenu.tscn
#   └── icons/
#       ├── gourd.png
#       ├── sword.png
#       ├── scroll.png
#       └── ...
#
# Если иконка не найдена — автоматически рисуется заглушка с первой буквой.
# =============================================================================

var items: Array[Dictionary] = []

func _build_items() -> void:
	items = [
		{
			"name": "Лечебная Тыква",
			"price": 500,
			"icon": "res://icons/gourd.png",       # ← ПУТЬ К ТВОЕМУ PNG
			"description": "Восстанавливает здоровье.\nМожно использовать до 5 раз\nперед отдыхом у Скульптуры.",
			"lore": "Тыквенная бутыль, наполненная\nцелительным эликсиром. Говорят,\nчто настоящий синоби никогда\nне расстаётся с такой флягой.",
			"col": Color(0.4, 0.8, 0.3),
			"texture": null
		},
		{
			"name": "Связка Сена",
			"price": 300,
			"icon": "res://icons/pouch.png",
			"description": "Монеты для торговли.\nОсновная валюта торговцев\nв Асина.",
			"lore": "Пучок рисовой соломы,\nперевязанный верёвкой. Принято\nв качестве оплаты по всей\nстране.",
			"col": Color(0.9, 0.75, 0.2),
			"texture": null
		},
		{
			"name": "Свиток Синоби",
			"price": 1200,
			"icon": "res://icons/scroll.png",
			"description": "Открывает новый боевой\nприём. Требует изучения\nу Скульптора.",
			"lore": "Пожелтевший свиток с\nтехниками ниндзя. Написан\nкровью мастеров прошлого,\nпередавших знания потомкам.",
			"col": Color(0.6, 0.4, 0.9),
			"texture": null
		},
		{
			"name": "Масляный Эликсир",
			"price": 450,
			"icon": "res://icons/flask.png",
			"description": "Увеличивает урон огнём.\nДействует в течение одного\nбоя.",
			"lore": "Густое масло, вспыхивающее\nпри контакте с огнём.\nИзлюбленное средство\nпиротехников Асина.",
			"col": Color(0.95, 0.55, 0.1),
			"texture": null
		},
		{
			"name": "Колокол Будды",
			"price": 2500,
			"icon": "res://icons/bell.png",
			"description": "Призывает торговца\nиз памяти. Редкий\nпредмет.",
			"lore": "Бронзовый колокол,\nотлитый в старой кузнице.\nЗвук его проникает сквозь\nзавесу между мирами.",
			"col": Color(0.7, 0.85, 0.95),
			"texture": null
		},
		{
			"name": "Уголь Духа",
			"price": 800,
			"icon": "res://icons/ember.png",
			"description": "Усиливает протезу\nСиноби. Один из видов\nредкого топлива.",
			"lore": "Чёрный уголь, тлеющий\nбез огня. Скульптор\nиспользует его для\nзаточки своих инструментов.",
			"col": Color(0.9, 0.3, 0.25),
			"texture": null
		},
		{
			"name": "Маска Памяти",
			"price": 3500,
			"icon": "res://icons/mask.png",
			"description": "Позволяет заглянуть\nв прошлое. Используется\nодин раз.",
			"lore": "Белая маска из дерева\nхиноки. Надевший её\nвидит то, что хотел\nзабыть больше всего.",
			"col": Color(0.85, 0.85, 0.9),
			"texture": null
		},
		{
			"name": "Клинок Синоби",
			"price": 1800,
			"icon": "res://icons/sword.png",
			"description": "Основное оружие синоби.\nОстрый и лёгкий. Баланс\nсмерти и ремесла.",
			"lore": "Меч, выкованный\nмастером Дзинзаэмоном\nиз стали горных рудников\nАсина. Никогда не ржавеет.",
			"col": Color(0.75, 0.8, 0.85),
			"texture": null
		},
	]

# ─── STATE ─────────────────────────────────────────────────────────────────────
var hovered_index: int = -1
var selected_index: int = -1
var player_gold: int = 3000
var scroll_offset: float = 0.0
var target_scroll: float = 0.0
var anim_time: float = 0.0

const LEFT_PANEL_W: int = 460
const RIGHT_PANEL_X: int = 500
const ITEM_H: int = 62
const LIST_START_Y: int = 180
const LIST_MARGIN_X: int = 40

var font_default: Font
var font_bold: Font

# ─── LIFECYCLE ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_items()
	_load_textures()
	set_process(true)
	set_process_input(true)
	font_default = ThemeDB.fallback_font
	font_bold    = ThemeDB.fallback_font

# Загружаем все PNG заранее — один раз при старте
func _load_textures() -> void:
	for i: int in items.size():
		var path: String = items[i]["icon"] as String
		if ResourceLoader.exists(path):
			items[i]["texture"] = load(path) as Texture2D
		else:
			items[i]["texture"] = null
			print("ShopMenu: иконка не найдена: ", path)

func _process(delta: float) -> void:
	anim_time     += delta
	scroll_offset  = lerp(scroll_offset, target_scroll, delta * 10.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_click(mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var max_s: float = maxf(0.0, float(items.size() * ITEM_H) - 400.0)
				target_scroll = clampf(target_scroll + 60.0, 0.0, max_s)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				var max_s: float = maxf(0.0, float(items.size() * ITEM_H) - 400.0)
				target_scroll = clampf(target_scroll - 60.0, 0.0, max_s)

func _update_hover(mouse_pos: Vector2) -> void:
	var prev: int = hovered_index
	hovered_index = -1
	for i: int in items.size():
		var iy: float = float(LIST_START_Y) + float(i * ITEM_H) - scroll_offset
		var r := Rect2(float(LIST_MARGIN_X), iy, float(LEFT_PANEL_W - LIST_MARGIN_X * 2), float(ITEM_H - 4))
		if r.has_point(mouse_pos):
			hovered_index = i
			break
	if hovered_index != prev:
		queue_redraw()

func _handle_click(mouse_pos: Vector2) -> void:
	for i: int in items.size():
		var iy: float = float(LIST_START_Y) + float(i * ITEM_H) - scroll_offset
		var r := Rect2(float(LIST_MARGIN_X), iy, float(LEFT_PANEL_W - LIST_MARGIN_X * 2), float(ITEM_H - 4))
		if r.has_point(mouse_pos):
			if player_gold >= (items[i]["price"] as int):
				selected_index = i
	queue_redraw()

# ─── MAIN DRAW ─────────────────────────────────────────────────────────────────
func _draw() -> void:
	var W: float = size.x
	var H: float = size.y

	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.04, 0.03, 0.02))

	# Grain
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i: int in 600:
		draw_rect(Rect2(rng.randf_range(0.0, W), rng.randf_range(0.0, H), 1.0, 1.0),
				Color(1.0, 0.95, 0.8, rng.randf_range(0.01, 0.04)))

	draw_rect(Rect2(0.0, 0.0, float(LEFT_PANEL_W), H), Color(0.06, 0.05, 0.04, 0.95))

	_draw_vertical_divider()
	_draw_right_panel(W, H)
	_draw_header()
	_draw_gold_display()
	_draw_item_list()
	_draw_scrollbar()
	_draw_footer_hint(H)

# ─── DIVIDER ───────────────────────────────────────────────────────────────────
func _draw_vertical_divider() -> void:
	var x: float = float(LEFT_PANEL_W)
	var alphas: Array[float] = [0.06, 0.5, 0.06]
	var offsets: Array[float] = [-1.0, 0.0, 1.0]
	for i: int in 3:
		draw_line(Vector2(x + offsets[i], 0.0), Vector2(x + offsets[i], size.y),
				Color(0.7, 0.6, 0.4, alphas[i]), 1.0)
	for pct: float in [0.25, 0.5, 0.75]:
		var gy: float = size.y * pct
		draw_rect(Rect2(x - 3.0, gy - 3.0, 6.0, 6.0), Color(0.7, 0.6, 0.4, 0.6))
		draw_rect(Rect2(x - 2.0, gy - 2.0, 4.0, 4.0), Color(0.95, 0.88, 0.65, 0.8))

# ─── HEADER ────────────────────────────────────────────────────────────────────
func _draw_header() -> void:
	var pw: float = float(LEFT_PANEL_W)
	draw_rect(Rect2(0.0, 0.0, pw, 2.0), Color(0.7, 0.6, 0.4, 0.8))
	draw_rect(Rect2(0.0, 0.0, pw, 70.0), Color(0.08, 0.06, 0.04))
	var cc := Color(0.7, 0.6, 0.4, 0.5)
	draw_line(Vector2(10.0, 5.0),      Vector2(10.0, 20.0),     cc, 1.5)
	draw_line(Vector2(10.0, 5.0),      Vector2(25.0, 5.0),      cc, 1.5)
	draw_line(Vector2(pw - 10.0, 5.0), Vector2(pw - 10.0, 20.0), cc, 1.5)
	draw_line(Vector2(pw - 10.0, 5.0), Vector2(pw - 25.0, 5.0),  cc, 1.5)
	draw_string(font_bold,    Vector2(pw * 0.5 - 90.0, 32.0), "ТОРГОВЕЦ ЯСУХАРУ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.88, 0.65))
	draw_string(font_default, Vector2(pw * 0.5 - 55.0, 52.0), "— Товары синоби —",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.55, 0.4, 0.8))
	draw_line(Vector2(20.0, 66.0), Vector2(pw - 20.0, 66.0), Color(0.7, 0.6, 0.4, 0.3), 1.0)
	draw_string(font_default, Vector2(float(LIST_MARGIN_X), float(LIST_START_Y) - 14.0),
			"ПРЕДМЕТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.35))
	draw_string(font_default, Vector2(pw - float(LIST_MARGIN_X) - 60.0, float(LIST_START_Y) - 14.0),
			"ЦЕНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.35))
	draw_line(Vector2(float(LIST_MARGIN_X), float(LIST_START_Y) - 6.0),
			  Vector2(pw - float(LIST_MARGIN_X), float(LIST_START_Y) - 6.0),
			  Color(0.7, 0.6, 0.4, 0.2), 1.0)

# ─── GOLD DISPLAY ──────────────────────────────────────────────────────────────
func _draw_gold_display() -> void:
	var gx: float = 20.0
	var gy: float = size.y - 60.0
	draw_rect(Rect2(gx, gy, 220.0, 40.0),       Color(0.08, 0.07, 0.04))
	draw_rect(Rect2(gx, gy, 220.0, 1.0),         Color(0.7, 0.6, 0.4, 0.4))
	draw_rect(Rect2(gx, gy + 39.0, 220.0, 1.0), Color(0.7, 0.6, 0.4, 0.4))
	draw_circle(Vector2(gx + 18.0, gy + 20.0), 10.0, Color(0.8, 0.65, 0.1))
	draw_circle(Vector2(gx + 18.0, gy + 20.0),  7.0, Color(0.95, 0.82, 0.25))
	draw_string(font_default, Vector2(gx + 10.0, gy + 24.0),
			"Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.35, 0.05))
	draw_string(font_bold, Vector2(gx + 36.0, gy + 25.0),
			str(player_gold) + " Sen", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.85, 0.5))

# ─── ITEM LIST ─────────────────────────────────────────────────────────────────
func _draw_item_list() -> void:
	var clip_top: float = float(LIST_START_Y)
	var clip_bot: float = size.y - 80.0
	var pw: float = float(LEFT_PANEL_W)
	var lm: float = float(LIST_MARGIN_X)

	for i: int in items.size():
		var item: Dictionary = items[i]
		var iy: float = float(LIST_START_Y) + float(i * ITEM_H) - scroll_offset
		if iy + float(ITEM_H) < clip_top or iy > clip_bot:
			continue

		var is_hovered:  bool  = (i == hovered_index)
		var is_selected: bool  = (i == selected_index)
		var can_afford:  bool  = (player_gold >= (item["price"] as int))
		var col: Color         = item["col"] as Color

		# Row bg
		var row_rect := Rect2(lm, iy + 1.0, pw - lm * 2.0, float(ITEM_H) - 5.0)
		if is_selected:
			draw_rect(row_rect, Color(col.r * 0.18, col.g * 0.18, col.b * 0.18, 0.9))
			draw_rect(Rect2(lm, iy + 1.0, 3.0, float(ITEM_H) - 5.0), col)
		elif is_hovered:
			draw_rect(row_rect, Color(0.14, 0.11, 0.07, 0.9))
			draw_rect(Rect2(lm, iy + 1.0, 2.0, float(ITEM_H) - 5.0), Color(col.r, col.g, col.b, 0.7))
		else:
			draw_rect(row_rect, Color(0.08, 0.07, 0.05, 0.7))

		draw_line(Vector2(lm, iy + float(ITEM_H) - 4.0),
				  Vector2(pw - lm, iy + float(ITEM_H) - 4.0),
				  Color(0.25, 0.22, 0.16, 0.5), 1.0)

		# ── МИНИ-ИКОНКА (28x28 px, PNG или заглушка) ──
		var icon_size: float = 28.0
		var icon_x: float = lm + 6.0
		var icon_y: float = iy + (float(ITEM_H) - icon_size) * 0.5
		var tex: Texture2D = item["texture"] as Texture2D
		if tex != null:
			var mod: Color = Color(1.0, 1.0, 1.0, 0.6 if (not is_hovered and not is_selected) else 1.0)
			draw_texture_rect(tex, Rect2(icon_x, icon_y, icon_size, icon_size), false, mod)
		else:
			_draw_icon_placeholder(icon_x + icon_size * 0.5, icon_y + icon_size * 0.5,
					icon_size * 0.5, item["name"] as String, col,
					is_hovered or is_selected)

		# Name
		var name_color: Color
		if not can_afford:       name_color = Color(0.4, 0.35, 0.28)
		elif is_selected:        name_color = Color(1.0, 0.95, 0.75)
		elif is_hovered:         name_color = Color(0.95, 0.88, 0.65)
		else:                    name_color = Color(0.75, 0.68, 0.52)

		draw_string(font_bold, Vector2(icon_x + icon_size + 8.0, iy + float(ITEM_H) * 0.5 + 5.0),
				item["name"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, name_color)

		# Price
		var price_color: Color
		if not can_afford:       price_color = Color(0.55, 0.2, 0.15)
		elif is_hovered:         price_color = Color(0.95, 0.82, 0.25)
		else:                    price_color = Color(0.7, 0.6, 0.3)

		var price_str: String = str(item["price"])
		draw_string(font_default,
				Vector2(pw - lm - 10.0 - float(price_str.length()) * 9.0, iy + float(ITEM_H) * 0.5 + 5.0),
				price_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, price_color)

		if not can_afford and (is_hovered or is_selected):
			draw_string(font_default, Vector2(pw - lm - 85.0, iy + float(ITEM_H) * 0.5 - 8.0),
					"Мало Сен", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.25, 0.2, 0.9))

# ─── SCROLLBAR ─────────────────────────────────────────────────────────────────
func _draw_scrollbar() -> void:
	var total_h:   float = float(items.size() * ITEM_H)
	var visible_h: float = size.y - float(LIST_START_Y) - 80.0
	if total_h <= visible_h:
		return
	var bar_x: float = float(LEFT_PANEL_W) - 8.0
	draw_rect(Rect2(bar_x, float(LIST_START_Y), 4.0, visible_h), Color(0.15, 0.13, 0.1))
	var thumb_h: float = maxf(30.0, visible_h * (visible_h / total_h))
	var thumb_y: float = float(LIST_START_Y) + (scroll_offset / (total_h - visible_h)) * (visible_h - thumb_h)
	draw_rect(Rect2(bar_x, thumb_y, 4.0, thumb_h), Color(0.6, 0.52, 0.35, 0.8))

# ─── FOOTER ────────────────────────────────────────────────────────────────────
func _draw_footer_hint(H: float) -> void:
	draw_line(Vector2(float(LIST_MARGIN_X), H - 78.0),
			  Vector2(float(LEFT_PANEL_W - LIST_MARGIN_X), H - 78.0),
			  Color(0.7, 0.6, 0.4, 0.2), 1.0)
	draw_string(font_default, Vector2(float(LIST_MARGIN_X), H - 62.0),
			"[Колесо] Прокрутка    [ЛКМ] Купить",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.4, 0.3))

# ─── RIGHT PANEL ───────────────────────────────────────────────────────────────
func _draw_right_panel(W: float, H: float) -> void:
	var rx: float = float(RIGHT_PANEL_X)
	var pw: float = W - rx

	if hovered_index < 0:
		draw_string(font_default, Vector2(rx + pw * 0.5 - 80.0, H * 0.5),
				"Наведите на предмет", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.35, 0.3, 0.22))
		return

	var item: Dictionary = items[hovered_index]
	var col: Color  = item["col"] as Color
	var pulse: float = (sin(anim_time * 2.5) + 1.0) * 0.5

	# Panel glow
	for gi: int in 5:
		draw_rect(Rect2(rx, float(gi) * 40.0, pw, H - float(gi) * 80.0),
				Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.015 - float(gi) * 0.003))

	draw_rect(Rect2(rx + 30.0, 10.0, pw - 60.0, 2.0), Color(col.r, col.g, col.b, 0.6))

	# ── БОЛЬШАЯ ИКОНКА ──────────────────────────────────────────────────────────
	var icon_cx: float = rx + pw * 0.5
	var icon_cy: float = H * 0.32
	var icon_r: float  = 90.0

	# Внешние кольца пульсации
	for ri: int in 3:
		draw_arc(Vector2(icon_cx, icon_cy), icon_r + 20.0 + float(ri) * 14.0, 0.0, TAU, 64,
				Color(col.r, col.g, col.b, 0.06 - float(ri) * 0.015 + pulse * 0.03), 1.5)

	# Свечение
	for gi: int in 8:
		draw_circle(Vector2(icon_cx, icon_cy), icon_r + float(8 - gi) * 6.0,
				Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.025 * (1.0 + pulse * 0.3)))

	# Круг-подложка
	draw_circle(Vector2(icon_cx, icon_cy), icon_r, Color(0.07, 0.06, 0.04))
	draw_arc(Vector2(icon_cx, icon_cy), icon_r, 0.0, TAU, 64,
			Color(col.r, col.g, col.b, 0.5 + pulse * 0.2), 2.0)
	draw_arc(Vector2(icon_cx, icon_cy), icon_r - 8.0, 0.0, TAU, 64,
			Color(col.r, col.g, col.b, 0.15), 1.0)

	# PNG иконка (большая) — вписываем в квадрат внутри круга
	var big_size: float = icon_r * 1.3   # размер квадрата иконки
	var big_rect := Rect2(icon_cx - big_size * 0.5, icon_cy - big_size * 0.5, big_size, big_size)
	var tex: Texture2D = item["texture"] as Texture2D
	if tex != null:
		draw_texture_rect(tex, big_rect, false)
	else:
		_draw_icon_placeholder(icon_cx, icon_cy, icon_r * 0.6,
				item["name"] as String, col, true)

	# Название
	var name_y: float = icon_cy + icon_r + 38.0
	draw_line(Vector2(rx + 40.0, name_y - 18.0), Vector2(W - 40.0, name_y - 18.0),
			Color(col.r, col.g, col.b, 0.25), 1.0)
	var name_str: String = item["name"] as String
	draw_string(font_bold, Vector2(icon_cx - float(name_str.length()) * 6.5, name_y),
			name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.98, 0.93, 0.75))

	# Цена
	var badge_x: float = icon_cx - 60.0
	var badge_y: float = name_y + 14.0
	draw_rect(Rect2(badge_x, badge_y, 120.0, 28.0), Color(0.1, 0.08, 0.04))
	draw_rect(Rect2(badge_x, badge_y, 120.0, 1.0), Color(col.r, col.g, col.b, 0.5))
	draw_rect(Rect2(badge_x, badge_y + 27.0, 120.0, 1.0), Color(col.r, col.g, col.b, 0.5))
	draw_circle(Vector2(badge_x + 18.0, badge_y + 14.0), 9.0, Color(0.75, 0.6, 0.1))
	draw_circle(Vector2(badge_x + 18.0, badge_y + 14.0), 6.0, Color(0.95, 0.82, 0.25))
	var can_afford: bool = (player_gold >= (item["price"] as int))
	draw_string(font_bold, Vector2(badge_x + 32.0, badge_y + 18.0),
			str(item["price"]) + " Sen", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.95, 0.82, 0.25) if can_afford else Color(0.6, 0.25, 0.2))

	# Описание
	var desc_y: float = name_y + 58.0
	draw_line(Vector2(rx + 40.0, desc_y - 6.0), Vector2(W - 40.0, desc_y - 6.0),
			Color(0.4, 0.35, 0.25, 0.4), 1.0)
	var desc_lines: PackedStringArray = (item["description"] as String).split("\n")
	for li: int in desc_lines.size():
		draw_string(font_default, Vector2(rx + 44.0, desc_y + float(li) * 22.0),
				desc_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.76, 0.62))

	# Лор
	var lore_y: float = desc_y + float(desc_lines.size()) * 22.0 + 24.0
	draw_line(Vector2(rx + 40.0, lore_y - 10.0), Vector2(W - 40.0, lore_y - 10.0),
			Color(0.4, 0.35, 0.25, 0.25), 1.0)
	draw_string(font_default, Vector2(rx + 44.0, lore_y),
			"— Предание —", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.32))
	var lore_lines: PackedStringArray = (item["lore"] as String).split("\n")
	for li: int in lore_lines.size():
		draw_string(font_default, Vector2(rx + 44.0, lore_y + 18.0 + float(li) * 20.0),
				lore_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.55, 0.42))

	draw_rect(Rect2(rx + 30.0, H - 12.0, pw - 60.0, 2.0),
			Color(col.r, col.g, col.b, 0.4 + pulse * 0.15))

# ─── ЗАГЛУШКА (если PNG не найден) ────────────────────────────────────────────
# Рисует круг с первой буквой названия предмета
func _draw_icon_placeholder(cx: float, cy: float, r: float, item_name: String, col: Color, bright: bool) -> void:
	var alpha: float = 1.0 if bright else 0.5
	draw_circle(Vector2(cx, cy), r, Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, alpha))
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 32, Color(col.r, col.g, col.b, alpha), 2.0)
	if item_name.length() > 0:
		var letter: String = item_name.substr(0, 1).to_upper()
		draw_string(font_bold, Vector2(cx - r * 0.3, cy + r * 0.35),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.0),
				Color(col.r, col.g, col.b, alpha))
