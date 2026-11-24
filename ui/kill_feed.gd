class_name KillFeed
extends VBoxContainer
## The kill feed: the last few kills (EventBus kill_reported, on every peer), "Killer [SMG]
## Victim", newest at the bottom, each fading out after SHOW_SECONDS. Names come from the
## replicated players.

const MAX_ENTRIES: int = 5
const SHOW_SECONDS: float = 5.0

var _catalog: ShopCatalog = ShopCatalog.load_default()


## "Killer [SMG] Victim"; no killer (a fall, an enemy) = "Victim died".
static func entry_text(killer: String, weapon: String, victim: String) -> String:
	if killer.is_empty():
		return "%s died" % victim
	if weapon.is_empty():
		return "%s killed %s" % [killer, victim]
	return "%s [%s] %s" % [killer, weapon, victim]


func _ready() -> void:
	EventBus.kill_reported.connect(_on_kill_reported)


func _process(delta: float) -> void:
	for label: Label in get_children():
		var left: float = label.get_meta("left", 0.0) - delta
		label.set_meta("left", left)
		label.modulate.a = clampf(left, 0.0, 1.0)
		if left <= 0.0:
			label.queue_free()


func _on_kill_reported(killer_id: int, victim_id: int, weapon_index: int) -> void:
	var weapon: String = ""
	if _catalog.is_weapon_index(weapon_index):
		weapon = _catalog.weapons[weapon_index].display_name
	var label := Label.new()
	label.text = entry_text(_name_of(killer_id), weapon, _name_of(victim_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.set_meta("left", SHOW_SECONDS)
	add_child(label)
	while get_child_count() > MAX_ENTRIES:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func _name_of(peer_id: int) -> String:
	if peer_id == 0:
		return ""
	for node in get_tree().get_nodes_in_group(Groups.PLAYERS):
		var player := node as Player
		if player != null and player.peer_id == peer_id:
			return player.display_name
	return "?"
