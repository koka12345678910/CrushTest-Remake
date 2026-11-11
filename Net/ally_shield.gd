extends Node
## ally_shield.gd — Кора, наложенная союзником (кооп, Сольвейг: druid.gd
## _start_bark на союзника → Net.to_owner → give здесь у хозяина героя).
##
## Висит на герое узлом "AllyShield": съедает урон, пока не кончится запас
## или время. Вокруг героя — те же кружащие пластинки коры, что у самой
## Сольвейг (druid_bark.gd), и у других игроков — эхо на его кукле.
## Урон через щит пропускают герои сами: character_base.gd::receive_attack и
## player.gd::take_damage зовут absorb().

const BarkScript := preload("res://Player_scene/druid_bark.gd")

var amount := 0.0
var max_amount := 1.0
var left := 0.0
var _fx: Node2D


## Наложить (или обновить) щит на героя
static func give(hero: Node, absorb_amount: float, seconds: float) -> void:
	if not is_instance_valid(hero):
		return
	var s: Node = hero.get_node_or_null("AllyShield")
	if s == null:
		s = load("res://Net/ally_shield.gd").new()
		s.name = "AllyShield"
		hero.add_child(s)
	s.amount = maxf(s.amount, absorb_amount)
	s.max_amount = maxf(s.amount, 1.0)
	s.left = maxf(s.left, seconds)
	s._ensure_fx(hero)


## Сколько урона дойдёт до героя после щита (0 — всё поглощено)
static func absorb(hero: Node, damage: float) -> float:
	if not is_instance_valid(hero):
		return damage
	var s: Node = hero.get_node_or_null("AllyShield")
	if s == null or s.amount <= 0.0:
		return damage
	var taken := minf(s.amount, damage)
	s.amount -= taken
	if s.amount <= 0.0:
		s._finish(true)
	return damage - taken


func _ensure_fx(hero: Node) -> void:
	if is_instance_valid(_fx):
		return
	_fx = BarkScript.new()
	_fx.center = Vector2(0, -6)
	hero.add_child(_fx)
	Net.echo(_fx, "", [], {"center": Vector2(0, -6), "auto_fade": left}, true)


func _process(delta: float) -> void:
	left -= delta
	if is_instance_valid(_fx):
		_fx.strength = clampf(amount / maxf(max_amount, 0.01), 0.0, 1.0)
	if left <= 0.0:
		_finish(false)


func _finish(broken: bool) -> void:
	amount = 0.0
	if is_instance_valid(_fx):
		if broken:
			_fx.shatter()
		else:
			_fx.fade()
	_fx = null
	queue_free()
