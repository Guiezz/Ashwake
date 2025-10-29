extends CharacterBody2D

# --- ESTADOS DA IA ---
enum State { PATROL, CHASING, ATTACKING, DEAD } # <--- atualizado
var current_state = State.PATROL # <--- atualizado

# --- VIDA DO INIMIGO ---
@export var vida_maxima: int = 3
var vida_atual: int

# --- IA E MOVIMENTO ---
@export var velocidade: float = 100.0
@export var distancia_ataque: float = 250.0
@export var distancia_parar: float = 180.0
@export var patrol_range: float = 200.0 # <--- novo
@export var cooldown_ataque: float = 1.5
@export var tempo_disparo_ataque: float = 0.3

var start_position: Vector2 # <--- novo
var patrol_target: Vector2 # <--- novo

# Referência para o jogador
var player_ref: CharacterBody2D = null

# Referências dos nós
@onready var sprite := $AnimatedSprite2D
@onready var detection_range := $DetectionRange
@onready var collision_shape := $CollisionShape2D
@onready var attack_cooldown_timer := $AttackCooldownTimer
@onready var projectile_spawn_point := $ProjectileSpawnPoint
@onready var attack_shot_timer := $AttackShotTimer

# Cena do projétil
const BulletScene = preload("res://scenes/enemies/soul/bullet.tscn")

func _ready() -> void:
	vida_atual = vida_maxima
	start_position = global_position # <--- novo
	patrol_target = start_position + Vector2(patrol_range, 0) # <--- novo
	
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

	if player_ref == null and current_state != State.DEAD and current_state != State.ATTACKING:
		current_state = State.PATROL # <--- atualizado

	match current_state:
		State.PATROL: # <--- substitui o antigo IDLE
			sprite.play("move")

			var direcao = global_position.direction_to(patrol_target)
			velocity = direcao * (velocidade * 0.3) # patrulha mais lenta

			if direcao.x != 0:
				sprite.flip_h = (direcao.x < 0)

			# Inverte o ponto de patrulha ao chegar perto
			if global_position.distance_to(patrol_target) < 10.0:
				if patrol_target == start_position:
					patrol_target = start_position + Vector2(patrol_range, 0)
				else:
					patrol_target = start_position

			# Detecção de jogador
			if player_ref != null:
				current_state = State.CHASING

		State.CHASING:
			sprite.play("move")
			if player_ref == null:
				current_state = State.PATROL # <--- atualizado
				return

			var direcao = global_position.direction_to(player_ref.global_position)
			velocity = direcao * velocidade

			if direcao.x != 0:
				sprite.flip_h = (direcao.x < 0)

			var distancia = global_position.distance_to(player_ref.global_position)

			# Pode atacar?
			if distancia <= distancia_ataque and attack_cooldown_timer.is_stopped():
				current_state = State.ATTACKING
			elif distancia <= distancia_parar:
				velocity = Vector2.ZERO

		State.ATTACKING:
			velocity = Vector2.ZERO
			if sprite.animation != "attack":
				sprite.play("attack")
				attack_shot_timer.start(tempo_disparo_ataque)

		State.DEAD:
			velocity = Vector2.ZERO

# --- DISPARO ---
func disparar_projetil() -> void:
	# Não dispara se não estiver mais atacando ou se o jogador sumiu
	if current_state != State.ATTACKING or player_ref == null:
		if not attack_cooldown_timer.is_stopped():
			attack_cooldown_timer.stop()
		return

	var bullet_instance = BulletScene.instantiate()
	var direcao_disparo = global_position.direction_to(player_ref.global_position)

	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.iniciar(projectile_spawn_point.global_position, direcao_disparo)

	attack_cooldown_timer.start(cooldown_ataque)
	print("Projétil disparado! Cooldown iniciado.")

# --- DETECÇÃO ---
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

	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if sprite:
		sprite.modulate = Color.WHITE

	if vida_atual <= 0:
		morrer()
	else:
		# Cancela ataque se for atingido durante o disparo
		if current_state == State.ATTACKING and not attack_shot_timer.is_stopped():
			attack_shot_timer.stop()
			current_state = State.PATROL # <--- atualizado
			sprite.play("move") # <--- atualizado

func morrer() -> void:
	if current_state == State.DEAD:
		return

	print("Soul derrotado!")
	current_state = State.DEAD
	velocity = Vector2.ZERO
	attack_shot_timer.stop()
	attack_cooldown_timer.stop()
	collision_shape.set_deferred("disabled", true)
	detection_range.set_deferred("monitoring", false)
	sprite.play("death")

# --- ANIMAÇÕES E TIMERS ---
func _on_animation_finished() -> void:
	if sprite.animation == "death":
		queue_free()

	elif sprite.animation == "attack":
		# Após atacar, volta a perseguir se o jogador ainda estiver no range
		if player_ref != null:
			current_state = State.CHASING
		else:
			current_state = State.PATROL # <--- atualizado

func _on_attack_cooldown_timer_timeout() -> void:
	pass
