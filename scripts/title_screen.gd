extends Control

# Referências aos nós (ajuste os caminhos se tiver mudado os nomes)
@onready var controls_panel = $ControlsPanel

func _ready():
	# Garante que o painel de controles comece escondido
	controls_panel.visible = false

# Função para iniciar o jogo
func _on_btn_start_pressed():
	# Troca para a cena do Level 1. 
	# Verifiquei seus arquivos e o caminho parece ser este:
	get_tree().change_scene_to_file("res://scenes/home.tscn")

# Função para mostrar/esconder controles
func _on_btn_controls_pressed():
	controls_panel.visible = true

# Função para fechar o painel de controles
func _on_btn_close_controls_pressed():
	controls_panel.visible = false

# Função para sair do jogo
func _on_btn_exit_pressed():
	get_tree().quit()
