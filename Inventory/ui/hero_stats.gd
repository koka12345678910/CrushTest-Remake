extends RefCounted
## hero_stats.gd — строки «Саги героя» в правой колонке инвентаря
## (hero_inventory_skin.gd::_build_saga): живые значения персонажа с учётом
## надетых талисманов, трофеев и прокачки. Только чтение — ничего не меняет.
##
## Строка — [подпись, значение, бонус]. Бонус — короткая приписка зелёным
## ("+10", "×1.5"), "" — нет бонуса. Персонажи разные (рыцарь — player.gd,
## лучница — archer.gd, маг — mage.gd), поэтому всё через get()/has_method():
## у одного героя поля другого нет.

const Trophies := preload("res://Player_scene/knight_trophies.gd")


static func rows(p: Node) -> Array:
	if p == null:
		return []
	match p.get("character_id"):
		"archer":
			return _archer(p)
		"mage":
			return _mage(p)
		"druid":
			return _druid(p)
		_:
			return _knight(p)


static func _num(v: float) -> String:
	return str(int(roundf(v)))


static func _pct(v: float) -> String:
	return "%d%%" % int(roundf(v * 100.0))


## Здоровье и выносливость — с полоски HUD (она источник правды у всех трёх)
static func _vitals(p: Node, hp_bonus := 0.0, st_bonus := 0.0) -> Array:
	var out := []
	var bar = p.get("health_bar")
	var hp: float = p.get("health") if p.get("health") != null else 0.0
	var max_hp: float = p.get("max_health") if p.get("max_health") != null else 0.0
	if bar != null and bar.get("current_hp") != null:
		hp = bar.current_hp
	out.append(["Здоровье", "%s / %s" % [_num(hp), _num(max_hp)], ("+" + _num(hp_bonus)) if hp_bonus > 0.0 else ""])
	if bar != null and bar.get("max_stamina") != null:
		out.append(["Выносливость", _num(bar.max_stamina), ("+" + _num(st_bonus)) if st_bonus > 0.0 else ""])
	return out


static func _knight(p: Node) -> Array:
	var counts: Dictionary = p.get("trophy_counts") if p.get("trophy_counts") != null else {}
	var out := _vitals(p, Trophies.bonus("max_hp", counts), Trophies.bonus("max_stamina", counts))
	var defense := 0.0
	if p.has_method("get_damage_reduction_factor"):
		defense = 1.0 - p.get_damage_reduction_factor()
	out.append(["Защита", _pct(defense), ""])
	var posture := 0.0
	if p.has_method("get_posture_damage_reduction_factor"):
		posture = 1.0 - p.get_posture_damage_reduction_factor()
	out.append(["Стойкость", _pct(posture), ""])
	var mult := 1.0
	if p.has_method("get_damage_multiplier"):
		mult = p.get_damage_multiplier()
	out.append(["Сила удара", "×%.1f" % mult, ""])
	var magic = p.get("magic")
	if magic != null:
		var extra := Trophies.bonus("max_odr", counts)
		out.append(["Одр", "%s / %s" % [_num(magic.odr), _num(magic.max_odr)], ("+" + _num(extra)) if extra > 0.0 else ""])
	out.append(["Золото", str(p.get("gold")), ""])
	out.append(["Очки навыков", str(p.get("skill_points")), ""])
	out.append(["Трофеи", "%d / %d" % [Trophies.done_count(counts), Trophies.LIST.size()], ""])
	return out


static func _archer(p: Node) -> Array:
	var out := _vitals(p)
	var crit := float(p.get("BASE_CRIT_CHANCE"))
	var crit_bonus := 0.0
	if float(p.get("_last_look_time")) > 0.0:
		crit_bonus += float(p.get("LAST_LOOK_CRIT_BONUS"))
	out.append(["Урон стрелы", "%d–%d" % [int(p.get("charge_min_damage")), int(p.get("charge_max_damage"))], ""])
	out.append(["Шанс крита", _pct(crit + crit_bonus), ("+" + _pct(crit_bonus)) if crit_bonus > 0.0 else ""])
	if p.has_method("_has_talisman") and p._has_talisman(p.get("TALISMAN_NORN")):
		out.append(["Крит по раненым", _pct(crit + crit_bonus + float(p.get("NORN_CRIT_BONUS"))), "Игла Норн"])
	out.append(["Крит. урон", "×%d" % int(p.get("CRIT_MULT")), ""])
	out.append(["Золото", str(p.get("gold")), ""])
	out.append(["Очки навыков", str(p.get("skill_points")), ""])
	return out


static func _druid(p: Node) -> Array:
	var out := _vitals(p)
	out.append(["Рост", "%s / %s" % [_num(p.get("growth")), _num(p.get("max_growth"))], ""])
	var heal_pct: float = p.skill("heal_power_percent") if p.has_method("skill") else 0.0
	out.append(["Сила лечения", "×%.2f" % (1.0 + heal_pct / 100.0), ""])
	out.append(["Золото", str(p.get("gold")), ""])
	out.append(["Очки навыков", str(p.get("skill_points")), ""])
	return out


static func _mage(p: Node) -> Array:
	var out := _vitals(p)
	var vessel := int(p.get("vessel_level"))
	out.append(["Сейд", "%s / %s" % [_num(p.get("seid")), _num(p.get("max_seid"))],
			("+" + _num(vessel * float(p.get("VESSEL_SEID")))) if vessel > 0 else ""])
	var mimir: bool = p.has_method("_has_talisman") and p._has_talisman(p.get("TALISMAN_MIMIR"))
	var k: float = float(p.get("MIMIR_REGEN")) if mimir else 1.0
	# Подписи и простые значения переводит при отрисовке SagaPanel (tr), а
	# составную строку — здесь: шаблон переводится до подстановки чисел
	out.append(["Восполнение", String(TranslationServer.translate("%s/с · %s/с в покое")) % [_num(float(p.get("seid_regen")) * k), _num(float(p.get("seid_regen_rested")) * k)],
			("×%.1f" % k) if mimir else ""])
	# Скидка на заклинания — средняя по четырём рунам (ранги + Гандр вёльвы)
	var base := 0.0
	var now := 0.0
	for i in 4:
		base += p.base_spell_cost(i)
		now += p.spell_cost(i)
	var discount := 1.0 - now / maxf(base, 1.0)
	out.append(["Цена заклинаний", ("−" + _pct(discount)) if discount > 0.005 else "обычная", ""])
	out.append(["Души", str(p.get("souls")), ""])
	var draupnir: bool = p.has_method("_has_talisman") and p._has_talisman(p.get("TALISMAN_DRAUPNIR"))
	out.append(["Сбор душ", "×%.1f" % (float(p.get("DRAUPNIR_SOULS")) if draupnir else 1.0), "Драупнир" if draupnir else ""])
	out.append(["Очки навыков", str(p.get("skill_points")), ""])
	return out
