class_name TeamSetup
extends Resource
## A team for the progression paper run: who plays (one PlayerArchetype each) and which pet
## each one raises. Bots count as members like anyone else. Waves never grow with the team,
## so a bigger team shares the same bounties.

@export var display_name: String = ""
@export var members: Array[PlayerArchetype] = []
## PetCatalog index for each member (-1 or missing = no pet).
@export var pets := PackedInt32Array()
## Calls every early wave early (up to MatchSettings.early_call_last_wave): more credits, but
## those breaks have no shop and no Path step.
@export var calls_early: bool = false


## `size` players of `archetype`, with pets from `pet_order` in turn.
static func uniform(
	archetype: PlayerArchetype, size: int, pet_order: PackedInt32Array
) -> TeamSetup:
	var team := TeamSetup.new()
	team.display_name = "%s ×%d" % [archetype.display_name, size]
	for i in size:
		team.members.append(archetype)
		team.pets.append(pet_order[i % pet_order.size()] if not pet_order.is_empty() else -1)
	return team


func pet_for(member: int) -> int:
	return pets[member] if member < pets.size() else -1
