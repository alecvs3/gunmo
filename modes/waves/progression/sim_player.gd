class_name SimPlayer
extends RefCounted
## One player in the progression paper run: what they have bought (the same fields as a
## PlayerLoadout: gun, upgrade levels, pet tier, Path), their credits, and what they earned
## and spent. Stats come from PlayerStats, exactly as in a match.

const BASE_PLAYER: String = "res://player/data/default_player.tres"

## Income sources, for the graphs.
const BOUNTY := &"bounty"
const CLEAR := &"clear"
const INTEREST := &"interest"
const EARLY := &"early"
const SOURCES: Array[StringName] = [BOUNTY, CLEAR, INTEREST, EARLY]

var archetype: PlayerArchetype
var catalog: ShopCatalog
var pets: PetCatalog
var path_tree: PathTree
var base_player: PlayerData
var weapon_index: int = 0
var levels := PackedByteArray()
var pet_index: int = -1
var pet_tier: int = 0
var path := PathProgress.new()
## Credits are averages over many matches, so they keep fractions.
var credits: float = 0.0
var spent: float = 0.0
## Source -> credits earned in the whole run so far.
var earned: Dictionary = {}


static func make(who: PlayerArchetype, pet: int) -> SimPlayer:
	var player := SimPlayer.new()
	player.archetype = who
	player.catalog = ShopCatalog.load_default()
	player.pets = PetCatalog.load_default()
	player.path_tree = PathTree.load_default()
	player.base_player = load(BASE_PLAYER)
	player.levels.resize(player.catalog.upgrades.size())
	player.pet_index = pet if player.pets.is_pet_index(pet) else -1
	for source in SOURCES:
		player.earned[source] = 0.0
	return player


## A copy to try a purchase on (catalogs shared, progress copied).
func copy() -> SimPlayer:
	var other: SimPlayer = SimPlayer.new()
	for field in ["archetype", "catalog", "pets", "path_tree", "base_player"]:
		other.set(field, get(field))
	other.weapon_index = weapon_index
	other.levels = levels.duplicate()
	other.pet_index = pet_index
	other.pet_tier = pet_tier
	other.path.owned = path.owned
	other.path.cores = path.cores
	other.credits = credits
	return other


func earn(source: StringName, amount: float) -> void:
	credits += amount
	earned[source] = earned.get(source, 0.0) + amount


func weapon() -> WeaponData:
	var bonuses: PackedFloat32Array = path_tree.stat_bonuses(path.owned)
	return PlayerStats.effective_weapon(catalog.weapon(weapon_index), catalog, levels, bonuses)


func stats() -> PlayerData:
	var bonuses: PackedFloat32Array = path_tree.stat_bonuses(path.owned)
	return PlayerStats.effective_player(base_player, catalog, levels, bonuses)


## The pet's data (null = no pet or none bought yet).
func pet() -> PetData:
	return pets.pet(pet_index) if pet_index >= 0 and pet_tier > 0 else null


func shop_discount() -> float:
	return path_tree.shop_price_multiplier(path.owned)
