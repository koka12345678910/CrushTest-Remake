extends Node
## GraphicsQuality.gd — качество графики (автозагрузка).
##
## Четыре уровня: 0 НИЗКОЕ, 1 СРЕДНЕЕ, 2 ВЫСОКОЕ, 3 МАКСИМУМ (как задумано).
## Режим «АВТО» (по умолчанию) подбирает уровень сам:
##   1. при первом запуске на устройстве — по видеокарте и памяти;
##   2. в игре — по реальной частоте кадров: если на уровне карты долго
##      не держится плавность, качество снижается на ступень (и сразу
##      применяется); если запас большой — изредка поднимается обратно, но не
##      выше ступени, с которой уже приходилось снижать.
## Всё хранится в user://settings.cfg ОТДЕЛЬНО ДЛЯ КАЖДОГО УСТРОЙСТВА
## (раздел graphics_<id>, id — видеокарта + процессор): на ноутбуке и на
## мощном ПК у одной и той же копии игры свои настройки.
##
## Эффекты спрашивают нужное через has_fx() / value() и слушают
## quality_changed — часть меняется на лету, часть (то, что строится при
## входе на карту) — при следующем входе на уровень.

signal quality_changed(level: int)

const CONFIG_PATH := "user://settings.cfg"
const NAMES := ["НИЗКОЕ", "СРЕДНЕЕ", "ВЫСОКОЕ", "МАКСИМУМ"]
const LOW := 0
const MEDIUM := 1
const HIGH := 2
const ULTRA := 3

## Что включено на каком уровне (минимальный уровень эффекта). Ключи —
## имена эффектов, которые спрашивают сцены (has_fx)
const FX_MIN := {
	# Immersion (reference_map_level/scripts/immersion.gd)
	"fire": LOW,            # живой огонь: пламя есть всегда, детали — value()
	"fire_haze": HIGH,      # марево над огнём (копия экрана)
	"grade": MEDIUM,        # общий цветокор карты: приглушённые цвета, виньетка (~3 мс)
	"hero_light": LOW,      # светотень героя от огня (дёшево, рисованные тени)
	"shadows": LOW,         # узел теней строится всегда; сколько огней — shadow_lights
	"normals": HIGH,        # рельеф HD-арта под светом
	"silhouette": LOW,      # силуэт героя за домами (геймплей — всегда)
	"moon": LOW,
	"moon_rays": MEDIUM,
	"foreground": HIGH,     # свесы крыш и кроны на переднем плане (+140 вызовов отрисовки)
	"canopy": MEDIUM,       # тень и пятна света под кронами
	"clouds": LOW,          # тени облаков + ночной цветокор (без них ночь не та)
	"wind": LOW,
	"mist": MEDIUM,
	"smoke": LOW,
	"depth": MEDIUM,
	"critters": MEDIUM,
	"response": LOW,
	"weather": LOW,
}
## Числовые параметры по уровням [НИЗКОЕ, СРЕДНЕЕ, ВЫСОКОЕ, МАКСИМУМ]
const VALUES := {
	# Сколько ближайших огней отбрасывают тень от стен на землю
	"shadow_lights": [0, 2, 3, 5],
	# Доля частиц огня (искры, угли, пепел, дым)
	"particles": [0.35, 0.6, 0.85, 1.0],
	# Сколько ближайших горящих домов дают тень на героя (у всех 45 сразу
	# было ~18 мс кадра на слабом ноутбуке)
	"house_fire_shadows": [0, 1, 2, 3],
}

## Режим: true — авто, false — выбранный руками уровень
var auto := true
## Уровень, выбранный руками
var manual_level := ULTRA
## Уровень, подобранный автоматически для этого устройства
var auto_level := -1
## Выше этой ступени авто не поднимается (с неё уже приходилось снижать)
var auto_ceiling := ULTRA
var device_id := ""
var device_name := ""

# ── автоподбор по частоте кадров ──
## Окно замера, с
const WINDOW_S := 4.0
## После смены сцены / уровня замеры не считаются (загрузка, прогрев шейдеров)
const SETTLE_S := 6.0
var _settle := SETTLE_S
var _acc_t := 0.0
var _acc_frames := 0
var _acc_gpu := 0.0
var _slow_windows := 0
var _fast_windows := 0
var _scene: Node = null
var last_fps := 0.0
var last_gpu_ms := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	device_name = "%s / %s" % [RenderingServer.get_video_adapter_name(), OS.get_processor_name()]
	device_id = device_name.md5_text().substr(0, 12)
	_load()
	if auto_level < 0:
		auto_level = guess_level()
		_save()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


## Текущий уровень 0..3
func level() -> int:
	return auto_level if auto else manual_level


func has_fx(fx: String) -> bool:
	return level() >= int(FX_MIN.get(fx, LOW))


func value(key: String) -> float:
	var arr: Array = VALUES[key]
	return float(arr[clampi(level(), 0, arr.size() - 1)])


## Выбор в настройках: -1 — авто, 0..3 — уровень
func set_mode(mode: int) -> void:
	var before := level()
	if mode < 0:
		if not auto:
			# Снова авто: подбор начинается с догадки по железу заново
			auto_ceiling = ULTRA
			auto_level = guess_level()
		auto = true
	else:
		auto = false
		manual_level = clampi(mode, LOW, ULTRA)
	_save()
	_reset_window()
	if level() != before:
		quality_changed.emit(level())


