class_name BuildInfo
extends RefCounted
## Identifies this build so the host can refuse joiners running different code.
## In the editor the fingerprint is a hash of every script, scene and resource outside
## addons/, tests/ and docs/. Exported builds report RELEASE and are compared by version only.

const RELEASE: String = "release"
const HASHED_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
const SKIPPED_DIRS: PackedStringArray = ["addons", "tests", "docs"]

static var _cached_fingerprint: String = ""


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func fingerprint() -> String:
	if not OS.has_feature("editor"):
		return RELEASE
	if _cached_fingerprint.is_empty():
		_cached_fingerprint = hash_files(collect_files("res://"))
	return _cached_fingerprint


## Line endings are ignored so a Windows CRLF checkout matches an LF one.
static func hash_files(paths: PackedStringArray) -> String:
	var sorted_paths: Array = Array(paths)
	sorted_paths.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path: String in sorted_paths:
		context.update(path.to_utf8_buffer())
		context.update(FileAccess.get_file_as_string(path).replace("\r", "").to_utf8_buffer())
	return context.finish().hex_encode().left(12)


static func collect_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file_name in dir.get_files():
		if file_name.get_extension() in HASHED_EXTENSIONS:
			found.append(dir_path.path_join(file_name))
	for sub_dir in dir.get_directories():
		if not sub_dir.begins_with(".") and not (dir_path == "res://" and sub_dir in SKIPPED_DIRS):
			found.append_array(collect_files(dir_path.path_join(sub_dir)))
	return found
