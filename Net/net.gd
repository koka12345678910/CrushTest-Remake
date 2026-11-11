extends Node
## Net.gd — сетевой кооп (автозагрузка).
##
## СХЕМА. Один игрок — хост (сервер у себя), до MAX_PLAYERS-1 подключаются к
## нему. Кто что решает:
##   * каждый — свой герой: движение, удары, заклинания мгновенно у себя, без
##     ожидания сети; попал ли по нему враг (увернулся на своём экране —
##     увернулся). 30 раз в секунду он рассылает снимок героя, у остальных на
##     этом месте стоит кукла (net_puppet.gd);
##   * хост — враги: ИИ, здоровье, смерть. У клиентов вместо врагов — копии
##     (enemy.gd в режиме net_replica): идут по снимкам хоста, а всё, что с ними
##     делает свой герой (урон, стойкость, отброс, корни...), уходит хосту.
##   * заклинания и снаряды: создавший рассылает «эхо» (echo) — у остальных
##     появляется такое же заклинание от имени куклы, но без урона: урон уже
##     засчитан у создавшего. Заклинания проверяют это через is_echo(caster).
##
## Транспорт сейчас — ENet (Godot из коробки): игра по IP, для отладки — две
## копии игры на одном компьютере (127.0.0.1). На этапе Steam сюда встанет
## SteamMultiplayerPeer (GodotSteam) — остальной код этого не заметит.
##
## Вне сети (одиночная игра) multiplayer_peer — OfflineMultiplayerPeer,
## is_online() = false, и ничего из этого не работает и не мешает.

signal peers_changed
## Для окна лобби: строка состояния
signal status_changed(text: String)
## Сеанс оборвался не по нашей воле (хост вышел, связь пропала)
signal session_ended(reason: String)
## Приняли приглашение друга в Steam — главное меню открывает окно коопа
signal invite_join_started

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
## Снимков своего героя в секунду
const SEND_HZ := 30.0
## Снимков врагов в секунду (хост → клиенты)
const ENEMY_HZ := 20.0
const MENU_SCENE := "res://Main_Menu/scenes/MainMenu.tscn"
const PuppetScript := preload("res://Net/net_puppet.gd")

## peer_id -> {"character": id героя, "slot": порядковый номер игрока (0 — хост)}
var peers := {}
## Свой герой на уровне (регистрирует player_spawner.gd)
var local_character: Node2D
var _spawner: Node
var _puppets := {}
var _send_left := 0.0
var _in_game := false
var _sprite_cache: AnimatedSprite2D


func _ready() -> void:
	# Пауза дерева (одиночная игра) не должна останавливать сеть
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_init_steam()


# ═════════════════ STEAM ═════════════════
# Игра через интернет: GodotSteam (addons/godotsteam, Steamworks). Трафик идёт
# по сети серверов Valve (Steam Datagram Relay) — без проброса портов, с
# хорошим маршрутом у всех. Хост создаёт лобби «только для друзей», друзья
# входят по приглашению из Steam (или «Присоединиться» в списке друзей), и
# поверх лобби встаёт SteamMultiplayerPeer — остальной код сети его не
# отличает от ENet.
#
# Плагина нет (или Steam не запущен) — Steam просто недоступен, остаётся игра
# по IP. Поэтому к Steam обращаемся только через Engine.get_singleton и
# ClassDB: прямое имя Steam в коде без плагина не разобралось бы.
#
# Пока у игры нет своей страницы в Steam — тестовый ID 480 (steam_appid.txt в
# корне проекта; Steam будет показывать «Spacewar»). Свой ID — сюда и туда.

const STEAM_APP_ID := 480
const STEAM_LOBBY_FRIENDS_ONLY := 1
const STEAM_RESULT_OK := 1
const STEAM_ENTER_SUCCESS := 1

## Steam запущен и плагин работает — можно играть через Steam
var steam_ok := false
var steam_status := ""
var _steam: Object
var _lobby_id := 0
## Лобби из приглашения, пока главное меню ещё не готово (запуск с
## +connect_lobby)
var _pending_lobby := 0


func _init_steam() -> void:
	if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		steam_status = tr("Плагин Steam не загружен — игра по IP")
		return
	_steam = Engine.get_singleton("Steam")
	var r = _steam.call("steamInitEx", STEAM_APP_ID, true)
	if not (r is Dictionary) or int(r.get("status", -1)) != 0:
		steam_status = tr("Steam не запущен — игра по IP")
		return
	steam_ok = true
	steam_status = tr("Steam: %s") % my_name()
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("join_requested", _on_join_requested)
	# Игру запустили из приглашения Steam: «+connect_lobby <id>»
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size():
		_pending_lobby = int(args[i + 1])


