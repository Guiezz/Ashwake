extends CanvasLayer

# --- REFERÊNCIAS DA UI (Baseado na estrutura da sua cena) ---
@onready var health_bar = $MarginContainer/VBoxContainer/HealthContainer/HealthBar
@onready var health_text = $MarginContainer/VBoxContainer/HealthContainer/HealthBar/HealthText
@onready var xp_bar = $MarginContainer/VBoxContainer/XPContainer/XPBar
@onready var xp_text = $MarginContainer/VBoxContainer/XPContainer/XPBar/XPText
@onready var enemy_label = $MarginContainer/VBoxContainer/EnemyCountLabel

# Referência ao Player (será buscado no _ready)
var player: CharacterBody2D

func _ready():
	# Conecta aos sinais do Singleton (XP e Inimigos)
	Singleton.xp_updated.connect(atualizar_xp)
	Singleton.enemy_count_updated.connect(atualizar_inimigos)
	
	# Busca o player na cena para conectar a Vida
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(atualizar_vida)
		
		# Inicializa a barra com a vida atual do player
		atualizar_vida(player.vida_atual, player.vida_maxima)
	
	# Inicializa a UI com os valores atuais do Singleton
	atualizar_xp(Singleton.run_current_xp, Singleton.run_xp_to_next)
	atualizar_inimigos(Singleton.enemy_count.size())

func atualizar_vida(vida_atual: int, vida_maxima: int):
	health_bar.max_value = vida_maxima
	health_bar.value = vida_atual
	health_text.text = "%d / %d" % [vida_atual, vida_maxima]

func atualizar_xp(xp_atual: int, xp_proximo: int):
	xp_bar.max_value = xp_proximo
	xp_bar.value = xp_atual
	xp_text.text = "XP: %d / %d" % [xp_atual, xp_proximo]

func atualizar_inimigos(quantidade: int):
	enemy_label.text = "Inimigos Restantes: %d" % quantidade
