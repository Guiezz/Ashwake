extends Area2D

@export var dano: int = 2
@onready var sprite = $AnimatedSprite2D
@onready var colisor = $CollisionShape2D

func _ready() -> void:
	# --- NOVO: AUMENTA O TAMANHO DA MAGIA ---
	# Mude (2.5, 2.5) para o tamanho que achar melhor (3.0, 4.0, etc)
	scale = Vector2(2, 2) 
	
	colisor.set_deferred("disabled", true)
	sprite.play("Spell") 
	
	# Conexões de segurança
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	
	if not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)

func _on_frame_changed() -> void:
	# Ajuste conforme seus frames (mão saindo e recolhendo)
	if sprite.frame == 8: 
		colisor.set_deferred("disabled", false)
	elif sprite.frame == 12: 
		colisor.set_deferred("disabled", true)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("tomar_dano"):
			body.tomar_dano(dano)
			colisor.set_deferred("disabled", true)

func _on_animation_finished() -> void:
	queue_free()
