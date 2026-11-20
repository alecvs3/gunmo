class_name LaunchArgs
extends RefCounted
## Dev shortcuts that skip the menu. Pass them after "--", e.g. in Debug → Customize Run Instances:
##   -- --host [port]
##   -- --join <address>[:port]

const NONE: String = ""
const HOST: String = "host"
const JOIN: String = "join"


## Returns {"action": NONE/HOST/JOIN, "address": String, "port": int}.
static func parse(args: PackedStringArray, default_port: int) -> Dictionary:
	var result: Dictionary = {"action": NONE, "address": "", "port": default_port}
	var index: int = args.find("--host")
	if index != -1:
		result["action"] = HOST
		if index + 1 < args.size() and _is_port(args[index + 1]):
			result["port"] = args[index + 1].to_int()
		return result
	index = args.find("--join")
	if index != -1 and index + 1 < args.size() and not args[index + 1].begins_with("--"):
		var target: String = args[index + 1]
		result["action"] = JOIN
		result["address"] = target
		if target.count(":") == 1 and _is_port(target.get_slice(":", 1)):
			result["address"] = target.get_slice(":", 0)
			result["port"] = target.get_slice(":", 1).to_int()
	return result


static func _is_port(text: String) -> bool:
	return text.is_valid_int() and text.to_int() > 0 and text.to_int() <= 65535
