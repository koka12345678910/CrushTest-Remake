extends Control
## CoopPanel.gd — окно «Совместная игра» поверх главного меню (лобби коопа,
## Net/net.gd). Тот же вид, что у ConfirmDialog.gd: тёмная плашка с каймой,
## только крупнее — это целый экран лобби.
##
## Каждый приходит со своим героем из своего сейва (слот 0): без сейва —
## сначала «Новая игра».
##
## Всё через Steam, без кодов и адресов:
##   * хост жмёт «Пригласить друга» — лобби создаётся само, открывается
##     оверлей Steam со списком друзей. Оверлей не открылся (игра запущена не
##     через Steam) — прямо в окне появляется свой список друзей в сети;
##   * друг принимает приглашение в Steam (или «Присоединиться» в списке
##     друзей) — игра сама откроет это окно и подключится;
##   * в окне — места игроков с пингом; хост жмёт «Начать».
## По IP (ENet) — только в отладочной сборке или без Steam: локальная сеть,
## две копии на одном компьютере, Radmin VPN / ZeroTier.

signal closed

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")
const SLOT := 0
const WIDTH := 1040.0

var scene_path := ""

var _panel: PanelContainer
var _audio: AudioStreamPlayer
var _closing := false
var _hero_lbl: Label
var _steam_lbl: Label
var _status: Label
var _slots: Array[Label] = []
var _btn_invite: Button
var _btn_start: Button
var _btn_back: Button
var _friends_box: VBoxContainer
var _friends_list: VBoxContainer
var _ip_box: VBoxContainer
var _addr: LineEdit
var _btn_host: Button
var _btn_join: Button
var _has_save := false
var _me_line := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.make_theme()
	Style.make_dim(self, 0.7)
	_audio = Style.ui_player(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	var sb := Style.panel_box(6)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 28
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 64)
	m.add_theme_constant_override("margin_top", 44)
	m.add_theme_constant_override("margin_bottom", 44)
	_panel.add_child(m)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(WIDTH, 0)
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)

	var t := Style.label("СОВМЕСТНАЯ ИГРА", 42, Style.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_line(0.35))

	_hero_lbl = _wrap_label(26, Style.TEXT)
	v.add_child(_hero_lbl)
	_steam_lbl = Style.label(Net.steam_status, 20, Style.TEXT_DIM, true)
	_steam_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_steam_lbl)

	# Главная кнопка: лобби + оверлей Steam
	_btn_invite = _button(_row(v), "ПРИГЛАСИТЬ ДРУГА", _on_invite, Vector2(520, 82), 32)

	# Свой список друзей — если оверлей Steam не открылся
	_friends_box = VBoxContainer.new()
	_friends_box.add_theme_constant_override("separation", 10)
	_friends_box.visible = false
	v.add_child(_friends_box)
	var fl := _wrap_label(21, Style.TEXT_DIM)
	fl.text = tr("Оверлей Steam не открылся — выбери друга здесь, приглашение придёт ему в Steam:")
	_friends_box.add_child(fl)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_friends_box.add_child(scroll)
	_friends_list = VBoxContainer.new()
	_friends_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_friends_list)

	# Места игроков
	v.add_child(_line(0.2))
	var pl := Style.label("ИГРОКИ", 22, Style.TEXT_DIM, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pl)
	for i in Net.MAX_PLAYERS:
		var s := Style.label("", 28, Style.TEXT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.custom_minimum_size = Vector2(WIDTH, 40)
		v.add_child(s)
		_slots.append(s)

	_status = _wrap_label(22, Style.TEXT_DIM)
	_status.custom_minimum_size.y = 34
	v.add_child(_status)

	var brow := _row(v)
	_btn_back = _button(brow, "НАЗАД", _close, Vector2(320, 68), 26)
	_btn_start = _button(brow, "НАЧАТЬ", _on_start, Vector2(320, 68), 26)

	# По IP — отладка и запасной путь без Steam
	var ip_box := VBoxContainer.new()
	_ip_box = ip_box
	ip_box.add_theme_constant_override("separation", 10)
	ip_box.visible = OS.is_debug_build() or not Net.steam_ok
	v.add_child(ip_box)
	ip_box.add_child(_line(0.15))
	var ip_lbl := Style.label("ПО IP (ЛОКАЛЬНАЯ СЕТЬ, RADMIN VPN)", 17, Style.TEXT_DIM, true)
	ip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_box.add_child(ip_lbl)
	var row := _row(ip_box)
	_btn_host = _button(row, "СОЗДАТЬ ИГРУ", _on_host, Vector2(220, 46), 18)
	_addr = LineEdit.new()
	_addr.text = "127.0.0.1"
	_addr.custom_minimum_size = Vector2(260, 46)
	_addr.add_theme_font_size_override("font_size", 19)
	_addr.text_submitted.connect(func(_s: String): _on_join())
	row.add_child(_addr)
	_btn_join = _button(row, "ПОДКЛЮЧИТЬСЯ", _on_join, Vector2(220, 46), 18)

	Net.peers_changed.connect(_refresh)
	Net.pings_changed.connect(_refresh)
	Net.status_changed.connect(_on_status)
	Net.invite_fallback.connect(_show_friends)
	_check_save()
	# Вернулись в меню после обрыва — скажем, что случилось
	var notice := Net.take_notice()
	if notice != "":
		_status.text = notice
	elif Net.steam_ok and _has_save and not Net.is_connecting():
		_status.text = tr("Пригласи друга — когда он примет приглашение в Steam, он появится в списке")
	_refresh()
	_first_focus().call_deferred("grab_focus")
	Style.play_open(_audio)

	modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).from(Vector2(0.96, 0.96))\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _line(alpha: float) -> Control:
	var line := Style.FadeLine.new()
	line.color = Color(Style.GOLD, alpha)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _wrap_label(font_size: int, color: Color) -> Label:
	var l := Style.label("", font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	return l


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 24)
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, on_press: Callable, min_size: Vector2, font_size: int) -> Button:
	var b := Style.chip_button(text, font_size)
	b.custom_minimum_size = min_size
	b.focus_entered.connect(func(): Style.play_move(_audio))
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _first_focus() -> Control:
	if _has_save and not _btn_invite.disabled and _btn_invite.visible:
		return _btn_invite
	if _has_save and _btn_host.is_visible_in_tree() and not _btn_host.disabled:
		return _btn_host
	return _btn_back


