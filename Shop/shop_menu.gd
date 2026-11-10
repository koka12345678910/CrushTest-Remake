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
	# Маг — талисманы (эффекты в Player_scene/mage.gd)
	"Глаз Мимира": MimirEyeTalisman,
	"Кольцо Драупнир": DraupnirRingTalisman,
	"Гандр вёльвы": VolvaStaffTalisman,
}
const MimirEyeTalisman := preload("res://Inventory/systems/ability/abilities/mage/mimir_eye_talisman.gd")
const DraupnirRingTalisman := preload("res://Inventory/systems/ability/abilities/mage/draupnir_ring_talisman.gd")
const VolvaStaffTalisman := preload("res://Inventory/systems/ability/abilities/mage/volva_staff_talisman.gd")

func _knight_items() -> Array:
	return [
		{
			"name": "Мёд Поэзии",
			"price": 50,
			"icon": "res://Shop/icons/icons_2/jar_honey.png",
			"description": "Постепенно восстанавливает здоровье.",
			"lore": "Старинный напиток, рожденный из шёпота богов\nГоворят, его вкус дарует не только ясность ума, но и силу, что течёт глубже крови.\nНемногие знают, из чего он создан.\nИ ещё меньше — чем приходится за него платить.",
			"col": Color(0.4, 0.8, 0.3),
			"texture": null
		},
		{
			"name": "Песнь валькирии",
			"price": 0,
			"icon": "res://Shop/icons/icons_2/valkyrie's_song.png",
			"description": "Те, кто слышит её песнь, возвращаются к бою.\nНо не все возвращаются прежними.",
			"lore": "Тихий отголосок битв, что давно затихли.\nСчитается, что в этом сосуде запечатан последний вздох павшей валькирии.",
			"col": Color(0.9, 0.75, 0.2),
			"texture": null
		},
		{
			"name": "Эликсир Вальгаллы",
			"price": 120,
			"icon": "res://Shop/icons/icons_2/valhalla_elixir.png",
			"description": "Тот, кто испьёт его, на мгновение ощущает силу тех, кто уже пал.\nНо даже мимолётный взгляд за порог не проходит бесследно.",
			"lore": "Густой напиток, которым провожают павших воинов.\nГоворят, он пропитан эхом пиршеств из Вальгалла.",
			"col": Color(0.6, 0.4, 0.9),
			"texture": null
		},
		{
			"name": "Руна жертвы",
			"price": 0,
			"icon": "res://Shop/icons/icons_2/rune_of_sacrifice.png",
			"description": "Она откликается на боль владельца, возвращая утраченное.\nНо всегда забирает больше, чем было отдано.",
			"lore": "Старинный знак, вырезанный не ради защиты, а ради расплаты.\nКаждая линия на ней — напоминание о цене силы.",
			"col": Color(0.95, 0.55, 0.1),
			"texture": null
		},
		{
			"name": "Безумие Берсерка",
			"price": 0,
			"icon": "res://Shop/icons/icons_2/berserk.png",
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
			"icon": "res://Shop/icons/icons_2/fenrir.png",
			"description": "Дарует мощь, способную сокрушить всё на пути.\nНо зверь внутри никогда не служит долго.",
			"lore": "Сила зверя, что однажды разорвёт сами оковы мира.\nОна кипит, даже будучи заключённой.",
			"col": Color(0.75, 0.8, 0.85),
			"texture": null
		},
	]


# Товары лучницы. "subtitle" — принадлежность и тип под названием, "max" —
# сколько штук можно держать в сумке (талисман — один, второй не продаём)
func _archer_items() -> Array:
	# ВРЕМЕННО: все цены лучницы обнулены по просьбе пользователя — тестовый
	# бесплатный магазин. Настоящая цена — в комментарии рядом с "price",
	# верни её, когда магазин снова должен стать платным
	return [
		{
			"name": "Выстрел Валькирии",
			"subtitle": "Валькирии  •  Боевой навык",
			"price": 0,  # было 60
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
			"price": 0,  # было 80
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
			"price": 0,  # было 80
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
			"price": 0,  # было 90
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
			"price": 0,  # было 100
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
			"price": 0,  # было 150
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
			"price": 0,  # было 140
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
			"price": 0,  # было 250
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
			"price": 0,  # было 250
			"max": 1,
			"icon": "res://UI/icons_for_sigrid/norn's_needle.png",
			"description": "+20% шанса критического попадания по врагам,\nкоторых лучница уже поражала.",
			"lore": "Норны плетут нити судьбы, которым не способен\nпротивиться даже бог.\nИногда достаточно одной нити, чтобы изменить исход битвы.",
			"col": Color(0.85, 0.8, 0.65),
			"texture": null
		},
	]