## Своё имя в Steam (пусто без Steam)
func my_name() -> String:
	return String(_steam.call("getPersonaName")) if _steam != null else ""


func in_steam_lobby() -> bool:
	return _lobby_id != 0


## Создать игру через Steam: лобби для друзей, хост — мы
func host_steam() -> void:
	if not steam_ok:
		return
	leave()
	status_changed.emit(tr("Создаём лобби Steam…"))
	_steam.call("createLobby", STEAM_LOBBY_FRIENDS_ONLY, MAX_PLAYERS)


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != STEAM_RESULT_OK:
		status_changed.emit(tr("Steam не смог создать лобби"))
		return
	_lobby_id = lobby_id
	_steam.call("setLobbyJoinable", lobby_id, true)
	_steam.call("setLobbyData", lobby_id, "game", "the_last_oath")
	var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = p.call("create_host", 0)
	if err != OK:
		status_changed.emit(tr("Steam не смог создать игру"))
		leave()
		return
	multiplayer.multiplayer_peer = p
	peers = {1: {"character": SaveManager.get_character_id(), "slot": 0, "name": my_name()}}
	peers_changed.emit()
	status_changed.emit(tr("Лобби создано. Пригласи друзей через Steam"))


## Окно приглашения друзей в оверлее Steam
func invite_friends() -> void:
	if steam_ok and _lobby_id != 0:
		_steam.call("activateGameOverlayInviteDialog", _lobby_id)


## Войти в лобби друга (по приглашению)
func join_lobby(lobby_id: int) -> void:
	if not steam_ok:
		return
	leave()
	status_changed.emit(tr("Подключение через Steam…"))
	_steam.call("joinLobby", lobby_id)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != STEAM_ENTER_SUCCESS:
		status_changed.emit(tr("Не удалось войти в лобби Steam"))
		return
	var owner := int(_steam.call("getLobbyOwner", lobby_id))
	# Хосту Steam тоже присылает «вошёл» в своё же лобби — ему делать нечего
	if owner == int(_steam.call("getSteamID")):
		return
	_lobby_id = lobby_id
	var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = p.call("create_client", owner, 0)
	if err != OK:
		status_changed.emit(tr("Не удалось подключиться к хосту Steam"))
		leave()
		return
	multiplayer.multiplayer_peer = p
	status_changed.emit(tr("Подключение к %s…") % String(_steam.call("getFriendPersonaName", owner)))


## Друг пригласил, и мы нажали «Присоединиться» (игра уже запущена).
## Играем своим героем из своего сейва; его нет — сначала «Новая игра»
func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	if not SaveManager.slot_exists(0):
		status_changed.emit(tr("Сначала начни путь («Новая игра»): в совместную игру каждый приходит со своим героем."))
		return
	if not SaveManager.is_loaded():
		SaveManager.load_slot(0)
	join_lobby(lobby_id)
	invite_join_started.emit()


## Главное меню готово: если игру запустили из приглашения — входим
func take_pending_invite() -> void:
	if _pending_lobby != 0:
		var id := _pending_lobby
		_pending_lobby = 0
		_on_join_requested(id, 0)


# ═════════════════ СОСТОЯНИЕ ═════════════════

func is_online() -> bool:
	var p := multiplayer.multiplayer_peer
	if p == null or p is OfflineMultiplayerPeer:
		return false
	return p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


## В сети и не хост: враги у нас — только копии
func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func in_game() -> bool:
	return _in_game


## Заклинание создано как эхо чужого (его заклинатель — кукла): только вид,
## без урона и прочих последствий — они уже случились у хозяина
func is_echo(caster) -> bool:
	return is_instance_valid(caster) and (caster as Node).is_in_group("net_puppet")


## Подпись игрока в лобби и над куклой: «Имя в Steam · Следопыт» (без
## Steam — «Игрок 2 · Следопыт»)
func describe(peer_id: int) -> String:
	var info: Dictionary = peers.get(peer_id, {})
	var hero := tr(String(Characters.display_name(String(info.get("character", Characters.FALLBACK)))))
	hero = hero.substr(0, 1) + hero.substr(1).to_lower()
	var who := String(info.get("name", ""))
	if who == "":
		who = tr("Игрок %d") % (int(info.get("slot", 0)) + 1)
	return who + "  ·  " + hero


