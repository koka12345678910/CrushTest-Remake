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

var ability_class_map := {
	"Мёд Поэзии": HoneyMeadAbility,
	"Песнь валькирии": ValkyrieSongAbility,
	"Эликсир Вальгаллы": ValhallaElixirAbility,
	"Руна жертвы": SacrificeRuneAbility,
	"Безумие Берсерка": BerserkAbility,
	"Благословение Бальдра": BaldurBlessingAbility,
	"Глаз Одина": OdinEyeAbility,
	"Кровь Фенрира": FenrirBloodAbility,
}

func _build_items() -> void:
	items = [
		{
			"name": "Мёд Поэзии",
			"price": 50,
			"icon": "res://Shop/icons/jar_honey.png",       # ← ПУТЬ К ТВОЕМУ PNG
			"description": "Постепенно восстанавливает здоровье.",
			"lore": "Старинный напиток, рожденный из шёпота богов\nГоворят, его вкус дарует не только ясность ума, но и силу, что течёт глубже крови.\nНемногие знают, из чего он создан.\nИ ещё меньше — чем приходится за него платить.",
			"col": Color(0.4, 0.8, 0.3),
			"texture": null
		},
		{
			"name": "Песнь валькирии",
			"price": 100,
			"icon": "res://Shop/icons/flask_gold.png",
			"description": "Те, кто слышит её песнь, возвращаются к бою.\nНо не все возвращаются прежними.",
			"lore": "Тихий отголосок битв, что давно затихли.\nСчитается, что в этом сосуде запечатан последний вздох павшей валькирии.",
			"col": Color(0.9, 0.75, 0.2),
			"texture": null
		},
		{
			"name": "Эликсир Вальгаллы",
			"price": 120,
			"icon": "res://Shop/icons/flask_red.png",
			"description": "Тот, кто испьёт его, на мгновение ощущает силу тех, кто уже пал.\nНо даже мимолётный взгляд за порог не проходит бесследно.",
			"lore": "Густой напиток, которым провожают павших воинов.\nГоворят, он пропитан эхом пиршеств из Вальгалла.",
			"col": Color(0.6, 0.4, 0.9),
			"texture": null
		},
		{
			"name": "Руна жертвы",
			"price": 0,
			"icon": "res://Shop/icons/potion_blood.png",
			"description": "Она откликается на боль владельца, возвращая утраченное.\nНо всегда забирает больше, чем было отдано.",
			"lore": "Старинный знак, вырезанный не ради защиты, а ради расплаты.\nКаждая линия на ней — напоминание о цене силы.",
			"col": Color(0.95, 0.55, 0.1),
			"texture": null
		},
		{
			"name": "Безумие Берсерка",
			"price": 0,
			"icon": "res://Shop/icons/blood_pouch.png",
			"description": "С каждым ударом сила растёт.\nНо вместе с ней исчезает и контроль.",
			"lore": "Ярость, в которой теряется грань между человеком и зверем.\nГоворят, те, кто поддаются ей, больше не чувствуют боли.",
			"col": Color(0.7, 0.85, 0.95),
			"texture": null
		},
		{
			"name": "Благословение Бальдра",
			"price": 0,
			"icon": "res://Shop/icons/light_orb.png",
			"description": "Свет, к которому не может прикоснуться ни сталь, ни тьма.\nОн дарует защиту, что кажется абсолютной.",
			"lore": "Но даже самый чистый свет имеет то, что было упущено.\nИ именно через это приходит конец.",
			"col": Color(0.9, 0.3, 0.25),
			"texture": null
		},
		{
			"name": "Глаз Одина",
			"price": 0,
			"icon": "res://Shop/icons/eye_amulet.png",
			"description": "Истина открывается тем, кто осмелится взглянуть.\nНо не каждый разум способен её выдержать.",
			"lore": "Око, отданное в обмен на знание, что недоступно смертным.\nОно видит больше, чем должен видеть человек.",
			"col": Color(0.85, 0.85, 0.9),
			"texture": null
		},
		{
			"name": "Кровь Фенрира",
			"price": 0,
			"icon": "res://Shop/icons/demon_flask.png",
			"description": "Дарует мощь, способную сокрушить всё на пути.\nНо зверь внутри никогда не служит долго.",
			"lore": "Сила зверя, что однажды разорвёт сами оковы мира.\nОна кипит, даже будучи заключённой.",
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

const LEFT_PANEL_W: int = 550
const RIGHT_PANEL_X: int = 590
const ITEM_H: int = 78
const LIST_START_Y: int = 160
const LIST_MARGIN_X: int = 30

var font_default: Font
var font_bold: Font
var current_player: Node2D = null
var pending_buy_index: int = -1

# ─── UI-ЗВУКИ ──────────────────────────────────────────────────────────────────
const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_OPEN := preload("res://Sound/openUI_sound.mp3")
var _ui_audio: AudioStreamPlayer

func _play_ui_sound(stream: AudioStream) -> void:
	_ui_audio.stream = stream
	_ui_audio.play()

# ─── LIFECYCLE ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_items()
	_load_textures()
	set_process(false)       # ← было true, замени на false
	set_process_input(false) # ← было true, замени на false
	var custom_font := load("res://Font/sikandinarie.ttf") as Font
	font_default = custom_font if custom_font else ThemeDB.fallback_font
	font_bold = custom_font if custom_font else ThemeDB.fallback_font
	visible = false

	_ui_audio = AudioStreamPlayer.new()
	add_child(_ui_audio)

func open_shop(player: Node2D) -> void:
	if visible:
		return  # магазин уже открыт — игнорируем повторный вызов
	current_player = player
	player_gold = player.gold
	player.is_in_shop = true
	_play_ui_sound(SOUND_OPEN)

	visible = true
	set_process(true)
	set_process_input(true)
	
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.96, 0.96)
	pivot_offset = size / 2.0
	
	var tw = create_tween().set_parallel()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	_set_level_rain_muffled(true, 0.18)

	queue_redraw()

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_shop()
		get_viewport().set_input_as_handled()  # ← добавь
		return
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

# Приглушаем дождь уровня на время, пока открыт магазин — плавно, за то же
# время, что идёт анимация открытия/закрытия самого окна (см. duration в
# вызовах ниже), как приглушение звука за дверью в Sekiro
func _set_level_rain_muffled(muffled: bool, duration: float) -> void:
	var music_mgr = get_tree().get_first_node_in_group("level_music")
	if music_mgr and music_mgr.has_method("set_shop_open"):
		music_mgr.set_shop_open(muffled, duration)

func close_shop() -> void:
	_play_ui_sound(SOUND_OPEN)
	pivot_offset = size / 2.0
	var tw = create_tween().set_parallel()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.14)
	tw.tween_property(self, "scale", Vector2(0.96, 0.96), 0.14)
	_set_level_rain_muffled(false, 0.14)
	await tw.finished
	if current_player:
		current_player.is_in_shop = false
	visible = false
	set_process(false)
	set_process_input(false)

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

