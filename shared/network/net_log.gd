class_name NetLog
extends RefCounted
## Timestamped network log lines, printed (Godot also keeps them in user://logs/godot.log) and,
## in windowed runs, written to this session's own file in user://logs/net/ (the newest
## KEEP_FILES are kept), so a hiccup from last night's match can still be looked up.
## Headless runs (tests, the dedicated server) only print, so they never push a real
## session's log out of the rotation.

const FOLDER: String = "user://logs/net"
const KEEP_FILES: int = 30

static var _file: FileAccess = null
static var _opened: bool = false
static var _last_written: Dictionary = {}


static func write(message: String) -> void:
	var line: String = "[net %s] %s" % [Time.get_time_string_from_system(), message]
	print(line)
	_write_to_file(line)


## Like write(), but at most once every `min_seconds` per `key` (for things that can repeat
## every tick, such as a stalled connection). Returns whether it wrote.
static func write_limited(key: String, message: String, min_seconds: float = 5.0) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _last_written.has(key) and now - float(_last_written[key]) < min_seconds:
		return false
	_last_written[key] = now
	write(message)
	return true


## Closes this session's file (NetworkManager calls it on exit).
static func close() -> void:
	if _file != null:
		_file.close()
	_file = null
	_last_written.clear()


static func _write_to_file(line: String) -> void:
	if not _opened:
		_opened = true
		_file = _open_session_file()
	if _file != null:
		_file.store_line(line)
		_file.flush()


static func _open_session_file() -> FileAccess:
	if DisplayServer.get_name() == "headless":
		return null
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_remove_old_files()
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	return FileAccess.open("%s/net_%s.log" % [FOLDER, stamp], FileAccess.WRITE)


static func _remove_old_files() -> void:
	var names: PackedStringArray = DirAccess.get_files_at(FOLDER)
	names.sort()
	for i in maxi(names.size() - (KEEP_FILES - 1), 0):
		DirAccess.remove_absolute("%s/%s" % [FOLDER, names[i]])