## Кооп — своим героем из своего сейва. Нет сейва или герой закрыт — только назад
func _check_save() -> void:
	_has_save = SaveManager.slot_exists(SLOT)
	if not _has_save:
		_hero_lbl.text = tr("Сначала начни путь («Новая игра»): в совместную игру каждый приходит со своим героем.")
		return
	var id: String = SaveManager.peek_slot(SLOT).get("character_id", Characters.FALLBACK)
	if not Characters.is_available(id):
		_has_save = false
		_hero_lbl.text = tr("Твой герой ещё в разработке — выбери другого в «Новой игре».")
		return
	var hero := tr(String(Characters.display_name(id)))
	hero = hero.substr(0, 1) + hero.substr(1).to_lower()
	_hero_lbl.text = tr("Твой герой: %s") % hero
	# Пока лобби нет, первое место — всё равно ты
	var me := Net.my_name()
	_me_line = (me if me != "" else tr("Игрок %d") % 1) + "  ·  " + hero + "   " + tr("(ты)")


func _load_save() -> bool:
	if not _has_save:
		Style.play(_audio, Style.SOUND_DENIED)
		return false
	SaveManager.load_slot(SLOT)
	return true


func _on_invite() -> void:
	if not Net.steam_ok:
		Style.play(_audio, Style.SOUND_DENIED)
		_on_status(Net.steam_status)
		return
	# Хост грузит свой сейв один раз — при создании лобби
	if not Net.in_steam_lobby() and not _load_save():
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	Net.invite_friends()


