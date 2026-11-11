extends Node
## weather.gd — автозагрузка "Weather": время суток и погода уровня.
##
## Сутки идут по кругу: рассвет → утро → день → закат → сумерки → ночь →
## рассвет. Вид каждого часа задан опорными точками (KEYS) — цвет мира
## (CanvasModulate "NightModulate"), свет сквозь облака (узел Moonlight: ночью
## это луна, днём солнце), рассеянный свет неба (DirectionalLight2D), косые
## лучи (группа moon_rays) и цветокор (AtmosphereGrade). Между точками всё
## перетекает плавно (smoothstep), без скачков.
##
## Погода: ясно, пасмурно, туман, дождь, гроза — БЕЗ снега. Каждая держится
## несколько минут, потом медленно перетекает в соседнюю (из ясного неба сразу
## в ливень не бывает: ясно → пасмурно → дождь → гроза и обратно). Погода —
## это несколько чисел 0..1 (облачность, дождь, сила дождя, туман, гроза,
## ветер), и уже по ним работают существующие системы:
##   - Levels/rain_system.gd       — дождь (amount — доля, intensity — сила);
##   - Levels/level_music_manager.gd — звук дождя (rain_db());
##   - Levels/directional_light_2d.gd — молнии и гром только в грозу (storm);
##   - Levels/rain_splash_spawner.gd — старые всплески-спрайты;
##   - Levels/props/fire_flicker.gd — костры ярче ночью, слабее днём (fire_scale);
##   - Levels/loot/loot_item.gd, VFX/VFX_scene/gold_wisp.gd — компенсация
##     цвета мира (ambient_comp()), теперь живая: цвет мира меняется весь день.
## Туман — свой слой (Shaders/weather_fog.gdshader), создаётся здесь.
##
## Работает только на уровнях, где у корня есть CanvasModulate "NightModulate"
## (кладбище; в меню ничего не делает). На паузе (инвентарь, панель находки)
## время и погода стоят — у автозагрузки обычный режим обработки.

enum Kind { CLEAR, CLOUDY, FOG, RAIN, STORM }

# ── Время суток ──────────────────────────────────────────────────────
## Сколько РЕАЛЬНЫХ минут идут одни игровые сутки целиком. 18 минут — час
## игры за 45 секунд: свет заметно меняется, но без суеты
@export var day_length_minutes := 18.0
## С какого часа (0..24) начинается игра: 20 — закат, следом наступит ночь
@export_range(0.0, 24.0) var start_hour := 20.0
## Остановить время (для отладки и скриншотов): свет застынет на текущем часе
@export var time_frozen := false

# ── Погода ───────────────────────────────────────────────────────────
## С какой погоды начинается игра
@export var start_weather: Kind = Kind.RAIN
## Сколько реальных минут держится одна погода (случайно между min и max)
@export var weather_hold_min_minutes := 3.0
@export var weather_hold_max_minutes := 6.0
## За сколько реальных секунд одна погода перетекает в другую: дождь
## нарастает, облака сгущаются, туман наползает — всё за это время
@export var weather_transition_seconds := 60.0
## Насколько слабее костры и факелы днём (1 — как ночью, 0 — гаснут совсем)
@export_range(0.0, 1.0) var fire_day_scale := 0.35

## Отладка: ускорить и сутки, и погоду (1 — обычная скорость)
@export var debug_speed := 1.0

