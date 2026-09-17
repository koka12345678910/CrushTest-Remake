extends Node
## SkillTrees.gd — реестр деревьев навыков (автозагрузка), тот же приём, что
## у Characters.gd: один файл с чистыми данными, ничего не спавнит и не
## считает сам. UI (Inventory/ui/skill_tree_panel.gd) строит экран из этих
## данных, а применяет эффекты сам персонаж (см. player.gd::recompute_skill_modifiers) —
## этот файл только ХРАНИТ, что вообще существует и как узлы связаны друг с другом.
##
## Схема одного узла:
##   id                    — уникальный строковый id внутри ВСЕХ деревьев сразу
##   name                  — заголовок узла (кириллица, как в игре)
##   lore                  — короткая lore-строка для тултипа
##   effect_text           — человекочитаемое описание эффекта для тултипа
##   cost                  — сколько skill_points стоит открыть
##   prerequisites         — Array[String] id узлов, ВСЕ должны быть открыты
##   min_unlocked_in_tree  — доп. условие (только у capstone): сколько узлов
##                           этого дерева суммарно уже должно быть открыто
##   is_capstone           — отдельный визуальный стиль в UI
##   row / col             — позиция в сетке дерева (col — дробный, от 0 до
##                           ширины самого широкого ряда минус 1, для центровки
##                           узлов над своими потомками)
##   effects               — Dictionary с ключами, которые понимает
##                           player.gd::recompute_skill_modifiers(). Только
##                           заранее известные ключи, никакой строковой магии

## Единственное реализованное дерево — Руны Стойкости (Рыцарь). Клык Берсерка
## и Воля Эйнхерия — задел на будущее, намеренно пустые (см. договорённость:
## не реализовывать их на этом этапе)
const RUNES_OF_ENDURANCE := "runes_of_endurance"
const BERSERKER_FANG := "berserker_fang"
const WILL_OF_EINHERJAR := "will_of_einherjar"

