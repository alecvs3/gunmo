class_name CheckScope
extends RefCounted
## Which multiplayer smoke scenarios a set of changed files needs, from the rules in
## tools/check_scope.json. Pure (files and rules are passed in), so tested. The command line
## side is tools/check_scope_cli.gd, which .\tools\check.ps1 -Changed runs.

const RULES_PATH: String = "res://tools/check_scope.json"


## What a change needs: the scenarios to run (in order), whether that is all of them, and one
## line per reason, for the person reading the check's output.
class Decision:
	var full: bool = false
	var scenarios: Array[String] = []
	var reasons: Array[String] = []


static func load_rules(path: String = RULES_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func decide(files: PackedStringArray, rules: Dictionary) -> Decision:
	var decision := Decision.new()
	var all: Array = rules.get("scenarios", [])
	if files.size() > int(rules.get("big_change_files", 25)):
		decision.reasons.append("%d files changed: a big change, so everything" % files.size())
		return _everything(decision, all)
	var wanted: Dictionary = {}
	for file in files:
		var key: String = match_key(file, rules.get("paths", {}))
		var value: Variant = rules["paths"][key] if key != "" else "all"
		if value is String and value == "all":
			var why: String = "matches %s" % key if key != "" else "is in no rule"
			decision.reasons.append("%s %s: everything" % [file, why])
			return _everything(decision, all)
		for letter: String in value:
			wanted[letter] = true
		if not value.is_empty():
			decision.reasons.append("%s -> %s" % [file, ",".join(PackedStringArray(value))])
	for letter: String in all:
		if wanted.has(letter):
			decision.scenarios.append(letter)
	return decision


## The rule a file falls under: the longest path that starts it, else a "*suffix" rule its
## name ends with, else "" (no rule). A .uid file follows the script it belongs to.
static func match_key(file: String, paths: Dictionary) -> String:
	var name: String = file.replace("\\", "/").trim_suffix(".uid")
	var best: String = ""
	for key: String in paths:
		if key.begins_with("*"):
			if name.ends_with(key.substr(1)):
				return key
		elif name.begins_with(key) and key.length() > best.length():
			best = key
	return best


static func _everything(decision: Decision, all: Array) -> Decision:
	decision.full = true
	decision.scenarios.assign(all)
	return decision