## Опорные точки суток. h — час; ambient — цвет мира (CanvasModulate);
## sun/sun_e — свет сквозь облака (ночью луна) и его сила; sky/sky_e —
## рассеянный свет неба; rays/rays_k — цвет и доля косых лучей; night —
## насколько сейчас ночь (костры, ореол героя); остальное — цветокор.
## Ночь (21.5..4.5) — прежние значения уровня, когда он был только ночным
const KEYS := [
	{h = 0.0, ambient = Color(0.325, 0.365, 0.39), sun = Color(0.6, 0.72, 0.95), sun_e = 0.3,
		sky = Color(0.55, 0.65, 0.8), sky_e = 0.08, rays = Color(0.66, 0.78, 0.95), rays_k = 1.0, night = 1.0,
		desat = 0.3, contrast = 1.1, tint = Color(0.82, 0.9, 0.95), vignette = 0.55},
	{h = 4.5, ambient = Color(0.325, 0.365, 0.39), sun = Color(0.6, 0.72, 0.95), sun_e = 0.3,
		sky = Color(0.55, 0.65, 0.8), sky_e = 0.08, rays = Color(0.66, 0.78, 0.95), rays_k = 1.0, night = 1.0,
		desat = 0.3, contrast = 1.1, tint = Color(0.82, 0.9, 0.95), vignette = 0.55},
	# Рассвет: мир ещё тёмный, небо розово-сиреневое, солнце низкое и тёплое
	{h = 6.0, ambient = Color(0.5, 0.46, 0.52), sun = Color(1.0, 0.7, 0.52), sun_e = 0.24,
		sky = Color(0.9, 0.7, 0.65), sky_e = 0.08, rays = Color(1.0, 0.74, 0.56), rays_k = 0.9, night = 0.55,
		desat = 0.22, contrast = 1.08, tint = Color(0.9, 0.88, 0.95), vignette = 0.45},
	# Утро: светло, свет чуть тёплый
	{h = 8.0, ambient = Color(0.72, 0.7, 0.68), sun = Color(1.0, 0.88, 0.72), sun_e = 0.24,
		sky = Color(1.0, 0.92, 0.82), sky_e = 0.1, rays = Color(1.0, 0.9, 0.75), rays_k = 0.55, night = 0.1,
		desat = 0.16, contrast = 1.06, tint = Color(0.95, 0.95, 0.98), vignette = 0.34},
	# День: самый светлый и нейтральный
	{h = 12.0, ambient = Color(0.84, 0.83, 0.79), sun = Color(1.0, 0.96, 0.86), sun_e = 0.22,
		sky = Color(1.0, 0.97, 0.9), sky_e = 0.12, rays = Color(1.0, 0.97, 0.88), rays_k = 0.3, night = 0.0,
		desat = 0.12, contrast = 1.04, tint = Color(0.97, 0.97, 1.0), vignette = 0.28},
	{h = 16.0, ambient = Color(0.82, 0.79, 0.72), sun = Color(1.0, 0.92, 0.78), sun_e = 0.22,
		sky = Color(1.0, 0.94, 0.85), sky_e = 0.12, rays = Color(1.0, 0.92, 0.8), rays_k = 0.4, night = 0.0,
		desat = 0.13, contrast = 1.05, tint = Color(0.96, 0.95, 0.97), vignette = 0.3},
	# Закат: мир тёплый, оранжевый, длинные золотые лучи
	{h = 18.5, ambient = Color(0.66, 0.53, 0.45), sun = Color(1.0, 0.62, 0.36), sun_e = 0.26,
		sky = Color(1.0, 0.68, 0.48), sky_e = 0.1, rays = Color(1.0, 0.66, 0.42), rays_k = 0.9, night = 0.3,
		desat = 0.18, contrast = 1.08, tint = Color(0.92, 0.86, 0.9), vignette = 0.42},
	# Сумерки: солнце ушло, мир синеет и гаснет
	{h = 20.0, ambient = Color(0.42, 0.4, 0.5), sun = Color(0.7, 0.66, 0.9), sun_e = 0.25,
		sky = Color(0.6, 0.62, 0.85), sky_e = 0.08, rays = Color(0.75, 0.75, 0.95), rays_k = 0.8, night = 0.8,
		desat = 0.25, contrast = 1.1, tint = Color(0.85, 0.88, 0.97), vignette = 0.5},
	{h = 21.5, ambient = Color(0.325, 0.365, 0.39), sun = Color(0.6, 0.72, 0.95), sun_e = 0.3,
		sky = Color(0.55, 0.65, 0.8), sky_e = 0.08, rays = Color(0.66, 0.78, 0.95), rays_k = 1.0, night = 1.0,
		desat = 0.3, contrast = 1.1, tint = Color(0.82, 0.9, 0.95), vignette = 0.55},
	{h = 24.0, ambient = Color(0.325, 0.365, 0.39), sun = Color(0.6, 0.72, 0.95), sun_e = 0.3,
		sky = Color(0.55, 0.65, 0.8), sky_e = 0.08, rays = Color(0.66, 0.78, 0.95), rays_k = 1.0, night = 1.0,
		desat = 0.3, contrast = 1.1, tint = Color(0.82, 0.9, 0.95), vignette = 0.55},
]

