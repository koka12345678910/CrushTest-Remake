# res://systems/ability/abilities/honey_mead_ability.gd
class_name HoneyMeadAbility
extends Ability

@export var heal_per_tick: float = 8.0
@export var tick_interval: float = 0.5
@export var total_ticks: int = 6  # лечит 6 раз = 48 HP суммарно

# Через preload, а не по глобальному имени класса: class_name регистрируется
# только когда редактор пересканирует проект, и до этого обращение к HealVFX
# по имени валится с "Identifier not declared" уже в самой игре
const HEAL_VFX := preload("res://VFX/VFX_scene/heal_vfx.gd")

func _init() -> void:
	ability_name = "Мёд Поэзии"
	cooldown_duration = 12.0
	description = "Постепенно восстанавливает здоровье"
	icon = load("res://Shop/icons/jar_honey.png")

func _execute(player: Node) -> void:
	# Сначала игрок пьёт, и только когда звук доиграет — начинается лечение
	if player.has_method("play_drink_sound"):
		await player.play_drink_sound()
	# За время питья игрок мог погибнуть и быть выгружен из сцены
	if not is_instance_valid(player):
		return

	# Тёплый янтарный тик — под цвет самого мёда
	player.start_heal_over_time(heal_per_tick, tick_interval, total_ticks,
		Color(1.6, 1.25, 0.6, 1.0))

	# Искры неспешно поднимаются всё время действия — медленный эффект должен
	# и выглядеть медленным, в отличие от разового эликсира
	var vfx = HEAL_VFX.new()
	vfx.variant = HEAL_VFX.Variant.HONEY
	vfx.duration = tick_interval * total_ticks
	player.add_child(vfx)
