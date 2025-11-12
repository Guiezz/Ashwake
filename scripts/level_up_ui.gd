extends CanvasLayer

# Referências para os botões (arraste-os do editor ou use @onready)
@onready var option_button_1 = $HBoxContainer/OptionButton1
@onready var option_button_2 = $HBoxContainer/OptionButton2
@onready var option_button_3 = $HBoxContainer/OptionButton3

func _ready():
	# --- O PASSO MAIS IMPORTANTE ---
	# Permite que esta UI (e seus botões) funcione mesmo com o jogo pausado.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Começa invisível
	visible = false

	# Conecta esta UI ao sinal global do Singleton
	# (Verifique se o nome do seu autoload é "Singleton", com 'S' maiúsculo)
	Singleton.player_leveled_up.connect(_on_player_leveled_up)

	# Conecta os botões à função de fechar
	option_button_1.pressed.connect(_on_option_selected)
	option_button_2.pressed.connect(_on_option_selected)
	option_button_3.pressed.connect(_on_option_selected)


# Esta função é chamada AUTOMATICAMENTE pelo sinal do Singleton
func _on_player_leveled_up(new_level: int):
	print("UI recebendo sinal de Level Up!")
	
	# PAUSA O JOGO
	get_tree().paused = true
	
	# Por enquanto, só mostramos os mesmos textos
	# (No futuro, vamos carregar 3 power-ups aleatórios aqui)
	option_button_1.text = "Mais Velocidade"
	option_button_2.text = "Mais Pulo"
	option_button_3.text = "Mais Dano"

	# Mostra a UI
	visible = true


# Esta função é chamada por QUALQUER um dos 3 botões
func _on_option_selected():
	# (No futuro, vamos aplicar o power-up escolhido aqui)
	print("Opção selecionada!")

	# Esconde a UI
	visible = false
	
	# DESPAUSA O JOGO
	get_tree().paused = false
