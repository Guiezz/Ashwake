extends CharacterBody2D

# --- VIDA DO INIMIGO ---
@export var vida_maxima: int = 3
var vida_atual: int

# --- FÍSICA E IA ---
var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var velocidade: float = 100.0
@export var forca_pulo: float = -300.0
@export var forca_pulo_parede := Vector2(200, -300)

# Referência para o jogador (quando ele estiver no alcance)
var player_ref: Node2D = null

# Referências dos nós de detecção
@onready var wall_detector := $WallDetector
@onready var gap_detector := $GapDetector
@onready var sprite := $Sprite2D # (Troque "Sprite2D" pelo nome do seu sprite)

func _ready() -> void:
	vida_atual = vida_maxima

func _physics_process(delta: float) -> void:
	# 1. Aplicar Gravidade
	if not is_on_floor():
		velocity.y += gravidade * delta

	# 2. Processar Lógica de IA (se o jogador estiver por perto)
	if player_ref != null:
		processar_ia()
	else:
		# Se o jogador não estiver por perto, pare
		velocity.x = move_toward(velocity.x, 0, velocidade * delta)

	# 3. Mover o Inimigo
	move_and_slide()

# --- LÓGICA DE IA ---

func processar_ia() -> void:
	# Pega a direção horizontal para o jogador
	var direcao_x = sign(player_ref.global_position.x - global_position.x)

	# Vira o sprite e os detectores
	if direcao_x != 0:
		sprite.flip_h = (direcao_x < 0)
		wall_detector.target_position.x = 20 * direcao_x
		gap_detector.target_position.x = 20 * direcao_x

	# --- Lógica de Pulo ---
	
	# 1. Pular de Paredes (lógica similar à do jogador)
	if is_on_wall() and not is_on_floor():
		# Pula se estiver se movendo contra a parede
		if sign(velocity.x) == -get_wall_normal().x:
			velocity.y = forca_pulo_parede.y
			velocity.x = get_wall_normal().x * forca_pulo_parede.x
			print("IA: Pulando da parede!")

	# 2. Pular obstáculos ou buracos
	if is_on_floor():
		# Se o "detector de parede" estiver tocando (ex: um caixote)
		if wall_detector.is_colliding():
			pular()
			print("IA: Pulando obstáculo!")
			
		# Se o "detector de buraco" NÃO estiver tocando o chão
		if not gap_detector.is_colliding():
			pular()
			print("IA: Pulando buraco!")

	# --- Lógica de Movimento ---
	velocity.x = direcao_x * velocidade

func pular() -> void:
	if is_on_floor():
		velocity.y = forca_pulo

# --- SINAIS DE DETECÇÃO ---

func _on_detection_range_body_entered(body: Node2D) -> void:
	# Começa a perseguir o jogador
	player_ref = body

func _on_detection_range_body_exited(body: Node2D) -> void:
	# Para de perseguir
	player_ref = null

# --- DANO E MORTE ---

func ser_atingido() -> void:
	vida_atual -= 1
	print("Inimigo atingido! Vida restante: ", vida_atual)

	if vida_atual <= 0:
		morrer()

func morrer() -> void:
	print("Inimigo derrotado!")
	queue_free()
