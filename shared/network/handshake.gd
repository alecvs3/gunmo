class_name Handshake
extends RefCounted
## The messages exchanged before a peer may enter the game, and the host's rules for them.
## Pure logic with no networking, so it can be unit-tested; JoinGate does the sending.

## Bump when the hello/reply format or any network format (snapshots, commands, events) changes.
const PROTOCOL: int = 4
## bytes_to_var needs at least a 4-byte type header.
const MIN_PAYLOAD_SIZE: int = 4


static func make_hello(version: String, build: String) -> Dictionary:
	return {"protocol": PROTOCOL, "version": version, "build": build}


static func accept() -> Dictionary:
	return {"ok": true}


static func reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func encode(message: Dictionary) -> PackedByteArray:
	return var_to_bytes(message)


## Never decodes objects, so a malicious peer can't make us instantiate anything.
## Payloads shorter than a Variant header are dropped before Godot logs a decode error.
static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < MIN_PAYLOAD_SIZE:
		return {}
	var value: Variant = bytes_to_var(data)
	if value is Dictionary:
		return value
	return {}


## Returns "" if the joiner may enter, otherwise the reason shown to them.
static func check_hello(
	hello: Dictionary, host_hello: Dictionary, player_count: int, max_players: int, same_build: bool
) -> String:
	if hello.get("protocol") != PROTOCOL:
		return "Incompatible game version. Pull the latest commit."
	if hello.get("version") != host_hello["version"]:
		var versions: Array = [host_hello["version"], hello.get("version")]
		return "Version mismatch: host has %s, you have %s." % versions
	if same_build and _builds_differ(str(hello.get("build")), str(host_hello["build"])):
		return (
			"Your build (%s) differs from the host's (%s). Pull the same commit and save all scenes."
			% [hello.get("build"), host_hello["build"]]
		)
	if player_count >= max_players:
		return "Lobby is full (%d/%d players)." % [player_count, max_players]
	return ""


static func _builds_differ(joiner_build: String, host_build: String) -> bool:
	if joiner_build == BuildInfo.RELEASE or host_build == BuildInfo.RELEASE:
		return false
	return joiner_build != host_build
