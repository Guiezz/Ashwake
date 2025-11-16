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
	Singleton.xp_updated.connect(atualizar_xp)
	Singleton.enemy_count_updated.connect(atualizar_inimigos)
	
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(atualizar_vida)
		atualizar_vida(player.vida_atual, player.vida_maxima)
	
	# Inicializa a UI com os valores atuais do Singleton
	atualizar_xp(Singleton.run_current_xp, Singleton.run_xp_to_next)
	verificar_visibilidade_inimigos()

func verificar_visibilidade_inimigos():
	var cena_atual = get_tree().current_scene.name.to_lower()
	
	# Se estiver na "home", esconde o texto e força zero
	if cena_atual == "home":
		enemy_label.visible = false
		# Opcional: Pode zerar o texto também para garantir
		enemy_label.text = ""
	else:
		# Se for uma fase normal, mostra o label e pega o valor real
		enemy_label.visible = true
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
	if get_tree().current_scene.name.to_lower() == "home":
		enemy_label.visible = false
		return
		
	enemy_label.visible = true
	enemy_label.text = "Inimigos Restantes: %d" % quantidade
