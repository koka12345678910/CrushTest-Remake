extends Control
## CoopPanel.gd — окно «Совместная игра» поверх главного меню (лобби коопа,
## Net/net.gd). Тот же вид, что у ConfirmDialog.gd: тёмная плашка с каймой.
##
## Каждый приходит со своим героем из своего сейва (слот 0): без сейва —
## сначала «Новая игра». Хост жмёт «Создать игру» и видит свой адрес в сети;
## остальные вводят этот адрес и жмут «Подключиться». Когда все в лобби, хост
## жмёт «Начать» — уровень загружается у всех.
##
## Пока транспорт — ENet по IP: на одном компьютере 127.0.0.1, в домашней сети —
## адрес хоста из окна. Через интернет без открытых портов это не работает —
## для этого будет Steam (этап 5).

signal closed

const Style := preload("res://Main_Menu/scripts/MenuStyle.gd")
const SLOT := 0

## Куда уходить по «Начать» — задаёт MainMenu.gd
var scene_path := ""

var _panel: PanelContainer
var _audio: AudioStreamPlayer
var _closing := false
var _hero_lbl: Label
var _status: Label
var _players: Label
var _addr: LineEdit
var _btn_host: Button
var _btn_join: Button
var _btn_start: Button
var _btn_back: Button
var _btn_steam: Button
var _btn_invite: Button
var _steam_lbl: Label
var _has_save := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.make_theme()
	Style.make_dim(self, 0.6)
	_audio = Style.ui_player(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	var sb := Style.panel_box(6)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 48)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 34)
	_panel.add_child(m)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(620, 0)
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)

	var t := Style.label("СОВМЕСТНАЯ ИГРА", 25, Style.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var line := Style.FadeLine.new()
	line.color = Color(Style.GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)

	_hero_lbl = Style.label("", 19, Style.TEXT)
	_hero_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_lbl.custom_minimum_size = Vector2(620, 0)
	v.add_child(_hero_lbl)

	# Через Steam: лобби для друзей и приглашение из оверлея (Net/net.gd)
	_steam_lbl = Style.label(Net.steam_status, 16, Style.TEXT_DIM, true)
	_steam_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_steam_lbl)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 20)
	v.add_child(srow)
	_btn_steam = _button(srow, "СОЗДАТЬ ЧЕРЕЗ STEAM", _on_host_steam)
	_btn_invite = _button(srow, "ПРИГЛАСИТЬ ДРУЗЕЙ", _on_invite)

	var line2 := Style.FadeLine.new()
	line2.color = Color(Style.GOLD, 0.2)
	line2.custom_minimum_size = Vector2(0, 1)
	v.add_child(line2)
	var ip_lbl := Style.label("ИЛИ ПО IP (ОДНА СЕТЬ, ОТЛАДКА)", 15, Style.TEXT_DIM, true)
	ip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ip_lbl)

	# Создать / подключиться по IP
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	_btn_host = _button(row, "СОЗДАТЬ ИГРУ", _on_host)
	_btn_join = _button(row, "ПОДКЛЮЧИТЬСЯ", _on_join)

	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_theme_constant_override("separation", 12)
	v.add_child(arow)
	var al := Style.label("АДРЕС ХОСТА", 16, Style.TEXT_DIM, true)
	arow.add_child(al)
	_addr = LineEdit.new()
	_addr.text = "127.0.0.1"
	_addr.custom_minimum_size = Vector2(300, 40)
	_addr.add_theme_font_size_override("font_size", 19)
	_addr.text_submitted.connect(func(_s: String): _on_join())
	arow.add_child(_addr)

	_status = Style.label("", 17, Style.TEXT_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 0)
	v.add_child(_status)

	_players = Style.label("", 19, Style.TEXT)
	_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players.custom_minimum_size = Vector2(620, 0)
	v.add_child(_players)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)

	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 20)
	v.add_child(brow)
	_btn_back = _button(brow, "НАЗАД", _close)
	_btn_start = _button(brow, "НАЧАТЬ", _on_start)

	Net.peers_changed.connect(_refresh)
	Net.status_changed.connect(_on_status)
	_check_save()
	_refresh()
	(_btn_host if _has_save else _btn_back).call_deferred("grab_focus")
	Style.play_open(_audio)

	modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).from(Vector2(0.96, 0.96))\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Style.chip_button(text)
	b.custom_minimum_size = Vector2(240, 46)
	b.focus_entered.connect(func(): Style.play_move(_audio))
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


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
	_hero_lbl.text = tr("Твой герой: %s") % (hero.substr(0, 1) + hero.substr(1).to_lower())


func _load_save() -> bool:
	if not _has_save:
		Style.play(_audio, Style.SOUND_DENIED)
		return false
	SaveManager.load_slot(SLOT)
	return true


func _on_host() -> void:
	if not _load_save():
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	if Net.host() == OK:
		_on_status(tr("Игра создана. Друзьям — адрес: %s") % _local_addresses())


func _on_host_steam() -> void:
	if not Net.steam_ok or not _load_save():
		Style.play(_audio, Style.SOUND_DENIED)
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	Net.host_steam()


func _on_invite() -> void:
	if not Net.in_steam_lobby():
		Style.play(_audio, Style.SOUND_DENIED)
		return
	Style.play(_audio, Style.SOUND_ACCEPT)
	Net.invite_friends()


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


func _refresh() -> void:
	var lines := []
	var ids := Net.peers.keys()
	ids.sort_custom(func(a, b): return int(Net.peers[a]["slot"]) < int(Net.peers[b]["slot"]))
	for id in ids:
		var s := Net.describe(int(id))
		if int(id) == Net.my_id():
			s += "  " + tr("(ты)")
		lines.append(s)
	_players.text = "\n".join(lines)
	var online := Net.is_online() or not Net.peers.is_empty()
	_btn_host.disabled = not _has_save or online
	_btn_join.disabled = not _has_save or online
	_addr.editable = not online
	_btn_start.visible = Net.is_host()
	_btn_steam.disabled = not Net.steam_ok or not _has_save or online
	_btn_invite.visible = Net.in_steam_lobby() and Net.is_host()
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


## Назад — выходим из лобби (если создали или подключились)
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
