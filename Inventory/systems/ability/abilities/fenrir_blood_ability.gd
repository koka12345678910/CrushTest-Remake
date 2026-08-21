# res://systems/ability/abilities/fenrir_blood_ability.gd
class_name FenrirBloodAbility
extends Ability

@export var duration: float = 15.0
@export var speed_bonus: float = 100.0
@export var damage_multiplier_start: float = 1.2
@export var damage_multiplier_peak: float = 2.5

# Рычание волка на активацию. Питч занижен — низкий рык звучит тяжелее и
# первобытнее, чем тот же семпл на исходной высоте
@export var growl_pitch := 0.74
const GROWL_SOUND := preload("res://Sound/abilities_sound/fenrir_blood.mp3")

func _init() -> void:
	ability_name = "Кровь Фенрира"
	cooldown_duration = 60.0
	description = "Неуязвимость к урону и контролю, сила растёт по ходу действия"
	icon = load("res://Shop/icons/demon_flask.png")

func _execute(player: Node) -> void:
	# Неуязвимость через существующую систему i-frames — теперь снимает и стан от контратак
	player.is_invulnerable = true
	player.active_ability_name = "fenrir"

	# Применяем бафф — множитель урона будет расти по ходу действия способности
	var buff_data := {
		"speed_bonus": speed_bonus,
		"damage_multiplier": damage_multiplier_start,
		"duration": duration,
		"name": "fenrir_blood",
		"invulnerable": true
	}
	if player.has_method("apply_buff"):
		player.apply_buff(buff_data)

	# Растущая сила — волк рвёт цепи и набирает мощь к концу действия способности
	var power_tween := player.create_tween()
	power_tween.tween_method(
		func(v: float): buff_data["damage_multiplier"] = v,
		damage_multiplier_start, damage_multiplier_peak, duration
	)

	# Подмена VFX удара на время действия способности
	if player.has_method("set") and "fenrir_hit_vfx_scene" in player:
		player.active_hit_vfx_override = player.fenrir_hit_vfx_scene

	# Вспышка с силуэтом волка при активации
	var flash_fx := player.get_node_or_null("Camera2D/CanvasLayer/FenrirFlash")
	if flash_fx:
		flash_fx.play()

	# Рычание волка на активацию — с реверб-хвостом (шина FenrirEcho) и
	# заниженным питчем, чтобы звучало тяжело и первобытно
	var growl_audio := player.get_node_or_null("FenrirAudio")
	if growl_audio:
		growl_audio.stream = GROWL_SOUND
		growl_audio.pitch_scale = growl_pitch
		growl_audio.play()

	# Снимаем неуязвимость и VFX через duration секунд
	player.get_tree().create_timer(duration).timeout.connect(
		func():
			player.is_invulnerable = false
			player.active_hit_vfx_override = null
			print("[КровьФенрира] Эффект закончился")
	)

	print("[КровьФенрира] Активирована! Неуязвимость на ", duration, " сек")