## Товары мага — зелья рыцарского каталога (те же иконки и предания), цены
## в душах. Боевые способности рыцаря и лучницы завязаны на свой класс, магу
## не годятся; свои способности у мага появятся позже
const MAGE_PRICES := {"Мёд Поэзии": 50, "Песнь валькирии": 80, "Эликсир Вальгаллы": 120}

func _mage_items() -> Array:
	var out := []
	for it in _knight_items():
		if MAGE_PRICES.has(it["name"]):
			var m: Dictionary = it.duplicate()
			m["price"] = MAGE_PRICES[it["name"]]
			m["subtitle"] = "Зелье"
			# Сколько влезает в сумку — как у рыцаря (inventory_ui._get_max_count)
			m["max"] = 5 if it["name"] == "Мёд Поэзии" else 3
			out.append(m)
	out.append_array(_mage_talismans())
	return out


## Товары Сольвейг — пока только зелья рыцарского каталога за золото (те же
## цены). Своих талисманов у неё ещё нет (Жёлудь Иггдрасиля, Венок Сив,
## Волчья шкура — в планах)
func _druid_items() -> Array:
	var out := []
	for it in _knight_items():
		if MAGE_PRICES.has(it["name"]):
			var m: Dictionary = it.duplicate()
			m["subtitle"] = "Зелье"
			m["max"] = 5 if it["name"] == "Мёд Поэзии" else 3
			out.append(m)
	return out


## Талисманы мага — надеваются во вкладке "Талисманы", как у лучницы
func _mage_talismans() -> Array:
	return [
		{
			"name": "Глаз Мимира",
			"subtitle": "Мимир  •  Талисман, пассивный",
			"price": 150,
			"max": 1,
			"icon": "res://UI/icons_for_mage/mimir_eye.png",
			"description": "Сейд восполняется на 50% быстрее —\nи в бою, и в передышке.",
			"lore": "Один отдал глаз за глоток из источника Мимира.\nТот глаз до сих пор смотрит со дна —\nи видит, откуда течёт сила.",
			"col": Color(0.45, 0.7, 1.0),
			"texture": null
		},
		{
			"name": "Кольцо Драупнир",
			"subtitle": "Один  •  Талисман, пассивный",
			"price": 200,
			"max": 1,
			"icon": "res://UI/icons_for_mage/draupnir_ring.png",
			"description": "Каждая собранная душа приносит\nна 30% больше.",
			"lore": "Каждую девятую ночь из Драупнира капают\nвосемь колец, равных ему по весу.\nТо, что к нему прикасается, множится.",
			"col": Color(0.95, 0.75, 0.35),
			"texture": null
		},
		{
			"name": "Гандр вёльвы",
			"subtitle": "Вёльва  •  Талисман, пассивный",
			"price": 250,
			"max": 1,
			"icon": "res://UI/icons_for_mage/volva_staff.png",
			"description": "Все заклинания стоят на 20% меньше Сейда.",
			"lore": "Посох провидицы, что пела сейд у границ миров.\nВ нём сила не тратится —\nона лишь течёт из одного русла в другое.",
			"col": Color(0.7, 0.55, 1.0),
			"texture": null
		},
	]


## Каталог по классу покупателя. У лучницы есть character_id, у рыцаря нет
func _build_items_for(player: Node) -> void:
	var cid = player.get("character_id") if player else null
	if cid == "archer":
		items.assign(_archer_items())
	elif cid == "mage":
		items.assign(_mage_items())
	elif cid == "druid":
		items.assign(_druid_items())
	else:
		items.assign(_knight_items())
	_load_textures()
	selected_index = -1
	hovered_index = -1
	scroll_offset = 0.0
	target_scroll = 0.0


## ── Для лута ────────────────────────────────────────────────────────────────
## Товары, которые этот герой может получить (каталог его класса без тех, что
## уже лежат в сумке по максимуму). Маг получает зелья (_mage_items)
func loot_catalog(player: Node) -> Array:
	if player == null or player.get("inventory_ui") == null:
		return []
	var cid = player.get("character_id")
	var catalog: Array
	if cid == "archer":
		catalog = _archer_items()
	elif cid == "mage":
		catalog = _mage_items()
	elif cid == "druid":
		catalog = _druid_items()
	elif cid == null or cid == "knight":
		catalog = _knight_items()
	else:
		return []
	var out := []
	var inv = player.get("inventory_system")
	for it in catalog:
		if not ability_class_map.has(it["name"]):
			continue
		if it.has("max") and inv != null and inv.get_count(it["name"]) >= (it["max"] as int):
			continue
		out.append(it)
	return out


## Новый экземпляр способности по имени товара (null — такого нет)
func make_ability(item_name: String) -> Ability:
	if not ability_class_map.has(item_name):
		return null
	return ability_class_map[item_name].new()


