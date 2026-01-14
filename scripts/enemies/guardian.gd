extends CharacterBody2D

# --- ESTADOS ---
enum State { PATROL, CHASING, MELEE_ATTACK, RANGED_ATTACK, HIT, DEATH }
var current_state = State.PATROL

# --- CONFIGURAÇÕES ---
@export_group("Status")
@export var vida_maxima: int = 8
@export var xp_value: int = 15
var vida_atual: int

@export_group("Movimento")
@export var velocidade_patrulha: float = 60.0
@export var velocidade_perseguicao: float = 110.0
@export var gravidade: float = 980.0
@export var tempo_espera_virada: float = 5.0

@export_group("Combate")
# AUMENTADO PARA 130: Margem de segurança para garantir que ele alcance o player
@export var distancia_ataque_melee: float = 160.0  
@export var distancia_ataque_ranged: float = 300.0 
@export var cooldown_ataque: float = 1.5
@export var knockback_recebido: float = 200.0
@export var projectile_scene: PackedScene = preload("res://scenes/enemies/guardian/guardian_spit.tscn")
@onready var blood_particles := $BloodParticles # adicione este nó na cena!


# --- VARIÁVEIS INTERNAS ---
var player_ref: Node2D = null
var direcao_patrulha: int = 1
var knockback_timer: float = 0.0
var timer_espera_patrulha: float = 0.0
var hitbox_pos_x_padrao: float = 0.0 # Memoriza a posição original da hitbox

# --- REFERÊNCIAS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_range: Area2D = $DetectionRange
@onready var wall_detector: RayCast2D = $WallDetector
@onready var floor_detector: RayCast2D = $FloorDetector
@onready var spit_spawn_point: Marker2D = $SpitSpawnPoint
@onready var attack_timer: Timer = $AttackCooldownTimer

# Pega a Hitbox mesmo sendo filha do Sprite
@onready var attack_hitbox: Area2D = $AnimatedSprite2D/AttackHitbox

func _ready() -> void:
	vida_atual = vida_maxima
	
	# Salva a posição X positiva (direita) da hitbox para referência
	if attack_hitbox:
		hitbox_pos_x_padrao = abs(attack_hitbox.position.x)
		attack_hitbox.monitoring = false
		attack_hitbox.body_entered.connect(_on_melee_hitbox_entered)
	
	if attack_timer:
		attack_timer.one_shot = true # <--- ADICIONE ISSO!
	
	detection_range.body_entered.connect(_on_detection_entered)
	detection_range.body_exited.connect(_on_detection_exited)
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta

	if current_state == State.DEATH:
		move_and_slide()
		return

	if current_state == State.HIT:
		_processar_knockback(delta)
	else:
		_processar_ia(delta)

	move_and_slide()
	_atualizar_animacao()

func _processar_ia(delta: float) -> void:
	match current_state:
		State.PATROL:
			velocity.x = direcao_patrulha * velocidade_patrulha
			
			if timer_espera_patrulha > 0:
				timer_espera_patrulha -= delta
			
			if timer_espera_patrulha <= 0:
				var bateu_parede = is_on_wall()
				var vai_cair = is_on_floor() and not floor_detector.is_colliding()
				
				if bateu_parede or vai_cair:
					direcao_patrulha *= -1
					_virar_tudo(direcao_patrulha)
					timer_espera_patrulha = tempo_espera_virada 
			
			# 4. Se viu o player, muda para perseguição
			if player_ref:
				current_state = State.CHASING
				timer_espera_patrulha = 0

		State.CHASING:
			if not player_ref:
				current_state = State.PATROL
				return

			var dist = global_position.distance_to(player_ref.global_position)
			print("Distância: ", dist, " | Melee Max: ", distancia_ataque_melee)
			var dir_x = sign(player_ref.global_position.x - global_position.x)
			
			_virar_tudo(dir_x)
			
			if attack_timer.is_stopped():
				# LÓGICA CORRIGIDA: Prioridade total para o Melee
				# Se está perto o suficiente para o soco (mesmo que colado), SOCA.
				if dist <= distancia_ataque_melee:
					print("TENTANDO MELEE! Distância: ", dist)
					_iniciar_ataque("attack_1", State.MELEE_ATTACK)
				
				# Se não, verifica se está na distância de tiro
				elif dist <= distancia_ataque_ranged:
					print("TENTANDO RANGED! Distância: ", dist)
					_iniciar_ataque("spit", State.RANGED_ATTACK)
				
				# Se não, corre atrás
				else:
					velocity.x = dir_x * velocidade_perseguicao
			else:
				# Em cooldown: Se estiver muito perto, para. Senão, persegue.
				if dist < distancia_ataque_melee - 20:
					velocity.x = 0
				else:
					velocity.x = dir_x * velocidade_perseguicao

		State.MELEE_ATTACK, State.RANGED_ATTACK:
			velocity.x = 0

