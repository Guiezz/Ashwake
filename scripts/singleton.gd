extends Node

## --- Game State Variables ---
var enemy_count: Array[Node] = []    # List of active enemy nodes
var enemy_label: Label = null        # Reference to the UI label showing the enemy count

var returning_home := false
var game_started := false

# --- Completed Levels Tracking ---
var completed_levels: Array[String] = []  # Armazena os nomes das fases completadas


func _ready() -> void:
	call_deferred("_init_after_ready")


func _init_after_ready() -> void:
	get_tree().connect("tree_changed", Callable(self, "_on_tree_changed"))
	_refresh_scene_data()


func _on_tree_changed() -> void:
	if returning_home:
		return
	call_deferred("_refresh_scene_data")


func _refresh_scene_data() -> void:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	if current_scene.name == "home":
		enemy_label = null
		enemy_count.clear()
		returning_home = false
		game_started = false
		return

	if not game_started:
		game_started = true

	enemy_count = get_tree().get_nodes_in_group("enemies")

	var player = get_tree().get_first_node_in_group("player")
	if player:
		enemy_label = player.get_node_or_null("EnemyCount")
	else:
		enemy_label = null

	update_enemy_label()


func update_enemy_label() -> void:
	if enemy_label != null:
		enemy_label.text = "Enemies: %d" % enemy_count.size()

	if enemy_count.size() == 0 and get_tree().current_scene.name != "home" and not returning_home:
		returning_home = true
		# Marca a fase como completada
		_mark_level_completed(get_tree().current_scene.name)

	if game_started and enemy_count.size() == 0 and get_tree().current_scene.name != "home" and returning_home:
		returning_home = false
		print("All enemies defeated — returning to home scene...")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scenes/home.tscn")


func on_enemy_removed(enemy: CharacterBody2D) -> void:
	if enemy in enemy_count:
		enemy_count.erase(enemy)
		update_enemy_label()


## --- Completed Levels Functions ---
func _mark_level_completed(level_name: String) -> void:
	if level_name in completed_levels:
		return
	completed_levels.append(level_name)
	print("Level completed:", level_name)
