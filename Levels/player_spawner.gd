extends Marker2D
## player_spawner.gd — создаёт персонажа из текущего сейва в точке маркера.
##
## Раньше игрок стоял в level_01.tscn готовым инстансом (нода Player2), поэтому
## сменить героя было невозможно в принципе. Теперь в сцене только эта точка, а
## кого именно спавнить — решает сейв (SaveManager.get_character_id()).
##
## Маркер должен быть ПРЯМЫМ ребёнком уровня: персонаж добавляется к тому же
## родителю и получает position маркера напрямую. Кладём в родителя, а не в сам
## маркер, чтобы персонаж не таскал за собой его трансформ.

## Тот же слой, что стоял у Player2 в сцене — иначе игрок уезжает под тайлы
@export var character_z_index := 1

## Границы камеры персонажа в мировых пикселях. Пустой прямоугольник —
## не трогать (как в level_01); на картах с краем-туманом (level_graveyard)
## не даёт камере уехать за пределы нарисованной карты
@export var camera_limits := Rect2i()

## Мягкое свечение вокруг персонажа, чтобы его было видно на тёмных картах.
## 0 — выключено (как в level_01)
@export var player_glow_energy := 0.0
@export var player_glow_color := Color(0.78, 0.84, 0.95)
## Радиус свечения в пикселях мира
@export var player_glow_radius := 95.0

## Тень персонажа от огня (костры, камин, лампы). У ног ставится маленький
## LightOccluder2D; тень от него отбрасывают только источники, у которых
## включены тени и в shadow_item_cull_mask есть SHADOW_OCCLUDER_BIT.
##
## В виде сверху такой свет, стоящий НИЖЕ персонажа, положил бы тень прямо на
## его же спрайт (тело "над" ногами — как раз за оклюдером). Поэтому тело
## переезжает на свой слой света BODY_LIGHT_BIT (без бита 1): огонь с тенью
## светит только на землю и предметы, а тело освещает его "копия" без тени
## (у костра — BodyLight). Все прочие источники (луна, облака, свечение игрока,
## свет комнаты, заклинания) получают BODY_LIGHT_BIT автоматически — на них
## ничего не меняется
@export var player_shadow := false
## Половина ширины и высоты овала-оклюдера у ног, px мира
@export var shadow_radius := Vector2(6.0, 2.5)

const BODY_LIGHT_BIT := 8
const SHADOW_OCCLUDER_BIT := 16

## Как часто скидывать прогресс на диск. Пишем редко: сохранение — это запись
## файла, а дёргать её каждый кадр незачем
@export var autosave_interval := 30.0

var character: Node2D = null
var _autosave_timer := 0.0


func _ready() -> void:
	var id := SaveManager.get_character_id()
	var scene := Characters.get_scene(id)
	if scene == null:
		push_error("[PlayerSpawner] Не удалось загрузить сцену персонажа '%s'" % id)
		return

	character = scene.instantiate()
	# position/z_index задаём ДО добавления в дерево — работают и на "оторванной"
	# ноде, зато камера персонажа сразу стартует в нужной точке, без рывка
	character.position = position
	character.z_index = character_z_index
	_add_glow()
	if player_shadow:
		_setup_shadow()

	# ОБЯЗАТЕЛЬНО call_deferred: наш _ready() вызывается, пока уровень ещё
	# расставляет своих детей, и обычный add_child в этот момент отваливается с
	# "Parent node is busy setting up children" — персонаж молча оставался
	# висеть вне дерева, то есть игрока в игре просто не было
	get_parent().add_child.call_deferred(character)
	# Отложенные вызовы выполняются в порядке очереди, поэтому прогресс
	# гарантированно переливается уже после добавления в дерево — когда у
	# персонажа отработал _ready и его поля существуют
	_apply_progress.call_deferred()


func _apply_progress() -> void:
	SaveManager.apply_to(character)
	_apply_camera_limits()


