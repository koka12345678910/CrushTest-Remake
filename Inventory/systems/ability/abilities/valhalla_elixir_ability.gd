# res://systems/ability/abilities/valhalla_elixir_ability.gd
class_name ValhallaElixirAbility
extends Ability

@export var heal_amount: float = 60.0  # не 100% — как по описанию
# Лёгкий толчок камеры: лечение мгновенное, поэтому и отдача должна быть
# рваной. Слабее удара по игроку — это не урон, а прилив сил
@export var punch_shake: float = 4.0

# Через preload, а не по глобальному имени класса — см. комментарий в
# honey_mead_ability.gd
const HEAL_VFX := preload("res://VFX/VFX_scene/heal_vfx.gd")

func _init() -> void:
	ability_name = "Эликсир Вальгаллы"
	cooldown_duration = 8.0
	description = "Моментально восстанавливает здоровье"
	icon = load("res://Shop/icons/flask_red.png")

func _execute(player: Node) -> void:
	# Сначала игрок пьёт, и только когда звук доиграет — приходит лечение
	if player.has_method("play_drink_sound"):
		await player.play_drink_sound()
	# За время питья игрок мог погибнуть и быть выгружен из сцены
	if not is_instance_valid(player):
		return

	if player.has_method("heal"):
		player.heal(heal_amount)

	# Один резкий взрыв вместо тянущегося шлейфа — темп эффекта повторяет темп
	# самой способности (мгновенно), в отличие от Мёда и Песни
	var vfx = HEAL_VFX.new()
	vfx.variant = HEAL_VFX.Variant.ELIXIR
	player.add_child(vfx)

	# Короткая красно-золотая вспышка и толчок камеры
	if player.has_method("flash_tint"):
		player.flash_tint(Color(2.2, 0.9, 0.7, 1.0), 0.04, 0.2)
	if player.has_method("shake_camera"):
		player.shake_camera(punch_shake)

	print("[ЭликсирВальгаллы] Мгновенное лечение на ", heal_amount)
