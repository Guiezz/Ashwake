# soul.gd
extends CharacterBody2D

# --- ESTADOS DA IA ---
enum State { IDLE, CHASING, ATTACKING, DEAD }
var current_state = State.IDLE

# --- VIDA DO INIMIGO ---
@export var vida_maxima: int = 3 # Soul pode ser mais frágil
var vida_atual: int

# --- IA E MOVIMENTO ---
@export var velocidade: float = 100.0 # Velocidade de voo
@export var distancia_ataque: float = 250.0 # Distância para começar a atacar
@export var distancia_parar: float = 180.0 # Distância para parar de perseguir e atacar
@export var cooldown_ataque: float = 1.5 # Tempo entre ataques
@export var tempo_disparo_ataque: float = 0.3 # Tempo após iniciar o ataque para disparar <--- NOVO

# Referência para o jogador
var player_ref: CharacterBody2D = null

# Referências dos nós
@onready var sprite := $AnimatedSprite2D
@onready var detection_range := $DetectionRange
@onready var collision_shape := $CollisionShape2D
@onready var attack_cooldown_timer := $AttackCooldownTimer
@onready var projectile_spawn_point := $ProjectileSpawnPoint
@onready var attack_shot_timer := $AttackShotTimer # <--- NOVO TIMER REFERENCIADO

# Pre-carrega a cena do projétil
const BulletScene = preload("res://scenes/enemies/soul/bullet.tscn") # Ajuste o caminho!

func _ready() -> void:
	vida_atual = vida_maxima
	# Conecta os sinais que vamos usar NO CÓDIGO (outros serão no editor)
	# (As conexões do _ready podem ser feitas no editor também, se preferir)
	detection_range.body_entered.connect(_on_detection_range_body_entered)
	detection_range.body_exited.connect(_on_detection_range_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	attack_shot_timer.timeout.connect(disparar_projetil) 

func _physics_process(delta: float) -> void:
	processar_ia(delta)
	move_and_slide()

# --- LÓGICA DE IA (MÁQUINA DE ESTADOS) ---
func processar_ia(delta: float) -> void:

	if player_ref == null and current_state != State.DEAD:
		current_state = State.IDLE

	match current_state:
		State.IDLE:
			sprite.play("idle")
			velocity = velocity.move_toward(Vector2.ZERO, velocidade * 0.1)
			if player_ref != null:
				current_state = State.CHASING

		State.CHASING:
			sprite.play("move")
			if player_ref == null:
				current_state = State.IDLE
				return

			var direcao = global_position.direction_to(player_ref.global_position)
			velocity = direcao * velocidade

			if direcao.x != 0:
				sprite.flip_h = (direcao.x < 0)

			var distancia = global_position.distance_to(player_ref.global_position)
			if distancia <= distancia_ataque and attack_cooldown_timer.is_stopped():
				current_state = State.ATTACKING
			elif distancia <= distancia_parar:
				velocity = Vector2.ZERO

		State.ATTACKING:
			velocity = Vector2.ZERO
			if sprite.animation != "attack":
				sprite.play("attack")
				# Inicia o timer para disparar o projétil no meio da animação
				attack_shot_timer.start(tempo_disparo_ataque) # <--- INICIA O TIMER DE DISPARO AQUI

		State.DEAD:
			velocity = Vector2.ZERO

# --- DISPARO ---
func disparar_projetil() -> void:
	# Não dispara se não estiver mais atacando (ex: tomou dano e mudou de estado)
	# ou se o jogador sumiu
	if current_state != State.ATTACKING or player_ref == null:
		# Garante que o cooldown não iniciou se o tiro falhou
		if not attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.stop()
		return

	var bullet_instance = BulletScene.instantiate()
	var direcao_disparo = global_position.direction_to(player_ref.global_position)

	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.iniciar(projectile_spawn_point.global_position, direcao_disparo)

	# Inicia o cooldown APÓS disparar
	attack_cooldown_timer.start(cooldown_ataque)

# --- SINAIS DE DETECÇÃO ---
func _on_detection_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body

func _on_detection_range_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null

# --- DANO E MORTE ---
func ser_atingido() -> void:
	if current_state == State.DEAD:
		return

	vida_atual -= 1
	print("Soul atingido! Vida restante: ", vida_atual)

	if vida_atual <= 0:
		morrer()
	else:
		# IMPORTANTE: Se o Soul tomar dano enquanto ataca, cancele o disparo
		if current_state == State.ATTACKING and not attack_shot_timer.is_stopped():
			attack_shot_timer.stop() # Cancela o timer de disparo
			# Decide para qual estado ir (pode ser IDLE, ou um estado HIT se criar)
			current_state = State.IDLE # Volta para idle após ser atingido
			sprite.play("idle") # Toca a animação idle (ou hit se tiver)

func morrer() -> void:
	if current_state == State.DEAD:
		return

	print("Soul derrotado!")
	current_state = State.DEAD
	velocity = Vector2.ZERO
	# Para timers caso esteja morrendo no meio do ataque
	attack_shot_timer.stop()
	attack_cooldown_timer.stop()
	collision_shape.set_deferred("disabled", true)
	detection_range.set_deferred("monitoring", false)
	sprite.play("death")

# --- SINAIS DE ANIMAÇÃO E TIMER ---
func _on_animation_finished() -> void:
	if sprite.animation == "death":
		queue_free()

	elif sprite.animation == "attack":
		if player_ref != null:
			current_state = State.CHASING
		else:
			current_state = State.IDLE

# Sinal do Timer de Cooldown
func _on_attack_cooldown_timer_timeout() -> void:
	print("Cooldown do ataque terminou!") # (Opcional: para depuração)
	pass # Não precisa mudar o estado aqui diretamente


func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.
