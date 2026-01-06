extends Control

@onready var controls_panel = $ControlsPanel

# Referências para os botões (para podermos dar foco neles)
# IMPORTANTE: Verifique se o caminho "$VBoxContainer/BtnStart" bate com a sua cena.
# Se o VBoxContainer tiver outro nome, ajuste aqui.
@onready var btn_start = $VBoxContainer/BtnStart
@onready var btn_controls = $VBoxContainer/BtnControls
@onready var btn_close_controls = $ControlsPanel/BtnCloseControls

func _ready():
	controls_panel.visible = false
	
	# O SEGREDO: Assim que o jogo abre, já seleciona o primeiro botão
	# Isso faz o controle saber onde ele está.
	btn_start.grab_focus()

func _on_btn_start_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/tutorial.tscn")

func _on_btn_controls_pressed():
	controls_panel.visible = true
	# Quando abre o pop-up, muda o foco para o botão de fechar dentro dele
	btn_close_controls.grab_focus()

func _on_btn_close_controls_pressed():
	controls_panel.visible = false
	# Quando fecha o pop-up, devolve o foco para o botão de controles
	btn_controls.grab_focus()

func _on_btn_exit_pressed():
	get_tree().quit()
