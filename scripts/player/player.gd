extends CharacterBody2D

# --- VARIÁVEIS DE MOVIMENTO ---
@export var velocidade := 300.0
@export var forca_do_pulo := -400.0
@export var gravidade := 1200.0
@export var desaceleracao := 1000.0

# --- WALL JUMP / SLIDE ---
@export var forca_pulo_parede := Vector2(300, -400)
@export var velocidade_deslizando := 40.0
@export var forca_pulo_neutro_x := 50.0 # Pequeno impulso horizontal para o pulo neutro

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

# --- REFERÊNCIAS DE NÓS ---
@onready var timer_dash := $DashTimer
@onready var animacao := $Animacao
@onready var hitbox := $Hitbox
@onready var attack_hitbox_timer := $AttackHitboxTimer
@onready var attack_duration_timer := $AttackDurationTimer

# --- PULO DUPLO ---
var saltos_restantes := 1
@export var max_saltos := 2


func _physics_process(delta: float) -> void:
	var direcao_input := Input.get_axis("mover_esquerda", "mover_direita")

	# --- LÓGICA DE ATAQUE (Prioridade 1) ---
	# (MOVIDO PARA CIMA PARA TRAVAR A FÍSICA)
	
	# 1. Verifica se o jogador quer atacar
	if Input.is_action_just_pressed("atacar") and not esta_atacando and not esta_na_parede and not esta_dando_dash:
		if is_on_floor():
			esta_atacando = true
			velocity = Vector2.ZERO # Trava o jogador no lugar

			# Pega a duração da animação de ataque
			var frame_count = animacao.sprite_frames.get_frame_count("attack01")
			var speed = animacao.sprite_frames.get_animation_speed("attack01")
			var duracao_ataque = frame_count / speed

			# Inicia o timer de DURAÇÃO TOTAL do ataque
			attack_duration_timer.start(duracao_ataque)

			# Inicia o timer da HITBOX (quando o golpe acerta)
			# !! AJUSTE ESSE NÚMERO (0.1) !! 
			# Deve ser o tempo (em segundos) até o frame do golpe
			attack_hitbox_timer.start(0.1)

	# 2. Se estiver atacando, trava todo o resto
	if esta_atacando:
		atualizar_animacoes(0.0) # Força a atualização da animação
		return # Pula o resto do _physics_process (gravidade, movimento, etc.)

	# --- FIM DA LÓGICA DE ATAQUE ---


	# --- GRAVIDADE ---
	if not is_on_floor() and not esta_dando_dash:
		velocity.y += gravidade * delta

	# --- MOVIMENTO HORIZONTAL ---
	if not esta_dando_dash and not pulou_da_parede_neste_quadro:
		velocity.x = move_toward(velocity.x, direcao_input * velocidade, desaceleracao * delta)

	# --- RESETAR SALTOS NO CHÃO ---
	# (Corrigido para não recarregar o dash durante um dash)
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

	# --- PULO (SEÇÃO MODIFICADA) ---
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
			saltos_restantes = max_saltos - 1 # Pular da parede consome um pulo
			
		elif saltos_restantes > 0:
			velocity.y = forca_do_pulo
			saltos_restantes -= 1

	# --- DASH ---
	if Input.is_action_just_pressed("dash") and pode_dar_dash:
		pode_dar_dash = false
		esta_dando_dash = true
		direcao_dash = Vector2(Input.get_axis("mover_esquerda", "mover_direita"), Input.get_axis("mover_cima", "mover_baixo"))
		
		if direcao_dash == Vector2.ZERO:
			# 1º Fallback: Tenta usar a velocidade atual
			direcao_dash = Vector2(sign(velocity.x), 0)
			
			# 2º Fallback (Corrigido): Se ainda for zero, usa a direção que o sprite está olhando
			if direcao_dash == Vector2.ZERO:
				if animacao.flip_h: # Se está olhando para a esquerda
					direcao_dash = Vector2.LEFT
				else: # Se está olhando para a direita
					direcao_dash = Vector2.RIGHT

		velocity = direcao_dash.normalized() * forca_dash
		timer_dash.start(duracao_dash)

	move_and_slide()
	
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
	esta_atacando = false # Libera o jogador para se mover
	hitbox.monitoring = false # Garante que a hitbox seja desligada

# Este timer é chamado no MEIO da animação (quando o golpe acerta)
func _on_attack_hitbox_timer_timeout():
	# 1. Liga a hitbox
	hitbox.monitoring = true

	# 2. Desliga a hitbox logo depois
	# !! AJUSTE ESSE NÚMERO (0.15) !!
	# É o tempo que a hitbox ficará "ativa"
	await get_tree().create_timer(0.15).timeout
	hitbox.monitoring = false
	
func _on_animacao_animation_finished() -> void:
	# (Corrigido o nome da animação para bater com o seu código)
	if animacao.animation == "wallSick":
		# (Use o nome exato da sua animação de loop de deslizar)
		animacao.play("wall_slide_loop")


# --- FUNÇÃO PRINCIPAL DE ANIMAÇÃO ---

func atualizar_animacoes(direcao: float) -> void:
	
	# Prioridade MÁXIMA: Atacando
	if esta_atacando:
		animacao.play("attack01") # (Use o nome da sua animação de attack)
		return # Trava a animação no ataque
	
	# --- LÓGICA DE VIRAR O SPRITE (FLIP_H) ---
	
	# 1. Se estiver dando dash, use a direção do dash
	if esta_dando_dash:
		if direcao_dash.x > 0:
			animacao.flip_h = false # Dash para direita
		elif direcao_dash.x < 0:
			animacao.flip_h = true  # Dash para esquerda
		# Se direcao_dash.x == 0 (dash reto p/ cima ou baixo), mantém o flip anterior
	
	# 2. Se estiver na parede
	elif esta_na_parede:
		animacao.flip_h = get_wall_normal().x > 0 # Força a olhar p/ longe da parede

	# 3. Lógica Padrão (correndo, pulando, parado)
	else:
		if direcao > 0:
			animacao.flip_h = false # Olhando para a direita
		elif direcao < 0:
			animacao.flip_h = true  # Olhando para a esquerda

	
	# --- LÓGICA DE QUAL ANIMAÇÃO TOCAR (POR PRIORIDADE) ---

	# Prioridade 1: Acabou de pular da parede?
	if pulou_da_parede_neste_quadro:
		animacao.play("wallSickOff") # (Use seu nome exato)

	# Prioridade 2: Está dando dash?
	elif esta_dando_dash:
		if direcao_dash.y < 0:
			animacao.play("jump") 
		elif direcao_dash.y > 0:
			animacao.play("fall")
		else:
			animacao.play("dash")

	# Prioridade 3: Está na parede?
	elif esta_na_parede:
		# (Use o nome exato da sua animação de "grudar")
		if animacao.animation != "wallSick" and animacao.animation != "wall_slide_loop":
			animacao.play("wallSick")
		
	# Prioridade 4: Está no ar?
	elif not is_on_floor():
		if velocity.y < 0:
			animacao.play("jump")
		else:
			animacao.play("fall")

	# Prioridade 5: Está correndo?
	elif direcao != 0:
		animacao.play("run")

	# Prioridade 6: Está parado
	else:
		animacao.play("idle")