## Погода как набор чисел. cloud — облачность, rain — есть ли дождь,
## heavy — его сила, fog — туман, storm — гроза (молнии), wind — ветер
const PRESETS := {
	Kind.CLEAR: {cloud = 0.0, rain = 0.0, heavy = 0.45, fog = 0.0, storm = 0.0, wind = 1.0},
	Kind.CLOUDY: {cloud = 0.7, rain = 0.0, heavy = 0.45, fog = 0.0, storm = 0.0, wind = 1.4},
	Kind.FOG: {cloud = 0.45, rain = 0.0, heavy = 0.45, fog = 1.0, storm = 0.0, wind = 0.4},
	Kind.RAIN: {cloud = 0.85, rain = 1.0, heavy = 0.55, fog = 0.15, storm = 0.0, wind = 1.5},
	Kind.STORM: {cloud = 1.0, rain = 1.0, heavy = 0.9, fog = 0.1, storm = 1.0, wind = 2.2},
}

## Куда может перейти погода (вес — насколько вероятно). Резких скачков нет:
## гроза только из дождя, дождь только из пасмурного неба
const NEXT := {
	Kind.CLEAR: {Kind.CLOUDY: 3.0, Kind.FOG: 1.0},
	Kind.CLOUDY: {Kind.CLEAR: 2.0, Kind.RAIN: 3.0, Kind.FOG: 1.0},
	Kind.FOG: {Kind.CLEAR: 2.0, Kind.CLOUDY: 2.0},
	Kind.RAIN: {Kind.CLOUDY: 3.0, Kind.STORM: 2.0},
	Kind.STORM: {Kind.RAIN: 1.0},
}
const PARAMS := ["cloud", "rain", "heavy", "fog", "storm", "wind"]

const FOG_SHADER := preload("res://Shaders/weather_fog.gdshader")
## Туман: ветер (px/с при wind = 1), размер клубов и период шума в клетках
## (тот же PERIOD в шейдере) — сдвиг заворачивается на период без рывка
const FOG_WIND := Vector2(9.0, 2.5)
const FOG_SCALE := 420.0
const FOG_PERIOD := 32.0

## Текущий час 0..24 и погода, к которой сейчас идёт небо
var hour := 0.0
var weather: Kind = Kind.RAIN
## Текущие (плавно меняющиеся) числа погоды — читают другие системы
var cloud := 0.0
var rain := 0.0
var heavy := 0.45
var fog := 0.0
var storm := 0.0
var wind := 1.0
## Насколько сейчас ночь (0 — день, 1 — ночь), с поправкой на тучи
var night := 1.0
## Множитель яркости костров и факелов (fire_flicker.gd)
var fire_scale := 1.0

var _active := false
var _scene: Node
var _ambient: CanvasModulate
var _sky_light: DirectionalLight2D
var _moon: Node
var _grade: Node
var _rain_sys: Node
var _fog: Sprite2D
var _fog_mat: ShaderMaterial
var _fog_drift_a := Vector2.ZERO
var _fog_drift_b := Vector2.ZERO
var _from := {}
var _to := {}
var _blend := 1.0
var _hold := 0.0
var _prev_weather: Kind = Kind.RAIN


func _ready() -> void:
	hour = start_hour
	weather = start_weather
	_prev_weather = start_weather
	var p: Dictionary = PRESETS[weather]
	for k in PARAMS:
		set(k, p[k])
	_to = p.duplicate()
	_hold = _hold_time()


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_bind(scene)
	if not _active:
		return
	var dt := delta * debug_speed
	if not time_frozen:
		hour = fposmod(hour + dt * 24.0 / (day_length_minutes * 60.0), 24.0)
	_update_weather(dt)
	# Клубы тумана плывут по ветру; второй слой мельче и медленнее
	var per_a := FOG_PERIOD * FOG_SCALE
	var per_b := per_a * 0.45
	var w := FOG_WIND * wind * delta
	_fog_drift_a = Vector2(fposmod(_fog_drift_a.x + w.x, per_a), fposmod(_fog_drift_a.y + w.y, per_a))
	_fog_drift_b = Vector2(fposmod(_fog_drift_b.x + w.x * 0.55, per_b), fposmod(_fog_drift_b.y + w.y * 0.55, per_b))
	_apply()


## Перейти к погоде kind: плавно (как обычно) или сразу (instant)
func set_weather(kind: Kind, instant := false) -> void:
	_from = {}
	for k in PARAMS:
		_from[k] = get(k)
	_to = PRESETS[kind]
	_prev_weather = weather
	weather = kind
	_blend = 0.0
	_hold = _hold_time()
	if instant:
		_blend = 1.0
		for k in PARAMS:
			set(k, _to[k])
	# Кооп: погоду решает хост — клиентам сразу (Net/net.gd)
	Net.weather_changed(int(kind))


var _net_synced := false

