extends RefCounted
## sound_bank.gd — банк звуков: Хальвард, скелеты, шаги, новые механики и
## эмбиент (файлы и авторы — Sound/CREDITS_sound_pass.txt). Каждый звук — пул
## вариантов, подряд один и тот же не повторяется.
##
## Файлы грузятся лениво: нет импорта (редактор ещё не видел новый файл) —
## WAV читается прямо с диска, а нет и файла — вызывающий получает null и
## оставляет свой прежний звук.

const DIR := "res://Sound/"

## Пул: папка и имена без расширения либо "имя_" + число вариантов
const POOLS := {
	"knight_swing": ["knight/swing_", 5],
	"knight_run_swing": ["knight/run_swing_", 2],
	"knight_hit_light": ["knight/hit_light_", 4],
	"knight_hit_heavy": ["knight/hit_heavy_", 4],
	"knight_hit_run": ["knight/hit_run_", 2],
	"knight_body": ["knight/body_", 3],
	"knight_block": ["knight/block_", 3],
	"knight_parry": ["knight/parry_", 3],
	"knight_armor": ["knight/armor_step_", 4],
	"step_soft": ["footsteps/soft_", 6],
	"step_stone": ["footsteps/stone_", 6],
	"skel_grunt": ["skeleton/grunt_", 5],
	"skel_aggro": ["skeleton/aggro_", 4],
	"skel_moan": ["skeleton/moan_", 5],
	"skel_swing": ["skeleton/swing_", 4],
	"skel_hit": ["skeleton/hit_", 3],
	"skel_rattle": ["skeleton/rattle_", 10],
	"skel_collapse": ["skeleton/collapse_", 3],
	"mage_hurt": ["mage_voice/hurt_", 3],
}
## Одиночные звуки
const SINGLE := {
	"knight_draw": "knight/draw.wav",
	"mage_death": "mage_voice/death.wav",
	"trap_place": "mechanics/trap_place.wav",
	"trap_snap": "mechanics/trap_snap.wav",
	"roots": "mechanics/roots.wav",
	"life_exchange": "mechanics/life_exchange.wav",
	"execution_wave": "mechanics/execution_wave.wav",
}

const GROUND_MASK := "res://TileMap/ground/generated/ground_mask.res"
const GROUND_MAP_PX := Vector2(3072, 1536)

static var _cache := {}
static var _last := {}
static var _mask: Image


## Звук из файла (null — файла нет)
static func load_sound(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
	elif path.ends_with(".wav") and FileAccess.file_exists(path):
		st = _read_wav(path)
	elif path.ends_with(".ogg") and FileAccess.file_exists(path):
		st = AudioStreamOggVorbis.load_from_file(path)
	_cache[path] = st
	return st


## Наш WAV (моно, 16 бит, заголовок 44 байта) — пока нет импорта
static func _read_wav(path: String) -> AudioStream:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() <= 44:
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = b.decode_u32(24)
	w.stereo = b.decode_u16(22) == 2
	w.data = b.slice(44)
	return w


## Все варианты пула (пусто — ни одного файла нет)
static func pool(key: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	if POOLS.has(key):
		var p: Array = POOLS[key]
		for i in int(p[1]):
			var st := load_sound("%s%s%d.wav" % [DIR, p[0], i + 1])
			if st:
				out.append(st)
	elif SINGLE.has(key):
		var st := load_sound(DIR + SINGLE[key])
		if st:
			out.append(st)
	return out


## Пул для плеера рыцаря: новый или, пока файлов нет, прежний
static func pool_or(key: String, fallback: Array[AudioStream]) -> Array[AudioStream]:
	var p := pool(key)
	return p if not p.is_empty() else fallback


## Случайный вариант, подряд не повторяется
static func pick(key: String) -> AudioStream:
	var p := pool(key)
	if p.is_empty():
		return null
	var idx := randi() % p.size()
	if p.size() > 1 and idx == int(_last.get(key, -1)):
		idx = (idx + 1 + randi() % (p.size() - 1)) % p.size()
	_last[key] = idx
	return p[idx]


static func pick_or(key: String, fallback: AudioStream) -> AudioStream:
	var st := pick(key)
	return st if st else fallback


## Разовый звук в точке мира: свой плеер, не обрывает другие
static func play_at(tree: SceneTree, key: String, at: Vector2, db := 0.0, pitch := 1.0, bus := "Combat") -> void:
	var st := pick(key)
	if st == null or tree == null or tree.current_scene == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = bus
	tree.current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


## Зацикленная копия потока: кэш не трогаем, настройка — до запуска
static func loop_stream(rel: String) -> AudioStream:
	var st := load_sound(DIR + rel)
	if st == null:
		return null
	if st is AudioStreamWAV:
		var w: AudioStreamWAV = st.duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(st.get_length() * w.mix_rate)
		return w
	if st is AudioStreamOggVorbis or st is AudioStreamMP3:
		var d: AudioStream = st.duplicate()
		d.set("loop", true)
		return d
	return st


## Что под ногами: "stone" (плиты, камень, пол в доме) или "soft" (трава,
## земля). Камень — зелёный канал маски земли (Shaders/ground_blend.gdshader)
static func surface_at(tree: SceneTree, at: Vector2) -> String:
	for h in tree.get_nodes_in_group("house_interior"):
		if h.has_method("is_roofed") and h.is_roofed(at):
			return "stone"
	var scene := tree.current_scene
	if scene == null or not scene.has_node("GroundSurface"):
		return "soft"
	if _mask == null:
		var tex: Texture2D = load(GROUND_MASK) if ResourceLoader.exists(GROUND_MASK) else null
		if tex == null:
			return "soft"
		_mask = tex.get_image()
		if _mask.is_compressed():
			_mask.decompress()
	var uv := (at / GROUND_MAP_PX).clamp(Vector2.ZERO, Vector2.ONE)
	var px := Vector2i(mini(int(uv.x * _mask.get_width()), _mask.get_width() - 1), mini(int(uv.y * _mask.get_height()), _mask.get_height() - 1))
	return "stone" if _mask.get_pixelv(px).g > 0.5 else "soft"


## Шаг по текущей поверхности (null — файлов нет, у героя останется старый)
static func step(tree: SceneTree, at: Vector2) -> AudioStream:
	return pick("step_stone" if surface_at(tree, at) == "stone" else "step_soft")
