extends Control

# --- CONFIGURAÇÃO ---
# Arraste as imagens no Inspector
@export var imagem_1: Texture2D
@export var imagem_2: Texture2D
@export var imagem_3: Texture2D

# Tempos (em segundos)
@export var tempo_fade_in: float = 1.5
@export var tempo_leitura: float = 3.0
@export var tempo_fade_out: float = 1.0

# Referências aos nós
@onready var background = $Background
@onready var label = $StoryText

# Os textos da história
var textos = [
	"O selo foi quebrado. O mal que estava preso nas cavernas agora caminha livre pela floresta.",
	"Os Golens, outrora protetores, foram corrompidos pela malícia antiga.",
	"Você falhou em proteger este lugar uma vez. Mas o destino lhe deu uma segunda chance. Empunhe sua espada. Limpe a corrupção. O pesadelo só terminará quando o Demônio Rei cair"
]

var slide_atual = 0
var tween_atual: Tween

func _ready():
	# Garante que começam invisíveis (caso tenha esquecido no editor)
	background.modulate.a = 0.0
	label.modulate.a = 0.0
	
	# Começa a sequência
	iniciar_ciclo_slide()

func _input(event):
	# Se apertar qualquer coisa, pula a intro
	if event.is_pressed() and not event.is_echo():
		if tween_atual and tween_atual.is_running():
			tween_atual.kill() # Para a animação atual
		iniciar_jogo()

func iniciar_ciclo_slide():
	# Verifica se ainda tem slides
	if slide_atual >= textos.size():
		iniciar_jogo()
		return

	# 1. Prepara o conteúdo (troca imagem e texto escondido)
	if slide_atual == 0: background.texture = imagem_1
	elif slide_atual == 1: background.texture = imagem_2
	elif slide_atual == 2: background.texture = imagem_3
	label.text = textos[slide_atual]
	
	# 2. Cria o Tween (o robô da animação)
	tween_atual = create_tween()
	
	# --- FADE IN ---
	# Anima o alpha ("modulate:a") do background para 1.0 (visível)
	tween_atual.tween_property(background, "modulate:a", 1.0, tempo_fade_in)
	# O ".parallel()" faz o próximo comando rodar ao mesmo tempo que o anterior
	tween_atual.parallel().tween_property(label, "modulate:a", 1.0, tempo_fade_in)
	
	# --- TEMPO DE LEITURA ---
	# Espera um tempo sem fazer nada
	tween_atual.tween_interval(tempo_leitura)
	
	# --- FADE OUT ---
	# Anima o alpha de volta para 0.0 (invisível)
	tween_atual.tween_property(background, "modulate:a", 0.0, tempo_fade_out)
	tween_atual.parallel().tween_property(label, "modulate:a", 0.0, tempo_fade_out)
	
	# --- PRÓXIMO PASSO ---
	# Quando terminar tudo acima, chama a função para preparar o próximo
	tween_atual.finished.connect(preparar_proximo)

func preparar_proximo():
	slide_atual += 1
	iniciar_ciclo_slide()

func iniciar_jogo():
	# Troque pelo caminho correto do seu jogo
	get_tree().change_scene_to_file("res://scenes/levels/level3.tscn")