const TREES := {
	RUNES_OF_ENDURANCE: {
		"name": "РУНЫ СТОЙКОСТИ",
		"tagline": "Путь несокрушимого рыцаря",
		"description": "Укрепляй тело, защищайся от любых ударов и стой там, где другие падают.",
		"nodes": [
			{
				"id": "stone_heart",
				"name": "КАМЕННОЕ СЕРДЦЕ",
				"lore": "Фундамент стойкости рыцаря. Сердце твёрже камня.",
				"effect_text": "+8% к максимальному здоровью",
				"cost": 1,
				"prerequisites": [],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 0, "col": 1.5,
				"effects": {"max_hp_percent": 8.0},
			},
			{
				"id": "rock_breath",
				"name": "ДЫХАНИЕ СКАЛЫ",
				"lore": "Учись дышать глубоко и спокойно, пока буря бьёт о твой щит.",
				"effect_text": "+10% к максимальной выносливости",
				"cost": 1,
				"prerequisites": ["stone_heart"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 1, "col": 0.5,
				"effects": {"max_stamina_percent": 10.0},
			},
			{
				"id": "iron_blood",
				"name": "ЖЕЛЕЗНАЯ КРОВЬ",
				"lore": "Кровь в жилах становится густой, как расплавленное железо.",
				"effect_text": "+8% к физической защите",
				"cost": 1,
				"prerequisites": ["stone_heart"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 1, "col": 2.5,
				"effects": {"physical_defense_percent": 8.0},
			},
			{
				"id": "shield_rune",
				"name": "РУНА ЩИТА",
				"lore": "Древние руны усиливают твой щит, заставляя удары скользить по нему.",
				"effect_text": "-10% получаемого урона во время блока",
				"cost": 1,
				"prerequisites": ["rock_breath"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 2, "col": 0.0,
				"effects": {"block_damage_reduction_percent": 10.0},
			},
			{
				"id": "stone_stance",
				"name": "КАМЕННАЯ СТОЙКА",
				"lore": "Ты становишься неподвижен, как скала, когда враг пытается сломить тебя.",
				"effect_text": "+15% сопротивления урону стойкости",
				"cost": 1,
				"prerequisites": ["rock_breath"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 2, "col": 1.0,
				"effects": {"posture_resist_percent": 15.0},
			},
			{
				"id": "unyielding",
				"name": "НЕСГИБАЕМЫЙ",
				"lore": "Никакая сила не заставит тебя отступить или пошатнуться.",
				"effect_text": "+25% сопротивления ошеломлению",
				"cost": 1,
				"prerequisites": ["iron_blood"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 2, "col": 2.0,
				"effects": {"stagger_resist_percent": 25.0},
			},
			{
				"id": "giant_bones",
				"name": "КОСТИ ВЕЛИКАНА",
				"lore": "Твои кости уплотняются, словно кости древних великанов.",
				"effect_text": "+12% к максимальному здоровью",
				"cost": 1,
				"prerequisites": ["iron_blood"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 2, "col": 3.0,
				"effects": {"max_hp_percent": 12.0},
			},
			{
				"id": "iron_oath",
				"name": "ЖЕЛЕЗНЫЙ ОБЕТ",
				"lore": "Каждый раз, когда ты поднимаешь щит, ты даёшь обет выстоять любой ценой.",
				"effect_text": "-15% траты выносливости при блоке. После полного блока следующая атака наносит +10% урона стойкости",
				"cost": 1,
				"prerequisites": ["shield_rune", "stone_stance"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 3, "col": 0.5,
				"effects": {
					"block_stamina_cost_reduction_percent": 15.0,
					"block_followup_posture_bonus_percent": 10.0,
				},
			},
			{
				"id": "mountain_stance",
				"name": "ГОРНАЯ СТОЙКА",
				"lore": "Ты стоишь, как гора. Враги бьются о тебя, но не могут сдвинуть.",
				"effect_text": "+30% сопротивления урону стойкости",
				"cost": 1,
				"prerequisites": ["unyielding", "giant_bones"],
				"min_unlocked_in_tree": 0,
				"is_capstone": false,
				"row": 3, "col": 2.5,
				"effects": {"posture_resist_percent": 30.0},
			},
			{
				"id": "jotun_heart",
				"name": "СЕРДЦЕ ЙОТУНА",
				"lore": "Твоё сердце бьётся в такт с горами. Ты — стена между врагом и всем, что тебе дорого.",
				"effect_text": "+15% макс. здоровья, +10% физ. защиты, +20% сопротивления ошеломлению. Пока здоровье выше 70% — получаемый урон стойкости дополнительно -15%",
				"cost": 3,
				"prerequisites": ["iron_oath", "mountain_stance"],
				"min_unlocked_in_tree": 6,
				"is_capstone": true,
				"row": 4, "col": 1.5,
				"effects": {
					"max_hp_percent": 15.0,
					"physical_defense_percent": 10.0,
					"stagger_resist_percent": 20.0,
					"capstone_conditional_posture_resist": true,
				},
			},
		],
	},
	# Задел на будущее — те же деревья, что обсуждали, но без узлов, пока не
	# дизайним их отдельно (см. договорённость в чате)
	BERSERKER_FANG: {"name": "КЛЫК БЕРСЕРКА", "tagline": "", "description": "", "nodes": []},
	WILL_OF_EINHERJAR: {"name": "ВОЛЯ ЭЙНХЕРИЯ", "tagline": "", "description": "", "nodes": []},
}


func get_tree_data(tree_id: String) -> Dictionary:
	return TREES.get(tree_id, {})


func get_nodes(tree_id: String) -> Array:
	return get_tree_data(tree_id).get("nodes", [])


func get_node_data(tree_id: String, node_id: String) -> Dictionary:
	for n in get_nodes(tree_id):
		if n["id"] == node_id:
			return n
	return {}
