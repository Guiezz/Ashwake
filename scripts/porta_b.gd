extends Area2D

var doorNode = self
@onready var labelDoorA = get_node("/root/home/PortaA/textoA")
@onready var labelDoorB = get_node("/root/home/PortaB/textoB")
#@onready var colorA = get_node("/root/home/PortaA/ColorRect")
#@onready var colorB = get_node("/root/home/PortaB/ColorRect")
@onready var collisionA = get_node("/root/home/PortaA/CollisionShape2D")
@onready var collisionB = get_node("/root/home/PortaB/CollisionShape2D")

var singleton = Singleton

var player_in_area: bool = false  # Track if player is inside

func _ready() -> void:
	labelDoorA.visible = false
	labelDoorB.visible = false  

	# PortaA logic
	if "tutorial" in singleton.completed_levels:
		#colorA.color = Color.GREEN   # Level completed → green
		collisionA.disabled = true   # Disable collision so player can't enter
	else:
		#colorA.color = Color.RED
		collisionA.disabled = false

	# PortaB logic
	if "tutorial" in singleton.completed_levels:
		#colorB.color = Color.GREEN
		collisionB.disabled = true
	else:
		#colorB.color = Color.RED
		collisionB.disabled = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_area = true
		match doorNode.name:
			"PortaA":
				labelDoorA.visible = true
			"PortaB":
				labelDoorB.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_area = false
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


func change_scene_to_porta_a():
	get_tree().change_scene_to_file("res://scenes/levels/tutorial.tscn")


func change_scene_to_porta_b():
	get_tree().change_scene_to_file("res://scenes/levels/tutorial.tscn")
