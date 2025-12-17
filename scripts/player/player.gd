extends CharacterBody2D

signal health_changed(nova_vida, vida_maxima, amount)

# --- VARIÁVEIS DE VIDA E DANO ---
@export var vida_maxima: int = 5
var vida_atual: int
var esta_invencivel := false
var esta_morto := false 

# --- VARIÁVEIS DE MOVIMENTO ---

@export var velocidade := 300.0
@export var forca_do_pulo := -400.0
@export var gravidade := 1200.0
@export var desaceleracao := 1000.0
@export var gravidade_ataque_aereo_mult := 0.8
@export var dano_ataque: int = 1
@export var knockback_force: int = 200

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

# --- ATAQUE (COMBO) ---
var esta_atacando := false
var current_attack_animation := ""
var combo_count := 0 # <--- NOVO: Rastreia o combo
var proximo_ataque_solicitado := false # <--- NOVO: Buffer de input

# --- REFERÊNCIAS DE NÓS ---
@onready var timer_dash := $DashTimer
@onready var animacao := $Animacao
@onready var hitbox := $Hitbox
@onready var attack_hitbox_timer := $AttackHitboxTimer
@onready var attack_duration_timer := $AttackDurationTimer
@onready var invencibilidade_timer := $InvencibilidadeTimer
@onready var hurtbox := $Hurtbox 
@onready var collision_shape := $CollisionShape2D 
@onready var combo_window_timer := $ComboWindowTimer # <--- NOVO: Adicione este Timer na cena
 
# --- REFERÊNCIAS DAS HITBOX SHAPES ---
@onready var hitbox_ground_shape := $Hitbox/GroundShape
@onready var hitbox_air_shape := $Hitbox/AirShape 

# --- PULO DUPLO ---
var saltos_restantes := 1
@export var max_saltos := 2


func _ready() -> void:
	# --- LÓGICA DE CARREGAR VIDA MÁXIMA ---
	if Singleton.player_max_health_run > 0:
		vida_maxima = Singleton.player_max_health_run
	else:
		# Se for a primeira vez (valor 0), usa o padrão do Inspector e salva
		Singleton.player_max_health_run = vida_maxima
	
	if Singleton.player_damage_run > 0:
		dano_ataque = Singleton.player_damage_run
	else:
		Singleton.player_damage_run = dano_ataque # Salva o padrão (1)

	# --- LÓGICA DE CARREGAR VIDA ATUAL (Já existia, mas ajustada) ---
	if Singleton.player_health_run > 0:
		vida_atual = Singleton.player_health_run
	else:
		vida_atual = vida_maxima
	
	call_deferred("emit_signal", "health_changed", vida_atual, vida_maxima, 0)


# --- NOVA FUNÇÃO DE ATAQUE (Refatorada) ---
func iniciar_ataque(nome_animacao: String):
	esta_atacando = true
	current_attack_animation = nome_animacao
	
	hitbox_ground_shape.disabled = true
	hitbox_air_shape.disabled = true

	# Verifica se a animação realmente existe
	if not animacao.sprite_frames.has_animation(nome_animacao):
		print("ERRO: Animação de ataque não encontrada: ", nome_animacao)
		# Tenta usar 'attack01' como padrão
		if animacao.sprite_frames.has_animation("attack01"):
			current_attack_animation = "attack01"
		else:
			# Se nem 'attack01' existe, aborta o ataque
			esta_atacando = false
			current_attack_animation = ""
			combo_count = 0
			return

	var frame_count = animacao.sprite_frames.get_frame_count(current_attack_animation)
	var speed = animacao.sprite_frames.get_animation_speed(current_attack_animation)
	var duracao_ataque = frame_count / speed

	attack_duration_timer.start(duracao_ataque)
	
	# Idealmente, o tempo de hitbox deve ser diferente para cada ataque
	attack_hitbox_timer.start(0.1)


