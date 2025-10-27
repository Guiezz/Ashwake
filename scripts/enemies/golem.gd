extends CharacterBody2D

# --- ESTADOS DA IA ---
enum State { IDLE, WALKING, ATTACKING, HIT, DEAD }
var current_state = State.IDLE

# --- VIDA DO INIMIGO ---
@export var vida_maxima: int = 5
var vida_atual: int

# --- FÍSICA E IA ---
var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var velocidade: float = 100.0
@export var forca_pulo: float = -300.0

# Referência para o jogador
var player_ref: Node2D = null

# Referências dos nós
@onready var sprite := $AnimatedSprite2D
@onready var wall_detector := $WallDetector
@onready var gap_detector := $GapDetector
@onready var detection_range := $DetectionRange
@onready var collision_shape := $CollisionShape2D
@onready var attack_hitbox := $AnimatedSprite2D/AttackHitbox 
@onready var attack_delay_timer := $AttackDelayTimer

func _ready() -> void:
	vida_atual = vida_maxima
	# Conecta os sinais que vamos usar
	detection_range.body_entered.connect(_on_detection_range_body_entered)
	detection_range.body_exited.connect(_on_detection_range_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	# 1. Aplicar Gravidade (só se não estiver morto)
	if current_state != State.DEAD and not is_on_floor():
		velocity.y += gravidade * delta

	# 2. Processar a Máquina de Estados
	processar_ia(delta)

	# 3. Mover o Inimigo
	move_and_slide()

# --- LÓGICA DE IA (MÁQUINA DE ESTADOS) ---
func processar_ia(delta: float) -> void:
	
	# Se o jogador não existe, fique parado.
	if player_ref == null and current_state != State.DEAD and current_state != State.HIT:
		current_state = State.IDLE
	
	match current_state:
		State.IDLE:
			sprite.play("idle")
			velocity.x = 0
			# Se o jogador se aproximar, comece a andar
			if player_ref != null:
				current_state = State.WALKING

		State.WALKING:
			sprite.play("walk")
			
			if player_ref == null:
				current_state = State.IDLE
				return

			# Pega a direção
			var direcao_x = sign(player_ref.global_position.x - global_position.x)
			
			# Vira o sprite e os detectores
			if direcao_x != 0:
				sprite.flip_h = (direcao_x > 0)
				# Ajusta os RayCasts baseado na direção
				var dir_local = 1 if not sprite.flip_h else -1
				attack_hitbox.scale.x = dir_local
				wall_detector.target_position.x = abs(wall_detector.target_position.x) * dir_local
				gap_detector.target_position.x = abs(gap_detector.target_position.x) * dir_local

			# Lógica de Pulo
			if is_on_floor():
				if wall_detector.is_colliding():
					velocity.y = forca_pulo
				if not gap_detector.is_colliding():
					velocity.y = forca_pulo
			
			# Lógica de Movimento
			velocity.x = direcao_x * velocidade
			
			# Se chegar perto o suficiente, ataque
			var distancia = global_position.distance_to(player_ref.global_position)
			if distancia < 200.0:
				current_state = State.ATTACKING

		State.ATTACKING:
			velocity.x = 0
			if sprite.animation != "attack": 
				sprite.play("attack")
				
				attack_delay_timer.start(0.5)

		State.HIT:
			# Não faz nada, só espera a animação "hit" terminar.
			velocity.x = 0
			
		State.DEAD:
			# Não faz nada, só espera a animação "death" terminar.
			velocity.x = 0

# --- SINAIS DE DETECÇÃO ---

func _on_detection_range_body_entered(body: Node2D) -> void:
	# Começa a perseguir o jogador
	if body.is_in_group("player"):
		player_ref = body

func _on_detection_range_body_exited(body: Node2D) -> void:
	# Para de perseguir
	if body == player_ref:
		player_ref = null

# --- HITBOX DE ATAQUE (NOVA FUNÇÃO) ---

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	# Verifica se o corpo que entrou é o jogador
	if body.is_in_group("player"):
		print("TOMANDO DANO")
		# Tenta chamar a função de tomar dano no script do player
		if body.has_method("tomar_dano"):
			body.tomar_dano(1) #
		
		# Desativa a hitbox imediatamente para não acertar várias vezes
		# attack_hitbox.set_deferred("monitoring", false)

# --- DANO E MORTE ---

func ser_atingido() -> void:
	if current_state == State.HIT or current_state == State.DEAD:
		return

	vida_atual -= 1
	print("Golem atingido! Vida restante: ", vida_atual)

	if vida_atual <= 0:
		morrer()
	else:
		current_state = State.HIT
		sprite.play("hit")

func morrer() -> void:
	if current_state == State.DEAD:
		return
		
	print("Golem derrotado!")
	current_state = State.DEAD
	collision_shape.set_deferred("disabled", true)
	detection_range.set_deferred("monitoring", false)
	sprite.play("death")

# --- SINAL DE ANIMAÇÃO ---

func _ativar_hitbox_ataque() -> void:
	print("Hitbox ATIVADA (pela animação)")
	attack_hitbox.monitoring = true

func _desativar_hitbox_ataque() -> void:
	print("Hitbox DESATIVADA (pela animação)")
	# Usamos set_deferred para evitar bugs de física
	attack_hitbox.set_deferred("monitoring", false)

func _on_animation_finished() -> void:
	if sprite.animation == "death":
		queue_free()
	
	elif sprite.animation == "attack":
		attack_hitbox.set_deferred("monitoring", false) # <-- MUDANÇA AQUI
		current_state = State.IDLE
	
	elif sprite.animation == "hit":
		current_state = State.IDLE


func _on_attack_delay_timer_timeout() -> void:
	if current_state == State.ATTACKING:
		attack_hitbox.monitoring = true
