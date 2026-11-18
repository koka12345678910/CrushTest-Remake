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
# На кладбище night_energy и цвет ведёт время суток (Levels/weather.gd), а
# молнии бьют только в грозу (Weather.storm). Вспышка — прибавка поверх
# базовой яркости, поэтому свет суток и молния не спорят за energy
var _flash_boost := 0.0

# Сила вспышки. Раньше свет бил до 3.0, а белый слой на экране — до половины
# непрозрачности: в тёмной сцене это слепило. Теперь вспышка мягче — мир
# коротко высвечивается холодным светом, но не заливает экран белым
@export var flash_energy := 1.4
@export_range(0.0, 1.0) var flash_overlay_alpha := 0.2
## Холодный оттенок экранной вспышки — чистый белый режет глаз сильнее
@export var flash_overlay_color := Color(0.75, 0.82, 1.0)
## Цвет самого света во вспышке. Обычный цвет неба ведёт время суток
## (на закате он оранжевый) — молния же всегда холодная
@export var flash_light_color := Color(0.8, 0.87, 1.0)
## Сила зарницы (далёкая вспышка в тучах) относительно грозовой
@export_range(0.0, 1.0) var cloud_flash_strength := 0.6
var _sky_color := Color.WHITE
var _flash_k := 1.0

# Гром. Свет доходит мгновенно, звук — примерно 343 м/с, поэтому далёкая
# молния грохочет заметно позже вспышки и тише. Именно эта задержка и делает
# грозу "настоящей" — мгновенный гром читается как фальшь
@export var thunder_delay_min := 0.35   # молния почти над головой
@export var thunder_delay_max := 4.5    # далёкая, на горизонте
@export var thunder_volume_near := -2.0
@export var thunder_volume_far := -20.0
@export var thunder_pitch_variation := 0.12

# Удары молнии РЯДОМ с героем (видимый разряд, свет, трещина, оглушение
# врагов). Остальные вспышки — далёкие: свет мира мигает, иногда у края вида
# виден бледный разряд
@export_range(0.0, 1.0) var strike_chance := 0.3
@export var strike_distance_min := 80.0
@export var strike_distance_max := 190.0
## Радиус, в котором удар отбрасывает и оглушает врагов (без урона)
@export var strike_stun_radius := 60.0
@export_range(0.0, 1.0) var far_bolt_chance := 0.45
## Зарницы: в пасмурную погоду без грозы небо изредка вспыхивает — только
## свет и далёкий глухой гром, без ударов и разрядов. Доля частоты грозы
## при сплошных тучах (0 — нет зарниц, как на кладбище)
@export_range(0.0, 1.0) var cloud_flash_rate := 0.0

const LightningBolt := preload("res://VFX/VFX_scene/lightning_bolt.gd")
const MageFx := preload("res://Player_scene/mage_fx.gd")

var lightning_timer := 0.0
var next_lightning_time := 0.0

func _ready() -> void:
	next_lightning_time = randf_range(lightning_interval_min, lightning_interval_max)

func _process(delta: float) -> void:
	energy = night_energy + _flash_boost
	# Цвет неба запоминаем, пока вспышки нет (его каждый кадр ставит погода);
	# во вспышке свет уходит в холодный
	if _flash_boost <= 0.0:
		_sky_color = color
	color = _sky_color.lerp(flash_light_color, clampf(_flash_boost / maxf(flash_energy, 0.01), 0.0, 1.0))
	# Без грозы неба не рвёт; пока гроза нарастает — молнии редкие, в разгар
	# грозы — с обычной частотой
	var storm: float = Weather.storm if Weather.is_active() else 1.0
	var rate := storm
	var far_only := false
	if storm < 0.3:
		# Зарницы в сплошных тучах (cloud_flash_rate), иначе неба не рвёт
		var cloud: float = Weather.cloud if Weather.is_active() else 0.0
		rate = cloud_flash_rate * smoothstep(0.5, 0.8, cloud)
		far_only = true
	if rate <= 0.0:
		lightning_timer = 0.0
		return
	lightning_timer += delta * rate
	if lightning_timer >= next_lightning_time:
		lightning_timer = 0.0
		next_lightning_time = randf_range(lightning_interval_min, lightning_interval_max)
		_trigger_lightning(far_only)

