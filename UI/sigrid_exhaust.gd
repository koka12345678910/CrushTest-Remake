extends CanvasLayer
## Истощение Сигрид и рыцаря — вместо общей голубой виньетки
## (sustained_vignette.gd): багровая рамка с венами, которая бьётся в такт
## сердцу (Shaders/sigrid_exhaust.gdshader). Тот же интерфейс, что у общей
## виньетки — set_active(on) — его зовут character_base.gd::_update_condition_fx
## (Сигрид) и player.gd::_update_condition_fx (рыцарь).
##
## Такт — по самому звуку сердцебиения (Sound/pulse.mp3, плеер HeartbeatAudio
## героя): в файле двойной стук «тук-ТУК» — первый удар в FIRST_BEAT, второй,
## громче, через DUB, и так каждые PERIOD секунд (замерено по огибающей
## файла). Позиция берётся из плеера, поэтому картинка не уезжает от звука.
## Если сердце молчит — тот же ритм по своим часам

const SHADER := preload("res://Shaders/sigrid_exhaust.gdshader")
const FIRST_BEAT := 0.95
const PERIOD := 1.4273
const DUB := 0.46
## После этого места в файле ударов уже нет (хвост тишины до конца петли)
const LAST_BEAT_END := 33.9

@export var fade_in_time := 0.6
@export var fade_out_time := 0.9

var _rect: ColorRect
var _mat: ShaderMaterial
var _active := false
var _strength := 0.0
var _clock := 0.0


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("vein_tex", _vein_noise())
	_mat.set_shader_parameter("warp_tex", _warp_noise())
	_rect.material = _mat
	add_child(_rect)
	visible = false


func set_active(on: bool) -> void:
	_active = on


func _process(delta: float) -> void:
	var target := 1.0 if _active else 0.0
	var speed := 1.0 / (fade_in_time if _active else fade_out_time)
	_strength = move_toward(_strength, target, speed * delta)
	visible = _strength > 0.001
	if not visible:
		return
	_clock += delta
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_mat.set_shader_parameter("strength", smoothstep(0.0, 1.0, _strength))
	_mat.set_shader_parameter("beat", _beat())


## 0..1 — насколько «бьёт» прямо сейчас: два затухающих толчка на цикл
func _beat() -> float:
	var t := _clock
	var hb: AudioStreamPlayer = null
	if get_parent():
		hb = get_parent().get("_heartbeat") as AudioStreamPlayer
		if hb == null:
			# у рыцаря плеер сердцебиения — нода HeartbeatAudio (player.gd)
			hb = get_parent().get("heartbeat_audio") as AudioStreamPlayer
	if hb and hb.playing:
		t = hb.get_playback_position() + AudioServer.get_time_since_last_mix()
		if t < FIRST_BEAT - 0.05 or t > LAST_BEAT_END:
			return 0.0
	var ph := fposmod(t - FIRST_BEAT, PERIOD)
	return clampf(_thump(ph, 0.0, 0.7) + _thump(ph, DUB, 1.0), 0.0, 1.0)


## Толчок: быстрый подъём за 40 мс и затухание
static func _thump(ph: float, at: float, amp: float) -> float:
	var dt := ph - at
	if dt < -0.04:
		return 0.0
	if dt < 0.0:
		return amp * (1.0 + dt / 0.04)
	return amp * exp(-dt * 6.5)


## Сеть вен — края ячеек клеточного шума (DISTANCE2_SUB ≈ 0 на границе)
static func _vein_noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.frequency = 0.012
	n.seed = 7
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 30.0
	n.domain_warp_frequency = 0.01
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	return t


## Мягкий шум для изгиба вен и разрывов сети
static func _warp_noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.008
	n.seed = 13
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	return t
