# res://systems/ability/abilities/valkyrie_song_ability.gd
class_name ValkyrieSongAbility
extends Ability

@export var heal_per_tick: float = 6.0
@export var tick_interval: float = 0.5
@export var total_ticks: int = 6

# Через preload, а не по глобальному имени класса — см. комментарий в
# honey_mead_ability.gd
const HEAL_VFX := preload("res://VFX/VFX_scene/heal_vfx.gd")

func _init() -> void:
	ability_name = "Песнь Валькирии"
	cooldown_duration = 15.0
	description = "Постепенно лечит и снимает все негативные эффекты"
	icon = load("res://Shop/icons/flask_gold.png")

func _execute(player: Node) -> void:
	# Сначала игрок пьёт, и только когда звук доиграет — начинается действие
	if player.has_method("play_drink_sound"):
		await player.play_drink_sound()
	# За время питья игрок мог погибнуть и быть выгружен из сцены
	if not is_instance_valid(player):
		return

	# Снимаем негативные эффекты
	if player.has_method("clear_negative_effects"):
		player.clear_negative_effects()
	# TODO: когда появятся статусы — раскомментировать:
	# player.remove_status("poison")
	# player.remove_status("bleed")
	# player.remove_status("slow")

	# Постепенное лечение — бело-золотой тик, холоднее и "небеснее" тёплого
	# янтаря Мёда: механика та же, но на глаз способности должны различаться
	player.start_heal_over_time(heal_per_tick, tick_interval, total_ticks,
		Color(1.5, 1.45, 1.1, 1.0))

	# Кольцо очищения (внутри VFX) + перья, падающие ВНИЗ — визуальная
	# противоположность поднимающимся искрам Мёда
	var vfx = HEAL_VFX.new()
	vfx.variant = HEAL_VFX.Variant.VALKYRIE
	vfx.duration = tick_interval * total_ticks
	player.add_child(vfx)

	print("[ВалькирияСонг] Снял негативные эффекты и начал лечение")
