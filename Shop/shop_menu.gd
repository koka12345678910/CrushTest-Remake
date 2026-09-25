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
	# Лучница
	"Выстрел Валькирии": ValkyrieShotAbility,
	"Коготь Фенрира": FenrirClawAbility,
	"Шёпот Одина": OdinWhisperAbility,
	"Танец Валькирии": ValkyrieDanceAbility,
	"Кровавое Перо": BloodyFeatherAbility,
	"Последний взор": LastLookAbility,
	"Путь охотницы": HuntressPathAbility,
	"Перо Хугина": HuginnFeatherAbility,
	"Игла Норн": NornNeedleAbility,
}

func _knight_items() -> Array:
	return [
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
			"price": 0,
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


# Товары лучницы. "subtitle" — принадлежность и тип под названием, "max" —
# сколько штук можно держать в сумке (талисман — один, второй не продаём)
func _archer_items() -> Array:
	return [
		{
			"name": "Выстрел Валькирии",
			"subtitle": "Валькирии  •  Боевой навык",
			"price": 60,
			"max": 3,
			"icon": "res://UI/icons_for_sigrid/valkyrie's_shot.png",
			"description": "Следующий выстрел срывается с тетивы мгновенно,\nлетит почти вдвое быстрее и наносит +1 урона.",
			"lore": "Стрела, которой Валькирии отмечали достойных павших.\nВыпущенная с силой, она находит цель прежде,\nчем та успевает заметить смерть.",
			"col": Color(1.0, 0.82, 0.35),
			"texture": null
		},
		{
			"name": "Коготь Фенрира",
			"subtitle": "Фенрир  •  Боевой навык",
			"price": 80,
			"max": 3,
			"icon": "res://UI/icons_for_sigrid/fenrir's_claw.png",
			"description": "Следующие 3 стрелы пробивают первого врага\nи поражают того, кто стоит за ним.",
			"lore": "Говорят, ни одна цепь не могла удержать зверя вечно.\nТак и эта стрела не знает преград.",
			"col": Color(0.85, 0.25, 0.2),
			"texture": null
		},
		{
			"name": "Шёпот Одина",
			"subtitle": "Один  •  Боевой навык",
			"price": 80,
			"max": 3,
			"icon": "res://UI/icons_for_sigrid/odin's_whisper.png",
			"description": "Следующие 3 стрелы проходят сквозь препятствия\nи поражают врага за ними.",
			"lore": "Одину не нужны были глаза, чтобы знать всё происходящее.\nГоворят, его шёпот достигал даже тех мест,\nкуда не мог добраться человек.",
			"col": Color(0.45, 0.7, 1.0),
			"texture": null
		},
		{
			"name": "Танец Валькирии",
			"subtitle": "Валькирии  •  Боевой навык",
			"price": 90,
			"max": 3,
			"icon": "res://UI/icons_for_sigrid/valkyrie_dance.png",
			"description": "12 сек: после каждого переката следующий выстрел\nусилен — он всегда критический.",
			"lore": "Валькирия не стоит перед смертью.\nОна движется вместе с ней.",
			"col": Color(0.9, 0.85, 1.0),
			"texture": null
		},
		{
			"name": "Кровавое Перо",
			"subtitle": "Валькирии  •  Боевой навык",
			"price": 100,
			"max": 3,
			"icon": "res://UI/icons_for_sigrid/bloody_feather.png",
			"description": "20 сек: критическое попадание накладывает\nкровотечение — 3 урона за 3 секунды.",
			"lore": "Перо Валькирии чернеет лишь после того,\nкак принимает кровь павшего.\nЧем глубже рана, тем тяжелее становится следующий удар.",
			"col": Color(0.8, 0.1, 0.1),
			"texture": null
		},
		{
			"name": "Последний взор",
			"subtitle": "Один  •  Временная способность",
			"price": 150,
			"max": 2,
			"icon": "res://UI/icons_for_sigrid/last_look.png",
			"description": "8 сек: стрельба вдвое быстрее, стрелы доворачивают\nв цель, +1 урона и +15% шанса крита.",
			"lore": "Один отдал глаз ради знания, недоступного смертным.\nНа мгновение охотница видит то,\nчто обычно скрыто от человеческого взгляда.",
			"col": Color(1.0, 0.7, 0.25),
			"texture": null
		},
		{
			"name": "Путь охотницы",
			"subtitle": "Скади, древние охотницы  •  Временная способность",
			"price": 140,
			"max": 2,
			"icon": "res://UI/icons_for_sigrid/path_of_the_huntress.png",
			"description": "12 сек: цель в фокусе (или первая поражённая)\nстановится добычей. Каждое попадание по ней\nусиливает следующее — до +2 урона.",
			"lore": "Охотница не спешит за добычей.\nОна следует её следу, пока тот не приведёт к смерти.",
			"col": Color(0.95, 0.35, 0.15),
			"texture": null
		},
		{
			"name": "Перо Хугина",
			"subtitle": "Один  •  Талисман, пассивный",
			"price": 250,
			"max": 1,
			"icon": "res://UI/icons_for_sigrid/odin's_raven.png",
			"description": "Каждое попадание метит врага на 5 сек. Лук сам\nнаводится на помеченных, даже издалека.\nДобыча Пути охотницы под меткой копит силу вдвое быстрее.",
			"lore": "Хугин летал над девятью мирами и приносил Одину вести\nо том, чего тот не видел сам.\nНи одна цель не должна оставаться незамеченной.",
			"col": Color(0.6, 0.8, 1.0),
			"texture": null
		},
		{
			"name": "Игла Норн",
			"subtitle": "Норны  •  Талисман, пассивный",
			"price": 250,
			"max": 1,
			"icon": "res://UI/icons_for_sigrid/norn's_needle.png",
			"description": "+20% шанса критического попадания по врагам,\nкоторых лучница уже поражала.",
			"lore": "Норны плетут нити судьбы, которым не способен\nпротивиться даже бог.\nИногда достаточно одной нити, чтобы изменить исход битвы.",
			"col": Color(0.85, 0.8, 0.65),
			"texture": null
		},
	]


## Каталог по классу покупателя. У лучницы есть character_id, у рыцаря нет
func _build_items_for(player: Node) -> void:
	var cid = player.get("character_id") if player else null
	if cid == "archer":
		items.assign(_archer_items())
	else:
		items.assign(_knight_items())
	_load_textures()
	selected_index = -1
	hovered_index = -1
	scroll_offset = 0.0
	target_scroll = 0.0


# ─── STATE ─────────────────────────────────────────────────────────────────────
var hovered_index: int = -1
var selected_index: int = -1
var player_gold: int = 3000
var scroll_offset: float = 0.0
var target_scroll: float = 0.0
var anim_time: float = 0.0

var font_title: Font   # заголовки
var font_body: Font    # описания/цены — засечки с нормальными цифрами
var current_player: Node2D = null
var pending_buy_index: int = -1

# Кнопка "[E] Купить" и кнопки подтверждения под курсором
var _buy_hover := false
var _confirm_hover := -1   # 0 — Да, 1 — Нет
# Момент открытия — та же E, что открыла магазин (interact в shop_trigger.gd),
# не должна тут же нажать "Купить"
var _opened_at := 0.0
var _vignette: Texture2D
var _glow: Texture2D

# ─── ВЁРСТКА ───────────────────────────────────────────────────────────────────
# Всё в координатах макета 1920×1080. _draw() масштабирует их под реальный
# размер окна (_view_scale/_view_offset), мышь пересчитывается обратно
const DESIGN := Vector2(1920, 1080)
const LEFT_PANEL := Rect2(34, 110, 590, 925)
const BANNER := Rect2(64, 22, 400, 92)
const LIST_TOP := 176.0
const LIST_BOTTOM := 890.0
const ROW_X := 58.0
const ROW_W := 542.0
const ITEM_H := 76.0
const RIGHT_PANEL := Rect2(664, 110, 1070, 925)
const GOLD_PILL := Rect2(1646, 32, 238, 48)
const ICON_C := Vector2(1199, 266)
const ICON_R := 106.0
const TITLE_Y := 456.0
const PRICE_PILL := Rect2(1092, 522, 214, 46)
const DESC_X := 716.0
const DESC_Y := 618.0
const LORE_SEP_Y := 712.0
const BUY_BTN := Rect2(858, 930, 684, 58)
const CONFIRM := Rect2(680, 400, 560, 250)

# ─── ПАЛИТРА ───────────────────────────────────────────────────────────────────
const C_BG := Color(0.03, 0.026, 0.024)
const C_PANEL := Color(0.045, 0.04, 0.036, 0.93)
const C_GOLD := Color(0.78, 0.62, 0.37)
const C_GOLD_DIM := Color(0.55, 0.45, 0.3, 0.65)
const C_GOLD_FAINT := Color(0.55, 0.45, 0.3, 0.25)
const C_GOLD_BRIGHT := Color(0.98, 0.84, 0.5)
const C_TEXT := Color(0.9, 0.85, 0.75)
const C_TEXT_DIM := Color(0.62, 0.57, 0.48)
const C_RED := Color(0.86, 0.26, 0.18)
const C_BANNER := Color(0.3, 0.055, 0.045)

var _view_scale := 1.0
var _view_offset := Vector2.ZERO

# ─── UI-ЗВУКИ ──────────────────────────────────────────────────────────────────
const SOUND_ACCEPT := preload("res://Sound/UI_button/accept.wav")
const SOUND_DENIED := preload("res://Sound/UI_button/denied.wav")
const SOUND_CHOICE := preload("res://Sound/UI_button/choice.wav")
const SOUND_OPEN := preload("res://Sound/openUI_sound.mp3")
const SOUND_BUY := preload("res://Sound/shop_sound/sound_buy.mp3")
var _ui_audio: AudioStreamPlayer

func _play_ui_sound(stream: AudioStream) -> void:
	_ui_audio.stream = stream
	_ui_audio.play()

# ─── LIFECYCLE ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	items.assign(_knight_items())
	_load_textures()
	set_process(false)
	set_process_input(false)
	# Шрифт с засечками и нормальными цифрами — как в инвентаре
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Cambria", "Georgia"])
	font_body = serif
	# Заголовки — тот же шрифт с засечками, как на макете, только крупнее
	font_title = serif
	visible = false

	_vignette = _radial_texture([Color(0.1, 0.085, 0.07, 1.0), Color(0.02, 0.017, 0.015, 1.0)])
	_glow = _radial_texture([Color(1.0, 0.6, 0.25, 1.0), Color(1.0, 0.5, 0.2, 0.0)])

	_ui_audio = AudioStreamPlayer.new()
	add_child(_ui_audio)


func _radial_texture(colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[1])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func open_shop(player: Node2D) -> void:
	if visible:
		return  # магазин уже открыт — игнорируем повторный вызов
	current_player = player
	player_gold = player.gold
	_build_items_for(player)
	# Карточка справа сразу показывает первый товар — пустая половина экрана
	# при открытии выглядит как недогруженное окно
	selected_index = 0 if not items.is_empty() else -1
	pending_buy_index = -1
	player.is_in_shop = true
	_opened_at = anim_time
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


func _max_scroll() -> float:
	return maxf(0.0, float(items.size()) * ITEM_H - (LIST_BOTTOM - LIST_TOP))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			# Сначала закрывается окно подтверждения, потом уже весь магазин
			if pending_buy_index >= 0:
				pending_buy_index = -1
				_play_ui_sound(SOUND_CHOICE)
			else:
				close_shop()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_E and anim_time - _opened_at > 0.25:
			if pending_buy_index >= 0:
				_confirm_buy()
			elif selected_index >= 0:
				_open_confirm(selected_index)
			get_viewport().set_input_as_handled()
			return
		if pending_buy_index < 0 and (key == KEY_UP or key == KEY_DOWN):
			_move_selection(-1 if key == KEY_UP else 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		_update_hover(_to_design((event as InputEventMouseMotion).position))
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_click(_to_design(mb.position))
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_scroll = clampf(target_scroll + 60.0, 0.0, _max_scroll())
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_scroll = clampf(target_scroll - 60.0, 0.0, _max_scroll())


func _to_design(p: Vector2) -> Vector2:
	return (p - _view_offset) / _view_scale


## Стрелки вверх/вниз листают список, прокрутка догоняет выбранную строку
func _move_selection(step: int) -> void:
	if items.is_empty():
		return
	selected_index = clampi(selected_index + step, 0, items.size() - 1)
	_play_ui_sound(SOUND_CHOICE)
	var top := float(selected_index) * ITEM_H
	var bottom := top + ITEM_H
	var view_h := LIST_BOTTOM - LIST_TOP
	if top < target_scroll:
		target_scroll = top
	elif bottom > target_scroll + view_h:
		target_scroll = bottom - view_h
	target_scroll = clampf(target_scroll, 0.0, _max_scroll())

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


func _row_rect(i: int) -> Rect2:
	return Rect2(ROW_X, LIST_TOP + float(i) * ITEM_H - scroll_offset, ROW_W, ITEM_H - 8.0)


func _row_visible(r: Rect2) -> bool:
	return r.position.y >= LIST_TOP - 2.0 and r.end.y <= LIST_BOTTOM + 2.0


func _update_hover(p: Vector2) -> void:
	hovered_index = -1
	_buy_hover = false
	_confirm_hover = -1
	if pending_buy_index >= 0:
		var btns := _confirm_buttons()
		for i in btns.size():
			if btns[i].has_point(p):
				_confirm_hover = i
		return
	for i: int in items.size():
		var r := _row_rect(i)
		if _row_visible(r) and r.has_point(p):
			hovered_index = i
			break
	_buy_hover = selected_index >= 0 and BUY_BTN.has_point(p)

var last_click_time: float = 0.0
var last_click_index: int = -1
const DOUBLE_CLICK_TIME := 0.35

func _handle_click(p: Vector2) -> void:
	if pending_buy_index >= 0:
		_handle_confirm_click(p)
		return

	if selected_index >= 0 and BUY_BTN.has_point(p):
		_open_confirm(selected_index)
		return

	for i: int in items.size():
		var r := _row_rect(i)
		if _row_visible(r) and r.has_point(p):
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

func _open_confirm(index: int) -> void:
	var item = items[index]
	if player_gold < (item["price"] as int):
		_play_ui_sound(SOUND_DENIED)
		return  # недостаточно золота — не открываем окно
	if _is_maxed(item):
		_play_ui_sound(SOUND_DENIED)
		return  # сумка полна этим предметом (талисман — только один)
	selected_index = index
	pending_buy_index = index
	_play_ui_sound(SOUND_CHOICE)

## Уже держим столько, сколько влезает ("max" в каталоге). У товаров рыцаря
## лимита в каталоге нет — им не мешаем, как и раньше
func _is_maxed(item: Dictionary) -> bool:
	if not item.has("max") or current_player == null:
		return false
	var inv = current_player.get("inventory_system")
	if inv == null:
		return false
	return inv.get_count(item["name"]) >= (item["max"] as int)


func _confirm_buttons() -> Array[Rect2]:
	var bw := 190.0
	var bh := 48.0
	var y := CONFIRM.end.y - 78.0
	var cx := CONFIRM.get_center().x
	return [Rect2(cx - bw - 14.0, y, bw, bh), Rect2(cx + 14.0, y, bw, bh)]


func _handle_confirm_click(p: Vector2) -> void:
	var btns := _confirm_buttons()
	if btns[0].has_point(p):
		_confirm_buy()
	elif btns[1].has_point(p):
		pending_buy_index = -1
		_confirm_hover = -1
		_play_ui_sound(SOUND_CHOICE)


func _confirm_buy() -> void:
	_play_ui_sound(SOUND_BUY)
	_try_buy(pending_buy_index)
	pending_buy_index = -1
	_confirm_hover = -1

func _try_buy(index: int) -> void:
	var item = items[index]
	var price: int = item["price"] as int

	if player_gold < price:
		return  # недостаточно золота

	if not current_player or _is_maxed(item):
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
	# Макет 1920×1080 вписывается в окно целиком, по центру
	_view_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_view_offset = (size - DESIGN * _view_scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	draw_set_transform(_view_offset, 0.0, Vector2(_view_scale, _view_scale))

	_draw_background()
	_draw_left_panel()
	_draw_banner()
	_draw_gold_pill()
	_draw_right_panel()
	if pending_buy_index >= 0:
		_draw_confirm_dialog()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ─── ФОН ───────────────────────────────────────────────────────────────────────
func _draw_background() -> void:
	# Мягкая виньетка: к центру чуть теплее и светлее, по краям в черноту
	draw_texture_rect(_vignette, Rect2(-200, -300, DESIGN.x + 400, DESIGN.y + 600), false)

	# Тёплые отсветы свечей — справа внизу и слева вверху, мерцают неровно
	var f1 := 0.85 + 0.1 * sin(anim_time * 7.3) + 0.05 * sin(anim_time * 17.0)
	var f2 := 0.85 + 0.1 * sin(anim_time * 5.1 + 1.3) + 0.05 * sin(anim_time * 13.0)
	draw_texture_rect(_glow, Rect2(1500, 560, 700, 700), false, Color(1, 1, 1, 0.13 * f1))
	draw_texture_rect(_glow, Rect2(-260, -300, 700, 600), false, Color(1, 1, 1, 0.06 * f2))

	# Зерно — неподвижное (фиксированный seed), только чтобы фон не был плоским
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i: int in 700:
		draw_rect(Rect2(rng.randf_range(0.0, DESIGN.x), rng.randf_range(0.0, DESIGN.y), 1.0, 1.0),
				Color(1.0, 0.95, 0.8, rng.randf_range(0.01, 0.045)))


# ─── ОБЩИЕ ОРНАМЕНТЫ ───────────────────────────────────────────────────────────

## Панель с двойной каймой и кованными уголками
func _draw_panel(r: Rect2, fill := C_PANEL) -> void:
	draw_rect(r, fill)
	# Лёгкий градиент сверху — панель не выглядит плоской заливкой
	for i in 6:
		draw_rect(Rect2(r.position.x, r.position.y + i * 14.0, r.size.x, 14.0),
				Color(0.12, 0.1, 0.07, 0.035 * (6 - i)))
	draw_rect(r, C_GOLD_DIM, false, 1.0)
	draw_rect(r.grow(-7.0), C_GOLD_FAINT, false, 1.0)
	for c in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0],
			[Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		_draw_corner(c[0], c[1], c[2])


func _draw_corner(p: Vector2, sx: float, sy: float) -> void:
	var L := 34.0
	draw_line(p + Vector2(-sx * 6, -sy * 6), p + Vector2(sx * L, -sy * 6), C_GOLD, 1.5)
	draw_line(p + Vector2(-sx * 6, -sy * 6), p + Vector2(-sx * 6, sy * L), C_GOLD, 1.5)
	# Завиток внутрь угла и ромбик на самом углу
	draw_line(p + Vector2(sx * 4, sy * 4), p + Vector2(sx * 16, sy * 16), C_GOLD_DIM, 1.0)
	draw_arc(p + Vector2(sx * 20, sy * 20), 5.0, 0.0, TAU, 16, C_GOLD_DIM, 1.0, true)
	_draw_diamond(p + Vector2(-sx * 6, -sy * 6), 5.0, C_GOLD, true)


func _draw_diamond(c: Vector2, s: float, col: Color, filled := false) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	if filled:
		draw_colored_polygon(pts, Color(0.06, 0.05, 0.04))
	pts.append(pts[0])
	draw_polyline(pts, col, 1.3, true)
	if filled:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.4, 0),
				c + Vector2(0, s * 0.4), c + Vector2(-s * 0.4, 0)]), col)