func _physics_process(delta: float) -> void:
	
	# --- LÓGICA DE MORTE (Prioridade 0) ---
	if esta_morto:
		
		if not is_on_floor():
			velocity.y += gravidade * delta
			move_and_slide()
		# --------------------------------

		if not animacao.is_playing() and animacao.animation == "die":
			if Input.is_action_just_pressed("pular"):
				reviver()
			
		return
		
	# --- O RESTO DA FÍSICA  ---
		
	var direcao_input := Input.get_axis("mover_esquerda", "mover_direita")

	# --- LÓGICA DE ATAQUE (Prioridade 1) ---
	# --- ALTERADO PARA COMBO ---
	if Input.is_action_just_pressed("atacar") and not esta_na_parede and not esta_dando_dash:
		
		if is_on_floor():
			# Se NÃO está atacando (início do combo)
			if not esta_atacando:
				combo_window_timer.stop() # Para o timer de reset, se estiver ativo
				combo_count = 1
				iniciar_ataque("attack01")
			
			# Se ESTÁ atacando (tentando continuar o combo)
			else:
				# Se o combo não chegou ao fim (max 3 hits)
				if combo_count < 3:
					proximo_ataque_solicitado = true
				# Se combo_count == 3, não faz nada, 'proximo_ataque_solicitado' continua false
		
		else:
			# Ataque aéreo (sem combo)
			if not esta_atacando:
				# Inicia o combo aéreo
				combo_count = 1 # Define como 1 para a sequência aérea
				iniciar_ataque("attack_air01") # Usa a primeira animação aérea
			# Buffer para o segundo ataque aéreo (somente se estiver no primeiro hit)
			elif combo_count == 1: 
				proximo_ataque_solicitado = true
				# Se combo_count já for >= 2 no ar, não faz buffer

	if esta_atacando:
		atualizar_animacoes(0.0) 

	# --- GRAVIDADE ---
	if not is_on_floor() and not esta_dando_dash:
		if esta_atacando:
			velocity.y += (gravidade * gravidade_ataque_aereo_mult) * delta
		else:
			velocity.y += gravidade * delta

	# --- MOVIMENTO HORIZONTAL ---
	if not esta_dando_dash and not pulou_da_parede_neste_quadro:
		
		if esta_atacando and not is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, (desaceleracao * 0.2) * delta)
		elif esta_atacando and is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, desaceleracao * delta)
		else:
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
	
	if not esta_atacando:
		atualizar_animacoes(direcao_input)

	if pulou_da_parede_neste_quadro:
		await get_tree().create_timer(0.1).timeout
		pulou_da_parede_neste_quadro = false

# ==================================================
# --- FUNÇÕES DE DANO E VIDA ---
# ==================================================

func tomar_dano(dano: int, damage_source: Node2D = null) -> void:
	if esta_invencivel or esta_morto: 
		return

	vida_atual -= dano
	
	if damage_source:
		var knockback_direction = (global_position - damage_source.global_position).normalized()
		velocity = knockback_direction * knockback_force
		
	Singleton.player_health_run = vida_atual
	
	health_changed.emit(vida_atual, vida_maxima, -dano)
	print("Jogador atingido! Vida restante: ", vida_atual)
	
	esta_invencivel = true
	invencibilidade_timer.start() 
	
	var tween = get_tree().create_tween()
	tween.tween_property(animacao, "modulate", Color.RED, 0.1)
	tween.tween_property(animacao, "modulate", Color.WHITE, 0.1)
	tween.tween_property(animacao, "modulate", Color.RED, 0.1)
	tween.tween_property(animacao, "modulate", Color.WHITE, 0.1)

	if vida_atual <= 0:
		morrer()

func morrer() -> void:
	if esta_morto: 
		return
		
	print("Jogador morreu!")
	esta_morto = true
	
	hurtbox.monitoring = false
	
	animacao.play("die")
	
	await animacao.animation_finished
	
	Singleton.reset_run_stats()
	
	get_tree().change_scene_to_file("res://scenes/home.tscn")
	
func reviver() -> void:
	print("Revivendo...")
	get_tree().reload_current_scene() 

func _on_invencibilidade_timer_timeout():
	esta_invencivel = false
	if animacao and not esta_morto: 
		animacao.modulate = Color.WHITE

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		tomar_dano(1, body)


# ==================================================
# --- TIMERS E SINAIS DE ATAQUE (ALTERADO) ---
# ==================================================

func _on_dash_timer_timeout():
	esta_dando_dash = false
	velocity.x *= 0.5

# --- ALTERADO PARA LÓGICA DE COMBO ---
# --- ALTERADO PARA LÓGICA DE COMBO (CHÃO E AR) ---
func _on_attack_duration_timer_timeout():

	# Guarda o estado ANTES de resetar `current_attack_animation`
	var was_ground_attack = current_attack_animation.begins_with("attack") and not current_attack_animation.begins_with("attack_air")
	var was_air_attack = current_attack_animation.begins_with("attack_air")

	# --- LÓGICA DE CONTINUAÇÃO DO COMBO ---
	if proximo_ataque_solicitado:
		proximo_ataque_solicitado = false # Consome o buffer imediatamente

		# Tenta continuar combo no CHÃO
		if is_on_floor() and was_ground_attack and combo_count < 3:
			combo_count += 1
			var proxima_animacao_chao = "attack%02d" % combo_count # attack02 ou attack03
			if animacao.sprite_frames.has_animation(proxima_animacao_chao):
				esta_atacando = false # Reseta o estado para iniciar_ataque
				iniciar_ataque(proxima_animacao_chao)
				return # Inicia o próximo ataque e sai da função
			# Se a animação não existe, cai para a lógica de reset abaixo

		# Tenta continuar combo no AR
		elif not is_on_floor() and was_air_attack and combo_count < 2: # Limite de 2 hits no ar
			combo_count += 1 # Vai para 2
			var proxima_animacao_ar = "attack_air%02d" % combo_count # attack_air02
			if animacao.sprite_frames.has_animation(proxima_animacao_ar):
				esta_atacando = false # Reseta o estado para iniciar_ataque
				iniciar_ataque(proxima_animacao_ar)
				return # Inicia o próximo ataque e sai da função
			# Se a animação não existe, cai para a lógica de reset abaixo

		# Se apertou buffer mas as condições não foram atendidas (ex: pousou, limite atingido),
		# continua para a lógica de reset abaixo.


	# --- LÓGICA DE RESET (Se não houve continuação) ---
	esta_atacando = false 
	current_attack_animation = "" 

	hitbox.monitoring = false
	hitbox_ground_shape.disabled = true
	hitbox_air_shape.disabled = true

	proximo_ataque_solicitado = false # Garante que está resetado

	# Inicia a janela de reset APENAS se foi um ataque no chão e ainda estamos no chão
	if was_ground_attack and is_on_floor():
		combo_window_timer.start()
		# Não reseta combo_count aqui, espera a janela
	else:
		# Reseta o combo imediatamente se foi um ataque aéreo,
		# ou se caímos da plataforma durante/após um ataque no chão.
		combo_count = 0

