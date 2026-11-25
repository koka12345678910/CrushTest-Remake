extends SceneTree
## Петля шелеста травы для главного меню из полевой записи.
##
## Источник: BigSoundBank #1097 «Wind in a cornfield» (CC0, автор не нужен),
## https://bigsoundbank.com/wind-in-a-cornfield-s1097.html — ветер в поле
## сухих стеблей, 3:25, 48 кГц, 16 бит, стерео. Оригинал в проект не кладём
## (38 МБ): инструмент вырезает из него петлю.
##
## Запуск: GRASS_SRC=<путь к 1097.wav> godot --headless --path . --script res://tools/menu_grass_import.gd
## Пишет Sound/ambience/grass_loop.wav: моно, 48 кГц, LEN секунд.
##
## Что делает:
##   - ищет самый ровный кусок записи (громкость по секундам близка к
##     медиане, без всплесков и провалов) — петля не «дышит» сама по себе,
##     порывы задаёт игра (MainMenu.gd);
##   - срезает низ ниже HP_HZ: гул ветра в микрофоне, ветер звучит отдельно;
##   - стерео → моно;
##   - хвост XF секунд подмешивает в начало — стык петли без щелчка.

const LEN := 40.0
const XF := 2.0
const HP_HZ := 160.0
const OUT := "res://Sound/ambience/grass_loop.wav"


func _initialize() -> void:
	var src := OS.get_environment("GRASS_SRC")
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		push_error("нет файла GRASS_SRC: " + src)
		quit(1)
		return
	var bytes := f.get_buffer(f.get_length())
	f.close()

	# Разбор RIFF: ищем fmt и data
	var ch := 2
	var sr := 48000
	var bits := 16
	var data_off := -1
	var data_len := 0
	var p := 12
	while p + 8 <= bytes.size():
		var id := bytes.slice(p, p + 4).get_string_from_ascii()
		var sz := bytes.decode_u32(p + 4)
		if id == "fmt ":
			ch = bytes.decode_u16(p + 10)
			sr = bytes.decode_u32(p + 12)
			bits = bytes.decode_u16(p + 22)
		elif id == "data":
			data_off = p + 8
			data_len = mini(sz, bytes.size() - data_off)
			break
		p += 8 + sz + (sz & 1)
	if data_off < 0 or bits != 16:
		push_error("не PCM16 WAV")
		quit(1)
		return
	var frames := data_len / (2 * ch)
	print("src: %d Гц, %d кан., %.1f с" % [sr, ch, float(frames) / sr])

	# Моно
	var mono := PackedFloat32Array()
	mono.resize(frames)
	for i in frames:
		var s := 0.0
		for c in ch:
			s += bytes.decode_s16(data_off + (i * ch + c) * 2)
		mono[i] = s / (32768.0 * ch)

	# Громкость по секундам и самый ровный кусок длиной LEN + XF
	var secs := frames / sr
	var rms := PackedFloat32Array()
	for s in secs:
		var acc := 0.0
		for i in range(s * sr, (s + 1) * sr):
			acc += mono[i] * mono[i]
		rms.append(sqrt(acc / sr))
	var sorted := rms.duplicate()
	sorted.sort()
	var med := sorted[sorted.size() / 2]
	var need := int(ceil(LEN + XF))
	var best := 0
	var best_cost := INF
	# Первые и последние 5 с не берём: там бывают щелчки записи
	for s in range(5, secs - need - 5):
		var cost := 0.0
		for k in need:
			var r: float = rms[s + k]
			cost += absf(log(maxf(r, 1e-5) / med))
		if cost < best_cost:
			best_cost = cost
			best = s
	print("кусок: %d–%d с (медиана RMS %.4f)" % [best, best + need, med])

	var n := int((LEN + XF) * sr)
	var buf := mono.slice(best * sr, best * sr + n)

	# Срез низа (2 прохода HP — крутизна 24 дБ/окт)
	for pass_i in 2:
		var hp := Biquad.new(HP_HZ, 0.707, sr)
		for i in buf.size():
			buf[i] = hp.run(buf[i])

	# Петля: хвост XF секунд — в начало, равномощный переход
	var xn := int(XF * sr)
	var body := buf.size() - xn
	var out := buf.slice(0, body)
	for i in xn:
		var k := float(i) / xn
		out[i] = out[i] * sqrt(k) + buf[body + i] * sqrt(1.0 - k)

	# Нормализация до пика 0.7
	var m := 0.0001
	for v in out:
		m = maxf(m, absf(v))
	var g := 0.7 / m
	for i in out.size():
		out[i] *= g
	_save(out, sr)
	quit()


class Biquad:
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(f: float, q: float, sr: float) -> void:
		var w := TAU * f / sr
		var c := cos(w)
		var al := sin(w) / (2.0 * q)
		var a0 := 1.0 + al
		b0 = (1.0 + c) / 2.0; b1 = -(1.0 + c); b2 = (1.0 + c) / 2.0
		a1 = -2.0 * c
		a2 = 1.0 - al
		b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0

	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		return y


func _save(buf: PackedFloat32Array, sr: int) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)  # RIFF
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)  # WAVE
	h.encode_u32(12, 0x20746d66)  # fmt
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 1)
	h.encode_u32(24, sr)
	h.encode_u32(28, sr * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)  # data
	h.encode_u32(40, data.size())
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	f.store_buffer(h)
	f.store_buffer(data)
	f.close()
	print("grass_loop.wav: %.1f с, %d Гц моно" % [float(buf.size()) / sr, sr])
