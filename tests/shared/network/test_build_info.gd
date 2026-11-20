extends GutTest

const DIR: String = "user://test_build_info"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/sub")
	_write("a.gd", "extends Node\nvar x := 1\n")
	_write("sub/b.tscn", "[gd_scene format=3]\n")
	_write("notes.txt", "ignored")


func after_each() -> void:
	for path in ["a.gd", "sub/b.tscn", "notes.txt"]:
		DirAccess.remove_absolute(DIR.path_join(path))
	DirAccess.remove_absolute(DIR + "/sub")
	DirAccess.remove_absolute(DIR)


func test_collects_only_hashed_extensions_recursively() -> void:
	var files: PackedStringArray = BuildInfo.collect_files(DIR)
	assert_eq(files.size(), 2)
	assert_has(files, DIR.path_join("a.gd"))
	assert_has(files, DIR.path_join("sub").path_join("b.tscn"))


func test_hash_is_stable_and_order_independent() -> void:
	var files: PackedStringArray = BuildInfo.collect_files(DIR)
	var reversed := files.duplicate()
	reversed.reverse()
	assert_eq(BuildInfo.hash_files(files), BuildInfo.hash_files(reversed))
	assert_eq(BuildInfo.hash_files(files).length(), 12)


func test_hash_changes_when_content_changes() -> void:
	var before: String = BuildInfo.hash_files(BuildInfo.collect_files(DIR))
	_write("a.gd", "extends Node\nvar x := 2\n")
	assert_ne(BuildInfo.hash_files(BuildInfo.collect_files(DIR)), before)


func test_hash_ignores_line_endings() -> void:
	var before: String = BuildInfo.hash_files(BuildInfo.collect_files(DIR))
	_write("a.gd", "extends Node\r\nvar x := 1\r\n")
	assert_eq(BuildInfo.hash_files(BuildInfo.collect_files(DIR)), before)


func test_project_fingerprint_is_available_in_editor_runs() -> void:
	assert_eq(BuildInfo.fingerprint().length(), 12)
	assert_eq(BuildInfo.version(), "0.1.0")


func _write(relative_path: String, text: String) -> void:
	var file := FileAccess.open(DIR.path_join(relative_path), FileAccess.WRITE)
	file.store_string(text)
	file.close()