# ═════════════════ ЛОББИ ═════════════════

## Создать игру. Свой сейв должен быть уже загружен (SaveManager.load_slot)
func host(port := DEFAULT_PORT) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		status_changed.emit(tr("Не удалось открыть порт %d — он занят?") % port)
		return err
	multiplayer.multiplayer_peer = p
	peers = {1: {"character": SaveManager.get_character_id(), "slot": 0, "name": my_name()}}
	peers_changed.emit()
	status_changed.emit(tr("Игра создана. Ждём игроков…"))
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address.strip_edges(), port)
	if err != OK:
		status_changed.emit(tr("Не удалось подключиться к %s") % address)
		return err
	multiplayer.multiplayer_peer = p
	status_changed.emit(tr("Подключение к %s…") % address)
	return OK


## Выйти из сеанса (или отменить ожидание) — тихо, без сигнала session_ended
func leave() -> void:
	_clear_puppets()
	peers.clear()
	_in_game = false
	local_character = null
	_spawner = null
	_enemies.clear()
	_pending_roster.clear()
	var p := multiplayer.multiplayer_peer
	if p != null and not (p is OfflineMultiplayerPeer):
		p.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _lobby_id != 0 and _steam != null:
		_steam.call("leaveLobby", _lobby_id)
	_lobby_id = 0
	peers_changed.emit()


## Хост: все уходят на уровень
func start_game(scene_path: String) -> void:
	if not is_host():
		return
	_start.rpc(scene_path)


@rpc("authority", "call_local", "reliable")
func _start(scene_path: String) -> void:
	_in_game = true
	_enemies.clear()
	_pending_roster.clear()
	SceneLoader.change_scene(scene_path)


func _on_connected() -> void:
	_register.rpc_id(1, SaveManager.get_character_id(), my_name())


func _on_connection_failed() -> void:
	leave()
	status_changed.emit(tr("Не удалось подключиться: хост не отвечает"))


func _on_peer_connected(_id: int) -> void:
	pass


## Клиент представился хосту: каким героем играет
@rpc("any_peer", "reliable")
func _register(character_id: String, player_name := "") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	peers[id] = {"character": character_id, "slot": _free_slot(), "name": player_name}
	_sync_peers.rpc(peers)
	# Опоздавший — сразу на тот же уровень
	if _in_game:
		_start.rpc_id(id, get_tree().current_scene.scene_file_path)


func _free_slot() -> int:
	var used := []
	for k in peers:
		used.append(int(peers[k]["slot"]))
	for s in MAX_PLAYERS:
		if not (s in used):
			return s
	return peers.size()


@rpc("authority", "call_local", "reliable")
func _sync_peers(all: Dictionary) -> void:
	peers = all
	peers_changed.emit()
	if not multiplayer.is_server():
		status_changed.emit(tr("Подключено. Ждём, когда хост начнёт"))
	_ensure_puppets()


func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	_remove_puppet(id)
	peers_changed.emit()
	if multiplayer.is_server():
		_sync_peers.rpc(peers)


func _on_server_disconnected() -> void:
	var was_in_game := _in_game
	leave()
	session_ended.emit(tr("Хост закрыл игру"))
	status_changed.emit(tr("Хост закрыл игру"))
	if was_in_game:
		SceneLoader.change_scene(MENU_SCENE)


# ═════════════════ УРОВЕНЬ ═════════════════

## player_spawner.gd: свой герой появился. С этого момента идёт рассылка
## снимков, для остальных игроков на уровне встают куклы, а враги становятся
## общими (хост раздаёт их список, у клиента свои враги заменяются копиями)
func register_local(character: Node2D, spawner: Node) -> void:
	local_character = character
	_spawner = spawner
	_sprite_cache = null
	if not is_online():
		return
	_in_game = true
	_ensure_puppets()
	if is_host():
		_scan_enemies()
	else:
		_drop_local_enemies()
		_request_roster.rpc_id(1)
		_apply_pending_roster()


func _ensure_puppets() -> void:
	if not _in_game or not is_instance_valid(_spawner):
		return
	for id in peers:
		if int(id) == my_id():
			continue
		if _puppets.has(id) and is_instance_valid(_puppets[id]):
			continue
		var p: Node2D = PuppetScript.new()
		p.setup(int(id), String(peers[id]["character"]), describe(int(id)))
		_puppets[id] = p
		_spawner.add_puppet(p, int(peers[id]["slot"]))
	for id in _puppets.keys():
		if not peers.has(id):
			_remove_puppet(id)


