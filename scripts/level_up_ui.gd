extends CanvasLayer

@onready var option_button_1 = $HBoxContainer/OptionButton1
@onready var option_button_2 = $HBoxContainer/OptionButton2
@onready var option_button_3 = $HBoxContainer/OptionButton3

var all_options = [
	{"name": "Força Bruta","description":"Aumenta o dano dos ataques.","type":"damage","value":1},
	{"name": "Pés Ligeiros","description":"+20 Velocidade de Movimento.","type":"speed","value":20.0},
	{"name": "Poção de Cura","description":"Recupera 2 corações de vida.","type":"heal","value":2},
	{"name": "Vitalidade","description":"Aumenta a Vida Máxima em +1.","type":"max_health","value":1},
]

var current_choices = []

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	if Singleton.has_signal("player_leveled_up"):
		Singleton.player_leveled_up.connect(_on_player_leveled_up)
	
	# Conexões de clique
	option_button_1.pressed.connect(_on_button_pressed.bind(0))
	option_button_2.pressed.connect(_on_button_pressed.bind(1))
	option_button_3.pressed.connect(_on_button_pressed.bind(2))

	# 🔥 IMPORTANTE: habilitar foco para navegação no controle
	for b in [option_button_1, option_button_2, option_button_3]:
		b.focus_mode = Control.FOCUS_ALL

	# 🔥 Definir vizinhos (navegação horizontal)
	option_button_1.focus_neighbor_right = option_button_2.get_path()
	option_button_2.focus_neighbor_right = option_button_3.get_path()

	option_button_3.focus_neighbor_left = option_button_2.get_path()
	option_button_2.focus_neighbor_left = option_button_1.get_path()


# ------------------------
# ABERTURA DA TELA
# ------------------------

func _on_player_leveled_up(new_level: int):
	Singleton.request_pause(self)
	current_choices = _get_random_options(3)

	_update_button_visual(option_button_1, current_choices[0])
	_update_button_visual(option_button_2, current_choices[1])
	_update_button_visual(option_button_3, current_choices[2])

	visible = true

	# 🔥 Começar com o primeiro botão focado
	option_button_1.grab_focus()


func _get_random_options(amount: int) -> Array:
	var shuffled_list = all_options.duplicate()
	shuffled_list.shuffle()
	return shuffled_list.slice(0, amount)


func _update_button_visual(button: Button, option: Dictionary):
	button.text = option["name"] + "\n(" + option["description"] + ")"


func _on_button_pressed(index: int):
	var selected_option = current_choices[index]
	_apply_upgrade(selected_option)

	visible = false
	Singleton.release_pause(self)


# ------------------------
# SUPORTE AO BOTÃO "ui_aceitar"
# ------------------------

func _unhandled_input(event):
	if event.is_action_pressed("ui_aceitar"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")


# ------------------------
# APLICAÇÃO DOS UPGRADES
# ------------------------

func _apply_upgrade(option: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERRO: Player não encontrado!")
		return

	match option["type"]:
		"heal":
			if player.has_method("curar"):
				player.curar(option["value"])

		"max_health":
			if player.has_method("aumentar_vida_maxima"):
				player.aumentar_vida_maxima(option["value"])

		"speed":
			if "velocidade" in player:
				player.velocidade += option["value"]

		"damage":
			if player.has_method("aumentar_dano"):
				player.aumentar_dano(option["value"])
