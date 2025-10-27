# bullet.gd
extends Area2D

var velocidade: float = 300.0
var direcao: Vector2 = Vector2.RIGHT # Será definido ao instanciar

func _ready() -> void:
	# Conecta os sinais
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Move o projétil
	global_position += direcao * velocidade * delta

func _on_body_entered(body: Node2D) -> void:
	# Se colidir com o jogador
	if body.is_in_group("player"):
		if body.has_method("tomar_dano"):
			body.tomar_dano(1) # Ou o dano desejado
		queue_free() # Destroi o projétil

	# Se colidir com algo que não seja inimigo ou outro projétil (ex: parede)
	# Ajuste as condições conforme necessário (ex: verificar layer de colisão)
	elif not body.is_in_group("enemy") and not body.is_in_group("enemy_projectile"):
		queue_free() # Destroi o projétil ao bater na parede

# Função para inicializar (opcional, mas útil)
func iniciar(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direcao = dir.normalized()
	# Rotaciona o sprite para apontar na direção (se necessário)
	rotation = direcao.angle()
