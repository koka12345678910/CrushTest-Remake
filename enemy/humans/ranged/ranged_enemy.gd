extends "res://enemy/humans/human_enemy.gd"
## ranged_enemy.gd — стрелок: держит дистанцию и стреляет снарядами.
##
## Всё остальное (реакции на удары, стан, смерть, навигация) — как у
## остальных людей (human_enemy.gd -> enemy/enemy.gd). Здесь:
##   * атака не включает хитбокс ближнего боя, а выпускает снаряды в моменты
##     вспышек выстрела на кадрах (shots);
##   * стреляет только при прямой видимости, иначе обходит стену по навмешу;
##   * держится на preferred_distance, подошедшему вплотную герою пятится;
##   * блока и стойки со щитом у стрелков нет;
##   * "вот-вот ударю" (по этому воин поднимает щит на парирование) — только
##     когда его снаряд реально подлетает к герою, а не пока он целится.

## Выстрелы по атакам: клип -> список [доля длины клипа, поворот в градусах, от чего].
## Доля — кадр вспышки на листе / 15. Поворот отсчитывается от направления
## на цель; если третий элемент "facing" — от направления взгляда (веер по
## кругу у стрелка: ружьё на кадрах крутится независимо от цели)
@export var shots := {
	"attack": [[0.69, 0.0]],
}
## Взрывы по области: клип -> список [доля, радиус px, смещение центра вперёд px].
## Урон всем героям в круге, картинку взрыва рисует сам лист, кольцо на
## земле показывает область
@export var bursts := {}
@export var burst_color := Color(0.95, 0.35, 1.0)
## Атаки только вблизи (удар посохом, ногой, взрыв вокруг себя): берутся,
## когда герой ближе close_range, и никогда — издалека
@export var close_only: PackedStringArray = []
@export var close_range := 70.0
## Вблизи — с какой вероятностью брать атаку ближнего боя, а не стрелять в упор
@export_range(0.0, 1.0) var close_preference := 0.75
@export_group("Снаряд")
@export var projectile_speed := 320.0
@export var projectile_range := 420.0
@export var projectile_length := 18.0
@export var projectile_width := 2.0
@export var projectile_core := Color(1, 1, 1)
@export var projectile_glow := Color(1, 0.5, 0.2)
## Точка вылета: вперёд по взгляду и вверх (дуло на уровне груди), px мира
@export var muzzle_forward := 18.0
@export var muzzle_up := 10.0
## Насколько пуля может уйти от направления, куда смотрит спрайт (8 сторон),
## чтобы попасть в героя. Больше — стреляет "боком", меньше — мажет
@export var aim_spread_deg := 25.0
## Упреждение: доля скорости героя, на которую стрелок целится вперёд
@export var aim_lead := 0.15
@export_group("Прицел")
## Линия прицела во время замаха — честное предупреждение о выстреле
@export var aim_line := false
@export var aim_line_color := Color(1, 0.2, 0.15, 0.55)
@export_group("Звук")
@export var shot_sound: AudioStream
@export var shot_volume_db := -6.0
@export var shot_pitch := 1.0

const ProjectileScript := preload("res://enemy/humans/ranged/enemy_projectile.gd")

var _fired := {}            # индекс выстрела -> true в текущей атаке
var _live: Array = []       # свои снаряды в полёте
var _aim: Line2D
var _shot_audio: AudioStreamPlayer2D


func _ready() -> void:
	super()
	# Зона обзора в базовой сцене — круг 145 px: за ним враг "теряет" героя.
	# Стрелку нужно видеть на свою дальность. Форму копируем — она общая
	# для всех врагов, сделанных из enemy.tscn
	var vs := get_node_or_null("VisionArea/CollisionShape2D") as CollisionShape2D
	if vs and vs.shape is CircleShape2D:
		var c := (vs.shape as CircleShape2D).duplicate() as CircleShape2D
		c.radius = vision_range
		vs.shape = c
	_aim = Line2D.new()
	_aim.width = 1.0
	_aim.default_color = aim_line_color
	_aim.visible = false
	_aim.top_level = true
	_aim.z_index = 9
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aim.material = mat
	add_child(_aim)
	_shot_audio = AudioStreamPlayer2D.new()
	_shot_audio.max_distance = 900.0
	if AudioServer.get_bus_index(&"Combat") >= 0:
		_shot_audio.bus = &"Combat"
	add_child(_shot_audio)


