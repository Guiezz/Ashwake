extends CharacterBody2D

# --- ESTADOS DA IA ---
enum State { IDLE, CHASE, ATTACK_MELEE, CAST_SPELL, HURT, DEAD }
var current_state = State.IDLE

# --- CONFIGURAÇÕES DO BOSS ---
@export_group("Status")
@export var vida_maxima: int = 30
@export var xp_value: int = 100
var vida_atual: int

@export_group("Movimento")
@export var velocidade: float = 70.0
@export var gravidade: float = 980.0

@export_group("Combate")
@export var distancia_melee: float = 100.0 
@export var distancia_cast: float = 350.0
@export var cooldown_melee: float = 2.0
@export var cooldown_cast: float = 4.0
@export var spell_scene: PackedScene

# --- AJUSTES VISUAIS ---
@export_group("Ajustes Visuais")
@export var sprite_offset_x: float = 0.0 

# --- REFERÊNCIAS INTERNAS ---
var player_ref: Node2D = null
var pode_atacar_melee: bool = true
var pode_castar: bool = true

# Guarde as posições ORIGINAIS (com sinal!)
var hitbox_x_padrao: float = 0.0
var spell_point_x_padrao: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_range: Area2D = $DetectionRange
@onready var attack_hitbox: Area2D = $AnimatedSprite2D/AttackHitbox 
@onready var spell_spawn_point: Marker2D = $SpellSpawnPoint 
@onready var melee_timer: Timer = $MeleeTimer
@onready var cast_timer: Timer = $CastTimer

func _ready() -> void:
	vida_atual = vida_maxima
	
	# Salva posições ORIGINAIS (com sinal!)
	if attack_hitbox:
		hitbox_x_padrao = attack_hitbox.position.x
		attack_hitbox.monitoring = false
		if not attack_hitbox.body_entered.is_connected(_on_melee_hitbox_entered):
			attack_hitbox.body_entered.connect(_on_melee_hitbox_entered)

	if spell_spawn_point:
		spell_point_x_padrao = spell_spawn_point.position.x

	# Timers
	if melee_timer: melee_timer.timeout.connect(func(): pode_atacar_melee = true)
	if cast_timer: cast_timer.timeout.connect(func(): pode_castar = true)

	# Detecção
	if detection_range:
		detection_range.body_entered.connect(func(b):
			if b.is_in_group("player"): player_ref = b)

		detection_range.body_exited.connect(func(b):
			if b == player_ref: player_ref = null)

	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravidade * delta

	if current_state == State.DEAD:
		move_and_slide()
		return

	if current_state not in [State.HURT, State.ATTACK_MELEE, State.CAST_SPELL]:
		processar_ia(delta)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade * delta)

	move_and_slide()
	atualizar_animacao()


func processar_ia(_delta: float) -> void:
	if not player_ref:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, 10)
		return

	var distancia = global_position.distance_to(player_ref.global_position)
	var direcao_x = sign(player_ref.global_position.x - global_position.x)
	
	if direcao_x != 0:
		virar_sprite(direcao_x)

	if distancia <= distancia_melee and pode_atacar_melee:
		iniciar_ataque_melee()
	elif distancia <= distancia_cast and pode_castar:
		iniciar_cast()
	else:
		current_state = State.CHASE
		velocity.x = direcao_x * velocidade


# --- VIRAR SPRITE (FINALMENTE CORRETO) ---
func virar_sprite(dir_x: int) -> void:
	var facing = 1 if dir_x > 0 else -1   # +1 = direita, -1 = esquerda

	# Flip visual
	sprite.flip_h = facing == 1

	# Aplica offset visual
	# OBS: se ficar invertido, troque o sinal (+/-)
	sprite.position.x = sprite_offset_x * facing

	# Move hitbox e spell spawn simetricamente
	if attack_hitbox:
		attack_hitbox.position.x = hitbox_x_padrao * facing

	if spell_spawn_point:
		spell_spawn_point.position.x = spell_point_x_padrao * facing


func iniciar_ataque_melee() -> void:
	current_state = State.ATTACK_MELEE
	velocity.x = 0
	sprite.play("attack")
	pode_atacar_melee = false
	melee_timer.start(cooldown_melee)

	await get_tree().create_timer(0.5).timeout
	if current_state == State.ATTACK_MELEE:
		attack_hitbox.monitoring = true
		await get_tree().create_timer(0.3).timeout
		attack_hitbox.set_deferred("monitoring", false)


func iniciar_cast() -> void:
	current_state = State.CAST_SPELL
	velocity.x = 0
	sprite.play("cast")
	pode_castar = false
	cast_timer.start(cooldown_cast)

	await get_tree().create_timer(0.6).timeout
	if current_state == State.CAST_SPELL:
		invocar_magia_no_ceu()


func invocar_magia_no_ceu() -> void:
	if spell_scene and player_ref:
		var spell = spell_scene.instantiate()
		get_tree().current_scene.add_child(spell)

		var pos_alvo = player_ref.global_position
		pos_alvo.y -= 65 
		
		spell.global_position = pos_alvo


func _on_melee_hitbox_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("tomar_dano"):
		body.tomar_dano(2)


func ser_atingido(dano: int = 1) -> void:
	if current_state == State.DEAD: return
	
	vida_atual -= dano
	
	# Efeito visual de dano (Flash Vermelho)
	sprite.modulate = Color(10, 0, 0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	if vida_atual <= 0:
		morrer()


func morrer() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	sprite.play("death")
	
	$CollisionShape2D.set_deferred("disabled", true)
	attack_hitbox.set_deferred("monitoring", false)
	detection_range.monitoring = false

	if has_node("/root/Singleton"):
		get_node("/root/Singleton").add_xp_to_run(xp_value)


func atualizar_animacao() -> void:
	if current_state == State.CHASE:
		sprite.play("walk")
	elif current_state == State.IDLE:
		sprite.play("idle")


func _on_animation_finished() -> void:
	if sprite.animation == "death":
		return
	elif sprite.animation in ["attack", "cast"]:
		current_state = State.IDLE
