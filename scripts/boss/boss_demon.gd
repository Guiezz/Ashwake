extends CharacterBody2D

signal health_changed(vida_atual, vida_maxima)
signal boss_defeated


# --- ESTADOS ---
enum State { IDLE, CHASE, ATTACKING, HIT, DEAD }
var current_state = State.IDLE

# --- ATRIBUTOS ---
@export var vida_maxima: int = 30
var vida_atual: int
@export var xp_value: int = 500
@export var ajuste_sprite_flip_x: float = 0.0 # Tente valores como -20, 20, -50...

# Ajuste para quando ele olha para a Direita (já estava usando)
@export var ajuste_posicao_direita: float = 0.0 
# Ajuste para quando ele olha para a Esquerda (NOVO - Para corrigir o bug dos 174)
@export var ajuste_posicao_esquerda: float = 0.0

# --- FÍSICA ---
var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var velocidade_movimento: float = 60.0 

# --- COMBATE ---
@export var dano_ataque: int = 2
@export var distancia_ataque: float = 60.0 # Ajuste conforme o tamanho do seu sprite
@export var tempo_para_hitbox: float = 0.9  # Tente começar com 0.8 ou 0.9 para 10 FPS
@export var duracao_da_hitbox: float = 0.2  # Quanto tempo a hitbox fica ligada

var player_ref: Node2D = null
var pode_atacar: bool = true

# --- REFERÊNCIAS ---
# Certifique-se que os nomes dos nós na cena correspondem a estes:
@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var detection_range = $DetectionRange
@onready var attack_hitbox = $AttackHitbox # A área que dá dano (sua espada/corte)
@onready var attack_cooldown = $AttackCooldown

func _ready() -> void:
	vida_atual = vida_maxima
	if not detection_range.body_entered.is_connected(_on_detection_range_body_entered):
		detection_range.body_entered.connect(_on_detection_range_body_entered)
		
	if not attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
		print("Sinal de ataque conectado via código com sucesso!")

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	# Garante que a hitbox comece desligada para não dar dano invisível
	attack_hitbox.monitoring = false
	
	emit_signal("health_changed", vida_atual, vida_maxima)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: 
		return
		
	if not is_on_floor():
		velocity.y += gravidade * delta

	match current_state:
		State.IDLE:
			sprite.play("idle")
			velocity.x = move_toward(velocity.x, 0, 10)
			if player_ref != null:
				current_state = State.CHASE

		State.CHASE:
			sprite.play("walk")
			if player_ref:
				var direcao_vetor = global_position.direction_to(player_ref.global_position)
				var distancia = global_position.distance_to(player_ref.global_position)
				var lado_do_player = sign(direcao_vetor.x) # 1 (Direita) ou -1 (Esquerda)
				
				velocity.x = direcao_vetor.x * velocidade_movimento
				_virar_boss_para_player(direcao_vetor.x)
				var distancia_gatilho = 60.0 # Padrão (Direita)
				
				if lado_do_player < 0: 
					distancia_gatilho = 250.0
				else:
					distancia_gatilho = 60.0
				if distancia <= distancia_gatilho and pode_atacar:
					current_state = State.ATTACKING
			else:
				current_state = State.IDLE

		State.ATTACKING:
			velocity.x = 0
			if sprite.animation != "attack":
				sprite.play("attack")
				_iniciar_ataque()

		State.HIT:
			velocity.x = move_toward(velocity.x, 0, 5)

	move_and_slide()

# --- FUNÇÃO DE VIRAR O BOSS ---
func _virar_boss_para_player(dir_x: float) -> void:
	# Boss Original olha para a ESQUERDA
	
	if dir_x > 0: # Player na DIREITA (Vira)
		sprite.flip_h = true 
		attack_hitbox.scale.x = -1
		
		# Aplica o ajuste no Sprite, na Hitbox E NO CORPO FÍSICO
		sprite.position.x = ajuste_sprite_flip_x 
		attack_hitbox.position.x = ajuste_sprite_flip_x
		collision_shape.position.x = ajuste_sprite_flip_x # <--- ADICIONE ISSO
		
	elif dir_x < 0: # Player na ESQUERDA (Padrão)
		sprite.flip_h = false 
		attack_hitbox.scale.x = 1
		
		# Reseta tudo para 0
		sprite.position.x = 0
		attack_hitbox.position.x = 0
		collision_shape.position.x = 0 # <--- ADICIONE ISSO

# --- LÓGICA DE ATAQUE ---
func _iniciar_ataque() -> void:
	await get_tree().create_timer(tempo_para_hitbox).timeout 
	
	if current_state == State.ATTACKING: 
		print("Hitbox ATIVADA!") # Ajuda a debugar no console
		attack_hitbox.monitoring = true
		
		await get_tree().create_timer(duracao_da_hitbox).timeout
		attack_hitbox.monitoring = false

# --- RECEBER DANO ---
func ser_atingido(dano: int = 1) -> void:
	if current_state == State.DEAD: return

	vida_atual -= dano
	health_changed.emit(vida_atual, vida_maxima)
	print("Boss tomou dano! Vida: ", vida_atual)

	if vida_atual <= 0:
		morrer()
	else:
		# Opcional: Bosses nem sempre entram em animação de Hit para não serem "stunlockados"
		# Se quiser que ele sinta o golpe, descomente abaixo:
		# if current_state != State.ATTACKING:
		# 	current_state = State.HIT
		# 	sprite.play("hit")
		
		# Flash vermelho para feedback visual
		sprite.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

func morrer() -> void:
	current_state = State.DEAD
	sprite.play("death")
	attack_hitbox.set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	
	# Da XP e avisa o jogo
	if Singleton:
		Singleton.add_xp_to_run(xp_value)
	emit_signal("boss_defeated")

# --- SINAIS ---
func _on_detection_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body

func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		attack_hitbox.set_deferred("monitoring", false)
		pode_atacar = false
		attack_cooldown.start(1.5) # Tempo de descanso entre ataques
		current_state = State.CHASE
	elif sprite.animation == "hit":
		current_state = State.CHASE
	elif sprite.animation == "death":
		# Finaliza o Boss (pode tocar som, abrir portal, etc)
		pass

func _on_attack_cooldown_timeout() -> void:
	pode_atacar = true

# Conecte o sinal body_entered da AttackHitbox (Area2D) no editor para cá
func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("tomar_dano"):
		body.tomar_dano(dano_ataque)
