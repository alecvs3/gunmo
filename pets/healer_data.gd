class_name HealerData
extends PetData
## The Healer's numbers (HealerRules reads them). Every heal is a share of max health with a
## limit each wave, so the Healer never makes anyone unkillable.

@export_group("Mending (tier 1, better from 2)")
## The team must have dealt this share of the wave's enemy health first.
@export_range(0.0, 1.0) var mending_threshold: float = 0.5
@export_range(0.0, 1.0) var mending_share: float = 0.12
@export_range(0.0, 1.0) var mending_share_upgraded: float = 0.15

@export_group("Wave's End (tier 2, better from 3)")
@export_range(0.0, 1.0) var wave_end_share: float = 0.08
@export_range(0.0, 1.0) var wave_end_share_upgraded: float = 0.10

@export_group("Triage (tier 3)")
## Extra share of max health a player revived by this pet's owner comes back with.
@export_range(0.0, 1.0) var triage_health_bonus: float = 0.2
## The owner's revives fill this much faster (1.25 = 25% faster).
@export_range(1.0, 5.0) var triage_revive_speed: float = 1.25

@export_group("Siphon (tier 4, better from 5)")
## Share of the damage you deal that heals you.
@export_range(0.0, 1.0) var siphon_share: float = 0.02
## At most this share of your max health per wave.
@export_range(0.0, 1.0) var siphon_cap: float = 0.10
@export_range(0.0, 1.0) var siphon_cap_upgraded: float = 0.15

@export_group("Guardian (tier 5)")
## The first time each wave you'd go down you stay up with this share of your max health.
@export_range(0.0, 1.0) var guardian_share: float = 0.2
