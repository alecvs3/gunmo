extends Node
## Root scene. Shows the menu; once hosting starts, the host puts the level into
## LevelContainer and the game mode into ModeContainer, and their MultiplayerSpawners
## replicate both to every client (late joiners too).
## The match settings (and with them the mode) come from the menu's choice, or from the
## --match launch arg. Dev launch args (see LaunchArgs) can also host or join straight away.

const LEVEL_SCENE: PackedScene = preload("res://levels/test_arena.tscn")

## Set by --match; otherwise the menu decides.
var _match_settings: MatchSettings = null

@onready var _level_container: Node = $LevelContainer
@onready var _mode_container: Node = $ModeContainer
@onready var _menu: MainMenu = $UI/MainMenu


func _ready() -> void:
	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.joined_host.connect(_menu.hide)
	NetworkManager.join_failed.connect(_on_session_ended)
	NetworkManager.session_ended.connect(_on_session_ended)
	_apply_launch_args.call_deferred()


func _apply_launch_args() -> void:
	var launch: LaunchArgs.Options = LaunchArgs.parse(
		OS.get_cmdline_user_args(), NetworkManager.config.default_port
	)
	_load_match_settings(launch.match_path)
	var net_sim: Array = launch.net_sim
	if not net_sim.is_empty():
		NetworkManager.configure_simulator(net_sim[0], net_sim[1], net_sim[2])
	match launch.action:
		LaunchArgs.HOST:
			_menu.host_on(launch.port)
		LaunchArgs.JOIN:
			_menu.join_at(launch.address, launch.port)
		LaunchArgs.DEDICATED:
			if NetworkManager.host(launch.port, true) != OK:
				get_tree().quit(1)


func _load_match_settings(path: String) -> void:
	if path.is_empty():
		return
	var loaded := load(path) as MatchSettings if ResourceLoader.exists(path) else null
	if loaded == null:
		push_warning("--match %s is not a MatchSettings resource; using the default." % path)
		return
	_match_settings = loaded


## The level first, then the mode (which spawns the players into it).
func _on_hosting_started() -> void:
	_menu.hide()
	var settings: MatchSettings = _match_settings if _match_settings else _menu.chosen_match()
	var scene: PackedScene = LEVEL_SCENE
	if settings.map != null and settings.map.scene != null:
		scene = settings.map.scene
	var level: Level = scene.instantiate()
	_level_container.add_child(level, true)
	var mode: GameMode = settings.mode_scene.instantiate()
	mode.setup(level, settings)
	_mode_container.add_child(mode, true)


func _on_session_ended(reason: String) -> void:
	for container in [_mode_container, _level_container]:
		for child: Node in container.get_children():
			child.queue_free()
	_menu.show()
	_menu.show_status(reason)