func _remove_puppet(id: int) -> void:
	if _puppets.has(id):
		if is_instance_valid(_puppets[id]):
			_puppets[id].queue_free()
		_puppets.erase(id)


func _clear_puppets() -> void:
	for id in _puppets.keys():
		_remove_puppet(id)


func puppet_of(peer_id: int) -> Node2D:
	var p = _puppets.get(peer_id)
	return p if p != null and is_instance_valid(p) else null


## Смещение точки появления по номеру игрока, чтобы не стоять друг в друге
func spawn_offset(slot: int) -> Vector2:
	@warning_ignore("integer_division")
	var row := slot / 2
	return Vector2((slot % 2) * 2 - 1, row) * Vector2(22.0, 16.0) if slot > 0 else Vector2.ZERO


## Инвентарь, карточка лута: одному — пауза всего мира; в сети мир не встаёт
## (у других он идёт дальше), замирает только свой герой
func pause_world(on: bool) -> void:
	if not is_online():
		get_tree().paused = on
		return
	if is_instance_valid(local_character) and "is_in_shop" in local_character:
		local_character.is_in_shop = on


# ═════════════════ СНИМКИ СВОЕГО ГЕРОЯ ═════════════════

func _physics_process(delta: float) -> void:
	if not _in_game or not is_online():
		return
	if is_instance_valid(local_character):
		_send_left -= delta
		if _send_left <= 0.0:
			_send_left = maxf(_send_left + 1.0 / SEND_HZ, 0.0)
			var s := _snapshot()
			if not s.is_empty():
				_state.rpc(s)
	_enemy_tick(delta)
	_weather_tick(delta)
	_death_tick(delta)


## [время отправки мс, позиция, анимация, кадр, отражение, смещение спрайта,
##  масштаб спрайта, поворот, наклон, цвет, масштаб героя, флаги (атакует,
##  перекат, уклон, мёртв), скорость уклона, скорость]
func _snapshot() -> Array:
	if not is_instance_valid(_sprite_cache):
		_sprite_cache = PuppetScript.find_sprite(local_character)
	var sp := _sprite_cache
	if sp == null:
		return []
	var c := local_character
	var flags := 0
	if c.get("is_attacking") == true:
		flags |= 1
	if c.get("is_rolling") == true:
		flags |= 2
	if c.get("is_dodging") == true:
		flags |= 4
	if c.has_method("is_dead") and c.is_dead():
		flags |= 8
	var dv = c.get("dodge_velocity")
	# Доля здоровья — полоска над куклой и выбор цели лекарем (Сольвейг)
	var hp := 1.0
	var mh = c.get("max_health")
	var h = c.get("health")
	if (mh is float or mh is int) and (h is float or h is int) and float(mh) > 0.0:
		hp = clampf(float(h) / float(mh), 0.0, 1.0)
	return [Time.get_ticks_msec(), c.global_position, String(sp.animation), sp.frame,
			sp.flip_h, sp.position, sp.scale, sp.rotation, sp.skew,
			sp.modulate * sp.self_modulate, c.scale, flags,
			dv if dv is Vector2 else Vector2.ZERO, (c as CharacterBody2D).velocity if c is CharacterBody2D else Vector2.ZERO,
			hp]


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _state(s: Array) -> void:
	var p := puppet_of(multiplayer.get_remote_sender_id())
	if p != null:
		p.push(s)


# ═════════════════ ВРАГИ ═════════════════
# У хоста — настоящие враги, у каждого свой номер (meta "net_id"). Клиент на
# входе в уровень убирает своих врагов (их расставил случайный спавнер, у
# хоста они другие) и получает список хоста — создаёт по нему копии.

## net_id -> враг (у хоста — настоящий, у клиента — копия)
var _enemies := {}
var _next_enemy_id := 1
var _scan_left := 0.0
var _enemy_send_left := 0.0
## Список пришёл раньше, чем клиент загрузил уровень
var _pending_roster: Array = []


static func is_net_enemy(n: Node) -> bool:
	return n is Node2D and n.is_in_group("enemy") and n.has_method("apply_root") \
			and n.scene_file_path != "" and "net_replica" in n


func enemy_id(e) -> int:
	return int(e.get_meta("net_id", 0)) if is_instance_valid(e) else 0


