extends Node2D

# --- CONFIGURAÇÕES DA HORDA ---
@export var tempo_entre_ondas: float = 8.0 # Ajustado conforme balanceamento anterior
@export var maximo_inimigos_vivos: int = 2

# Preload dos Inimigos
const INIMIGO_SOUL = preload("res://scenes/enemies/soul/soul.tscn")
const INIMIGO_GOLEM = preload("res://scenes/enemies/golem.tscn")
const INIMIGO_GUARDIAN = preload("res://scenes/enemies/guardian/guardian.tscn")
const INIMIGO_SKELETON = preload("res://scenes/enemies/skeleton_lighter.tscn")

@onready var lista_inimigos = [
	INIMIGO_SOUL, 
	INIMIGO_SKELETON, 
	INIMIGO_GOLEM
]

# --- REFERÊNCIAS ---
@onready var wave_timer := $WaveTimer
@onready var spawn_points_container := $SpawnPoints 
@onready var boss_ui = $BossUI 
@onready var boss = $BossDemon # O nó do Boss na cena

func _ready() -> void:
	# --- CONFIGURAÇÃO DA HORDA ---
	if wave_timer:
		wave_timer.wait_time = tempo_entre_ondas
		if not wave_timer.timeout.is_connected(_on_wave_timer_timeout):
			wave_timer.timeout.connect(_on_wave_timer_timeout)
		wave_timer.start()
	
	print("Batalha final iniciada!")

	# --- CONFIGURAÇÃO DO BOSS ---
	if boss:
		# 1. Conecta a UI
		if boss_ui:
			boss_ui.initialize(boss)
		
		# 2. Conecta o sinal de Vitória (O NOVO PASSO)
		if not boss.boss_defeated.is_connected(_on_boss_defeated):
			boss.boss_defeated.connect(_on_boss_defeated)
	else:
		print("AVISO: BossDemon não encontrado na cena!")

func _on_wave_timer_timeout() -> void:
	# Só spawna inimigos se o boss ainda estiver vivo
	if boss and boss.vida_atual > 0:
		spawnar_onda()

func spawnar_onda() -> void:
	var inimigos_ativos = get_tree().get_nodes_in_group("enemies").size()
	if inimigos_ativos >= maximo_inimigos_vivos:
		return

	if not spawn_points_container: return
	var spawns = spawn_points_container.get_children()
	if spawns.size() == 0: return
		
	var ponto_escolhido = spawns.pick_random() as Marker2D
	var cena_inimigo = lista_inimigos.pick_random()
	
	var novo_inimigo = cena_inimigo.instantiate()
	novo_inimigo.global_position = ponto_escolhido.global_position
	
	if not novo_inimigo.is_in_group("enemies"):
		novo_inimigo.add_to_group("enemies")
	
	add_child(novo_inimigo)

# --- FUNÇÃO DE VITÓRIA ---
func _on_boss_defeated() -> void:
	print("VITÓRIA! Boss derrotado.")
	
	if wave_timer:
		wave_timer.stop()
	
	if get_tree():
		get_tree().call_group("enemies", "queue_free")
	
	await get_tree().create_timer(4.0).timeout
	
	if not is_inside_tree():
		return
	
	if Singleton:
		Singleton.permanent_save_xp() 
		Singleton.reset_run_stats()
	
	print("Retornando para a base...")
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/home.tscn")
