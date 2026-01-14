extends Node2D

@onready var portal = $Portal # Certifique-se que o nó se chama "Portal" na cena
@onready var label_instrucao = $Interface/LabelInstrucao # Referência ao texto na interface

# Variável para controlar se o portal já foi aberto para não repetir o comando
var nivel_concluido := false

func _process(delta: float) -> void:
	if nivel_concluido:
		return
		
	# Verifica quantos nós estão no grupo "enemy"
	var inimigos = get_tree().get_nodes_in_group("enemy")
	var quantidade_inimigos = inimigos.size()
	
	# --- NOVA FEATURE: Atualiza o texto com a contagem ---
	if label_instrucao:
		label_instrucao.text = "Derrote todos os inimigos para liberar a passagem!"
	# -----------------------------------------------------
	
	# Se não sobrou ninguém
	if quantidade_inimigos <= 0:
		abrir_passagem()

func abrir_passagem() -> void:
	nivel_concluido = true
	print("Todos os inimigos derrotados! Passagem liberada.")
	
	# --- NOVA FEATURE: Texto de vitória ---
	if label_instrucao:
		label_instrucao.text = "Zona limpa! Entre no portal."
	# --------------------------------------
	
	if portal:
		# Verifica se o portal tem o método 'ativar' ou se deve usar visible/monitoring
		if portal.has_method("ativar"):
			portal.ativar()
		else:
			# Fallback caso o script do portal seja simples
			portal.visible = true
			if portal.has_method("set_monitoring"):
				portal.set_monitoring(true)
	else:
		print("ERRO: Nó Portal não encontrado na cena!")