## Горизонтальная линия-орнамент: затухающие концы, ромбик в центре
func _draw_ornament_line(a: Vector2, b: Vector2, col := C_GOLD_DIM, center_diamond := true) -> void:
	var mid := (a + b) * 0.5
	var gap := 12.0 if center_diamond else 0.0
	draw_line(a, mid - Vector2(gap, 0), col, 1.0)
	draw_line(mid + Vector2(gap, 0), b, col, 1.0)
	draw_circle(a, 1.5, col)
	draw_circle(b, 1.5, col)
	if center_diamond:
		_draw_diamond(mid, 5.0, col)


## Плашка с заострёнными концами-стрелками (цена, золото, кнопка)
func _pill_points(r: Rect2, tip: float) -> PackedVector2Array:
	var cy := r.position.y + r.size.y * 0.5
	return PackedVector2Array([
		Vector2(r.position.x + tip, r.position.y), Vector2(r.end.x - tip, r.position.y),
		Vector2(r.end.x, cy), Vector2(r.end.x - tip, r.end.y),
		Vector2(r.position.x + tip, r.end.y), Vector2(r.position.x, cy)])


func _draw_pill(r: Rect2, border: Color, fill := Color(0.05, 0.043, 0.037, 0.95), wings := true) -> void:
	var tip := minf(r.size.y * 0.5, 22.0)
	var pts := _pill_points(r, tip)
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, border, 1.3, true)
	var inner := _pill_points(r.grow_individual(-5, -4, -5, -4), tip - 3.0)
	inner.append(inner[0])
	draw_polyline(inner, Color(border, border.a * 0.35), 1.0, true)
	if wings:
		# Шевроны снаружи концов — "наконечники", как на HUD
		var cy := r.position.y + r.size.y * 0.5
		var h := r.size.y * 0.42
		for side: float in [-1.0, 1.0]:
			var x := r.position.x - 6.0 if side < 0.0 else r.end.x + 6.0
			draw_polyline(PackedVector2Array([Vector2(x - side * 2.0, cy - h),
					Vector2(x + side * 10.0, cy), Vector2(x - side * 2.0, cy + h)]), border, 1.3, true)
			_draw_diamond(Vector2(x + side * 18.0, cy), 3.0, border)