## Оверлей не открылся — свой список друзей в сети
func _show_friends() -> void:
	for c in _friends_list.get_children():
		_friends_list.remove_child(c)
		c.queue_free()
	var friends := Net.online_friends()
	for f in friends:
		var text := String(f["name"])
		if f["here"]:
			text += "   ·   " + tr("в игре")
		var b := _button(_friends_list, text, _on_friend_pick.bind(int(f["id"])), Vector2(0, 52), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if friends.is_empty():
		var l := _wrap_label(21, Style.TEXT_DIM)
		l.text = tr("Никого из друзей нет в сети")
		_friends_list.add_child(l)
	_friends_box.visible = true
	# Окно и так высокое: отладочный IP прячем, пока открыт список друзей
	_ip_box.visible = false
	if not friends.is_empty():
		(_friends_list.get_child(0) as Control).grab_focus.call_deferred()


func _on_friend_pick(friend_id: int) -> void:
	Style.play(_audio, Style.SOUND_ACCEPT)
	Net.invite_friend(friend_id)


func _on_host() -> void:
	if not _load_save():
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	if Net.host() == OK:
		_on_status(tr("Игра создана. Друзьям — адрес: %s") % _local_addresses())


func _on_join() -> void:
	if not _load_save():
		return
	if _addr.text.strip_edges() == "":
		Style.play(_audio, Style.SOUND_DENIED)
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	Net.join(_addr.text)


func _on_start() -> void:
	if not Net.is_host():
		Style.play(_audio, Style.SOUND_DENIED)
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	Net.start_game(scene_path)


func _on_status(text: String) -> void:
	_status.text = text
	_refresh()


func _refresh() -> void:
	if _closing:
		return
	var ids := Net.peers.keys()
	ids.sort_custom(func(a, b): return int(Net.peers[a]["slot"]) < int(Net.peers[b]["slot"]))
	for i in _slots.size():
		var s := _slots[i]
		if i < ids.size():
			var pid := int(ids[i])
			var text := Net.describe(pid)
			if pid == Net.my_id():
				text += "   " + tr("(ты)")
			else:
				var ping := Net.ping_of(pid)
				if ping == -2:
					text += "   ·   " + tr("нет связи")
				elif ping >= 0:
					text += "   ·   " + tr("%d мс") % ping
			if pid == 1 and ids.size() > 1:
				text = "★  " + text
			s.text = text
			s.add_theme_color_override("font_color", Style.TEXT)
		elif i == 0 and _me_line != "" and not Net.is_joining():
			s.text = _me_line
			s.add_theme_color_override("font_color", Style.TEXT)
		else:
			s.text = tr("— свободное место —")
			s.add_theme_color_override("font_color", Color(Style.TEXT_DIM, 0.45))
	var busy := Net.is_online() or not Net.peers.is_empty() or Net.is_connecting()
	var client := Net.is_client() or Net.is_joining()
	# Пригласить может хост (или тот, кто ещё никуда не вошёл)
	_btn_invite.visible = not client
	_btn_invite.disabled = not Net.steam_ok or not _has_save or (busy and not Net.is_host() and not Net.is_creating_lobby())
	if Net.is_host() and Net.in_steam_lobby():
		_btn_invite.text = tr("ПРИГЛАСИТЬ ЕЩЁ")
	else:
		_btn_invite.text = tr("ПРИГЛАСИТЬ ДРУГА")
	if client:
		_friends_box.visible = false
	_btn_start.visible = Net.is_host()
	_btn_host.disabled = not _has_save or busy
	_btn_join.disabled = not _has_save or busy
	_addr.editable = not busy
	_steam_lbl.text = Net.steam_status


## Адреса этого компьютера в локальной сети (для друзей в той же сети)
func _local_addresses() -> String:
	var out := []
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		out.append(a)
	return ", ".join(out) if not out.is_empty() else "127.0.0.1"


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
	if not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


## Назад — выходим из лобби (если создали, подключились или ждём ответа)
func _close() -> void:
	if _closing:
		return
	_closing = true
	Net.leave()
	Style.play_back(_audio)
	closed.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2(0.97, 0.97), 0.16)
	await tw.finished
	queue_free()


## Уходим на уровень (хост нажал «Начать») — окно просто гасим, сеанс живёт
func dismiss() -> void:
	_closing = true
	visible = false
	queue_free()