# ─── STATE ─────────────────────────────────────────────────────────────────────
var hovered_index: int = -1
var selected_index: int = -1
var player_gold: int = 3000
## Покупатель платит душами (маг), а не золотом — см. open_shop / _money
var _souls_mode := false
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
## Затемнение краёв экрана поверх затемнённого мира (как за инвентарём)
var _vignette: Texture2D
## Иконки товаров рисуются отдельным слоем с шейдером иконок инвентаря
## (середина картинки, мягкие края, чуть ярче), окно подтверждения — ещё
## одним слоем поверх них
var _icon_layer: Control
var _overlay: Control
## Подсветка строк 0..1 (выбранная — 1, под курсором — 0.5), плавно
var _row_glow: Array[float] = []
var _glow_ms := 0
## Слои HUD, спрятанные на время магазина (как у инвентаря)
var _hidden_layers: Array[CanvasLayer] = []

# ─── ВЁРСТКА ───────────────────────────────────────────────────────────────────
# Всё в координатах макета 1920×1080. _draw() масштабирует их под реальный
# размер окна (_view_scale/_view_offset), мышь пересчитывается обратно.
# Сетка — как у инвентаря героя: панели от y=118 высотой 890, поля по 46
const DESIGN := Vector2(1920, 1080)
## Слой CanvasLayer магазина — выше HUD героя и экранных эффектов (все они 1)
const SHOP_CANVAS_LAYER := 20
const HEADER := Rect2(780, 28, 360, 58)
const LIST_PANEL := Rect2(46, 118, 720, 890)
const LIST_TOP := 196.0
const LIST_BOTTOM := 904.0
const ROW_X := 70.0
const ROW_W := 656.0
const ITEM_H := 76.0
const CARD := Rect2(780, 118, 1094, 890)
const ICON_C := Vector2(1327, 294)
const ICON_BOX := 212.0
const ICON_SZ := 180.0
const NAME_Y := 484.0
const DESC_Y := 640.0
const LORE_SEP_Y := 744.0
const BUY_BTN := Rect2(1097, 934, 460, 56)
const CONFIRM := Rect2(680, 415, 560, 250)

# ─── ПАЛИТРА ───────────────────────────────────────────────────────────────────
# Та же, что у инвентаря, HUD и главного меню (UI/clean_hud.gd): почти чёрные
# полупрозрачные плашки с каймой в 7 % белого, тёплый почти белый текст,
# золото — только выбранное, наведённое и цена
const CleanHud := preload("res://UI/clean_hud.gd")
const HeroSkin := preload("res://Inventory/ui/hero_inventory_skin.gd")
const ProcSkin := preload("res://Inventory/ui/proc_skin.gd")
const PANEL_FILL := Color(0.012, 0.012, 0.012, 0.95)
const C_BORDER := CleanHud.BORDER
const C_GOLD := CleanHud.GOLD
const C_GOLD_HI := CleanHud.GOLD_HI
const C_TEXT := CleanHud.TEXT
const C_TEXT_DIM := CleanHud.TEXT_DIM
const C_LINE := CleanHud.LINE
## Значок души — как у счётчика душ в HUD мага (mage_hud.gd SOUL_ICON)
const C_SOUL := Color(0.6, 0.72, 0.88)
## Плашки: панель, клетка (строка, клетка иконки), кнопка, кнопка под курсором
var _sb_panel: StyleBoxFlat
var _sb_cell: StyleBoxFlat
var _sb_btn: StyleBoxFlat
var _sb_btn_hover: StyleBoxFlat
var _sb_btn_off: StyleBoxFlat
var _font_caps: FontVariation

var _view_scale := 1.0
var _view_offset := Vector2.ZERO

# ─── UI-ЗВУКИ ──────────────────────────────────────────────────────────────────
const UiSounds := preload("res://UI/ui_sounds.gd")
const SOUND_ACCEPT := UiSounds.SELECT
const SOUND_DENIED := UiSounds.ERROR
const SOUND_CHOICE := UiSounds.MOVE
const SOUND_OPEN := UiSounds.OPEN
const SOUND_CLOSE := UiSounds.CLOSE
const SOUND_BUY := preload("res://Sound/shop_sound/sound_buy.mp3")
var _ui_audio: AudioStreamPlayer

func _play_ui_sound(stream: AudioStream) -> void:
	_ui_audio.stream = stream
	_ui_audio.play()

