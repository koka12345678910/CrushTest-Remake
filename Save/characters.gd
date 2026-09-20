extends Node
## Characters.gd — реестр играбельных персонажей (автозагрузка).
##
## Единственное место, где перечислены персонажи и их сцены. Добавить нового =
## дописать запись в DATA и его id в ORDER; ни меню выбора, ни спавнер, ни
## система сохранений об этом знать не обязаны — они читают реестр.
##
## Сам по себе ничего не спавнит: сцену по id достаёт get_scene(), а кто и
## когда её создаёт — дело player_spawner.gd на уровне.

const KNIGHT := "knight"
const ARCHER := "archer"
const MAGE := "mage"

## Порядок карточек в меню выбора. Отдельно от DATA, потому что порядок ключей
## в словаре — не то, на что стоит опираться при отрисовке UI
const ORDER: Array[String] = [KNIGHT, ARCHER, MAGE]

## Порядок строк со статами на экране выбора героя. ВАЖНО: пока это витрина,
## а не механика — в бою по-прежнему у всех троих одинаковые 100 hp / 100
## стамины (character_base.max_health). Значения описывают задуманные роли
## классов; когда появятся реальные характеристики, брать их надо будет
## отсюда же, а не заводить второй источник правды
const STAT_ORDER: Array[String] = [
	"Health", "Stamina", "Strength", "Dexterity", "Intelligence", "Faith",
]

## Иконки статов — имена глифов из GlyphIcon.gd
const STAT_ICONS := {
	"Health": "heart",
	"Stamina": "bolt",
	"Strength": "fist",
	"Dexterity": "feather",
	"Intelligence": "book",
	"Faith": "flame",
}

## portrait_sheet + portrait_region — ряд листа Idle. Ряд y=256 во всех трёх
## листах это стойка лицом к камере (Idle_Down), 15 кадров по 128×128:
## отдельных портретов у персонажей нет, а экран выбора крутит этот же ряд
## как анимацию (SpriteSheetAnimation.gd). idle_frame_time совпадает с
## длительностью кадра в самих сценах персонажей
const DATA := {
	KNIGHT: {
		"name": "WARRIOR",
		"scene": "res://Player_scene/player.tscn",
		"tagline": "Sword and Shield",
		"description": "A disciplined fighter, trained in the art of war. The warrior relies on strength, endurance and unwavering will.",
		"quote": "Some are born with a sword,\nothers are forged by it.",
		"color": Color(0.85, 0.72, 0.35),
		"icon": "shield",
		"portrait_sheet": "res://Character/CharacterAnimationAssets/Knight_Character/IDLE/Idle.png",
		"portrait_region": Rect2(0, 256, 128, 128),
		"idle_frame_time": 0.1,
		"stats": {
			"Health": 0.85, "Stamina": 0.7, "Strength": 0.9,
			"Dexterity": 0.45, "Intelligence": 0.3, "Faith": 0.5,
		},
	},
	ARCHER: {
		"name": "RANGER",
		"scene": "res://Player_scene/archer.tscn",
		"tagline": "Bow and Distance",
		"description": "A patient hunter who ends a fight before it begins. Deadly at range, fragile once the distance closes.",
		"quote": "The arrow does not argue.\nIt arrives.",
		"color": Color(0.55, 0.78, 0.45),
		"icon": "bow",
		"portrait_sheet": "res://Character/Archer/Idle.png",
		"portrait_region": Rect2(0, 256, 128, 128),
		"idle_frame_time": 0.2,
		"stats": {
			"Health": 0.5, "Stamina": 0.85, "Strength": 0.45,
			"Dexterity": 0.95, "Intelligence": 0.5, "Faith": 0.4,
		},
	},
	MAGE: {
		"name": "MAGE",
		"scene": "res://Player_scene/mage.tscn",
		"tagline": "Staff and Runes",
		"description": "A scholar of the old runes, trading steel for arcane fire. Frail of body, overwhelming in force.",
		"quote": "Every rune remembers\nthe hand that carved it.",
		"color": Color(0.55, 0.6, 0.9),
		"icon": "rune",
		"portrait_sheet": "res://Character/Mage/Idle.png",
		"portrait_region": Rect2(0, 256, 128, 128),
		"idle_frame_time": 0.2,
		"stats": {
			"Health": 0.35, "Stamina": 0.5, "Strength": 0.3,
			"Dexterity": 0.55, "Intelligence": 0.95, "Faith": 0.85,
		},
	},
}

## Кем играем, если сейв не загружен — например, когда уровень запускают прямо
## из редактора (F6), минуя главное меню. Без этого запаса отладочный запуск
## уровня падал бы в пустую сцену без персонажа
const FALLBACK := KNIGHT


func exists(id: String) -> bool:
	return DATA.has(id)


func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA[FALLBACK])


## Не get_name() — так называется метод самой Node, перекрывать его нельзя
func display_name(id: String) -> String:
	return get_data(id).get("name", "?")


func get_color(id: String) -> Color:
	return get_data(id).get("color", Color.WHITE)


func get_scene(id: String) -> PackedScene:
	var path: String = get_data(id).get("scene", "")
	if path == "" or not ResourceLoader.exists(path):
		push_error("[Characters] Нет сцены для персонажа '%s': %s" % [id, path])
		return null
	return load(path) as PackedScene


## Портрет собирается в рантайме из спрайт-листа — отдельных файлов-портретов
## нет. Вернёт null, если лист не найден; вызывающий рисует заглушку
func get_portrait(id: String) -> Texture2D:
	var d := get_data(id)
	var sheet_path: String = d.get("portrait_sheet", "")
	if sheet_path == "" or not ResourceLoader.exists(sheet_path):
		return null
	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = d.get("portrait_region", Rect2(0, 256, 128, 128))
	return atlas


## Лист целиком — для покадровой анимации на экране выбора. Ряд и размер
## кадра берутся из portrait_region, число кадров считается по ширине листа
func get_idle_sheet(id: String) -> Texture2D:
	var sheet_path: String = get_data(id).get("portrait_sheet", "")
	if sheet_path == "" or not ResourceLoader.exists(sheet_path):
		return null
	return load(sheet_path) as Texture2D


func get_idle_region(id: String) -> Rect2:
	return get_data(id).get("portrait_region", Rect2(0, 256, 128, 128))


func get_idle_frame_time(id: String) -> float:
	return get_data(id).get("idle_frame_time", 0.1)


## 0..1 — насколько заполнена полоска стата. Незнакомый стат = пусто, чтобы
## добавление имени в STAT_ORDER не роняло экран выбора
func get_stat(id: String, stat: String) -> float:
	var stats: Dictionary = get_data(id).get("stats", {})
	return stats.get(stat, 0.0)
