extends RefCounted
## strings_en.gd — английский перевод интерфейса.
##
## Ключ — русский текст ровно в том виде, как он стоит в коде или сцене
## (регистр, переносы \n, пробелы), значение — английский. GameSettings
## собирает из словаря Translation с локалью "en" и включает её, когда
## в настройках выбран английский.
##
## Label и Button переводят свой text сами (auto_translate), поэтому для
## перевода новой надписи достаточно добавить строку сюда. Где текст рисуется
## руками (draw_string) или собирается из шаблона — в коде стоит tr().
##
## Переведено: главное меню, настройки (и вкладка настроек инвентаря), выбор
## героя, памятка управления, окна подтверждения, экран загрузки. Инвентарь,
## HUD, магазин и прочее пока по-русски — добавляются сюда же по частям.

const MESSAGES := {
	# ── Главное меню ──────────────────────────────────────────────────────────
	"ПРОДОЛЖИТЬ": "CONTINUE",
	"НОВЫЙ ПУТЬ": "NEW JOURNEY",
	"ЗАГРУЗИТЬ": "LOAD GAME",
	"НАСТРОЙКИ": "SETTINGS",
	"ВЫХОД": "QUIT",
	"v0.1.0  ·  ранний доступ": "v0.1.0  ·  early access",
	"Выбрать": "Select",
	"Выход": "Quit",
	"Назад": "Back",
	"%s в пути": "%s on the road",
	"меньше минуты": "under a minute",
	"%d мин": "%d min",
	"%d ч %d мин": "%d h %d min",
	"ПОКИНУТЬ ИГРУ?": "QUIT THE GAME?",
	"ВЫЙТИ": "QUIT",
	"ОСТАТЬСЯ": "STAY",
	"НАЧАТЬ ЗАНОВО?": "START OVER?",
	"Прошлое прохождение (%s) будет стёрто без возврата.": "Your previous journey (%s) will be erased for good.",
	"НАЧАТЬ": "START",
	"ОТМЕНА": "CANCEL",
	"ДА": "YES",
	"НЕТ": "NO",

	# ── Герои (Save/characters.gd) ────────────────────────────────────────────
	"ВОИН": "WARRIOR",
	"СЛЕДОПЫТ": "RANGER",
	"МАГ": "MAGE",
	"Меч и щит": "Sword and Shield",
	"Лук и расстояние": "Bow and Distance",
	"Посох и руны": "Staff and Runes",
	"Закалённый боец, выученный ремеслу войны. Полагается на силу, выносливость и несгибаемую волю.":
		"A disciplined fighter, trained in the art of war. The warrior relies on strength, endurance and unwavering will.",
	"Терпеливая охотница: заканчивает бой раньше, чем он начнётся. Смертоносна издалека, уязвима вблизи.":
		"A patient huntress who ends a fight before it begins. Deadly at range, fragile once the distance closes.",
	"Знаток древних рун, сменивший сталь на чародейский огонь. Хрупок телом, но сокрушителен в силе.":
		"A scholar of the old runes, trading steel for arcane fire. Frail of body, overwhelming in force.",
	"Одни рождаются с мечом,\nдругих меч выковывает.": "Some are born with a sword,\nothers are forged by it.",
	"Стрела не спорит.\nОна прилетает.": "The arrow does not argue.\nIt arrives.",
	"Каждая руна помнит\nруку, что её вырезала.": "Every rune remembers\nthe hand that carved it.",
	"Здоровье": "Health",
	"Выносливость": "Stamina",
	"Сила": "Strength",
	"Ловкость": "Dexterity",
	"Интеллект": "Intelligence",
	"Вера": "Faith",

	# ── Выбор героя ───────────────────────────────────────────────────────────
	"ВЫБОР ГЕРОЯ": "CHOOSE YOUR HERO",
	"О ГЕРОЕ": "THE HERO",
	"ХАРАКТЕРИСТИКИ": "ATTRIBUTES",
	"ВЫБРАТЬ": "CHOOSE",
	"Герой": "Hero",

	# ── Памятка управления ────────────────────────────────────────────────────
	"УПРАВЛЕНИЕ": "CONTROLS",
	"Запомни, как держать клинок, прежде чем дать клятву.": "Learn the ways of the blade before you take the oath.",
	"ДВИЖЕНИЕ": "MOVEMENT",
	"ПРЕДМЕТЫ И МИР": "ITEMS & WORLD",
	"БОЙ": "COMBAT",
	"Идти": "Move",
	"или стрелки": "or the arrow keys",
	"Бег": "Run",
	"держать при движении": "hold while moving",
	"Перекат": "Roll",
	"сквозь врагов": "passes through enemies",
	"Использовать": "Use item",
	"предмет из быстрого слота": "from the quick slot",
	"Сменить слот": "Switch quick slot",
	"Взаимодействие": "Interact",
	"поднять, говорить, торговать": "pick up, talk, trade",
	"Инвентарь": "Inventory",
	"предметы, навыки, настройки": "items, skills, settings",
	"Удар": "Attack",
	"серия из 4 — последний с разворота": "a combo of 4 — the last strike spins",
	"Удар с разбега": "Running attack",
	"Блок": "Block",
	"держать": "hold",
	"Парирование": "Parry",
	"нажать перед самым ударом": "press just before a hit lands",
	"Пинок": "Kick",
	"Захват цели": "Lock on",
	"ближайший враг": "the nearest enemy",
	"Пробел": "Space",
	"НАЗАД": "BACK",
	"НАЧАТЬ ПУТЬ": "BEGIN JOURNEY",

	# ── Окно «в разработке» ───────────────────────────────────────────────────
	"В РАЗРАБОТКЕ": "IN DEVELOPMENT",
	"Путь этого героя ещё куётся.\nОн появится в одном из следующих обновлений.":
		"This hero's path is still being forged.\nIt will arrive in a future update.",
	"ПОНЯТНО": "UNDERSTOOD",

	# ── Экран загрузки ────────────────────────────────────────────────────────
	"ЗАГРУЗКА": "LOADING",
	"Четвёртый удар серии — с разворота: он задевает всех врагов вокруг.":
		"The fourth strike of a combo spins through every foe around you.",
	"Вовремя парированный удар открывает врага для ответа.":
		"A well-timed parry leaves your enemy open for a counter.",
	"Перекат проносит сквозь врагов — но не сквозь стены.":
		"A roll carries you through enemies — but never through walls.",
	"Отдай кровь Руне Жертвы — и боги забудут, что твои силы на перезарядке.":
		"Sacrifice blood to the rune, and the gods forget your cooldowns.",
	"Благословение Бальдра может однажды спасти от смертельного удара.":
		"Baldur's blessing may spare you once from a killing blow.",
	"Под взором Одина время замедляется — и отмеченные уже не встают.":
		"Under Odin's gaze time slows — and the marked do not rise again.",
	"Кровь Фенрира делает тебя несокрушимым и злее с каждой секундой.":
		"Fenrir's blood makes you unbreakable, and angrier with every second.",
	"Выносливость — это жизнь. Выдохшийся воин — мёртвый воин.":
		"Stamina is life. An exhausted warrior is a dead one.",
	"Заметивший тебя враг не забудет. Бей первым.":
		"Enemies that spot you will not forget. Strike first.",
	"У костра можно отдохнуть: здоровье вернётся, но враги воскреснут.":
		"Rest at a bonfire to recover — but the dead will rise again.",

	# ── Настройки (меню и вкладка инвентаря, hero_settings_screen.gd) ─────────
	"ОБЩИЕ": "GENERAL",
	"ГРАФИКА": "GRAPHICS",
	"ЗВУК": "AUDIO",
	"ЯЗЫК": "LANGUAGE",
	"Камера и ощущение боя": "Camera and combat feel",
	"Экран и синхронизация": "Display and sync",
	"Громкость музыки и эффектов": "Music and effects volume",
	"Клавиши": "Keys",
	"Язык интерфейса": "Interface language",
	"ОПИСАНИЕ": "DESCRIPTION",
	"СБРОСИТЬ ВСЁ": "RESET ALL",
	"[ ESC ]   НАЗАД": "[ ESC ]   BACK",
	"Тряска камеры": "Camera shake",
	"Тряска экрана от ударов, оглушения и усталости. Выключите, если от неё укачивает.":
		"Screen shake from hits, stagger and exhaustion. Turn it off if it makes you dizzy.",
	"Режим экрана": "Display mode",
	"ОКНО": "WINDOWED",
	"ВЕСЬ ЭКРАН": "FULLSCREEN",
	"Играть в окне или на весь экран.": "Play in a window or fullscreen.",
	"Вертикальная синхр.": "VSync",
	"Подстраивает частоту кадров под монитор — без разрывов картинки.":
		"Matches the frame rate to your monitor to prevent screen tearing.",
	"Общая громкость": "Master volume",
	"Громкость всего звука игры.": "Overall volume of all game audio.",
	"Музыка": "Music",
	"Громкость музыки и саундтрека.": "Volume of the music and soundtrack.",
	"Эффекты": "Effects",
	"Громкость боя и звуков интерфейса. Отпустите ползунок — прозвучит пример.":
		"Volume of combat and interface sounds. Release the slider to hear a sample.",
	"Прицел мышью": "Mouse aim",
	"Удары, выстрелы и заклинания идут туда, куда указывает мышь, а не по стрелкам. Цель в фокусе по-прежнему важнее.":
		"Strikes, shots and spells go where the mouse points instead of the movement keys. A locked-on target still takes priority.",
	"Переназначение клавиш": "Key rebinding",
	"скоро": "soon",
	"Настройка клавиш появится в одном из следующих обновлений.": "Key rebinding will arrive in a future update.",
	"Язык": "Language",
	"Язык меню и настроек. Остальная игра будет переведена в следующих обновлениях.":
		"Language of the menus and settings. The rest of the game will be translated in future updates.",
	"ВКЛ": "ON",
	"ВЫКЛ": "OFF",
	"Пункт": "Item",
	"Значение": "Value",
	"Раздел": "Section",

	# ═════════════════════ Инвентарь ═════════════════════
	# Вкладки, заголовки, фильтры
	"ИНВЕНТАРЬ": "INVENTORY",
	"НАВЫКИ": "SKILLS",
	"ТАЛИСМАНЫ": "TALISMANS",
	"МАГИЯ": "MAGIC",
	"ГРИМУАР": "GRIMOIRE",
	"БЫСТРЫЙ СЛОТ": "QUICK SLOT",
	"СЛОТЫ МАГИИ": "MAGIC SLOTS",
	"КОЛЧАН": "QUIVER",
	"СОСУД ДУШ": "SOUL VESSEL",
	"САГА ГЕРОЯ": "HERO'S SAGA",
	"НОВОЕ": "NEW",
	"Всё": "All",
	"Зелья": "Potions",
	"Навыки": "Skills",
	"Талисманы": "Talismans",
	"Ключи": "Keys",
	"Эффект": "Effect",
	"При себе": "Carried",
	"Макс. за сессию": "Max per run",
	"Стоимость": "Cost",
	"Длительность": "Duration",
	"Выберите предмет": "Select an item",
	"Выберите заклинание": "Select a spell",
	"Нажмите на ячейку": "Click a cell",
	"Нажмите на ячейку инвентаря": "Click an inventory cell",
	"Благословения богов находят в мире. Применение — Q, смена слота — X, цена — Одр.":
		"Blessings of the gods are found in the world. Use — Q, switch slot — X, cost — Odr.",
	"ЛКМ": "LMB",
	"ПКМ": "RMB",
	"ЗАКРЫТЬ": "CLOSE",
	"ТРОФЕИ": "TROPHIES",
	"[E]   УБРАТЬ ИЗ СЛОТА": "[E]   REMOVE FROM SLOT",
	"[E]   В СЛОТ МАГИИ": "[E]   TO MAGIC SLOT",
	"[E]   В БЫСТРЫЙ СЛОТ": "[E]   TO QUICK SLOT",
	"СМ. ВКЛАДКУ «ТАЛИСМАНЫ»": "SEE THE «TALISMANS» TAB",
	"[G]   ОТКРЫТЬ ГРИМУАР": "[G]   OPEN GRIMOIRE",
	"[T]   СТЕНА ТРОФЕЕВ": "[T]   TROPHY WALL",
	"[ ESC ]  НАЗАД": "[ ESC ]  BACK",
	"%d Одр": "%d Odr",
	"%d сек": "%d sec",
	"Магия  %d/%d": "Magic  %d/%d",
	"Быстрый доступ  %d/%d": "Quick access  %d/%d",
	"Быстрый доступ": "Quick access",
	"Расходуемое": "Consumable",
	"экипирован": "equipped",
	"снят": "not equipped",
	"в слоте": "in slot",
	"Экипируется на вкладке «Талисманы»": "Equipped on the «Talismans» tab",
	"Убрано из слотов магии: %s": "Removed from magic slots: %s",
	"Убрано из быстрого доступа: %s": "Removed from quick access: %s",
	"Слоты магии заполнены (%d/%d) — сначала уберите заклинание": "Magic slots are full (%d/%d) — remove a spell first",
	"Быстрый доступ заполнен (%d/%d) — сначала уберите предмет": "Quick access is full (%d/%d) — remove an item first",
	"Предмет закончился": "Out of this item",
	"В слоте магии: %s": "In magic slot: %s",
	"В быстром доступе: %s": "In quick access: %s",
	"%s  ·  %d душ\nПрокачка заклинаний — в Гримуаре": "%s  ·  %d souls\nUpgrade spells in the Grimoire",

	# Сага героя (hero_stats.gd)
	"Защита": "Defense",
	"Стойкость": "Poise",
	"Сила удара": "Strike power",
	"Одр": "Odr",
	"Золото": "Gold",
	"Очки навыков": "Skill points",
	"Трофеи": "Trophies",
	"Урон стрелы": "Arrow damage",
	"Шанс крита": "Crit chance",
	"Крит по раненым": "Crit on wounded",
	"Крит. урон": "Crit damage",
	"Сейд": "Seid",
	"Восполнение": "Regeneration",
	"%s/с · %s/с в покое": "%s/s · %s/s at rest",
	"Цена заклинаний": "Spell cost",
	"обычная": "normal",
	"Души": "Souls",
	"Сбор душ": "Soul gain",
	"Драупнир": "Draupnir",

	# Колчан и алтарь (hero_side_panels.gd)
	"заряжен": "charged",
	"Танец: следующий — крит": "Dance: next is a crit",
	"%.1f с": "%.1f s",
	"оберег": "charm",
	"Колчан пуст.": "The quiver is empty.",
	"Навыки из быстрого слота": "Skills from the quick slot",
	"заряжают стрелы — они": "charge your arrows — they",
	"появятся здесь.": "will appear here.",
	"Казнь": "Execution",
	"Идеальное парирование": "Perfect parry",
	"Убийство": "Kill",
	"Одр  %d / %d": "Odr  %d / %d",
	"%s — %d Одра": "%s — %d Odr",
	"Тора": "Thor",
	"Сурта": "Surt",
	"хватит ×%d": "enough ×%d",
	"мало Одра": "not enough Odr",
	"Боги платят Одром за:": "The gods pay Odr for:",

	# Навыки (hero_skills_screen.gd, skill_tree_panel.gd)
	"НАВЫК": "SKILL",
	"ДРЕВА": "TREES",
	"ОЧКОВ НАВЫКОВ:  %d": "SKILL POINTS:  %d",
	"ОЧКОВ НАВЫКОВ: %d": "SKILL POINTS: %d",
	"До следующего очка: %d / %d": "To next point: %d / %d",
	"Клик — выбрать навык,\nдвойной клик или E — изучить": "Click — select a skill,\ndouble-click or E — learn",
	"Древо навыков в разработке": "This skill tree is in development",
	"←  НАЗАД": "←  BACK",
	"Выберите навык": "Select a skill",
	"Навыки появятся позже": "Skills will appear later",
	"Ключевой навык": "Key skill",
	"Пассивный навык": "Passive skill",
	"Требуется: %d %s": "Requires: %d %s",
	"очко": "point",
	"очка": "points",
	"очков": "points",
	"◆  ИЗУЧЕНО  ◆": "◆  LEARNED  ◆",
	"[E]  ИЗУЧИТЬ": "[E]  LEARN",
	"Недостаточно очков": "Not enough points",
	"Сначала: %s": "First: %s",
	"открыто навыков %d/%d": "skills learned %d/%d",

	# Талисманы
	"В сумке": "In bag",
	"Секция": "Section",
	"Пассивные обереги — действуют, пока экипированы": "Passive charms — active while equipped",
	"пусто": "empty",
	"ЭКИПИРОВАНО": "EQUIPPED",
	"не надет": "not worn",
	"Талисман": "Talisman",
	"[E]   СНЯТЬ": "[E]   UNEQUIP",
	"[E]   ЭКИПИРОВАТЬ": "[E]   EQUIP",
	"Выберите талисман": "Select a talisman",
	"Нажмите на ячейку слева": "Click a cell on the left",
	"Снято: %s": "Unequipped: %s",
	"Все %d секции заняты — сначала снимите талисман": "All %d sections are taken — unequip a talisman first",
	"Экипирован: %s": "Equipped: %s",

	# Стена трофеев (trophy_wall.gd, Player_scene/knight_trophies.gd)
	"СТЕНА ТРОФЕЕВ": "TROPHY WALL",
	"ПОДВИГИ": "DEEDS",
	"Действуют навсегда:": "Permanent bonuses:",
	"[ T ]   НАЗАД": "[ T ]   BACK",
	"Добыто  %d  из  %d": "Earned  %d  of  %d",
	"Пока ни одного.\nПодвиги копятся сами — в бою:\nубийства, казни, парирования\nи молитвы богам.":
		"None yet.\nDeeds add up on their own in battle:\nkills, executions, parries\nand prayers to the gods.",
	"ДОБЫТ": "EARNED",
	"Трофей: %s": "Trophy: %s",
	"Кости погоста": "Graveyard Bones",
	"Упокоить 20 простых скелетов": "Lay 20 common skeletons to rest",
	"+10 к здоровью": "+10 health",
	"Расколотый щит": "Shattered Shield",
	"Сломить 8 щитоносцев": "Break 8 shield-bearers",
	"−10% урона по концентрации": "−10% poise damage taken",
	"Топор громилы": "Brute's Axe",
	"Повалить 5 громил с топорами": "Fell 5 axe brutes",
	"+10 к выносливости": "+10 stamina",
	"Сломанный клинок": "Broken Blade",
	"Одолеть 5 скелетов-дуэлянтов": "Defeat 5 skeleton duelists",
	"−5% получаемого урона": "−5% damage taken",
	"Палач Хельхейма": "Executioner of Helheim",
	"Совершить 10 казней": "Perform 10 executions",
	"+10 Одра за каждую казнь": "+10 Odr per execution",
	"Рука Тюра": "Hand of Tyr",
	"15 идеальных парирований": "15 perfect parries",
	"+5 Одра за парирование": "+5 Odr per parry",
	"Глас богов": "Voice of the Gods",
	"Получить 10 благословений": "Receive 10 blessings",
	"Молитвы на 10% дешевле": "Prayers cost 10% less",
	"Путь эйнхерия": "Path of the Einherjar",
	"Сразить 60 врагов": "Slay 60 enemies",
	"+15 к шкале Одра": "+15 to the Odr gauge",

	# Гримуар мага (mage_grimoire.gd)
	"Души, собранные с павших, вплетаются в руны: ранг II — дешевле, ранг III — сильнее":
		"Souls taken from the fallen are woven into runes: rank II — cheaper, rank III — stronger",
	"ВЫСШИЙ РАНГ": "MAX RANK",
	"УСИЛИТЬ  ·  %d душ": "EMPOWER  ·  %d souls",
	"%d душ": "%d souls",
	"Шкала Сейда: %d\n+%d за каждый уровень сосуда": "Seid gauge: %d\n+%d per vessel level",
	"СОСУД ПОЛОН": "VESSEL FULL",
	"РАСШИРИТЬ  ·  %d душ": "EXPAND  ·  %d souls",
	"%s — ранг %s": "%s — rank %s",
	"Не хватает душ": "Not enough souls",
	"Сосуд душ расширен — Сейд %d": "Soul vessel expanded — Seid %d",
	"руна %s": "rune %s",
	"Цена": "Cost",
	"%d Сейда": "%d Seid",
	"Целей": "Targets",
	"Урон": "Damage",
	"до %d": "up to %d",
	"Ранг II: цена −20%": "Rank II: cost −20%",
	"Ранг III: %s": "Rank III: %s",
	"Руна раскрыта полностью": "The rune is fully awakened",
	"Огненный шар": "Fireball",
	"Выжигание": "Scorch",
	"Двойной импульс": "Twin Pulse",
	"Столпы Сейда": "Pillars of Seid",
	"Кеназ": "Kenaz",
	"Соулу": "Sowilo",
	"Хагалаз": "Hagalaz",
	"Альгиз": "Algiz",
	"Сгусток голубого пламени летит в цель и опаляет всех рядом с ней.":
		"A clot of blue flame flies at the target and scorches everyone near it.",
	"Голубой огонь катится вперёд конусом, жжёт и отбрасывает.":
		"Blue fire rolls forward in a cone, burning and knocking back.",
	"Две волны силы расходятся от мага — малая и большая — и раскидывают врагов.":
		"Two waves of force spread from the mage — a small one and a large one — and scatter enemies.",
	"Под ближайшими врагами проступают руны — и из земли вырываются столпы огня.":
		"Runes surface beneath the nearest enemies — and pillars of fire burst from the ground.",
	"+1 урона шару": "+1 fireball damage",
	"+1 урона огню": "+1 fire damage",
	"+1 урона волнам": "+1 wave damage",
	"+2 цели столпам": "+2 pillar targets",
	"ПЛАМЯ МУСПЕЛЬХЕЙМА": "FLAME OF MUSPELHEIM",
	"ЛЁД НИФЛЬХЕЙМА": "ICE OF NIFLHEIM",
	"Кольцо инея": "Rime Ring",
	"Вихрь": "Blizzard Whirl",
	"Ледяной луч": "Frost Ray",
	"Ледяной шаг": "Ice Step",
	"Иса": "Isa",
	"Йера": "Jera",
	"Тейваз": "Tiwaz",
	"Эваз": "Ehwaz",
	"Вокруг мага из земли вырастают ледяные шипы: ранят, отбрасывают и сковывают ознобом.":
		"Ice spikes burst from the ground around the mage: they wound, push back and bind with chill.",
	"Маг крутится в метели: стягивает врагов к себе, дважды бьёт льдом и раскидывает. Удар его не сбивает.":
		"The mage spins in a blizzard: drags enemies in, strikes twice with ice and hurls them away. Blows do not interrupt it.",
	"Пока зажата клавиша, из рук бьёт луч стужи: пронзает всех на линии и тянет Сейд каждую секунду.":
		"While the key is held, a ray of cold pours from the hands: it pierces everyone in line and drains Seid every second.",
	"Рывок осколками сквозь врагов, неуязвимый. Позади — наледь, что морозит, впереди — вспышка холода.":
		"An invulnerable dash of shards through enemies. Behind — freezing ice, ahead — a burst of cold.",
	"+1 урона шипам": "+1 spike damage",
	"+1 урона каждому удару": "+1 damage per strike",
	"+1 урона за тик": "+1 damage per tick",
	"+1 урона вспышке": "+1 burst damage",
	# Реакции стихий мага (mage_reactions.gd)
	"ПАР": "STEAM",
	"ВСПЫШКА": "FLARE",
	"РАСКОЛ": "SHATTER",
	"КАЗНЬ": "EXECUTION",
	"Ctrl": "Ctrl",

	# ═════════════════════ Предметы, способности, талисманы ═════════════════════
	# Названия — ключи логики и сейва, по-русски внутри; переводится только показ
	"Мёд Поэзии": "Mead of Poetry",
	"Песнь Валькирии": "Valkyrie's Song",
	"Песнь валькирии": "Valkyrie's Song",
	"Эликсир Вальгаллы": "Elixir of Valhalla",
	"Руна Жертвы": "Rune of Sacrifice",
	"Руна жертвы": "Rune of Sacrifice",
	"Безумие Берсерка": "Berserker's Fury",
	"Благословение Бальдра": "Baldur's Blessing",
	"Глаз Одина": "Eye of Odin",
	"Кровь Фенрира": "Fenrir's Blood",
	"Выстрел Валькирии": "Valkyrie's Shot",
	"Коготь Фенрира": "Fenrir's Claw",
	"Шёпот Одина": "Odin's Whisper",
	"Танец Валькирии": "Valkyrie's Dance",
	"Кровавое Перо": "Blood Feather",
	"Последний взор": "Last Glance",
	"Путь охотницы": "Huntress's Path",
	"Перо Хугина": "Huginn's Feather",
	"Игла Норн": "Needle of the Norns",
	"Глаз Мимира": "Mimir's Eye",
	"Кольцо Драупнир": "Ring Draupnir",
	"Гандр вёльвы": "Völva's Gandr",
	"Благословение Тора": "Blessing of Thor",
	"Благословение Сурта": "Blessing of Surt",
	"Благословение": "Blessing",
	"Боевой навык": "Combat skill",
	"Временная способность": "Timed ability",
	"Талисман  •  пассивный": "Talisman  •  passive",
	"Зелье": "Potion",
	"Способность": "Ability",
	"Валькирии  •  Боевой навык": "Valkyries  •  Combat skill",
	"Фенрир  •  Боевой навык": "Fenrir  •  Combat skill",
	"Один  •  Боевой навык": "Odin  •  Combat skill",
	"Один  •  Временная способность": "Odin  •  Timed ability",
	"Скади, древние охотницы  •  Временная способность": "Skadi, the ancient huntresses  •  Timed ability",
	"Один  •  Талисман, пассивный": "Odin  •  Talisman, passive",
	"Норны  •  Талисман, пассивный": "Norns  •  Talisman, passive",
	"Мимир  •  Талисман, пассивный": "Mimir  •  Talisman, passive",
	"Вёльва  •  Талисман, пассивный": "Völva  •  Talisman, passive",

	# Описания способностей (скрипты способностей)
	"Постепенно восстанавливает здоровье": "Gradually restores health",
	"Постепенно лечит и снимает все негативные эффекты": "Gradually heals and removes all negative effects",
	"Моментально восстанавливает здоровье": "Instantly restores health",
	"Жертвуешь часть HP и сбрасываешь кулдауны всех остальных способностей":
		"Sacrifice part of your HP to reset the cooldowns of all other abilities",
	"HP пополам, сила x2, скорость, дальнобойные удары": "Half HP, x2 strength, speed, long-reaching strikes",
	"Снижает урон и один раз воскрешает при гибели": "Reduces damage and revives you once on death",
	"Замедляет время и метит ближайших врагов на мгновенную казнь":
		"Slows time and marks the nearest enemies for instant execution",
	"Неуязвимость к урону и контролю, сила растёт по ходу действия":
		"Immune to damage and crowd control; strength grows while it lasts",
	"Следующий выстрел срывается с тетивы мгновенно,\nлетит почти вдвое быстрее и наносит +1 урона.":
		"Your next shot leaves the string instantly,\nflies almost twice as fast and deals +1 damage.",
	"Следующие 3 стрелы пробивают первого врага\nи поражают того, кто стоит за ним.":
		"Your next 3 arrows pierce the first enemy\nand hit the one standing behind it.",
	"Следующие 3 стрелы проходят сквозь препятствия\nи поражают врага за ними.":
		"Your next 3 arrows pass through obstacles\nand hit the enemy behind them.",
	"12 сек: после каждого переката следующий выстрел\nусилен — он всегда критический.":
		"12 sec: after every roll your next shot\nis empowered — it is always critical.",
	"20 сек: критическое попадание накладывает\nкровотечение — 3 урона за 3 секунды.":
		"20 sec: critical hits inflict\nbleeding — 3 damage over 3 seconds.",
	"8 сек: стрельба вдвое быстрее, стрелы доворачивают\nв цель, +1 урона и +15% шанса крита.":
		"8 sec: shoot twice as fast, arrows home in\non the target, +1 damage and +15% crit chance.",
	"12 сек: цель в фокусе (или первая поражённая)\nстановится добычей. Каждое попадание по ней\nусиливает следующее — до +2 урона.":
		"12 sec: the focused target (or the first one hit)\nbecomes your prey. Every hit on it\nempowers the next — up to +2 damage.",
	"Каждое попадание метит врага на 5 сек. Лук\nсам наводится на помеченных, даже издалека.\nДобыча Пути охотницы под меткой копит силу вдвое быстрее.":
		"Every hit marks the enemy for 5 sec. The bow\naims at marked foes by itself, even from afar.\nMarked prey of the Huntress's Path gains power twice as fast.",
	"Каждое попадание метит врага на 5 сек. Лук сам\nнаводится на помеченных, даже издалека.\nДобыча Пути охотницы под меткой копит силу вдвое быстрее.":
		"Every hit marks the enemy for 5 sec. The bow\naims at marked foes by itself, even from afar.\nMarked prey of the Huntress's Path gains power twice as fast.",
	"+20% шанса критического попадания по врагам,\nкоторых лучница уже поражала.":
		"+20% critical hit chance against enemies\nthe archer has already struck.",
	"Каждая собранная душа приносит\nна 30% больше.": "Every soul collected\nyields 30% more.",
	"Сейд восполняется на 50% быстрее —\nи в бою, и в передышке.": "Seid regenerates 50% faster —\nboth in battle and at rest.",
	"Все заклинания стоят на 20% меньше Сейда.": "All spells cost 20% less Seid.",

	# Описания и предания из каталога торговца (Shop/shop_menu.gd)
	"Постепенно восстанавливает здоровье.": "Gradually restores health.",
	"Старинный напиток, рожденный из шёпота богов\nГоворят, его вкус дарует не только ясность ума, но и силу, что течёт глубже крови.\nНемногие знают, из чего он создан.\nИ ещё меньше — чем приходится за него платить.":
		"An ancient drink born of the gods' whispers.\nThey say its taste grants not only clarity of mind but a strength that runs deeper than blood.\nFew know what it is made of.\nFewer still — what one must pay for it.",
	"Те, кто слышит её песнь, возвращаются к бою.\nНо не все возвращаются прежними.":
		"Those who hear her song return to battle.\nBut not all return unchanged.",
	"Тихий отголосок битв, что давно затихли.\nСчитается, что в этом сосуде запечатан последний вздох павшей валькирии.":
		"A quiet echo of battles long fallen silent.\nIt is said this vessel holds the last breath of a fallen valkyrie.",
	"Тот, кто испьёт его, на мгновение ощущает силу тех, кто уже пал.\nНо даже мимолётный взгляд за порог не проходит бесследно.":
		"Whoever drinks it feels, for a moment, the strength of those who have already fallen.\nBut even a fleeting glance beyond the threshold leaves its mark.",
	"Густой напиток, которым провожают павших воинов.\nГоворят, он пропитан эхом пиршеств из Вальгалла.":
		"A thick drink poured to see fallen warriors off.\nThey say it is steeped in echoes of the feasts of Valhalla.",
	"Она откликается на боль владельца, возвращая утраченное.\nНо всегда забирает больше, чем было отдано.":
		"It answers its bearer's pain, returning what was lost.\nBut it always takes more than was given.",
	"Старинный знак, вырезанный не ради защиты, а ради расплаты.\nКаждая линия на ней — напоминание о цене силы.":
		"An ancient sign carved not for protection, but for payment.\nEvery line on it is a reminder of the price of power.",
	"С каждым ударом сила растёт.\nНо вместе с ней исчезает и контроль.":
		"With every blow the strength grows.\nBut control fades along with it.",
	"Ярость, в которой теряется грань между человеком и зверем.\nГоворят, те, кто поддаются ей, больше не чувствуют боли.":
		"A fury in which the line between man and beast is lost.\nThey say those who yield to it no longer feel pain.",
	"Свет, к которому не может прикоснуться ни сталь, ни тьма.\nОн дарует защиту, что кажется абсолютной.":
		"A light that neither steel nor darkness can touch.\nIt grants a protection that seems absolute.",
	"Но даже самый чистый свет имеет то, что было упущено.\nИ именно через это приходит конец.":
		"But even the purest light has something overlooked.\nAnd it is through that the end arrives.",
	"Истина открывается тем, кто осмелится взглянуть.\nНо не каждый разум способен её выдержать.":
		"Truth reveals itself to those who dare to look.\nBut not every mind can bear it.",
	"Око, отданное в обмен на знание, что недоступно смертным.\nОно видит больше, чем должен видеть человек.":
		"An eye given in exchange for knowledge beyond mortals.\nIt sees more than a man should see.",
	"Дарует мощь, способную сокрушить всё на пути.\nНо зверь внутри никогда не служит долго.":
		"Grants a might that can crush everything in its path.\nBut the beast within never serves for long.",
	"Сила зверя, что однажды разорвёт сами оковы мира.\nОна кипит, даже будучи заключённой.":
		"The strength of the beast that will one day tear the very chains of the world.\nIt seethes even in captivity.",
	"Стрела, которой Валькирии отмечали достойных павших.\nВыпущенная с силой, она находит цель прежде,\nчем та успевает заметить смерть.":
		"The arrow the Valkyries used to mark the worthy fallen.\nLoosed with force, it finds its target\nbefore death can even be noticed.",
	"Говорят, ни одна цепь не могла удержать зверя вечно.\nТак и эта стрела не знает преград.":
		"They say no chain could hold the beast forever.\nNor does this arrow know any barrier.",
	"Одину не нужны были глаза, чтобы знать всё происходящее.\nГоворят, его шёпот достигал даже тех мест,\nкуда не мог добраться человек.":
		"Odin needed no eyes to know all that happens.\nThey say his whisper reached even places\nno man could ever reach.",
	"Валькирия не стоит перед смертью.\nОна движется вместе с ней.":
		"A Valkyrie does not stand before death.\nShe moves with it.",
	"Перо Валькирии чернеет лишь после того,\nкак принимает кровь павшего.\nЧем глубже рана, тем тяжелее становится следующий удар.":
		"A Valkyrie's feather turns black only\nonce it takes the blood of the fallen.\nThe deeper the wound, the heavier the next blow.",
	"Один отдал глаз ради знания, недоступного смертным.\nНа мгновение охотница видит то,\nчто обычно скрыто от человеческого взгляда.":
		"Odin gave an eye for knowledge beyond mortals.\nFor a moment the huntress sees\nwhat is usually hidden from human sight.",
	"Охотница не спешит за добычей.\nОна следует её следу, пока тот не приведёт к смерти.":
		"The huntress does not rush after her prey.\nShe follows its trail until it leads to death.",
	"Хугин летал над девятью мирами и приносил Одину вести\nо том, чего тот не видел сам.\nНи одна цель не должна оставаться незамеченной.":
		"Huginn flew over the nine worlds and brought Odin news\nof what he did not see himself.\nNo target should go unnoticed.",
	"Норны плетут нити судьбы, которым не способен\nпротивиться даже бог.\nИногда достаточно одной нити, чтобы изменить исход битвы.":
		"The Norns weave threads of fate\nthat not even a god can resist.\nSometimes a single thread is enough to change a battle's outcome.",
	"Один отдал глаз за глоток из источника Мимира.\nТот глаз до сих пор смотрит со дна —\nи видит, откуда течёт сила.":
		"Odin gave an eye for a sip from Mimir's well.\nThat eye still gazes from the bottom —\nand sees where power flows from.",
	"Каждую девятую ночь из Драупнира капают\nвосемь колец, равных ему по весу.\nТо, что к нему прикасается, множится.":
		"Every ninth night eight rings of equal weight\ndrip from Draupnir.\nWhatever touches it multiplies.",
	"Посох провидицы, что пела сейд у границ миров.\nВ нём сила не тратится —\nона лишь течёт из одного русла в другое.":
		"The staff of a seeress who sang seid at the edges of the worlds.\nIn it power is never spent —\nit only flows from one channel to another.",

	# Благословения рыцаря (Player_scene/magic/spells.gd)
	"Молния Тора бьёт в поднятый меч.\n30 сек: удары сильнее бьют по концентрации\nи перескакивают разрядом на соседнего врага.":
		"Thor's lightning strikes the raised sword.\n30 sec: strikes hit poise harder\nand arc to a nearby enemy.",
	"Тор, сын Одина, — защитник Мидгарда от великанов. Гром — стук колёс его колесницы, молния — след брошенного Мьёльнира, что всегда возвращается в руку хозяина. Воины молились ему перед битвой: тот, кто поднял меч во имя Аса, не боится грозы.":
		"Thor, son of Odin, is Midgard's defender against the giants. Thunder is the rumble of his chariot's wheels, lightning — the trail of the thrown Mjölnir that always returns to its master's hand. Warriors prayed to him before battle: whoever raises a sword in the Aesir's name does not fear the storm.",
	"Огонь Муспельхейма вырывается из-под земли и охватывает клинок.\nОгненное кольцо поджигает и отталкивает тех, кто рядом.\n30 сек: удары поджигают врагов.":
		"The fire of Muspelheim bursts from the ground and engulfs the blade.\nA ring of flame ignites and repels those nearby.\n30 sec: strikes set enemies ablaze.",
	"Сурт — огненный великан, страж Муспельхейма. В Рагнарёк он пройдёт по радужному мосту с мечом ярче солнца, и пламя его поглотит все девять миров. Просить у него благословения — значит взять взаймы у самого конца света.":
		"Surt is the fire giant, guardian of Muspelheim. At Ragnarök he will cross the rainbow bridge with a sword brighter than the sun, and his flame will devour all nine worlds. To ask for his blessing is to borrow from the end of the world itself.",

	# Древа навыков (Save/skill_trees.gd)
	"РУНЫ СТОЙКОСТИ": "RUNES OF FORTITUDE",
	"КЛЫК БЕРСЕРКА": "BERSERKER'S FANG",
	"ВОЛЯ ЭЙНХЕРИЯ": "WILL OF THE EINHERJAR",
	"Путь несокрушимого рыцаря": "Path of the unbreakable knight",
	"Укрепляй тело, защищайся от любых ударов и стой там, где другие падают.":
		"Harden your body, guard against any blow and stand where others fall.",
	"КАМЕННОЕ СЕРДЦЕ": "HEART OF STONE",
	"Фундамент стойкости рыцаря. Сердце твёрже камня.": "The foundation of a knight's fortitude. A heart harder than stone.",
	"+8% к максимальному здоровью": "+8% max health",
	"ДЫХАНИЕ СКАЛЫ": "BREATH OF THE CLIFF",
	"Учись дышать глубоко и спокойно, пока буря бьёт о твой щит.": "Learn to breathe deep and calm while the storm beats on your shield.",
	"+10% к максимальной выносливости": "+10% max stamina",
	"ЖЕЛЕЗНАЯ КРОВЬ": "IRON BLOOD",
	"Кровь в жилах становится густой, как расплавленное железо.": "The blood in your veins grows thick as molten iron.",
	"+8% к физической защите": "+8% physical defense",
	"РУНА ЩИТА": "SHIELD RUNE",
	"Древние руны усиливают твой щит, заставляя удары скользить по нему.": "Ancient runes strengthen your shield, making blows glance off it.",
	"-10% получаемого урона во время блока": "-10% damage taken while blocking",
	"КАМЕННАЯ СТОЙКА": "STONE STANCE",
	"Ты становишься неподвижен, как скала, когда враг пытается сломить тебя.": "You stand unmoving as a rock when the enemy tries to break you.",
	"+15% сопротивления урону стойкости": "+15% poise damage resistance",
	"НЕСГИБАЕМЫЙ": "UNBENDING",
	"Никакая сила не заставит тебя отступить или пошатнуться.": "No force can make you retreat or falter.",
	"+25% сопротивления ошеломлению": "+25% stagger resistance",
	"КОСТИ ВЕЛИКАНА": "GIANT'S BONES",
	"Твои кости уплотняются, словно кости древних великанов.": "Your bones grow dense like the bones of ancient giants.",
	"+12% к максимальному здоровью": "+12% max health",
	"ЖЕЛЕЗНЫЙ ОБЕТ": "IRON VOW",
	"Каждый раз, когда ты поднимаешь щит, ты даёшь обет выстоять любой ценой.": "Every time you raise your shield, you vow to hold at any cost.",
	"-15% траты выносливости при блоке. После полного блока следующая атака наносит +10% урона стойкости":
		"-15% stamina cost when blocking. After a full block your next attack deals +10% poise damage",
	"ГОРНАЯ СТОЙКА": "MOUNTAIN STANCE",
	"Ты стоишь, как гора. Враги бьются о тебя, но не могут сдвинуть.": "You stand like a mountain. Enemies crash against you but cannot move you.",
	"+30% сопротивления урону стойкости": "+30% poise damage resistance",
	"СЕРДЦЕ ЙОТУНА": "HEART OF THE JÖTUNN",
	"Твоё сердце бьётся в такт с горами. Ты — стена между врагом и всем, что тебе дорого.":
		"Your heart beats in time with the mountains. You are the wall between the enemy and all you hold dear.",
	"+15% макс. здоровья, +10% физ. защиты, +20% сопротивления ошеломлению. Пока здоровье выше 70% — получаемый урон стойкости дополнительно -15%":
		"+15% max health, +10% physical defense, +20% stagger resistance. While health is above 70%, poise damage taken is reduced by a further 15%",

	# ═════════════════════ HUD ═════════════════════
	"утро": "morning",
	"день": "day",
	"вечер": "evening",
	"ночь": "night",
	"Ясно": "Clear",
	"Пасмурно": "Overcast",
	"Туман": "Fog",
	"Дождь": "Rain",
	"Гроза": "Storm",
	# Подбор лута и карточка подробностей (Levels/loot)
	"Подобрать": "Pick up",
	"Нажмите": "Press",
	# Запятая после клавиши в «Нажмите [Tab], чтобы…» — в английском не нужна.
	# Пустая строка как перевод: tr() вернул бы ключ, поэтому — пробел нулевой ширины
	",": "​",
	"чтобы узнать подробнее": "to learn more",
	"закрыть": "close",
	"ПРЕДАНИЕ": "LORE",
	"НАЗНАЧЕНИЕ": "PURPOSE",
	"Магия  •  Благословение": "Magic  •  Blessing",
	"%s\nЦена: %d Одра.": "%s\nCost: %d Odr.",
	"%d золота": "%d gold",
	"Сейд  •  Валюта": "Seid  •  Currency",
	"Мидгард  •  Валюта": "Midgard  •  Currency",
	"Тусклые монеты из курганов и разорённых святилищ. Северяне клали золото в могилу вместе с воином: верили, что в Вальгалле оно служит ему так же, как служило в Мидгарде. Потому мёртвые так неохотно с ним расстаются.":
		"Dull coins from barrows and plundered shrines. Northmen laid gold in the grave beside a warrior, believing it would serve him in Valhalla as it had in Midgard. That is why the dead part with it so reluctantly.",
	"Валюта. Тратится у торговца на зелья, руны, навыки и талисманы.":
		"Currency. Spent at the merchant on potions, runes, skills and talismans.",
	"Обрывки тех, кто не дошёл ни до Вальгаллы, ни до чертогов Хель. Вёльвы собирали их, как другие копят серебро: в шёпоте мёртвых — сила сейда.":
		"Shreds of those who reached neither Valhalla nor the halls of Hel. Völvas gathered them as others hoard silver: in the whisper of the dead lies the power of seid.",
	"Валюта мага. Тратится у торговца на зелья и талисманы.":
		"The mage's currency. Spent at the merchant on potions and talismans.",
	"← НАЗАД": "← BACK",

	# ═════════════════════ Магазин (Shop/shop_menu.gd) ═════════════════════
	"МАГАЗИН": "SHOP",
	"ПРЕДМЕТ": "ITEM",
	"ЦЕНА": "PRICE",
	"У вас есть:": "You have:",
	"в сумке": "in bag",
	"Предание": "Lore",
	"[E]  Купить": "[E]  Buy",
	"Уже в сумке": "Already in bag",
	"Недостаточно душ": "Not enough souls",
	"Недостаточно золота": "Not enough gold",
	"Подтверждение": "Confirmation",
	"Купить «%s» за %s?": "Buy «%s» for %s?",
	"[E]  Да": "[E]  Yes",
	"[Esc]  Нет": "[Esc]  No",

	# ═════════════════════ Костры (Levels/bonfire) ═════════════════════
	"Костёр": "Bonfire",
	"Западный тракт": "Western Road",
	"Восточная ограда": "Eastern Fence",
	"Зажечь костёр": "Kindle the bonfire",
	"Отдохнуть у костра": "Rest at the bonfire",
	"КОСТЁР ЗАЖЖЁН": "BONFIRE LIT",
	"Нельзя отдохнуть": "You cannot rest",
	"Рядом враги": "Enemies are near",
	"Силы восстановлены · мир пробудился · сохранено": "Strength restored · the world awakens · saved",
	"Перемещение": "Travel",
	"Сумка": "Bag",
	"Покинуть костёр": "Leave the bonfire",
	"Других зажжённых костров нет": "No other bonfires are lit",
	"Куда отправиться?": "Where to?",
	"W/S — выбор    E — выбрать    Esc — назад": "W/S — choose    E — select    Esc — back",
}
