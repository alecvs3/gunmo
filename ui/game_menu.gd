class_name GameMenu
extends Control
## In-match menu on Esc: Resume or Leave. The game keeps running underneath (multiplayer).

@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	hide()
	%ResumeButton.pressed.connect(hide)
	_leave_button.pressed.connect(_on_leave_pressed)
	NetworkManager.session_ended.connect(hide.unbind(1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and NetworkManager.is_online():
		_leave_button.text = "End match for everyone" if NetworkManager.is_host() else "Leave match"
		visible = not visible
		get_viewport().set_input_as_handled()


func _on_leave_pressed() -> void:
	hide()
	NetworkManager.leave()
