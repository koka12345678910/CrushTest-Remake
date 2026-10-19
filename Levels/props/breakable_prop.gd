extends StaticBody2D
## breakable_prop.gd — предмет, который можно разбить: бочка, ящик, скамья…
##
## Узел стоит основанием предмета (по нему он сортируется по глубине). Внутри:
## Sprite2D (картинка — AtlasTexture из листа), CollisionShape2D (твёрдое
## основание) и Hurtbox — Area2D на весь предмет. Узлы собирает
## tools/graveyard_generator.gd (gp_breakable).
##
## Что бьёт: ближние удары героев — области в группе "player_attack" (меч
## рыцаря, пинок лучника) — ловятся Hurtbox'ом, как у врагов. Стрелы и
## заклинания мага зовут take_damage() сами: предмет в группе "breakable" и
## отвечает тем же, что и враг (is_dead, take_damage, global_position).
## Урон не важен — каждое попадание снимает одну "прочность" (hits).
##
## Разбитый предмет разлетается обломками — его же картинка, нарезанная на
## куски: они подлетают, падают, чуть подпрыгивают и лежат, потом гаснут.
## Иногда выпадают монеты.

const GoldWisp := preload("res://VFX/VFX_scene/gold_wisp.gd")
const HIT_SOUND := preload("res://Sound/melee_sound/block.wav")
const BREAK_SOUND := preload("res://Sound/posture_break.mp3")

## Сколько попаданий выдерживает
@export var hits := 2
## Шанс, что из обломков выпадут монеты
@export_range(0.0, 1.0) var loot_chance := 0.0
## Цвет щепок (средний цвет предмета)
@export var chip_color := Color(0.42, 0.3, 0.2)
## На сколько кусков режется картинка
@export var pieces := Vector2i(2, 2)
## Сколько лежат обломки, прежде чем погаснуть
@export var debris_time := 6.0

var is_dead := false

var _sprite: Sprite2D
var _cooldown := 0.0
var _chunks: Array = []      # [узел, скорость xy, высота, скорость по высоте, угл. скорость]
var _age := 0.0


func _ready() -> void:
	add_to_group("breakable")
	_sprite = get_node("Sprite") as Sprite2D
	var hb := get_node_or_null("Hurtbox") as Area2D
	if hb:
		hb.area_entered.connect(_on_hurtbox_area_entered)
	set_process(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack") or (area.get_parent() and area.get_parent().is_in_group("player_attack")):
		take_damage(1, area.get_parent())


## Тот же вход, что у врагов: стрелы и заклинания зовут его напрямую
func take_damage(_amount: int = 1, source: Node = null) -> void:
	if is_dead or _cooldown > 0.0:
		return
	# Один взмах меча может задеть предмет несколько раз подряд
	_cooldown = 0.18
	hits -= 1
	if hits <= 0:
		_break(source)
	else:
		_hit_feedback(source)


func _hit_feedback(source: Node) -> void:
	_play(HIT_SOUND, randf_range(0.62, 0.78), -4.0)
	var away := _away_from(source)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color(2.2, 2.2, 2.2), 0.04)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	var s := create_tween()
	s.tween_property(_sprite, "position", away * 3.0, 0.05)
	s.tween_property(_sprite, "position", -away * 1.5, 0.06)
	s.tween_property(_sprite, "position", Vector2.ZERO, 0.08)
	_splinters(6, away)


func _break(source: Node) -> void:
	is_dead = true
	remove_from_group("breakable")
	for ch in get_children():
		if ch is CollisionShape2D:
			(ch as CollisionShape2D).set_deferred("disabled", true)
	var hb := get_node_or_null("Hurtbox") as Area2D
	if hb:
		hb.set_deferred("monitoring", false)
	_play(BREAK_SOUND, randf_range(0.7, 0.82), -3.0)
	_play(HIT_SOUND, randf_range(0.5, 0.6), -2.0)
	var away := _away_from(source)
	_splinters(16, away)
	_spawn_chunks(away)
	_sprite.visible = false
	if randf() < loot_chance:
		_drop_coins()
	set_process(true)