# ─── LIFECYCLE ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Лут на уровне (Levels/loot/loot_item.gd) находит магазин по группе и
	# берёт товары оттуда — лут выдаёт ровно то, что продаётся
	add_to_group("shop_menu")
	# Магазин — экран поверх всего (мир позади затемнён). HUD героя (здоровье,
	# стамина, Одр, быстрые слоты, лут) — тоже CanvasLayer слоя 1 и добавляется
	# позже, поэтому рисовался поверх магазина. Поднимаем слой магазина над ними
	# (а сам HUD на время магазина прячется — _hide_game_hud)
	var shop_layer := get_parent() as CanvasLayer
	if shop_layer and shop_layer.layer < SHOP_CANVAS_LAYER:
		shop_layer.layer = SHOP_CANVAS_LAYER
	items.assign(_knight_items())
	_load_textures()
	set_process(false)
	set_process_input(false)
	# Шрифт инвентаря — антиква с кириллицей и нормальными цифрами
	font_body = CleanHud.font()
	font_title = CleanHud.font()
	# Заглавные подписи — та же антиква с разрядкой (как в главном меню)
	_font_caps = FontVariation.new()
	_font_caps.base_font = CleanHud.font()
	_font_caps.spacing_glyph = 3
	visible = false

	_sb_panel = ProcSkin.CleanU.box(PANEL_FILL, C_BORDER, 6, 10)
	_sb_cell = ProcSkin.CleanU.box(Color(0, 0, 0, 0.32), C_BORDER, 4)
	_sb_btn = ProcSkin.CleanU.box(Color(0, 0, 0, 0.35), Color(C_GOLD, 0.35), 4)
	_sb_btn_hover = ProcSkin.CleanU.box(Color(C_GOLD_HI, 0.07), Color(C_GOLD_HI, 0.7), 4)
	_sb_btn_off = ProcSkin.CleanU.box(Color(0, 0, 0, 0.35), C_BORDER, 4)
	# Края экрана чуть темнее середины — как фон инвентаря (inventory_ui._build_backdrop)
	_vignette = _radial_texture(PackedFloat32Array([0.0, 0.55, 1.0]),
			PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.08), Color(0, 0, 0, 0.45)]))

	_icon_layer = _make_layer()
	_icon_layer.material = HeroSkin.icon_material(1.15)
	_icon_layer.draw.connect(_draw_icons)
	_overlay = _make_layer()
	_overlay.draw.connect(_draw_overlay)

	_ui_audio = AudioStreamPlayer.new()
	_ui_audio.bus = UiSounds.bus()
	add_child(_ui_audio)


## Слой рисования поверх магазина на весь экран (мышь не ловит)
func _make_layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


func _radial_texture(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
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
	# Маг платит душами (его валюта), остальные — золотом. player_gold здесь
	# и дальше — просто "деньги покупателя" в его валюте
	_souls_mode = player.get("collects_souls") == true
	player_gold = player.souls if _souls_mode else player.gold
	_build_items_for(player)
	# Карточка справа сразу показывает первый товар — пустая половина экрана
	# при открытии выглядит как недогруженное окно
	selected_index = 0 if not items.is_empty() else -1
	pending_buy_index = -1
	player.is_in_shop = true
	_opened_at = anim_time
	_play_ui_sound(SOUND_OPEN)

	_row_glow.clear()
	_row_glow.resize(items.size())
	_row_glow.fill(0.0)
	if selected_index >= 0:
		_row_glow[selected_index] = 1.0
	_glow_ms = Time.get_ticks_msec()

	visible = true
	set_process(true)
	set_process_input(true)
	_hide_game_hud(true)

	# Только проявление: за магазином — затемнённый мир на весь экран,
	# масштабировать его вместе с окном нельзя (открылись бы края)
	modulate = Color(1, 1, 1, 0)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)
	_set_level_rain_muffled(true, 0.18)

	queue_redraw()

# Загружаем все PNG заранее — один раз при старте
func _load_textures() -> void:
	for i: int in items.size():
		var path: String = items[i]["icon"] as String
		if ResourceLoader.exists(path):
			# Через общий кеш предметов: крупные PNG (icons_2, 1254 px) уменьшаются
			# один раз, та же текстура, что в сумке и быстром слоте
			items[i]["texture"] = Ability.load_icon(path)
		else:
			items[i]["texture"] = null
			print("ShopMenu: иконка не найдена: ", path)

func _process(delta: float) -> void:
	anim_time     += delta
	scroll_offset  = lerp(scroll_offset, target_scroll, delta * 10.0)
	# Подсветка строк — по реальному времени (Juice может замедлять
	# Engine.time_scale): полный переход за ~0.18 с, как у значков инвентаря
	var now := Time.get_ticks_msec()
	var dt := minf((now - _glow_ms) / 1000.0, 0.1)
	_glow_ms = now
	for i in _row_glow.size():
		var target := 1.0 if i == selected_index else (0.5 if i == hovered_index else 0.0)
		_row_glow[i] = move_toward(_row_glow[i], target, ProcSkin.SheetIcon.SPEED * dt)
	queue_redraw()
	_icon_layer.queue_redraw()
	_overlay.queue_redraw()


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
	_play_ui_sound(SOUND_CLOSE)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.14)
	_set_level_rain_muffled(false, 0.14)
	await tw.finished
	if current_player:
		current_player.is_in_shop = false
	visible = false
	set_process(false)
	set_process_input(false)
	_hide_game_hud(false)