func mode() -> int:
	return -1 if auto else manual_level


## Первая догадка по железу. Встроенная видеокарта Intel UHD/HD — НИЗКОЕ,
## Iris Xe и встроенные AMD — СРЕДНЕЕ, дискретная — МАКСИМУМ; мало памяти
## (видеопамять у встроенной общая с системой) — не выше СРЕДНЕГО
func guess_level() -> int:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	var t := RenderingServer.get_video_adapter_type()
	var lv := HIGH
	if t == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		lv = ULTRA
	elif t == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		lv = MEDIUM
	if name.contains("uhd") or name.contains("hd graphics") or name.contains("intel(r) graphics"):
		lv = LOW
	elif name.contains("iris") or name.contains("radeon(tm) graphics") or name.contains("vega"):
		lv = mini(lv, MEDIUM)
	if t == RenderingDevice.DEVICE_TYPE_CPU or t == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
		lv = LOW
	var mem: Dictionary = OS.get_memory_info()
	var phys := float(mem.get("physical", 0))
	if phys > 0.0 and phys < 9.0e9:
		lv = mini(lv, MEDIUM)
	return lv


# ── хранение (свой раздел на каждое устройство) ──

func _section() -> String:
	return "graphics_" + device_id


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var s := _section()
	auto = cfg.get_value(s, "auto", auto)
	manual_level = clampi(cfg.get_value(s, "manual_level", manual_level), LOW, ULTRA)
	auto_level = cfg.get_value(s, "auto_level", auto_level)
	auto_ceiling = clampi(cfg.get_value(s, "auto_ceiling", auto_ceiling), LOW, ULTRA)


## Пишет только свой раздел: остальное (звук, другие устройства) не трогает
func _save() -> void:
	# Консольные запуски (инструменты, проверки) — не устройство игрока
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	var s := _section()
	cfg.set_value(s, "device", device_name)
	cfg.set_value(s, "auto", auto)
	cfg.set_value(s, "manual_level", manual_level)
	cfg.set_value(s, "auto_level", auto_level)
	cfg.set_value(s, "auto_ceiling", auto_ceiling)
	cfg.save(CONFIG_PATH)


# ── автоподбор ──

func _reset_window() -> void:
	_acc_t = 0.0
	_acc_frames = 0
	_acc_gpu = 0.0


func _process(delta: float) -> void:
	if not auto:
		return
	var tree := get_tree()
	var sc := tree.current_scene
	if sc != _scene:
		_scene = sc
		_settle = SETTLE_S
		_slow_windows = 0
		_fast_windows = 0
		_reset_window()
	# Меряем только на уровнях (там, где есть герой), не на паузе и не в
	# свёрнутом / неактивном окне (там Windows сам режет кадры)
	if sc == null or tree.paused or not _is_level(sc) or not get_window().has_focus():
		_reset_window()
		return
	if _settle > 0.0:
		_settle -= delta
		return
	# Рывок загрузки (> 0.25 с) не считается
	if delta > 0.25:
		return
	_acc_t += delta
	_acc_frames += 1
	_acc_gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	if _acc_t < WINDOW_S:
		return
	last_fps = _acc_frames / _acc_t
	last_gpu_ms = _acc_gpu / maxf(_acc_frames, 1)
	_reset_window()
	_judge()


func _is_level(sc: Node) -> bool:
	return sc.get_node_or_null("Objects/PlayerSpawn") != null or sc.find_child("PlayerSpawn", false, false) != null \
		or not get_tree().get_nodes_in_group("player").is_empty()


## Цель — частота монитора, но не выше 60 (vsync держит 60, больше не нужно)
func _target_fps() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz <= 0.0:
		hz = 60.0
	return minf(hz, 60.0)


func _judge() -> void:
	var target := _target_fps()
	var budget_ms := 1000.0 / target
	var lv := auto_level
	if last_fps < target * 0.5:
		# Совсем плохо (< 30) — сразу ступень вниз
		_slow_windows = 2
	elif last_fps < target * 0.82:
		_slow_windows += 1
	else:
		_slow_windows = 0
	# Большой запас видеокарты и кадры ровные — можно попробовать выше
	if last_fps >= target * 0.95 and last_gpu_ms > 0.0 and last_gpu_ms < budget_ms * 0.4:
		_fast_windows += 1
	else:
		_fast_windows = 0
	if _slow_windows >= 2 and lv > LOW:
		auto_level = lv - 1
		auto_ceiling = auto_level
		_slow_windows = 0
		_settle = 3.0
		print("[GraphicsQuality] %.0f FPS — качество снижено: %s" % [last_fps, NAMES[auto_level]])
	elif _fast_windows >= 8 and lv < auto_ceiling:
		auto_level = lv + 1
		_fast_windows = 0
		_settle = 3.0
		print("[GraphicsQuality] запас (%.1f мс GPU) — качество повышено: %s" % [last_gpu_ms, NAMES[auto_level]])
	if auto_level != lv:
		_save()
		quality_changed.emit(auto_level)
