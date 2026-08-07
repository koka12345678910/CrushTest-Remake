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
# Пока открыт магазин — дождь приглушается почти полностью (как звук за дверью
# в Sekiro), но не обрывается мгновенно, а плавно уходит за то же время,
# что идёт анимация открытия/закрытия окна магазина
@export var rain_volume_shop := -60.0

# Вороны — редкий атмосферный звук, не должен звучать постоянно, поэтому
# играем его через случайные паузы (тот же приём, что и для грома в
# directional_light_2d.gd)
@export var crows_interval_min := 12.0
@export var crows_interval_max := 30.0
@export var crows_pitch_variation := 0.08
# "Расстояние" до каркающей вороны — рандомим каждый крик в сторону дальнего
# плана (0 = близко, 1 = у горизонта), чтобы звук читался как "где-то вдалеке",
# а не как ворона сидит у игрока на плече
@export var crows_distance_min := 0.5
@export var crows_distance_max := 1.0
@export var crows_volume_near := -11.0
@export var crows_volume_far := -22.0
# Дальний звук теряет верха — имитируем это фильтром: чем дальше, тем ниже срез
@export var crows_filter_freq_near := 9000.0
@export var crows_filter_freq_far := 1000.0
# Небольшой эхо-хвост (не пещерный гул, а лёгкая естественная реверберация
# открытого пространства) — своя аудио-шина, чтобы не трогать эффектами
# остальные звуки уровня
const CROWS_BUS := "CrowsEcho"

# --- Даккинг музыки под сильные удары ---
# Приём из файтингов: на мощном попадании музыка на доли секунды проседает,
# освобождая место удару, и тут же возвращается. Ухо не успевает распознать
# это как "музыку сделали тише" — оно считывает удар как более весомый.
# Давим ШИНУ, а не volume_db плееров: их громкость уже занята кроссфейдом
# спокойного/боевого трека, и второй твин на то же свойство дрался бы с ним
const MUSIC_BUS := "Music"
@export var duck_depth_db := -7.0   # насколько проседает на максимально сильном ударе
@export var duck_attack := 0.05     # уход вниз почти мгновенный
@export var duck_release := 0.4     # возврат плавный, чтобы не "выпрыгивало"
var _duck_tween: Tween

@onready var calm_player: AudioStreamPlayer = $CalmPlayer
@onready var combat_player: AudioStreamPlayer = $CombatPlayer
@onready var rain_player: AudioStreamPlayer = $RainPlayer
@onready var crows_player: AudioStreamPlayer = $CrowsPlayer

var _in_combat := false
var _in_shop := false
var _check_timer := 0.0
var _fade_tween: Tween
var _rain_tween: Tween
var _crows_timer := 0.0
var _next_crows_time := 0.0

const SILENT_DB := -80.0

func _ready() -> void:
	add_to_group("level_music")
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

	_setup_crows_bus()
	_next_crows_time = randf_range(crows_interval_min, crows_interval_max)
	# Шины живут дольше сцены: если прошлый забег оборвался посреди просадки,
	# музыка так и осталась бы приглушённой после рестарта уровня
	_set_music_bus_db(0.0)

	# Стартуем музыку на следующий кадр, а не в тот же, когда узел только вошёл
	# в дерево — иначе AudioStreamPlayer иногда сразу "финиширует"
	await get_tree().process_frame
	if calm_music:
		calm_player.play()
	if combat_music:
		combat_player.play()


