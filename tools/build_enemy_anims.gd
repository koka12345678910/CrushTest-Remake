extends SceneTree
## tools/build_enemy_anims.gd — собирает анимации новых врагов из листов enemys/.
##
## Для каждого врага из TYPES пишет в его папку (out):
##   <id>_frames.tres — SpriteFrames для AnimatedSprite2D
##   <id>_anims.tres  — AnimationLibrary для EnemyAnim
## Запуск (из корня проекта, редактор лучше закрыть):
##   Godot --headless --path . --script res://tools/build_enemy_anims.gd
## Только один враг:  ... --script res://tools/build_enemy_anims.gd -- footsoldier
##
## Листы: 15 кадров x 8 строк по 128 px. Строки — направления по кругу
## (Right, Down_Right, Down, Down_Left, Left, Up_Left, Up, Up_Right) —
## проверено по кадрам ходьбы Footsoldier. Имена клипов — те, что ждёт
## enemy.gd: <действие>_<направление>.
##
## Обрезанное оружие. Если в листе клинок упирается в край ячейки 128 px
## (рисунок обрезан ещё в исходнике), у врага ставится "feather": N. Тогда
## сначала запускается очистка:
##   Godot --headless --path . --script res://tools/build_enemy_anims.gd -- crusader --clean
## она пишет исправленные копии листов в <out>/sheets/: в кадрах, где что-то
## касается края, всё, что СОЕДИНЕНО с краем (клинок, след удара), плавно
## растворяется на последних N пикселях — вместо обрубка сужающийся кончик.
## Тело и плащ, которые края не касаются, не меняются. Исходники в enemys/
## не трогаются. Потом импорт (открыть редактор или --import) и обычная сборка —
## она берёт листы из <out>/sheets/, если они там есть.
##
## ВАЖНО (против "замёрзших" врагов): enemy.gd зовёт anim.play() напрямую для
## block / parry / pummel / stagger* / take_damage / die. Клипа нет — спрайт
## застывает на последнем кадре. Поэтому REQUIRED обязателен для каждого врага:
## инструмент не сохранит ресурсы, если чего-то не хватает.

const DIRS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const CELL := 128

## Клипы, которые enemy.gd может запросить у любого врага
const REQUIRED := [
	"idle2", "walk", "run", "attack", "attack2", "attack3",
	"take_damage", "stagger", "stagger2", "stagger3",
	"block", "parry", "pummel", "die",
]

