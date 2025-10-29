extends CharacterBody2D

# --- ESTADOS DA IA ---
enum State { PATROL, WALKING, ATTACKING, HIT, DEAD }
var current_state = State.PATROL

# --- VIDA DO INIMIGO ---
@export var vida_maxima: int = 5
var vida_atual: int

# --- FÍSICA E IA ---
var gravidade: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var velocidade: float = 100.0
@export var forca_pulo: float = -300.0
var patrol_direction: int = 1

# --- DETECÇÃO DE TRAVAMENTO ---
var last_position: Vector2
var time_stuck: float = 0.0
@export var tempo_limite_travado: float = 5.0  # tempo em segundos antes de virar por estar "travado"

# --- DETECÇÃO DE PAREDE ---
@export var flip_cooldown: float = 0.3  # evita flips muito rápidos repetidos
var flip_cooldown_timer: float = 0.0

# --- REFERÊNCIAS ---
var player_ref: Node2D = null
@onready var sprite := $AnimatedSprite2D
@onready var wall_detector := $WallDetector
@onready var gap_detector := $GapDetector
@onready var detection_range := $DetectionRange
@onready var collision_shape := $CollisionShape2D
@onready var attack_hitbox := $AnimatedSprite2D/AttackHitbox 
@onready var attack_delay_timer := $AttackDelayTimer

func _ready() -> void:
	vida_atual = vida_maxima
	last_position = global_position
	detection_range.body_entered.connect(_on_detection_range_body_entered)
	detection_range.body_exited.connect(_on_detection_range_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if flip_cooldown_timer > 0.0:
		flip_cooldown_timer = max(0.0, flip_cooldown_timer - delta)

	if current_state != State.DEAD and not is_on_floor():
		velocity.y += gravidade * delta

	processar_ia(delta)
	move_and_slide()

# --- LÓGICA DE IA ---
func processar_ia(delta: float) -> void:
	if player_ref == null and current_state not in [State.DEAD, State.HIT, State.ATTACKING]:
		current_state = State.PATROL

	match current_state:
		State.PATROL:
			sprite.play("walk")
			velocity.x = patrol_direction * (velocidade * 0.5)

			# --- 1) Detecção de travamento ---
			if abs(global_position.x - last_position.x) < 2.0:
				time_stuck += delta
			else:
				time_stuck = 0.0

			if time_stuck >= tempo_limite_travado:
				_inverter_direcao()
				time_stuck = 0.0

			# --- 2) Detecção de parede ---
			if (is_on_wall() or wall_detector.is_colliding()) and flip_cooldown_timer <= 0.0:
				_inverter_direcao()
				time_stuck = 0.0

			last_position = global_position
			_atualizar_direcao_visual()

			if player_ref != null:
				current_state = State.WALKING

		State.WALKING:
			sprite.play("walk")

			if player_ref == null:
				current_state = State.PATROL
				return

			var direcao_x = sign(player_ref.global_position.x - global_position.x)
			
			if direcao_x != 0:
				patrol_direction = direcao_x
				_atualizar_direcao_visual()

			# --- Pulo durante perseguição ---
			if is_on_floor():
				if wall_detector.is_colliding() or not gap_detector.is_colliding():
					velocity.y = forca_pulo
			
			velocity.x = direcao_x * velocidade
			
			var distancia = global_position.distance_to(player_ref.global_position)
			if distancia < 200.0:
				current_state = State.ATTACKING

		State.ATTACKING:
			velocity.x = 0
			if sprite.animation != "attack": 
				sprite.play("attack")
				attack_delay_timer.start(0.5)

		State.HIT:
			velocity.x = 0

		State.DEAD:
			velocity.x = 0

# --- AUXILIARES ---
func _inverter_direcao():
	patrol_direction *= -1
	flip_cooldown_timer = flip_cooldown
	last_position = global_position

func _atualizar_direcao_visual():
	sprite.flip_h = (patrol_direction < 0)
	var dir_local = 1 if not sprite.flip_h else -1
	attack_hitbox.scale.x = dir_local
	wall_detector.target_position.x = abs(wall_detector.target_position.x) * dir_local
	gap_detector.target_position.x = abs(gap_detector.target_position.x) * dir_local

# --- DETECÇÃO ---
func _on_detection_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body

func _on_detection_range_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null

# --- ATAQUE ---
func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("tomar_dano"):
			body.tomar_dano(1)

# --- DANO ---
func ser_atingido() -> void:
	if current_state in [State.HIT, State.DEAD]:
		return

	vida_atual -= 1
	if vida_atual <= 0:
		morrer()
	else:
		current_state = State.HIT
		sprite.play("hit")

func morrer() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.DEAD
	collision_shape.set_deferred("disabled", true)
	detection_range.set_deferred("monitoring", false)
	sprite.play("death")

# --- ANIMAÇÕES ---
func _ativar_hitbox_ataque() -> void:
	attack_hitbox.monitoring = true

func _desativar_hitbox_ataque() -> void:
	attack_hitbox.set_deferred("monitoring", false)

func _on_animation_finished() -> void:
	match sprite.animation:
		"death":
			queue_free()
		"attack", "hit":
			attack_hitbox.set_deferred("monitoring", false)
			current_state = State.PATROL

func _on_attack_delay_timer_timeout() -> void:
	if current_state == State.ATTACKING:
		attack_hitbox.monitoring = true
