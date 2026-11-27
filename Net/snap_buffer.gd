extends RefCounted
## snap_buffer.gd — очередь сетевых снимков с плавным показом (Net/net.gd).
## Общая для кукол игроков (net_puppet.gd) и копий врагов (enemy.gd в режиме
## net_replica).
##
## Показываем не последний снимок, а мир «задержку» мс назад: между двумя
## снимками, которые окружают этот момент, позиция идёт линейно. Пакет,
## пришедший с опозданием или потерянный, не даёт рывка. Время снимков — часы
## отправителя; сдвиг до своих часов — минимум (приход − отправка): пинг в одну
## сторону плюс разница часов.
##
## Задержка подстраивается под сеть: в локальной сети пакеты идут ровно —
## DELAY (100 мс); через интернет они приходят «пачками» (разброс, джиттер) —
## задержка растёт на этот разброс, до MAX_DELAY, иначе кукла дёргалась бы
## между «стоит» и «догоняет». Сеть успокоилась — задержка медленно
## возвращается к DELAY.

const DELAY := 100.0
const MAX_DELAY := 320.0
## Новее снимков нет — продолжаем движение не дальше этого, потом стоим
const MAX_EXTRAPOLATE := 120.0
const MAX_SIZE := 32
## Часы двух компьютеров чуть расходятся (десятки мкс в секунду). Сдвиг
## понемногу «отпускаем» вверх, чтобы он шёл за ними и задержка не копилась
const OFFSET_CREEP := 0.0005

var _buf: Array = []
var _offset := INF
var _last_push := 0.0
## Насколько снимки опаздывают сверх лучшего (сглажено), мс
var _jitter := 0.0
var _delay := DELAY


## t — время отправителя (мс), data — сам снимок. true — это первый снимок
func push(t: float, data: Array) -> bool:
	var now := float(Time.get_ticks_msec())
	if _offset != INF:
		_offset += (now - _last_push) * OFFSET_CREEP
	_last_push = now
	_offset = minf(_offset, now - t)
	var late := (now - t) - _offset
	# Растёт быстро (сеть забарахлила — сразу запас), спадает медленно
	_jitter = lerpf(_jitter, late, 0.2 if late > _jitter else 0.01)
	_delay = clampf(DELAY + _jitter * 1.5, DELAY, MAX_DELAY)
	var first := _buf.is_empty()
	if not first and t <= float(_buf[_buf.size() - 1][0]):
		return false
	_buf.append([t, data])
	if _buf.size() > MAX_SIZE:
		_buf.pop_front()
	return first


func is_empty() -> bool:
	return _buf.is_empty()


## Текущая задержка показа, мс (для отладки)
func delay_ms() -> float:
	return _delay


## [позиция, снимок для вида] на сейчас; pos_index — где в снимке позиция.
## Пусто — снимков ещё нет
func sample(pos_index: int) -> Array:
	if _buf.is_empty():
		return []
	var t := float(Time.get_ticks_msec()) - _offset - _delay
	while _buf.size() > 2 and float(_buf[1][0]) <= t:
		_buf.pop_front()
	var a: Array = _buf[0]
	if _buf.size() == 1 or t <= float(a[0]):
		return [a[1][pos_index], a[1]]
	var b: Array = _buf[1]
	var ta := float(a[0])
	var tb := float(b[0])
	var pa: Vector2 = a[1][pos_index]
	var pb: Vector2 = b[1][pos_index]
	if t >= tb:
		var vel := (pb - pa) / maxf(tb - ta, 1.0)
		return [pb + vel * minf(t - tb, MAX_EXTRAPOLATE), b[1]]
	return [pa.lerp(pb, (t - ta) / maxf(tb - ta, 1.0)), a[1]]


## Последний пришедший снимок (для того, что не интерполируется: здоровье)
func latest() -> Array:
	return _buf[_buf.size() - 1][1] if not _buf.is_empty() else []
