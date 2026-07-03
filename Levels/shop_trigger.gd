extends Area2D

@export var shop_menu_path: NodePath

var player_in_range: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	print("body_entered: ", body.name, " in_group player: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_in_range = body

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null

func _input(event: InputEvent) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		print("открываем магазин, path=", shop_menu_path)
		var shop_menu = get_node(shop_menu_path)
		print("найдена нода: ", shop_menu)
		if shop_menu:
			shop_menu.open_shop(player_in_range)
