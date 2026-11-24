class_name BossBar
extends VBoxContainer
## The boss health bar: while a boss is in the level (Groups.BOSSES, on every peer) it shows
## its name, its current phase and its health, from the replicated enemy. Hidden otherwise.

@onready var _label: Label = %BossLabel
@onready var _bar: ProgressBar = %BossBar


## "Warden · Lockdown" ("Warden" when the phase has no name).
static func title(boss_name: String, phase_name: String) -> String:
	return boss_name if phase_name.is_empty() else "%s · %s" % [boss_name, phase_name]


func _process(_delta: float) -> void:
	var boss := get_tree().get_first_node_in_group(Groups.BOSSES) as ChaserEnemy
	visible = boss != null and boss.is_inside_tree() and boss.health_share() > 0.0
	if not visible:
		return
	var data: EnemyData = boss.enemy_data
	var index: int = boss.phase_index()
	var phase_name: String = data.phases[index].display_name if index < data.phases.size() else ""
	_label.text = title(data.display_name, phase_name)
	_bar.value = boss.health_share() * 100.0