## Пока магазин открыт, игровой HUD (полоски, слоты, счётчики — CanvasLayer
## с layer >= 1) прячется, как у инвентаря героя; при закрытии — обратно
func _hide_game_hud(on: bool) -> void:
	if not on:
		for l in _hidden_layers:
			if is_instance_valid(l):
				l.visible = true
		_hidden_layers.clear()
		return
	var own := get_parent() as CanvasLayer
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var l := n as CanvasLayer
		if l == own or not l.visible or l.layer < 1:
			continue
		l.visible = false
		_hidden_layers.append(l)


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

	# списываем золото (у мага — души)
	if _souls_mode:
		current_player.souls -= price
		player_gold = current_player.souls
	else:
		current_player.gold -= price
		player_gold = current_player.gold

	# создаём способность и добавляем в инвентарь
	var ability_class = ability_class_map[item_name]
	var ability_instance: Ability = ability_class.new()
	current_player.inventory_ui.add_item(ability_instance)

	selected_index = index
	print("Куплено: ", item_name, " за ", price)

# ─── MAIN DRAW ─────────────────────────────────────────────────────────────────
# Вид — как у инвентаря героя (тема CLEAN, Inventory/ui/hero_inventory_skin.gd):
# мир позади затемнён, поверх — почти чёрные полупрозрачные плашки с едва
# заметной каймой, тонкие гаснущие черты, золото — только у выбранного,
# наведённого и у цены. Иконки — слой _icon_layer, подтверждение — _overlay
func _draw() -> void:
	# Макет 1920×1080 вписывается в окно целиком, по центру
	_view_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_view_offset = (size - DESIGN * _view_scale) * 0.5
	# Мир за магазином — затемнён так же, как за инвентарём
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, HeroSkin.CLEAN["world_dim"]))
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
	draw_set_transform(_view_offset, 0.0, Vector2(_view_scale, _view_scale))

	_draw_header()
	_draw_list_panel()
	_draw_card()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ─── ОБЩИЕ ДЕТАЛИ ──────────────────────────────────────────────────────────────

## Тонкая черта, гаснущая к концам (FadeLine / ProcDivider инвентаря)
func _fade_line(ci: CanvasItem, x: float, w: float, y: float, col := C_LINE) -> void:
	var c0 := Color(col, 0.0)
	ci.draw_polyline_colors(PackedVector2Array([Vector2(x, y), Vector2(x + w * 0.18, y),
			Vector2(x + w * 0.82, y), Vector2(x + w, y)]), PackedColorArray([c0, col, col, c0]), 1.0)


## Заголовок колонки: золотистая подпись заглавными, под ней короткая
## золотая черта (ProcPlaque инвентаря)
func _plaque(ci: CanvasItem, text: String, cx: float, y: float) -> void:
	_text_on(ci, Vector2(cx - 200.0, y), tr(text).to_upper(), 17, C_GOLD, _font_caps, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
	ci.draw_line(Vector2(cx - 50.0, y + 14.0), Vector2(cx + 50.0, y + 14.0), Color(C_GOLD, 0.35), 1.0)


## Золотая кромка выбранной/наведённой клетки с мягким ореолом внутрь
## (HeroCell инвентаря); h — сила подсветки 0..1
func _gold_edge(ci: CanvasItem, r: Rect2, h: float) -> void:
	if h <= 0.0:
		return
	for k in 6:
		ci.draw_rect(r.grow(-2.0 - k * 2.0), Color(C_GOLD_HI, 0.045 * h), false, 2.0)
	ci.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), Color(C_GOLD_HI, 0.85 * h), false, 1.0)
	ci.draw_rect(r.grow(-3.0), Color(C_GOLD_HI, 0.05 * h))


