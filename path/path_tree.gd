class_name PathTree
extends Resource
## Every Path node, in a fixed order: nodes travel by index (bit i of a player's owned mask is
## the node at index i, in requests and the player snapshot), so every peer uses the default
## tree at DEFAULT_PATH. Append new nodes; never reorder or remove one.

const DEFAULT_PATH: String = "res://path/data/path_tree.tres"
## The owned mask is 64 bits.
const MAX_NODES: int = 64

@export var nodes: Array[PathNode] = []


static func load_default() -> PathTree:
	return load(DEFAULT_PATH)


func is_node_index(index: int) -> bool:
	return index >= 0 and index < mini(nodes.size(), MAX_NODES) and nodes[index] != null


func node(index: int) -> PathNode:
	return nodes[index] if is_node_index(index) else null


## -1 if the node is not in this tree.
func index_of(path_node: PathNode) -> int:
	var index: int = nodes.find(path_node)
	return index if is_node_index(index) else -1


static func owns(owned: int, index: int) -> bool:
	return index >= 0 and index < MAX_NODES and owned & (1 << index) != 0


## The owned nodes' effects, in tree order.
func owned_effects(owned: int) -> Array[PathEffect]:
	var effects: Array[PathEffect] = []
	for i in mini(nodes.size(), MAX_NODES):
		if owns(owned, i) and nodes[i] != null:
			effects.append_array(nodes[i].effects)
	return effects


## One bonus per UpgradeData.Stat (index = the stat), summed over the owned nodes.
func stat_bonuses(owned: int) -> PackedFloat32Array:
	var bonuses := PackedFloat32Array()
	bonuses.resize(UpgradeData.Stat.size())
	for effect in owned_effects(owned):
		for stat in UpgradeData.Stat.values():
			bonuses[stat] += effect.stat_bonus(stat)
	return bonuses


func shop_price_multiplier(owned: int) -> float:
	var multiplier: float = 1.0
	for effect in owned_effects(owned):
		multiplier *= effect.shop_price_multiplier()
	return multiplier


func extra_boss_cores(owned: int) -> int:
	var extra: int = 0
	for effect in owned_effects(owned):
		extra += effect.extra_boss_cores()
	return extra


## The nodes that lock node `index` out (and that it locks out): `excludes` works both ways.
func rivals(index: int) -> Array[int]:
	var found: Array[int] = []
	var path_node: PathNode = node(index)
	if path_node == null:
		return found
	for i in mini(nodes.size(), MAX_NODES):
		var other: PathNode = nodes[i]
		if other != null and (other in path_node.excludes or path_node in other.excludes):
			found.append(i)
	return found


## The branches in the order their first node appears.
func branches() -> Array[String]:
	var names: Array[String] = []
	for path_node in nodes:
		if path_node != null and path_node.branch not in names:
			names.append(path_node.branch)
	return names
