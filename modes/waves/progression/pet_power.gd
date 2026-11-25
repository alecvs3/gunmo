class_name PetPower
extends RefCounted
## What a pet adds to a paper player (PlayerPower), as averages over a wave: extra damage,
## heals and team effects. Every rule comes from the pet's own rules class (SoldierRules,
## WizardRules, HealerRules) and its data; the averaging knobs are in ProgressionModel.


## The owner's own damage bonus (Soldier Drill; Last Stand only counts while someone is down).
static func own_damage(player: SimPlayer) -> float:
	var soldier := player.pet() as SoldierData
	return SoldierRules.damage_bonus(soldier, player.pet_tier, false) if soldier != null else 0.0


## Adds the pet's damage and team effects to `power`.
static func add(
	power: PlayerPower,
	player: SimPlayer,
	weapon: WeaponData,
	wave: WaveReport.Row,
	model: ProgressionModel
) -> void:
	var pet: PetData = player.pet()
	if pet is SoldierData:
		_soldier(power, pet as SoldierData, player, weapon, wave, model)
	elif pet is WizardData:
		_wizard(power, pet as WizardData, player, weapon, wave, model)
	elif pet is HealerData:
		power.team_heal = HealerRules.wave_end_share(pet as HealerData, player.pet_tier)


## Share of max health the Healer gives back each wave: Mending, Siphon (up to its cap), and
## Guardian's save. `power.dps` must already be set (Siphon heals from damage dealt).
static func heal_share(player: SimPlayer, power: PlayerPower, model: ProgressionModel) -> float:
	var healer := player.pet() as HealerData
	if healer == null:
		return 0.0
	var tier: int = player.pet_tier
	var share: float = HealerRules.mending_share(healer, tier)
	if tier >= HealerRules.SIPHON:
		var cap: float = (
			healer.siphon_cap_upgraded if tier >= HealerRules.GUARDIAN else healer.siphon_cap
		)
		var dealt: float = power.dps * model.clear_seconds * healer.siphon_share
		share += minf(cap, dealt / maxf(player.stats().max_health, 1.0))
	if HealerRules.guardian_saves(tier, false):
		share += healer.guardian_share
	return share


## How much the pet cuts the owner's chance to go down (Guardian).
static func down_cut(player: SimPlayer, model: ProgressionModel) -> float:
	return (
		model.guardian_cut
		if HealerRules.guardian_saves(player.pet_tier, false) and player.pet() is HealerData
		else 0.0
	)


static func _soldier(
	power: PlayerPower,
	data: SoldierData,
	player: SimPlayer,
	weapon: WeaponData,
	wave: WaveReport.Row,
	model: ProgressionModel
) -> void:
	var tier: int = player.pet_tier
	var factor: float = PlayerPower.type_factor(wave, data.damage_type)
	var cover: int = SoldierRules.cover_damage(data, tier, weapon.damage)
	power.dps += cover / data.cover_interval * model.pet_accuracy * factor
	if tier >= SoldierRules.AIRSTRIKE:
		var number: int = wave.wave if wave != null else 1
		var strike: int = SoldierRules.airstrike_damage(data, number, false)
		var burst: float = strike * model.airstrike_targets / model.airstrike_seconds * factor
		power.dps += burst
		power.burst_dps += burst
	if tier >= SoldierRules.RALLY:
		power.team_fire_rate = SoldierRules.rally_fire_rate(data, tier) * model.rally_uptime


static func _wizard(
	power: PlayerPower,
	data: WizardData,
	player: SimPlayer,
	weapon: WeaponData,
	wave: WaveReport.Row,
	model: ProgressionModel
) -> void:
	var tier: int = player.pet_tier
	var factor: float = PlayerPower.type_factor(wave, data.damage_type)
	var cycle: float = weapon.magazine_size / weapon.fire_rate + weapon.reload_time
	var aim: float = player.archetype.accuracy * player.archetype.uptime
	var hits: float = weapon.magazine_size / cycle * weapon.pellets * aim
	var arcs: float = minf(hits * WizardRules.arc_chance(data, tier), 1.0 / data.arc_cooldown)
	var slowed: bool = tier >= WizardRules.CONDUCTION
	var jump: float = WizardRules.arc_damage(data, tier, weapon.damage, false)
	if slowed:
		jump *= 1.0 + data.conduction_bonus * model.slowed_share
	power.dps += arcs * WizardRules.arc_jumps(data, tier, false) * jump * factor
	if tier >= WizardRules.TEMPEST:
		var health: int = roundi(wave.average_health) if wave != null else 100
		var bolt: int = WizardRules.tempest_damage(data, health, false)
		var burst: float = data.tempest_bolts * bolt / WizardRules.tempest_interval(data, tier)
		power.dps += burst * factor
		power.burst_dps += burst * factor
	_wizard_team(power, data, tier, model)


static func _wizard_team(
	power: PlayerPower, data: WizardData, tier: int, model: ProgressionModel
) -> void:
	var rune: float = WizardRules.rune_interval(data, tier)
	if rune > 0.0:
		power.team_slow = data.rune_slow * minf(data.rune_seconds / rune, 1.0) * model.rune_coverage
	var hex: float = WizardRules.hex_interval(data, tier)
	if hex > 0.0:
		power.team_damage = (
			data.hex_bonus * minf(data.hex_seconds / hex, 1.0) * model.hex_focus_share
		)
