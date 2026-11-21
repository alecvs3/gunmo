extends GutTest
## The guides for Claude (every CLAUDE.md and the recipes in .claude/skills) must not point at
## files that no longer exist. A path in `backticks` is checked from the project root, then from
## the guide's own folder. Fix the guide in the same PR that moves or renames a file.

const SKILLS_FOLDER: String = "res://.claude/skills"
const SKIP_FOLDERS: Array[String] = ["res://.godot", "res://addons", "res://.git"]
const FILE_PATTERN: String = "^[\\w./-]+\\.(gd|tres|tscn|md|ps1|json|cfg)$"


func test_every_path_in_a_guide_exists() -> void:
	var guides: Array[String] = _guides()
	assert_gt(guides.size(), 7, "the root guide, the folder guides and the recipes are found")
	var pattern := RegEx.create_from_string(FILE_PATTERN)
	for guide in guides:
		for path in _quoted_paths(guide, pattern):
			assert_true(_exists(path, guide.get_base_dir()), "%s names missing %s" % [guide, path])


func test_every_recipe_has_a_name_and_description() -> void:
	for folder in DirAccess.get_directories_at(SKILLS_FOLDER):
		var text: String = FileAccess.get_file_as_string("%s/%s/SKILL.md" % [SKILLS_FOLDER, folder])
		assert_true(text.begins_with("---\nname: %s\n" % folder), folder + ": name matches folder")
		assert_string_contains(text, "\ndescription: ")


func _guides() -> Array[String]:
	var found: Array[String] = []
	_find_claude_md("res://", found)
	for folder in DirAccess.get_directories_at(SKILLS_FOLDER):
		found.append("%s/%s/SKILL.md" % [SKILLS_FOLDER, folder])
	return found


func _find_claude_md(folder: String, found: Array[String]) -> void:
	if folder.trim_suffix("/") in SKIP_FOLDERS:
		return
	if FileAccess.file_exists(folder.path_join("CLAUDE.md")):
		found.append(folder.path_join("CLAUDE.md"))
	for child in DirAccess.get_directories_at(folder):
		if not child.begins_with("."):
			_find_claude_md(folder.path_join(child), found)


## Every `backticked` text in the guide that looks like a file path.
func _quoted_paths(guide: String, pattern: RegEx) -> Array[String]:
	var paths: Array[String] = []
	var parts: PackedStringArray = FileAccess.get_file_as_string(guide).split("`")
	for i in range(1, parts.size(), 2):
		var text: String = parts[i].trim_prefix("res://")
		if "/" in text and pattern.search(text) != null:
			paths.append(text)
	return paths


func _exists(path: String, guide_folder: String) -> bool:
	return (
		FileAccess.file_exists("res://" + path)
		or FileAccess.file_exists(guide_folder.path_join(path))
	)