## Направление "от удара" — туда предмет качнётся и полетят обломки
func _away_from(source: Node) -> Vector2:
	if source is Node2D and is_instance_valid(source):
		var d := global_position - (source as Node2D).global_position
		if d.length() > 0.5:
			return d.normalized()
	return Vector2.from_angle(randf() * TAU)


func _spawn_chunks(away: Vector2) -> void:
	var at := _sprite.texture as AtlasTexture
	if at == null:
		return
	var reg := at.region
	var sc := _sprite.scale
	var cell := reg.size / Vector2(pieces)
	for j in pieces.y:
		for i in pieces.x:
			var sub := AtlasTexture.new()
			sub.atlas = at.atlas
			sub.region = Rect2(reg.position + cell * Vector2(i, j), cell)
			var s := Sprite2D.new()
			s.texture = sub
			s.scale = sc
			s.flip_h = _sprite.flip_h
			s.texture_filter = _sprite.texture_filter
			s.material = _sprite.material
			# Кусок стоит там же, где был в целой картинке (с учётом отражения)
			var cx := (i + 0.5) * cell.x
			if _sprite.flip_h:
				cx = reg.size.x - cx
			var local := _sprite.offset + Vector2(cx, (j + 0.5) * cell.y)
			var p := local * sc
			add_child(s)
			# Летит от удара и в стороны от центра предмета; верхние куски — выше
			var out := Vector2(p.x, 0.0).normalized() if absf(p.x) > 0.5 else Vector2.ZERO
			var v := (away * randf_range(25.0, 60.0) + out * randf_range(15.0, 40.0)) * Vector2(1.0, 0.6)
			var height := -p.y        # высота куска над землёй
			_chunks.append([s, v, height, randf_range(40.0, 90.0), randf_range(-8.0, 8.0), p.x, 0.0])


func _process(delta: float) -> void:
	_age += delta
	for c in _chunks:
		var s: Sprite2D = c[0]
		# c[5], c[6] — положение куска на земле; c[2] — высота над землёй
		if c[2] > 0.0 or c[3] > 0.0:
			c[3] -= 260.0 * delta
			c[2] += c[3] * delta
			c[5] += c[1].x * delta
			c[6] += c[1].y * delta
			s.rotation += c[4] * delta
			if c[2] <= 0.0:
				c[2] = 0.0
				# Отскок: слабее с каждым разом, по земле тормозит
				c[3] = -c[3] * 0.3 if absf(c[3]) > 30.0 else 0.0
				c[1] *= 0.45
				c[4] *= 0.4
		s.position = Vector2(c[5], c[6] - c[2])
	if _age > debris_time:
		modulate.a = 1.0 - clampf((_age - debris_time) / 1.5, 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()


## Щепки: мелкие квадратики цвета предмета, разлетаются и падают
func _splinters(amount: int, away: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.position = Vector2(0, _sprite.offset.y * _sprite.scale.y * 0.5)
	p.direction = (away + Vector2(0, -1.2)).normalized()
	p.spread = 70.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = chip_color
	p.z_index = 1
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _drop_coins() -> void:
	var level := get_tree().current_scene
	if level == null:
		return
	# Герой без золота (маг копит души, а не монеты) — монеты не выпадают
	var hero := get_tree().get_first_node_in_group("player")
	if hero and "collects_gold" in hero and not hero.collects_gold:
		return
	# Золотые души вместо монет — сами летят к игроку (gold_wisp.gd)
	for i in randi_range(1, 2):
		GoldWisp.spawn(get_tree(), global_position + Vector2(0, -6), 5)


func _play(stream: AudioStream, pitch: float, volume: float) -> void:
	var a := AudioStreamPlayer2D.new()
	a.stream = stream
	a.pitch_scale = pitch
	a.volume_db = volume
	a.max_distance = 700.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
