extends Node
## Root scene. Shows the menu; once hosting starts, the host puts the level into
## LevelContainer and LevelSpawner replicates it to every client (late joiners too).

const LEVEL_SCENE: PackedScene = preload("res://levels/test_arena.tscn")

@onready var _level_container: Node = $LevelContainer
@onready var _menu: MainMenu = $UI/MainMenu


func _ready() -> void:
	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.joined_host.connect(_menu.hide)
	NetworkManager.join_failed.connect(_on_session_ended.bind("Could not connect to host."))
	NetworkManager.host_disconnected.connect(_on_session_ended.bind("Host disconnected."))


func _on_hosting_started() -> void:
	_menu.hide()
	_level_container.add_child(LEVEL_SCENE.instantiate(), true)


func _on_session_ended(message: String) -> void:
	for level in _level_container.get_children():
		level.queue_free()
	_menu.show()
	_menu.show_status(message)
