class_name MainMenu
extends Control
## Name, mode, bots, Host / Join / Cancel / Quit. Only talks to NetworkManager and
## GameSettings; main.gd asks it for the chosen match when hosting starts, hides it once a
## session starts and shows it again with the reason when one ends.

const DEFAULT_ADDRESS: String = "127.0.0.1"
## What the host can pick. `bots`: the mode fills empty slots with bots.
const MODES: Array[Dictionary] = [
	{"name": "Waves (co-op)", "match": "res://modes/data/default_match.tres", "bots": true},
	{"name": "Gun Game", "match": "res://modes/data/gun_game_match.tres", "bots": true},
]

@onready var _ip_edit: LineEdit = %IpEdit
@onready var _port_edit: LineEdit = %PortEdit
@onready var _status_label: Label = %StatusLabel
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _cancel_button: Button = %CancelButton
@onready var _name_edit: LineEdit = %NameEdit
@onready var _mode_select: OptionButton = %ModeSelect
@onready var _bots_spin: SpinBox = %BotsSpin


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_cancel_button.pressed.connect(NetworkManager.cancel_join)
	%QuitButton.pressed.connect(get_tree().quit)
	NetworkManager.joined_host.connect(_set_joining.bind(false))
	NetworkManager.join_failed.connect(_set_joining.bind(false).unbind(1))
	_port_edit.text = str(NetworkManager.config.default_port)
	_name_edit.text = GameSettings.player_name
	for mode: Dictionary in MODES:
		_mode_select.add_item(mode["name"])
	_mode_select.item_selected.connect(_on_mode_selected)
	_on_mode_selected(_mode_select.selected)
	_set_joining(false)


## The host's choice: a copy of the mode's match settings with the menu's bot count.
func chosen_match() -> MatchSettings:
	var mode: Dictionary = MODES[maxi(_mode_select.selected, 0)]
	var settings: MatchSettings = (load(mode["match"]) as MatchSettings).duplicate()
	if mode["bots"]:
		settings.bot_fill_to = roundi(_bots_spin.value)
	return settings


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
	_use_name()
	var port: int = _read_port()
	var err: Error = NetworkManager.host(port)
	if err != OK:
		show_status("Could not host on port %d (%s)." % [port, error_string(err)])


func _on_join_pressed() -> void:
	_use_name()
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


func _use_name() -> void:
	GameSettings.set_player_name(_name_edit.text)
	NetworkManager.set_local_name(GameSettings.player_name)


func _on_mode_selected(index: int) -> void:
	%BotsRow.visible = MODES[maxi(index, 0)]["bots"]


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
