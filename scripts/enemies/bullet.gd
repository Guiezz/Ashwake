extends Area2D

var velocidade: float = 250.0 # Velocidade um pouco menor para dar tempo de reagir
var direcao: Vector2 = Vector2.RIGHT
var rebatida: bool = false # Controla se a bala já é do player

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direcao * velocidade * delta

# --- CORREÇÃO DO ERRO ---
# Esta é a função que o soul.gd estava procurando e não achava
func iniciar(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direcao = dir.normalized()
	rotation = direcao.angle()

# --- NOVA MECÂNICA DE PARRY ---
func rebater(nova_direcao: Vector2) -> void:
	if rebatida: return
	
	rebatida = true
	direcao = nova_direcao.normalized()
	velocidade *= 1.5
	rotation = direcao.angle()
	modulate = Color(0, 1, 1) # Cor Ciano
	
	# --- AQUI É A MÁGICA DA FÍSICA ---
	
	# 1. Pare de colidir com o Player (Layer 1)
	set_collision_mask_value(1, false) 
	
	# 2. Comece a colidir com o Inimigo (Layer 3 - VERIFIQUE NO SEU PROJETO!)
	set_collision_mask_value(2, true)
	
	# 3. (Opcional) Se quiser que ela atravesse paredes ao ser rebatida, desligue a Layer 2
	# set_collision_mask_value(2, false)

# No final do arquivo bullet.gd

func _on_body_entered(body: Node2D) -> void:
	
	# --- CENÁRIO 1: A BALA FOI REBATIDA (Agora é do Player) ---
	if rebatida:
		# Verifica se bateu em um inimigo (Soul, Golem, etc)
		# A verificação 'has_method' é mais segura que checar grupo
		if body.has_method("ser_atingido"):
			print("HEADSHOT! Inimigo atingido pelo rebate.")
			
			# Aplica um dano alto (ex: 3 de dano mata o Soul na hora)
			body.ser_atingido(3, global_position) 
			
			queue_free() # Destroi a bala após o impacto
			
		# Se bateu na parede (TileMap), destrói a bala
		# (O 'not body.is_in_group("player")' impede que ela exploda ao sair da sua espada)
		elif not body.is_in_group("player"):
			queue_free()

	# --- CENÁRIO 2: A BALA É NORMAL (Ainda é do Inimigo) ---
	else:
		# Se acertar o Player
		if body.is_in_group("player"):
			if body.has_method("tomar_dano"):
				body.tomar_dano(1, self)
			queue_free()
			
		# Se acertar parede (qualquer coisa que não seja o próprio inimigo que atirou)
		elif not body.is_in_group("enemy"): 
			queue_free()
