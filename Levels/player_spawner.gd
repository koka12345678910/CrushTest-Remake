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


func _process(delta: float) -> void:
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
