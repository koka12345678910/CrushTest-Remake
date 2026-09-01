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

## portrait_sheet + portrait_region — кадр из листа Idle для карточки выбора.
## Ряд y=256 во всех трёх листах — это стойка лицом к камере (Idle_Down);
## отдельных портретов у персонажей пока нет, а вырезать кадр из уже
## существующего спрайт-листа дешевле, чем рисовать их
const DATA := {
	KNIGHT: {
		"name": "РЫЦАРЬ",
		"scene": "res://Player_scene/player.tscn",
		"tagline": "Меч и щит",
		"description": "Парирование, блок, серии ударов.\nЕдинственный, кто уже умеет всё.",
		"color": Color(0.85, 0.72, 0.35),
		"portrait_sheet": "res://Character/CharacterAnimationAssets/Knight_Character/IDLE/Idle.png",
		"portrait_region": Rect2(0, 256, 128, 128),
	},
	ARCHER: {
		"name": "ЛУЧНИК",
		"scene": "res://Player_scene/archer.tscn",
		"tagline": "Лук и дистанция",
		"description": "Бьёт издалека, но хрупок вблизи.\nВ разработке.",
		"color": Color(0.55, 0.78, 0.45),
		"portrait_sheet": "res://Character/Archer/Idle.png",
		"portrait_region": Rect2(0, 256, 128, 128),
	},
	MAGE: {
		"name": "МАГ",
		"scene": "res://Player_scene/mage.tscn",
		"tagline": "Посох и руны",
		"description": "Заклинания вместо стали.\nВ разработке.",
		"color": Color(0.55, 0.6, 0.9),
		"portrait_sheet": "res://Character/Mage/Idle.png",
		"portrait_region": Rect2(0, 256, 128, 128),
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