func enemy_by_id(id: int) -> Node2D:
	var e = _enemies.get(id)
	return e if e != null and is_instance_valid(e) else null


func _enemy_tick(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = 0.5
		if is_host():
			_scan_enemies()
		elif is_instance_valid(local_character):
			_drop_local_enemies()
	if not is_host():
		return
	_enemy_send_left -= delta
	if _enemy_send_left > 0.0:
		return
	_enemy_send_left = maxf(_enemy_send_left + 1.0 / ENEMY_HZ, 0.0)
	var batch: Array = [Time.get_ticks_msec()]
	for id in _enemies:
		var e := enemy_by_id(id)
		if e != null:
			batch.append(e.net_snapshot(id))
	if batch.size() > 1:
		_enemy_states.rpc(batch)


## Хост: новым врагам — номера, клиентам — их список
func _scan_enemies() -> void:
	if get_tree().current_scene == null:
		return
	var fresh := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_net_enemy(e) or e.has_meta("net_id") or e.is_dead:
			continue
		var id := _next_enemy_id
		_next_enemy_id += 1
		e.set_meta("net_id", id)
		_enemies[id] = e
		e.tree_exiting.connect(_on_enemy_gone.bind(id))
		fresh.append(_roster_entry(id, e))
	if not fresh.is_empty():
		_enemy_spawn.rpc(fresh)


func _roster_entry(id: int, e: Node2D) -> Array:
	var scene := get_tree().current_scene
	return [id, e.scene_file_path, String(scene.get_path_to(e.get_parent())), e.global_position]


func _on_enemy_gone(id: int) -> void:
	_enemies.erase(id)
	if is_host():
		_enemy_despawn.rpc(id)


@rpc("any_peer", "reliable")
func _request_roster() -> void:
	if not multiplayer.is_server():
		return
	_scan_enemies()
	var all := []
	for id in _enemies:
		var e := enemy_by_id(id)
		if e != null and not e.is_dead:
			all.append(_roster_entry(id, e))
	_enemy_spawn.rpc_id(multiplayer.get_remote_sender_id(), all)


## Клиент: свои (не копии) враги на уровне не нужны — их место займут копии
func _drop_local_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_net_enemy(e) and not e.net_replica:
			e.remove_from_group("enemy")
			e.queue_free()


@rpc("authority", "call_remote", "reliable")
func _enemy_spawn(list: Array) -> void:
	_pending_roster.append_array(list)
	_apply_pending_roster()


func _apply_pending_roster() -> void:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(local_character):
		return
	for entry in _pending_roster:
		var id := int(entry[0])
		if enemy_by_id(id) != null:
			continue
		var packed := load(String(entry[1])) as PackedScene
		if packed == null:
			continue
		var e := packed.instantiate()
		e.net_replica = true
		e.set_meta("net_id", id)
		var parent := scene.get_node_or_null(NodePath(String(entry[2])))
		if parent == null:
			parent = scene
		parent.add_child(e)
		e.global_position = entry[3]
		_enemies[id] = e
	_pending_roster.clear()


@rpc("authority", "call_remote", "reliable")
func _enemy_despawn(id: int) -> void:
	# Враг мог пропасть у хоста раньше, чем мы успели загрузить уровень и
	# создать его копию по списку — тогда и создавать уже нечего
	_pending_roster = _pending_roster.filter(func(entry): return int(entry[0]) != id)
	var e := enemy_by_id(id)
	_enemies.erase(id)
	if e != null:
		e.net_despawn()


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _enemy_states(batch: Array) -> void:
	var t := float(batch[0])
	for i in range(1, batch.size()):
		var s: Array = batch[i]
		var e := enemy_by_id(int(s[0]))
		if e != null:
			e.net_push(t, s)


## Хост: звук, вспышка, взмах врага — копиям у клиентов (enemy.gd::_net_ev)
func enemy_event(e: Node2D, kind: String, arg = null) -> void:
	if not is_host():
		return
	var id := enemy_id(e)
	if id != 0:
		_enemy_event.rpc(id, kind, _enc(arg))


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _enemy_event(id: int, kind: String, arg) -> void:
	var e := enemy_by_id(id)
	if e != null:
		e.net_event(kind, _dec(arg, 0))


## Клиент: свой герой что-то сделал с копией врага — настоящему врагу у хоста.
## kind: dmg [урон, мимо блока, стихия], posture [сила], bleed [урон],
## slow [%, с], root [с], push [скорость], stun [откуда], kill [], break []
func enemy_act(e: Node2D, kind: String, args: Array) -> void:
	var id := enemy_id(e)
	if id == 0 or not is_online():
		return
	_enemy_act.rpc_id(1, id, kind, args)


@rpc("any_peer", "reliable")
func _enemy_act(id: int, kind: String, args: Array) -> void:
	if not multiplayer.is_server():
		return
	var e := enemy_by_id(id)
	var who := puppet_of(multiplayer.get_remote_sender_id())
	if e == null or e.is_dead:
		return
	match kind:
		"dmg":
			if who != null:
				who.set_meta("hit_element", String(args[2]) if args.size() > 2 else "")
			e.take_damage(int(args[0]), who, bool(args[1]))
			if who != null:
				who.set_meta("hit_element", "")
		"posture":
			if who != null and e.player == null:
				e.player = who
			e.take_posture_damage(float(args[0]))
		"bleed":
			e.take_bleed_damage(int(args[0]), who)
		"slow":
			e.apply_slow(float(args[0]), float(args[1]))
		"root":
			e.apply_root(float(args[0]))
		"push":
			e.knockback_velocity = args[0]
		"stun":
			e.lightning_stun(args[0])
		"kill":
			e.execute_kill()
		"break":
			e._posture_break()
		"add_posture":
			# Благословение Тора: концентрация напрямую, без стаггера
			# (knight_magic.gd::_add_posture)
			if not e.is_posture_broken:
				e.posture = minf(e.posture + float(args[0]), e.max_posture)
				e.posture_regen_timer = 0.0
				e.posture_bar.visible = true
				e.posture_bar.value = e.posture
				if e.posture >= e.max_posture:
					e._posture_break()


# ═════════════════ УДАРЫ ПО ИГРОКАМ И ОТВЕТЫ ═════════════════

## Хост: враг ударил куклу — удар уходит её хозяину, решает его герой
func hit_player(peer_id: int, attack_data: Dictionary) -> void:
	var src = attack_data.get("source")
	_hit_me.rpc_id(peer_id, enemy_id(src), float(attack_data.get("damage", 0)))


@rpc("authority", "call_remote", "reliable")
func _hit_me(eid: int, damage: float) -> void:
	if not is_instance_valid(local_character) or not local_character.has_method("receive_attack"):
		return
	local_character.receive_attack({"damage": damage, "source": enemy_by_id(eid)})


const OWNER_CALLS := ["receive_parry", "add_skill_points", "on_enemy_killed", "on_weapon_hit",
		"on_execution_of", "heal", "clear_negative_effects", "apply_ally_shield", "net_revive"]

## С куклой что-то сделали (враг, союзник) — то же самое у её хозяина с его
## настоящим героем. element — стихия удара мага (meta "hit_element")
func to_owner(peer_id: int, method: String, args: Array, element := "") -> void:
	if not is_online() or not (method in OWNER_CALLS):
		return
	var enc := []
	for a in args:
		enc.append(_enc(a))
	if peer_id == my_id():
		_owner_call(method, enc, element)
	else:
		_owner_call.rpc_id(peer_id, method, enc, element)


@rpc("any_peer", "call_remote", "reliable")
func _owner_call(method: String, enc: Array, element: String) -> void:
	if not (method in OWNER_CALLS) or not is_instance_valid(local_character):
		return
	var args := []
	for a in enc:
		args.append(_dec(a, 0))
	# Союзная помощь (Сольвейг): не методы героя, а общее для всех героев
	match method:
		"apply_ally_shield":
			preload("res://Net/ally_shield.gd").give(local_character, float(args[0]), float(args[1]))
			return
		"net_revive":
			_revive_by_ally(float(args[0]))
			return
	if not local_character.has_method(method):
		return
	if element != "":
		local_character.set_meta("hit_element", element)
	local_character.callv(method, args)
	if element != "":
		local_character.set_meta("hit_element", "")
	# Одр рыцаря за убийство и добивание: у себя враг зовёт magic героя сам
	# (enemy.gd), а за куклу — некому, поэтому здесь
	var magic = local_character.get("magic")
	if magic != null:
		if method == "on_enemy_killed" and magic.has_method("on_kill"):
			magic.on_kill(args[0] if not args.is_empty() else null)
		elif method == "on_execution_of" and magic.has_method("on_execution"):
			magic.on_execution()


# ═════════════════ МИР ═════════════════
# Предметы уровня (ящики, бочки) у всех стоят по одним путям в сцене — по пути
# их и находим. Погоду и время суток решает хост, клиенты повторяют.

## Что-то случилось с предметом уровня у нас — то же у остальных.
## kind: break — ящик разбит (breakable_prop.gd::net_break)
func world_event(kind: String, node: Node) -> void:
	if not _in_game or not is_online() or get_tree().current_scene == null:
		return
	_world_event.rpc(kind, String(get_tree().current_scene.get_path_to(node)))


@rpc("any_peer", "call_remote", "reliable")
func _world_event(kind: String, path: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var n := scene.get_node_or_null(NodePath(path))
	if n == null:
		return
	match kind:
		"break":
			if n.has_method("net_break"):
				n.net_break()


const WEATHER_SYNC_EVERY := 3.0
var _weather_left := 0.0

## Хост: погода сменилась (Weather.set_weather) — клиентам сразу
func weather_changed(kind: int) -> void:
	if is_host() and _in_game:
		_weather_sync.rpc(Weather.hour, kind)


func _weather_tick(delta: float) -> void:
	if not is_host():
		return
	_weather_left -= delta
	if _weather_left > 0.0:
		return
	_weather_left = WEATHER_SYNC_EVERY
	_weather_sync.rpc(Weather.hour, int(Weather.weather))


@rpc("authority", "call_remote", "reliable")
func _weather_sync(hour: float, kind: int) -> void:
	Weather.net_sync(hour, kind)


# ═════════════════ СМЕРТЬ И ВОЗРОЖДЕНИЕ ═════════════════
# В коопе павший герой встаёт сам через RESPAWN_DELAY секунд — у своего
# последнего костра на этом уровне или на старте, с полным здоровьем.
# Остальные тем временем дерутся дальше; кукла павшего лежит, враги её не
# трогают (net_puppet.gd: мёртвая кукла уходит из группы "player")

const RESPAWN_DELAY := 10.0
const BonfireScript := preload("res://Levels/bonfire/bonfire.gd")
var _dead_time := -1.0


func _death_tick(delta: float) -> void:
	if not is_instance_valid(local_character):
		return
	var dead: bool = local_character.has_method("is_dead") and local_character.is_dead()
	if not dead:
		_dead_time = -1.0
		return
	if _dead_time < 0.0:
		_dead_time = 0.0
		_banner("ТЫ ПАЛ")
	_dead_time += delta
	if _dead_time >= RESPAWN_DELAY:
		_dead_time = -1.0
		_respawn_local()


func _respawn_local() -> void:
	var at: Vector2 = local_character.global_position
	var b = null
	if SaveManager.last_bonfire != "":
		b = BonfireScript.find(get_tree(), SaveManager.last_bonfire)
	if b != null:
		at = b.rest_position()
	elif is_instance_valid(_spawner):
		var slot: int = int(peers.get(my_id(), {}).get("slot", 0))
		at = (_spawner as Node2D).global_position + spawn_offset(slot)
	if local_character.has_method("net_respawn"):
		local_character.net_respawn(at)
	else:
		local_character.global_position = at
		BonfireScript.restore_hero(local_character)
	_banner("ВОЗРОЖДЕНИЕ")


## Союзник (Сольвейг) поднял павшего: встаёт на месте, с долей здоровья
## hp_frac, таймер возрождения у костра отменяется
func _revive_by_ally(hp_frac: float) -> void:
	if not is_instance_valid(local_character) or not local_character.has_method("is_dead") \
			or not local_character.is_dead():
		return
	_dead_time = -1.0
	var at: Vector2 = local_character.global_position
	if local_character.has_method("net_respawn"):
		local_character.net_respawn(at)
	else:
		BonfireScript.restore_hero(local_character)
	# Поднятый — не с полным здоровьем, а с тем, что дал союзник
	var mh = local_character.get("max_health")
	if mh != null:
		var target := float(mh) * clampf(hp_frac, 0.05, 1.0)
		local_character.health = target
		var bar = local_character.get("health_bar")
		if bar != null:
			bar.current_hp = target
	_banner("ТЕБЯ ПОДНЯЛИ")


func _banner(text: String) -> void:
	var ui = load("res://Levels/bonfire/bonfire_ui.gd").of(get_tree())
	if ui and ui.has_method("show_banner"):
		ui.show_banner(text)


# ═════════════════ ЭХО ЗАКЛИНАНИЙ ═════════════════
# Свой герой создал узел заклинания или снаряда (уже настроенный и в дереве) —
# у остальных создаётся такой же: тот же скрипт, тот же вызов с теми же
# параметрами, только заклинатель — кукла. Узлы-ссылки в параметрах
# (заклинатель, враг-цель) едут как метки и превращаются обратно у получателя.

## node — созданный узел; method/args — как его запускали (setup/launch);
## props — свойства, выставленные до запуска; under_caster — узел был
## ребёнком героя (а не уровня)
func echo(node: Node, method: String, args: Array, props := {}, under_caster := false) -> void:
	if not _in_game or not is_online() or node == null or node.get_script() == null:
		return
	var enc := []
	for a in args:
		enc.append(_enc(a))
	var penc := {}
	for k in props:
		penc[k] = _enc(props[k])
	_echo.rpc(String(node.get_script().resource_path), method, enc, penc, under_caster)


## Эхо эффекта-сцены (вспышки ударов Фенрира/Берсерка, огненное кольцо
## рыцаря): та же сцена в том же месте и повороте. props — её поля; пустые
## (null) не шлём
func echo_scene(node: Node2D, props := {}) -> void:
	if not _in_game or not is_online() or node == null or node.scene_file_path == "":
		return
	var p := {}
	for k in props:
		if props[k] != null:
			p[k] = _enc(props[k])
	_echo_scene.rpc(node.scene_file_path, node.global_position, node.rotation, p)


@rpc("any_peer", "call_remote", "reliable", 3)
func _echo_scene(path: String, pos: Vector2, rot: float, p: Dictionary) -> void:
	var scene := get_tree().current_scene
	var packed := load(path) as PackedScene
	if scene == null or packed == null:
		return
	var n := packed.instantiate()
	n.set_meta("net_echo", true)
	for k in p:
		n.set(k, _dec(p[k], multiplayer.get_remote_sender_id()))
	scene.add_child(n)
	if n is Node2D:
		(n as Node2D).global_position = pos
		(n as Node2D).rotation = rot


## Эхо статического эффекта (функция без узла): script_path.func(args)
func echo_static(script_path: String, fn: String, args: Array) -> void:
	if not _in_game or not is_online():
		return
	var enc := []
	for a in args:
		enc.append(_enc(a))
	_echo_static.rpc(script_path, fn, enc)


@rpc("any_peer", "call_remote", "reliable", 3)
func _echo(script_path: String, method: String, enc: Array, penc: Dictionary, under_caster: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var caster := puppet_of(sender)
	var scene := get_tree().current_scene
	if caster == null or scene == null:
		return
	var script := load(script_path) as Script
	if script == null:
		return
	var node: Node = script.new()
	# Метка эха — для узлов без заклинателя в параметрах (след ледяного шага)
	node.set_meta("net_echo", true)
	for k in penc:
		node.set(k, _dec(penc[k], sender))
	var args := []
	for a in enc:
		args.append(_dec(a, sender))
	var parent: Node = caster if under_caster else scene
	if method == "launch":
		parent.add_child(node)
		node.callv(method, args)
	else:
		if method != "":
			node.callv(method, args)
		parent.add_child(node)


@rpc("any_peer", "call_remote", "reliable", 3)
func _echo_static(script_path: String, fn: String, enc: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if puppet_of(sender) == null:
		return
	var script := load(script_path) as Script
	if script == null:
		return
	var args := []
	for a in enc:
		args.append(_dec(a, sender))
	script.callv(fn, args)


## Узел — в метку: свой герой → {"__c": 1}, враг → {"__e": номер}, дерево →
## {"__t": 1}; остальное (числа, векторы, цвета, строки) — как есть
func _enc(v):
	if v is Node:
		if v == local_character:
			return {"__c": 1}
		var id := enemy_id(v)
		if id != 0:
			return {"__e": id}
		return null
	if v is SceneTree:
		return {"__t": 1}
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _enc(v[k])
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(_enc(x))
		return a
	return v


## Метка — обратно в узел у получателя: заклинатель — кукла отправителя
func _dec(v, sender: int):
	if v is Dictionary:
		if v.has("__c"):
			return puppet_of(sender) if sender != 0 else null
		if v.has("__e"):
			return enemy_by_id(int(v["__e"]))
		if v.has("__t"):
			return get_tree()
		var d := {}
		for k in v:
			d[k] = _dec(v[k], sender)
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(_dec(x, sender))
		return a
	return v
