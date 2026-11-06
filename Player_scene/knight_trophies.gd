extends RefCounted
## knight_trophies.gd — стена трофеев Хальварда: подвиги, которые копятся
## сами (убийства по видам скелетов, казни, идеальные парирования, молитвы)
## и, когда набрана цель, навсегда дают маленький бонус.
##
## Здесь только данные и счёт. Счётчики живут на рыцаре (player.gd::
## trophy_counts, сейв — SaveManager.hero_progress), бонусы читает рыцарь и
## его магия через player.trophy_bonus(key); стену рисует
## Inventory/ui/trophy_wall.gd.
##   const Trophies := preload("res://Player_scene/knight_trophies.gd")

## counter — какой счётчик растит трофей (player.trophy_note):
##   grunt/shield/brute/duelist — убит скелет этого вида (skeleton_enemy.gd Kind),
##   kills — любой враг, executions — казни, parries — идеальные парирования,
##   prayers — молитвы, на которые ответили боги (удар молнии/огня в меч).
## bonus — ключ бонуса и его величина (player.trophy_bonus):
##   max_hp / max_stamina — прибавка к максимуму, defense / posture_resist —
##   доля снижения входящего урона, odr_exec / odr_parry — Одр сверх
##   обычного, prayer_discount — доля скидки цены молитвы, max_odr — прибавка
##   к шкале Одра.
## emblem — что нарисовать на табличке (trophy_wall.gd::_draw_emblem)
const LIST := [
	{"id": "bones", "name": "Кости погоста", "counter": "grunt", "goal": 20,
		"task": "Упокоить 20 простых скелетов",
		"bonus": ["max_hp", 10.0], "bonus_text": "+10 к здоровью", "emblem": "skull"},
	{"id": "shield", "name": "Расколотый щит", "counter": "shield", "goal": 8,
		"task": "Сломить 8 щитоносцев",
		"bonus": ["posture_resist", 0.1], "bonus_text": "−10% урона по концентрации", "emblem": "shield"},
	{"id": "axe", "name": "Топор громилы", "counter": "brute", "goal": 5,
		"task": "Повалить 5 громил с топорами",
		"bonus": ["max_stamina", 10.0], "bonus_text": "+10 к выносливости", "emblem": "axe"},
	{"id": "blade", "name": "Сломанный клинок", "counter": "duelist", "goal": 5,
		"task": "Одолеть 5 скелетов-дуэлянтов",
		"bonus": ["defense", 0.05], "bonus_text": "−5% получаемого урона", "emblem": "sword"},
	{"id": "executioner", "name": "Палач Хельхейма", "counter": "executions", "goal": 10,
		"task": "Совершить 10 казней",
		"bonus": ["odr_exec", 10.0], "bonus_text": "+10 Одра за каждую казнь", "emblem": "rune"},
	{"id": "tyr", "name": "Рука Тюра", "counter": "parries", "goal": 15,
		"task": "15 идеальных парирований",
		"bonus": ["odr_parry", 5.0], "bonus_text": "+5 Одра за парирование", "emblem": "hand"},
	{"id": "voice", "name": "Глас богов", "counter": "prayers", "goal": 10,
		"task": "Получить 10 благословений",
		"bonus": ["prayer_discount", 0.1], "bonus_text": "Молитвы на 10% дешевле", "emblem": "bolt"},
	{"id": "einherjar", "name": "Путь эйнхерия", "counter": "kills", "goal": 60,
		"task": "Сразить 60 врагов",
		"bonus": ["max_odr", 15.0], "bonus_text": "+15 к шкале Одра", "emblem": "valknut"},
]

## Kind скелета (enemy/location_cemetery/skeleton_enemy.gd) -> счётчик
const KIND_COUNTERS := ["grunt", "shield", "brute", "duelist"]


static func is_done(trophy: Dictionary, counts: Dictionary) -> bool:
	return int(counts.get(trophy["counter"], 0)) >= int(trophy["goal"])


static func progress(trophy: Dictionary, counts: Dictionary) -> int:
	return mini(int(counts.get(trophy["counter"], 0)), int(trophy["goal"]))


static func done_count(counts: Dictionary) -> int:
	var n := 0
	for t in LIST:
		if is_done(t, counts):
			n += 1
	return n


## Сумма бонуса key по всем добытым трофеям
static func bonus(key: String, counts: Dictionary) -> float:
	var sum := 0.0
	for t in LIST:
		if t["bonus"][0] == key and is_done(t, counts):
			sum += float(t["bonus"][1])
	return sum


## Трофеи, которые станут добытыми, если counter вырастет с before до after
static func newly_done(counter: String, before: int, after: int) -> Array:
	var out := []
	for t in LIST:
		if t["counter"] == counter and before < int(t["goal"]) and after >= int(t["goal"]):
			out.append(t)
	return out