func _draw_coin(c: Vector2, r: float, can_afford := true) -> void:
	var base := Color(0.8, 0.6, 0.18) if can_afford else Color(0.72, 0.16, 0.1)
	var hi := Color(1.0, 0.85, 0.4) if can_afford else Color(0.98, 0.42, 0.3)
	draw_circle(c, r + 2.0, Color(base, 0.25))
	draw_circle(c, r, base)
	draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.62, hi)
	draw_arc(c, r * 0.8, 0.0, TAU, 20, Color(base.darkened(0.3), 0.8), 1.0, true)


func _text(pos: Vector2, s: String, sz: int, col: Color, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font if font else font_body, pos, s, align, width, sz, col)


func _text_w(s: String, sz: int, font: Font = null) -> float:
	return (font if font else font_body).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


# ─── ЗАГОЛОВОК-ЗНАМЯ ───────────────────────────────────────────────────────────
func _draw_banner() -> void:
	var r := BANNER
	var notch := 18.0
	var pts := PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - notch, r.position.y + r.size.y * 0.5), Vector2(r.end.x, r.end.y),
		Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(pts, C_BANNER)
	# Затемнение книзу и потёртости ткани
	for i in 5:
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (0.5 + i * 0.1), r.size.x - notch * 1.2,
				r.size.y * 0.1), Color(0, 0, 0, 0.06 * (i + 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in 60:
		draw_rect(Rect2(rng.randf_range(r.position.x, r.end.x - notch * 1.5), rng.randf_range(r.position.y, r.end.y), 2.0, 1.0),
				Color(0, 0, 0, rng.randf_range(0.1, 0.3)))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, C_GOLD_DIM, 1.5, true)
	draw_line(r.position + Vector2(8, 6), Vector2(r.end.x - 10, r.position.y + 6), C_GOLD_FAINT, 1.0)
	draw_line(Vector2(r.position.x + 8, r.end.y - 6), Vector2(r.end.x - 10, r.end.y - 6), C_GOLD_FAINT, 1.0)

	# Эмблема: медальон с руной-звездой
	var ec := Vector2(r.position.x + 44, r.position.y + r.size.y * 0.5)
	draw_circle(ec, 27.0, Color(0.08, 0.05, 0.04))
	draw_arc(ec, 27.0, 0.0, TAU, 32, C_GOLD, 2.0, true)
	draw_arc(ec, 21.0, 0.0, TAU, 32, C_GOLD_DIM, 1.0, true)
	for k in 2:
		var tri := PackedVector2Array()
		for j in 4:
			tri.append(ec + Vector2.from_angle(-PI / 2.0 + k * PI / 3.0 + j * TAU / 3.0) * 14.0)
		draw_polyline(tri, C_GOLD, 1.3, true)
	draw_circle(ec, 2.5, C_GOLD_BRIGHT)

	_text(Vector2(r.position.x + 88, r.position.y + r.size.y * 0.5 + 12), "МАГАЗИН", 34, C_TEXT, font_title)


# ─── ЛЕВАЯ ПАНЕЛЬ: СПИСОК ──────────────────────────────────────────────────────
func _draw_left_panel() -> void:
	_draw_panel(LEFT_PANEL)

	var hy := 150.0
	_text(Vector2(64, hy), "ПРЕДМЕТ", 18, C_GOLD_DIM)
	_text(Vector2(ROW_X, hy), "ЦЕНА", 18, C_GOLD_DIM, null, HORIZONTAL_ALIGNMENT_RIGHT, ROW_W - 14.0)
	_draw_ornament_line(Vector2(180, hy - 6), Vector2(ROW_X + ROW_W - 80, hy - 6), C_GOLD_FAINT)
	draw_line(Vector2(ROW_X, hy + 12), Vector2(ROW_X + ROW_W, hy + 12), C_GOLD_FAINT, 1.0)
	_draw_diamond(Vector2(ROW_X, hy + 12), 3.0, C_GOLD_DIM)
	_draw_diamond(Vector2(ROW_X + ROW_W, hy + 12), 3.0, C_GOLD_DIM)

	for i: int in items.size():
		var r := _row_rect(i)
		if _row_visible(r):
			_draw_row(i, r)
	_draw_scrollbar()

	# Низ панели: "У вас есть:" и золото
	var by := 944.0
	_text(Vector2(62, by), "У вас есть:", 18, C_TEXT_DIM)
	_draw_ornament_line(Vector2(170, by - 6), Vector2(290, by - 6), C_GOLD_FAINT, false)
	_draw_diamond(Vector2(170, by - 6), 3.0, C_GOLD_DIM)
	_draw_coin(Vector2(84, 988), 14.0)
	_text(Vector2(110, 998), "%d G" % player_gold, 28, C_TEXT)


func _draw_row(i: int, r: Rect2) -> void:
	var item: Dictionary = items[i]
	var is_hovered := i == hovered_index
	var is_selected := i == selected_index
	var can_afford := player_gold >= (item["price"] as int)
	var maxed := _is_maxed(item)

	if is_selected:
		var pulse := 0.5 + 0.5 * sin(anim_time * 2.5)
		draw_rect(r.grow(3.0), Color(C_GOLD_BRIGHT, 0.06 + 0.04 * pulse))
		# Золотистая заливка, светлее к середине строки
		draw_rect(r, Color(0.2, 0.15, 0.07, 0.95))
		for k in 4:
			draw_rect(Rect2(r.position.x + r.size.x * 0.15 + k * 30.0, r.position.y, r.size.x * 0.7 - k * 60.0, r.size.y),
					Color(0.5, 0.36, 0.12, 0.05))
		draw_rect(r, Color(C_GOLD_BRIGHT, 0.85), false, 1.5)
		draw_rect(r.grow(-4.0), Color(C_GOLD, 0.3), false, 1.0)
		# Маркер-засечка слева от выбранной строки
		draw_line(Vector2(r.position.x - 26, r.get_center().y), Vector2(r.position.x - 8, r.get_center().y), C_GOLD, 1.5)
		_draw_diamond(Vector2(r.position.x - 4, r.get_center().y), 4.0, C_GOLD_BRIGHT, true)
	elif is_hovered:
		draw_rect(r, Color(0.1, 0.085, 0.065, 0.95))
		draw_rect(r, C_GOLD_DIM, false, 1.0)
	else:
		draw_rect(r, Color(0.055, 0.048, 0.042, 0.9))
		draw_rect(r, Color(0.35, 0.3, 0.22, 0.3), false, 1.0)

	# Иконка в рамке
	var isz := 56.0
	var ir := Rect2(r.position.x + 12.0, r.get_center().y - isz * 0.5, isz, isz)
	draw_rect(ir.grow(2.0), Color(0.02, 0.018, 0.016))
	var tex: Texture2D = item["texture"] as Texture2D
	var dim := 1.0 if (is_hovered or is_selected) else 0.82
	if tex:
		draw_texture_rect(tex, ir, false, Color(dim, dim, dim))
	else:
		_draw_icon_placeholder(ir.get_center().x, ir.get_center().y, isz * 0.4,
				item["name"] as String, item["col"] as Color, is_hovered or is_selected)
	draw_rect(ir.grow(2.0), C_GOLD if is_selected else C_GOLD_DIM, false, 1.0)

	var name_col := C_TEXT if (is_selected or is_hovered) else Color(0.8, 0.75, 0.64)
	if not can_afford and not maxed:
		name_col = name_col.darkened(0.25)
	_text(Vector2(ir.end.x + 22.0, r.get_center().y + 7.0), item["name"] as String, 21, name_col)

	# Цена справа: монета + число. Не хватает золота — всё красное
	var right := r.end.x - 16.0
	var cy := r.get_center().y
	if maxed:
		_text(Vector2(r.position.x, cy + 6.0), "в сумке", 17, C_TEXT_DIM, null,
				HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16.0)
		return
	var price_str := str(item["price"])
	var pw := _text_w(price_str, 25)
	_text(Vector2(right - pw, cy + 9.0), price_str, 25, C_GOLD_BRIGHT if can_afford else C_RED)
	_draw_coin(Vector2(right - pw - 18.0, cy + 1.0), 9.0, can_afford)


func _draw_scrollbar() -> void:
	var total_h := float(items.size()) * ITEM_H
	var visible_h := LIST_BOTTOM - LIST_TOP
	if total_h <= visible_h:
		return
	var bar_x := ROW_X + ROW_W + 10.0
	draw_rect(Rect2(bar_x, LIST_TOP, 2.0, visible_h), C_GOLD_FAINT)
	var thumb_h: float = maxf(30.0, visible_h * (visible_h / total_h))
	var thumb_y: float = LIST_TOP + (scroll_offset / (total_h - visible_h)) * (visible_h - thumb_h)
	draw_rect(Rect2(bar_x - 1.0, thumb_y, 4.0, thumb_h), C_GOLD_DIM)


# ─── ЗОЛОТО СПРАВА СВЕРХУ ──────────────────────────────────────────────────────
func _draw_gold_pill() -> void:
	var r := GOLD_PILL
	_draw_pill(r, C_GOLD_DIM, Color(0.05, 0.043, 0.037, 0.95), false)
	draw_polyline(PackedVector2Array([Vector2(r.end.x - 4, r.position.y + 8), Vector2(r.end.x + 8, r.get_center().y),
			Vector2(r.end.x - 4, r.end.y - 8)]), C_GOLD_DIM, 1.3, true)
	# Значок-свеча в кружке
	var c := Vector2(r.position.x + 28, r.get_center().y)
	draw_circle(c, 17.0, Color(0.09, 0.06, 0.04))
	draw_arc(c, 17.0, 0.0, TAU, 28, C_GOLD, 1.5, true)
	var fl := 1.0 + 0.12 * sin(anim_time * 11.0) + 0.06 * sin(anim_time * 23.0)
	draw_rect(Rect2(c.x - 4, c.y + 1, 8, 9), Color(0.85, 0.78, 0.62))
	var flame := PackedVector2Array([c + Vector2(0, -12 * fl), c + Vector2(3.5, -3), c + Vector2(0, 0), c + Vector2(-3.5, -3)])
	draw_colored_polygon(flame, Color(1.0, 0.72, 0.25))
	draw_circle(c + Vector2(0, -4), 1.8, Color(1.0, 0.95, 0.7))
	_text(Vector2(c.x + 30, r.get_center().y + 9), "%d G" % player_gold, 26, C_TEXT)


# ─── ПРАВАЯ ПАНЕЛЬ: КАРТОЧКА ТОВАРА ────────────────────────────────────────────
func _draw_right_panel() -> void:
	var rp := RIGHT_PANEL
	_draw_panel(rp)
	# Шпиль-орнамент над медальоном по центру верхней кромки
	var top := Vector2(rp.get_center().x, rp.position.y)
	draw_polyline(PackedVector2Array([top + Vector2(-60, 0), top + Vector2(0, -26), top + Vector2(60, 0)]), C_GOLD_DIM, 1.3, true)
	_draw_diamond(top + Vector2(0, -26), 6.0, C_GOLD, true)
	_draw_rune_column(Vector2(rp.position.x + 30, 190))
	_draw_rune_column(Vector2(rp.end.x - 30, 190))

	if selected_index < 0 or selected_index >= items.size():
		_text(Vector2(rp.position.x, rp.get_center().y), "Выберите предмет", 22, C_TEXT_DIM, null,
				HORIZONTAL_ALIGNMENT_CENTER, rp.size.x)
		return

	var item: Dictionary = items[selected_index]
	var col: Color = item["col"] as Color
	var can_afford := player_gold >= (item["price"] as int)
	var maxed := _is_maxed(item)

	_draw_medallion(item, col)

	# Название с орнаментальными линиями по бокам
	var name_str: String = item["name"] as String
	var nw := _text_w(name_str, 40, font_title)
	var cx := rp.get_center().x
	_text(Vector2(rp.position.x, TITLE_Y), name_str, 40, C_TEXT, font_title, HORIZONTAL_ALIGNMENT_CENTER, rp.size.x)
	var ly := TITLE_Y - 13.0
	for side: float in [-1.0, 1.0]:
		var inner := cx + side * (nw * 0.5 + 34.0)
		var outer := rp.position.x + 50.0 if side < 0.0 else rp.end.x - 50.0
		draw_line(Vector2(inner + side * 14.0, ly), Vector2(outer, ly), C_GOLD_FAINT, 1.0)
		_draw_diamond(Vector2(inner, ly), 6.0, C_GOLD_DIM)
		draw_line(Vector2(inner + side * 7.0, ly), Vector2(inner + side * 30.0, ly), C_GOLD_DIM, 1.0)

	if item.has("subtitle"):
		_text(Vector2(rp.position.x, TITLE_Y + 36.0), item["subtitle"] as String, 20,
				Color(C_GOLD, 0.95), null, HORIZONTAL_ALIGNMENT_CENTER, rp.size.x)

	# Цена
	_draw_pill(PRICE_PILL, C_GOLD_DIM)
	var price_str := "%d G" % (item["price"] as int)
	var pw := _text_w(price_str, 26)
	var pc := PRICE_PILL.get_center()
	_draw_coin(Vector2(pc.x - pw * 0.5 - 8.0, pc.y), 11.0, can_afford)
	_text(Vector2(pc.x - pw * 0.5 + 12.0, pc.y + 9.0), price_str, 26, C_TEXT if can_afford else C_RED)

	# Описание
	var desc_lines: PackedStringArray = (item["description"] as String).split("\n")
	for li in desc_lines.size():
		_text(Vector2(DESC_X, DESC_Y + li * 34.0), desc_lines[li], 21, C_TEXT)

	# Предание — ниже описания, но не выше своей строки на макете
	var sep_y := maxf(LORE_SEP_Y, DESC_Y + desc_lines.size() * 34.0 + 22.0)
	_draw_diamond(Vector2(DESC_X - 6.0, sep_y - 7.0), 3.5, C_GOLD_DIM)
	_text(Vector2(DESC_X + 8.0, sep_y), "Предание", 21, C_GOLD_DIM)
	var lx := DESC_X + 8.0 + _text_w("Предание", 21) + 14.0
	_draw_diamond(Vector2(lx, sep_y - 7.0), 3.5, C_GOLD_DIM)
	_draw_ornament_line(Vector2(lx + 10.0, sep_y - 7.0), Vector2(rp.end.x - 60.0, sep_y - 7.0), C_GOLD_FAINT)
	var lore_lines: PackedStringArray = (item["lore"] as String).split("\n")
	for li in lore_lines.size():
		_text(Vector2(DESC_X, sep_y + 44.0 + li * 29.0), lore_lines[li], 18, C_TEXT_DIM)

	_draw_buy_button(can_afford, maxed)


## Круглая иконка в медальоне: тёплое свечение, кольцо рун, засечки
func _draw_medallion(item: Dictionary, col: Color) -> void:
	var c := ICON_C
	var pulse := 0.5 + 0.5 * sin(anim_time * 2.0)
	var warm := col.lerp(Color(1.0, 0.6, 0.25), 0.5)
	draw_texture_rect(_glow, Rect2(c - Vector2.ONE * (ICON_R + 110), Vector2.ONE * (ICON_R + 110) * 2.0),
			false, Color(warm, 0.14 + 0.05 * pulse))

	draw_circle(c, ICON_R + 34.0, Color(0.035, 0.03, 0.027, 0.9))
	draw_arc(c, ICON_R + 34.0, 0.0, TAU, 96, C_GOLD_FAINT, 1.0, true)
	draw_arc(c, ICON_R + 16.0, 0.0, TAU, 96, C_GOLD_DIM, 1.2, true)
	# Засечки и "руны" между кольцами медленно проворачиваются
	var rot := anim_time * 0.05
	for k in 72:
		var a := rot + k * TAU / 72.0
		var d := Vector2.from_angle(a)
		var long := k % 6 == 0
		draw_line(c + d * (ICON_R + 17.0), c + d * (ICON_R + (27.0 if long else 21.0)),
				C_GOLD_DIM if long else C_GOLD_FAINT, 1.0)
	for k in 12:
		var a := -rot * 2.0 + (k + 0.5) * TAU / 12.0
		var p := c + Vector2.from_angle(a) * (ICON_R + 26.0)
		var t := Vector2.from_angle(a + PI / 2.0)
		var n := Vector2.from_angle(a)
		draw_line(p - n * 4.0, p + n * 4.0, C_GOLD_DIM, 1.0)
		draw_line(p, p + (n + t * (1.0 if k % 2 == 0 else -1.0)) * 3.0, C_GOLD_DIM, 1.0)
	# Ромбики по сторонам и сверху — снизу нет, там сразу название
	for k in [0, 2, 3]:
		var d := Vector2.from_angle(k * PI / 2.0)
		_draw_diamond(c + d * (ICON_R + 44.0), 5.0, C_GOLD, true)
		draw_line(c + d * (ICON_R + 50.0), c + d * (ICON_R + 70.0), C_GOLD_DIM, 1.0)

	draw_circle(c, ICON_R + 2.0, Color(0.02, 0.018, 0.016))
	var tex: Texture2D = item["texture"] as Texture2D
	if tex != null:
		# Обрезка по кругу треугольным веером
		var segments := 64
		var center_uv := Vector2(0.5, 0.5)
		for si in segments:
			var a0 := float(si) / segments * TAU
			var a1 := float(si + 1) / segments * TAU
			var d0 := Vector2.from_angle(a0)
			var d1 := Vector2.from_angle(a1)
			draw_primitive(
				PackedVector2Array([c, c + d0 * ICON_R, c + d1 * ICON_R]),
				PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]),
				PackedVector2Array([center_uv, d0 * 0.5 + center_uv, d1 * 0.5 + center_uv]),
				tex)
	else:
		_draw_icon_placeholder(c.x, c.y, ICON_R * 0.6, item["name"] as String, col, true)
	draw_arc(c, ICON_R, 0.0, TAU, 96, Color(C_GOLD, 0.7 + 0.2 * pulse), 2.0, true)
	draw_arc(c, ICON_R - 6.0, 0.0, TAU, 96, Color(0, 0, 0, 0.35), 5.0, true)


