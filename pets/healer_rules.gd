class_name HealerRules
extends RefCounted
## The Healer's tiers as pure rules (numbers from HealerData). `tier` is how many tiers the
## owner has bought (0 = no Healer); a tier's rule applies from that tier on.

const MENDING: int = 1
const WAVE_END: int = 2
const TRIAGE: int = 3
const SIPHON: int = 4
const GUARDIAN: int = 5


## Tier 1: the share Mending heals (0 = not owned), more from tier 2.
static func mending_share(data: HealerData, tier: int) -> float:
	if tier < MENDING:
		return 0.0
	return data.mending_share_upgraded if tier >= WAVE_END else data.mending_share


## Whether the team has dealt enough of the wave's enemy health for Mending.
static func mending_ready(data: HealerData, dealt: int, wave_health: int) -> bool:
	return wave_health > 0 and dealt >= wave_health * data.mending_threshold


## Tier 2: the share everyone heals when a wave is cleared, more from tier 3.
static func wave_end_share(data: HealerData, tier: int) -> float:
	if tier < WAVE_END:
		return 0.0
	return data.wave_end_share_upgraded if tier >= TRIAGE else data.wave_end_share


## Tier 3: how much faster the owner revives, and the extra health their revives give.
static func revive_speed(data: HealerData, tier: int) -> float:
	return data.triage_revive_speed if tier >= TRIAGE else 1.0


static func revive_bonus(data: HealerData, tier: int) -> float:
	return data.triage_health_bonus if tier >= TRIAGE else 0.0


## Tier 4: health back for dealing `damage`, given `healed` already this wave (never past the
## per-wave cap, more from tier 5).
static func siphon_heal(
	data: HealerData, tier: int, damage: int, healed: int, max_health: int
) -> int:
	if tier < SIPHON or damage <= 0:
		return 0
	var cap_share: float = data.siphon_cap_upgraded if tier >= GUARDIAN else data.siphon_cap
	var room: int = floori(max_health * cap_share) - healed
	return clampi(roundi(damage * data.siphon_share), 0, maxi(room, 0))


## Tier 5: whether Guardian saves the owner from going down (once a wave).
static func guardian_saves(tier: int, used_this_wave: bool) -> bool:
	return tier >= GUARDIAN and not used_this_wave


## Health from a share of max health (at least 1).
static func amount(share: float, max_health: int) -> int:
	return maxi(roundi(max_health * share), 1)
