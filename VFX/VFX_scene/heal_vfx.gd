class_name HealVFX
extends Node2D
## Процедурный VFX лечения — три варианта под три способности.
##
## Всё строится кодом (частицы + радиальные градиенты вместо текстур), как
## свечение быстрого слота в quick_slot_ui.gd — новых файлов на диске не нужно.
## Инстанцируется через .new(), а не из .tscn: сцена не понадобилась бы ни для
## чего, кроме хранения тех же самых параметров.
##
## Три способности лечат по-разному, и эффект должен читать РАЗНИЦУ, а не
## просто "что-то полезное произошло":
##   HONEY    — медленный тик-хил: тёплые искры неспешно поднимаются вверх
##   VALKYRIE — тик-хил + снятие негатива: кольцо очищения, затем перья ВНИЗ
##   ELIXIR   — мгновенный хил: один резкий взрыв, без растянутого шлейфа

enum Variant { HONEY, VALKYRIE, ELIXIR }

var variant: int = Variant.HONEY
## Сколько секунд идёт эмиссия. Для тик-хилов совпадает с длительностью
## лечения, для мгновенного эликсира не используется (там one_shot)
var duration: float = 3.0

var _particles: CPUParticles2D


func _ready() -> void:
	_particles = CPUParticles2D.new()
	# У мёда своя текстура — мягкое дымчатое пятно без чёткого края (см.
	# _make_smoke_texture). _make_dot_texture специально сделана с плотным
	# ядром и резкой границей — это годится для искр/перьев, но не для пара:
	# с ней частицы читались бы как капли, а не как дымка
	_particles.texture = _make_smoke_texture() if variant == Variant.HONEY else _make_dot_texture()
	# Аддитивный бленд — тот же приём, что у вспышек Фенрира/Одина/Руны: на
	# тёмной ночной сцене частицы начинают именно СВЕТИТЬСЯ, а не лежать
	# полупрозрачным серым пятном поверх фона.
	# Мёд — исключение: это пар над кружкой, а не магическая искра, светиться
	# он не должен. Обычное альфа-смешивание вместо аддитивного, цвета в
	# _setup_honey() уже не HDR-переяркие (не глушить бленд-режимом нечего)
	if variant != Variant.HONEY:
		_particles.material = _make_additive_material()
	add_child(_particles)

	match variant:
		Variant.HONEY:
			_setup_honey()
		Variant.VALKYRIE:
			_setup_valkyrie()
		Variant.ELIXIR:
			_setup_elixir()

	_particles.emitting = true

	# Живём ровно столько, сколько нужно последней частице: время эмиссии плюс
	# её собственный lifetime. Иначе узел либо оборвал бы хвост, либо остался
	# висеть в сцене навсегда
	var alive := _particles.lifetime
	if not _particles.one_shot:
		alive += duration
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(_particles):
			_particles.emitting = false
	await get_tree().create_timer(_particles.lifetime + 0.1).timeout
	queue_free()


# --- Мёд Поэзии: лёгкий пар над кружкой, а не магическое свечение ---
func _setup_honey() -> void:
	var p := _particles
	# Дымка — это МНОГО МЕЛКИХ мягких пятен, перекрывающих друг друга, а не
	# горстка крупных чётких капель. Область спавна при этом маленькая (как
	# у шлейфа монет) — плотное, компактное облачко, а не крупный эффект
	p.amount = 24
	p.lifetime = 1.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(7, 9)
	p.direction = Vector2(0, -1)
	p.spread = 35.0                      # шире искрового — пар не летит по прямой, а колышется
	p.gravity = Vector2(0, -14)          # тянет вверх медленно и вальяжно
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.damping_min = 2.0                  # гасим разгон — пар не ускоряется, а плывёт
	p.damping_max = 5.0
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.22
	# Пар расширяется и тает по мере подъёма — растущий масштаб продаёт это
	# нагляднее, чем частицы неизменного размера
	p.scale_amount_curve = _make_growth_curve()
	# Обычные (не HDR) цвета — без аддитивного бленда (см. _ready) переяркие
	# значения просто выглядели бы плоским пересвеченным пятном. Тёплый
	# бледный оттенок пара, не искра
	p.color_ramp = _make_ramp(
		Color(0.85, 0.78, 0.6, 0.0),
		Color(0.8, 0.73, 0.56, 0.4),
		Color(0.68, 0.63, 0.5, 0.0)
	)