var last_click_time: float = 0.0
var last_click_index: int = -1
const DOUBLE_CLICK_TIME := 0.35

func _handle_click(mouse_pos: Vector2) -> void:
	if pending_buy_index >= 0:
		_handle_confirm_click(mouse_pos)
		return
	
	for i: int in items.size():
		var iy: float = float(LIST_START_Y) + float(i * ITEM_H) - scroll_offset
		var r := Rect2(float(LIST_MARGIN_X), iy, float(LEFT_PANEL_W - LIST_MARGIN_X * 2), float(ITEM_H - 4))
		if r.has_point(mouse_pos):
			var now := Time.get_ticks_msec() / 1000.0
			if i == last_click_index and (now - last_click_time) < DOUBLE_CLICK_TIME:
				_open_confirm(i)
				last_click_index = -1
			else:
				selected_index = i
				last_click_index = i
				last_click_time = now
				_play_ui_sound(SOUND_CHOICE)
			break
	queue_redraw()

func _open_confirm(index: int) -> void:
	var item = items[index]
	if player_gold < (item["price"] as int):
		_play_ui_sound(SOUND_DENIED)
		return  # недостаточно золота — не открываем окно
	pending_buy_index = index
	queue_redraw()

func _handle_confirm_click(mouse_pos: Vector2) -> void:
	var W: float = size.x
	var H: float = size.y
	var box_w := 420.0
	var box_h := 200.0
	var box_x := (W - box_w) * 0.5
	var box_y := (H - box_h) * 0.5
	
	var btn_w := 140.0
	var btn_h := 44.0
	var btn_y := box_y + box_h - 70.0
	var yes_x := box_x + box_w * 0.5 - btn_w - 10.0
	var no_x  := box_x + box_w * 0.5 + 10.0
	
	var yes_rect := Rect2(yes_x, btn_y, btn_w, btn_h)
	var no_rect  := Rect2(no_x, btn_y, btn_w, btn_h)
	
	if yes_rect.has_point(mouse_pos):
		_play_ui_sound(SOUND_ACCEPT)
		_try_buy(pending_buy_index)
		pending_buy_index = -1
	elif no_rect.has_point(mouse_pos):
		pending_buy_index = -1
	queue_redraw()