## [клип, лист, кадров/с, зациклен, кадры, сдвиг строки]
## кадры: [первый, последний] — диапазон; или явный список через "seq"
## (["seq", 13, 14, 13]). Лист — имя файла без "_Shadowless.png".
const TYPES := {
	# Пехотинец: меч и щит. Attack2 НЕ используется — у него клинок в 3 кадрах
	# выходит за ячейку 128 px и обрезан (видимый срез меча)
	"footsoldier": {
		"src": "res://enemys/3Footsoldier/",
		"out": "res://enemy/humans/footsoldier/",
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack1", 20.0, false, [0, 14], 0],      # выпад, удар ~43%
			["attack2", "Attack3", 20.0, false, [0, 14], 0],     # прыжок и рубящий, ~50%
			["attack3", "Attack4", 20.0, false, [0, 14], 0],     # щит, затем рубящий, ~62%
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Idle2 — подъём щита: к 12-14 кадру щит закрывает корпус.
			# Блок — удержание этой позы, парирование — быстрый подъём щита
			["block", "Idle2", 6.0, true, ["seq", 12, 13, 14, 13], 0],
			["parry", "Idle2", 24.0, false, [8, 14], 0],
			# Контратака после парирования — удар щитом (начало Attack4)
			["pummel", "Attack4", 20.0, false, [0, 8], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Крестоносец: двуручник и плащ, медленный и тяжёлый. Длинный клинок в
	# Attack1/2/3/4 и Die местами срезан краем ячейки — отсюда feather.
	# Attack3 не используется (обрезан в 4 направлениях, а замен хватает)
	"crusader": {
		"src": "res://enemys/6Crusader/",
		"out": "res://enemy/humans/crusader/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 13.0, true, [0, 14], 0],
			["run", "Run", 18.0, true, [0, 14], 0],
			["attack", "Attack2", 20.0, false, [0, 14], 0],      # горизонтальный размах, ~50%
			["attack2", "Attack1", 18.0, false, [0, 14], 0],     # удар сверху / выпад (по направлению), ~62% (кадр 9)
			["attack3", "Attack4", 20.0, false, [0, 14], 0],     # широкий замах из-за спины, ~63%
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Щита нет: блок — клинок поперёк корпуса (кадр 7 Idle2, где он
			# крутит меч), парирование — быстрый вынос клинка навстречу (4-7)
			["block", "Idle2", 4.0, true, ["seq", 7, 7], 0],
			["parry", "Idle2", 24.0, false, [4, 7], 0],
			# Контратака — короткий размах из середины Attack2
			["pummel", "Attack2", 22.0, false, [4, 10], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Ассасин: одноручный клинок, плащ с капюшоном. Быстрый и хрупкий.
	# Касания края мелкие (1-3 px следа удара) — feather на всякий случай.
	# Attack4 (прыжок с вращением) не используется: след до 12 px упирается в край
	"assassin": {
		"src": "res://enemys/4Assassin/",
		"out": "res://enemy/humans/assassin/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 16.0, true, [0, 14], 0],
			["run", "Run", 22.0, true, [0, 14], 0],
			["attack", "Attack2", 22.0, false, [0, 14], 0],      # выпад, клинок вперёд — кадр 7
			["attack2", "Attack3", 22.0, false, [0, 14], 0],     # разворот, рубящий перед собой — кадр 6
			["attack3", "Attack1", 22.0, false, [0, 14], 0],     # связка, завершающий полосующий — кадр 10
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Idle2 — низкая стойка с клинком вперёд: это и есть его защита
			["block", "Idle2", 10.0, true, [0, 14], 0],
			# Парирование — клинок вскинут вверх (начало Attack3)
			["parry", "Attack3", 24.0, false, [2, 5], 0],
			# Контратака — короткий выпад из Attack2
			["pummel", "Attack2", 24.0, false, [5, 9], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Копейщик: длинное копьё, держит дистанцию. Атаки почти чистые (1-2 px),
	# но у лежащего тела в конце Die копьё упирается в край — отсюда feather
	"spearman": {
		"src": "res://enemys/12Guard/",
		"out": "res://enemy/humans/spearman/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack1", 20.0, false, [0, 14], 0],      # укол с подкруткой — кадр 7
			["attack2", "Attack2", 20.0, false, [0, 14], 0],     # вращение и выпад — кадр 8
			["attack3", "Attack3", 20.0, false, [0, 14], 0],     # двойной укол, урон на втором — кадр 9
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Блок — упор, копьё опущено остриём на противника (кадр 3 Attack2;
			# кадр 3 Attack3 не годится — там копьё отведено назад для замаха),
			# парирование — быстрое опускание копья навстречу (Attack2, 0-3)
			["block", "Attack2", 4.0, true, ["seq", 3, 3], 0],
			["parry", "Attack2", 22.0, false, [0, 3], 0],
			# Контратака — подсечка древком с пинком (Attack4)
			["pummel", "Attack4", 22.0, false, [1, 8], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Молотобоец: двуручный боевой молот. Головка молота срезана краем кадра
	# ещё при рендере пака (и в отдельных кадрах в Downloads тоже), поэтому
	# листы сначала чинит tools/repair_clipped.gd (см. команду там) — ячейка
	# 160 px, недостающая часть головки перенесена из целых кадров того же
	# направления. Attack2 и Taunt не используются: Attack2 обрезан сильнее
	# всех (слабые совпадения), Taunt не нужен enemy.gd
	"hammer": {
		"src": "res://enemys/1Hammer/",
		"out": "res://enemy/humans/hammer/",
		"cell": 160,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 13.0, true, [0, 14], 0],
			["run", "Run", 17.0, true, [0, 14], 0],
			["attack", "Attack1", 19.0, false, [0, 14], 0],      # удар сверху наискось — кадр 9
			["attack2", "Attack3", 18.0, false, [0, 14], 0],     # молот над головой и в землю — кадр 9
			["attack3", "Attack4", 19.0, false, [0, 14], 0],     # размашистый с разворота — кадр 9
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Блок — древко поперёк корпуса (кадр 5 Idle2, где он крутит молот),
			# парирование — быстрый вынос древка навстречу (3-5)
			["block", "Idle2", 4.0, true, ["seq", 5, 5], 0],
			["parry", "Idle2", 22.0, false, [3, 5], 0],
			# Контратака — короткий тычок головкой молота вперёд (начало Attack4)
			["pummel", "Attack4", 22.0, false, [0, 4], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
		],
	},
	# Громила в огненных рукавицах. Листы нарисованы в ячейке 192 px (фигура
	# крупнее), всё чистое — ничего не касается края. Attack3 (двойка) не
	# используется: три удара ниже разнообразнее
	"bruiser": {
		"src": "res://enemys/5Bruiser/",
		"out": "res://enemy/humans/bruiser/",
		"src_cell": 192,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 14.0, true, [0, 14], 0],
			["run", "Run", 18.0, true, [0, 14], 0],
			["attack", "Attack2", 20.0, false, [0, 14], 0],      # джеб — кадр 7
			["attack2", "Attack1", 20.0, false, [0, 14], 0],     # огненный удар — кадр 8
			["attack3", "Attack4", 18.0, false, [0, 14], 0],     # двумя кулаками в землю — кадр 6
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Idle2 — боксёрская стойка, кулаки перед лицом: это и есть блок
			["block", "Idle2", 8.0, true, [0, 14], 0],
			# Парирование — быстрый подъём кулаков (начало Attack2)
			["parry", "Attack2", 24.0, false, [1, 4], 0],
			# Контратака — джеб
			["pummel", "Attack2", 22.0, false, [4, 9], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Драчун с кастетами: легче и быстрее громилы. Ячейка 192 px, всё чистое.
	# Attack3 (двойка) не используется — повторяет джеб
	"brawler": {
		"src": "res://enemys/8Brawler/",
		"out": "res://enemy/humans/brawler/",
		"src_cell": 192,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack2", 22.0, false, [0, 14], 0],      # джеб — кадр 6
			["attack2", "Attack1", 20.0, false, [0, 14], 0],     # размашистый хук — кадр 8
			["attack3", "Attack4", 20.0, false, [0, 14], 0],     # нырок и встречный — кадр 7
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			# Idle2 — руки скрещены перед грудью: защита
			["block", "Idle2", 8.0, true, [0, 14], 0],
			# Парирование — нырок под удар (Attack4, 3-5)
			["parry", "Attack4", 22.0, false, [3, 5], 0],
			# Контратака — джеб
			["pummel", "Attack2", 24.0, false, [4, 8], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Стрелок с магическим ружьём (бак за спиной). Снаряды выпускает
	# ranged_enemy.gd в кадры вспышек: Attack1 — кадр 10, Attack4 — 7 и 12,
	# Attack3 — веер по кругу, кадры 6-13. Края задевают только вспышки у дула
	# и падающее ружьё в середине Die (кадры 9-11) — feather.
	# Блока у стрелков нет (шансы 0): block/parry/pummel — запасные клипы,
	# чтобы спрайт не замёрз, если код всё же их запросит
	"shooter": {
		"src": "res://enemys/2Shooter/",
		"out": "res://enemy/humans/shooter/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack1", 20.0, false, [0, 14], 0],
			["attack2", "Attack4", 20.0, false, [0, 14], 0],
			["attack3", "Attack3", 20.0, false, [0, 14], 0],
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			["block", "Idle2", 8.0, true, [0, 14], 0],
			["parry", "Idle2", 22.0, false, [0, 4], 0],
			["pummel", "Attack2", 22.0, false, [11, 14], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Снайпер: та же раскадровка, что у стрелка, другая винтовка (красная вспышка)
	"sniper": {
		"src": "res://enemys/7Sniper/",
		"out": "res://enemy/humans/sniper/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack1", 18.0, false, [0, 14], 0],
			["attack2", "Attack2", 18.0, false, [0, 14], 0],
			["attack3", "Attack4", 18.0, false, [0, 14], 0],
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			["block", "Idle2", 8.0, true, [0, 14], 0],
			["parry", "Idle2", 22.0, false, [0, 4], 0],
			["pummel", "Attack2", 22.0, false, [11, 14], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Маги (ranged_enemy.gd). attack4 — четвёртая атака сверх обязательных
	# трёх: enemy.gd играет любой клип по имени, attack4 берётся только вблизи
	# (close_only в сцене). Блока у магов нет — block/parry/pummel запасные
	"commander": {
		"src": "res://enemys/9Commander/",
		"out": "res://enemy/humans/commander/",
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack1", 20.0, false, [0, 14], 0],      # толчок обеими руками — поток сгустков, кадры 6/8/10
			["attack2", "Attack2", 20.0, false, [0, 14], 0],     # вихрь и бросок — кадр 9
			["attack3", "Attack3", 20.0, false, [0, 14], 0],     # собранный сгусток вперёд — кадр 8
			["attack4", "Attack4", 22.0, false, [0, 14], 0],     # удар ногой (вблизи) — кадр 7
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			["block", "Idle2", 8.0, true, [0, 14], 0],
			["parry", "Idle2", 22.0, false, [0, 4], 0],
			["pummel", "Attack4", 24.0, false, [4, 8], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	"caster": {
		"src": "res://enemys/10Caster/",
		"out": "res://enemy/humans/caster/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 14.0, true, [0, 14], 0],
			["run", "Run", 18.0, true, [0, 14], 0],
			["attack", "Attack1", 18.0, false, [0, 14], 0],      # сгусток с руки — кадр 10
			["attack2", "Attack2", 18.0, false, [0, 14], 0],     # с навершия посоха — кадр 7
			["attack3", "Attack3", 18.0, false, [0, 14], 0],     # удар посохом (вблизи) — кадр 9
			["attack4", "Attack4", 18.0, false, [0, 14], 0],     # взрыв вокруг себя (вблизи) — кадр 6
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			["block", "Idle2", 8.0, true, [0, 14], 0],
			["parry", "Idle2", 22.0, false, [0, 4], 0],
			["pummel", "Attack3", 22.0, false, [7, 10], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Тайный элементаль. Сфера в Attack4 на кадрах 10-12 упирается в край
	# ячейки (одинаково во всех направлениях — это эффект поверх фигуры) —
	# эти кадры выкинуты: сфера дорастает (8-9) и сразу оседающие искры (13-14),
	# переход прикрывает кольцо взрыва из ranged_enemy.gd
	"arcane": {
		"src": "res://enemys/11Arcane elemental/",
		"out": "res://enemy/humans/arcane/",
		"feather": 8,
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 15.0, true, [0, 14], 0],
			["run", "Run", 20.0, true, [0, 14], 0],
			["attack", "Attack1", 20.0, false, [0, 14], 0],      # веер из трёх искр — кадр 6
			["attack2", "Attack2", 20.0, false, [0, 14], 0],     # одиночная искра — кадр 9
			["attack3", "Attack3", 20.0, false, [0, 14], 0],     # пара искр — кадры 6 и 8
			["attack4", "Attack4", 18.0, false, ["seq", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14], 0],  # сфера (вблизи)
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			["block", "Idle2", 8.0, true, [0, 14], 0],
			["parry", "Idle2", 22.0, false, [0, 4], 0],
			["pummel", "Attack1", 24.0, false, [4, 7], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Taunt", 12.0, false, [0, 14], 0],
		],
	},
	# Боевой пёс (овчарка). Листы чистые. Attack4 (кувырок с трёпкой) не
	# используется — момент укуса в нём не читается. Howl — вой (taunt).
	# Блока у пса нет: block/parry/pummel — запасные клипы
	"dog": {
		"src": "res://enemys/13Shepard/",
		"out": "res://enemy/beasts/dog/",
		"clips": [
			["idle2", "Idle", 10.0, true, [0, 14], 0],
			["walk", "Walk", 16.0, true, [0, 14], 0],
			["run", "Run", 22.0, true, [0, 14], 0],
			["attack", "Attack1", 22.0, false, [0, 14], 0],      # бросок с укусом — кадр 6
			["attack2", "Attack2", 20.0, false, [0, 14], 0],     # прыжок на цель — кадр 8
			["attack3", "Attack3", 22.0, false, [0, 14], 0],     # щелчок зубами низко — кадр 4
			["take_damage", "TakeDamage", 20.0, false, [0, 14], 0],
			["stagger", "TakeDamage", 18.0, false, [0, 14], 0],
			["stagger2", "TakeDamage", 15.0, false, [0, 14], 0],
			["stagger3", "TakeDamage", 16.0, false, [2, 14], 0],
			["block", "Idle2", 8.0, true, [0, 14], 0],
			["parry", "Attack3", 22.0, false, [0, 2], 0],
			["pummel", "Attack1", 24.0, false, [4, 7], 0],
			["die", "Die", 15.0, false, [0, 14], 0],
			["taunt", "Howl", 12.0, false, [0, 14], 0],
		],
	},
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var clean := "--clean" in args
	var only: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			only.append(a)
	for id in TYPES:
		if only.is_empty() or id in only:
			if clean:
				_clean(id, TYPES[id])
			else:
				_build(id, TYPES[id])
	quit()


## Лист, из которого брать кадры: очищенная копия, если она есть
func _sheet_path(t: Dictionary, sheet: String) -> String:
	var fixed: String = t["out"] + "sheets/" + sheet + "_Shadowless.png"
	if ResourceLoader.exists(fixed):
		return fixed
	return t["src"] + sheet + "_Shadowless.png"


# ───────────── очистка обрезанных краёв ─────────────

func _clean(id: String, t: Dictionary) -> void:
	var band: int = t.get("feather", 0)
	if band <= 0:
		print("%s: feather не задан — очищать нечего" % id)
		return
	var dir: String = t["out"] + "sheets/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var done := {}
	for c in t["clips"]:
		var sheet: String = c[1]
		if done.has(sheet):
			continue
		done[sheet] = true
		var src: String = t["src"] + sheet + "_Shadowless.png"
		var img := (load(src) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var fixed := 0
		for r in img.get_height() / CELL:
			for col in img.get_width() / CELL:
				if _feather_cell(img, col * CELL, r * CELL, band):
					fixed += 1
		var dst := dir + sheet + "_Shadowless.png"
		if fixed > 0:
			img.save_png(ProjectSettings.globalize_path(dst))
			print("%s: %s — исправлено кадров: %d -> %s" % [id, sheet, fixed, dst])
		elif FileAccess.file_exists(dst):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dst))
	print("%s: очистка готова. Теперь импорт (редактор или --import), затем сборка без --clean" % id)


## Растворяет всё, что соединено с краем ячейки, в полосе band px от края.
## Вернёт true, если в ячейке что-то касалось края
func _feather_cell(img: Image, ox: int, oy: int, band: int) -> bool:
	var seen := {}
	var queue: Array[Vector2i] = []
	for i in CELL:
		for p in [Vector2i(i, 0), Vector2i(i, CELL - 1), Vector2i(0, i), Vector2i(CELL - 1, i)]:
			if not seen.has(p) and img.get_pixel(ox + p.x, oy + p.y).a > 0.02:
				seen[p] = true
				queue.append(p)
	if queue.is_empty():
		return false
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= CELL or n.y >= CELL or seen.has(n):
				continue
			if _edge_dist(n) >= band:
				continue
			if img.get_pixel(ox + n.x, oy + n.y).a > 0.02:
				seen[n] = true
				queue.append(n)
	for p in queue:
		var k := smoothstep(0.0, float(band), float(_edge_dist(p)) + 0.5)
		var col := img.get_pixel(ox + p.x, oy + p.y)
		col.a *= k
		img.set_pixel(ox + p.x, oy + p.y, col)
	return true


func _edge_dist(p: Vector2i) -> int:
	return mini(mini(p.x, p.y), mini(CELL - 1 - p.x, CELL - 1 - p.y))


func _frames(spec: Array) -> Array:
	if spec.size() > 0 and spec[0] is String and spec[0] == "seq":
		return spec.slice(1)
	return range(int(spec[0]), int(spec[1]) + 1)


func _build(id: String, t: Dictionary) -> void:
	var out: String = t["out"]
	var have := {}
	for c in t["clips"]:
		have[c[0]] = true
	var missing := REQUIRED.filter(func(r): return not have.has(r))
	if not missing.is_empty():
		push_error("%s: не хватает обязательных клипов %s — ничего не сохранено" % [id, missing])
		return

	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var lib := AnimationLibrary.new()
	var atlas_cache := {}
	var textures := {}
	for c in t["clips"]:
		var clip: String = c[0]
		var path: String = _sheet_path(t, String(c[1]))
		if not textures.has(path):
			if not ResourceLoader.exists(path):
				push_error("%s: нет листа %s — ничего не сохранено" % [id, path])
				return
			textures[path] = load(path)
		var tex: Texture2D = textures[path]
		# Увеличенная ячейка (repair_clipped.gd) — только из починенных листов
		# src_cell — родной размер ячейки листа (громилы нарисованы в 192 px)
		var cell: int = int(t.get("cell", t.get("src_cell", CELL)))
		if t.has("cell") and not path.begins_with(String(t["out"]) + "sheets/"):
			push_error("%s: лист %s не починен под ячейку %d — запустите tools/repair_clipped.gd" % [id, path, cell])
			return
		var fps: float = c[2]
		var loop: bool = c[3]
		var frames := _frames(c[4])
		var row_shift: int = c[5]
		for d in DIRS.size():
			var row := posmod(d + row_shift, DIRS.size())
			var name := StringName(clip + "_" + DIRS[d])
			sf.add_animation(name)
			sf.set_animation_speed(name, fps)
			sf.set_animation_loop(name, loop)
			for f in frames:
				var key := "%s/%d/%d" % [path, row, f]
				if not atlas_cache.has(key):
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(int(f) * cell, row * cell, cell, cell)
					# Без фильтрации соседей по атласу: кадры не "подтекают" друг в друга
					at.filter_clip = true
					atlas_cache[key] = at
				sf.add_frame(name, atlas_cache[key])
			var n := frames.size()
			var a := Animation.new()
			a.length = n / fps
			a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			var tr := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(tr, NodePath("AnimatedSprite2D:frame"))
			a.value_track_set_update_mode(tr, Animation.UPDATE_DISCRETE)
			for i in n:
				a.track_insert_key(tr, i / fps, i)
			var tr2 := a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(tr2, NodePath("AnimatedSprite2D:animation"))
			a.value_track_set_update_mode(tr2, Animation.UPDATE_DISCRETE)
			a.track_insert_key(tr2, 0.0, name)
			lib.add_animation(name, a)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var e1 := ResourceSaver.save(sf, out + id + "_frames.tres")
	var e2 := ResourceSaver.save(lib, out + id + "_anims.tres")
	print("%s: clips=%d atlases=%d save=%d,%d" % [id, sf.get_animation_names().size(), atlas_cache.size(), e1, e2])
