extends Label

func start(amount: int, target_position: Vector2):
	var text_to_display: String
	if amount > 0:
		text_to_display = "+" + str(amount)
		modulate = Color.GREEN
	else:
		text_to_display = str(amount)
		modulate = Color.RED

	text = text_to_display
	global_position = target_position

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", global_position - Vector2(0, 50), 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	queue_free()