func _try_buy(index: int) -> void:
	var item = items[index]
	var price: int = item["price"] as int
	
	if player_gold < price:
		return  # недостаточно золота
	
	if not current_player:
		return
	
	var item_name: String = item["name"] as String
	if not ability_class_map.has(item_name):
		print("ShopMenu: нет класса способности для ", item_name)
		return
	
	# списываем золото
	current_player.gold -= price
	player_gold = current_player.gold
	
	# создаём способность и добавляем в инвентарь
	var ability_class = ability_class_map[item_name]
	var ability_instance: Ability = ability_class.new()
	current_player.inventory_ui.add_item(ability_instance)
	
	selected_index = index
	print("Куплено: ", item_name, " за ", price)

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
	if pending_buy_index >= 0:
		_draw_confirm_dialog(W, H)

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
	draw_rect(Rect2(0.0, 0.0, pw, 88.0), Color(0.08, 0.06, 0.04))
	var cc := Color(0.7, 0.6, 0.4, 0.5)
	draw_line(Vector2(10.0, 5.0),      Vector2(10.0, 20.0),     cc, 1.5)
	draw_line(Vector2(10.0, 5.0),      Vector2(25.0, 5.0),      cc, 1.5)
	draw_line(Vector2(pw - 10.0, 5.0), Vector2(pw - 10.0, 20.0), cc, 1.5)
	draw_line(Vector2(pw - 10.0, 5.0), Vector2(pw - 25.0, 5.0),  cc, 1.5)
	draw_string(font_bold, Vector2(pw * 0.5 - 110.0, 38.0), "СБОРЩИК ДУШ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.95, 0.88, 0.65))
	draw_line(Vector2(20.0, 80.0), Vector2(pw - 20.0, 80.0), Color(0.7, 0.6, 0.4, 0.3), 1.0)
	draw_string(font_default, Vector2(float(LIST_MARGIN_X), float(LIST_START_Y) - 12.0),
			"ПРЕДМЕТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.45, 0.35))
	draw_string(font_default, Vector2(pw - float(LIST_MARGIN_X) - 70.0, float(LIST_START_Y) - 12.0),
			"ЦЕНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.45, 0.35))
	draw_line(Vector2(float(LIST_MARGIN_X), float(LIST_START_Y) - 4.0),
			  Vector2(pw - float(LIST_MARGIN_X), float(LIST_START_Y) - 4.0),
			  Color(0.7, 0.6, 0.4, 0.2), 1.0)

# ─── GOLD DISPLAY ──────────────────────────────────────────────────────────────
func _draw_gold_display() -> void:
	var gx: float = 20.0
	var gy: float = size.y - 60.0
	draw_rect(Rect2(gx, gy, 260.0, 48.0),       Color(0.08, 0.07, 0.04))
	draw_rect(Rect2(gx, gy, 260.0, 1.0),         Color(0.7, 0.6, 0.4, 0.4))
	draw_rect(Rect2(gx, gy + 47.0, 260.0, 1.0), Color(0.7, 0.6, 0.4, 0.4))
	draw_circle(Vector2(gx + 22.0, gy + 24.0), 12.0, Color(0.8, 0.65, 0.1))
	draw_circle(Vector2(gx + 22.0, gy + 24.0),  8.0, Color(0.95, 0.82, 0.25))
	draw_string(font_default, Vector2(gx + 13.0, gy + 29.0),
			"Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.35, 0.05))
	draw_string(font_bold, Vector2(gx + 44.0, gy + 30.0),
			str(player_gold) + " Sen", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.85, 0.5))

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

		# ── МИНИ-ИКОНКА (40x40 px, PNG или заглушка) ──
		var icon_size: float = 40.0
		var icon_x: float = lm + 8.0
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

		draw_string(font_bold, Vector2(icon_x + icon_size + 14.0, iy + float(ITEM_H) * 0.5 + 7.0),
				item["name"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, name_color)

		# Price
		var price_color: Color
		if not can_afford:       price_color = Color(0.55, 0.2, 0.15)
		elif is_hovered:         price_color = Color(0.95, 0.82, 0.25)
		else:                    price_color = Color(0.7, 0.6, 0.3)

		var price_str: String = str(item["price"])
		draw_string(font_default,
				Vector2(pw - lm - 10.0 - float(price_str.length()) * 11.0, iy + float(ITEM_H) * 0.5 + 7.0),
				price_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, price_color)

		if not can_afford and (is_hovered or is_selected):
			draw_string(font_default, Vector2(pw - lm - 95.0, iy + float(ITEM_H) * 0.5 - 10.0),
					"Мало Сен", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.25, 0.2, 0.9))

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
	draw_line(Vector2(float(LIST_MARGIN_X), H - 82.0),
			  Vector2(float(LEFT_PANEL_W - LIST_MARGIN_X), H - 82.0),
			  Color(0.7, 0.6, 0.4, 0.2), 1.0)
	draw_string(font_default, Vector2(float(LIST_MARGIN_X), H - 62.0),
			"[Колесо] Прокрутка    [ЛКМ] Купить",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.4, 0.3))

# ─── RIGHT PANEL ───────────────────────────────────────────────────────────────
func _draw_right_panel(W: float, H: float) -> void:
	var rx: float = float(RIGHT_PANEL_X)
	var pw: float = W - rx

	if selected_index < 0:
		draw_string(font_default, Vector2(rx + pw * 0.5 - 80.0, H * 0.5),
				"Выберите предмет", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.35, 0.3, 0.22))
		return

	var item: Dictionary = items[selected_index]
	var col: Color  = item["col"] as Color
	var pulse: float = (sin(anim_time * 2.5) + 1.0) * 0.5

	# Panel glow
	for gi: int in 5:
		draw_rect(Rect2(rx, float(gi) * 40.0, pw, H - float(gi) * 80.0),
				Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.015 - float(gi) * 0.003))

	draw_rect(Rect2(rx + 30.0, 10.0, pw - 60.0, 2.0), Color(col.r, col.g, col.b, 0.6))

	# ── БОЛЬШАЯ ИКОНКА ──────────────────────────────────────────────────────────
	var icon_cx: float = rx + pw * 0.5
	var icon_cy: float = H * 0.28
	var icon_r: float  = 130.0

	# Внешние кольца пульсации
	#for ri: int in 3:
	#	draw_arc(Vector2(icon_cx, icon_cy), icon_r + 20.0 + float(ri) * 14.0, 0.0, TAU, 64,
	#			Color(col.r, col.g, col.b, 0.06 - float(ri) * 0.015 + pulse * 0.03), 1.5)

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

	# PNG иконка — обрезанная по кругу через треугольники
	var tex: Texture2D = item["texture"] as Texture2D
	print("рисуем иконку, tex=", tex, " icon_cx=", icon_cx, " icon_cy=", icon_cy, " icon_r=", icon_r)
	if tex != null:
		var segments: int = 64
		var verts := PackedVector2Array()
		var uvs   := PackedVector2Array()
		# Точки по окружности
		for si: int in segments + 1:
			var angle: float = float(si) / float(segments) * TAU
			verts.append(Vector2(icon_cx + cos(angle) * icon_r, icon_cy + sin(angle) * icon_r))
			uvs.append(Vector2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5))
		# Центр
		verts.append(Vector2(icon_cx, icon_cy))
		uvs.append(Vector2(0.5, 0.5))
		# Рисуем треугольники от центра к краям
		for si: int in segments:
			draw_primitive(
				PackedVector2Array([verts[segments], verts[si], verts[si + 1]]),
				PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]),
				PackedVector2Array([uvs[segments],  uvs[si],  uvs[si + 1]]),
				tex
			)
	else:
		_draw_icon_placeholder(icon_cx, icon_cy, icon_r * 0.6,
				item["name"] as String, col, true)

	# Название
	var name_y: float = icon_cy + icon_r + 48.0
	draw_line(Vector2(rx + 40.0, name_y - 22.0), Vector2(W - 40.0, name_y - 22.0),
			Color(col.r, col.g, col.b, 0.25), 1.0)
	var name_str: String = item["name"] as String
	draw_string(font_bold, Vector2(icon_cx - float(name_str.length()) * 8.0, name_y),
			name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.98, 0.93, 0.75))

	# Цена
	var badge_x: float = icon_cx - 80.0
	var badge_y: float = name_y + 18.0
	draw_rect(Rect2(badge_x, badge_y, 160.0, 36.0), Color(0.1, 0.08, 0.04))
	draw_rect(Rect2(badge_x, badge_y, 160.0, 1.0), Color(col.r, col.g, col.b, 0.5))
	draw_rect(Rect2(badge_x, badge_y + 35.0, 160.0, 1.0), Color(col.r, col.g, col.b, 0.5))
	draw_circle(Vector2(badge_x + 22.0, badge_y + 18.0), 12.0, Color(0.75, 0.6, 0.1))
	draw_circle(Vector2(badge_x + 22.0, badge_y + 18.0),  8.0, Color(0.95, 0.82, 0.25))
	var can_afford: bool = (player_gold >= (item["price"] as int))
	draw_string(font_bold, Vector2(badge_x + 42.0, badge_y + 23.0),
			str(item["price"]) + " Sen", HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			Color(0.95, 0.82, 0.25) if can_afford else Color(0.6, 0.25, 0.2))

	# Описание
	var desc_y: float = name_y + 72.0
	draw_line(Vector2(rx + 40.0, desc_y - 8.0), Vector2(W - 40.0, desc_y - 8.0),
			Color(0.4, 0.35, 0.25, 0.4), 1.0)
	var desc_lines: PackedStringArray = (item["description"] as String).split("\n")
	for li: int in desc_lines.size():
		draw_string(font_default, Vector2(rx + 50.0, desc_y + float(li) * 26.0),
				desc_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.82, 0.76, 0.62))

	# Лор
	var lore_y: float = desc_y + float(desc_lines.size()) * 26.0 + 30.0
	draw_line(Vector2(rx + 40.0, lore_y - 12.0), Vector2(W - 40.0, lore_y - 12.0),
			Color(0.4, 0.35, 0.25, 0.25), 1.0)
	draw_string(font_default, Vector2(rx + 50.0, lore_y),
			"— Предание —", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.5, 0.45, 0.32))
	var lore_lines: PackedStringArray = (item["lore"] as String).split("\n")
	for li: int in lore_lines.size():
		draw_string(font_default, Vector2(rx + 50.0, lore_y + 26.0 + float(li) * 24.0),
				lore_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.55, 0.42))

	draw_rect(Rect2(rx + 30.0, H - 12.0, pw - 60.0, 2.0),
			Color(col.r, col.g, col.b, 0.4 + pulse * 0.15))