## Вертикальная колонка рун-засечек у края панели
func _draw_rune_column(top: Vector2) -> void:
	for k in 6:
		var p := top + Vector2(0, k * 26.0)
		var col := Color(C_GOLD, 0.22)
		draw_line(p, p + Vector2(0, 16), col, 1.2)
		match k % 3:
			0:
				draw_line(p + Vector2(0, 4), p + Vector2(6, 9), col, 1.2)
			1:
				draw_line(p + Vector2(0, 3), p + Vector2(-6, 8), col, 1.2)
				draw_line(p + Vector2(0, 8), p + Vector2(-6, 13), col, 1.2)
			2:
				draw_line(p + Vector2(-5, 4), p + Vector2(5, 12), col, 1.2)


func _draw_buy_button(can_afford: bool, maxed: bool) -> void:
	var enabled := can_afford and not maxed
	var hover := _buy_hover and enabled
	var border := C_GOLD if hover else C_GOLD_DIM
	var fill := Color(0.12, 0.09, 0.05, 0.96) if hover else Color(0.05, 0.043, 0.037, 0.95)
	_draw_pill(BUY_BTN, border, fill)
	var label := "[E]  Купить"
	var col := C_GOLD_BRIGHT if hover else C_TEXT
	if maxed:
		label = "Уже в сумке"
		col = C_TEXT_DIM
	elif not can_afford:
		label = "Недостаточно золота"
		col = Color(C_RED, 0.85)
	_text(Vector2(BUY_BTN.position.x, BUY_BTN.get_center().y + 8.0), label, 23, col, null,
			HORIZONTAL_ALIGNMENT_CENTER, BUY_BTN.size.x)


