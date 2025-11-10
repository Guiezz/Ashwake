extends CharacterBody2D

# --- VARIÁVEIS DE MOVIMENTO ---
@export var velocidade := 300.0
@export var forca_do_pulo := -400.0
@export var gravidade := 1200.0
@export var desaceleracao := 1000.0

# --- WALL JUMP / SLIDE ---
@export var forca_pulo_parede := Vector2(300, -400)
@export var velocidade_deslizando := 40.0
@export var forca_pulo_neutro_x := 50.0 # (NOVO) Pequeno impulso horizontal para o pulo neutro

var esta_na_parede := false
var pulou_da_parede_neste_quadro := false

# --- DASH ---
@export var forca_dash := 600.0
@export var duracao_dash := 0.15
var pode_dar_dash := true
var esta_dando_dash := false
var direcao_dash := Vector2.ZERO
@onready var timer_dash := $DashTimer

# --- PULO DUPLO ---
var saltos_restantes := 1
@export var max_saltos := 2

func _physics_process(delta: float) -> void:
	var direcao_input := Input.get_axis("mover_esquerda", "mover_direita")

	# --- GRAVIDADE ---
	if not is_on_floor() and not esta_dando_dash:
		velocity.y += gravidade * delta

	# --- MOVIMENTO HORIZONTAL ---
	if not esta_dando_dash and not pulou_da_parede_neste_quadro:
		velocity.x = move_toward(velocity.x, direcao_input * velocidade, desaceleracao * delta)

	# --- RESETAR SALTOS NO CHÃO ---
	if is_on_floor():
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
			
			# Lógica do Pulo Neutro: verifica se o jogador está apertando alguma direção
			if direcao_input == 0:
				# Pulo Neutro: Impulso vertical forte, horizontal fraco
				velocity.x = direcao_parede * forca_pulo_neutro_x
			else:
				# Pulo de Parede Normal: Impulso para longe da parede
				velocity.x = direcao_parede * forca_pulo_parede.x
			
			# Aplica o impulso vertical para ambos os tipos de pulo
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
			direcao_dash = Vector2(sign(velocity.x), 0)
		velocity = direcao_dash.normalized() * forca_dash
		timer_dash.start(duracao_dash)

	move_and_slide()

	if pulou_da_parede_neste_quadro:
		await get_tree().create_timer(0.1).timeout
		pulou_da_parede_neste_quadro = false


func _on_dash_timer_timeout():
	esta_dando_dash = false
	velocity.x *= 0.5
