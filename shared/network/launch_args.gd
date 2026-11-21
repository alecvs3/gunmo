class_name LaunchArgs
extends RefCounted
## Command-line shortcuts. Pass them after "--", e.g. in Debug → Customize Run Instances:
##   -- --host [port]                 host a game (skips the menu)
##   -- --join <address>[:port]       join a game (skips the menu)
##   -- --dedicated [port]            run a host with no player of its own (a server)
##   -- --net-sim <ms>,<jitter>,<%>   fake latency, jitter and loss on this instance

const NONE: String = ""
const HOST: String = "host"
const JOIN: String = "join"
const DEDICATED: String = "dedicated"


## Returns {"action", "address", "port", "net_sim"}. net_sim is [] or [latency, jitter, loss]
## with loss as a 0..1 share.
static func parse(args: PackedStringArray, default_port: int) -> Dictionary:
	var result: Dictionary = {"action": NONE, "address": "", "port": default_port, "net_sim": []}
	result["net_sim"] = _parse_net_sim(args)
	for action: String in [HOST, DEDICATED]:
		var index: int = args.find("--" + action)
		if index != -1:
			result["action"] = action
			if index + 1 < args.size() and _is_port(args[index + 1]):
				result["port"] = args[index + 1].to_int()
			return result
	var join_index: int = args.find("--join")
	if (
		join_index != -1
		and join_index + 1 < args.size()
		and not args[join_index + 1].begins_with("--")
	):
		_parse_join_target(args[join_index + 1], result)
	return result


static func _parse_join_target(target: String, result: Dictionary) -> void:
	result["action"] = JOIN
	result["address"] = target
	if target.count(":") == 1 and _is_port(target.get_slice(":", 1)):
		result["address"] = target.get_slice(":", 0)
		result["port"] = target.get_slice(":", 1).to_int()


static func _parse_net_sim(args: PackedStringArray) -> Array:
	var index: int = args.find("--net-sim")
	if index == -1 or index + 1 >= args.size():
		return []
	var parts: PackedStringArray = args[index + 1].split(",")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int()):
		return []
	if not parts[2].is_valid_float():
		return []
	return [parts[0].to_int(), parts[1].to_int(), clampf(parts[2].to_float() / 100.0, 0.0, 1.0)]


static func _is_port(text: String) -> bool:
	return text.is_valid_int() and text.to_int() > 0 and text.to_int() <= 65535