# ─── ПОДТВЕРЖДЕНИЕ ПОКУПКИ ─────────────────────────────────────────────────────
func _draw_confirm_dialog() -> void:
	draw_rect(Rect2(-200, -200, DESIGN.x + 400, DESIGN.y + 400), Color(0, 0, 0, 0.62))
	var item: Dictionary = items[pending_buy_index]
	_draw_panel(CONFIRM, Color(0.05, 0.044, 0.038, 0.98))
	_text(Vector2(CONFIRM.position.x, CONFIRM.position.y + 58.0), "Подтверждение", 26, C_GOLD, font_title,
			HORIZONTAL_ALIGNMENT_CENTER, CONFIRM.size.x)
	_draw_ornament_line(Vector2(CONFIRM.position.x + 90, CONFIRM.position.y + 78), Vector2(CONFIRM.end.x - 90, CONFIRM.position.y + 78))
	_text(Vector2(CONFIRM.position.x, CONFIRM.position.y + 124.0),
			"Купить «%s» за %d G?" % [item["name"], item["price"]], 21, C_TEXT, null,
			HORIZONTAL_ALIGNMENT_CENTER, CONFIRM.size.x)

	var btns := _confirm_buttons()
	var labels := ["[E]  Да", "[Esc]  Нет"]
	for i in 2:
		var hover := _confirm_hover == i
		_draw_pill(btns[i], C_GOLD if hover else C_GOLD_DIM,
				Color(0.12, 0.09, 0.05, 0.96) if hover else Color(0.05, 0.043, 0.037, 0.95), false)
		_text(Vector2(btns[i].position.x, btns[i].get_center().y + 8.0), labels[i], 21,
				C_GOLD_BRIGHT if hover else C_TEXT, null, HORIZONTAL_ALIGNMENT_CENTER, btns[i].size.x)


# ─── ЗАГЛУШКА (если PNG не найден) ────────────────────────────────────────────
# Рисует круг с первой буквой названия предмета
func _draw_icon_placeholder(cx: float, cy: float, r: float, item_name: String, col: Color, bright: bool) -> void:
	var alpha: float = 1.0 if bright else 0.5
	draw_circle(Vector2(cx, cy), r, Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, alpha))
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 32, Color(col.r, col.g, col.b, alpha), 2.0)
	if item_name.length() > 0:
		var letter: String = item_name.substr(0, 1).to_upper()
		draw_string(font_title, Vector2(cx - r * 0.3, cy + r * 0.35),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.0),
				Color(col.r, col.g, col.b, alpha))
