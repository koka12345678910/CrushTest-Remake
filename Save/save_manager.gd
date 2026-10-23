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
var skill_points := 0
var skill_progress := 0
## id открытых узлов дерева навыков (см. Save/skill_trees.gd,
## Player_scene/player.gd::unlocked_skills) — те же id, что использует
## персонаж, копия хранится тут для сейва, тот же контракт, что у gold
var unlocked_skills: Array = []
var playtime := 0.0
var created_at := 0
## Милли, а не целые секунды: по этой метке кнопка "ПРОДОЛЖИТЬ" выбирает
## последний сейв, и с точностью до секунды два сохранения подряд оказывались
## бы неразличимы. Именно int, а не float: ConfigFile пишет дробные числа с
## урезанной точностью и из 1787913753.0 на диске получалось 1787910000.0 —
## то есть промах почти на час
var last_played_ms := 0
## Подобранный лут (Levels/loot/loot_item.gd): id находок, которые больше не
## появляются. id = путь сцены уровня + путь узла находки в ней
var taken_loot: Array = []
## Содержимое сумки: имя способности (Ability.ability_name) -> сколько штук.
## has_inventory = false — сумку ещё ни разу не сохраняли (новый слот): тогда
## у героя остаются стартовые предметы, а не пустая сумка
var inventory: Dictionary = {}
var has_inventory := false
## Книга заклинаний рыцаря (Player_scene/magic/knight_magic.gd) — имена
## выученных благословений
var spells: Array = []


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
		"skill_points": cfg.get_value("progress", "skill_points", 0),
		"skill_progress": cfg.get_value("progress", "skill_progress", 0),
		"unlocked_skills": cfg.get_value("progress", "unlocked_skills", []),
		"playtime": cfg.get_value("progress", "playtime", 0.0),
		"created_at": cfg.get_value("save", "created_at", 0),
		"last_played_ms": cfg.get_value("save", "last_played_ms", 0),
		"taken_loot": cfg.get_value("world", "taken_loot", []),
		"inventory": cfg.get_value("progress", "inventory", {}),
		"has_inventory": cfg.has_section_key("progress", "inventory"),
		"spells": cfg.get_value("progress", "spells", []),
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
	skill_points = 0
	skill_progress = 0
	unlocked_skills = []
	playtime = 0.0
	created_at = int(Time.get_unix_time_from_system())
	last_played_ms = int(Time.get_unix_time_from_system() * 1000.0)
	taken_loot = []
	inventory = {}
	has_inventory = false
	spells = []
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
	skill_points = info["skill_points"]
	skill_progress = info["skill_progress"]
	unlocked_skills = info["unlocked_skills"]
	playtime = info["playtime"]
	created_at = info["created_at"]
	last_played_ms = info["last_played_ms"]
	taken_loot = info["taken_loot"]
	inventory = info["inventory"]
	has_inventory = info["has_inventory"]
	spells = info["spells"]
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
	cfg.set_value("progress", "skill_points", skill_points)
	cfg.set_value("progress", "skill_progress", skill_progress)
	cfg.set_value("progress", "unlocked_skills", unlocked_skills)
	cfg.set_value("progress", "playtime", playtime)
	if has_inventory:
		cfg.set_value("progress", "inventory", inventory)
	cfg.set_value("world", "taken_loot", taken_loot)
	cfg.set_value("progress", "spells", spells)
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
	skill_points = 0
	skill_progress = 0
	unlocked_skills = []
	playtime = 0.0
	last_played_ms = 0
	taken_loot = []
	inventory = {}
	has_inventory = false
	spells = []


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
	if "skill_points" in character:
		character.skill_points = skill_points
	if "skill_progress" in character:
		character.skill_progress = skill_progress
	if "unlocked_skills" in character:
		# unlocked_skills на персонаже — typed Array[String]; присваивание
		# обычного (нетипизированного) Array через динамическое свойство
		# (character типизирован как Node, а не как player.gd) НЕ делает
		# неявную конвертацию и падает с "Invalid assignment... type Array" —
		# assign() внутрь уже типизированного массива конвертирует по-честному
		var typed_ids: Array[String] = []
		typed_ids.assign(unlocked_skills)
		character.unlocked_skills = typed_ids
		# _ready() уже отработал к этому моменту (apply_to зовётся отложенно
		# из player_spawner.gd) и успел пересчитать бонусы на пустом
		# unlocked_skills — пересчитываем ещё раз, теперь по-настоящему
		if character.has_method("recompute_skill_modifiers"):
			character.recompute_skill_modifiers()
	_restore_inventory(character)
	var magic = character.get("magic")
	if magic:
		for spell_name in spells:
			magic.learn(spell_name)


## Сумка: стартовые предметы героя заменяем сохранённым содержимым. Раньше
## сумка не сохранялась вовсе — купленное и найденное пропадало при перезапуске
func _restore_inventory(character: Node) -> void:
	if not has_inventory:
		return
	var inv = character.get("inventory_system")
	if inv == null:
		return
	var classes := _ability_classes()
	if classes.is_empty():
		push_warning("[SaveManager] Нет магазина на уровне — сумку восстановить не из чего")
		return
	inv.clear()
	for item_name in inventory:
		var cls = classes.get(item_name)
		if cls == null:
			push_warning("[SaveManager] Неизвестный предмет в сейве: %s" % item_name)
			continue
		inv.add_item(cls.new(), int(inventory[item_name]))
	# Быстрые слоты заполнены стартовыми предметами — убираем те, которых в
	# сумке больше нет (иначе слот висел бы пустым до первого нажатия)
	var slots = character.get("ability_system")
	if slots != null:
		for i in range(slots.abilities.size() - 1, -1, -1):
			if not inv.has_charges(slots.abilities[i].ability_name):
				slots.remove_ability(i)


## ability_name -> класс способности. Источник — каталог магазина
## (Shop/shop_menu.gd ability_class_map): всё, что может лежать в сумке, там есть
func _ability_classes() -> Dictionary:
	var out := {}
	var shop := get_tree().get_first_node_in_group("shop_menu")
	if shop == null:
		return out
	for cls in shop.ability_class_map.values():
		var a: Ability = cls.new()
		out[a.ability_name] = cls
	return out


# ----------------------------------------------------------
# ЛУТ
# ----------------------------------------------------------

func is_loot_taken(id: String) -> bool:
	return id in taken_loot


## Находку подобрали — запоминаем и сразу пишем на диск вместе с тем, что из
## неё получено (золото, предмет в сумке), чтобы одно не разошлось с другим
func mark_loot_taken(id: String, character: Node) -> void:
	if not is_loaded():
		return
	if not id in taken_loot:
		taken_loot.append(id)
	capture_from(character)


## Забрать прогресс из персонажа и записать на диск
func capture_from(character: Node) -> void:
	if not is_loaded() or not is_instance_valid(character):
		return
	if "gold" in character:
		gold = character.gold
	if "skill_points" in character:
		skill_points = character.skill_points
	if "skill_progress" in character:
		skill_progress = character.skill_progress
	if "unlocked_skills" in character:
		unlocked_skills = character.unlocked_skills.duplicate()
	var inv = character.get("inventory_system")
	if inv != null:
		inventory = {}
		for it in inv.get_all():
			var ab := it as Ability
			if ab:
				inventory[ab.ability_name] = inv.get_count(ab.ability_name)
		has_inventory = true
	var magic = character.get("magic")
	if magic:
		spells = magic.known_spell_names()
	save()
