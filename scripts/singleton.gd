extends Node

signal xp_updated(current, next_level)
signal enemy_count_updated(count)

## --- Game State Variables ---
var enemy_count: Array[Node] = []    # List of active enemy nodes
var enemy_label: Label = null        # Reference to the UI label showing the enemy count

var returning_home := false
var game_started := false

# --- Completed Levels Tracking ---
var completed_levels: Array[String] = []  # Armazena os nomes das fases completadas

# --- VARIÁVEIS PERMANENTES DE XP E NÍVEL ---
var current_xp: int = 0
var xp_to_next_level: int = 10 # O jogador começa precisando de 10 XP
var current_level: int = 1
var run_xp: int = 0 # Acumulador de XP ganho (para salvar no final)


# --- NOVAS VARIÁVEIS DE ESTADO DA RUN ---
# Estas rastreiam o estado *durante* a fase (temporário)
var run_current_xp: int = 0
var run_xp_to_next: int = 0
var run_level: int = 0


# --- SINAL DE LEVEL UP ---
# Emitido quando o jogador sobe de nível (mesmo que temporariamente)
signal player_leveled_up(new_level)


func _ready() -> void:
	call_deferred("_init_after_ready")
	
	# --- MUDANÇA IMPORTANTE ---
	# Inicializa os stats da run quando o jogo começa
	reset_run_stats()


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
	
	# --- CORREÇÃO DE BUG ---
	# Removemos o reset de XP daqui para não resetar
	# toda vez que a cena é carregada.
	
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
	enemy_count_updated.emit(enemy_count.size())
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

	print("Salvando XP da run: ", run_xp)
	
	# --- FUNÇÕES ATUALIZADAS ---
	# 1. Salva o estado atual da run como permanente
	permanent_save_xp()
		
	# 2. Reseta os stats da run de volta ao estado (agora salvo)
	reset_run_stats()
	

# --- FUNÇÃO ATUALIZADA ---
# Salva o estado ATUAL da run como o novo estado PERMANENTE
func permanent_save_xp() -> void:
	current_xp = run_current_xp
	xp_to_next_level = run_xp_to_next
	current_level = run_level
	
	print("--- STATS PERMANENTES SALVOS ---")
	print("Nível: ", current_level, " | XP: ", current_xp, "/", xp_to_next_level)


# --- FUNÇÃO ATUALIZADA (LÓGICA PRINCIPAL) ---
func add_xp_to_run(amount: int) -> void:
	run_xp += amount 
	run_current_xp += amount
	
	xp_updated.emit(run_current_xp, run_xp_to_next)

	print("XP ganho: ", amount, " | XP da Run: ", run_current_xp, "/", run_xp_to_next)

	while run_current_xp >= run_xp_to_next:
		run_level += 1
		run_current_xp -= run_xp_to_next
		run_xp_to_next = int(run_xp_to_next * 1.5)
		player_leveled_up.emit(run_level)
		xp_updated.emit(run_current_xp, run_xp_to_next)
		print("LEVEL UP (Temporário)! Nível: ", run_level, " | XP Atual: ", run_current_xp, " | Próximo em: ", run_xp_to_next, " XP")


# --- FUNÇÃO ATUALIZADA E RENOMEADA ---
# Esta função reseta os stats temporários da run para os permanentes.
# É chamada no início do jogo, ao morrer, ou ao completar uma fase.
func reset_run_stats() -> void:
	run_xp = 0
	
	# Copia os stats PERMANENTES para os stats TEMPORÁRIOS da run
	run_current_xp = current_xp
	run_xp_to_next = xp_to_next_level
	run_level = current_level
	
	xp_updated.emit(run_current_xp, run_xp_to_next)
	
	print("Stats da run resetados para o estado permanente.")
