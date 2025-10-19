extends CharacterBody2D

# --- VARIÁVEIS DE MOVIMENTO ---
@export var velocidade := 300.0
@export var forca_do_pulo := -400.0
@export var gravidade := 1200.0
@export var desaceleracao := 1000.0
@export var gravidade_ataque_aereo_mult := 0.2

# --- WALL JUMP / SLIDE ---
@export var forca_pulo_parede := Vector2(300, -400)
@export var velocidade_deslizando := 40.0
@export var forca_pulo_neutro_x := 50.0

var esta_na_parede := false
var pulou_da_parede_neste_quadro := false

# --- DASH ---
@export var forca_dash := 600.0
@export var duracao_dash := 0.15
var pode_dar_dash := true
var esta_dando_dash := false
var direcao_dash := Vector2.ZERO

# --- ATAQUE ---
var esta_atacando := false
var current_attack_animation := ""

# --- REFERÊNCIAS DE NÓS ---
@onready var timer_dash := $DashTimer
@onready var animacao := $Animacao
@onready var hitbox := $Hitbox
@onready var attack_hitbox_timer := $AttackHitboxTimer
@onready var attack_duration_timer := $AttackDurationTimer

# --- REFERÊNCIAS DAS HITBOX SHAPES ---
@onready var hitbox_ground_shape := $Hitbox/GroundShape
@onready var hitbox_air_shape := $Hitbox/AirShape 

# --- PULO DUPLO ---
var saltos_restantes := 1
@export var max_saltos := 2


func _physics_process(delta: float) -> void:
	var direcao_input := Input.get_axis("mover_esquerda", "mover_direita")

	# --- LÓGICA DE ATAQUE (Prioridade 1) ---
	if Input.is_action_just_pressed("atacar") and not esta_atacando and not esta_na_parede and not esta_dando_dash:
		
		esta_atacando = true
		# velocity = Vector2.ZERO <-- LINHA REMOVIDA
		
		# Garante que ambas as hitboxes comecem desligadas
		hitbox_ground_shape.disabled = true
		hitbox_air_shape.disabled = true

		# Decide qual animação usar
		if is_on_floor():
			current_attack_animation = "attack01"
		else:
			current_attack_animation = "attack_air"

		# Calcula a duração do ataque
		var frame_count = animacao.sprite_frames.get_frame_count(current_attack_animation)
		var speed = animacao.sprite_frames.get_animation_speed(current_attack_animation)
		var duracao_ataque = frame_count / speed

		attack_duration_timer.start(duracao_ataque)
		attack_hitbox_timer.start(0.1) 

	# Se estiver atacando, força a animação, mas NÃO PARA a física
	if esta_atacando:
		atualizar_animacoes(0.0) 
		# return <-- LINHA REMOVIDA

	# --- FIM DA LÓGICA DE ATAQUE ---

	# --- GRAVIDADE (MODIFICADA) ---
	if not is_on_floor() and not esta_dando_dash:
		# Se estiver atacando no ar, aplica gravidade reduzida
		if esta_atacando:
			velocity.y += (gravidade * gravidade_ataque_aereo_mult) * delta
		else:
			# Gravidade normal
			velocity.y += gravidade * delta

	# --- MOVIMENTO HORIZONTAL (MODIFICADO) ---
	if not esta_dando_dash and not pulou_da_parede_neste_quadro:
		
		# Se estiver atacando (no ar ou chão), perde o controle horizontal
		if esta_atacando and not is_on_floor():
			# No ar: O jogador não controla, apenas desacelera lentamente
			# (Mantém um pouco do ímpeto do pulo)
			velocity.x = move_toward(velocity.x, 0.0, (desaceleracao * 0.2) * delta)
		elif esta_atacando and is_on_floor():
			# No chão: Trava o movimento horizontal
			velocity.x = move_toward(velocity.x, 0.0, desaceleracao * delta)
		else:
			# Controle normal
			velocity.x = move_toward(velocity.x, direcao_input * velocidade, desaceleracao * delta)

	# --- RESETAR SALTOS NO CHÃO ---
	if is_on_floor() and not esta_dando_dash:
		saltos_restantes = max_saltos
		pode_dar_dash = true

	# --- WALL GRAB / SLIDE ---
	var segurando_grudar = Input.is_action_pressed("grudar_parede")
	var tocando_parede = is_on_wall() and not is_on_floor()

	if tocando_parede and direcao_input != 0 and sign(direcao_input) == -get_wall_normal().x:
		esta_na_parede = true
		if segurando_grudar:
			velocity.y = 0
		else:
			velocity.y = move_toward(velocity.y, velocidade_deslizando, gravidade * delta)
	else:
		esta_na_parede = false

	# --- PULO ---
	if Input.is_action_just_pressed("pular"):
		if esta_na_parede:
			var direcao_parede = get_wall_normal().x
			if direcao_input == 0:
				velocity.x = direcao_parede * forca_pulo_neutro_x
			else:
				velocity.x = direcao_parede * forca_pulo_parede.x
			velocity.y = forca_pulo_parede.y
			
			pulou_da_parede_neste_quadro = true
			pode_dar_dash = true
			esta_na_parede = false
			saltos_restantes = max_saltos - 1
			
		elif saltos_restantes > 0:
			velocity.y = forca_do_pulo
			saltos_restantes -= 1

	# --- DASH ---
	if Input.is_action_just_pressed("dash") and pode_dar_dash:
		pode_dar_dash = false
		esta_dando_dash = true
		direcao_dash = Vector2(Input.get_axis("mover_esquerda", "mover_direita"), Input.get_axis("mover_cima", "mover_baixo"))
		
		if direcao_dash == Vector2.ZERO:
			direcao_dash = Vector2(sign(velocity.x), 0)
			if direcao_dash == Vector2.ZERO:
				direcao_dash = Vector2.LEFT if animacao.flip_h else Vector2.RIGHT

		velocity = direcao_dash.normalized() * forca_dash
		timer_dash.start(duracao_dash)

	move_and_slide()
	
	# Só atualiza animações se NÃO estiver atacando (pois já foi feito acima)
	if not esta_atacando:
		atualizar_animacoes(direcao_input)

	if pulou_da_parede_neste_quadro:
		await get_tree().create_timer(0.1).timeout
		pulou_da_parede_neste_quadro = false


