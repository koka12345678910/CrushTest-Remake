extends Node
## SaveManager.gd — слоты сохранения (автозагрузка).
##
## Формат тот же, что у настроек (ConfigFile, см. GameSettings.gd) — текстовый,
## читаемый глазами, легко чинится руками при отладке. Каждый слот — отдельный
## файл user://saves/slot_N.cfg, чтобы повреждение одного не уносило остальные.
##
## ПЕРСОНАЖ ВЫБИРАЕТСЯ ОДИН РАЗ. character_id пишется при создании слота и
## дальше только читается — во всём проекте нет кода, который меняет его у
## существующего сейва. Захотел другого героя — заводи новый слот.

signal slot_changed

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1

## Какой слот сейчас в игре. -1 = ни один (уровень запустили напрямую из
## редактора, минуя меню) — тогда играем за Characters.FALLBACK и ничего не пишем
var current_slot := -1

var character_id := ""
var gold := 0
var playtime := 0.0
var created_at := 0
## Милли, а не целые секунды: по этой метке кнопка "ПРОДОЛЖИТЬ" выбирает
## последний сейв, и с точностью до секунды два сохранения подряд оказывались
## бы неразличимы. Именно int, а не float: ConfigFile пишет дробные числа с
## урезанной точностью и из 1787913753.0 на диске получалось 1787910000.0 —
## то есть промах почти на час
var last_played_ms := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.cfg" % [SAVE_DIR, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func is_loaded() -> bool:
	return current_slot >= 0


func has_any_slot() -> bool:
	for i in SLOT_COUNT:
		if slot_exists(i):
			return true
	return false


## Первый свободный слот или -1, если все заняты
func first_free_slot() -> int:
	for i in SLOT_COUNT:
		if not slot_exists(i):
			return i
	return -1


## Слот, в который играли последним — для кнопки "ПРОДОЛЖИТЬ". -1, если сейвов нет
func last_recent_slot() -> int:
	var best := -1
	var best_time := -1
	for i in SLOT_COUNT:
		var info := peek_slot(i)
		if info.is_empty():
			continue
		var t: int = info.get("last_played_ms", 0)
		if t > best_time:
			best_time = t
			best = i
	return best


## Прочитать слот, НЕ делая его текущим — для списка сохранений в меню.
## Пустой словарь = слота нет
func peek_slot(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return {}
	return {
		"character_id": cfg.get_value("save", "character_id", Characters.FALLBACK),
		"gold": cfg.get_value("progress", "gold", 0),
		"playtime": cfg.get_value("progress", "playtime", 0.0),
		"created_at": cfg.get_value("save", "created_at", 0),
		"last_played_ms": cfg.get_value("save", "last_played_ms", 0),
	}


# ----------------------------------------------------------
# СОЗДАНИЕ / ЗАГРУЗКА / УДАЛЕНИЕ
# ----------------------------------------------------------

## Новое прохождение. Единственное место, где вообще задаётся character_id
func create_slot(slot: int, new_character_id: String) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		push_error("[SaveManager] Слот вне диапазона: %d" % slot)
		return false
	if not Characters.exists(new_character_id):
		push_error("[SaveManager] Неизвестный персонаж: %s" % new_character_id)
		return false

	current_slot = slot
	character_id = new_character_id
	gold = 0
	playtime = 0.0
	created_at = int(Time.get_unix_time_from_system())
	last_played_ms = int(Time.get_unix_time_from_system() * 1000.0)
	save()
	slot_changed.emit()
	return true


func load_slot(slot: int) -> bool:
	var info := peek_slot(slot)
	if info.is_empty():
		return false
	current_slot = slot
	character_id = info["character_id"]
	gold = info["gold"]
	playtime = info["playtime"]
	created_at = info["created_at"]
	last_played_ms = info["last_played_ms"]
	slot_changed.emit()
	return true


func save() -> void:
	if not is_loaded():
		return  # играем без слота (запуск уровня из редактора) — писать некуда
	last_played_ms = int(Time.get_unix_time_from_system() * 1000.0)
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", SAVE_VERSION)
	cfg.set_value("save", "character_id", character_id)
	cfg.set_value("save", "created_at", created_at)
	cfg.set_value("save", "last_played_ms", last_played_ms)
	cfg.set_value("progress", "gold", gold)
	cfg.set_value("progress", "playtime", playtime)
	cfg.save(slot_path(current_slot))


func delete_slot(slot: int) -> void:
	if not slot_exists(slot):
		return
	# Путь user:// отдаём как есть: globalize_path в экспортированной сборке
	# указывает не туда, куда в редакторе, а DirAccess понимает user:// сам
	DirAccess.remove_absolute(slot_path(slot))
	if current_slot == slot:
		unload()
	slot_changed.emit()


## Выгрузить текущий слот из памяти (выход в меню), файл при этом остаётся
func unload() -> void:
	current_slot = -1
	character_id = ""
	gold = 0
	playtime = 0.0
	last_played_ms = 0


# ----------------------------------------------------------
# СВЯЗЬ С ПЕРСОНАЖЕМ
# ----------------------------------------------------------

## Кем играть прямо сейчас. Слота может не быть (F6 по уровню в редакторе) —
## тогда отдаём персонажа по умолчанию, чтобы отладочный запуск работал
func get_character_id() -> String:
	if character_id != "" and Characters.exists(character_id):
		return character_id
	return Characters.FALLBACK


## Перелить сохранённый прогресс в только что заспавненного персонажа.
## has-проверки, а не прямое присваивание: у лучника и мага пока нет ни золота,
## ни остальных полей рыцаря, и обращение к ним уронило бы спавн
func apply_to(character: Node) -> void:
	if not is_loaded():
		return
	if "gold" in character:
		character.gold = gold


## Забрать прогресс из персонажа и записать на диск
func capture_from(character: Node) -> void:
	if not is_loaded() or not is_instance_valid(character):
		return
	if "gold" in character:
		gold = character.gold
	save()