# ───────────── выбор состояния ─────────────

func _change_state(new_state: State) -> void:
	# Стойки со щитом у стрелка нет — вместо неё обычная погоня (держит дистанцию)
	if new_state == State.GUARD:
		new_state = State.CHASE
	# Стрелять только по видимой цели: за стеной — обходить
	if new_state == State.ATTACK and not has_line_of_sight():
		new_state = State.CHASE
	super(new_state)
	if current_state == State.ATTACK:
		_fired.clear()


## Блок — только если герой вплотную (у стрелков шанс блока обычно 0)
func _try_block() -> void:
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) > 60.0:
		return
	super()


func _state_chase(delta: float) -> void:
	# Цель за стеной — держать дистанцию бессмысленно, подходим по навмешу,
	# пока не откроется линия огня
	if not has_line_of_sight():
		var keep := preferred_distance
		preferred_distance = 24.0
		super(delta)
		preferred_distance = keep
		return
	super(delta)


func has_line_of_sight() -> bool:
	if not player or not is_instance_valid(player):
		return false
	var q := PhysicsRayQueryParameters2D.create(_muzzle_position(direction), player.global_position, 1)
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# ───────────── атака ─────────────

func _play_attack_sound() -> void:
	pass  # звук свиста оружия стрелку не нужен — звучит сам выстрел


## Выбор атаки по дистанции: вблизи — в основном атаки ближнего боя,
## издалека — только выстрелы
func _pick_attack_anim() -> String:
	var near := player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= close_range
	var near_list: PackedStringArray = []
	var far_list: PackedStringArray = []
	for a in attack_pool:
		if a in close_only:
			near_list.append(a)
		else:
			far_list.append(a)
	var keep := attack_pool
	if near and not near_list.is_empty() and (far_list.is_empty() or randf() < close_preference):
		attack_pool = near_list
	elif not far_list.is_empty():
		attack_pool = far_list
	var pick := super()
	attack_pool = keep
	return pick


func _state_attack(delta: float) -> void:
	var list: Array = shots.get(current_attack_anim, [])
	var blasts: Array = bursts.get(current_attack_anim, [])
	if list.is_empty() and not blasts.is_empty():
		_state_burst(blasts)
		return
	if list.is_empty():
		super(delta)  # атака без выстрелов — обычный удар ближнего боя
		return
	move_velocity = Vector2.ZERO
	if not player or not is_instance_valid(player):
		_exit_attack()
		_change_state(State.WANDER)
		return
	var first_shot := INF
	for i in list.size():
		var t: float = float(list[i][0]) * _attack_windup_time
		first_shot = minf(first_shot, t)
		if not _fired.has(i) and state_time >= t:
			_fired[i] = true
			var spec: Array = list[i]
			_fire(float(spec[1]), spec.size() > 2 and String(spec[2]) == "facing")
	# Прицел — до первого выстрела, ярче к моменту выстрела
	if aim_line and _fired.is_empty() and state_time < first_shot:
		var k := clampf(state_time / maxf(first_shot, 0.01), 0.0, 1.0)
		var from := _muzzle_position(_facing_vector())
		var dir := _aim_direction(from)
		_aim.clear_points()
		_aim.add_point(from)
		_aim.add_point(from + dir * projectile_range)
		var c := aim_line_color
		c.a *= 0.25 + 0.75 * k
		_aim.default_color = c
		_aim.visible = true
	else:
		_aim.visible = false
	if not _fired.is_empty():
		_stop_attack_telegraph()


func _exit_attack() -> void:
	if _aim:
		_aim.visible = false
	super()


func _facing_vector() -> Vector2:
	var ang: float = DIR_ANGLES.get(attack_direction_name if attack_direction_name != "" else _get_direction_name(direction), PI * 0.5)
	return Vector2.from_angle(ang)


func _muzzle_position(facing: Vector2) -> Vector2:
	return global_position + facing.normalized() * muzzle_forward + Vector2(0, -muzzle_up)


## Куда стрелять: в героя с упреждением, но не дальше aim_spread_deg от
## направления, куда смотрит спрайт — пуля вылетает оттуда, куда смотрит ружьё
func _aim_direction(from: Vector2) -> Vector2:
	var facing := _facing_vector()
	if not player or not is_instance_valid(player):
		return facing
	var target: Vector2 = player.global_position + player.velocity * aim_lead
	var want := (target - from).normalized()
	var diff := wrapf(want.angle() - facing.angle(), -PI, PI)
	var lim := deg_to_rad(aim_spread_deg)
	return Vector2.from_angle(facing.angle() + clampf(diff, -lim, lim))


