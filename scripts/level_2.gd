extends Node2D

@onready var portal = $Portal # Certifique-se que o nó se chama "Portal" na cena

# Variável para controlar se o portal já foi aberto para não repetir o comando
var nivel_concluido := false

func _process(delta: float) -> void:
	if nivel_concluido:
		return
		
	# Verifica quantos nós estão no grupo "enemy"
	var quantidade_inimigos = get_tree().get_nodes_in_group("enemy").size()
	
	# Se não sobrou ninguém
	if quantidade_inimigos <= 0:
		abrir_passagem()

func abrir_passagem() -> void:
	nivel_concluido = true
	print("Todos os inimigos derrotados! Passagem liberada.")
	
	if portal:
		portal.ativar()
	else:
		print("ERRO: Nó Portal não encontrado na cena!")
