extends Node
## LevelMusicManager.gd
## Динамическая музыка уровня, как в Sekiro: пока ни один враг не видит
## игрока — играет спокойный трек, как только враг замечает игрока
## (see_player = true) — плавный кроссфейд на боевой трек, и обратно,
## когда все враги теряют игрока из виду.

@export var calm_music: AudioStream
@export var combat_music: AudioStream
@export var crossfade_time := 1.5
@export var check_interval := 0.3

# Дождь — постоянная атмосфера уровня: обычная громкость в спокойствии,
# приглушается (не выключается), когда враг заметил игрока и звучит музыка.
# Сам поток дождя, зацикливание (в импорте) и autoplay заданы прямо в сцене
# на узле RainPlayer — как в главном меню, где такой же дождь стабильно играет.
# Здесь мы им НЕ управляем через play(), только держим громкость.
@export var rain_volume_calm := -15.0
@export var rain_volume_combat := -12.0

@onready var calm_player: AudioStreamPlayer = $CalmPlayer
@onready var combat_player: AudioStreamPlayer = $CombatPlayer
@onready var rain_player: AudioStreamPlayer = $RainPlayer

var _in_combat := false
var _check_timer := 0.0
var _fade_tween: Tween

const SILENT_DB := -80.0

func _ready() -> void:
	_force_loop(calm_music)
	_force_loop(combat_music)

	calm_player.stream = calm_music
	combat_player.stream = combat_music

	# Оба трека всегда играют синхронно — переключаем только громкость,
	# так музыка не дёргается и не сбивается с такта при смене состояния
	calm_player.volume_db = 0.0
	combat_player.volume_db = SILENT_DB
	# Дождь стартует сам (autoplay в сцене); задаём его спокойную громкость.
	# Зацикливаем НЕ через loop_mode потока (менять его на живом autoplay-
	# воспроизведении рвёт звук — с невалидным loop_end получается петля нулевой
	# длины и тишина), а перезапуском: когда одноразовый поток доигрывает,
	# сигнал finished запускает его заново.
	rain_player.volume_db = rain_volume_calm
	if not rain_player.finished.is_connected(_replay_rain):
		rain_player.finished.connect(_replay_rain)
	# Стартуем музыку на следующий кадр, а не в тот же, когда узел только вошёл
	# в дерево — иначе AudioStreamPlayer иногда сразу "финиширует"
	await get_tree().process_frame
	if calm_music:
		calm_player.play()
	if combat_music:
		combat_player.play()


func _replay_rain() -> void:
	# Бесшовно-ish перезапуск дождя, когда поток доиграл до конца
	rain_player.play()


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = check_interval
		_update_combat_state()


func _update_combat_state() -> void:
	var engaged := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead and e.see_player:
			engaged = true
			break

	if engaged == _in_combat:
		return
	_in_combat = engaged

	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	if _in_combat:
		_fade_tween.tween_property(calm_player, "volume_db", SILENT_DB, crossfade_time)
		_fade_tween.tween_property(combat_player, "volume_db", 0.0, crossfade_time)
		_fade_tween.tween_property(rain_player, "volume_db", rain_volume_combat, crossfade_time)
	else:
		_fade_tween.tween_property(calm_player, "volume_db", 0.0, crossfade_time)
		_fade_tween.tween_property(combat_player, "volume_db", SILENT_DB, crossfade_time)
		_fade_tween.tween_property(rain_player, "volume_db", rain_volume_calm, crossfade_time)


func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