## Взрыв по области в заданные моменты клипа
func _state_burst(blasts: Array) -> void:
	move_velocity = Vector2.ZERO
	if not player or not is_instance_valid(player):
		_exit_attack()
		_change_state(State.WANDER)
		return
	for i in blasts.size():
		var spec: Array = blasts[i]
		if not _fired.has(i) and state_time >= float(spec[0]) * _attack_windup_time:
			_fired[i] = true
			_stop_attack_telegraph()
			_blast(float(spec[1]), float(spec[2]))


func _burst_center(forward: float) -> Vector2:
	return global_position + _facing_vector() * forward


func _blast(radius: float, forward: float) -> void:
	var center := _burst_center(forward)
	var ring := ProjectileScript.new()
	ring.shooter = self
	var parent := get_parent() if get_parent() else get_tree().current_scene
	parent.add_child(ring)
	ring.global_position = center
	ring.start_ring(radius, burst_color)
	if shot_sound:
		_shot_audio.stream = shot_sound
		_shot_audio.volume_db = shot_volume_db + 3.0
		_shot_audio.pitch_scale = shot_pitch * 0.7
		_shot_audio.play()
	for hero in get_tree().get_nodes_in_group("player"):
		if not (hero is Node2D) or not is_instance_valid(hero):
			continue
		if (hero as Node2D).global_position.distance_to(center) > radius:
			continue
		var dmg := get_attack_damage()
		if hero.has_method("receive_attack"):
			hero.receive_attack({"damage": dmg, "source": ring})
		elif hero.has_method("take_damage"):
			hero.take_damage(dmg, ring)


func _fire(turn_deg: float, from_facing := false) -> void:
	var facing := _facing_vector()
	var dir: Vector2
	if from_facing:
		# Веер по кругу: поворот от направления взгляда (как ружьё на кадрах)
		dir = facing.rotated(deg_to_rad(turn_deg))
	else:
		# В цель, с поворотом (веер из нескольких снарядов в сторону героя)
		dir = _aim_direction(_muzzle_position(facing)).rotated(deg_to_rad(turn_deg))
	var from := _muzzle_position(dir)
	var p := ProjectileScript.new()
	p.shooter = self
	p.velocity = dir * projectile_speed
	p.damage = get_attack_damage()
	p.max_range = projectile_range
	p.length = projectile_length
	p.width = projectile_width
	p.core_color = projectile_core
	p.glow_color = projectile_glow
	p.global_position = from
	var parent := get_parent() if get_parent() else get_tree().current_scene
	parent.add_child(p)
	p.global_position = from
	_live.append(p)
	if shot_sound:
		_shot_audio.stream = shot_sound
		_shot_audio.volume_db = shot_volume_db
		_shot_audio.pitch_scale = shot_pitch * randf_range(0.94, 1.06)
		_shot_audio.play()


## Для парирования воина: правда, только когда наш снаряд долетит до героя
## не позже чем через lead_time. Пока стрелок целится — щит не поднимается
func is_about_to_strike(lead_time: float) -> bool:
	if is_dead:
		return false
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return false
	var soon := false
	# Взрыв по области: вот-вот грянет, а герой в круге
	if current_state == State.ATTACK:
		var blasts: Array = bursts.get(current_attack_anim, [])
		for i in blasts.size():
			if _fired.has(i):
				continue
			var spec: Array = blasts[i]
			var left := float(spec[0]) * _attack_windup_time - state_time
			if left <= lead_time and hero.global_position.distance_to(_burst_center(float(spec[2]))) <= float(spec[1]):
				soon = true
	var alive: Array = []
	for p in _live:
		if not is_instance_valid(p):
			continue
		alive.append(p)
		var v: Vector2 = p.velocity
		if v == Vector2.ZERO:
			continue
		var to_hero: Vector2 = hero.global_position - (p as Node2D).global_position
		var along := to_hero.dot(v.normalized())
		if along < -8.0:
			continue  # уже пролетел
		var miss := absf(to_hero.cross(v.normalized()))
		if miss <= 14.0 and along / v.length() <= lead_time:
			soon = true
	_live = alive
	return soon
