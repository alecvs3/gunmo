class_name FullscreenCheck
extends CheckBox
## "Fullscreen" checkbox: shows GameSettings.fullscreen and changes it. Stays in step when
## F11 / Alt+Enter or another menu's checkbox changes the setting.


func _ready() -> void:
	set_pressed_no_signal(GameSettings.fullscreen)
	toggled.connect(GameSettings.set_fullscreen)
	GameSettings.fullscreen_changed.connect(set_pressed_no_signal)
