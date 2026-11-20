class_name MainMenu
extends Control
## Host / Join / Cancel / Quit. Only talks to NetworkManager; main.gd hides this once a
## session starts and shows it again with the reason when one ends.

const DEFAULT_ADDRESS: String = "127.0.0.1"

@onready var _ip_edit: LineEdit = %IpEdit
@onready var _port_edit: LineEdit = %PortEdit
@onready var _status_label: Label = %StatusLabel
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_cancel_button.pressed.connect(NetworkManager.cancel_join)
	%QuitButton.pressed.connect(get_tree().quit)
	NetworkManager.joined_host.connect(_set_joining.bind(false))
	NetworkManager.join_failed.connect(_set_joining.bind(false).unbind(1))
	_port_edit.text = str(NetworkManager.config.default_port)
	_set_joining(false)


func show_status(message: String) -> void:
	_status_label.text = message


## Used by launch args; same as filling in the fields and clicking.
func host_on(port: int) -> void:
	_port_edit.text = str(port)
	_on_host_pressed()


func join_at(address: String, port: int) -> void:
	_ip_edit.text = address
	_port_edit.text = str(port)
	_on_join_pressed()


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
	_set_joining(true)
	show_status("Connecting to %s:%d..." % [address, port])


func _set_joining(joining: bool) -> void:
	_host_button.disabled = joining
	_join_button.disabled = joining
	_cancel_button.visible = joining


func _read_port() -> int:
	var text: String = _port_edit.text.strip_edges()
	if text.is_valid_int() and text.to_int() > 0 and text.to_int() <= 65535:
		return text.to_int()
	_port_edit.text = str(NetworkManager.config.default_port)
	return NetworkManager.config.default_port
