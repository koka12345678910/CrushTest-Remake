extends DirectionalLight2D

# Вспышка молнии живёт внутри персонажа (Camera2D/CanvasLayer/LightningFlash).
# Раньше сюда был вписан путь целиком — "Level01/Player2/..." — и он ломался,
# как только игрок перестал стоять в сцене готовой нодой Player2 и начал
# спавниться из сейва (см. Levels/player_spawner.gd). Ищем лениво через группу
# "player": персонажа на момент _ready может ещё не быть, а у лучника и мага
# этого оверлея нет вовсе — тогда молния просто сверкнёт без засветки экрана
var lightning_flash: ColorRect = null

@onready var thunder_audio: AudioStreamPlayer = get_node_or_null("ThunderAudio")

@export var lightning_interval_min := 5.0
@export var lightning_interval_max := 15.0
@export var night_energy := 1.0 # обычное ночное освещение — поставь своё значение

# Сила вспышки. Раньше свет бил до 3.0, а белый слой на экране — до половины
# непрозрачности: в тёмной сцене это слепило. Теперь вспышка мягче — мир
# коротко высвечивается холодным светом, но не заливает экран белым
@export var flash_energy := 1.4
@export_range(0.0, 1.0) var flash_overlay_alpha := 0.2
## Холодный оттенок экранной вспышки — чистый белый режет глаз сильнее
@export var flash_overlay_color := Color(0.75, 0.82, 1.0)

# Гром. Свет доходит мгновенно, звук — примерно 343 м/с, поэтому далёкая
# молния грохочет заметно позже вспышки и тише. Именно эта задержка и делает
# грозу "настоящей" — мгновенный гром читается как фальшь
@export var thunder_delay_min := 0.35   # молния почти над головой
@export var thunder_delay_max := 4.5    # далёкая, на горизонте
@export var thunder_volume_near := -2.0
@export var thunder_volume_far := -20.0
@export var thunder_pitch_variation := 0.12

var lightning_timer := 0.0
var next_lightning_time := 0.0

func _ready() -> void:
	next_lightning_time = randf_range(lightning_interval_min, lightning_interval_max)

func _process(delta: float) -> void:
	lightning_timer += delta
	if lightning_timer >= next_lightning_time:
		lightning_timer = 0.0
		next_lightning_time = randf_range(lightning_interval_min, lightning_interval_max)
		_trigger_lightning()

func _trigger_lightning() -> void:
	# "дальность" удара: 0 = рядом, 1 = у горизонта. Одно и то же число задаёт
	# и паузу до грома, и его громкость, поэтому близкая молния бьёт резко и
	# громко, а далёкая долго доходит и глухо перекатывается
	var distance := randf()
	_play_thunder(distance)

	var flash_count = randi_range(2, 4)
	for i in flash_count:
		await _flash()
		await get_tree().create_timer(randf_range(0.05, 0.15)).timeout


func _play_thunder(distance: float) -> void:
	if thunder_audio == null:
		return
	await get_tree().create_timer(lerpf(thunder_delay_min, thunder_delay_max, distance)).timeout
	if not is_instance_valid(thunder_audio):
		return
	thunder_audio.volume_db = lerpf(thunder_volume_near, thunder_volume_far, distance)
	thunder_audio.pitch_scale = randf_range(
		1.0 - thunder_pitch_variation, 1.0 + thunder_pitch_variation
	)
	thunder_audio.play()

func _resolve_lightning_flash() -> ColorRect:
	if is_instance_valid(lightning_flash):
		return lightning_flash
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	lightning_flash = player.get_node_or_null("Camera2D/CanvasLayer/LightningFlash") as ColorRect
	return lightning_flash


func _flash() -> void:
	var tween = create_tween()
	# Каждый всполох в серии чуть разный по силе — так молния живее
	var k := randf_range(0.6, 1.0)
	tween.tween_property(self, "energy", flash_energy * k, 0.03)
	tween.tween_property(self, "energy", night_energy, 0.12)

	var flash := _resolve_lightning_flash()
	if flash:
		flash.color = Color(flash_overlay_color, flash.color.a)
		var flash_tween = create_tween()
		flash_tween.tween_property(flash, "color:a", flash_overlay_alpha * k, 0.03)
		flash_tween.tween_property(flash, "color:a", 0.0, 0.12)

	await tween.finished
