extends Node
## weather_link.gd — погружение reference_map слушает время суток и погоду
## (автозагрузка Weather, Levels/weather.gd; на карте она включена узлом
## NightModulate).
##
## Всё погружение настраивалось под вечную ночь. Здесь те же эффекты
## подстраиваются под час и небо, плавно (Weather сам всё меняет плавно):
##   облака    — днём чёткие тени и тёплое солнце в просветах; в сплошных
##               тучах отдельных теней нет (небо и так серое); ночью — как было;
##   ветер     — кроны, трава, ткань и передний план качаются по силе ветра
##               погоды (туман — почти штиль, гроза — сильно);
##   передний план — днём не такой чёрный;
##   пропасть  — днём на дно попадает больше света;
##   река      — отражает дневное небо, в тучах бликов меньше.
## Без погоды (Weather не активна) всё остаётся ночным, как было.

const CLOUD_SHADER := preload("res://reference_map_level/shaders/cloud_shadows.gdshader")
const FG_SHADER := preload("res://reference_map_level/shaders/foreground.gdshader")
const ABYSS_SHADER := preload("res://reference_map_level/shaders/abyss.gdshader")
const SHEEN_SHADER := preload("res://reference_map_level/shaders/water_sheen.gdshader")
const WIND_SHADER := preload("res://reference_map_level/shaders/wind_fade.gdshader")

## Ночные значения — как настроено в immersion.gd; дневные — здесь
const NIGHT_MOON := Color(0.55, 0.63, 0.82)
const DAY_SUN := Color(1.0, 0.93, 0.8)
const NIGHT_SKY := Color(0.6, 0.7, 0.9)
const DAY_SKY := Color(0.82, 0.88, 0.95)

var _clouds: Array[ShaderMaterial] = []
var _fg: Array[ShaderMaterial] = []
var _fg_nodes: Array[Node] = []
var _abyss: Array[ShaderMaterial] = []
var _sheen: Array[ShaderMaterial] = []
var _wind: Array[ShaderMaterial] = []
## Исходные значения материалов (ночь) — материал -> {параметр: значение}
var _base := {}
var _wind_base := 1.0
var _t := 0.0
var stats := {}


## Слой воды: цвет подобран под ночь — днём он ядовито-бирюзовый, гасим
var _water: CanvasItem
var _water_night := Color.WHITE
## Во сколько раз темнее и серее вода в полдень
const WATER_DAY := Color(0.74, 0.74, 0.7)


## Старт карты: час и погода при ПЕРВОМ заходе на карту за сессию (после
## смерти и перезахода время идёт дальше). <0 — не трогать (как задано в
## Weather). Погода — Weather.Kind: 0 ясно, 1 пасмурно, 2 туман, 3 дождь, 4 гроза
var start_hour := -1.0
var start_weather := -1


func setup(map: Node, wind_strength: float) -> void:
	_wind_base = wind_strength
	_start_once()
	_water = map.get_node_or_null("Water") as CanvasItem
	if _water:
		_water_night = _water.modulate
	_walk(map)
	stats = {"clouds": _clouds.size(), "foreground": _fg.size(), "abyss": _abyss.size(),
		"river": _sheen.size(), "wind": _wind.size()}


func _start_once() -> void:
	var w := get_node_or_null("/root/Weather")
	if w == null or w.has_meta("reference_map_started"):
		return
	# В коопе час и погоду решает хост, клиенту их пришлёт Net
	var net := get_node_or_null("/root/Net")
	if net and net.call("is_client"):
		return
	w.set_meta("reference_map_started", true)
	if start_hour >= 0.0:
		w.call("set_hour", start_hour)
	if start_weather >= 0:
		w.call("set_weather", start_weather, true)


func _walk(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			var m := (c as CanvasItem).material as ShaderMaterial
			if m and not _base.has(m):
				_sort(m)
			if "wind_strength" in c and c.get_script() != null and m and m.shader == FG_SHADER:
				_fg_nodes.append(c)
		if c is TileMapLayer and (c as TileMapLayer).tile_set:
			_tiles((c as TileMapLayer).tile_set)
		_walk(c)


func _tiles(ts: TileSet) -> void:
	for si in ts.get_source_count():
		var src := ts.get_source(ts.get_source_id(si)) as TileSetAtlasSource
		if src == null:
			continue
		for ti in src.get_tiles_count():
			var coords := src.get_tile_id(ti)
			for ai in src.get_alternative_tiles_count(coords):
				var td := src.get_tile_data(coords, src.get_alternative_tile_id(coords, ai))
				var m := td.material as ShaderMaterial if td else null
				if m and not _base.has(m):
					_sort(m)


func _sort(m: ShaderMaterial) -> void:
	var keys: Array = []
	match m.shader:
		CLOUD_SHADER:
			_clouds.append(m)
			keys = ["strength", "moon_strength", "light_keep"]
		FG_SHADER:
			_fg.append(m)
			keys = ["darkness"]
		ABYSS_SHADER:
			_abyss.append(m)
			keys = ["floor_light"]
		SHEEN_SHADER:
			_sheen.append(m)
			keys = ["sheen", "glint"]
		WIND_SHADER:
			_wind.append(m)
		_:
			return
	var b := {}
	for k in keys:
		var v: Variant = m.get_shader_parameter(k)
		if v == null:
			# Не задан в материале — значение по умолчанию из шейдера
			v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), k)
		b[k] = v
	_base[m] = b


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	var w := get_node_or_null("/root/Weather")
	if w == null or not w.call("is_active"):
		return
	var day: float = 1.0 - float(w.get("night"))
	var cloud: float = w.get("cloud")
	var wind: float = w.get("wind")
	for m in _clouds:
		var b: Dictionary = _base[m]
		# Днём тени облаков чёткие; в сплошных тучах их не видно
		var s: float = lerpf(float(b["strength"]), 0.34, day) * (1.0 - cloud * 0.85)
		m.set_shader_parameter("strength", s)
		m.set_shader_parameter("moon_color", NIGHT_MOON.lerp(DAY_SUN, day))
		m.set_shader_parameter("moon_strength", lerpf(float(b["moon_strength"]), 0.22, day) * (1.0 - cloud * 0.9))
		# Ночью светлое — это огонь, его облако не гасит; днём светло всё
		var lk: Vector2 = b["light_keep"]
		m.set_shader_parameter("light_keep", lk.lerp(Vector2(0.95, 1.4), day))
	for m in _fg:
		m.set_shader_parameter("darkness", lerpf(float(_base[m]["darkness"]), 0.85, day))
	for m in _abyss:
		m.set_shader_parameter("floor_light", lerpf(float(_base[m]["floor_light"]), 0.4, day))
	for m in _sheen:
		var b: Dictionary = _base[m]
		m.set_shader_parameter("moon_color", NIGHT_SKY.lerp(DAY_SKY, day))
		m.set_shader_parameter("sheen", float(b["sheen"]) * lerpf(1.0, 0.3, day) * (1.0 - cloud * 0.5))
		m.set_shader_parameter("glint", float(b["glint"]) * (1.0 - cloud * 0.8))
	if is_instance_valid(_water):
		var wc := _water_night * Color.WHITE.lerp(WATER_DAY, day)
		wc.a = _water_night.a
		_water.modulate = wc
	# Ветер погоды: 1 — обычный (ясно), 0.4 туман … 2.2 гроза
	var ws := _wind_base * clampf(wind, 0.3, 2.4)
	for m in _wind:
		m.set_shader_parameter("wind_strength", ws)
	for n in _fg_nodes:
		if is_instance_valid(n):
			n.set("wind_strength", ws)
