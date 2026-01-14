extends CanvasLayer

@onready var menu_container = $VBoxContainer
@onready var controls_panel = $ControlsPanel
@onready var btn_resume = $VBoxContainer/BtnResume
@onready var btn_close_controls = $ControlsPanel/BtnCloseControls

func _ready():
	visible = false
	controls_panel.visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if controls_panel.visible:
			_on_btn_close_controls_pressed()
		else:
			toggle_pause()

func toggle_pause():
	var is_paused = Singleton.is_paused()
	
	if is_paused:
		# If it's already paused, we assume this script is the one that paused it.
		Singleton.release_pause(self)
	else:
		Singleton.request_pause(self)

	# Update visibility based on the *new* state
	visible = not is_paused
	
	if visible:
		btn_resume.grab_focus()


func _on_btn_resume_pressed():
	toggle_pause()


func _on_btn_controls_pressed():
	controls_panel.visible = true
	menu_container.visible = false
	btn_close_controls.grab_focus()


func _on_btn_close_controls_pressed():
	controls_panel.visible = false
	menu_container.visible = true
	btn_resume.grab_focus()


func _on_btn_quit_pressed():
	# Ensure the game is unpaused before quitting
	Singleton.release_pause(self)
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
