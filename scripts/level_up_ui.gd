extends CanvasLayer

# Referências para os botões
@onready var option_button_1 = $HBoxContainer/OptionButton1
@onready var option_button_2 = $HBoxContainer/OptionButton2
@onready var option_button_3 = $HBoxContainer/OptionButton3

# Lista Mestra de Upgrades (Adicione mais aqui se quiser!)
var all_options = [
	{
		"name": "Força Bruta",
		"description": "Aumenta o dano dos ataques.", # Placeholder se tiver lógica de dano
		"type": "damage",
		"value": 1
	},
	{
		"name": "Pés Ligeiros",
		"description": "+20 Velocidade de Movimento.",
		"type": "speed",
		"value": 20.0
	},
	{
		"name": "Poção de Cura",
		"description": "Recupera 2 corações de vida.",
		"type": "heal",
		"value": 2
	},
	{
		"name": "Vitalidade",
		"description": "Aumenta a Vida Máxima em +1.",
		"type": "max_health",
		"value": 1
	},
	# Dica: Se quiser que algo apareça mais vezes, pode duplicar a entrada aqui na lista
]

# Variável para guardar quais as 3 opções que foram sorteadas na rodada atual
var current_choices = []

func _ready():
	# Permite funcionar com o jogo pausado
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	# Conecta ao sinal do Singleton (Verifique se o nome do Autoload é 'Singleton')
	if Singleton.has_signal("player_leveled_up"):
		Singleton.player_leveled_up.connect(_on_player_leveled_up)
	
	# Conecta os botões usando 'bind' para sabermos qual botão foi clicado (0, 1 ou 2)
	option_button_1.pressed.connect(_on_button_pressed.bind(0))
	option_button_2.pressed.connect(_on_button_pressed.bind(1))
	option_button_3.pressed.connect(_on_button_pressed.bind(2))


# Chamado quando o player upa de nível
func _on_player_leveled_up(new_level: int):
	print("Level Up! Sorteando cartas...")
	get_tree().paused = true
	
	# Sorteia 3 opções aleatórias e únicas
	current_choices = _get_random_options(3)
	
	# Atualiza o visual dos botões com as opções sorteadas
	_update_button_visual(option_button_1, current_choices[0])
	_update_button_visual(option_button_2, current_choices[1])
	_update_button_visual(option_button_3, current_choices[2])

	visible = true


# Função auxiliar para embaralhar e pegar X opções
func _get_random_options(amount: int) -> Array:
	var shuffled_list = all_options.duplicate()
	shuffled_list.shuffle() # Mistura o array
	return shuffled_list.slice(0, amount) # Pega os primeiros 'amount' itens


# Atualiza o texto do botão
func _update_button_visual(button: Button, option: Dictionary):
	button.text = option["name"] + "\n" + "(" + option["description"] + ")"
	# Se tiver ícones no futuro: button.icon = load(option["icon_path"])


# Chamado quando clica em QUALQUER botão
func _on_button_pressed(index: int):
	var selected_option = current_choices[index] # Pega a opção baseada no botão clicado
	_apply_upgrade(selected_option)
	
	# Fecha a tela e resume o jogo
	visible = false
	get_tree().paused = false


# Aplica o efeito no Player
func _apply_upgrade(option: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("ERRO: Player não encontrado no grupo 'player'!")
		return
		
	print("Aplicando upgrade: ", option["name"])

	match option["type"]:
		"heal":
			# Chama a função que criamos no player.gd
			if player.has_method("curar"):
				player.curar(option["value"])
			else:
				print("ERRO: O script do Player não tem a função 'curar()'")
				
		"max_health":
			# Chama a função que criamos no player.gd
			if player.has_method("aumentar_vida_maxima"):
				player.aumentar_vida_maxima(option["value"])
			else:
				print("ERRO: O script do Player não tem a função 'aumentar_vida_maxima()'")

		"speed":
			# Aumenta a velocidade diretamente
			if "velocidade" in player:
				player.velocidade += option["value"]
				print("Nova velocidade: ", player.velocidade)
		
		"damage":
			if player.has_method("aumentar_dano"):
				player.aumentar_dano(option["value"])
			else:
				print("ERRO: Função aumentar_dano não encontrada no Player!")
