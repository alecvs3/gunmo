class_name NetLog
extends RefCounted
## Timestamped network log lines. Godot also writes them to user://logs/godot.log.


static func write(message: String) -> void:
	print("[net %s] %s" % [Time.get_time_string_from_system(), message])