# --- TIMERS E SINAIS ---

func _on_dash_timer_timeout():
	esta_dando_dash = false
	velocity.x *= 0.5

# Este timer é chamado quando a ANIMAÇÃO INTEIRA de ataque acaba
func _on_attack_duration_timer_timeout():
	esta_atacando = false 
	current_attack_animation = "" 
	
	# Garante que ambas as hitboxes sejam desligadas
	hitbox.monitoring = false
	hitbox_ground_shape.disabled = true
	hitbox_air_shape.disabled = true

# Este timer é chamado no MEIO da animação (quando o golpe acerta)
func _on_attack_hitbox_timer_timeout():
	hitbox.monitoring = true

	if current_attack_animation == "attack01":
		hitbox_ground_shape.disabled = false
	elif current_attack_animation == "attack_air":
		hitbox_air_shape.disabled = false

	await get_tree().create_timer(0.15).timeout
	
	hitbox.monitoring = false
	hitbox_ground_shape.disabled = true
	hitbox_air_shape.disabled = true
	
# --- SINAL DA HITBOX (CONECTE NO EDITOR) ---
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("ser_atingido"):
		body.ser_atingido()
	
func _on_animacao_animation_finished() -> void:
	if animacao.animation == "wallSick":
		animacao.play("wall_slide_loop")


# --- FUNÇÃO PRINCIPAL DE ANIMAÇÃO ---

func atualizar_animacoes(direcao: float) -> void:
	
	# Prioridade MÁXIMA: Atacando
	if esta_atacando:
		animacao.play(current_attack_animation)
		return 
	
	# --- LÓGICA DE VIRAR O SPRITE (FLIP_H) ---
	if esta_dando_dash:
		if direcao_dash.x > 0:
			animacao.flip_h = false 
		elif direcao_dash.x < 0:
			animacao.flip_h = true  
	elif esta_na_parede:
		animacao.flip_h = get_wall_normal().x > 0
	else:
		if direcao > 0:
			animacao.flip_h = false
		elif direcao < 0:
			animacao.flip_h = true 

	# --- LÓGICA DE VIRAR A HITBOX ---
	if animacao.flip_h:
		hitbox.scale.x = -1 
	else:
		hitbox.scale.x = 1  
	
	
	# --- LÓGICA DE QUAL ANIMAÇÃO TOCAR (POR PRIORIDADE) ---
	if pulou_da_parede_neste_quadro:
		animacao.play("wallSickOff") 
	elif esta_dando_dash:
		if direcao_dash.y < 0:
			animacao.play("jump") 
		elif direcao_dash.y > 0:
			animacao.play("fall")
		else:
			animacao.play("dash")
	elif esta_na_parede:
		if animacao.animation != "wallSick" and animacao.animation != "wall_slide_loop":
			animacao.play("wallSick")
	elif not is_on_floor():
		if velocity.y < 0:
			animacao.play("jump")
		else:
			animacao.play("fall")
	elif direcao != 0:
		animacao.play("run")
	else:
		animacao.play("idle")