# Отдельная шина с лёгкой реверберацией — создаём один раз (шины AudioServer
# переживают перезагрузку сцены, но не перезапуск игры), чтобы вороны звучали
# с естественным эхо открытого пространства, а не сухо поверх остальной атмосферы
func _setup_crows_bus() -> void:
	if AudioServer.get_bus_index(CROWS_BUS) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, CROWS_BUS)
		AudioServer.set_bus_send(idx, "Master")
		# Эффект 0: реверберация открытого пространства — чуть больше комнаты
		# и хвоста, чем раньше, чтобы крик "уходил вдаль", но wet всё ещё в
		# пределах умеренного, не гулкого эффекта
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.75
		reverb.damping = 0.7
		reverb.spread = 1.0
		reverb.wet = 0.3
		reverb.dry = 1.0
		AudioServer.add_bus_effect(idx, reverb)
		# Эффект 1: срез верхних частот — на дальних криках cutoff двигается
		# ниже в _play_crows(), имитируя, как расстояние глушит высокие частоты
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = crows_filter_freq_near
		AudioServer.add_bus_effect(idx, lowpass)
	crows_player.bus = CROWS_BUS


func _replay_rain() -> void:
	# Бесшовно-ish перезапуск дождя, когда поток доиграл до конца
	rain_player.play()


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = check_interval
		_update_combat_state()

	_crows_timer += delta
	if _crows_timer >= _next_crows_time:
		_crows_timer = 0.0
		_next_crows_time = randf_range(crows_interval_min, crows_interval_max)
		_play_crows()


# Вызывается игроком при сильном попадании. power — тот же множитель веса
# удара, что управляет тряской камеры, хитстопом и громкостью звука, поэтому
# просадка музыки соразмерна остальной отдаче: вихрь давит заметно, удар на
# бегу — чуть-чуть
func duck_music(power := 1.0, max_power := 2.2) -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx == -1:
		return
	var t: float = clamp((power - 1.0) / max(max_power - 1.0, 0.001), 0.0, 1.0)
	var depth: float = lerpf(0.0, duck_depth_db, t)

	# Новый удар перебивает предыдущую просадку, а не складывается с ней —
	# иначе в быстром комбо музыка уезжала бы в тишину и не успевала вернуться
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_music_bus_db, AudioServer.get_bus_volume_db(idx), depth, duck_attack)
	_duck_tween.tween_method(_set_music_bus_db, depth, 0.0, duck_release)


func _set_music_bus_db(value: float) -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, value)


func _play_crows() -> void:
	var distance := randf_range(crows_distance_min, crows_distance_max)
	crows_player.volume_db = lerpf(crows_volume_near, crows_volume_far, distance)
	crows_player.pitch_scale = randf_range(1.0 - crows_pitch_variation, 1.0 + crows_pitch_variation)

	var bus_idx := AudioServer.get_bus_index(CROWS_BUS)
	if bus_idx != -1:
		var lowpass := AudioServer.get_bus_effect(bus_idx, 1) as AudioEffectLowPassFilter
		if lowpass:
			lowpass.cutoff_hz = lerpf(crows_filter_freq_near, crows_filter_freq_far, distance)

	crows_player.play()


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
	else:
		_fade_tween.tween_property(calm_player, "volume_db", 0.0, crossfade_time)
		_fade_tween.tween_property(combat_player, "volume_db", SILENT_DB, crossfade_time)
	_apply_rain_volume(crossfade_time)


# Вызывается магазином (и любым другим UI) при открытии/закрытии — duration
# передаётся снаружи, чтобы приглушение шло РОВНО столько же, сколько длится
# анимация открытия/закрытия этого конкретного окна, а не по своей отдельной
# константе, которая могла бы разъехаться с реальной анимацией
func set_shop_open(is_open: bool, duration: float) -> void:
	_in_shop = is_open
	_apply_rain_volume(duration)


# Единая точка, откуда управляется громкость дождя — и по боевому состоянию,
# и по магазину. Раньше это делал ещё один tween внутри _update_combat_state,
# и он бы конфликтовал с этим, борясь за одно и то же свойство rain_player
func _apply_rain_volume(duration: float) -> void:
	var target := rain_volume_shop if _in_shop else (rain_volume_combat if _in_combat else rain_volume_calm)
	if _rain_tween:
		_rain_tween.kill()
	_rain_tween = create_tween()
	_rain_tween.tween_property(rain_player, "volume_db", target, duration)


func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