## Кнопка — плашка с золотистой каймой; под курсором чуть светлеет, текст
## ярко-золотой; недоступная — серая кайма и серый текст
func _button(ci: CanvasItem, r: Rect2, label: String, hover: bool, enabled := true) -> void:
	var sb := _sb_btn_off if not enabled else (_sb_btn_hover if hover else _sb_btn)
	ci.draw_style_box(sb, r)
	var col := C_TEXT_DIM if not enabled else (C_GOLD_HI if hover else C_TEXT)
	_text_on(ci, Vector2(r.position.x, r.get_center().y + 8.0), label, 22, col, null,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Сумма в валюте покупателя: золото у рыцаря и лучницы, души у мага
func _money(n: int) -> String:
	return tr("%d душ") % n if _souls_mode else "%d G" % n


## Значок валюты линиями, как в HUD (clean_hud.gd Glyph): монета — золотая,
## душа (маг) — бледно-голубая капля пламени. Не хватает — серый
func _draw_coin(c: Vector2, r: float, can_afford := true) -> void:
	var k := r / 8.0
	if _souls_mode:
		var col := C_SOUL if can_afford else C_TEXT_DIM
		var out := PackedVector2Array([c + Vector2(0, -11) * k])
		for i in range(17):
			var a := -PI * 0.15 + (PI * 1.3) * float(i) / 16.0
			out.append(c + (Vector2(cos(a), sin(a)) * 7.0 + Vector2(0, 3)) * k)
		out.append(c + Vector2(0, -11) * k)
		draw_polyline(out, col, 1.6 * k, true)
		draw_circle(c + Vector2(0, 4) * k, 2.2 * k, Color(col, 0.8))
		return
	var gc := C_GOLD if can_afford else C_TEXT_DIM
	draw_arc(c, 8.0 * k, 0, TAU, 28, gc, 1.6 * k, true)
	draw_arc(c, 4.5 * k, 0, TAU, 20, Color(gc, 0.6), 1.0 * k, true)


## Текст с тонкой тенью (как Label в clean_hud.label) — читается на любом фоне
func _text_on(ci: CanvasItem, pos: Vector2, s: String, sz: int, col: Color, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	# Перевод — здесь: подписи, названия и строки описаний (tr не трогает
	# уже переведённое и строки без перевода)
	var f := font if font else font_body
	var t := tr(s)
	ci.draw_string(f, pos + Vector2(1, 1), t, align, width, sz, Color(0, 0, 0, 0.75 * col.a))
	ci.draw_string(f, pos, t, align, width, sz, col)


func _text(pos: Vector2, s: String, sz: int, col: Color, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_text_on(self, pos, s, sz, col, font, align, width)


func _text_w(s: String, sz: int, font: Font = null) -> float:
	return (font if font else font_body).get_string_size(tr(s), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


func _glow_of(i: int) -> float:
	return _row_glow[i] if i < _row_glow.size() else 0.0


# ─── ЗАГОЛОВОК ─────────────────────────────────────────────────────────────────
## Плашка по центру сверху, как полоса вкладок инвентаря: значок-сундук и
## «МАГАЗИН» золотом (это открытая «вкладка»); справа — подсказка выхода
func _draw_header() -> void:
	var r := HEADER
	draw_style_box(ProcSkin.CleanU.box(PANEL_FILL, C_BORDER, 6, 8), r)
	var label := tr("МАГАЗИН")
	var tw := _text_w(label, 22, _font_caps)
	var icon_px := 30
	var x0 := r.get_center().x - (icon_px + 14.0 + tw) * 0.5
	var tex := ProcSkin.SheetIcon.texture_for("chest", icon_px)
	if tex:
		draw_texture_rect(tex, Rect2(x0, r.get_center().y - icon_px * 0.5 - 1.0, icon_px, icon_px), false, C_GOLD)
	_text(Vector2(x0 + icon_px + 14.0, r.get_center().y + 8.0), label, 22, C_GOLD, _font_caps)
	draw_line(Vector2(r.get_center().x - 60.0, r.end.y - 2.0), Vector2(r.get_center().x + 60.0, r.end.y - 2.0),
			Color(C_GOLD, 0.8), 1.5)


# ─── ЛЕВАЯ ПАНЕЛЬ: СПИСОК ──────────────────────────────────────────────────────
func _draw_list_panel() -> void:
	var p := LIST_PANEL
	draw_style_box(_sb_panel, p)
	# Подписи колонок — серые заглавные, под ними тонкая черта
	var hy := p.position.y + 50.0
	_text(Vector2(ROW_X + 8.0, hy), tr("ПРЕДМЕТ"), 15, C_TEXT_DIM, _font_caps)
	_text(Vector2(ROW_X, hy), tr("ЦЕНА"), 15, C_TEXT_DIM, _font_caps, HORIZONTAL_ALIGNMENT_RIGHT, ROW_W - 18.0)
	_fade_line(self, p.position.x + 20.0, p.size.x - 40.0, hy + 16.0)

	for i: int in items.size():
		var r := _row_rect(i)
		if _row_visible(r):
			_draw_row(i, r)
	_draw_scrollbar()

	# Низ панели: тонкая черта, «У вас есть» и деньги покупателя
	var by := p.end.y - 70.0
	_fade_line(self, p.position.x + 20.0, p.size.x - 40.0, by)
	var ty := by + 44.0
	_text(Vector2(ROW_X + 6.0, ty), "У вас есть:", 18, C_TEXT_DIM)
	var money := _money(player_gold)
	var mw := _text_w(money, 24)
	var right := ROW_X + ROW_W - 10.0
	_text(Vector2(right - mw, ty + 1.0), money, 24, C_TEXT)
	_draw_coin(Vector2(right - mw - 20.0, ty - 7.0), 8.0)


func _draw_row(i: int, r: Rect2) -> void:
	var item: Dictionary = items[i]
	var g := _glow_of(i)
	var can_afford := player_gold >= (item["price"] as int)
	var maxed := _is_maxed(item)

	# Строка — тёмная полупрозрачная клетка; выбранная и наведённая —
	# золотая кромка (наведённая вполсилы)
	draw_style_box(_sb_cell, r)
	_gold_edge(self, r, g)

	# Клетка иконки (сама иконка — на слое _icon_layer)
	var ir := _row_icon_rect(r)
	draw_style_box(_sb_cell, ir.grow(3.0))
	if item["texture"] == null:
		_draw_icon_placeholder(ir.get_center().x, ir.get_center().y, ir.size.x * 0.4,
				item["name"] as String, item["col"] as Color, g > 0.0)

	var name_col := C_TEXT if g > 0.0 else Color(C_TEXT, 0.82)
	if not can_afford and not maxed:
		name_col = C_TEXT_DIM
	_text(Vector2(ir.end.x + 22.0, r.get_center().y + 7.0), item["name"] as String, 21, name_col)

	# Цена справа: значок валюты и число золотом. Не хватает — всё серое
	var right := r.end.x - 18.0
	var cy := r.get_center().y
	if maxed:
		_text(Vector2(r.position.x, cy + 6.0), "в сумке", 17, C_TEXT_DIM, null,
				HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18.0)
		return
	var price_str := str(item["price"])
	var pw := _text_w(price_str, 23)
	_text(Vector2(right - pw, cy + 8.0), price_str, 23, C_GOLD if can_afford else C_TEXT_DIM)
	_draw_coin(Vector2(right - pw - 17.0, cy), 7.0, can_afford)


func _row_icon_rect(r: Rect2) -> Rect2:
	var isz := 52.0
	return Rect2(r.position.x + 11.0, r.get_center().y - isz * 0.5, isz, isz)


func _draw_scrollbar() -> void:
	var total_h := float(items.size()) * ITEM_H
	var visible_h := LIST_BOTTOM - LIST_TOP
	if total_h <= visible_h:
		return
	var bar_x := ROW_X + ROW_W + 12.0
	draw_rect(Rect2(bar_x, LIST_TOP, 1.0, visible_h), C_LINE)
	var thumb_h: float = maxf(30.0, visible_h * (visible_h / total_h))
	var thumb_y: float = LIST_TOP + (scroll_offset / (total_h - visible_h)) * (visible_h - thumb_h)
	draw_rect(Rect2(bar_x - 1.0, thumb_y, 3.0, thumb_h), Color(1, 1, 1, 0.22))


# ─── ПРАВАЯ ПАНЕЛЬ: КАРТОЧКА ТОВАРА ────────────────────────────────────────────
## Как карточка предмета в инвентаре: иконка в тёмной клетке сверху, под
## ней название, принадлежность, цена; ниже — описание и предание абзацами,
## внизу кнопка
func _draw_card() -> void:
	var cp := CARD
	draw_style_box(_sb_panel, cp)

	if selected_index < 0 or selected_index >= items.size():
		_text(Vector2(cp.position.x, cp.get_center().y), "Выберите предмет", 22, C_TEXT_DIM, null,
				HORIZONTAL_ALIGNMENT_CENTER, cp.size.x)
		return

	var item: Dictionary = items[selected_index]
	var can_afford := player_gold >= (item["price"] as int)
	var maxed := _is_maxed(item)
	var cx := cp.get_center().x
	var left := cp.position.x + 60.0
	var width := cp.size.x - 120.0

	draw_style_box(ProcSkin.CleanU.box(Color(0, 0, 0, 0.3), C_BORDER, 6), _card_icon_rect().grow((ICON_BOX - ICON_SZ) * 0.5))
	if item["texture"] == null:
		_draw_icon_placeholder(ICON_C.x, ICON_C.y, ICON_SZ * 0.35, item["name"] as String, item["col"] as Color, true)

	_text(Vector2(left, NAME_Y), item["name"] as String, 34, C_TEXT, font_title, HORIZONTAL_ALIGNMENT_CENTER, width)
	var y := NAME_Y + 34.0
	if item.has("subtitle"):
		_text(Vector2(left, y), item["subtitle"] as String, 18, C_TEXT_DIM, null, HORIZONTAL_ALIGNMENT_CENTER, width)
		y += 36.0
	else:
		y += 6.0

	# Цена: значок и сумма золотом; не хватает — серым
	var price_str := _money(item["price"] as int)
	var pw := _text_w(price_str, 24)
	_draw_coin(Vector2(cx - pw * 0.5 - 6.0, y - 8.0), 8.0, can_afford)
	_text(Vector2(cx - pw * 0.5 + 12.0, y), price_str, 24, C_GOLD if can_afford else C_TEXT_DIM)

	_fade_line(self, cp.position.x + 30.0, cp.size.x - 60.0, DESC_Y - 46.0)

	# Описание
	# Переводим целиком до разбивки: ключ перевода — с переносами \n
	var desc_lines: PackedStringArray = tr(item["description"] as String).split("\n")
	for li in desc_lines.size():
		_text(Vector2(left, DESC_Y + li * 32.0), desc_lines[li], 20, C_TEXT, null,
				HORIZONTAL_ALIGNMENT_CENTER, width)

	# Предание — ниже описания, но не выше своей строки на макете
	var sep_y := maxf(LORE_SEP_Y, DESC_Y + desc_lines.size() * 32.0 + 30.0)
	var cap := tr("Предание")
	var cw := _text_w(cap, 17)
	_text(Vector2(left, sep_y), cap, 17, C_TEXT_DIM, null, HORIZONTAL_ALIGNMENT_CENTER, width)
	_fade_line(self, cx - cw * 0.5 - 220.0, 200.0, sep_y - 6.0)
	_fade_line(self, cx + cw * 0.5 + 20.0, 200.0, sep_y - 6.0)
	var lore_lines: PackedStringArray = tr(item["lore"] as String).split("\n")
	for li in lore_lines.size():
		_text(Vector2(left, sep_y + 40.0 + li * 28.0), lore_lines[li], 18, C_TEXT_DIM, null,
				HORIZONTAL_ALIGNMENT_CENTER, width)

	_draw_buy_button(can_afford, maxed)


func _card_icon_rect() -> Rect2:
	return Rect2(ICON_C - Vector2(ICON_SZ, ICON_SZ) * 0.5, Vector2(ICON_SZ, ICON_SZ))


func _draw_buy_button(can_afford: bool, maxed: bool) -> void:
	var enabled := can_afford and not maxed
	var label := "[E]  Купить"
	if maxed:
		label = "Уже в сумке"
	elif not can_afford:
		label = "Недостаточно душ" if _souls_mode else "Недостаточно золота"
	_button(self, BUY_BTN, label, _buy_hover and enabled, enabled)


# ─── ИКОНКИ ────────────────────────────────────────────────────────────────────
## Слой _icon_layer с шейдером иконок инвентаря (HeroSkin.icon_material):
## середина картинки без своей рамки, мягкие края, яркость 1.15. Не под
## курсором и не выбранная — чуть темнее
func _draw_icons() -> void:
	if not visible:
		return
	var ci := _icon_layer
	ci.draw_set_transform(_view_offset, 0.0, Vector2(_view_scale, _view_scale))
	for i: int in items.size():
		var r := _row_rect(i)
		var tex: Texture2D = items[i]["texture"] as Texture2D
		if tex and _row_visible(r):
			var d := 0.8 + 0.2 * minf(_glow_of(i) * 2.0, 1.0)
			ci.draw_texture_rect(tex, _row_icon_rect(r), false, Color(d, d, d))
	if selected_index >= 0 and selected_index < items.size():
		var tex: Texture2D = items[selected_index]["texture"] as Texture2D
		if tex:
			ci.draw_texture_rect(tex, _card_icon_rect(), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ─── ПОДТВЕРЖДЕНИЕ ПОКУПКИ ─────────────────────────────────────────────────────
## Слой _overlay — поверх иконок: экран темнеет, по центру плашка с вопросом
func _draw_overlay() -> void:
	if not visible or pending_buy_index < 0:
		return
	var ci := _overlay
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	ci.draw_set_transform(_view_offset, 0.0, Vector2(_view_scale, _view_scale))
	var item: Dictionary = items[pending_buy_index]
	ci.draw_style_box(_sb_panel, CONFIRM)
	_plaque(ci, "Подтверждение", CONFIRM.get_center().x, CONFIRM.position.y + 48.0)
	_text_on(ci, Vector2(CONFIRM.position.x, CONFIRM.position.y + 118.0),
			tr("Купить «%s» за %s?") % [tr(item["name"]), _money(item["price"] as int)], 21, C_TEXT, null,
			HORIZONTAL_ALIGNMENT_CENTER, CONFIRM.size.x)

	var btns := _confirm_buttons()
	var labels := ["[E]  Да", "[Esc]  Нет"]
	for i in 2:
		_button(ci, btns[i], labels[i], _confirm_hover == i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ─── ЗАГЛУШКА (если PNG не найден) ────────────────────────────────────────────
# Серый кружок с первой буквой названия предмета
func _draw_icon_placeholder(cx: float, cy: float, r: float, item_name: String, _col: Color, bright: bool) -> void:
	var col := C_TEXT if bright else C_TEXT_DIM
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 32, Color(col, 0.6), 1.5, true)
	if item_name.length() > 0:
		var letter: String = tr(item_name).substr(0, 1).to_upper()
		draw_string(font_title, Vector2(cx - r, cy + r * 0.35), letter, HORIZONTAL_ALIGNMENT_CENTER,
				r * 2.0, int(r * 1.0), col)
