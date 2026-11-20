class_name MainMenu
extends Control
## Host / Join / Quit. Only talks to NetworkManager; main.gd hides this once a session starts.

const DEFAULT_ADDRESS: String = "127.0.0.1"

@onready var _ip_edit: LineEdit = %IpEdit
@onready var _port_edit: LineEdit = %PortEdit
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%QuitButton.pressed.connect(get_tree().quit)
	_port_edit.text = str(NetworkManager.DEFAULT_PORT)


func show_status(message: String) -> void:
	_status_label.text = message


func _on_host_pressed() -> void:
	var port: int = _read_port()
	var err: Error = NetworkManager.host(port)
	if err != OK:
		show_status("Could not host on port %d (%s)." % [port, error_string(err)])


func _on_join_pressed() -> void:
	var address: String = _ip_edit.text.strip_edges()
	if address.is_empty():
		address = DEFAULT_ADDRESS
	var port: int = _read_port()
	var err: Error = NetworkManager.join(address, port)
	if err != OK:
		show_status("Could not join %s:%d (%s)." % [address, port, error_string(err)])
		return
	show_status("Connecting to %s:%d..." % [address, port])


func _read_port() -> int:
	var text: String = _port_edit.text.strip_edges()
	if text.is_valid_int() and text.to_int() > 0 and text.to_int() <= 65535:
		return text.to_int()
	_port_edit.text = str(NetworkManager.DEFAULT_PORT)
	return NetworkManager.DEFAULT_PORT