# --- Песнь Валькирии: перья мягко падают ВНИЗ + кольцо очищения ---
func _setup_valkyrie() -> void:
	var p := _particles
	p.amount = 22
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20, 6)
	p.position = Vector2(0, -30)         # сыплются сверху, от головы игрока
	p.direction = Vector2(0, 1)
	p.spread = 34.0
	p.gravity = Vector2(0, 22)           # вниз, но медленно — перья планируют
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 18.0
	p.damping_min = 8.0                  # гасим скорость: планирование, не падение
	p.damping_max = 14.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.65
	p.color_ramp = _make_ramp(
		Color(1.5, 1.42, 1.05, 0.0),
		Color(1.4, 1.3, 0.9, 1.0),
		Color(0.8, 0.72, 0.45, 0.0)
	)
	_spawn_cleanse_ring()


# --- Эликсир Вальгаллы: один резкий взрыв, лечение мгновенное ---
func _setup_elixir() -> void:
	var p := _particles
	p.amount = 30
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0                # все частицы разом, а не потоком
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0                     # во все стороны
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	p.color_ramp = _make_ramp(
		Color(1.8, 1.3, 0.6, 1.0),
		Color(1.7, 0.5, 0.22, 1.0),
		Color(0.9, 0.12, 0.08, 0.0)
	)


# Кольцо очищения — расходящаяся волна в момент снятия негативных эффектов.
# Отдельный спрайт, а не частицы: нужна одна чёткая расширяющаяся окружность
func _spawn_cleanse_ring() -> void:
	var ring := Sprite2D.new()
	ring.texture = _make_ring_texture()
	ring.material = _make_additive_material()
	ring.scale = Vector2(0.25, 0.18)     # сплюснуто по вертикали — вид сверху
	ring.modulate = Color(1.5, 1.4, 1.0, 1.0)
	add_child(ring)

	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(1.5, 1.05), 0.55)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(ring, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)


# --- Процедурные текстуры ---

func _make_smoke_texture() -> GradientTexture2D:
	## Мягкое дымчатое пятно — в отличие от _make_dot_texture (чёткое ядро,
	## резкий обрез) тут затухание растянуто почти на весь радиус: ни одной
	## точки с чётким краем, только плавный туман. Так частицы сливаются в
	## общее облачко, а не читаются как отдельные капли
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)
	])
	return _radial(grad, 40)


## Кривая роста для scale_amount_curve — частица рождается мелкой и
## увеличивается к концу жизни, как расширяющийся и оседающий пар
func _make_growth_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.45))
	c.add_point(Vector2(1.0, 1.7))
	return c


func _make_dot_texture() -> GradientTexture2D:
	## Искра с ЧЁТКИМ краем. Раньше затухание начиналось почти от центра
	## (0.45) и тянулось до самого края — из-за этого частицы выглядели
	## мыльными пятнами. Держим плотное ядро до 0.55 и гасим коротко, за
	## последнюю четверть радиуса
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.68, 0.82, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)
	])
	return _radial(grad, 32)


func _make_ring_texture() -> GradientTexture2D:
	## Прозрачный центр, яркий обод — именно кольцо, а не заливка. Полоса
	## обода узкая (0.72..0.86), иначе кольцо расплывается в мутный диск
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.72, 0.8, 0.86, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)
	])
	return _radial(grad, 192)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _radial(grad: Gradient, size: int) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


func _make_ramp(from: Color, mid: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([from, mid, to])
	return g