## far_only — зарница: только свет неба и далёкий гром
func _trigger_lightning(far_only := false) -> void:
	_flash_k = cloud_flash_strength if far_only else 1.0
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if not far_only and hero and randf() < strike_chance and _outdoors(hero.global_position):
		_strike(hero)
		return
	if not far_only and hero and randf() < far_bolt_chance and _outdoors(hero.global_position):
		_far_bolt(hero)
	# "дальность" удара: 0 = рядом, 1 = у горизонта. Одно и то же число задаёт
	# и паузу до грома, и его громкость, поэтому близкая молния бьёт резко и
	# громко, а далёкая долго доходит и глухо перекатывается. Зарница — всегда
	# далеко: гром поздний и глухой
	var distance := randf_range(0.65, 1.0) if far_only else randf()
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
	var k := randf_range(0.6, 1.0) * _flash_k
	tween.tween_property(self, "_flash_boost", maxf(flash_energy * k - night_energy, 0.0), 0.03)
	tween.tween_property(self, "_flash_boost", 0.0, 0.12)

	# Засветка экрана — через Juice: она есть у любого героя (раньше — только
	# у рыцаря, оверлей LightningFlash в его камере)
	Juice.flash(flash_overlay_alpha * k)

	await tween.finished


## Под крышей молния не видна — только гром и отсвет в окнах
func _outdoors(p: Vector2) -> bool:
	for house in get_tree().get_nodes_in_group("house_interior"):
		if house.is_roofed(p):
			return false
	return true


## Удар рядом с героем — самая зрелищная часть грозы
func _strike(hero: Node2D) -> void:
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	var at := hero.global_position + Vector2(dir.x, dir.y * 0.75) * randf_range(strike_distance_min, strike_distance_max)
	LightningBolt.strike(get_tree(), at, true)
	# Мир и экран — вспышкой; гром сразу, без паузы: молния над головой
	var t := create_tween()
	t.tween_property(self, "_flash_boost", maxf(flash_energy * 1.4 - night_energy, 0.0), 0.03)
	t.tween_property(self, "_flash_boost", 0.0, 0.4)
	Juice.flash(0.42)
	Juice.pulse("aberration", 0.45, 0.0)
	Juice.shake(6.0)
	Juice.kick(hero.global_position - at, 5.0)
	Juice.shockwave(at, 90.0, 0.45, 0.022)
	Juice.ground_crack(at, 1.5, Color(0.55, 0.75, 1.0, 0.9))
	var h := MageFx.holder(get_tree(), at + Vector2(0, -4), 1.0, 12)
	MageFx.sparks(h, 22, 240.0, 0.5, Vector2.UP, 80.0)
	MageFx.smoke(h, 6, 8.0, 26.0, 1.0)
	if thunder_audio:
		thunder_audio.volume_db = thunder_volume_near + 2.0
		thunder_audio.pitch_scale = randf_range(0.9, 1.0)
		thunder_audio.play()
	# Враги у точки удара отлетают и на миг оглушены, ящики разлетаются
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead and e.global_position.distance_to(at) < strike_stun_radius \
				and e.has_method("lightning_stun"):
			e.lightning_stun(at)
	for p in get_tree().get_nodes_in_group("breakable"):
		if is_instance_valid(p) and not p.is_dead and p.global_position.distance_to(at) < strike_stun_radius * 0.7:
			p.take_damage(99, null)
	# Порыв: дождь на несколько секунд усиливается
	for r in get_tree().get_nodes_in_group("rain_fx"):
		if r.has_method("boost"):
			r.boost(0.45, 4.0)
	# Второй всполох неба — эхо удара
	await get_tree().create_timer(0.12).timeout
	await _flash()


## Далёкая молния: бледный разряд за краем вида, без последствий
func _far_bolt(hero: Node2D) -> void:
	var cam := hero.get_node_or_null("Camera2D") as Camera2D
	var half := Vector2(320, 180)
	if cam:
		half = get_viewport().get_visible_rect().size / cam.zoom * 0.5
	var side := Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, -0.2))
	var at := hero.global_position + Vector2(side.x * half.x * 1.1, side.y * half.y * 1.6)
	LightningBolt.strike(get_tree(), at, false)
