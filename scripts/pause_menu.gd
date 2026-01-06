extends CanvasLayer

@onready var menu_container = $VBoxContainer # Ou onde estão seus botões
@onready var controls_panel = $ControlsPanel # Se você copiou o painel
@onready var btn_resume = $VBoxContainer/BtnResume
@onready var btn_close_controls = $ControlsPanel/BtnCloseControls # Botão dentro do painel

func _ready():
	# Começa invisível
	visible = false 
	controls_panel.visible = false

func _unhandled_input(event):
	# Se apertar ESC ou o botão Start do controle (precisa configurar no Input Map como "pause")
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		# Se o painel de controles estiver aberto, fecha ele primeiro
		if controls_panel.visible:
			_on_btn_close_controls_pressed()
		else:
			toggle_pause()

func toggle_pause():
	# Inverte o estado de pausa (se está true vira false, e vice-versa)
	get_tree().paused = not get_tree().paused
	
	# Mostra ou esconde o menu
	visible = get_tree().paused
	
	if visible:
		# Se abriu o menu, dá foco no botão de continuar (para controle)
		btn_resume.grab_focus()

func _on_btn_resume_pressed():
	toggle_pause()

func _on_btn_controls_pressed():
	controls_panel.visible = true
	menu_container.visible = false # Esconde os botões principais
	btn_close_controls.grab_focus()

func _on_btn_close_controls_pressed():
	controls_panel.visible = false
	menu_container.visible = true
	btn_resume.grab_focus()

func _on_btn_quit_pressed():
	# Despausa antes de sair (importante para não bugar a próxima vez que rodar)
	get_tree().paused = false
	# Volta para a tela inicial
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