# --- ALTERADO PARA LÓGICA DE COMBO ---
func _on_attack_hitbox_timer_timeout():
	hitbox.monitoring = true

	# Habilita a hitbox para QUALQUER ataque no chão
	if current_attack_animation.begins_with("attack") and not current_attack_animation.begins_with("attack_air"):
		hitbox_ground_shape.disabled = false
	# Habilita a hitbox para QUALQUER ataque no ar (attack_air01, attack_air02, ...)
	elif current_attack_animation.begins_with("attack_air"):
		hitbox_air_shape.disabled = false

	await get_tree().create_timer(0.15).timeout

	hitbox.monitoring = false
	hitbox_ground_shape.disabled = true
	hitbox_air_shape.disabled = true

# --- NOVA FUNÇÃO ---
func _on_combo_window_timer_timeout():
	# Se o tempo da janela acabar, reseta o combo.
	combo_count = 0
	print("Janela do combo fechada. Combo resetado.")
	
	
func _on_hitbox_body_entered(body: Node2D) -> void:
	# Agora passamos o 'dano_ataque' para o inimigo!
	if body.has_method("ser_atingido"):
		body.ser_atingido(dano_ataque)
	
func _on_animacao_animation_finished() -> void:
	if animacao.animation == "wallSick":
		animacao.play("wall_slide_loop")


# ==================================================
# --- FUNÇÃO PRINCIPAL DE ANIMAÇÃO ---
# ==================================================

func atualizar_animacoes(direcao: float) -> void:
	
	# Prioridade 0: Morto
	if esta_morto:
		if animacao.animation != "die":
			animacao.play("die")
		return

	# Prioridade 1: Atacando
	if esta_atacando:
		animacao.play(current_attack_animation)
		return 
	
	# --- LÓGICA DE VIRAR O SPRITE  ---
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
	
	
	# --- LÓGICA DAS ANIMAÇÕES ---
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
		
func _on_hitbox_area_entered(area: Area2D) -> void:
	# Verifica se o objeto que a espada tocou tem a função 'rebater'
	if area.has_method("rebater"):
		
		# Calcula a direção do rebatedor (para frente do player)
		var direcao_rebate = Vector2.RIGHT
		if animacao.flip_h:
			direcao_rebate = Vector2.LEFT
			
		# Executa o parry
		area.rebater(direcao_rebate)
		
		# (Opcional) Efeito de "Time Stop" para dar impacto (Game Juice!)
		efeito_parry()

func efeito_parry():
	# Congela o jogo por uma fração de segundo
	var time_scale_original = Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05 * 0.05).timeout # Espera em tempo real reduzido
	Engine.time_scale = time_scale_original
	
# --- NOVAS FUNÇÕES DE CURA E UPGRADE ---

func curar(quantidade: int) -> void:
	if vida_atual >= vida_maxima:
		return # Já está cheio
		
	vida_atual += quantidade
	
	# Garante que não ultrapasse o máximo
	if vida_atual > vida_maxima:
		vida_atual = vida_maxima
		
	# Atualiza o Singleton e a UI
	Singleton.player_health_run = vida_atual
	health_changed.emit(vida_atual, vida_maxima, quantidade)
	
	print("Player curado! Vida: ", vida_atual)
	
	# Feedback visual (piscar verde)
	modulate = Color.GREEN
	await get_tree().create_timer(0.2).timeout
	modulate = Color.WHITE

func aumentar_vida_maxima(quantidade: int) -> void:
	vida_maxima += quantidade
	vida_atual += quantidade
	
	# --- SALVANDO NO SINGLETON ---
	Singleton.player_health_run = vida_atual      # Salva a vida atual nova
	Singleton.player_max_health_run = vida_maxima # <--- O SEGREDO ESTÁ AQUI!
	
	health_changed.emit(vida_atual, vida_maxima, quantidade)
	print("Vida Máxima Aumentada e SALVA! Novo Max: ", vida_maxima)

# Adicione junto com as funções curar() e aumentar_vida_maxima()

func aumentar_dano(quantidade: int) -> void:
	dano_ataque += quantidade
	Singleton.player_damage_run = dano_ataque # Salva na memória global
	print("FORÇA BRUTA! Novo Dano: ", dano_ataque)
