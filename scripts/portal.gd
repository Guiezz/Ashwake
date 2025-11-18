extends Area2D

# Escolha a cena do próximo nível no Inspetor
@export_file("*.tscn") var proxima_cena 

var esta_ativo: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visible = false # Começa invisível
	monitoring = false # Começa sem detectar ninguém

# Função chamada pelo script do Nível quando os inimigos acabam
func ativar() -> void:
	esta_ativo = true
	visible = true
	monitoring = true
	print("Portal Aberto!")
	# Opcional: Tocar um som ou animação de porta abrindo aqui

func _on_body_entered(body: Node2D) -> void:
	if esta_ativo and body.is_in_group("player"):
		call_deferred("mudar_fase")

func mudar_fase():
	# Se tiver uma cena definida, vai para ela. Se não, volta para Home.
	if proxima_cena:
		get_tree().change_scene_to_file(proxima_cena)
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
