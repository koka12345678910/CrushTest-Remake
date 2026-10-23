extends Ability
## blessing.gd — заклинание рыцаря «Благословение богов». Такая же способность,
## как предметы сумки (Ability), но лежит в книге заклинаний (не тратится) и
## стоит Одра — "связи с богами" (Player_scene/magic/knight_magic.gd).
## Применение: рыцарь возносит меч (молитва), в меч бьёт молния / вспыхивает
## огонь, и на duration секунд удары несут стихию.
##
## Все поля — @export: быстрый слот кладёт в себя duplicate() заклинания, а
## duplicate копирует только экспортируемые свойства

## "lightning" — благословение Тора, "fire" — Сурта
@export var element := "lightning"
## Сколько Одра стоит (списывается в момент удара молнии / вспышки огня)
@export var odr_cost := 40.0
## Сколько секунд держится благословение на мече
@export var duration := 30.0
## Цвет стихии — свечение меча, свет, кромки эффектов
@export var color := Color(0.6, 0.8, 1.0)


func _execute(player: Node) -> void:
	var magic = player.get("magic")
	if magic:
		magic.begin_prayer(self)