## Кооп, клиент: погода и час от хоста (Net._weather_sync). Первый раз — сразу,
## дальше погода перетекает как обычно, а час подтягивается, если ушёл
func net_sync(h: float, kind: int) -> void:
	if not _net_synced:
		_net_synced = true
		hour = h
		set_weather(kind as Kind, true)
		return
	if kind != int(weather):
		set_weather(kind as Kind)
	if absf(angle_difference(hour / 24.0 * TAU, h / 24.0 * TAU)) > 0.02:
		hour = h


## Идёт ли смена суток и погоды на текущей сцене
func is_active() -> bool:
	return _active


## Поставить час (0..24) — для отладки и будущего сна у костра
func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)


## "утро", "день", "вечер" или "ночь" — для подсказок и интерфейса
func phase_name() -> String:
	if hour >= 5.0 and hour < 9.0:
		return "утро"
	if hour >= 9.0 and hour < 17.0:
		return "день"
	if hour >= 17.0 and hour < 21.0:
		return "вечер"
	return "ночь"


## Погода словом — для часов в HUD (UI/skill_points_bar.gd). Пока идёт
## переход, до середины показывается прежняя погода, потом новая
func weather_name() -> String:
	var kind := weather if _blend >= 0.5 else _prev_weather
	return ["Ясно", "Пасмурно", "Туман", "Дождь", "Гроза"][kind]


## Обратный множитель цвета мира: светящееся (души, находки) не должно тонуть
## в ночном тоне или съезжать в цвет заката. Без уровня — белый
func ambient_comp() -> Color:
	var c := Color.WHITE
	if _active and is_instance_valid(_ambient):
		c = _ambient.color
	elif is_instance_valid(get_tree().current_scene):
		for ch in get_tree().current_scene.get_children():
			if ch is CanvasModulate and ch.visible:
				c = ch.color
				break
	return Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)


## Громкость дождя от погоды, дБ (прибавка к громкости из music manager)
func rain_db() -> float:
	if not _active:
		return 0.0
	return linear_to_db(maxf(rain * lerpf(0.55, 1.0, heavy), 0.0001))


func _bind(scene: Node) -> void:
	_scene = scene
	_active = false
	_net_synced = false
	_ambient = null
	_sky_light = null
	_moon = null
	_grade = null
	_rain_sys = null
	_fog = null
	if scene == null:
		return
	_ambient = scene.get_node_or_null("NightModulate") as CanvasModulate
	if _ambient == null:
		return
	_active = true
	for ch in scene.get_children():
		if ch is DirectionalLight2D and _sky_light == null:
			_sky_light = ch
	_moon = scene.get_node_or_null("Moonlight")
	_grade = scene.get_node_or_null("AtmosphereGrade")
	_rain_sys = scene.get_node_or_null("RainSystem")
	for ray in get_tree().get_nodes_in_group("moon_rays"):
		var mat := (ray as CanvasItem).material as ShaderMaterial
		if mat and not ray.has_meta("base_intensity"):
			ray.set_meta("base_intensity", mat.get_shader_parameter("intensity"))
	_make_fog(scene)


func _make_fog(scene: Node) -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_fog = Sprite2D.new()
	_fog.name = "WeatherFog"
	_fog.texture = ImageTexture.create_from_image(img)
	_fog.z_as_relative = false
	_fog.z_index = 83
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FOG_SHADER
	_fog.material = _fog_mat
	# Лампы на туман не светят: иначе на нём проступают прямоугольные тени
	# окклюдеров от неба (DirectionalLight2D). Цвет мира (CanvasModulate) он
	# всё равно получает — ночью тёмный, днём белёсый
	_fog.light_mask = 0
	# Под крышей туман гаснет вместе с дождём (house_interior.gd, группа rain_fx)
	_fog.add_to_group("rain_fx")
	_fog.visible = false
	scene.add_child(_fog)


func _hold_time() -> float:
	return randf_range(weather_hold_min_minutes, weather_hold_max_minutes) * 60.0


func _update_weather(dt: float) -> void:
	if _blend < 1.0:
		_blend = minf(_blend + dt / maxf(weather_transition_seconds, 1.0), 1.0)
		var k := smoothstep(0.0, 1.0, _blend)
		for p in PARAMS:
			set(p, lerpf(_from[p], _to[p], k))
	_hold -= dt
	# В коопе следующую погоду выбирает только хост (у клиентов — net_sync)
	if _hold <= 0.0 and _blend >= 1.0 and not Net.is_client():
		set_weather(_pick_next())


