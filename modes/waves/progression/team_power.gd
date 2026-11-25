class_name TeamPower
extends RefCounted
## A whole team's strength against one wave: its players' PlayerPower added up, with each pet
## team effect counted once (the strongest), like the game's "team effects don't stack". Every
## difficulty axis reads it in `DifficultyAxis.handled()`.

var dps: float = 0.0
var burst_dps: float = 0.0
var melee_health: float = 0.0
var ranged_health: float = 0.0
var mobility: float = 0.0
var players: Array[PlayerPower] = []


static func of(powers: Array[PlayerPower]) -> TeamPower:
	var team := TeamPower.new()
	team.players = powers
	var fire_rate: float = 0.0
	var damage: float = 0.0
	var slow: float = 0.0
	var heal: float = 0.0
	for power in powers:
		team.dps += power.dps
		team.burst_dps += power.burst_dps
		team.melee_health += power.melee_health
		team.ranged_health += power.ranged_health
		team.mobility += power.mobility
		fire_rate = maxf(fire_rate, power.team_fire_rate)
		damage = maxf(damage, power.team_damage)
		slow = maxf(slow, power.team_slow)
		heal = maxf(heal, power.team_heal)
	team.dps *= (1.0 + fire_rate) * (1.0 + damage)
	team.melee_health *= (1.0 + heal) * (1.0 + slow)
	team.ranged_health *= 1.0 + heal
	team.mobility *= 1.0 + slow
	return team


## Each player's share of the team's kills (bounty goes to the killing hit): damage per second
## to the power `kill_power`, over the team's. Adds up to 1.
func kill_shares(kill_power: float) -> PackedFloat32Array:
	var shares := PackedFloat32Array()
	var total: float = 0.0
	for power in players:
		shares.append(pow(maxf(power.dps, 0.0), kill_power))
		total += shares[-1]
	for i in shares.size():
		shares[i] = shares[i] / total if total > 0.0 else 1.0 / shares.size()
	return shares
