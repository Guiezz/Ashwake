extends Area2D

var doorNode = self
@onready var labelDoorA = get_node("/root/Node2D/PortaA/textoA")
@onready var labelDoorB = get_node("/root/Node2D/PortaB/textoB")

var player_in_area: bool = false  # Track if player is inside

func _ready() -> void:
	labelDoorA.visible = false
	labelDoorB.visible = false  

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":  # only react to player
		player_in_area = true
		match doorNode.name:
			"PortaA":
				labelDoorA.visible = true
			"PortaB":
				labelDoorB.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_area = false
		print(doorNode.name)
		print("saiu")
		match doorNode.name:
			"PortaB":
				labelDoorB.visible = false
			"PortaA":
				labelDoorA.visible = false

func _process(delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("interact"): 
		match doorNode.name:
			"PortaA":
				change_scene_to_porta_a()
			"PortaB":
				change_scene_to_porta_b()

# Example scene change functions
func change_scene_to_porta_a():
	get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")

func change_scene_to_porta_b():
	get_tree().change_scene_to_file("res://scenes/levels/level2.tscn")