func _pick_next() -> Kind:
	var options: Dictionary = NEXT[weather].duplicate()
	# Туман чаще под утро и ночью
	if options.has(Kind.FOG) and (hour < 9.0 or hour > 20.0):
		options[Kind.FOG] *= 2.0
	var total := 0.0
	for w in options.values():
		total += w
	var r := randf() * total
	for kind in options:
		r -= options[kind]
		if r <= 0.0:
			return kind
	return options.keys()[0]


## Вид текущего часа: опорные точки KEYS, между ними — плавно
func _sample() -> Dictionary:
	var i := 0
	while i < KEYS.size() - 2 and hour >= KEYS[i + 1].h:
		i += 1
	var a: Dictionary = KEYS[i]
	var b: Dictionary = KEYS[i + 1]
	var t := smoothstep(0.0, 1.0, (hour - a.h) / (b.h - a.h))
	var out := {}
	for key in a:
		if a[key] is Color:
			out[key] = (a[key] as Color).lerp(b[key], t)
		else:
			out[key] = lerpf(a[key], b[key], t)
	return out


func _apply() -> void:
	var s := _sample()
	# Тучи днём заметно гасят мир, ночью — чуть-чуть (там и так темно)
	night = s.night
	var day := 1.0 - night
	var dim := 1.0 - cloud * lerpf(0.08, 0.24, day) - storm * 0.08
	var ambient: Color = s.ambient * dim
	# В тумане цвета серее
	var grey := ambient.get_luminance()
	ambient = ambient.lerp(Color(grey, grey, grey), fog * 0.3)
	ambient.a = 1.0
	_ambient.color = ambient

	var dark := night + day * cloud * 0.35
	fire_scale = lerpf(fire_day_scale, 1.0, clampf(dark, 0.0, 1.0))

	if is_instance_valid(_sky_light):
		_sky_light.color = s.sky
		# directional_light_2d.gd: базовая яркость, к ней прибавляются вспышки
		_sky_light.set("night_energy", s.sky_e * (1.0 - cloud * 0.3))

	if is_instance_valid(_moon):
		_moon.set("color", s.sun)
		# В тучах прогалин нет — свет сквозь облака почти пропадает
		_moon.set("energy", s.sun_e * (1.0 - cloud * 0.75))
		_moon.set("wind_scale", wind)

	for ray in get_tree().get_nodes_in_group("moon_rays"):
		var mat := (ray as CanvasItem).material as ShaderMaterial
		if mat and ray.has_meta("base_intensity"):
			mat.set_shader_parameter("intensity", float(ray.get_meta("base_intensity")) * s.rays_k * (1.0 - cloud * 0.85))
			mat.set_shader_parameter("ray_color", s.rays)

	if is_instance_valid(_grade):
		_grade.set("desaturation", s.desat + cloud * 0.1 + fog * 0.1)
		_grade.set("contrast", s.contrast - fog * 0.06 - cloud * 0.02)
		_grade.set("shadow_tint", s.tint)
		_grade.set("vignette_strength", s.vignette + storm * 0.08)

	if is_instance_valid(_rain_sys):
		_rain_sys.set("amount", rain)
		_rain_sys.set("intensity", heavy)

	var hero := get_tree().get_first_node_in_group("player")
	if hero:
		# Холодный ореол героя (player_spawner.gd) — ночной, днём не нужен
		var glow := hero.get_node_or_null("PlayerGlow") as PointLight2D
		if glow:
			if not glow.has_meta("base_energy"):
				glow.set_meta("base_energy", glow.energy)
			glow.energy = float(glow.get_meta("base_energy")) * clampf(dark, 0.0, 1.0)
		_update_fog(hero)


func _update_fog(hero: Node) -> void:
	if not is_instance_valid(_fog):
		return
	_fog.visible = fog > 0.01
	if not _fog.visible:
		return
	var cam := hero.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var view := get_viewport().get_visible_rect().size / cam.zoom
	_fog.global_position = cam.get_screen_center_position()
	_fog.scale = view * 1.3
	_fog_mat.set_shader_parameter("density", fog)
	_fog_mat.set_shader_parameter("scale", FOG_SCALE)
	_fog_mat.set_shader_parameter("drift_a", _fog_drift_a)
	_fog_mat.set_shader_parameter("drift_b", _fog_drift_b)
	_fog_mat.set_shader_parameter("cam_pos", _fog.global_position)
	_fog_mat.set_shader_parameter("view_half", view * 0.5)