func _add_glow() -> void:
	if player_glow_energy <= 0.0:
		return
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var light := PointLight2D.new()
	light.name = "PlayerGlow"
	# Холодный "лунный" ореол — в доме гаснет на теле героя, там его
	# освещает огонь (Levels/house_interior.gd)
	light.add_to_group("outdoor_light")
	light.texture = tex
	light.texture_scale = player_glow_radius * 2.0 / 128.0
	light.color = player_glow_color
	light.energy = player_glow_energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	character.add_child(light)


func _setup_shadow() -> void:
	_move_body_to_own_light_layer(character)

	var occ := LightOccluder2D.new()
	occ.name = "ShadowOccluder"
	var poly := OccluderPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * shadow_radius.x, sin(a) * shadow_radius.y))
	poly.polygon = pts
	occ.occluder = poly
	occ.position = Vector2(0, _feet_y())
	occ.occluder_light_mask = SHADOW_OCCLUDER_BIT
	character.add_child(occ)

	# Источники, которые уже на уровне, и те, что появятся позже (свечение
	# игрока, облака луны, свет заклинаний)
	for l in get_tree().root.find_children("*", "Light2D", true, false):
		_light_body_too(l)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Light2D:
		_light_body_too(n)


## Обычный источник светит и на тело персонажа; "теневой" огонь — нет (тело
## от него освещает отдельная копия без тени)
func _light_body_too(l: Light2D) -> void:
	if l.shadow_enabled and (l.shadow_item_cull_mask & SHADOW_OCCLUDER_BIT) != 0:
		return
	if (l.range_item_cull_mask & 1) != 0:
		l.range_item_cull_mask |= BODY_LIGHT_BIT


func _move_body_to_own_light_layer(n: Node) -> void:
	for ch in n.get_children():
		if ch is CanvasLayer:
			continue        # интерфейс светом не освещается
		if ch is CanvasItem and ((ch as CanvasItem).light_mask & 1) != 0:
			var ci := ch as CanvasItem
			ci.light_mask = (ci.light_mask & ~1) | BODY_LIGHT_BIT
		_move_body_to_own_light_layer(ch)


## Низ коллизии персонажа — там его ноги
func _feet_y() -> float:
	for ch in character.get_children():
		if ch is CollisionShape2D and (ch as CollisionShape2D).shape:
			var cs := ch as CollisionShape2D
			var sh := cs.shape
			var half := 0.0
			if sh is CapsuleShape2D:
				half = (sh as CapsuleShape2D).height * 0.5
			elif sh is RectangleShape2D:
				half = (sh as RectangleShape2D).size.y * 0.5
			elif sh is CircleShape2D:
				half = (sh as CircleShape2D).radius
			return cs.position.y + half * cs.scale.y
	return 10.0


func _apply_camera_limits() -> void:
	if camera_limits.size == Vector2i.ZERO or not is_instance_valid(character):
		return
	var cam := character.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = camera_limits.position.x
	cam.limit_top = camera_limits.position.y
	cam.limit_right = camera_limits.end.x
	cam.limit_bottom = camera_limits.end.y


func _process(delta: float) -> void:
	# Центр "окна" прозрачности для всего, что перекрывает персонажа
	# (Shaders/occlusion_fade.gdshaderinc) — до проверки сейва, окно нужно всегда
	if is_instance_valid(character) and character.is_inside_tree():
		RenderingServer.global_shader_parameter_set("occlusion_player_pos", character.global_position)
	if not SaveManager.is_loaded():
		return
	SaveManager.playtime += delta
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		SaveManager.capture_from(character)


# Выход в меню, перезапуск сцены, закрытие игры — везде это последний момент,
# когда персонаж ещё жив и с него можно снять прогресс
func _exit_tree() -> void:
	SaveManager.capture_from(character)
	# Уровень успели закрыть до того, как сработал отложенный add_child — тогда
	# персонаж так и остался вне дерева, и удалить его больше некому
	if is_instance_valid(character) and character.get_parent() == null:
		character.queue_free()
