extends Node2D

# --- CONFIGURAÇÕES DA HORDA ---
@export var tempo_entre_ondas: float = 4.0
@export var maximo_inimigos_vivos: int = 6 

# Carregue as cenas dos inimigos
# É melhor usar 'const' aqui para preloads, ou manter var.
const INIMIGO_SOUL = preload("res://scenes/enemies/soul/soul.tscn")
const INIMIGO_GOLEM = preload("res://scenes/enemies/golem.tscn")
const INIMIGO_GUARDIAN = preload("res://scenes/enemies/guardian/guardian.tscn")
const INIMIGO_SKELETON = preload("res://scenes/enemies/skeleton_lighter.tscn")

# --- CORREÇÃO AQUI ---
# Usamos @onready para montar a lista quando o jogo começar
@onready var lista_inimigos = [
	INIMIGO_SOUL, 
	INIMIGO_SOUL, # Soul aparece mais vezes (2x chance)
	INIMIGO_SKELETON, 
	INIMIGO_GUARDIAN
]

# --- REFERÊNCIAS ---
@onready var wave_timer := $WaveTimer
@onready var spawn_points_container := $SpawnPoints 

func _ready() -> void:
	# Configura o timer
	if wave_timer:
		wave_timer.wait_time = tempo_entre_ondas
		# Se não conectou pelo editor, conecte via código:
		if not wave_timer.timeout.is_connected(_on_wave_timer_timeout):
			wave_timer.timeout.connect(_on_wave_timer_timeout)
		wave_timer.start()
	
	print("Começando a invocação da horda!")

func _on_wave_timer_timeout() -> void:
	spawnar_onda()

func spawnar_onda() -> void:
	# 1. Verifica limites
	var inimigos_ativos = get_tree().get_nodes_in_group("enemies").size()
	if inimigos_ativos >= maximo_inimigos_vivos:
		return

	# 2. Verifica Spawn Points
	if not spawn_points_container:
		print("ERRO: Container 'SpawnPoints' não encontrado!")
		return
		
	var spawns = spawn_points_container.get_children()
	if spawns.size() == 0:
		print("ERRO: Nenhum Marker2D dentro de SpawnPoints!")
		return
		
	# 3. Sorteia local e inimigo
	var ponto_escolhido = spawns.pick_random() as Marker2D
	var cena_inimigo = lista_inimigos.pick_random()
	
	# 4. Instancia
	var novo_inimigo = cena_inimigo.instantiate()
	novo_inimigo.global_position = ponto_escolhido.global_position
	
	if not novo_inimigo.is_in_group("enemies"):
		novo_inimigo.add_to_group("enemies")
	
	add_child(novo_inimigo)
	
	# Feedback no console
	print("Inimigo spawnado em: ", ponto_escolhido.name)