# --- FUNÇÃO DE VIRAR CORRIGIDA ---
# --- FUNÇÃO DE VIRAR CORRIGIDA ---
func _virar_tudo(dir: int) -> void:
	if dir == 0: return
	
	# 1. Vira o Sprite (Visual)
	sprite.flip_h = (dir < 0)
	
	# 2. Define o multiplicador (1 para direita, -1 para esquerda)
	var multiplier = -1 if sprite.flip_h else 1
	
	# 3. Vira a Hitbox MANUALMENTE
	if attack_hitbox:
		attack_hitbox.position.x = hitbox_pos_x_padrao * multiplier
		
	# 4. Vira os Detectores e Spawn Points
	wall_detector.target_position.x = abs(wall_detector.target_position.x) * multiplier
	floor_detector.position.x = abs(floor_detector.position.x) * multiplier
	spit_spawn_point.position.x = abs(spit_spawn_point.position.x) * multiplier
	
	# 5. --- CORREÇÃO: Vira o DetectionRange ---
	# Isso garante que o inimigo continue vendo o player ao virar
	if detection_range:
		# Se a colisão do DetectionRange tiver um offset na posição X:
		detection_range.position.x = abs(detection_range.position.x) * multiplier
		# Se você usou scale.x no passado para virar, pode usar: detection_range.scale.x = multiplier

func _iniciar_ataque(anim: String, state: State) -> void:
	current_state = state
	velocity.x = 0
	sprite.play(anim)
	attack_timer.start(cooldown_ataque)
	
	# Backup de ativação de hitbox (caso a animação falhe)
	if state == State.MELEE_ATTACK:
		await get_tree().create_timer(0.4).timeout # Ajuste este tempo conforme a animação
		if current_state == State.MELEE_ATTACK:
			attack_hitbox.monitoring = true
			await get_tree().create_timer(0.2).timeout
			attack_hitbox.set_deferred("monitoring", false)
	elif state == State.RANGED_ATTACK:
		# Espera um tempo para a animação abrir a boca (ajuste o 0.4 conforme necessário)
		await get_tree().create_timer(0.4).timeout
		
		# Verifica se o inimigo não morreu ou tomou dano durante a espera
		if current_state == State.RANGED_ATTACK:
			disparar_projetil()

# --- OUTRAS FUNÇÕES (Dano, Morte, Projétil) ---
func disparar_projetil() -> void:
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		var dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		if proj.has_method("iniciar"):
			proj.iniciar(spit_spawn_point.global_position, dir)

func _on_detection_entered(body: Node2D) -> void:
	if body.is_in_group("player"): player_ref = body

func _on_detection_exited(body: Node2D) -> void:
	if body == player_ref: player_ref = null

func _on_melee_hitbox_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("tomar_dano"):
		print("DANO APLICADO NO PLAYER")
		body.tomar_dano(1, self)

func ser_atingido(dano: int = 1, origem: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEATH: return
	vida_atual -= dano
	if vida_atual <= 0:
		morrer()
	else:
		current_state = State.HIT
		sprite.play("hit")
		knockback_timer = 0.3
		var dir = sign(global_position.x - origem.x)
		if dir == 0: dir = -direcao_patrulha
		velocity.x = dir * knockback_recebido
		velocity.y = -150
		
	if blood_particles:
		blood_particles.global_position = global_position
		blood_particles.scale.x = 1 if sprite.flip_h else 1
		blood_particles.emitting = false
		blood_particles.restart()
		blood_particles.emitting = true

func _processar_knockback(delta: float) -> void:
	knockback_timer -= delta
	velocity.x = lerp(velocity.x, 0.0, delta * 5.0)
	if knockback_timer <= 0.0:
		current_state = State.CHASING if player_ref else State.PATROL

func morrer() -> void:
	current_state = State.DEATH
	velocity = Vector2.ZERO
	sprite.play("death")
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	attack_hitbox.set_deferred("monitoring", false)
	detection_range.monitoring = false
	if has_node("/root/Singleton"):
		get_node("/root/Singleton").add_xp_to_run(xp_value)

func _on_animation_finished() -> void:
	var anim = sprite.animation
	if anim == "death":
		queue_free()
	elif anim in ["attack_1", "spit", "hit"]:
		if player_ref:
			current_state = State.CHASING
		else:
			current_state = State.PATROL

func _atualizar_animacao() -> void:
	if current_state == State.PATROL or current_state == State.CHASING:
		if velocity.x != 0:
			sprite.play("walk")
		else:
			sprite.play("idle")
