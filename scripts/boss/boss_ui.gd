extends CanvasLayer

@onready var health_bar = $HealthBar # Ajuste o caminho se necessário

func _ready() -> void:
	# Começa escondido até o boss aparecer/ativar
	visible = false

func initialize(boss_node):
	if not boss_node: return
	
	# Conecta ao sinal do Boss
	if not boss_node.health_changed.is_connected(_on_boss_health_changed):
		boss_node.health_changed.connect(_on_boss_health_changed)
	
	# Conecta ao sinal de morte para esconder a barra
	if not boss_node.boss_defeated.is_connected(_on_boss_defeated):
		boss_node.boss_defeated.connect(_on_boss_defeated)
		
	# Configura valores iniciais
	health_bar.max_value = boss_node.vida_maxima
	health_bar.value = boss_node.vida_atual
	visible = true # Mostra a barra agora que o boss está pronto

func _on_boss_health_changed(current, max_health):
	# O Tween faz a barra descer suavemente (opcional, mas fica bonito)
	var tween = create_tween()
	tween.tween_property(health_bar, "value", current, 0.3).set_trans(Tween.TRANS_SINE)
	# Se preferir instantâneo: health_bar.value = current

func _on_boss_defeated():
	visible = false
	# Pode adicionar uma animação de fade-out aqui antes de esconder