func _draw_confirm_dialog(W: float, H: float) -> void:
	# затемнение всего фона
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.0, 0.0, 0.0, 0.6))
	
	var item = items[pending_buy_index]
	var col: Color = item["col"] as Color
	
	var box_w := 420.0
	var box_h := 200.0
	var box_x := (W - box_w) * 0.5
	var box_y := (H - box_h) * 0.5
	
	draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0.08, 0.07, 0.05, 0.98))
	draw_rect(Rect2(box_x, box_y, box_w, 2.0), Color(col.r, col.g, col.b, 0.7))
	draw_rect(Rect2(box_x, box_y + box_h - 2.0, box_w, 2.0), Color(col.r, col.g, col.b, 0.7))
	draw_rect(Rect2(box_x, box_y, 2.0, box_h), Color(col.r, col.g, col.b, 0.4))
	draw_rect(Rect2(box_x + box_w - 2.0, box_y, 2.0, box_h), Color(col.r, col.g, col.b, 0.4))
	
	var item_name: String = item["name"] as String
	var msg := "Купить «" + item_name + "» за " + str(item["price"]) + " Sen?"
	draw_string(font_default, Vector2(box_x + 30.0, box_y + 50.0),
			msg, HORIZONTAL_ALIGNMENT_LEFT, int(box_w - 60.0), 17, Color(0.92, 0.86, 0.7))
	
	var btn_w := 140.0
	var btn_h := 44.0
	var btn_y := box_y + box_h - 70.0
	var yes_x := box_x + box_w * 0.5 - btn_w - 10.0
	var no_x  := box_x + box_w * 0.5 + 10.0
	
	# Кнопка ДА
	draw_rect(Rect2(yes_x, btn_y, btn_w, btn_h), Color(0.15, 0.25, 0.1))
	draw_rect(Rect2(yes_x, btn_y, btn_w, 1.0), Color(0.4, 0.8, 0.3, 0.8))
	draw_string(font_bold, Vector2(yes_x + btn_w * 0.5 - 20.0, btn_y + btn_h * 0.5 + 6.0),
			"Да", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.95, 0.5))
	
	# Кнопка НЕТ
	draw_rect(Rect2(no_x, btn_y, btn_w, btn_h), Color(0.25, 0.1, 0.1))
	draw_rect(Rect2(no_x, btn_y, btn_w, 1.0), Color(0.8, 0.3, 0.3, 0.8))
	draw_string(font_bold, Vector2(no_x + btn_w * 0.5 - 22.0, btn_y + btn_h * 0.5 + 6.0),
			"Нет", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.5, 0.5))	

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
